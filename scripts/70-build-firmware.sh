#!/usr/bin/env bash
# Step 5: build firmware-xiaomi-marble (must be built separately, otherwise
# `pmbootstrap install` fails with "no such package" for the firmware subpackages).
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
LOG=/mnt/e/Cache/shuaji/logs/70-build-firmware.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] build firmware-xiaomi-marble"

su - "$USER_NAME" -c '
set -u
export PATH="$HOME/.local/bin:$PATH"
export CI=1                 # non-interactive, enables the 900 s stall timeout
export PMB_APK_TOOLS_VERSION_IGNORE=0

pmbootstrap --details-to-stdout -y build firmware-xiaomi-marble 2>&1
rc=$?
echo "### build exit code: $rc"
exit $rc
'
rc=$?
echo "### [$(date -Is)] firmware build finished rc=$rc"
exit $rc
