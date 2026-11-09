#!/usr/bin/env bash
# Fix ownership + add the upstream remote pmbootstrap expects, then verify channel resolution.
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
BUILD=/home/$USER_NAME/marble-build
LOG=/mnt/e/Cache/shuaji/logs/54-fix-git.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] fix git"

# pmbootstrap runs as the build user; root-owned files break git's ownership check.
chown -R "$USER_NAME:$USER_NAME" "$BUILD"

su - "$USER_NAME" -c '
set -u
cd ~/marble-build/pmaports
git config --global --add safe.directory ~/marble-build/pmaports
git config --global --add safe.directory ~/marble-build/pmbootstrap

echo "=== remotes before ==="
git remote -v

# pmbootstrap looks for a remote whose URL matches its known pmaports URLs.
if ! git remote | grep -qx upstream; then
    git remote add upstream https://gitlab.postmarketos.org/postmarketOS/pmaports.git
fi

echo "=== remotes after ==="
git remote -v

echo "=== fetch upstream main (channels.cfg source) ==="
git fetch --depth=1 upstream main 2>&1 | tail -5 || {
    echo "!! postmarketos.org unreachable, retrying via nura mirror"
    git remote set-url upstream https://gitlab.nura.eco/postmarketOS/pmaports.git
    git fetch --depth=1 upstream main 2>&1 | tail -5
}

echo "=== channels.cfg from upstream/main ==="
git show upstream/main:channels.cfg 2>&1 | head -20

echo "=== local channels.cfg (marble branch) ==="
head -8 channels.cfg

echo "=== current branch + channel ==="
git rev-parse --abbrev-ref HEAD
grep -E "^channel" pmaports.cfg
'
echo "### [$(date -Is)] fix git done"
