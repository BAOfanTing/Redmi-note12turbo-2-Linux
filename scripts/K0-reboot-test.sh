#!/usr/bin/env bash
# 实测：重启后能否自己回到 Wi-Fi 并提供 SSH（完全不依赖电脑）
set -uo pipefail
export SSHPASS="${MARBLE_PASSWORD:?set it in secrets.sh}"
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o LogLevel=ERROR"

echo "=== 重启前状态 ==="
sshpass -e ssh $O marble@<PHONE_IP> 'uptime; ip -4 -o addr show wlan0 | awk "{print \$4}"'

echo
echo "=== 发起重启 ==="
sshpass -e ssh $O marble@<PHONE_IP> 'echo "$MARBLE_PASSWORD" | sudo -S systemctl reboot' 2>/dev/null
echo "  已发送 reboot"

echo
echo "=== 轮询等待重新上线（最多 4 分钟）==="
for i in $(seq 1 24); do
    sleep 10
    out=$(sshpass -e ssh $O marble@<PHONE_IP> 'echo BACK' 2>&1)
    if echo "$out" | grep -q BACK; then
        echo "  [第 $((i*10))s] SSH 已恢复 ✅"
        RECOVERED=1
        break
    fi
    echo "  [第 $((i*10))s] 还没起来..."
done

if [ "${RECOVERED:-0}" != "1" ]; then
    echo
    echo "!!! 4 分钟内没回来，尝试重新找 IP"
    exit 2
fi

echo
echo "=== 重启后完整状态 ==="
sshpass -e ssh $O marble@<PHONE_IP> '
echo "--- uptime（应为刚起来）---"; uptime
echo "--- IP ---"; ip -4 -o addr show wlan0 | awk "{print \$4}"
echo "--- DNS ---"; getent hosts dl-cdn.alpinelinux.org >/dev/null 2>&1 && echo OK || echo FAIL
echo "--- 服务 ---"
for u in sshd NetworkManager seatd marble-dashboard marble-dashboard-kiosk marble-screen-idle avahi-daemon; do
  printf "  %-26s %s\n" "$u" "$(systemctl is-active $u 2>/dev/null)"
done
echo "--- failed units ---"; systemctl --failed --no-legend
echo "--- 根分区 ---"; df -h / | tail -1
echo "--- 电池 ---"; cat /sys/class/power_supply/qcom-battmgr-bat/capacity
'
