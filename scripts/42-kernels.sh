#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== required programs present? ==="
for t in git kpartx losetup openssl ps tar chroot sh; do
    printf '%-12s %s\n' "$t" "$(command -v "$t" || echo MISSING)"
done
echo
echo "=== kernels() parser ==="
grep -n -A30 'def kernels' pmb/parse/_apkbuild.py | head -45
