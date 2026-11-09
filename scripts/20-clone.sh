#!/usr/bin/env bash
# Step 2: clone pmaports (marble branch) + install pmbootstrap, on ext4.
set -euo pipefail

USER_NAME="${USER_NAME:-baofanting}"
BUILD=/home/$USER_NAME/marble-build
LOG=/mnt/e/Cache/shuaji/logs/20-clone.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] clone start"

mkdir -p "$BUILD"
chown "$USER_NAME:$USER_NAME" "$BUILD"
cd "$BUILD"

# ------------------------------------------------------------------ pmaports
if [ -d pmaports/.git ]; then
    echo "pmaports: already cloned, updating"
    git -C pmaports fetch origin marble
else
    echo "### cloning pmaports (marble branch)"
    git clone --depth 1 -b marble https://github.com/iLtanaka/pmaports.git pmaports
fi

cd pmaports
echo "### pmaports HEAD"
git log -1 --format='%H%n%ad%n%s' --date=iso
echo

# The device package reads channels.cfg from the upstream branch, so the
# upstream remote + a shallow fetch of main is mandatory before init.
if ! git remote | grep -qx upstream; then
    echo "### adding upstream remote"
    git remote add upstream https://gitlab.postmarketos.org/postmarketOS/pmaports.git
fi
echo "### fetching upstream/main (shallow)"
git fetch --depth=1 upstream main || {
    echo "!! gitlab.postmarketos.org failed, trying gitlab.nura.eco"
    git remote set-url upstream https://gitlab.nura.eco/postmarketOS/pmaports.git
    git fetch --depth=1 upstream main
}

echo "### channels.cfg present?"
ls -l channels.cfg 2>&1 || echo "!! channels.cfg MISSING"

echo
echo "### marble device package files"
ls -l device/testing/device-xiaomi-marble/ 2>&1 | head -30
echo
echo "### linux kernel aport"
ls -d device/testing/linux-xiaomi-marble 2>&1
grep -E '^(pkgname|pkgver|_commit|_tag)=' device/testing/linux-xiaomi-marble/APKBUILD 2>&1 | head
echo
echo "### firmware aport(s)"
ls -d device/testing/firmware-xiaomi-marble* 2>&1 | head -20

cd "$BUILD"

# --------------------------------------------------------------- pmbootstrap
if [ -d pmbootstrap/.git ]; then
    echo "pmbootstrap: already cloned"
else
    echo "### cloning pmbootstrap"
    git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git pmbootstrap
fi
cd pmbootstrap
git log -1 --format='%H %ad %s' --date=short
chown -R "$USER_NAME:$USER_NAME" "$BUILD"

echo "### [$(date -Is)] clone done"
