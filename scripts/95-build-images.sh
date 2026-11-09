#!/usr/bin/env bash
# Step 7: build the device package + generate split boot/root images.
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
LOG=/mnt/e/Cache/shuaji/logs/95-build-images.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] build device package + images"

su - "$USER_NAME" -c '
set -u
export PATH="$HOME/.local/bin:$PATH"
export CI=1

echo "=== device package ==="
pmbootstrap --details-to-stdout -y build device-xiaomi-marble 2>&1 | tail -40
rc1=${PIPESTATUS[0]}
echo "device pkg rc=$rc1"

echo
echo "=== generating split images (this installs the full aarch64 rootfs) ==="
pmbootstrap --details-to-stdout -y install --split 2>&1 | tail -120
rc2=${PIPESTATUS[0]}
echo "install rc=$rc2"

exit $(( rc1 != 0 || rc2 != 0 ))
'
rc=$?
echo "### [$(date -Is)] images finished rc=$rc"
exit $rc
