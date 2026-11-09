#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 给 greetd 加 initial_session（直接进 phosh，免屏幕输密码）====="
R 'cp -n /etc/phrog/greetd-config.toml /etc/phrog/greetd-config.toml.bak'
R 'printf "\n[initial_session]\ncommand = \"phosh-session\"\nuser = \"marble\"\n" >> /etc/phrog/greetd-config.toml'
R 'cat /etc/phrog/greetd-config.toml'

echo
echo "===== 2. 切到平板模式 ====="
R '/usr/local/bin/marble-mode.sh tablet'
sleep 15

echo
echo "===== 3. 检查进程 ====="
for p in greetd phrog-greetd-session phoc phosh phosh-session; do
    n=$(pgrep -c -f "$p" 2>/dev/null || echo 0)
    printf '  %-24s %s\n' "$p" "$n"
done
R 'pgrep -af "phoc|phosh|greetd" 2>/dev/null | cut -c1-100 | head -6'

echo
echo "===== 4. 模式状态 ====="
R '/usr/local/bin/marble-mode.sh status'

echo
echo "===== 5. 用户会话 ====="
R 'loginctl list-sessions 2>/dev/null'
echo "$PW" | sudo -S ls -la /run/user/10000/ 2>/dev/null | head -8

echo
echo "===== 6. 尝试截图 ====="
R 'env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/phosh-shot.png 2>&1; ls -l /tmp/phosh-shot.png 2>/dev/null'
