#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 找 phosh 和 greetd 配置 ====="
R 'ls -l /usr/bin/phosh /usr/sbin/phosh /usr/libexec/phosh 2>/dev/null'
R 'ls -la /etc/greetd/ 2>/dev/null || echo "  /etc/greetd 不存在"'
R 'find /etc /usr/share -name "config.toml" -path "*greetd*" 2>/dev/null'
R 'cat /usr/lib/systemd/system/greetd.service 2>/dev/null'

echo
echo "===== greetd-phrog 包内容 ====="
R 'apk info -L greetd-phrog 2>/dev/null'
R 'apk info -L postmarketos-ui-phosh-systemd 2>/dev/null | head -20'

echo
echo "===== 找 phosh 的启动方式 ====="
R 'grep -rl "phosh" /etc/greetd /usr/share/greetd /usr/lib/systemd/user 2>/dev/null | head'
R 'cat /usr/share/wayland-sessions/*.desktop 2>/dev/null | head -20'

echo
echo "===== 用户会话相关 ====="
id marble 2>/dev/null
echo "$PW" | sudo -S ls -la /run/user/10000 2>/dev/null | head -5
