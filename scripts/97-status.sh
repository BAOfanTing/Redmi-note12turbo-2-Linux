#!/usr/bin/env bash
set -uo pipefail
W=/home/baofanting/marble-build/work

echo "=== chroots ==="
ls -d "$W"/chroot_* 2>/dev/null
echo
echo "=== sizes ==="
du -sm "$W"/chroot_* 2>/dev/null
echo
echo "=== built packages ==="
find "$W/packages" -name '*.apk' 2>/dev/null | sort
echo
echo "=== devices pkg built? ==="
find "$W/packages" -name 'device-xiaomi-marble*.apk' 2>/dev/null
echo
echo "=== rootfs chroot state ==="
ls "$W/chroot_rootfs_xiaomi-marble" 2>/dev/null | head -10
echo
echo "=== pmbootstrap log tail (latest lines) ==="
tail -25 /home/baofanting/.local/var/pmbootstrap/log.txt 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
tail -25 "$W/log.txt" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
echo
echo "=== work dir log files ==="
ls -la "$W"/*.log /home/baofanting/.local/var/pmbootstrap/*.log 2>/dev/null
