#!/bin/sh
# Ukishima session lock.
#
# One script, compositor-supported locks. The pill's power menu, a keybind and hypridle all call
# this; which lock you get is the `lockMethod` flag in the ukishima flags.json
# (the same file the shell writes), so the pill and any keybind stay in sync:
#
#   Hyprland: "hyprlock" or "quickshell"
#   niri:     "swaylock" or "quickshell"
#   Quickshell failures fall back only to the active compositor's external lock.
#
# It used to be two scripts. lock.sh was hyprlock-only; lock-qs.sh was an opt-in
# alternative you picked by pointing `lock_cmd` at one or the other; and adding
# the flag later folded that choice in here — which left lock-qs.sh behind as a
# second front door whose own header still told you to point your idle locker
# at it and thereby skip the flag, the probe and the guard below. Two entry
# points for one decision is the same shape of mistake as the one the guard
# exists to prevent. There is one entry point now.
#
# "hyprlock" is a hand-off, not a mode Ukishima configures. The repo ships no
# hyprlock.conf and generates none, so choosing it discards every visual
# setting on the LOCK surface — background, blur, avatar, indicators — in
# favour of the user's own hyprlock.conf. It is also an external dependency
# that may simply not be installed, so it is probed before use rather than
# exec'd on faith. That probe used to be missing, which meant a machine
# without hyprlock ran `exec hyprlock`, got exit 127, and sat there unlocked.
#
# A missing hyprlock is never a reason to leave the session unlocked. The
# Quickshell lock needs nothing beyond Quickshell itself, so a request for
# hyprlock that cannot be honoured is downgraded to it, and the downgrade is
# logged, not failed. Only when neither exists is this a real failure, and
# then it says so on stderr.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima"
LOG="$CACHE_DIR/lock.log"
# JPEG, not PNG. The backdrop is drawn blurred and then never looked at
# closely, so PNG's lossless encode buys nothing and costs a great deal:
# measured here across two outputs, ~830ms and 1.3 MB for PNG against ~50ms
# and 290 KB for JPEG at q90. That gap is why the capture used to arrive late.
SHOT="$CACHE_DIR/lock-shot.jpg"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/wm.sh"
LOCK_QML="$SCRIPT_DIR/../lockscreen/shell.qml"
mkdir -p "$CACHE_DIR" 2>/dev/null

note() {
    mkdir -p "$CACHE_DIR" 2>/dev/null
    echo "$(date '+%F %T'): $*" >>"$LOG"
}

METHOD="hyprlock"
FLAGS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima/flags.json"
if [ -f "$FLAGS_FILE" ]; then
    val=$(sed -n 's/.*"lockMethod"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FLAGS_FILE" | head -1)
    [ -n "$val" ] && METHOD="$val"
fi

QS_BIN="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null)"
have_hyprlock=0
have_swaylock=0
if [ "$UKISHIMA_WM" = hyprland ] && command -v hyprlock >/dev/null 2>&1; then
    have_hyprlock=1
elif [ "$UKISHIMA_WM" = niri ] && command -v swaylock >/dev/null 2>&1; then
    have_swaylock=1
fi

# A stale choice from another compositor resolves safely without rewriting the
# user's preference, so it can become active again when they switch back.
case "$UKISHIMA_WM:$METHOD" in
    niri:hyprlock)
        note "saved hyprlock choice is unsupported on niri; using the Quickshell lock"
        METHOD=quickshell
        ;;
    niri:swaylock)
        if [ "$have_swaylock" -ne 1 ]; then
            note "swaylock was selected but is not installed; using the Quickshell lock"
            echo "lock.sh: swaylock is selected but not installed; using the Quickshell lock" >&2
            METHOD=quickshell
        fi
        ;;
    hyprland:swaylock)
        note "saved swaylock choice is unsupported on Hyprland; using the Quickshell lock"
        METHOD=quickshell
        ;;
    generic:hyprlock | generic:swaylock)
        note "saved $METHOD choice is unsupported on this compositor; using the Quickshell lock"
        METHOD=quickshell
        ;;
esac
# Ask the running compositor whether it is still there, instead of assuming
# Hyprland: hyprctl exists on a niri box but cannot answer. Used only on the
# signal-death path, where a dead compositor means there is nothing left to
# protect and re-locking would only stack a surface on a teardown.
compositor_gone() {
    if [ "$UKISHIMA_WM" = hyprland ] && command -v hyprctl >/dev/null 2>&1; then
        ! hyprctl version >/dev/null 2>&1
    elif [ "$UKISHIMA_WM" = niri ] && command -v niri >/dev/null 2>&1; then
        ! niri msg version >/dev/null 2>&1
    else
        return 1
    fi
}
# The Quickshell lock needs both halves: a Quickshell to run and the config to
# run it against. Probing only for one of them was how "quickshell" could be
# selected on a machine that had neither.
have_qs=0
[ -n "$QS_BIN" ] && [ -f "$LOCK_QML" ] && have_qs=1

# Only one process can hold the Wayland session lock, so a second hyprlock can
# never improve on a first: it either fails to take the lock, or stacks an
# identical surface behind the live one where no dismiss can reach it. Either
# way it never exits, and each instance parks ~167 MiB of renderer for the rest
# of the session -- 34 of them were once resident here, 5.5 GiB total.
#
# `exec` preserves the pid, so writing $$ before handing over names the exact
# process this script started. A live recorded pid means the session is already
# locked and the request is a no-op; anything else is stale bookkeeping.
#
# Every failure path below still locks. Leaving the session unlocked to save
# 167 MiB would be the wrong trade, so the guard fails open at each step.
PIDFILE="$CACHE_DIR/hyprlock.pid"

hyprlock_is_live() {
    [ -f "$PIDFILE" ] || return 1
    pid=$(cat "$PIDFILE" 2>/dev/null)
    case "$pid" in '' | *[!0-9]*) return 1 ;; esac
    kill -0 "$pid" 2>/dev/null || return 1
    # A recycled pid must not read as "locked": confirm it is really hyprlock.
    [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = "hyprlock" ] || return 1
    return 0
}

# Reap instances this script did not start. Only reached on the path where a
# fresh lock is being taken, so a stray that happens to hold the lock is
# replaced within the same request instead of being left to linger.
reap_stray_hyprlocks() {
    command -v pkill >/dev/null 2>&1 || return 0
    strays=$(pgrep -x hyprlock 2>/dev/null | wc -l)
    if [ "$strays" -gt 0 ]; then
        pkill -x hyprlock 2>/dev/null
        sleep 0.3
        note "reaped $strays stray hyprlock instance(s) from an earlier lock request"
    fi
    return 0
}

run_hyprlock() {
    if hyprlock_is_live; then
        note "hyprlock already running (pid $(cat "$PIDFILE" 2>/dev/null)) -> session is already locked, not spawning another"
        exit 0
    fi
    rm -f "$PIDFILE"
    reap_stray_hyprlocks
    mkdir -p "$CACHE_DIR" 2>/dev/null
    echo $$ >"$PIDFILE"
    exec hyprlock
}

run_swaylock() {
    note "method=swaylock -> swaylock"
    exec swaylock
}

run_external_fallback() {
    if [ "$UKISHIMA_WM" = hyprland ] && [ "$have_hyprlock" -eq 1 ]; then
        note "Quickshell lock unavailable or failed -> hyprlock"
        run_hyprlock
    elif [ "$UKISHIMA_WM" = niri ] && [ "$have_swaylock" -eq 1 ]; then
        note "Quickshell lock unavailable or failed -> swaylock"
        run_swaylock
    fi
    return 1
}

# The Quickshell lock. Returns only on failure; every other outcome exits or
# execs, so the compositor-supported external-locker fallback below is reached
# session still needs protecting.
run_quickshell_lock() {
    note "starting $QS_BIN -p $LOCK_QML"

    # Pre-capture the desktop, the way hyprlock's `path = screenshot` does.
    # grim has to finish BEFORE the lock covers the screen: a ScreencopyView
    # inside ext-session-lock is racy on Hyprland/NVIDIA and usually comes
    # back empty or torn.
    #
    # It now also finishes before quickshell is *spawned*, which is the whole
    # fix for a lock that felt slow. This used to run grim concurrently with
    # quickshell's startup so the session would lock without waiting on the
    # encode, on the reasoning that a foreground grim cost ~450ms with the
    # desktop still interactive. That number was a PNG encode; as JPEG the
    # same two-output capture measures ~50ms, far less than the ~271ms the
    # lockscreen process then spends parsing QML before it can show anything.
    # Paying ~50ms to have the picture already on disk when the first frame is
    # mapped costs less wall-clock than overlapping the two did, and it removes
    # the failure the overlap created: the surface came up before the file
    # existed, so LockSurface polled a half-written PNG, re-read it on a 25ms
    # timer, latched status=Error on every truncated attempt and needed 13
    # tries and ~300ms to attach (see the "capture attached after 300ms
    # (attempt 13)" line in the log). The screen showed the wallpaper first and
    # cross-faded to the screenshot after, which is the visible stall.
    #
    # Ordering it this way also means the screenshot cannot contain the lock
    # surface itself, which is inherent to capturing after the lock is up.
    #
    # The old file is removed first so a capture that never arrives cannot be
    # mistaken for a fresh one — otherwise a screenshot from an hour ago would
    # silently appear.
    rm -f "$SHOT"
    if command -v grim >/dev/null 2>&1; then
        # grim hangs rather than failing when an output is powered off, and
        # this now runs on the critical path, so a hang would stop the lock
        # from ever being requested. Cap it and carry on without a backdrop.
        if ! timeout 3 grim -t jpeg -q 90 "$SHOT" >>"$LOG" 2>&1; then
            note "grim failed or timed out (rc=$?), continuing without pre-capture"
            rm -f "$SHOT"
        fi
    else
        note "grim not found, continuing without pre-capture"
    fi

    # Quickshell parses and validates the QML before rendering, so it exits
    # non-zero immediately if an import (e.g. a missing compiled module) cannot
    # be resolved. If we exec'd it here, the external-locker fallback below would be
    # unreachable and the session would stay unlocked while appearing to lock.
    # Run in the foreground instead.
    "$QS_BIN" -p "$LOCK_QML" >>"$LOG" 2>&1
    rc=$?
    if [ $rc -eq 0 ]; then
        note "quickshell exited 0 — lock released cleanly"
        exit 0
    fi
    # rc > 128 means quickshell was killed by a signal, which means it was ALIVE
    # and holding a session lock when it died. That is not "locking failed" -- the
    # compositor has already released the lock by the time the process is gone.
    # Starting a second locker on top of that teardown can crash the compositor,
    # which is why the wait below is not optional. Re-lock with the active
    # compositor's external locker so the session is not left wide open. This
    # path deliberately bypasses the guard:
    # the lock was granted and torn down, so there is no live instance to
    # compare against and refusing here would be the one case that leaves the
    # session open.
    # Exclude 255 explicitly. A real signal death is 128+N, so it can never
    # reach 255, but 255 numerically clears the `> 128` test -- and 255 is
    # Quickshell's "config failed to load", which means nothing was ever
    # locked. Without this, a config-load failure was reported as "lock was
    # granted", slept a pointless second waiting for a teardown that was never
    # coming, and then re-locked. It still ended up protected, so it looked
    # fine, but the log lied and every fallback cost an extra second.
    if [ $rc -gt 128 ] && [ $rc -ne 255 ]; then
        note "quickshell killed by signal $((rc - 128)) -- lock was granted, waiting for teardown"
        sleep 1
        if compositor_gone; then
            note "compositor is gone -- not re-locking"
            exit $rc
        fi
        run_external_fallback || true
        exit $rc
    fi
    # 255 is Quickshell's "failed to load/validate the config". Nothing was ever
    # locked, so the fallback is the only thing protecting the session.
    note "quickshell exited $rc -- config never loaded"
}

if [ "$METHOD" = "hyprlock" ] && [ "$UKISHIMA_WM" = hyprland ] && [ "$have_hyprlock" = 1 ]; then
    note "method=hyprlock -> hyprlock"
    run_hyprlock
fi

if [ "$METHOD" = "swaylock" ] && [ "$UKISHIMA_WM" = niri ] && [ "$have_swaylock" = 1 ]; then
    run_swaylock
fi

if [ "$have_qs" = 1 ]; then
    if [ "$METHOD" = "hyprlock" ] && [ "$UKISHIMA_WM" = hyprland ]; then
        note "method=hyprlock but hyprlock is not installed -> downgrading to the Quickshell lock"
    elif [ "$METHOD" = "swaylock" ]; then
        note "method=swaylock but swaylock is not installed -> using the Quickshell lock"
    else
        note "method=$METHOD -> the Quickshell lock"
    fi
    run_quickshell_lock
fi

run_external_fallback || true

note "ERROR no compositor-supported locker installed and no Quickshell lockscreen at $LOCK_QML"
echo "lock.sh: no supported locker installed and no Quickshell lockscreen at $LOCK_QML — cannot lock" >&2
exit 1
