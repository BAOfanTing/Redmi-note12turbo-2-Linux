#!/usr/bin/env bash
# 把 Wi-Fi 凭据写进 rootfs 的 NetworkManager 配置，并重新生成 sparse 镜像
set -uo pipefail
IMG=/mnt/e/Cache/shuaji/out/xiaomi-marble-root.img
SIMG=/mnt/e/Cache/shuaji/tmp/root.simg
M=/mnt/rootfs
SSID="${WIFI_SSID:?set it in secrets.sh}"
PSK="${WIFI_PSK:?set it in secrets.sh}"

mkdir -p "$M"
mount -o loop "$IMG" "$M" || { echo "mount fail"; exit 1; }
trap 'umount "$M" 2>/dev/null' EXIT

echo "=== 1. 检查 wpa_supplicant / NetworkManager ==="
for b in /usr/sbin/wpa_supplicant /usr/bin/nmcli /usr/lib/NetworkManager; do
    [ -e "$M$b" ] && echo "  OK   $b" || echo "  MISS $b"
done
echo "--- NetworkManager 是否开机自启 ---"
if [ -L "$M/etc/systemd/system/multi-user.target.wants/NetworkManager.service" ]; then
    echo "  OK   已启用"
else
    echo "  未启用 -> 手动启用"
    mkdir -p "$M/etc/systemd/system/multi-user.target.wants"
    ln -sf /usr/lib/systemd/system/NetworkManager.service \
        "$M/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
fi

echo
echo "=== 2. 写入 Wi-Fi 连接配置 ==="
CONN_DIR="$M/etc/NetworkManager/system-connections"
mkdir -p "$CONN_DIR"
UUID=$(cat /proc/sys/kernel/random/uuid)
CONF="$CONN_DIR/${SSID}.nmconnection"
cat > "$CONF" <<EOF
[connection]
id=${SSID}
uuid=${UUID}
type=wifi
autoconnect=true
autoconnect-priority=100
autoconnect-retries=0

[wifi]
mode=infrastructure
ssid=${SSID}
powersave=2

[wifi-security]
key-mgmt=wpa-psk
psk=${PSK}

[ipv4]
method=auto
dns=223.5.5.5;223.6.6.6;

[ipv6]
method=ignore
EOF
chmod 600 "$CONF"
chown 0:0 "$CONF" 2>/dev/null || true
echo "  写入 $CONF"
sed 's/^psk=.*/psk=********/' "$CONF" | sed 's/^/    /'

echo
echo "=== 3. 顺手放一个 SSH 欢迎提示（确认登录后能看出来）==="
cat > "$M/etc/motd" <<'EOF'

  ==== marble · postmarketOS/Nura ====
  Wi-Fi 已预配：<WIFI_SSID>
  改密码: passwd     查看网络: nmcli device status
EOF

echo
echo "=== 4. 卸载并重新生成 sparse ==="
sync
umount "$M"
trap - EXIT
echo "  卸载完成"
ls -l "$IMG"

rm -f "$SIMG"
img2simg "$IMG" "$SIMG" 1048576
ls -l "$SIMG"
echo "  sparse magic: $(od -A n -t x1 -N 4 "$SIMG")"

echo
echo "=== 5. 记录新镜像 sha256 ==="
sha256sum "$IMG" "$SIMG"
