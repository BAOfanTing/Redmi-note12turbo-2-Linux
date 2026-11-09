#!/usr/bin/env bash
set -uo pipefail
echo "=== mirror.nura.eco root ==="
curl -sL --max-time 25 https://mirror.nura.eco/ | head -60
echo
echo "=== postmarketos/ listing ==="
curl -sL --max-time 25 https://mirror.nura.eco/postmarketos/ | grep -oE 'href="[^"]+"' | head -40
