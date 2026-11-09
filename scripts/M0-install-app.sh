#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 安装 App 相关文件 ====="
R 'install -Dm755 /tmp/dashboard/marble-mode.sh /usr/local/bin/marble-mode.sh'
R 'install -Dm755 /tmp/dashboard/marble-monitor /usr/local/bin/marble-monitor'
R 'install -Dm644 /tmp/dashboard/marble-monitor.desktop /usr/share/applications/marble-monitor.desktop'
R 'ls -l /usr/local/bin/marble-monitor /usr/share/applications/marble-monitor.desktop'

echo
echo "===== 2. 确保面板生成器在跑（平板模式也要）====="
R 'systemctl enable --now marble-dashboard 2>/dev/null'
echo "  marble-dashboard: $(systemctl is-active marble-dashboard)"
R 'ls -l /run/marble-dashboard/index.html'

echo
echo "===== 3. desktop 文件语法检查 ====="
R 'command -v desktop-file-validate >/dev/null 2>&1 && desktop-file-validate /usr/share/applications/marble-monitor.desktop && echo "  OK" || echo "  (无校验工具，跳过)"'
R 'head -8 /usr/share/applications/marble-monitor.desktop'

echo
echo "===== 4. 在 phosh 会话里启动 App（模拟点图标）====="
R 'pkill -f "app=file:///run/marble-dashboard" 2>/dev/null'
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus /usr/local/bin/marble-monitor >/tmp/monitor.log 2>&1 &'
sleep 10

echo "  --- 进程 ---"
R 'pgrep -af "marble-dashboard/index.html" 2>/dev/null | cut -c1-100 | head -3'
echo "  --- 日志 ---"
R 'tail -8 /tmp/monitor.log 2>/dev/null'

echo
echo "===== 5. 截图 ====="
R 'env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-app.png 2>&1; ls -l /tmp/shot-app.png 2>/dev/null || echo "  截图失败"'
