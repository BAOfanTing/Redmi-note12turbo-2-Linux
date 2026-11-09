#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 全盘搜谁提到 brightness / backlight ====="
R 'grep -rl "brightness" /usr/libexec /usr/bin /usr/sbin /etc /usr/lib/systemd /usr/share/postmarketos* 2>/dev/null | head -20'

echo
echo "===== 2. marble-hardware-tuning.sh 内容 ====="
R 'cat /usr/libexec/marble-hardware-tuning.sh 2>/dev/null | head -40'

echo
echo "===== 3. marble-touchboost 相关 ====="
R 'ls -l /usr/libexec/marble-touchboost /usr/lib/systemd/system/marble-touchboost.service 2>/dev/null'
R 'cat /usr/lib/systemd/system/marble-touchboost.service 2>/dev/null'

echo
echo "===== 4. systemd-backlight 单元状态 ====="
R 'systemctl list-units "*backlight*" --all --no-legend 2>/dev/null'
R 'systemctl status "systemd-backlight@ae94000.dsi.0.service" --no-pager 2>/dev/null | head -8'

echo
echo "===== 5. 当前相关服务 ====="
R 'systemctl is-active marble-hardware-tuning marble-touchboost 2>/dev/null'
ps w 2>/dev/null | grep -E 'touchboost|tuning' | grep -v grep | cut -c1-80

echo
echo "===== 6. 设 0 后立刻查是谁（每 0.3 秒连查 8 次）====="
R 'echo 0 > /sys/class/backlight/ae94000.dsi.0/brightness'
i=0
while [ $i -lt 8 ]; do
    printf '  t+%s.%ss brightness=%s\n' "$((i/2))" "$(( (i%2)*5 ))" "$(cat /sys/class/backlight/ae94000.dsi.0/brightness)"
    sleep 0.3
    i=$((i+1))
done
