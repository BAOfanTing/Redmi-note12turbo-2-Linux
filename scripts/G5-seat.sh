#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== seatd / weston 可用�?====="
for p in seatd weston cage slurp grim; do
    r=$(S apk search -x "$p" 2>/dev/null | head -1)
    if [ -n "$r" ]; then echo "  �? $r"; else echo "  �? $p"; fi
done

echo
echo "===== libseat 支持的后�?====="
strings /usr/lib/libseat.so* 2>/dev/null | grep -iE '^(seatd|logind|builtin|noop)$' | sort -u
for f in /usr/lib/libseat*.so*; do
    [ -e "$f" ] || continue
    echo "  --- $f ---"
    strings "$f" 2>/dev/null | grep -iE 'seatd|logind|builtin|noop' | sort -u | head
done

echo
echo "===== logind 是否在跑（libseat 可用 logind 后端�?===="
systemctl is-active systemd-logind
ls -l /run/systemd/seats/ 2>/dev/null

echo
echo "===== 当前图形会话/seat ====="
command -v loginctl && S loginctl list-sessions 2>&1 | head -5
S loginctl list-seats 2>&1 | head -5
