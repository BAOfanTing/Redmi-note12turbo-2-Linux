#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== main.py global args ==="
sed -n '1,120p' pmb/main.py
echo
echo "=== config/file.py defaults dict ==="
grep -nE '^\s+"[a-z_]+":' pmb/config/file.py | head -80
