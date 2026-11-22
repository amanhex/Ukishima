#!/bin/sh
# Ukishima EQ chain supervisor.
#
# Runs `pipewire -c <conf>` (the EQ filter chain) as a child and ties its
# lifetime to the shell process that asked for it. Quickshell does not run QML
# destructors on exit, so a plain child of the shell is orphaned in the PipeWire
# graph; but a shell *reload* destroys the QML Process that launched us, so we
# must not stay that Process either. Hence: a detached supervisor that watches
# the shell pid and stops the chain once the shell is gone.
#
# Usage: eq-run.sh <eq.conf> <shell-pid> <pidfile>

set -u

conf=$1
shell=$2
pidfile=$3

stop() {
	if [ -n "${pw:-}" ]; then
		kill "$pw" 2>/dev/null
		wait "$pw" 2>/dev/null
	fi
	rm -f "$pidfile"
	exit 0
}
trap stop TERM INT

pipewire -c "$conf" &
pw=$!
echo "$pw" > "$pidfile" 2>/dev/null

# Stop with the shell (kill -0 fails once it is gone), or if the chain itself
# dies, so we never linger.
while kill -0 "$shell" 2>/dev/null; do
	kill -0 "$pw" 2>/dev/null || stop
	sleep 1
done
stop
