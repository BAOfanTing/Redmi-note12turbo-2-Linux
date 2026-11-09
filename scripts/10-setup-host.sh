#!/usr/bin/env bash
# Step 1: prepare the WSL2 Ubuntu build host for pmbootstrap (run as root).
set -euo pipefail

USER_NAME="${USER_NAME:-baofanting}"
LOG=/mnt/e/Cache/shuaji/logs/10-setup-host.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] setup-host start (user=$USER_NAME)"

# ---------------------------------------------------------------- sudoers
if [ ! -f /etc/sudoers.d/90-pmb-nopasswd ]; then
    echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-pmb-nopasswd
    chmod 0440 /etc/sudoers.d/90-pmb-nopasswd
    visudo -c -f /etc/sudoers.d/90-pmb-nopasswd >/dev/null
    echo "sudoers: NOPASSWD installed for $USER_NAME"
else
    echo "sudoers: already present"
fi

# ---------------------------------------------------------------- packages
export DEBIAN_FRONTEND=noninteractive
PKGS="git python3 python3-venv python3-pip qemu-user-static binfmt-support \
      build-essential flex bison bc libssl-dev libelf-dev ccache \
      e2fsprogs util-linux cryptsetup-bin dosfstools mtools android-tools-adb \
      android-tools-fastboot device-tree-compiler rsync curl wget unzip xz-utils \
      openssh-client kmod"

echo "### apt-get update"
apt-get update -qq

echo "### apt-get install"
# shellcheck disable=SC2086
apt-get install -y -qq --no-install-recommends $PKGS || {
    echo "!! bulk install failed, retrying package by package"
    for p in $PKGS; do
        apt-get install -y -qq --no-install-recommends "$p" || echo "   (skipped: $p)"
    done
}

# ---------------------------------------------------------------- binfmt
echo "### binfmt_misc status"
if [ -e /proc/sys/fs/binfmt_misc/register ]; then
    echo "binfmt_misc mounted"
else
    mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc || echo "!! cannot mount binfmt_misc"
fi

QEMU_BIN="$(command -v qemu-aarch64-static || true)"
echo "qemu-aarch64-static: ${QEMU_BIN:-MISSING}"

if [ -n "$QEMU_BIN" ]; then
    # Register explicitly (the F flag is required for chroot use).
    if [ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
        echo "registering qemu-aarch64 binfmt (F flag)"
        printf ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:%s:F\n' \
            "$QEMU_BIN" > /proc/sys/fs/binfmt_misc/register \
            && echo "registered" || echo "!! registration failed"
    else
        echo "qemu-aarch64 already registered"
        grep -E '^(enabled|flags)' /proc/sys/fs/binfmt_misc/qemu-aarch64 || true
    fi
    cat /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null || true
fi

# ---------------------------------------------------------------- sanity
echo "### post-install tool check"
for t in git python3 gcc make flex bison bc dtc qemu-aarch64-static mkfs.ext4 \
         fastboot adb cryptsetup ccache; do
    printf '%-22s %s\n' "$t" "$(command -v "$t" || echo MISSING)"
done
echo "### python"
python3 --version

echo "### [$(date -Is)] setup-host done"
