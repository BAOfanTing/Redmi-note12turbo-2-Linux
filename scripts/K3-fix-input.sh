#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 安装更新后的 kiosk 单元 ====="
R 'install -Dm644 /tmp/dashboard/marble-dashboard-kiosk.service /etc/systemd/system/marble-dashboard-kiosk.service'
R 'grep -E "WLR_LIBINPUT_NO_DEVICES" /etc/systemd/system/marble-dashboard-kiosk.service'

echo
echo "===== 2. 重启 kiosk（让 cage 不再独占输入）====="
R 'systemctl daemon-reload'
R 'systemctl restart marble-dashboard-kiosk'
sleep 8
echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"

echo
echo "===== 3. 现在谁还占着 input 设备 ====="
for p in $(R 'ls /proc | grep -E "^[0-9]+$"'); do
    n=$(R "ls -l /proc/$p/fd 2>/dev/null | grep -c 'input/event'")
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
        cmd=$(R "tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null" | cut -c1-55)
        echo "  pid=$p ($n 个) $cmd"
    fi
done
echo "  （cage 应该已经不在列表里，或者不再是 6 个）"

echo
echo "===== 4. idle 服务是否还在正常读 ====="
R 'journalctl -u marble-screen-idle -n 6 --no-pager | tail -4'
R '/usr/local/bin/marble-screen.sh status'
