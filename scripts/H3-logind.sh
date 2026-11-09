#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 重启 logind �?drop-in 生效 ====="
R 'systemctl restart systemd-logind'
sleep 3

echo
echo "===== 确认 logind 已读�?drop-in ====="
R 'systemctl show systemd-logind -p DropInPaths --value'
R 'systemd-analyze cat-config systemd/logind.conf 2>/dev/null | grep -E "HandlePowerKey|HandleSuspendKey" | tail -6'

echo
echo "===== 实际生效值（busctl�?===="
R 'busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey 2>/dev/null'

echo
echo "===== 服务全绿检�?====="
for u in sshd NetworkManager seatd marble-dashboard marble-dashboard-kiosk marble-screen-idle avahi-daemon; do
    printf '  %-28s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)"
done
echo "--- failed units ---"
R 'systemctl --failed --no-legend'
