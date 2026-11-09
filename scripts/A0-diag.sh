#!/usr/bin/env bash
set -uo pipefail
W=/home/baofanting/marble-build/work
cd /home/baofanting/marble-build/pmbootstrap

echo "=== install.py password logic ==="
sed -n '85,125p' pmb/commands/install.py
echo
echo "=== --password arg definition ==="
grep -n -A8 '"--password"' pmb/parse/arguments.py | head -20
echo
echo "=== device pkg build section of log ==="
sed -n '/device-xiaomi-marble: Building/,/build failed/p' "$W/log.txt" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -40
echo
echo "=== is cc1 present in aarch64 buildroot? ==="
find "$W/chroot_buildroot_aarch64" -name 'cc1' 2>/dev/null | head
echo "--- gcc pkgs installed ---"
grep -iE '^P:' "$W/chroot_buildroot_aarch64/lib/apk/db/installed" 2>/dev/null | grep -i gcc | head
echo "--- which gcc/cc ---"
ls -l "$W/chroot_buildroot_aarch64/usr/bin/gcc" "$W/chroot_buildroot_aarch64/usr/bin/cc" 2>/dev/null
