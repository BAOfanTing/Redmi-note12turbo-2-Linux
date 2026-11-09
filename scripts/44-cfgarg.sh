#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== global -c/--config arg ==="
grep -n -B2 -A6 '"--config"' pmb/parse/arguments.py | head -20
echo
echo "=== config subparser ==="
grep -n -A25 'config = sub.add_parser' pmb/parse/arguments.py | head -30
