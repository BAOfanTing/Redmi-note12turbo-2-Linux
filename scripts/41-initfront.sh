#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
sed -n '900,1010p' pmb/config/init.py
echo "=== total lines ==="
wc -l pmb/config/init.py
