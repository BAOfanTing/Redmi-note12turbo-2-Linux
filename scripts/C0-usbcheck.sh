#!/usr/bin/env bash
set -uo pipefail
echo "=== WSL 内核模块可用性（决定 usbipd 直通能否出 /dev/sdX）==="
for m in usb-storage uas usbip-core vhci-hcd scsi_mod sd_mod; do
    printf '%-14s ' "$m"
    if modinfo "$m" >/dev/null 2>&1; then echo "有"; else echo "无"; fi
done
echo
echo "=== 当前 lsmod（usb/scsi 相关）==="
lsmod 2>/dev/null | grep -iE 'usb|scsi|sd_mod' | head -10 || echo "(空)"
echo
echo "=== /dev 下的块设备 ==="
ls /dev/sd* /dev/nvme* 2>/dev/null || echo "(无)"
echo
echo "=== 块设备工具 ==="
for t in lsblk blkid wipefs sgdisk sgdisk partprobe; do
    printf '%-12s %s\n' "$t" "$(command -v "$t" || echo MISSING)"
done
