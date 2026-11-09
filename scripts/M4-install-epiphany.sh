#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 安装图标 + 启动器 ====="
R 'install -Dm755 /tmp/dashboard/marble-monitor /usr/local/bin/marble-monitor'
R 'install -Dm644 /tmp/dashboard/marble-monitor.desktop /usr/share/applications/marble-monitor.desktop'
R 'install -Dm644 /tmp/dashboard/marble-monitor.svg /usr/share/icons/hicolor/scalable/apps/marble-monitor.svg'
R 'gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null; echo "  icon cache: $?"'
R 'update-desktop-database /usr/share/applications 2>/dev/null; echo "  desktop db: $?"'
R 'ls -l /usr/share/icons/hicolor/scalable/apps/marble-monitor.svg /usr/share/applications/marble-monitor.desktop'

echo
echo "===== 后台安装 epiphany ====="
R 'systemctl reset-failed epiphany-install.service 2>/dev/null'
R 'systemd-run --unit=epiphany-install --collect /sbin/apk add --no-cache epiphany'
sleep 5
echo "  状态: $(systemctl is-active epiphany-install 2>/dev/null)"
R 'journalctl -u epiphany-install -n 3 --no-pager 2>/dev/null | tail -3'
