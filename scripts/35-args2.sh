#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
sed -n '815,845p' pmb/parse/arguments.py
echo "--- init command args ---"
grep -n 'def init\|"init"' pmb/parse/arguments.py | head
echo "--- install args ---"
grep -nE '^\s+"--(split|fde|add|disk|rsync|filesystem|user|password|no-sshd|ssh-keys|kernel)"' pmb/parse/arguments.py | head -30
