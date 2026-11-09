#!/usr/bin/env bash
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
ROOT="$OUT/xiaomi-marble-root.img"

echo "=== 导出包清单到文件（供核对/交付）==="
debugfs -R "cat /lib/apk/db/installed" "$ROOT" 2>/dev/null \
  | grep '^P:' | sed 's/^P://' | sort > "$OUT/../logs/rootfs-packages.txt"
echo "写到 logs/rootfs-packages.txt，共 $(wc -l < "$OUT/../logs/rootfs-packages.txt") 个包"

echo
echo "=== 关键包逐个核对（直接对文件 grep，不用 -x）==="
for p in device-xiaomi-marble device-xiaomi-marble-nonfree-firmware \
         firmware-xiaomi-marble-wlan firmware-xiaomi-marble-bluetooth \
         firmware-xiaomi-marble-adreno firmware-xiaomi-marble-modem \
         firmware-xiaomi-marble-adsp firmware-xiaomi-marble-slpi \
         linux-xiaomi-marble openssh networkmanager systemd; do
    if grep -qx -- "$p" "$OUT/../logs/rootfs-packages.txt"; then
        printf '  OK   %s\n' "$p"
    else
        printf '  MISS %s\n' "$p"
    fi
done

echo
echo "=== firmware 包实际文件数量 ==="
debugfs -R "ls -l /lib/firmware/qcom/sm8475/xiaomi/marble" "$ROOT" 2>/dev/null | grep -c '^ *[0-9]'
echo "=== ath11k WCN6855 ==="
debugfs -R "ls -l /lib/firmware/ath11k/WCN6855/hw2.1" "$ROOT" 2>/dev/null | awk 'NR>2{print $NF}'

echo
echo "=== initramfs 里的 marble hook ==="
debugfs -R "cat /initramfs" "$OUT/xiaomi-marble-boot.img" 2>/dev/null > /tmp/initramfs.gz || true
if file /tmp/initramfs.gz | grep -qi 'gzip'; then
    echo "initramfs 是 gzip"
    zcat /tmp/initramfs.gz 2>/dev/null | cpio -t 2>/dev/null | grep -iE 'marble|extlinux' | head -10
    zcat /tmp/initramfs.gz 2>/dev/null | cpio -t 2>/dev/null | grep -c . | xargs echo "initramfs 文件总数:"
fi
