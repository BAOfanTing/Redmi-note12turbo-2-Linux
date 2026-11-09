#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== build/init.py 55-135 ==="
sed -n '55,135p' pmb/build/init.py
echo
echo "=== autodetect.py 55-95 ==="
sed -n '55,95p' pmb/build/autodetect.py
echo
echo "=== chroot/mount.py: /native handling ==="
grep -rn 'native' pmb/chroot/mount.py | head -20
