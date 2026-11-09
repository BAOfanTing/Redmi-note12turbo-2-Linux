#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 部署最终版启动器 ====="
R 'install -Dm755 /tmp/dashboard/marble-monitor /usr/local/bin/marble-monitor'
R 'grep -c "new-window" /usr/local/bin/marble-monitor'
R 'pkill -f "epiphany --new-window" 2>/dev/null; systemctl reset-failed marble-monitor-app.service 2>/dev/null'

echo
echo "===== 2. 确认 App 图标已注册 ====="
R 'ls -l /usr/share/applications/marble-monitor.desktop /usr/share/icons/hicolor/scalable/apps/marble-monitor.svg'
R 'desktop-file-validate /usr/share/applications/marble-monitor.desktop 2>&1 && echo "  desktop 语法 OK"'
echo "  --- 图标是否可被 GTK 找到 ---"
R 'gtk4-encode-symbolic-svg --help >/dev/null 2>&1; python3 -c "print()" 2>/dev/null; ls /usr/share/icons/hicolor/scalable/apps/ | grep marble'

echo
echo "===== 3. 顺便：关掉自动锁屏（方便当平板用）====="
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus gsettings set org.gnome.desktop.screensaver lock-enabled false 2>&1; echo "  rc=$?"'
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus gsettings get org.gnome.desktop.screensaver lock-enabled 2>&1'

echo
echo "===== 4. 当前状态汇总 ====="
R 'echo "greetd=$(systemctl is-active greetd)"; echo "phoc=$(pgrep -c -f "usr/bin/phoc")"; echo "生成器=$(systemctl is-active marble-dashboard)"'
R 'ls -l /run/marble-dashboard/index.html'
