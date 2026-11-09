#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== top level ==="
ls -1
echo
echo "=== pmb/ ==="
ls -1 pmb/ 2>/dev/null | head -30
echo
echo "=== grep aports global arg ==="
grep -rn '"--aports"' . 2>/dev/null | head
echo
echo "=== grep aports= handling ==="
grep -rn 'args.aports' . 2>/dev/null | head
