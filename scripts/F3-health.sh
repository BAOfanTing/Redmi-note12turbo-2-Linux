#!/bin/sh
# marble health check (run on device)
echo "===== PARTITIONS ====="
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null | grep -E 'NAME|sda3[2-4]'
echo
df -h / /boot 2>/dev/null
echo
echo "===== FAILED UNITS ====="
systemctl --failed --no-legend 2>/dev/null
echo "(empty above = no failures)"
echo
echo "===== SERVICES ====="
for s in sshd NetworkManager systemd-timesyncd avahi-daemon buffyboard; do
  printf '%-24s %s / %s\n' "$s" "$(systemctl is-active $s 2>/dev/null)" "$(systemctl is-enabled $s 2>/dev/null)"
done
echo
echo "===== WIFI ====="
ip -4 addr show wlan0 2>/dev/null | grep inet
nmcli -t -f GENERAL.STATE,IP4.ADDRESS device show wlan0 2>/dev/null | head -4
iw dev wlan0 link 2>/dev/null | head -6
echo
echo "===== TEMPERATURE ====="
for z in /sys/class/thermal/thermal_zone*; do
  t=$(cat "$z/temp" 2>/dev/null) || continue
  n=$(cat "$z/type" 2>/dev/null)
  printf '  %-20s %s C\n' "$n" "$((t/1000))"
done | head -12
echo
echo "===== BATTERY ====="
for f in capacity status current_now voltage_now; do
  printf '  %-12s %s\n' "$f" "$(cat /sys/class/power_supply/battery/$f 2>/dev/null)"
done
echo
echo "===== ATH11K FIRMWARE ====="
dmesg 2>/dev/null | grep -i ath11k | tail -4
echo
echo "===== CPU / MEM ====="
nproc
free -h | head -2
echo
echo "===== KERNEL ====="
uname -a
