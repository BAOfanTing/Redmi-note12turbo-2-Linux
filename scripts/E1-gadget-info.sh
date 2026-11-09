#!/usr/bin/env bash
set -uo pipefail
IMG=/mnt/e/Cache/shuaji/out/xiaomi-marble-root.img
M=/mnt/rootfs
mkdir -p "$M"
mount -o loop,ro "$IMG" "$M" || { echo "mount fail"; exit 1; }
trap 'umount "$M" 2>/dev/null' EXIT

echo "=== deviceinfo 里的 usb 网络函数 ==="
grep -iE 'usb_network' "$M/usr/share/deviceinfo/device-xiaomi-marble" 2>/dev/null || echo "(无 usb_network 行)"

echo
echo "=== initramfs init_functions.sh 里的 gadget 代码 ==="
grep -nE 'ecm|rndis|ncm|usb_network_function|configfs|UDC|functions/' \
    "$M/usr/share/initramfs/init_functions.sh" 2>/dev/null | head -30

echo
echo "=== usb-gadget 相关单元 ==="
ls "$M/usr/lib/systemd/system" | grep -iE 'gadget|unudhcpd'

echo
echo "=== usb-gadget.target 内容 ==="
cat "$M/usr/lib/systemd/system/usb-gadget.target" 2>/dev/null | head -20

echo
echo "=== 系统里创建 gadget 的地方（找 configfs 写入）==="
grep -rIl 'gadget/config' "$M/usr" 2>/dev/null | head -10

echo
echo "=== 是否有 local.d 启动钩子 ==="
ls "$M/etc/local.d" 2>/dev/null || echo "(无 local.d)"
