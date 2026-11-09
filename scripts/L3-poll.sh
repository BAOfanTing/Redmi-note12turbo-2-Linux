#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 安装进度 ====="
if [ -f /tmp/phosh-done ]; then
    echo "  已完成，退出码: $(cat /tmp/phosh-done)"
else
    echo "  仍在进行..."
fi
echo "  日志行数: $(R 'wc -l < /tmp/phosh-install.log' 2>/dev/null)"
echo "  最近 6 行:"
R 'tail -6 /tmp/phosh-install.log' | sed 's/^/    /'
echo "  当前包数: $(R 'apk info 2>/dev/null | wc -l')"
echo "  磁盘: $(df -h / | tail -1 | awk "{print \$3\" used / \"\$4\" free\"}")"
