#!/usr/bin/env bash
set -uo pipefail
echo "=== repo info ==="
curl -s --max-time 30 https://api.github.com/repos/iLtanaka/firmware-xiaomi-marble | python3 -c 'import json,sys; d=json.load(sys.stdin); print("name:",d.get("name")); print("size(KB):",d.get("size")); print("branch:",d.get("default_branch"))'
echo
echo "=== latest release assets ==="
curl -s --max-time 30 https://api.github.com/repos/iLtanaka/firmware-xiaomi-marble/releases | python3 -c '
import json,sys
d=json.load(sys.stdin)
for r in d[:3]:
    print(r["tag_name"], r["name"])
    for a in r["assets"]:
        print("   ", a["name"], a["size"], a["browser_download_url"])
'
echo
echo "=== current partial download ==="
ls -l /home/baofanting/marble-build/work/cache_distfiles/ 2>/dev/null
