#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 容器/虚拟化相关包可用性 ====="
for p in podman distrobox docker qemu-aarch64 qemu-system-x86_64 systemd-container skopeo buildah; do
    r=$(R apk search -x "$p" 2>/dev/null | head -1)
    [ -n "$r" ] && echo "  有: $r" || echo "  无: $p"
done

echo
echo "===== 内核是否支持容器所需特性 ====="
for k in CONFIG_NAMESPACES CONFIG_CGROUPS CONFIG_CGROUP_PIDS CONFIG_OVERLAY_FS CONFIG_USER_NS CONFIG_SECCOMP CONFIG_VETH CONFIG_BRIDGE; do
    v=$(R "zcat /proc/config.gz 2>/dev/null | grep '^$k=' " )
    [ -n "$v" ] && echo "  $v" || echo "  $k = (config.gz 不可用，待查)"
done

echo
echo "===== 磁盘/内存余量 ====="
df -h / | tail -1
free -h | head -2

echo
echo "===== 已有 cgroup v2？====="
R 'mount | grep -c cgroup2'
R 'cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null'

echo
echo "===== 屏幕当前状态（判断电源键测试结果）====="
R '/usr/local/bin/marble-screen.sh status'
R 'journalctl -u marble-screen-idle -n 6 --no-pager | tail -5'
