#!/bin/sh
# 后台启动 phosh 安装（避免 SSH 超时中断）
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

R 'rm -f /tmp/phosh-install.log /tmp/phosh-done'
R 'nohup setsid sh -c "echo "$MARBLE_PASSWORD" | sudo -S apk add --no-cache postmarketos-ui-phosh > /tmp/phosh-install.log 2>&1; echo \$? > /tmp/phosh-done" >/dev/null 2>&1 &'
sleep 3
echo "=== 已启动后台安装 ==="
R 'pgrep -af "apk add" | head -3'
R 'ls -l /tmp/phosh-install.log 2>/dev/null'
R 'tail -3 /tmp/phosh-install.log 2>/dev/null'
