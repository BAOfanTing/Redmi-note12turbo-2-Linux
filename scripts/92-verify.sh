#!/usr/bin/env bash
set -uo pipefail
W=/home/baofanting/marble-build/work
OUT=/mnt/e/Cache/shuaji/out

echo "=== boot-uboot.img ==="
ls -l "$W/boot-uboot.img" 2>&1
sha256sum "$W/boot-uboot.img" 2>&1
echo "expected: 81d9e7bce88b43f39262198590ce686a0c6544585ab4dbe668a8c2b3deaadb00"
echo
echo "=== file type ==="
file "$W/boot-uboot.img" 2>&1
echo
echo "=== marble-install ==="
ls -l "$OUT/marble-install" 2>&1
head -3 "$OUT/marble-install" 2>&1
echo
echo "=== kernel build progress ==="
find "$W/packages" -name 'linux-xiaomi-marble*.apk' 2>/dev/null
ls -la "$W/cache_distfiles"/linux-* 2>/dev/null | head -5
du -sh "$W" 2>/dev/null
