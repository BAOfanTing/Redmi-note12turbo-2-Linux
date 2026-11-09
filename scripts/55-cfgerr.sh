#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
echo "=== where is 'Run .pmbootstrap init. first' raised ==="
grep -rn "first to generate a config file" pmb/ | head
echo
grep -rn -B12 "first to generate a config file" pmb/config/__init__.py pmb/core/context.py pmb/main.py 2>/dev/null | head -40
