#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
W=/home/baofanting/marble-build/work

echo "=== crossdirect references ==="
grep -rn 'crossdirect' pmb/ --include=*.py | head -20
echo
echo "=== /native mount inside buildroot? ==="
ls -ld "$W/chroot_buildroot_aarch64/native" 2>/dev/null || echo "no /native dir"
echo
echo "=== cc1 in native chroot (cross gcc) ==="
find "$W/chroot_native" -path '*aarch64*' -name cc1 2>/dev/null | head
echo
echo "=== crossdirect wrapper in native ==="
ls -l "$W/chroot_native/usr/lib/crossdirect/aarch64/" 2>/dev/null | head
echo
echo "=== pmaports crossdirect aport? ==="
ls -d /home/baofanting/marble-build/pmaports/main/crossdirect 2>/dev/null
grep -rn 'pmb:crossdirect\|cross-native' /home/baofanting/marble-build/pmaports/device/testing/device-xiaomi-marble/APKBUILD
