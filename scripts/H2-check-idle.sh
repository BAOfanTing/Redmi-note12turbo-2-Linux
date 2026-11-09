#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 熄屏状�?====="
R '/usr/local/bin/marble-screen.sh status'

echo
echo "===== idle 服务最近日�?====="
R 'journalctl -u marble-screen-idle -n 10 --no-pager | tail -8'

echo
echo "===== 电源�?logind 配置是否已生�?====="
R 'ls -l /etc/systemd/logind.conf.d/'
R 'systemctl show systemd-logind -p DropInPaths --value'
R 'grep -E "HandlePowerKey" /etc/systemd/logind.conf 2>/dev/null; grep -rE "HandlePowerKey" /etc/systemd/logind.conf.d/ 2>/dev/null'

echo
echo "===== logind 是否需要重启才读取 drop-in ====="
R 'systemctl show systemd-logind -p ActiveEnterTimestamp --value'

echo
echo "===== 上次输入活动时间 ====="
R 'date +%s; cat /run/marble-dashboard/last-activity'
