#!/usr/bin/env bash
set -uo pipefail
IMG=/mnt/e/Cache/shuaji/out/xiaomi-marble-root.img
M=/mnt/rootfs
mkdir -p "$M"
mount -o loop,ro "$IMG" "$M" || { echo "mount fail"; exit 1; }
trap 'umount "$M" 2>/dev/null' EXIT

echo "=== buffyboard 相关文件 ==="
find "$M" -name '*buffyboard*' 2>/dev/null | head -20

echo
echo "=== buffyboard 是否被启用 ==="
ls -l "$M/etc/systemd/system/"*/  2>/dev/null | grep -i buffy
find "$M/etc/systemd/system" -name '*buffy*' 2>/dev/null
grep -rl 'buffyboard' "$M/etc/systemd/system" 2>/dev/null | head

echo
echo "=== getty 覆盖配置（console UI 常用）==="
find "$M/etc/systemd/system" -path '*getty*' 2>/dev/null | head -10
for f in $(find "$M/etc/systemd/system" -path '*getty*' -name '*.conf' 2>/dev/null | head -5); do
    echo "--- $f ---"; cat "$f"
done

echo
echo "=== postmarketos-ui-console 关注的文件 ==="
ls "$M/usr/share/postmarketos-ui-console" 2>/dev/null
find "$M/usr/lib" -name '*buffyboard*' 2>/dev/null | head

echo
echo "=== 是否有 tty1 的 autologin/getty 单元 ==="
ls -l "$M/etc/systemd/system/multi-user.target.wants/" 2>/dev/null | head -20
