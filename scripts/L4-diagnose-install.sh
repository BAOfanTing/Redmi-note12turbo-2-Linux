#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== apk 进程状态 ====="
R 'ps -o pid,stat,etime,time,args 2>/dev/null | grep -E "apk add|PID" | head -5'

echo
echo "===== 它在等什么（wchan / 打开的文件）====="
AP=$(R 'pgrep -f "apk add --no-cache postmarketos-ui-phosh" | tail -1')
echo "  pid=$AP"
R "cat /proc/$AP/wchan 2>/dev/null; echo"
R "ls -l /proc/$AP/fd 2>/dev/null | tail -5"

echo
echo "===== 网络计数（5 秒间隔）====="
R 'cat /proc/net/dev | grep -E "wlan0"'
sleep 5
R 'cat /proc/net/dev | grep -E "wlan0"'

echo
echo "===== 临时目录/缓存增长 ====="
R 'du -sh /var/cache/apk 2>/dev/null; du -sh /tmp 2>/dev/null; du -sh /var/tmp 2>/dev/null'
sleep 3
R 'du -sh /var/cache/apk 2>/dev/null; du -sh /tmp 2>/dev/null'

echo
echo "===== 日志完整内容 ====="
R 'cat /tmp/phosh-install.log'
