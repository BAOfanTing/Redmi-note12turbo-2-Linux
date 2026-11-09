#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== pmb/config/init.py (first 200 lines) ==="
sed -n '1,200p' pmb/config/init.py
