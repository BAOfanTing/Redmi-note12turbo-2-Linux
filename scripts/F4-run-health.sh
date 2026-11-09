#!/usr/bin/env bash
# �?F3-health.sh 推到手机上执�?set -uo pipefail
export SSHPASS="${MARBLE_PASSWORD:?set it in secrets.sh}"
HOST=<PHONE_IP>
USER=marble
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"
SRC=/mnt/e/Cache/shuaji/scripts/F3-health.sh

echo "=== 拷贝脚本到手�?==="
sshpass -e scp $OPTS "$SRC" "$USER@$HOST:/tmp/F3-health.sh" || exit 1

echo "=== 在手机上执行 ==="
sshpass -e ssh $OPTS "$USER@$HOST" 'sh /tmp/F3-health.sh'
