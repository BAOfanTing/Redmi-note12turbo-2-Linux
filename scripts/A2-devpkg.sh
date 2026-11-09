#!/usr/bin/env bash
set -uo pipefail
LOG=/mnt/e/Cache/shuaji/logs/A2-devpkg.log
: > "$LOG"

su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"; export CI=1
pmbootstrap --details-to-stdout build device-xiaomi-marble 2>&1' > "$LOG" 2>&1
rc=$?

echo "### rc=$rc"
echo "=== abuild command line ==="
grep -aE 'abuild -d' "$LOG" | sed 's/\x1b\[[0-9;]*m//g' | tail -3
echo
echo "=== error context ==="
grep -a -B20 'cannot execute' "$LOG" | sed 's/\x1b\[[0-9;]*m//g' | tail -30
echo
echo "=== tail ==="
tail -20 "$LOG" | sed 's/\x1b\[[0-9;]*m//g'
exit $rc
