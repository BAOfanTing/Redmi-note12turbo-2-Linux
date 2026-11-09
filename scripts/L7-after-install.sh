#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== phosh 装好后新增/启用的单元 ====="
R 'systemctl list-unit-files 2>/dev/null | grep -iE "greetd|phosh|phrog|graphical-session" '
echo
echo "===== 当前是否被自动启用 ====="
for u in greetd phosh phosh.service getty@tty1 getty@tty7; do
    printf '  %-14s active=%-9s enabled=%s\n' "$u" "$(systemctl is-active $u 2>/dev/null)" "$(systemctl is-enabled $u 2>/dev/null)"
done

echo
echo "===== greetd 配置 ====="
R 'cat /etc/greetd/config.toml 2>/dev/null | head -20'
R 'ls -l /etc/greetd/ 2>/dev/null'

echo
echo "===== 关键程序 ====="
for b in phosh phoc greetd phrog gnome-session; do
    p=$(R "command -v $b 2>/dev/null")
    [ -n "$p" ] && echo "  有: $b -> $p" || echo "  无: $b"
done

echo
echo "===== 我们面板现在的状态 ====="
for u in marble-dashboard marble-dashboard-kiosk marble-screen-idle; do
    printf '  %-26s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)"
done

echo
echo "===== 磁盘/内存 ====="
df -h / | tail -1
free -h | head -2
