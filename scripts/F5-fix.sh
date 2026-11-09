#!/bin/sh
# marble: 扩容根文件系�?+ 排查电池
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
SUDO="echo $PW | sudo -S"

echo "===== 1. 扩容�?====="
df -h / | tail -1
resize2fs /dev/sda34 2>&1 || echo "  (需�?root，下面用 sudo 重试)"
echo "$PW" | sudo -S resize2fs /dev/sda34 2>&1 | tail -5

echo
echo "===== 2. 扩容�?====="
df -h / | tail -1

echo
echo "===== 3. 电池相关 sysfs ====="
echo "--- /sys/class/power_supply 目录 ---"
ls -1 /sys/class/power_supply/ 2>/dev/null
echo "--- 各设备的 type/uevent 关键�?---"
for d in /sys/class/power_supply/*; do
    [ -e "$d" ] || continue
    echo "  [$d]  type=$(cat $d/type 2>/dev/null)  name=$(cat $d/name 2>/dev/null)"
done
echo "--- 尝试常见字段 ---"
for f in capacity status current_now voltage_now present power_now; do
    for d in /sys/class/power_supply/*; do
        [ -r "$d/$f" ] || continue
        echo "  $(basename $d)/$f = $(cat $d/$f 2>/dev/null)"
    done
done

echo
echo "===== 4. 电源管理模块 ====="
lsmod 2>/dev/null | grep -iE 'battmgr|pmic|charger|qpnp|spmi' | head
echo "--- dmesg 电池/pmic ---"
dmesg 2>/dev/null | grep -iE 'battmgr|pm8350|charger|fuel' | tail -6

echo
echo "===== 5. 最终状�?====="
df -h / /boot | tail -3
