#!/usr/bin/env bash
# Build device-xiaomi-marble with --no-cross (crossdirect is broken under WSL2
# because /native is not bind-mounted into the foreign-arch chroot).
set -uo pipefail
LOG=/mnt/e/Cache/shuaji/logs/A6-devpkg-nocross.log

su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"; export CI=1
pmbootstrap --no-cross --details-to-stdout build device-xiaomi-marble 2>&1' > "$LOG" 2>&1
rc=$?

echo "### rc=$rc"
echo "=== error lines (if any) ==="
grep -aE 'ERROR|error:|fatal|Traceback' "$LOG" | sed 's/\x1b\[[0-9;]*m//g' | head -15
echo
echo "=== tail ==="
tail -12 "$LOG" | sed 's/\x1b\[[0-9;]*m//g'
echo
echo "=== resulting package ==="
find /home/baofanting/marble-build/work/packages -name 'device-xiaomi-marble*.apk' -exec ls -lh {} \;
exit $rc
