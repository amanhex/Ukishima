#!/usr/bin/env bash
# Report missing Ukishima dependencies. The list lives in dependencies.json;
# entries tagged with a compositor are only checked on that session.
set -eu

SELF=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF/wm.sh"
MANIFEST="${UKISHIMA_MANIFEST:-$(dirname -- "$SELF")/dependencies.json}"
: "${HOME:=/tmp}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima"
PAGE="$CACHE/deps.html"

usage() {
  cat <<'EOF'
usage: check-deps.sh [--all] [--json] [--install] [--page] [--report]

  --all      also list missing optional dependencies
  --json     machine-readable verdict
  --install  installer report; exit 1 if a required dependency is missing
  --page     open the HTML report
  --report   open the HTML report only when a required dependency is missing
EOF
}

mode=text
show_all=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all) show_all=1 ;;
    --json) mode=json ;;
    --install) mode=install ;;
    --page) mode=page ;;
    --report) mode=report ;;
    -h | --help) usage; exit 0 ;;
    *) printf 'check-deps: unknown option %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || {
  printf 'check-deps: jq is required to read %s\n' "$MANIFEST" >&2
  exit 2
}
[ -r "$MANIFEST" ] && jq -e . "$MANIFEST" >/dev/null 2>&1 || {
  printf 'check-deps: cannot read %s\n' "$MANIFEST" >&2
  exit 2
}

# Arch package names are the default; pkgAlt overrides them for other managers.
pm=""
for candidate in pacman apt-get dnf zypper apk xbps-install emerge brew; do
  if command -v "$candidate" >/dev/null 2>&1; then
    pm=$candidate
    break
  fi
done
install_cmd() {
  case "$pm" in
    pacman) printf 'sudo pacman -S %s' "$1" ;;
    apt-get) printf 'sudo apt-get install %s' "$1" ;;
    dnf) printf 'sudo dnf install %s' "$1" ;;
    zypper) printf 'sudo zypper install %s' "$1" ;;
    apk) printf 'sudo apk add %s' "$1" ;;
    xbps-install) printf 'sudo xbps-install -S %s' "$1" ;;
    emerge) printf 'sudo emerge %s' "$1" ;;
    brew) printf 'brew install %s' "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

rows=$(jq -r --arg wm "$UKISHIMA_WM" --arg pm "$pm" '
  def flat($v): if ($v | type) == "array" then ($v | join(" "))
                elif ($v | type) == "string" then $v
                else "" end;
  def arg($c): if ($c.bin?) then flat($c.bin)
               elif ($c.bins?) then flat($c.bins)
               elif ($c.anyBin?) then flat($c.anyBin)
               elif ($c.service?) then flat($c.service)
               elif ($c.path?) then flat($c.path)
               else "" end;
  def kind($c): if ($c.bin?) then "bin"
                elif ($c.bins?) then "bins"
                elif ($c.anyBin?) then "anyBin"
                elif ($c.service?) then "service"
                elif ($c.path?) then "path"
                else "" end;
  def pkgs($e): (($e.pkgAlt[$pm] // $e.pkg) // []) | join(" ");
  ( .core[]?     | select((.compositor // "shared") == "shared" or .compositor == $wm)
                 | ["core", .id, .why, pkgs(.), kind(.check), arg(.check), "0"] ),
  ( .optional[]? | select((.compositor // "shared") == "shared" or .compositor == $wm)
                 | ["optional", .id, .why, pkgs(.), kind(.check), arg(.check),
                    (if .nudge then "1" else "0" end)] )
  | join("\u001f")' "$MANIFEST") || {
  printf 'check-deps: cannot read entries from %s\n' "$MANIFEST" >&2
  exit 2
}

present() {
  case "$1" in
    bin) command -v "$2" >/dev/null 2>&1 ;;
    bins)
      for one in $2; do command -v "$one" >/dev/null 2>&1 || return 1; done
      ;;
    anyBin)
      for one in $2; do command -v "$one" >/dev/null 2>&1 && return 0; done
      return 1
      ;;
    service)
      command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$2" 2>/dev/null
      ;;
    path)
      for one in $2; do [ -e "$one" ] && return 0; done
      return 1
      ;;
    *) return 1 ;;
  esac
}

core_rows=""
opt_rows=""
nudge_rows=""
core_ids=""
opt_ids=""
core_pkgs=""
while IFS=$'\x1f' read -r section id why pkgs kind arg nudge; do
  [ -n "$id" ] || continue
  present "$kind" "$arg" && continue
  case "$section" in
    core)
      core_ids="$core_ids$id"$'\n'
      core_pkgs="$core_pkgs $pkgs"
      core_rows="$core_rows$id"$'\x1f'"$why"$'\x1f'"$pkgs"$'\n'
      ;;
    optional)
      opt_ids="$opt_ids$id"$'\n'
      opt_rows="$opt_rows$id"$'\x1f'"$why"$'\x1f'"$pkgs"$'\n'
      if [ "$nudge" = 1 ]; then
        nudge_rows="$nudge_rows$id"$'\x1f'"$why"$'\n'
      fi
      ;;
  esac
done <<< "$rows"

print_rows() {
  while IFS=$'\x1f' read -r id why pkgs; do
    [ -n "$id" ] || continue
    printf '  %-22s %s (%s)\n' "$id" "$why" "$pkgs"
  done
}

esc() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

html_rows() {
  local label=$1 class=$2
  while IFS=$'\x1f' read -r id why pkgs; do
    [ -n "$id" ] || continue
    printf '<li><div class="row"><span class="id">%s</span><span class="tag %s">%s</span></div><div class="why">%s</div><div class="pkgs"><code>%s</code></div></li>\n' \
      "$(esc "$id")" "$class" "$label" "$(esc "$why")" "$(esc "$pkgs")"
  done
}

gen_page() {
  mkdir -p "$CACHE" || return 1
  local stamp
  stamp=$(date '+%F %T')
  {
    cat <<'HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ukishima &mdash; dependencies</title>
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
  .tag.req { color: var(--verm); border-color: rgba(224,86,59,0.35);
             background: rgba(224,86,59,0.08); }
  .why { color: var(--sub); font-size: 13.5px; margin-top: 4px; }
  .pkgs { color: var(--faint); font-size: 12px; margin-top: 6px; }
  .pkgs code { color: var(--sub); }
  pre { background: #100c0a; border: 1px solid var(--hair); border-radius: 8px;
        padding: 11px 13px; overflow-x: auto; font-size: 13px; margin: 12px 0 0;
        font-family: ui-monospace, "SF Mono", Menlo, monospace; color: var(--ink); }
  code { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 13px; }
  footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid var(--hair);
           color: var(--faint); font-size: 12.5px; }
  .path { color: var(--faint); font-size: 12px; }
  @media (max-width: 520px) {
    body { padding: 24px 14px 40px; }
    h1 { font-size: 20px; }
    li { padding: 11px 12px; }
  }
</style>
</head>
<body>
<main>
HEAD

    printf '<h1>Ukishima &mdash; dependencies</h1>\n'
    if [ -n "$core_rows" ]; then
      n=$(printf '%s' "$core_rows" | grep -c .)
      printf '<p class="sub">Some things the shell needs are not installed.</p>\n'
      printf '<div class="banner"><strong>%s required</strong> missing &mdash; the affected features will not work until they are installed.</div>\n' "$n"
    else
      printf '<p class="sub">Everything the shell requires is installed.</p>\n'
      printf '<div class="banner ok"><strong>No required dependencies missing.</strong> Anything listed further down is optional and only adds features.</div>\n'
    fi
    if [ -n "$core_rows" ]; then
      printf '<h2>Missing &mdash; required</h2>\n<ul>\n'
      printf '%s' "$core_rows" | html_rows Required req
      printf '</ul>\n'
    fi
    if [ -n "$opt_rows" ]; then
      printf '<h2>Missing &mdash; optional</h2>\n'
      printf '<p class="sub">These only add features. Nothing breaks without them.</p>\n<ul>\n'
      printf '%s' "$opt_rows" | html_rows Optional opt
      printf '</ul>\n'
    fi
    pkgs=$(printf '%s\n' $core_pkgs | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$pkgs" ]; then
      printf '<h2>Install</h2>\n'
      printf '<pre><code>%s</code></pre>\n' "$(esc "$(install_cmd "$pkgs")")"
    fi
    printf '<footer>Generated %s from <span class="path">%s</span>.<br>Re-check at any time with <code>scripts/check-deps.sh</code>, or from the pill under Settings &rarr; Update.</footer>\n' \
      "$(esc "$stamp")" "$(esc "$MANIFEST")"
    printf '</main>\n</body>\n</html>\n'
  } > "$PAGE"
  printf '%s' "$PAGE"
}

if [ "$mode" = json ]; then
  jq -n --slurpfile man "$MANIFEST" --arg core "$core_ids" --arg opt "$opt_ids" \
    --arg page "$PAGE" '
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

if [ "$mode" = install ]; then
  if [ -n "$core_rows" ]; then
    printf '%s' "$core_rows" | while IFS=$'\x1f' read -r id why pkgs; do
      [ -n "$id" ] || continue
      printf '  \033[1;33mmissing: %s (%s)\033[0m\n' "$why" "$pkgs"
    done
  fi
  if [ -n "$nudge_rows" ]; then
    printf '%s' "$nudge_rows" | while IFS=$'\x1f' read -r id why; do
      [ -n "$id" ] || continue
      printf '  \033[1;33moptional: %s\033[0m\n' "$id"
    done
  fi
  if [ -n "$core_pkgs" ]; then
    pkgs=$(printf '%s\n' $core_pkgs | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//')
    printf '  install required packages with: %s\n' "$(install_cmd "$pkgs")"
  fi
  [ -n "$core_rows" ] && exit 1
  exit 0
fi

if [ "$mode" = page ] || [ "$mode" = report ]; then
  if [ "$mode" = page ] || [ -n "$core_rows" ]; then
    page=$(gen_page) || exit 2
    command -v xdg-open >/dev/null 2>&1 && xdg-open "file://$page" >/dev/null 2>&1 || true
  fi
  exit 0
fi

if [ -n "$core_rows" ]; then
  printf '\033[1;31mMissing required dependencies:\033[0m\n'
  printf '%s' "$core_rows" | print_rows
else
  printf '\033[1;32mAll required dependencies are present.\033[0m\n'
fi
if [ "$show_all" -eq 1 ] && [ -n "$opt_rows" ]; then
  printf '\n\033[1;33mOptional, missing:\033[0m\n'
  printf '%s' "$opt_rows" | print_rows
fi
[ -n "$core_rows" ] && exit 1
exit 0
