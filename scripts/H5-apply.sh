#!/bin/sh
# 1) 改密�? 2) 固化 DNS  3) 装新的屏幕管理器（电源键切换熄屏�?PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }
NEWPW="${MARBLE_PASSWORD:?set it in secrets.sh}"

echo "===== 1. 修改 marble 密码 ====="
R "echo 'marble:$NEWPW' | chpasswd"
R 'grep -c . /etc/shadow'
echo "  已设置（用户�?marble / 新密�?$NEWPW�?

echo
echo "===== 2. 固化 DNS ====="
# 2.1 �?NetworkManager 不再改写 resolv.conf
R 'mkdir -p /etc/NetworkManager/conf.d'
R "printf '[main]\ndns=none\n' > /etc/NetworkManager/conf.d/00-dns-none.conf"
# 2.2 resolv.conf 换成静态文件（不再�?systemd-resolved 的软链）
R 'rm -f /etc/resolv.conf'
R "printf 'nameserver 223.5.5.5\nnameserver 223.6.6.6\nnameserver 192.168.1.1\noptions edns0\n' > /etc/resolv.conf"
R 'chmod 644 /etc/resolv.conf'
# 2.3 停用并屏�?systemd-resolved（它�?stub 本机不响应，重启后会再造软链）
R 'systemctl disable --now systemd-resolved'
R 'systemctl mask systemd-resolved'
echo "  --- 结果 ---"
R 'ls -l /etc/resolv.conf'
R 'cat /etc/resolv.conf'
echo "  systemd-resolved: $(systemctl is-active systemd-resolved 2>/dev/null) / $(systemctl is-enabled systemd-resolved 2>/dev/null)"
R 'cat /etc/NetworkManager/conf.d/00-dns-none.conf'

echo
echo "===== 3. 安装新的屏幕管理�?====="
R 'install -Dm755 /tmp/dashboard/marble-screen-idle.sh /usr/local/bin/marble-screen-idle.sh'
R 'ls -l /usr/local/bin/marble-screen-idle.sh'
R 'systemctl restart marble-screen-idle'
sleep 4
echo "  marble-screen-idle: $(systemctl is-active marble-screen-idle)"

echo
echo "===== 4. 验证 ====="
echo "  --- DNS 解析 ---"
if getent hosts dl-cdn.alpinelinux.org >/dev/null 2>&1; then echo "    OK"; else echo "    FAIL"; fi
getent hosts dl-cdn.alpinelinux.org 2>&1 | head -2
echo "  --- apk 可用�?---"
R 'apk update 2>&1 | tail -2'
echo "  --- 屏幕状�?---"
R '/usr/local/bin/marble-screen.sh status'
echo "  --- idle 日志 ---"
R 'journalctl -u marble-screen-idle -n 8 --no-pager | tail -6'
