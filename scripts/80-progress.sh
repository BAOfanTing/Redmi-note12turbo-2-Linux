#!/usr/bin/env bash
set -uo pipefail
D=/home/baofanting/marble-build/work/cache_distfiles
echo "=== distfiles ==="
ls -la "$D" 2>/dev/null | head -20
echo
echo "=== firmware tarball size ==="
for f in "$D"/firmware-xiaomi-marble-*; do
    [ -e "$f" ] && printf '%s  %s bytes\n' "$(basename "$f")" "$(stat -c %s "$f")"
done
echo
echo "=== packages built so far ==="
find /home/baofanting/marble-build/work/packages -name '*.apk' 2>/dev/null | head -20
echo
echo "=== chroot sizes ==="
du -sh /home/baofanting/marble-build/work/chroot_* 2>/dev/null
