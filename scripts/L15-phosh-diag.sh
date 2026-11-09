#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== phosh-session / initial_session 相关日志 ====="
R 'journalctl -b --no-pager 2>/dev/null | grep -iE "initial_session|phosh-session|gnome-session.*phosh|start_session" | tail -12'

echo
echo "===== greetd 最近日志 ====="
R 'journalctl -u greetd -n 20 --no-pager 2>/dev/null | tail -20'

echo
echo "===== 以 root 身份检查 socket ====="
R 'ls -l /run/user/10000/ 2>/dev/null | grep -i wayland || echo "  uid10000 无 wayland"'
R 'ls -l /run/user/110/ 2>/dev/null | grep -i wayland || echo "  uid110 无 wayland"'

echo
echo "===== 截图（root 身份，指向 greetd 的 socket）====="
R 'env XDG_RUNTIME_DIR=/run/user/110 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-greeter.png 2>&1; ls -l /tmp/shot-greeter.png 2>/dev/null || echo "  gri 失败"'
