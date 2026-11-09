#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== phosh 模拟安装（看依赖数量和体积）====="
R 'apk add --simulate postmarketos-ui-phosh 2>&1 | tail -25'

echo
echo "===== 关键依赖里有没有 greetd / phrog（会和现有 console+kiosk 抢终端）====="
R 'apk add --simulate postmarketos-ui-phosh 2>&1 | grep -iE "greetd|phrog|tuigreet|seatd|phosh|phoc|gnome-session" | head -15'

echo
echo "===== 包数量统计 ====="
n=$(R 'apk add --simulate postmarketos-ui-phosh 2>&1 | grep -cE "^\("')
echo "  将安装/升级约 $n 个包"

echo
echo "===== 现有会冲突的服务 ====="
R 'systemctl list-unit-files 2>/dev/null | grep -iE "greetd|phrog|phosh" || echo "  (目前没有 greetd/phosh 相关单元)"'
R 'systemctl is-active getty@tty1 marble-dashboard-kiosk 2>/dev/null'

echo
echo "===== 磁盘够不够 ====="
df -h / | tail -1
