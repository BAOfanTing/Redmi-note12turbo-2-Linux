#!/usr/bin/env bash
set -uo pipefail
echo "=== config file ==="
cat /home/baofanting/.config/pmbootstrap_v3.cfg 2>&1
echo
echo "=== verbose read of one key ==="
su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"; pmbootstrap -p ~/marble-build/pmaports config device; echo "rc=$?"' 2>&1
echo
echo "=== status ==="
su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"; pmbootstrap -p ~/marble-build/pmaports status' 2>&1 | tail -30
