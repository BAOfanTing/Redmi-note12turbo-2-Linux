#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== sector_size handling ==="
grep -rn 'rootfs_image_sector_size\|sector_size' pmb/ --include=*.py | head -20
echo
echo "=== install --split image naming ==="
grep -rn 'rootfs_image_sector_size\|"-split"\|boot.img\|-boot\.img\|-root\.img' pmb/install/*.py pmb/install/**/*.py 2>/dev/null | head -20
echo
echo "=== where images are written ==="
grep -rn 'chroot_native/home/pmos/rootfs\|home/pmos/rootfs' pmb/ --include=*.py | head -10
