#!/usr/bin/env bash
# 在 rootfs 里补上 buffyboard（触摸键盘）单元并启用，然后重新生成 sparse
set -uo pipefail
IMG=/mnt/e/Cache/shuaji/out/xiaomi-marble-root.img
SIMG=/mnt/e/Cache/shuaji/tmp/root.simg
M=/mnt/rootfs
mkdir -p "$M"
mount -o loop "$IMG" "$M" || { echo "mount fail"; exit 1; }
trap 'umount "$M" 2>/dev/null' EXIT

echo "=== 确认上次写的 Wi-Fi 配置还在 ==="
ls -l "$M/etc/NetworkManager/system-connections/" 2>/dev/null
grep -c 'psk=' "$M/etc/NetworkManager/system-connections/"*.nmconnection 2>/dev/null

echo
echo "=== 加 buffyboard 单元（触摸屏软键盘，tty1 上用）==="
cat > "$M/etc/systemd/system/buffyboard.service" <<'EOF'
[Unit]
Description=buffyboard on-screen keyboard for marble console
After=getty@tty1.service systemd-user-sessions.service
Conflicts=buffyboard-kill.service

[Service]
Type=simple
ExecStart=/usr/bin/buffyboard --config /usr/share/buffyboard/buffyboard.conf
Restart=always
RestartSec=3
Nice=-5

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$M/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/buffyboard.service \
       "$M/etc/systemd/system/multi-user.target.wants/buffyboard.service"
echo "  已写入并启用 buffyboard.service"

echo
echo "=== 顺手确认 sshd / NetworkManager 都已启用 ==="
for u in sshd NetworkManager; do
    if [ -L "$M/etc/systemd/system/multi-user.target.wants/$u.service" ]; then
        echo "  OK   $u"
    else
        ln -sf "/usr/lib/systemd/system/$u.service" "$M/etc/systemd/system/multi-user.target.wants/$u.service"
        echo "  补启用 $u"
    fi
done

echo
echo "=== 卸载并重生成 sparse ==="
sync
umount "$M"
trap - EXIT
rm -f "$SIMG"
img2simg "$IMG" "$SIMG" 1048576
ls -l "$IMG" "$SIMG"
echo "  sparse magic: $(od -A n -t x1 -N 4 "$SIMG")"
sha256sum "$IMG" "$SIMG"
