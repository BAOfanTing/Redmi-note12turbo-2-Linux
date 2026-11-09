#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== version ==="
su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"; pmbootstrap --version' 2>&1
echo
echo "=== init --help ==="
su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"; pmbootstrap init --help' 2>&1 | head -40
echo
echo "=== config keys of interest ==="
grep -rnE '"(aports|ui|device|kernel|extra_packages|ssh_keys|sudo_timer|build_default_device_arch|locale|timezone|user|hostname)"' pmb/config/__init__.py 2>/dev/null | head -40
