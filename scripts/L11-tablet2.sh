#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 安装最新的 marble-mode.sh ====="
R 'install -Dm755 /tmp/dashboard/marble-mode.sh /usr/local/bin/marble-mode.sh'
echo -n "  已安装，检测逻辑版本: "; R 'grep -c "usr/libexec/phosh" /usr/local/bin/marble-mode.sh'

echo
echo "===== 2. 重写 greetd-config（去掉重复的 initial_session）====="
R 'if [ -f /etc/phrog/greetd-config.toml.bak ]; then cp /etc/phrog/greetd-config.toml.bak /etc/phrog/greetd-config.toml; fi'
R 'grep -q initial_session /etc/phrog/greetd-config.toml || printf "\n[initial_session]\ncommand = \"phosh-session\"\nuser = \"marble\"\n" >> /etc/phrog/greetd-config.toml'
R 'cat /etc/phrog/greetd-config.toml'

echo
echo "===== 3. 切到平板模式 ====="
R '/usr/local/bin/marble-mode.sh tablet'
echo "  等待 20 秒让桌面起来..."
sleep 20

echo
echo "===== 4. 进程检查 ====="
for p in greetd phrog-greetd-session phoc phosh-session; do
    n=$(pgrep -c -f "$p" 2>/dev/null || echo 0)
    printf '  %-24s %s\n' "$p" "$n"
done

echo
echo "===== 5. 模式状态 ====="
R '/usr/local/bin/marble-mode.sh status'

echo
echo "===== 6. Wayland socket ====="
R 'ls -l /run/user/10000/ | grep -i wayland || echo "  没有 wayland socket"'

echo
echo "===== 7. 截图 ====="
R 'env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/phosh-shot.png 2>&1; ls -l /tmp/phosh-shot.png 2>/dev/null || echo "  截图失败"'
