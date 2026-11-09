#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== pmb/core/config.py ==="
sed -n '1,140p' pmb/core/config.py
echo
echo "=== pmb/config/file.py ==="
cat pmb/config/file.py
