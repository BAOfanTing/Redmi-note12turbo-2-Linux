#!/usr/bin/env bash
# Step 4: write pmbootstrap config directly (no interactive wizard).
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
BUILD=/home/$USER_NAME/marble-build
LOG=/mnt/e/Cache/shuaji/logs/50-config.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] configure pmbootstrap"

su - "$USER_NAME" -c '
set -u
export PATH="$HOME/.local/bin:$PATH"
BUILD="$HOME/marble-build"

# pmbootstrap refuses to run if the config dir does not exist
mkdir -p ~/.config

pmb() { pmbootstrap -q -p "$BUILD/pmaports" "$@"; }

echo "--- work path ---"
pmb config work "$BUILD/work"
echo "--- aports ---"
pmb config aports "$BUILD/pmaports"
echo "--- device ---"
pmb config device xiaomi-marble
echo "--- kernel ---"
pmb config kernel mainline
echo "--- ui (headless server) ---"
pmb config ui console
echo "--- user ---"
pmb config user marble
echo "--- hostname ---"
pmb config hostname marble
echo "--- timezone ---"
pmb config timezone Asia/Shanghai
echo "--- locale ---"
pmb config locale en_US.UTF-8
echo "--- jobs ---"
pmb config jobs 12
echo "--- ccache ---"
pmb config ccache_size 5G
echo "--- extra packages ---"
pmb config extra_packages "openssh,htop,curl"
echo "--- build_default_device_arch ---"
pmb config build_default_device_arch True

echo
echo "=== resulting config ==="
pmb config
'
echo "### [$(date -Is)] configure done"
