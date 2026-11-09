#!/usr/bin/env bash
# Download boot-uboot.img and the marble-install helper into the build dir.
set -uo pipefail
W=/home/baofanting/marble-build/work
OUT=/mnt/e/Cache/shuaji/out
mkdir -p "$OUT"

echo "=== boot-uboot.img (v20261008) ==="
for attempt in 1 2 3; do
    if curl -fL --retry 3 --max-time 300 \
        -o "$W/boot-uboot.img" \
        https://github.com/iLtanaka/u-boot-marble/releases/download/v20261008/boot-uboot.img; then
        break
    fi
    echo "attempt $attempt failed"
    sleep 5
done

echo "=== marble-install ==="
curl -fL --retry 3 --max-time 120 -o "$OUT/marble-install" \
    https://raw.githubusercontent.com/iLtanaka/u-boot-marble/main/scripts/marble-install
chmod +x "$OUT/marble-install"

echo "=== results ==="
ls -l "$W/boot-uboot.img" "$OUT/marble-install"
echo
echo "=== sha256 of uboot ==="
sha256sum "$W/boot-uboot.img"
echo
echo "=== expected (from GitHub release) ==="
echo "81d9e7bce88b43f39262198590ce686a0c6544585ab4dbe668a8c2b3deaadb00"
