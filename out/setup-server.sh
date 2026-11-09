#!/usr/bin/env bash
# ============================================================================
# pmOS (marble) 首次启动后的初始化：SSH、时区、用户、温度监控、充电策略
# 在手机上以 root 执行：sudo ./setup-server.sh
# ============================================================================
set -euo pipefail

SSH_PORT="${SSH_PORT:-22}"
NEW_USER="${NEW_USER:-marble}"
AUTHORIZED_KEY="${AUTHORIZED_KEY:-}"   # 填入你的 ~/.ssh/id_ed25519.pub 内容

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 sudo 运行" >&2
    exit 1
fi

echo "=== 1/6 基础系统更新 ==="
apk update && apk upgrade

echo "=== 2/6 安装服务器常用包 ==="
apk add \
    openssh \
    htop \
    curl \
    wget \
    tmux \
    git \
    vim \
    zsh \
    tmux \
    tzdata \
    lm-sensors \
    sysbench \
    nginx \
    docker 2>/dev/null || true   # docker 在 Alpine 上可用，但需要内核支持；装不上就忽略

echo "=== 3/6 时区与主机名 ==="
setup-timezone -z Asia/Shanghai 2>/dev/null || cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hostname marble

echo "=== 4/6 创建用户并配置 SSH ==="
if ! getent passwd "$NEW_USER" >/dev/null; then
    adduser -D -s /bin/bash -G wheel "$NEW_USER"
    echo "为用户 $NEW_USER 设置密码："
    passwd "$NEW_USER"
fi

# 允许 wheel 组 sudo
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# SSH 配置
sed -i \
    -e 's/^#\?PermitRootLogin .*/PermitRootLogin no/' \
    -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' \
    -e 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' \
    /etc/ssh/sshd_config
rc-update add sshd default
rc-service sshd start || true

if [ -n "$AUTHORIZED_KEY" ]; then
    mkdir -p "/home/$NEW_USER/.ssh"
    echo "$AUTHORIZED_KEY" >> "/home/$NEW_USER/.ssh/authorized_keys"
    chmod 700 "/home/$NEW_USER/.ssh"
    chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
    chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
    echo "已写入 SSH 公钥"
fi

echo "=== 5/6 温度与电池监控 ==="
cat > /usr/local/bin/temp-monitor.sh <<'EOF'
#!/bin/sh
# 每 60 秒记录温度/电量，温度超过 55°C 打日志
while true; do
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -r "$zone/temp" ] || continue
        t=$(cat "$zone/temp" 2>/dev/null)
        echo "[$(date '+%F %T')] $zone: $((t/1000))°C"
    done
    cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    echo "[$(date '+%F %T')] battery: ${cap}%"
    sleep 60
done
EOF
chmod +x /usr/local/bin/temp-monitor.sh

echo "=== 6/6 充电策略提示 ==="
cat <<'EOF'
锂电池 7×24 插电会鼓包。建议：
  1. 用定时插座每天断电几小时（最稳妥）
  2. 或使用软件限制：充电到 80% 后触发断电提醒
  3. 加装小风扇 / 散热铜片，别让机身长期 >45°C

当前温度: 
EOF
for zone in /sys/class/thermal/thermal_zone*; do
    [ -r "$zone/temp" ] || continue
    t=$(cat "$zone/temp" 2>/dev/null)
    echo "  $zone: $((t/1000))°C"
done

echo
echo "=============================================================="
echo " 初始化完成。"
echo " - SSH: ssh $NEW_USER@<手机IP> -p $SSH_PORT"
echo " - 温度监控: /usr/local/bin/temp-monitor.sh"
echo " - 用 ip addr 查看 IP（Wi-Fi 或 USB 网络 172.16.42.1）"
echo "=============================================================="
