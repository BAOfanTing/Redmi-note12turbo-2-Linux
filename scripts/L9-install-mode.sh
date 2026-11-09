#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== greetd 的 override（pmOS 用 phrog 当登录器）====="
R 'cat /usr/lib/systemd/system/greetd.service.d/override.conf 2>/dev/null'
R 'cat /etc/phrog/greetd-config.toml 2>/dev/null'

echo
echo "===== 安装 marble-mode.sh ====="
R 'install -Dm755 /tmp/dashboard/marble-mode.sh /usr/local/bin/marble-mode.sh'
R 'ls -l /usr/local/bin/marble-mode.sh'

echo
echo "===== 默认先保持服务器模式：禁用 greetd ====="
R 'systemctl disable greetd 2>/dev/null'
R 'systemctl stop greetd 2>/dev/null'
echo "  greetd: $(systemctl is-active greetd 2>/dev/null) / $(systemctl is-enabled greetd 2>/dev/null)"

echo
echo "===== 当前模式 ====="
R '/usr/local/bin/marble-mode.sh status'
