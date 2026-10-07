#!/usr/bin/env bash
# Ukishima dependency check — the single reporter for what the shell needs.
#
# Everything it reports comes from dependencies.json at the repo root, so this
# script, remote-install.sh and the README link cannot disagree about what a
# dependency is. The point of the manifest is that adding a dependency becomes a
# one-line declarative change here, which is what lets the post-update report
# tell an existing user "this update now needs X" without anyone writing a
# bespoke message.
#
# It is deliberately a shell script rather than part of the shell: the update it
# guards against can be a dependency whose absence stops the shell from loading
# at all (an unresolvable QML import), and code that fails to load cannot report
# its own missing dependencies.
#
# Usage:
#   check-deps.sh              report to stdout; exit 1 if a core dep is missing
#   check-deps.sh --all        also list which optional deps are missing
#   check-deps.sh --json       JSON, for the in-app manual check
#   check-deps.sh --page       write the HTML report and open it in a browser
#   check-deps.sh --install    remote-install.sh's report format, from the manifest
#   check-deps.sh --report     post-update path: write the page and open it
#
# Exit codes: 0 = every core dependency present, 1 = core dependency missing,
#             2 = could not run the check at all (bad usage, or no jq/manifest).

set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# The manifest lives at the repo root, one level up from scripts/. UKISHIMA_MANIFEST
# overrides it so a caller can point at a specific checkout.
MANIFEST="${UKISHIMA_MANIFEST:-$(dirname -- "$SELF_DIR")/dependencies.json}"

# Under `set -u` an unset HOME is a fatal error, not an empty string, so the
# `${XDG_...:-$HOME/...}` idiom dies on any environment that does not export one
# — which is exactly the kind of stripped environment a Process can hand this
# script, and it would take the whole check down before a word is reported.
# Resolving HOME once, with a last-resort fallback, keeps the failure mode "the
# report went somewhere odd" instead of "no report".
: "${HOME:=/tmp}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima"
PAGE="$CACHE_DIR/deps.html"

usage() {
  # Slices this header's own comment block, so editing the usage above can never
  # leave --help printing a stale or truncated list.
  sed -n '3,/^$/p' -- "$0" | sed -e 's/^# \{0,1\}//' -e '/^$/d'
}

# ---------------------------------------------------------------------------
# escaping / small helpers
# ---------------------------------------------------------------------------

esc() {
  # HTML-escape. Everything interpolated into the page goes through this.
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
                         -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

# ---------------------------------------------------------------------------
# argument parsing
# ---------------------------------------------------------------------------

show_all=0
as_json=0
open_page=0
do_report=0
install_mode=0

while [ $# -gt 0 ]; do
  case "$1" in
    --all) show_all=1 ;;
    --json) as_json=1 ;;
    --page) open_page=1 ;;
    --report) do_report=1 ;;
    --install) install_mode=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'check-deps: unknown option %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done


# ---------------------------------------------------------------------------
# preconditions
#
# jq is both this script's parser and one of the dependencies it reports on, so
# its absence is a genuine chicken-and-egg case. Duplicating the list here to
# cover it would reintroduce exactly the drift the manifest exists to prevent, so
# we say what is actually wrong and how to fix it. remote-install.sh checks its
# own list independently, so a fresh install still gets the full report.
# ---------------------------------------------------------------------------

# Which package manager is this system using?
#
# The dependency *checks* are distribution-independent — `command -v` finds a
# binary the same way everywhere, and the `path` form covers the lib / lib64 /
# multiarch layouts. What is not distribution-independent is the advice: the
# manifest's `pkg` names are Arch names, and "sudo pacman -S" is meaningless on
# Fedora. So the command is detected and the names are resolved per manager.
#
# Detection feeds the *install line only*. A wrong guess cannot make the report
# wrong about what is missing; it can only make the suggested command wrong, and
# an unrecognised manager falls back to listing bare names rather than inventing
# a command nobody can run.
PM_ID=""
PM_CMD=""
detect_pm() {
  local pm
  for pm in pacman apt-get dnf zypper apk xbps-install emerge brew; do
    command -v "$pm" >/dev/null 2>&1 || continue
    PM_ID="$pm"
    case "$pm" in
      pacman) PM_CMD="sudo pacman -S" ;;
      apt-get) PM_CMD="sudo apt-get install" ;;
      dnf) PM_CMD="sudo dnf install" ;;
      zypper) PM_CMD="sudo zypper install" ;;
      apk) PM_CMD="sudo apk add" ;;
      xbps-install) PM_CMD="sudo xbps-install -S" ;;
      emerge) PM_CMD="sudo emerge" ;;
      brew) PM_CMD="brew install" ;;
    esac
    return 0
  done
  return 1
}
detect_pm || true

# The line to actually run, or the bare names when no manager was recognised.
install_cmd() {
  if [ -n "$PM_CMD" ]; then
    printf '%s %s' "$PM_CMD" "$1"
  else
    printf '%s' "$1"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  printf 'check-deps: jq is not installed, so dependencies.json cannot be read.\n' >&2
  printf '           Install jq with: %s\n' "$(install_cmd jq)" >&2
  exit 2
fi

if [ ! -f "$MANIFEST" ]; then
  printf 'check-deps: no manifest at %s\n' "$MANIFEST" >&2
  exit 2
fi

# Validated up front so a hand-edited or half-merged manifest reports itself
# instead of surfacing as a raw jq parse error partway through the report.
if ! jq -e . "$MANIFEST" >/dev/null 2>&1; then
  printf 'check-deps: %s is not valid JSON, so the dependency list cannot be read.\n' "$MANIFEST" >&2
  printf '           Usually a partially-edited or half-merged manifest; restore it with\n' >&2
  printf '           `git checkout -- dependencies.json` and re-run.\n' >&2
  exit 2
fi
# present <kind> <arg> — true when the dependency is satisfied.


# ---------------------------------------------------------------------------
# collect
#
# One jq invocation emits a tab-separated record per dependency. Pre-splitting
# the check into a kind and an argument keeps the per-entry work in bash, which
# matters because spawning jq per field per entry is ~100x slower for no gain.
# Column 6 is deliberately space-joined rather than JSON: no path or binary name
# in this manifest contains a space, and the simple form needs no re-parsing.
# ---------------------------------------------------------------------------

# An absent section is treated as empty rather than being an error: the report is
# the thing that must survive a slightly-off manifest. An entry that is present
# but malformed resolves to an empty kind, which `present` fails — so a typo'd
# entry is reported as MISSING instead of quietly counting as satisfied.
TSV=$(jq -r '
  # Normalise a check argument to a single space-separated string. Accepts
  # either shape, because a one-element list is not a list anyone wants to read:
  # { "pkgdb": "jq" } and { "pkgdb": ["jq"] } should not be a way to make the
  # manifest fail to parse. A bare string is passed through, an array is joined.
  def flat($v): if ($v | type) == "array" then ($v | join(" "))
                elif ($v | type) == "string" then $v
                else "" end;
  def arg($c): if ($c.bin?) then flat($c.bin)
               elif ($c.bins?) then flat($c.bins)
               elif ($c.anyBin?) then flat($c.anyBin)
               elif ($c.pkgdb?) then flat($c.pkgdb)
               elif ($c.service?) then flat($c.service)
               else flat($c.path // "") end;
  def kind($c): if ($c.bin?) then "bin" elif ($c.bins?) then "bins"
                elif ($c.anyBin?) then "anyBin" elif ($c.pkgdb?) then "pkgdb"
                elif ($c.service?) then "service"
                else "path" end;
  def pkgs($p): (($p // []) | join(" "));
  # Package names for the detected manager. `pkg` holds the Arch name; an entry
  # may carry `pkgAlt` mapping a manager id to that distribution'"'"'s names,
  # because plenty of them genuinely differ — bluetoothctl is in bluez-utils on
  # Arch but in plain bluez on Debian and Fedora. Absent an override the Arch
  # name is used, which is right on Arch and a recognisable hint anywhere else.
  def pkgs_for($e): (($e.pkgAlt[$pm] // $e.pkg) | join(" "));
  ( .core[]?    | ["core",    .id, .why, pkgs_for(.), kind(.check), arg(.check), "0"] ),
  ( .optional[]? | ["optional", .id, .why, pkgs_for(.), kind(.check), arg(.check),
                    (if .nudge then "1" else "0" end)] )
  | @tsv' --arg pm "$PM_ID" "$MANIFEST") || {
  printf 'check-deps: could not read entries out of %s\n' "$MANIFEST" >&2
  exit 2
}

# Expand a leading ~/ or $HOME/ in a path that arrived via a variable. The shell
# performs tilde expansion during parsing, not on the result of a parameter
# expansion, so `$HOME` in a manifest value stays literal unless we do it here.
# Deliberately not `eval`: the manifest is repo data, and handing it to the
# evaluator would make "editing a JSON file" an arbitrary-code-execution path
# for no benefit, since these two prefixes are the only ones anyone needs.
expand_path() {
  case "$1" in
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    '$HOME/'*) printf '%s/%s' "$HOME" "${1#\$HOME/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Is a package installed? Answered without asking the package manager.
# ---------------------------------------------------------------------------
#
# `pacman -Q`, `dpkg -s`, `rpm -q` and their relatives all answer this, and all
# of them answer it by starting a program built to do far more than answer it.
# That matters here for two reasons: this runs from the update path against the
# shell's own process environment, which is a plausible place for a command to
# go missing, and a check that forks a package manager once per dependency turns
# a millisecond of reading into a couple of seconds of process startup.
#
# Every mainstream package manager already keeps a record of exactly which
# packages it has installed, in a plain file or a directory of plain files. So
# the same question is answerable by reading that record, which needs no
# package manager, no network, and no elevated privileges — it is a question
# about what is already on this disk.
#
# The entire set is read in one pass rather than queried per dependency, so the
# cost is a fixed couple of greps no matter how many dependencies the manifest
# has. A system with 1139 packages installed is two processes and an
# associative-array fill; every lookup after that is a hash hit.
PKGDB_STATE=unloaded
PKGDB_READABLE=0
declare -A PKGDB

load_pkgdb() {
  [ "$PKGDB_STATE" = loaded ] && return 0
  PKGDB_STATE=loaded

  # Arch: /var/lib/pacman/local/<pkg-version>/desc, a %FIELDS% file whose
  # %NAME% line names the package. grep reads all of them in one process, and
  # -A1 takes the line after the marker, which is the name itself. The `--`
  # lines grep puts between groups are filtered out along with the markers.
  if [ -d /var/lib/pacman/local ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && PKGDB["$n"]=1
    done < <(grep -hA1 -- '^%NAME%$' /var/lib/pacman/local/*/desc 2>/dev/null |
             grep -vE '^(%NAME%|--)$' || true)
    PKGDB_READABLE=1
  fi

  # Debian / Ubuntu: one flat file of stanzas, `Package:` starting each name.
  if [ -f /var/lib/dpkg/status ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && PKGDB["$n"]=1
    done < <(sed -n 's/^Package: //p' /var/lib/dpkg/status 2>/dev/null || true)
    PKGDB_READABLE=1
  fi

  # Alpine: another flat file, one `P:` line per installed package.
  if [ -f /lib/apk/db/installed ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && PKGDB["$n"]=1
    done < <(sed -n 's/^P://p' /lib/apk/db/installed 2>/dev/null || true)
    PKGDB_READABLE=1
  fi

  # Gentoo and Void keep one directory per installed package instead of a file:
  # /var/db/pkg/<category>/<name>-<version>/ and /var/db/xbps/<name>-<version>_rev.
  # Both encode the version as a trailing -<digit>… run, so everything from the
  # first such run onwards is dropped to recover the name. A name that itself
  # contains a hyphen followed by a digit is the one shape this gets wrong, and
  # the effect is only a miss on that single package.
  if [ -d /var/db/pkg ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && PKGDB["$n"]=1
    done < <(for d in /var/db/pkg/*/*/; do [ -d "$d" ] && printf '%s\n' "${d%/}"; done 2>/dev/null |
             sed 's|.*/||; s/-[0-9].*$//' || true)
    PKGDB_READABLE=1
  fi
  if [ -d /var/db/xbps ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && PKGDB["$n"]=1
    done < <(for d in /var/db/xbps/*/; do [ -d "$d" ] && printf '%s\n' "${d%/}"; done 2>/dev/null |
             sed 's|.*/||; s/-[0-9].*$//' || true)
    PKGDB_READABLE=1
  fi

  # Fedora / RHEL store the same set in a SQLite database, which is a binary
  # format and so cannot be grepped. Reading it needs sqlite3, which a minimal
  # Fedora install may not have; when it is absent PKGDB_READABLE stays as it is
  # and the package-level check reports itself as unverified rather than
  # answering from a database it could not read.
  if [ -f /var/lib/rpm/rpmdb.sqlite ] && command -v sqlite3 >/dev/null 2>&1; then
    while IFS= read -r n; do
      [ -n "$n" ] && PKGDB["$n"]=1
    done < <(sqlite3 /var/lib/rpm/rpmdb.sqlite 'SELECT name FROM Packages;' 2>/dev/null || true)
    PKGDB_READABLE=1
  fi
}

# True when the named package is recorded as installed. A system whose package
# database could not be read answers false, the same as a genuine absence, so a
# package-level check there lands in the normal "missing" path and is described
# as unverified by the caller rather than being silently treated as satisfied.
pkg_installed() {
  load_pkgdb
  [ -n "${PKGDB[$1]:-}" ]
}

# True when the package database is one we can actually read. Separate from
# pkg_installed so a manifest entry can distinguish "not installed" from "we
# have no way of knowing", which are very different things to print at someone.
pkgdb_readable() {
  load_pkgdb
  [ "$PKGDB_READABLE" -eq 1 ]
}

present() {
  case "$1" in
    bin)
      command -v "$2" >/dev/null 2>&1
      ;;
    pkgdb)
      # At least one of the named packages is installed, read from the local
      # package database. The one check form that needs no binary, no running
      # daemon and no path — the right tool for a dependency that exists only
      # as a set of files, such as a font or a kernel module package.
      local one
      for one in $2; do
        pkg_installed "$one" && return 0
      done
      return 1
      ;;
    bins)
      # Every listed binary must be present.
      local one
      for one in $2; do
        command -v "$one" >/dev/null 2>&1 || return 1
      done
      return 0
      ;;
    anyBin)
      # At least one alternative is enough.
      local one
      for one in $2; do
        if command -v "$one" >/dev/null 2>&1; then
          return 0
        fi
      done
      return 1
      ;;
    service)
      # A running systemd unit, for features gated on a daemon rather than on a
      # binary. Checking `is-active` is what the shell itself does for these, so
      # a dependency the shell will actually use is a dependency we report on.
      # Installed-but-not-running reads as missing on purpose: the feature is
      # just as unavailable, and the remedy (enable the unit) is what the report
      # should be pointing at.
      command -v systemctl >/dev/null 2>&1 || return 1
      systemctl is-active --quiet "$2" 2>/dev/null
      ;;
    path)
      # Any one pattern is enough, and each may contain a glob.
      #
      # This is where distribution independence actually matters. A dependency
      # delivered as a QML module has no executable, so `command -v` can never
      # find it and a filesystem path is the only option — but hardcoding one
      # absolute path would report every non-Arch user as missing something they
      # have, because the Qt module directory is not in the same place
      # everywhere: /usr/lib/qt6/qml on Arch, /usr/lib64/qt6/qml on Fedora,
      # /usr/lib/x86_64-linux-gnu/qt6/qml on Debian, elsewhere again under Nix.
      #
      # The any-of *list* is what covers those, because a glob cannot: in bash's
      # pathname expansion `*` stops at `/`, so `/usr/lib*/qt6/qml/Foo` reaches
      # Arch and Fedora but never Debian's extra `x86_64-linux-gnu` component.
      # Two patterns do: "/usr/lib*/qt6/qml/Foo /usr/lib/*/qt6/qml/Foo".
      #
      # A glob is still worth having, for the case where one distribution nests
      # the module under a version-suffixed directory of its own.
      local pat hit
      for pat in $2; do
        for hit in $(expand_path "$pat"); do
          [ -e "$hit" ] && return 0
        done
      done
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

missing_core_ids=""
missing_core_pkgs=""
missing_core_rows=""
missing_opt_ids=""
missing_opt_rows=""
missing_nudge_rows=""
missing_pkg_present=0
have_missing_opt=0
core_total=0
opt_total=0

# Why a check failed is not always the same thing. "The package is not
# installed" and "the package is installed but the thing I looked for is not
# where I looked" produce identical results from a binary or path check, and
# they call for opposite remedies: install the package, or fix $PATH. Telling
# them apart is what the package database is for, and it is a distinction worth
# making automatically because the wrong one produces advice that cannot work.
pkg_present_hint() {
  # $1 = space-separated package names, $2 = check kind. Empty = genuinely absent.
  #
  # The remedy depends on what kind of check failed, and a $PATH hint on a
  # systemd unit is worse than no hint: it sends someone to edit their PATH
  # when the real answer is "the daemon is stopped".
  [ -n "$1" ] || return 0
  p=""
  for p in $1; do
    if pkg_installed "$p"; then
      case "$2" in
        bin | bins | anyBin)
          printf '%s is installed, so the binary is probably just not on your $PATH' "$p" ;;
        service)
          printf '%s is installed, so the unit is present but not running — start it rather than reinstalling' "$p" ;;
        path)
          printf '%s is installed, but the expected path is absent — usually a package layout other than the one this manifest assumes' "$p" ;;
        *)
          printf '%s is installed, so what this checks for is present but not where it looked' "$p" ;;
      esac
      return 0
    fi
  done
  return 0
}

while IFS="$(printf '\t')" read -r section id why pkgs kind arg nudge; do
  [ -n "${id:-}" ] || continue
  if present "$kind" "$arg"; then
    continue
  fi
  # Not for pkgdb entries: those already consult the database, so a failure is
  # the absence being real and there is nothing left to disambiguate.
  hint=""
  if [ "$kind" != pkgdb ]; then
    hint=$(pkg_present_hint "$pkgs" "$kind")
    [ -n "$hint" ] && missing_pkg_present=1
  fi
  case "$section" in
    core)
      core_total=$((core_total + 1))
      missing_core_ids="$missing_core_ids$id
"
      missing_core_pkgs="$missing_core_pkgs$pkgs
"
      missing_core_rows="$missing_core_rows$id	$why	$pkgs	$kind	$arg	$hint
"
      ;;
    optional)
      opt_total=$((opt_total + 1))
      have_missing_opt=1
      missing_opt_ids="$missing_opt_ids$id
"
      missing_opt_rows="$missing_opt_rows$id	$why	$pkgs	$kind	$arg	$hint
"
      # `nudge` is the installer's narrower list: only the optional deps whose
      # absence is worth a line at install time. Kept here so the installer has
      # no list of its own to keep in sync.
      [ "$nudge" = "1" ] && missing_nudge_rows="$missing_nudge_rows$id	$why	$pkgs	$kind	$arg	$hint
"
      ;;
  esac
done < <(printf '%s\n' "$TSV")

[ -n "$missing_core_ids" ] && missing_core=1 || missing_core=0


# ---------------------------------------------------------------------------
# HTML report
#
# Generated locally and opened with xdg-open: no server, no network, works
# offline, and nothing to keep alive. Lives in the cache dir because it is
# derived data, regenerated on demand, and safe to lose.
#
# The path is fixed, so this is always one file that gets overwritten in place —
# repeated checks never accumulate copies, and the surface's "open report" link
# and the post-update path always point at the same artifact.
# ---------------------------------------------------------------------------

# One <li> per dependency. Shared by the required and optional sections, which
# render identically and previously carried their own copy of this markup.
dep_entry_rows() {
  while IFS="$(printf '\t')" read -r id why pkgs kind arg hint; do
    [ -n "$id" ] || continue
    printf '<li><div class="row"><span class="id">%s</span>' "$(esc "$id")"
    case "$kind" in
      bin) printf '<span class="tag">%s</span>' "$(esc "$arg")" ;;
      bins) printf '<span class="tag">%s</span>' "$(esc "${arg// / + }")" ;;
      anyBin) printf '<span class="tag">%s</span>' "$(esc "${arg// / | }")" ;;
      service) printf '<span class="tag">systemd: %s</span>' "$(esc "$arg")" ;;
      pkgdb) printf '<span class="tag">package: %s</span>' "$(esc "${arg// / | }")" ;;
      path) printf '<span class="tag">%s</span>' "$(esc "$arg")" ;;
    esac
    printf '</div><div class="why">%s</div>' "$(esc "$why")"
    # When the package is installed anyway, the reason this was reported is not
    # the one the rest of the page is about. Say so here, where the entry is,
    # because "install this" is the advice the page gives and it would not help.
    if [ -n "$hint" ]; then
      printf '<div class="hint">%s</div>' "$(esc "$hint")"
    fi
    printf '</li>\n'
  done
}

gen_page() {
  mkdir -p "$CACHE_DIR"
  local stamp
  stamp=$(date '+%F %T')

  # Group the missing packages into one install line, de-duplicated.
  local all_pkgs uniq_pkgs
  if [ "$missing_core" -eq 1 ]; then
    all_pkgs=$(printf '%s' "$missing_core_pkgs" | tr ' ' '\n' | grep -v '^$')
  else
    all_pkgs=""
  fi
  if [ "$have_missing_opt" -eq 1 ]; then
    all_pkgs="$all_pkgs
$(printf '%s' "$missing_opt_rows" | cut -f3 | tr ' ' '\n' | grep -v '^$')"
  fi
  uniq_pkgs=$(printf '%s' "$all_pkgs" | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ $//')

  {
    cat <<'HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ukishima — dependencies</title>
<style>
  :root {
    --bg: #14100e; --panel: #1c1714; --ink: #ececec; --sub: #a8a8a8;
    --faint: #6a6a6a; --verm: #e0563b; --verm-deep: #a3371f; --ok: #7fa650;
    --hair: rgba(236,236,236,0.09);
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 40px 20px 64px; background: var(--bg); color: var(--ink);
    font: 15px/1.6 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  main { max-width: 720px; margin: 0 auto; }
  h1 { font-size: 22px; font-weight: 650; margin: 0 0 4px; letter-spacing: -0.01em; }
  h2 { font-size: 13px; font-weight: 600; text-transform: uppercase;
       letter-spacing: 0.08em; color: var(--faint); margin: 34px 0 12px; }
  .sub { color: var(--sub); font-size: 14px; margin: 0 0 4px; }
  .banner { border: 1px solid var(--verm-deep); background: rgba(224,86,59,0.09);
            border-radius: 10px; padding: 12px 14px; margin: 18px 0 4px;
            color: var(--ink); font-size: 14px; }
  .banner.ok { border-color: rgba(127,166,80,0.45); background: rgba(127,166,80,0.09); }
  .banner strong { color: var(--verm); font-weight: 650; }
  .banner.ok strong { color: var(--ok); }
  ul { list-style: none; margin: 0; padding: 0; }
  li { border: 1px solid var(--hair); background: var(--panel); border-radius: 10px;
       padding: 12px 14px; margin-bottom: 8px; }
  .row { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
  .id { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 13px;
        font-weight: 600; }
  .tag { font-size: 11px; padding: 1px 7px; border-radius: 999px;
         border: 1px solid var(--hair); color: var(--faint); }
  .why { color: var(--sub); font-size: 13.5px; margin-top: 4px; }
  /* Set only when the dependency's package is installed and the check still
     failed, i.e. when the page's install command would not actually help. */
  .hint { color: var(--verm); font-size: 13px; margin-top: 4px; }
  pre { background: #100c0a; border: 1px solid var(--hair); border-radius: 8px;
        padding: 11px 13px; overflow-x: auto; font-size: 13px; margin: 12px 0 0;
        font-family: ui-monospace, "SF Mono", Menlo, monospace; color: var(--ink); }
  code { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 13px; }
  footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid var(--hair);
           color: var(--faint); font-size: 12.5px; }
  .path { color: var(--faint); font-size: 12px; }
</style>
</head>
<body>
<main>
HEAD

    printf '<h1>Ukishima &mdash; dependencies</h1>\n'
    if [ "$missing_core" -eq 1 ]; then
      printf '<p class="sub">Some things the shell needs are not installed.</p>\n'
      n=$(printf '%s' "$missing_core_ids" | grep -c .)
      printf '<div class="banner"><strong>%s required</strong> missing &mdash; the affected features will not work until %s installed.</div>\n' \
        "$n" "$( [ "$n" -eq 1 ] && printf 'it is' || printf 'they are' )"
    else
      printf '<p class="sub">Everything the shell requires is installed.</p>\n'
      printf '<div class="banner ok"><strong>No required dependencies missing.</strong> Anything listed further down is optional and only adds features.</div>\n'
    fi

    if [ "$missing_core" -eq 1 ]; then
      printf '<h2>Missing &mdash; required</h2>\n<ul>\n'
      printf '%s' "$missing_core_rows" | dep_entry_rows
      printf '</ul>\n'
    fi

    if [ "$have_missing_opt" -eq 1 ]; then
      printf '<h2>Missing &mdash; optional</h2>\n'
      printf '<p class="sub">These only add features. Nothing breaks without them.</p>\n<ul>\n'
      printf '%s' "$missing_opt_rows" | dep_entry_rows
      printf '</ul>\n'
    fi

    if [ -n "$uniq_pkgs" ]; then
      printf '<h2>Install</h2>\n'
      # Names were resolved for the package manager this system actually has,
      # using each entry's pkgAlt override where the manifest supplies one.
      printf '<pre><code>%s</code></pre>\n' "$(esc "$(install_cmd "$uniq_pkgs")")"
      # The caveat only earns its place off Arch, where a name can still differ
      # from what this system's repository calls it.
      if [ -n "$PM_ID" ] && [ "$PM_ID" != pacman ]; then
        printf '<p class="sub">Names resolved for <code>%s</code>. If one does not exist in your repositories, install the equivalent &mdash; the <code>why</code> line on each entry says what provides it.</p>\n' \
          "$(esc "$PM_ID")"
      fi
    fi

    printf '<footer>Generated %s from <span class="path">%s</span>.<br>Re-check at any time with <code>scripts/check-deps.sh</code>, or from the pill under Appearance &rarr; Update.</footer>\n' \
      "$(esc "$stamp")" "$(esc "$MANIFEST")"
    printf '</main>\n</body>\n</html>\n'
  } >"$PAGE"

  printf '%s' "$PAGE"
}

# ---------------------------------------------------------------------------
# output modes
# ---------------------------------------------------------------------------

if [ "$as_json" -eq 1 ]; then
  # Consumed by the in-app manual check. One line, so the caller can parse the
  # whole stdout without buffering line-by-line.
  missing_core_json=""
  # Full records, not bare ids: the in-app list renders the id, the reason and
  # the package to install, and a notification or one summary line cannot carry
  # that. jq does the escaping, so a `why` containing quotes stays valid JSON.
  jq -n --slurpfile man "$MANIFEST" --arg core "$missing_core_ids" \
         --arg opt "$missing_opt_ids" --arg page "$PAGE" '
    $man[0] as $m
    | def recs($ids; $arr):
        [ $ids | split("\n")[] | select(length > 0) as $id
          | ($arr[] | select(.id == $id))
          | {id: .id, why: .why, pkg: .pkg} ];
      {
        ok: ($core | split("\n") | map(select(length > 0)) | length) == 0,
        missingCore: recs($core; ($m.core // [])),
        missingOptional: recs($opt; ($m.optional // [])),
        page: $page
      }'
  exit 0
fi

if [ "$install_mode" -eq 1 ]; then
  # remote-install.sh's exact wording, produced from the manifest so the
  # installer's report and the post-update report cannot describe different
  # dependency sets. The installer keeps the red summary footer.
  if [ "$missing_core" -eq 1 ]; then
    printf '%s' "$missing_core_rows" | while IFS="$(printf '\t')" read -r id why pkgs kind arg hint; do
      [ -n "$id" ] || continue
      printf '  \033[1;33mmissing: %s (%s)\033[0m\n' "$why" "$pkgs"
      [ -n "$hint" ] && printf '  \033[1;31mnote: %s\033[0m\n' "$hint"
    done
  fi
  if [ -n "$missing_nudge_rows" ]; then
    printf '%s' "$missing_nudge_rows" | while IFS="$(printf '\t')" read -r id why pkgs kind arg hint; do
      [ -n "$id" ] || continue
      printf '  \033[1;33moptional: %s\033[0m\n' "$id"
    done
  fi
  [ "$missing_core" -eq 1 ] && exit 1
  exit 0
fi

if [ "$do_report" -eq 0 ] && [ "$open_page" -eq 0 ]; then
  # Plain report. This is also what a human runs to see where they stand.
  if [ "$missing_core" -eq 1 ]; then
    printf '\033[1;31mMissing required dependencies:\033[0m\n'
    printf '%s' "$missing_core_rows" | while IFS="$(printf '\t')" read -r id why pkgs kind arg hint; do
      [ -n "$id" ] || continue
      printf '  %-24s %s  \033[1;33m(%s)\033[0m\n' "$id" "$why" "$pkgs"
      [ -n "$hint" ] && printf '  %-24s \033[1;31mnote: %s\033[0m\n' "" "$hint"
    done
  else
    printf '\033[1;32mAll required dependencies are present.\033[0m\n'
  fi
  if [ "$show_all" -eq 1 ] && [ "$have_missing_opt" -eq 1 ]; then
    printf '\n\033[1;33mOptional, missing:\033[0m\n'
    printf '%s' "$missing_opt_rows" | while IFS="$(printf '\t')" read -r id why pkgs kind arg hint; do
      [ -n "$id" ] || continue
      printf '  %-24s %s  \033[1;33m(%s)\033[0m\n' "$id" "$why" "$pkgs"
      [ -n "$hint" ] && printf '  %-24s \033[1;31mnote: %s\033[0m\n' "" "$hint"
    done
  fi
  [ "$missing_core" -eq 1 ] && exit 1
  exit 0
fi

# ---------------------------------------------------------------------------
# notify / page
#
# The post-update path. Deliberately quiet: the user pulled an update, and the
# only thing worth interrupting them for is a requirement that update introduced.
# A missing core dependency is worth a notification and a page; a missing
# optional one is not worth either, since every optional feature is documented
# to degrade and surfacing them here would just be noise on a bare profile.
# ---------------------------------------------------------------------------

if [ "$missing_core" -eq 0 ]; then
  if [ "$open_page" -eq 1 ]; then
    # Explicitly asked for the page, so show it even when everything is present.
    p=$(gen_page)
    command -v xdg-open >/dev/null 2>&1 && xdg-open "file://$p" >/dev/null 2>&1 || true
  fi
  exit 0
fi

# The post-update path: write the report and open it, and nothing else.
#
# This used to raise a desktop notification as well, with a signature of the
# missing set stored under XDG_STATE_HOME so an unfixed dependency would not
# re-notify on every login. Both are gone. A popup is a poor fit for this: it
# arrives whether or not anyone is looking, it cannot carry a list, and the
# surface already re-checks itself every time it is opened, so the answer is one
# click away whenever it is actually wanted. Opening the report keeps the
# information reachable without imposing it.
if [ "$do_report" -eq 1 ] || [ "$open_page" -eq 1 ]; then
  p=$(gen_page)
  command -v xdg-open >/dev/null 2>&1 && xdg-open "file://$p" >/dev/null 2>&1 || true
fi

exit 0
