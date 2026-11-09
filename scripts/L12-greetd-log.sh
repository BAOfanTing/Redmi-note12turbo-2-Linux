#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== greetd 日志 ====="
R 'journalctl -u greetd -n 30 --no-pager 2>/dev/null'

echo
echo "===== greetd 相关用户 ====="
R 'grep -E "^(greetd|phrog|marble):" /etc/passwd /etc/group 2>/dev/null'
R 'ls -ld /var/lib/greetd /etc/phrog 2>/dev/null'

echo
echo "===== greetd 进程与实际执行的命令 ====="
R 'pgrep -af greetd | head -3'
GP=$(R 'pgrep -f "^greetd" | head -1')
echo "  pid=$GP"
R "tr '\\0' '\\n' < /proc/$GP/cmdline 2>/dev/null; echo"
R "ls -l /proc/$GP/fd 2>/dev/null | head -6"

echo
echo "===== 是否有 phrog / phosh-session 尝试失败 ====="
R 'journalctl -b --no-pager 2>/dev/null | grep -iE "phrog|phosh-session|greetd.*(error|fail)" | tail -10'

echo
echo "===== phosh-session 是否在 PATH ====="
R 'command -v phosh-session; ls -l /usr/bin/phosh-session /usr/sbin/phosh-session 2>/dev/null'
