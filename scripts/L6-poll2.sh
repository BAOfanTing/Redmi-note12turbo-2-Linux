#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "状态: $(systemctl is-active phosh-install 2>/dev/null) / $(systemctl is-failed phosh-install 2>/dev/null)"
echo "已装包数: $(R 'apk info 2>/dev/null | wc -l')  (装前 504)"
echo "磁盘: $(df -h / | tail -1 | awk '{print $3" used / "$4" free"}')"
echo
echo "最近 8 行:"
R 'journalctl -u phosh-install -n 8 --no-pager 2>/dev/null | sed "s/.*apk\[[0-9]*\]: //"' | tail -8
