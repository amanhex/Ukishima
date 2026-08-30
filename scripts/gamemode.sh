#!/usr/bin/env bash
# Game-mode Hyprland strip: `on` quiets the compositor for a game, `off`
# restores it. No hyprland.conf / hyprland.lua is ever edited — everything is
# a live, session-scoped override, so a `hyprctl reload` or Hyprland restart
# drops the strip by itself.
#
# The originals are snapshotted to the user state dir next to flags.json
# before the strip and replayed verbatim on `off`, so:
#   * a user who already runs without animations/blur gets exactly that back,
#     not a set of presumed defaults forced "on"; and
#   * if the pill restarts while game mode is on, re-entering `on` re-applies
#     the strip instead of overwriting the snapshot (originals survive).
#
# Forward-compatible on purpose:
#   * nothing depends on the user's config file at all. What differs between
#     users is the language their Hyprland accepts for live changes: newer
#     builds speak `hyprctl eval 'hl.config(...)'`, older ones speak the
#     legacy `hyprctl keyword`. The script asks the running compositor which
#     one *it* speaks (probing the binary, never the config), and whenever a
#     key is rejected by one engine it transparently retries with the other —
#     so a lua user, a conf user, and any future variant all work unchanged.
#   * every key is applied in its own call after being probed, so an option
#     that is renamed or removed in a future Hyprland is skipped on its own,
#     and a missing hyprctl, jq (used only as a read fallback) or `timeout`
#     degrades instead of dying.
#   * extra keys can be layered in without editing the file via
#     UKISHIMA_GAMEMODE_EXTRA (one `option=value` per line).

cmd_hyprctl="$(command -v hyprctl 2>/dev/null || true)"
[ -n "$cmd_hyprctl" ] || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima"
state="$state_dir/gamemode.state"

# option=value targets applied while game mode is on.
strips="
animations:enabled=false
decoration:blur:enabled=false
decoration:active_opacity=1.0
decoration:inactive_opacity=1.0
decoration:dim_inactive=false
decoration:rounding=0
misc:disable_hyprland_logo=true
"
if [ -n "${UKISHIMA_GAMEMODE_EXTRA:-}" ]; then
    strips="$strips"$'\n'"$UKISHIMA_GAMEMODE_EXTRA"
fi

run_hyprctl() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 3 "$cmd_hyprctl" "$@"
    else
        "$cmd_hyprctl" "$@"
    fi
}

# Hyprland >= 0.55 dropped the keyword parser in favor of Lua. Probe the live
# compositor once to learn its language; if a key is ever rejected by that
# engine, apply_one retries it with the other one.
lua=0
if [ "$(run_hyprctl repl 'return type(hl.config)' 2>&1)" = function ]; then
    lua=1
fi

# Current value of an option as a bare scalar, or nothing when the option is
# gone/unknown. Prefers the plain ("bool: true") report so it never depends on
# jq, and only falls back to the -j JSON report when the plain form is gone —
# a future hyprctl format change degrades to a per-key skip, never a failure.
get_value() {
    local out
    out="$(run_hyprctl getoption "$1" 2>/dev/null)" || return 1
    out="$(printf '%s\n' "$out" | sed -n '1{/^[A-Za-z][A-Za-z]*: /s/^[A-Za-z][A-Za-z]*: //p}')"
    if [ -z "$out" ]; then
        out="$(run_hyprctl getoption "$1" -j 2>/dev/null)" || return 1
        case "$out" in
            \{*)
                command -v jq >/dev/null 2>&1 || return 1
                out="$(printf '%s' "$out" | jq -r 'if has("bool") then .bool elif has("float") then .float elif has("int") then .int elif has("str") then .str else empty end' 2>/dev/null)" || return 1
                ;;
            *) out="" ;;
        esac
    fi
    [ -n "$out" ] || return 1
    printf '%s' "$out"
}

# Render a bare scalar for embedding into a Lua table: booleans and numbers
# stay bare, anything else (strings) is quoted with escapes.
lua_val() {
    case "$1" in
        true|false|''|*[!0-9.eE+-]*)
            if [ "$1" = true ] || [ "$1" = false ]; then
                printf '%s' "$1"
            else
                printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
            fi
            ;;
        *)
            printf '%s' "$1" ;;
    esac
}

# Apply one key with its value through whichever engine the running
# Hyprland accepts, falling back to the other engine per key on rejection.
apply_one() {
    [ -n "$1" ] || return 0
    if [ "$lua" = 1 ]; then
        local lk="${1//:/\.}"
        if run_hyprctl eval "hl.config({[\"$lk\"]=$(lua_val "$2")})" >/dev/null 2>&1; then
            return 0
        fi
    fi
    run_hyprctl keyword "$1" "$2" >/dev/null 2>&1 || true
}

case "${1:-}" in
    on)
        mkdir -p "$state_dir" 2>/dev/null || true
        # First line of the state file is "active" while the strip is running.
        # A previous pill that died mid-game leaves it active: keep those
        # originals (tail) untouched and only re-apply the strip.
        keep=""
        keep_keys=""
        if [ -f "$state" ] && [ "$(head -n 1 "$state" 2>/dev/null)" = active ]; then
            keep="$(tail -n +2 "$state" 2>/dev/null)"
            keep_keys="$(printf '%s\n' "$keep" | cut -f 1)"
        fi
        new="$state_dir/.gamemode.$$"
        printf 'active\n' > "$new"
        [ -n "$keep" ] && printf '%s\n' "$keep" >> "$new"

        count=0
        while IFS='=' read -r key want; do
            [ -n "$key" ] || continue
            # Strip targets already in the kept snapshot lose their originals to
            # a strip-list change while game mode is active — snapshot them too.
            if [ -n "$keep_keys" ] && printf '%s\n' "$keep_keys" | grep -Fqx "$key"; then
                apply_one "$key" "$want"
                continue
            fi
            val="$(get_value "$key")" || continue
            printf '%s\t%s\n' "$key" "$val" >> "$new"
            count=$((count + 1))
            apply_one "$key" "$want"
        done <<< "$strips"

        if [ -z "$keep" ] && [ "$count" -eq 0 ]; then
            rm -f "$new"                     # nothing is restorable; stay silent
        else
            mv -f "$new" "$state" 2>/dev/null || rm -f "$new"
        fi
        ;;
    off)
        if [ ! -f "$state" ]; then
            # No snapshot to restore from (crash, manual wipe, first run):
            # don't leave the strip stuck — force the compositor back to its
            # config. Only used as an emergency fallback; the normal path
            # below restores each key to its exact pre-game value instead.
            run_hyprctl reload >/dev/null 2>&1 || true
            exit 0
        fi
        tail -n +2 "$state" | while IFS="$(printf '\t')" read -r key val; do
            [ -n "$key" ] || continue
            apply_one "$key" "$val"
        done
        rm -f "$state"
        ;;
esac
exit 0