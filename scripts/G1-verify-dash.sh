#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== 服务状�?====="
for u in marble-dashboard marble-dashboard-kiosk marble-screen-idle; do
    st=$(systemctl is-active $u 2>/dev/null)
    en=$(systemctl is-enabled $u 2>/dev/null)
    printf '  %-28s %s / %s\n' "$u" "$st" "$en"
done

echo
echo "===== 面板 HTML ====="
ls -l /run/marble-dashboard/index.html 2>/dev/null
echo "--- �?12 �?---"
head -12 /run/marble-dashboard/index.html 2>/dev/null

echo
echo "===== 生成脚本单跑一�?====="
S /usr/local/bin/marble-dashboard.sh
echo "  退出码: $?"
ls -l /run/marble-dashboard/index.html

echo
echo "===== 背光设备 ====="
ls -1 /sys/class/backlight/ 2>/dev/null || echo "  (没有 /sys/class/backlight)"
for d in /sys/class/backlight/*; do
    [ -e "$d" ] || continue
    echo "  $d: brightness=$(cat $d/brightness 2>/dev/null) max=$(cat $d/max_brightness 2>/dev/null)"
done

echo
echo "===== 屏幕控制状�?====="
S /usr/local/bin/marble-screen.sh status

echo
echo "===== kiosk 最近日�?====="
S journalctl -u marble-dashboard-kiosk -n 15 --no-pager 2>/dev/null | tail -15

echo
echo "===== idle 服务最近日�?====="
S journalctl -u marble-screen-idle -n 12 --no-pager 2>/dev/null | tail -12

echo
echo "===== chromium 进程 ====="
ps w 2>/dev/null | grep -E 'chromium|cage' | grep -v grep | head -5
