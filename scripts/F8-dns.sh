#!/bin/sh
# 诊断手机 DNS / 网络连通�?PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
echo "===== resolv.conf ====="
ls -l /etc/resolv.conf
cat /etc/resolv.conf 2>/dev/null

echo
echo "===== nmcli 里的 DNS ====="
nmcli -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show wlan0 2>/dev/null

echo
echo "===== 路由 ====="
ip route

echo
echo "===== ping 网关 ====="
ping -c 2 -W 2 192.168.1.1 2>&1 | tail -3

echo
echo "===== ping 公网 IP（跳�?DNS�?===="
ping -c 2 -W 2 223.5.5.5 2>&1 | tail -3

echo
echo "===== DNS 查询 ====="
getent hosts cdn.alpinelinux.org 2>&1 || echo "  getent 失败"
nslookup cdn.alpinelinux.org 2>&1 | head -8 || true

echo
echo "===== �?HTTP（用 IP，绕 DNS�?===="
wget -q -O /dev/null --timeout=8 http://223.5.5.5/ 2>&1 && echo "  IP 直连 OK" || echo "  IP 直连失败"

echo
echo "===== NetworkManager 连接详情 ====="
echo "$PW" | sudo -S nmcli connection show 2>/dev/null
