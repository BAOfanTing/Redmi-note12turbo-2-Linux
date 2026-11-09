#!/usr/bin/env bash
# Lightweight watcher: prints one line per 60s until both images exist.
set -uo pipefail
W=/home/baofanting/marble-build/work
RF="$W/chroot_native/home/pmos/rootfs"
BOOT="$RF/xiaomi-marble-boot.img"
ROOT="$RF/xiaomi-marble-root.img"

for i in $(seq 1 120); do
    b=0; r=0
    [ -f "$BOOT" ] && b=$(( $(stat -c %s "$BOOT") / 1048576 ))
    [ -f "$ROOT" ] && r=$(( $(stat -c %s "$ROOT") / 1048576 ))
    cr=$(du -sm "$W/chroot_rootfs_xiaomi-marble" 2>/dev/null | cut -f1)
    printf '[%s] boot=%sMB root=%sMB rootfs-chroot=%sMB\n' "$(date +%H:%M:%S)" "$b" "$r" "${cr:-0}"
    if [ -f "$BOOT" ] && [ -f "$ROOT" ]; then
        echo "BOTH IMAGES PRESENT"
        break
    fi
    sleep 60
done
echo "=== final ==="
ls -lh "$RF" 2>/dev/null
