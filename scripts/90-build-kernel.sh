#!/usr/bin/env bash
# Step 6: build the marble kernel (7.2.8, clang/lld, cross-native).
# This is the long step: kernel tarball (~140 MB) + full arm64 build.
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
LOG=/mnt/e/Cache/shuaji/logs/90-build-kernel.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] build linux-xiaomi-marble"

su - "$USER_NAME" -c '
set -u
export PATH="$HOME/.local/bin:$PATH"
export CI=1
pmbootstrap --details-to-stdout -y build linux-xiaomi-marble 2>&1 | \
    grep -vE "^ *linux-[0-9].*[0-9]+k " 
rc=${PIPESTATUS[0]}
echo "### build exit code: $rc"
exit $rc
'
rc=$?
echo "### [$(date -Is)] kernel build finished rc=$rc"
exit $rc
