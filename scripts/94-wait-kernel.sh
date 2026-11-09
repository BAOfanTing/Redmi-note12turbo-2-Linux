#!/usr/bin/env bash
# Wait for the kernel package to appear, without dumping compiler output.
set -uo pipefail
W=/home/baofanting/marble-build/work
for i in $(seq 1 180); do
    apk=$(find "$W/packages" -name 'linux-xiaomi-marble-*.apk' 2>/dev/null | head -1)
    if [ -n "$apk" ]; then
        echo "[$(date +%H:%M:%S)] kernel package found:"
        ls -lh "$apk"
        break
    fi
    # report build tree growth as a liveness signal
    sz=$(du -sm "$W/chroot_native/root" 2>/dev/null | cut -f1)
    printf '[%s] building... (chroot root: %s MB)\n' "$(date +%H:%M:%S)" "${sz:-?}"
    sleep 30
done
echo "=== packages ==="
find "$W/packages" -name '*.apk' 2>/dev/null | sort
