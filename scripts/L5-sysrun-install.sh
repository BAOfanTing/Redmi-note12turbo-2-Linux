#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 清理旧尝试 ====="
R 'pkill -f "apk add --no-cache postmarketos-ui-phosh" 2>/dev/null; rm -f /tmp/phosh-install.log /tmp/phosh-done'
R 'systemctl reset-failed phosh-install.service 2>/dev/null'

echo "===== 用 systemd 临时单元启动安装（与 SSH 解耦）====="
R 'systemd-run --unit=phosh-install --description="install postmarketos-ui-phosh" --collect /sbin/apk add --no-cache postmarketos-ui-phosh'
sleep 5
echo "  单元状态: $(systemctl is-active phosh-install 2>/dev/null)"
R 'systemctl status phosh-install --no-pager 2>/dev/null | head -10'
echo
echo "  最近日志:"
R 'journalctl -u phosh-install -n 6 --no-pager 2>/dev/null | tail -6'
