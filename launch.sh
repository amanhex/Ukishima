#!/usr/bin/env sh
# Launch Ukishima with jemalloc decay settings. Quickshell links jemalloc; by
# default the allocator keeps freed pages around, so resident memory rides at
# the session's peak instead of the live working set. Turning decay on returns
# unused pages to the OS as the shell churns, which keeps RSS near the live
# working set. This script resolves its own location, so it works from any
# install path (just point your autostart at it).
export MALLOC_CONF="background_thread:true,dirty_decay_ms:100,muzzy_decay_ms:100"
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v quickshell >/dev/null 2>&1; then
  exec quickshell --config "$DIR" "$@"
elif command -v qs >/dev/null 2>&1; then
  exec qs -c "$DIR" "$@"
fi

echo "launch.sh: quickshell not found in PATH" >&2
exit 127