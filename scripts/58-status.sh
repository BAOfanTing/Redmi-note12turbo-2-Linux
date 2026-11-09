#!/usr/bin/env bash
set -uo pipefail
LOG=/mnt/e/Cache/shuaji/logs/58-status.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] status check"

su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"
echo "=== pmbootstrap status ==="
pmbootstrap status 2>&1 | tail -40
echo
echo "=== deviceinfo_parse ==="
pmbootstrap deviceinfo_parse xiaomi-marble 2>&1 | head -40
' 2>&1

echo
echo "=== mirror reachability ==="
for u in http://mirror.postmarketos.org/postmarketos/ http://cdn.alpinelinux.org/ https://mirror.postmarketos.org/postmarketos/ ; do
    printf '%-55s %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 20 "$u")"
done
echo
echo "=== resolve mirror host ==="
getent hosts mirror.postmarketos.org 2>&1
