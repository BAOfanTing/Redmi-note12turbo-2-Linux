#!/usr/bin/env bash
# 推�?dashboard 目录并在手机上安装（sudo 执行�?set -uo pipefail
export SSHPASS="${MARBLE_PASSWORD:?set it in secrets.sh}"
HOST=<PHONE_IP>
USER=marble
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
SRC=/mnt/e/Cache/shuaji/out/dashboard

echo "=== 推�?dashboard/ ==="
sshpass -e ssh $OPTS "$USER@$HOST" 'rm -rf /tmp/dashboard'
sshpass -e scp $OPTS -r "$SRC" "$USER@$HOST:/tmp/dashboard" || exit 1
sshpass -e ssh $OPTS "$USER@$HOST" 'ls -l /tmp/dashboard'

echo
echo "=== 安装（sudo，apk 需要下�?cage+cog�?=="
sshpass -e ssh $OPTS -t "$USER@$HOST" "cd /tmp/dashboard && echo '$PW' | sudo -S sh install-dashboard.sh 2>&1 | tail -40"
