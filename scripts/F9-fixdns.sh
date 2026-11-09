#!/bin/sh
# 修复 DNS：优先用 systemd-resolved，不行就换成静�?resolv.conf
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== systemd-resolved 状�?====="
systemctl is-active systemd-resolved
systemctl is-enabled systemd-resolved
S systemctl status systemd-resolved --no-pager -l 2>&1 | head -12

echo
echo "===== 尝试启用并启�?systemd-resolved ====="
S systemctl enable --now systemd-resolved
sleep 2
systemctl is-active systemd-resolved

echo
echo "===== �?127.0.0.53 查询试试 ====="
( nslookup cdn.alpinelinux.org 2>&1 | head -6 )
echo "--- 直接�?223.5.5.5 ---"
( nslookup cdn.alpinelinux.org 223.5.5.5 2>&1 | head -8 )

echo
echo "===== 若仍失败，改成静�?resolv.conf ====="
if ! getent hosts cdn.alpinelinux.org >/dev/null 2>&1; then
    echo "  DNS 仍不可用 -> 写静态文�?
    S rm -f /etc/resolv.conf
    printf 'nameserver 223.5.5.5\nnameserver 223.6.6.6\nnameserver 192.168.1.1\noptions edns0\n' > /tmp/resolv.static
    S cp /tmp/resolv.static /etc/resolv.conf
    S chmod 644 /etc/resolv.conf
fi
echo "--- 现在�?/etc/resolv.conf ---"
ls -l /etc/resolv.conf
cat /etc/resolv.conf

echo
echo "===== 验证解析 ====="
if getent hosts cdn.alpinelinux.org; then
    echo "  DNS OK"
    DNS_OK=1
else
    echo "  DNS 仍失�?
    DNS_OK=0
fi

echo
echo "===== 再试 apk ====="
if [ "$DNS_OK" = "1" ]; then
    S apk update 2>&1 | tail -5
fi
