#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
echo "=== parse_channels_cfg + get_upstream_remote ==="
grep -n -A30 'def parse_channels_cfg' pmb/helpers/git.py
echo
grep -n -A25 'def get_upstream_remote' pmb/helpers/git.py
echo
echo "=== current git remotes in pmaports ==="
git -C /home/baofanting/marble-build/pmaports remote -v
echo "=== branches ==="
git -C /home/baofanting/marble-build/pmaports branch -a
