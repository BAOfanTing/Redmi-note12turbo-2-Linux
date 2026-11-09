#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
sed -n '60,140p' pmb/helpers/repo.py
echo "=== ---- pmaports url ---- ==="
sed -n '240,290p' pmb/helpers/repo.py
