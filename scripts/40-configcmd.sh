#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== -y / --assume-yes ==="
grep -n -A6 '"-y"' pmb/parse/arguments.py | head -20
echo
echo "=== config command ==="
cat pmb/commands/config.py 2>/dev/null | head -60
echo
echo "=== init subparser args ==="
sed -n '920,960p' pmb/parse/arguments.py
echo
echo "=== end of init(): what init does ==="
grep -n 'def run\|def frontend\|def init' pmb/config/init.py | head
