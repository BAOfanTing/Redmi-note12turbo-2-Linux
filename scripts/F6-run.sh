#!/usr/bin/env bash
# 通用：把指定脚本推到手机执行
#   ./F6-run.sh /mnt/e/Cache/shuaji/scripts/F5-fix.sh
set -uo pipefail
export SSHPASS="${MARBLE_PASSWORD:?set it in secrets.sh}"
HOST=<PHONE_IP>
USER=marble
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"
SRC="${1:?用法: F6-run.sh <本地脚本路径>}"
NAME=$(basename "$SRC")

echo "=== 推�?$NAME ==="
sshpass -e scp $OPTS "$SRC" "$USER@$HOST:/tmp/$NAME" || exit 1

echo "=== 远程执行 ==="
sshpass -e ssh $OPTS "$USER@$HOST" "sh /tmp/$NAME"
