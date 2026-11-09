#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmaports

echo "=== linux-xiaomi-marble APKBUILD (head) ==="
head -40 device/testing/linux-xiaomi-marble/APKBUILD
echo
echo "=== source= lines ==="
grep -nE '^(source|_repository|_commit|_tag|_config|pkgver|_flavor)' device/testing/linux-xiaomi-marble/APKBUILD | head -20
echo
echo "=== firmware APKBUILD ==="
head -30 device/testing/firmware-xiaomi-marble/APKBUILD
echo
echo "=== deviceinfo ==="
cat device/testing/device-xiaomi-marble/deviceinfo
echo
echo "=== channels.cfg ==="
cat channels.cfg 2>&1 | head -20
