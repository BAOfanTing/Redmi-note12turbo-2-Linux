#!/usr/bin/env bash
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
BOOT="$OUT/xiaomi-marble-boot.img"

echo "=== 用 dump 方式取 initramfs ==="
rm -f /tmp/initramfs.bin
debugfs -R "dump /initramfs /tmp/initramfs.bin" "$BOOT" 2>/dev/null
ls -lh /tmp/initramfs.bin
file /tmp/initramfs.bin

echo
echo "--- 解压并列出 marble 相关文件 ---"
mkdir -p /tmp/initramfs-root && rm -rf /tmp/initramfs-root/* 
cd /tmp/initramfs-root
if zcat /tmp/initramfs.bin 2>/dev/null | cpio -idm --quiet 2>/dev/null; then
    echo "文件总数: $(find . | wc -l)"
    echo "--- marble / extlinux 相关 ---"
    find . -iname '*marble*' 2>/dev/null | head
    echo "--- init 脚本 ---"
    ls -l init 2>/dev/null
    echo "--- 关键模块 ---"
    ls lib/modules/*/ 2>/dev/null | head -20
else
    echo "(cpio 解压失败，尝试其他格式)"
    head -c 16 /tmp/initramfs.bin | xxd | head -2
fi

echo
echo "=== 计算最终 SHA256SUMS ==="
cd "$OUT"
sha256sum boot-uboot.img marble-install \
          xiaomi-marble-boot.img xiaomi-marble-root.img \
          flash-marble.sh backup-marble.sh setup-server.sh \
          dashboard/marble-dashboard.sh dashboard/marble-dashboard.service \
          dashboard/marble-dashboard-kiosk.service dashboard/install-dashboard.sh \
          credentials.txt 手册.md \
          > SHA256SUMS.txt
cat SHA256SUMS.txt
