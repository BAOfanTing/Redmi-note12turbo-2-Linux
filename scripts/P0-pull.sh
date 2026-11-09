#!/usr/bin/env bash
# 从手机拉文件： ./P0-pull.sh <远程路径> <本地路径>
set -uo pipefail
export SSHPASS="${MARBLE_PASSWORD:?set it in secrets.sh}"
HOST=<PHONE_IP>
USER=marble
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"
REMOTE="${1:?远程路径}"
LOCAL="${2:?本地路径}"
sshpass -e scp $OPTS "$USER@$HOST:$REMOTE" "$LOCAL" && ls -l "$LOCAL"
