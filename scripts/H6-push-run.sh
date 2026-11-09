#!/usr/bin/env bash
# 推�?dashboard 目录并执行指定脚本（不跑 install-dashboard.sh�?set -uo pipefail
export SSHPASS="${MARBLE_PASSWORD:?set it in secrets.sh}"
HOST=<PHONE_IP>
USER=marble
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"
RUN="${1:?用法: H6-push-run.sh <设备端脚�?}"

echo "=== 推�?dashboard/ ==="
sshpass -e ssh $OPTS "$USER@$HOST" 'rm -rf /tmp/dashboard' || exit 1
sshpass -e scp $OPTS -r /mnt/e/Cache/shuaji/out/dashboard "$USER@$HOST:/tmp/dashboard" || exit 1

echo "=== 推�?$RUN ==="
sshpass -e ssh $OPTS "$USER@$HOST" 'rm -f /tmp/run.sh'
sshpass -e scp $OPTS "$RUN" "$USER@$HOST:/tmp/run.sh" || exit 1

echo "=== 执行 ==="
sshpass -e ssh $OPTS "$USER@$HOST" 'sh /tmp/run.sh'
