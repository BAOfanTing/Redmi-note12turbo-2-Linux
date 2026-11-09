#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 当前服务/屏幕状态（刚才部署被打断，先确认一致性）====="
for u in marble-dashboard marble-dashboard-kiosk marble-screen-idle seatd; do
    printf '  %-26s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)"
done
echo -n "  BLANK_MODE 配置: "; R 'grep BLANK_MODE /etc/systemd/system/marble-screen-idle.service.d/override.conf 2>/dev/null || echo "(无 override)"'
echo -n "  marble-screen.sh 版本: "; R 'grep -c "wlr-randr" /usr/local/bin/marble-screen.sh'
R '/usr/local/bin/marble-screen.sh status'

echo
echo "===== 桌面 UI 包可用性 ====="
for p in postmarketos-ui-phosh postmarketos-ui-plasma-mobile postmarketos-ui-gnome-mobile postmarketos-ui-sxmo-de-sway; do
    r=$(R apk search -x "$p" 2>/dev/null | head -1)
    if [ -n "$r" ]; then
        sz=$(R apk info -s "$p" 2>/dev/null | sed -n '2p')
        echo "  有: $r"
        echo "       $sz"
    else
        echo "  无: $p"
    fi
done

echo
echo "===== phosh 本体 ====="
for p in phosh phoc phosh-mobile-settings; do
    r=$(R apk search -x "$p" 2>/dev/null | head -1)
    [ -n "$r" ] && echo "  有: $r" || echo "  无: $p"
done

echo
echo "===== 磁盘/内存 ====="
df -h / | tail -1
free -h | head -2

echo
echo "===== GPU / DRM 状态 ====="
R 'ls /dev/dri/'
R 'dmesg 2>/dev/null | grep -iE "msm|adreno|freedreno" | tail -4'
