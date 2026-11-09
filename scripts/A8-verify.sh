#!/usr/bin/env bash
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
BOOT="$OUT/xiaomi-marble-boot.img"
ROOT="$OUT/xiaomi-marble-root.img"

echo "############ UUID 匹配检查 ############"
BUUID=$(blkid -p -o value -s UUID "$BOOT")
RUUID=$(blkid -p -o value -s UUID "$ROOT")
echo "boot img UUID      : $BUUID"
echo "root img UUID      : $RUUID"
echo "--- extlinux.conf 里声明的 ---"
debugfs -R "cat /extlinux/extlinux.conf" "$BOOT" 2>/dev/null | grep -oE 'pmos_(boot|root)_uuid=[0-9a-f-]+'
echo "--- 判定 ---"
debugfs -R "cat /extlinux/extlinux.conf" "$BOOT" 2>/dev/null | grep -q "$RUUID" \
    && echo "OK: root UUID 一致" || echo "!! MISMATCH: root UUID 不一致（会启动失败）"
debugfs -R "cat /extlinux/extlinux.conf" "$BOOT" 2>/dev/null | grep -q "$BUUID" \
    && echo "OK: boot UUID 一致" || echo "!! MISMATCH: boot UUID 不一致"

echo
echo "############ boot 分区关键文件 ############"
for f in /vmlinuz /initramfs /sm8475-xiaomi-marble.dtb /extlinux/extlinux.conf; do
    if debugfs -R "stat $f" "$BOOT" 2>/dev/null | grep -q 'Inode:'; then
        sz=$(debugfs -R "stat $f" "$BOOT" 2>/dev/null | awk '/Size:/{print $6}')
        printf '  OK   %-32s %s bytes\n' "$f" "$sz"
    else
        printf '  MISS %-32s\n' "$f"
    fi
done

echo
echo "############ root 分区关键内容 ############"
check() {
    if debugfs -R "stat $1" "$ROOT" 2>/dev/null | grep -q 'Inode:'; then
        printf '  OK   %s\n' "$1"
    else
        printf '  MISS %s\n' "$1"
    fi
}
echo "-- 系统基础 --"
check /etc/os-release
check /sbin/init
check /usr/lib/systemd/systemd
check /usr/bin/sshd
check /usr/bin/NetworkManager
check /boot
echo "-- UCM / 设备包文件 --"
check /usr/share/alsa/ucm2/Qualcomm/sm8450/xiaomi-marble/HiFi.conf
check /usr/share/alsa/ucm2/conf.d/sm8450/SM8475-Xiaomi-Marble.conf
check /usr/lib/udev/rules.d/81-libssc-xiaomi-marble.rules
check /usr/libexec/marble-touchboost
echo "-- 内核模块 --"
ls "$(dirname "$0")" >/dev/null 2>&1
debugfs -R "ls -l /usr/lib/modules" "$ROOT" 2>/dev/null | head -5

echo
echo "############ 固件（Wi-Fi 关键）############"
FWROOT=/lib/firmware
debugfs -R "ls -l $FWROOT" "$ROOT" 2>/dev/null | head -10
echo "--- qcom/sm8475/xiaomi/marble ---"
debugfs -R "ls -l $FWROOT/qcom/sm8475/xiaomi/marble" "$ROOT" 2>/dev/null | head -20
echo "--- WCN6855 (Wi-Fi/BT) ---"
debugfs -R "ls -l $FWROOT/qcom/sm8475/xiaomi/marble" "$ROOT" 2>/dev/null | grep -ci wcn6 \
    && echo "发现 WCN6855 相关固件" || echo "!! 未发现 WCN6855 固件（Wi-Fi 会不可用）"
debugfs -R "ls -l $FWROOT/ath11k/WCN6855/hw2.1" "$ROOT" 2>/dev/null | head -10

echo
echo "############ 已安装包清单抽样 ############"
debugfs -R "cat /lib/apk/db/installed" "$ROOT" 2>/dev/null | grep -E '^P:' | sed 's/^P://' | sort | head -60
echo "..."
echo -n "包总数: "
debugfs -R "cat /lib/apk/db/installed" "$ROOT" 2>/dev/null | grep -c '^P:'

echo
echo "############ 关键的 device / firmware 包是否在册 ############"
for p in device-xiaomi-marble device-xiaomi-marble-nonfree-firmware \
         firmware-xiaomi-marble-wlan firmware-xiaomi-marble-bluetooth \
         firmware-xiaomi-marble-adreno firmware-xiaomi-marble-modem \
         firmware-xiaomi-marble-adsp firmware-xiaomi-marble-slpi \
         linux-xiaomi-marble openssh networkmanager; do
    if debugfs -R "cat /lib/apk/db/installed" "$ROOT" 2>/dev/null | grep -qx "P:$p"; then
        printf '  OK   %s\n' "$p"
    else
        printf '  MISS %s\n' "$p"
    fi
done
