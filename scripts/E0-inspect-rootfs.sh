#!/usr/bin/env bash
# 挂载 root.img，检查 USB gadget 与网络配置
set -uo pipefail
IMG=/mnt/e/Cache/shuaji/out/xiaomi-marble-root.img
MNT=/mnt/rootfs
mkdir -p "$MNT"

cleanup() { umount "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

echo "=== 尝试 loop 挂载 ==="
if ! mount -o loop,ro "$IMG" "$MNT" 2>&1; then
    echo "loop 挂载失败，改用 debugfs 读取"
    exit 1
fi
echo "挂载成功"
mkdir -p "$MNT/proc" 2>/dev/null || true

echo
echo "=== /etc/deviceinfo 里的 USB 网络函数 ==="
grep -iE 'usb_network|usb_net' "$MNT/etc/deviceinfo" 2>/dev/null || echo "(未找到)"

echo
echo "=== 找 gadget 相关脚本/配置 ==="
grep -rIl --include='*' -e 'usb_network_function' -e 'rndis.usb0' -e 'ecm.usb0' -e 'ncm.usb0' \
    "$MNT/usr" "$MNT/etc" 2>/dev/null | head -20

echo
echo "=== initramfs 里的 USB 网络配置（如有）==="
ls -l "$MNT/boot" 2>/dev/null | head

echo
echo "=== NetworkManager 已有连接 ==="
ls -la "$MNT/etc/NetworkManager/system-connections/" 2>/dev/null || echo "(无)"

echo
echo "=== sshd 是否启用 ==="
ls -l "$MNT/etc/systemd/system/multi-user.target.wants/" 2>/dev/null | grep -i ssh || echo "(未在 wants 里)"
grep -iE '^PermitRootLogin|^PasswordAuthentication' "$MNT/etc/ssh/sshd_config" 2>/dev/null

echo
echo "=== 用户 marble 是否存在 ==="
grep '^marble:' "$MNT/etc/passwd" 2>/dev/null

echo
echo "=== 与 USB gadget 有关的 systemd 单元 ==="
grep -rIl -e 'configfs' -e 'usb_gadget' "$MNT/usr/lib/systemd/system" 2>/dev/null | head
ls "$MNT/usr/lib/systemd/system" 2>/dev/null | grep -iE 'usb|gadget' | head
