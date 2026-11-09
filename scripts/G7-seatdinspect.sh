#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== seatd 包内�?====="
S apk info -L seatd 2>/dev/null

echo
echo "===== 是否�?systemd 单元 ====="
ls -l /usr/lib/systemd/system/ 2>/dev/null | grep -i seat
ls -l /etc/init.d/ 2>/dev/null | grep -i seat

echo
echo "===== seatd 可执行与默认参数 ====="
command -v seatd; seatd -h 2>&1 | head -8

echo
echo "===== 相关用户/�?====="
grep -E '^(_?seat|seatd)' /etc/passwd /etc/group 2>/dev/null

echo
echo "===== logind 后端为什么失败（当前 SSH 会话�?seat�?===="
loginctl show-session $(loginctl list-sessions --no-legend 2>/dev/null | head -1 | awk '{print $1}') -p Seat -p Active -p Remote 2>/dev/null
