#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== commands dir ==="
ls -1 pmb/commands/
echo
echo "=== init.py ==="
cat pmb/commands/init.py 2>/dev/null | head -120
