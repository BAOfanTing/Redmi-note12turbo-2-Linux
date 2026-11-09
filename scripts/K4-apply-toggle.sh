#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 安装修好的屏幕管理器 + kiosk 单元 ====="
R 'install -Dm755 /tmp/dashboard/marble-screen-idle.sh /usr/local/bin/marble-screen-idle.sh'
R 'install -Dm644 /tmp/dashboard/marble-dashboard-kiosk.service /etc/systemd/system/marble-dashboard-kiosk.service'
R 'grep -c WLR_LIBINPUT_NO_DEVICES /etc/systemd/system/marble-dashboard-kiosk.service || true'
R 'systemctl daemon-reload'
R 'systemctl restart marble-screen-idle'
R 'systemctl restart marble-dashboard-kiosk'
sleep 6

echo
echo "===== 状态 ====="
for u in marble-dashboard-kiosk marble-screen-idle; do
    printf '  %-26s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)"
done
R '/usr/local/bin/marble-screen.sh status'

echo
echo "===== 清空日志标记，等待你按电源键 ====="
R 'journalctl --rotate >/dev/null 2>&1; journalctl -u marble-screen-idle --since "now" -n 1 --no-pager 2>/dev/null | tail -1'
echo "  准备就绪，可以按电源键了"
