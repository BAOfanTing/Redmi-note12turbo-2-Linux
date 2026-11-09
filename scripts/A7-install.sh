#!/usr/bin/env bash
# Generate a random rootfs user password, then build the split images.
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
LOG=/mnt/e/Cache/shuaji/logs/A7-install.log

mkdir -p "$OUT"
PW_FILE="$OUT/credentials.txt"

if [ -s "$PW_FILE" ]; then
    PW=$(grep '^password:' "$PW_FILE" | awk '{print $2}')
else
    PW=$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-14)
    cat > "$PW_FILE" <<EOF
# marble (xiaomi-marble) 初始登录凭据
# 首次登录后请立刻改密码： passwd
username: marble
password: $PW
hostname: marble
timezone: Asia/Shanghai
EOF
    chmod 600 "$PW_FILE"
fi
echo "using password from $PW_FILE"

su - baofanting -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; export CI=1
pmbootstrap --no-cross --details-to-stdout -y install --split --password '$PW' 2>&1" > "$LOG" 2>&1
rc=$?

echo "### install rc=$rc"
echo "=== errors ==="
grep -aE 'ERROR|Traceback|fatal' "$LOG" | sed 's/\x1b\[[0-9;]*m//g' | head -20
echo
echo "=== tail ==="
tail -30 "$LOG" | sed 's/\x1b\[[0-9;]*m//g'
echo
echo "=== images ==="
find /home/baofanting/marble-build/work -name 'xiaomi-marble-*.img' -exec ls -lh {} \; 2>/dev/null
exit $rc
