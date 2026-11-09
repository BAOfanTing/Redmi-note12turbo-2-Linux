#!/usr/bin/env bash
# Step 4b: hand-write pmbootstrap_v3.cfg in the exact format pmb/config/file.py
# serializes, plus the work folder with its version file. This bypasses the
# fully interactive `pmbootstrap init` wizard.
set -euo pipefail

USER_NAME="${USER_NAME:-baofanting}"
BUILD=/home/$USER_NAME/marble-build
LOG=/mnt/e/Cache/shuaji/logs/57-writecfg.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] write config"

WORK="$BUILD/work"
CFG_DIR=/home/$USER_NAME/.config
CFG="$CFG_DIR/pmbootstrap_v3.cfg"

mkdir -p "$WORK" "$CFG_DIR"
# work_version is 8 in pmb/config/__init__.py
echo "8" > "$WORK/version"
mkdir -p "$WORK/cache_git"

cat > "$CFG" <<EOF
[pmbootstrap]
aports = $BUILD/pmaports
boot_size = 512
build_default_device_arch = True
build_pkgs_on_install = True
ccache_size = 5G
device = xiaomi-marble
extra_packages = openssh,htop,curl
extra_space = 0
hostname = marble
jobs = 12
kernel = mainline
keymap = 
locale = en_US.UTF-8
qemu_redir_stdio = False
service_manager = default
ssh_key_glob = ~/.ssh/*.pub
ssh_keys = False
sudo_timer = False
timezone = Asia/Shanghai
ui = console
ui_extras = False
user = marble
work = $WORK
auto_zap_misconfigured_chroots = no

[providers]

[mirrors]
EOF

chown -R "$USER_NAME:$USER_NAME" "$CFG_DIR" "$WORK"
chmod 600 "$CFG"

echo "=== written config ==="
cat "$CFG"
echo
echo "=== work dir ==="
ls -la "$WORK"

echo
echo "=== pmbootstrap reads it back? ==="
su - "$USER_NAME" -c 'export PATH="$HOME/.local/bin:$PATH"; pmbootstrap config' 2>&1

echo "### [$(date -Is)] write config done"
