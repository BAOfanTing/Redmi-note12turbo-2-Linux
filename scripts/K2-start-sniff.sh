#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. logind 是否占着输入设备 ====="
LID=$(R 'systemctl show -p MainPID --value systemd-logind')
echo "  logind pid=$LID"
R "ls -l /proc/$LID/fd 2>/dev/null | grep -E 'input/event' " || echo "  （看不到 input 设备 fd）"

echo
echo "===== 2. 还有谁开着 input 设备 ====="
for p in $(R 'ls /proc | grep -E "^[0-9]+$"'); do
    n=$(R "ls -l /proc/$p/fd 2>/dev/null | grep -c 'input/event'")
    [ "${n:-0}" -gt 0 ] 2>/dev/null && {
        cmd=$(R "tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null" | cut -c1-60)
        echo "  pid=$p ($n 个) $cmd"
    }
done

echo
echo "===== 3. 启动抓包器（300 秒，后台常驻）====="
R 'pkill -f K1-evsniff.sh; rm -f /tmp/ev.log'
R 'nohup setsid sh /tmp/K1-evsniff.sh 300 >/dev/null 2>&1 &'
sleep 2
R 'ls -l /tmp/ev.log; pgrep -af K1-evsniff | head -3'

echo
echo "===== 4. 当前抓到的内容（应为空）====="
R 'cat /tmp/ev.log 2>/dev/null | head -5'
echo "  (结束)"
