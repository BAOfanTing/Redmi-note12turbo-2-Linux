#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 改成 default_session 直接跑 phosh-session（免登录）====="
R 'cp -n /etc/phrog/greetd-config.toml /etc/phrog/greetd-config.toml.bak2'
R 'cat > /etc/phrog/greetd-config.toml <<EOF
[terminal]
vt = 7

# 直接以 marble 身份启动 phosh 桌面（自动登录，不需要登录器）
# 想恢复登录界面：把 command 改回 "/usr/libexec/phrog-greetd-session"、user 改回 "greetd"
[default_session]
command = "phosh-session"
user = "marble"
EOF'
R 'cat /etc/phrog/greetd-config.toml'

echo
echo "===== 2. 重启 greetd ====="
R 'systemctl restart greetd'
echo "  等待 30 秒让 phosh 桌面起来..."
sleep 30

echo
echo "===== 3. 进程检查 ====="
for p in greetd phoc phosh gnome-shell gnome-session; do
    n=$(R "pgrep -af '$p' 2>/dev/null | grep -v pgrep | wc -l")
    printf '  %-16s %s\n' "$p" "$n"
done
echo "  --- 详情 ---"
R 'pgrep -af "phoc|phosh|gnome-shell" 2>/dev/null | cut -c1-90 | head -6'

echo
echo "===== 4. 会话 ====="
R 'loginctl list-sessions --no-legend 2>/dev/null'

echo
echo "===== 5. wayland socket ====="
R 'ls -l /run/user/10000/ 2>/dev/null | grep -i wayland || echo "  uid10000 无 wayland"'

echo
echo "===== 6. 截图 ====="
R 'env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-phosh.png 2>&1; ls -l /tmp/shot-phosh.png 2>/dev/null || echo "  截图失败"'

echo
echo "===== 7. 如果失败，看 greetd 日志 ====="
R 'journalctl -u greetd -n 12 --no-pager 2>/dev/null | tail -12'
