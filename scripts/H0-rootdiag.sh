#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== kiosk 服务状�?====="
R 'systemctl status marble-dashboard-kiosk --no-pager -l | head -14'

echo
echo "===== cage 进程 ====="
R 'pgrep -af cage | head -3'

echo
echo "===== cage 的环境变量（root 读取�?===="
CAGE=$(R 'pgrep -f "^/usr/sbin/cage" | head -1')
echo "cage pid=$CAGE"
R "tr '\\0' '\\n' < /proc/$CAGE/environ | grep -iE 'XDG_RUNTIME_DIR|WAYLAND|LIBSEAT|WLR|DISPLAY'"

echo
echo "===== chromium 环境 ====="
CH=$(R 'pgrep -f "chromium --ozone" | head -1')
echo "chromium pid=$CH"
R "tr '\\0' '\\n' < /proc/$CH/environ | grep -iE 'WAYLAND|XDG_RUNTIME|DISPLAY'"

echo
echo "===== xdg 目录内容（root 视角�?===="
R 'ls -la /run/marble-dashboard/xdg/'

echo
echo "===== 全盘�?wayland socket ====="
R 'find /run /tmp -maxdepth 4 -name "wayland-*" 2>/dev/null'

echo
echo "===== cage 最近日志（只看 cage 自身�?===="
R 'journalctl -u marble-dashboard-kiosk -n 60 --no-pager | grep -E "cage\[|wayland|socket|DRM|EGL|GL" | tail -15'
