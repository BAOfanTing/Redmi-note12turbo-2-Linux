#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== 'cross' CLI args ==="
grep -n -B3 -A8 '"--no-cross"\|"--cross"\|dest="cross"' pmb/parse/arguments.py | head -40
echo
echo "=== Config keys containing cross ==="
grep -n 'cross' pmb/core/config.py | head -20
