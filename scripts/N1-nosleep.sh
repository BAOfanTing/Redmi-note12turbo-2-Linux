#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 当前是否有挂起策略 ====="
echo "  logind IdleAction:"; R 'grep -E "IdleAction|HandleLidSwitch" /etc/systemd/logind.conf /etc/systemd/logind.conf.d/* 2>/dev/null | grep -v "^#" | grep -v ":#"'
echo "  sleep 相关 target 状态:"
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
    printf '    %-22s %s\n' "$t" "$(systemctl is-enabled $t 2>/dev/null)"
done
echo "  phosh 电源设置:"
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 2>/dev/null'
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 2>/dev/null'

echo
echo "===== 2. 加固：禁止自动挂起（服务器必须永不睡）====="
R 'systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>&1 | tail -4'
echo "  --- 结果 ---"
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
    printf '    %-22s %s\n' "$t" "$(systemctl is-enabled $t 2>/dev/null)"
done

echo
echo "===== 3. logind 也关掉空闲动作 ====="
R 'mkdir -p /etc/systemd/logind.conf.d'
R 'printf "[Login]\nIdleAction=ignore\nHandleLidSwitch=ignore\nHandleSuspendKey=ignore\n" > /etc/systemd/logind.conf.d/99-marble-nosleep.conf'
R 'cat /etc/systemd/logind.conf.d/99-marble-nosleep.conf'
R 'systemctl restart systemd-logind 2>/dev/null; echo "  logind restarted rc=$?"'

echo
echo "===== 4. phosh 里也把自动休眠关掉（AC 供电时）====="
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "nothing" 2>&1'
R 'sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 2>&1'

echo
echo "===== 5. 确认 SSH 仍然在线 ====="
systemctl is-active sshd
ip -4 -o addr show wlan0 | awk '{print "  wlan0 "$4}'
