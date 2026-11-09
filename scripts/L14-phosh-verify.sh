#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 正确添加 initial_session（用行首匹配，避开注释）====="
R 'if grep -q "^\[initial_session\]" /etc/phrog/greetd-config.toml; then echo "already present"; else printf "\n[initial_session]\ncommand = \"phosh-session\"\nuser = \"marble\"\n" >> /etc/phrog/greetd-config.toml; echo "added"; fi'
R 'cat /etc/phrog/greetd-config.toml'

echo
echo "===== 2. 重启 greetd ====="
R 'systemctl restart greetd'
echo "  等待 25 秒让 phosh 桌面起来..."
sleep 25

echo
echo "===== 3. 进程（用 pgrep -af 数行，别再用 -c）====="
for p in greetd phoc phrog phosh-session gnome-shell; do
    n=$(R "pgrep -af '$p' 2>/dev/null | wc -l")
    printf '  %-16s %s\n' "$p" "$n"
done
echo "  --- 详情 ---"
R 'pgrep -af "phoc|phosh|phrog|gnome-shell" 2>/dev/null | cut -c1-95 | head -8'

echo
echo "===== 4. Wayland / 会话 ====="
R 'ls -l /run/user/10000/ 2>/dev/null | grep -i wayland || echo "  marble 会话还没有 wayland"'
R 'ls -l /run/user/110/ 2>/dev/null | grep -i wayland || echo "  greetd 会话没有 wayland"'
R 'loginctl list-sessions --no-legend 2>/dev/null'

echo
echo "===== 5. 截图 ====="
for d in 10000 110; do
    for s in wayland-0 wayland-1; do
        [ -S "/run/user/$d/$s" ] || continue
        R "env XDG_RUNTIME_DIR=/run/user/$d WAYLAND_DISPLAY=$s grim /tmp/shot-$d-$s.png 2>&1"
        if [ -s "/tmp/shot-$d-$s.png" ]; then
            echo "  成功: /tmp/shot-$d-$s.png ($(ls -l /tmp/shot-$d-$s.png | awk '{print $5}') 字节)"
        fi
    done
done
R 'ls -l /tmp/shot-*.png 2>/dev/null || echo "  仍无截图"'
