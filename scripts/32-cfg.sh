#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== config defaults ==="
sed -n '1,160p' pmb/config/__init__.py
echo
echo "=== global args (aports?) ==="
grep -rn 'aports' pmb/cli/__init__.py pmb/main.py 2>/dev/null | head -20
