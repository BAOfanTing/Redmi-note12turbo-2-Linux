#!/bin/sh
echo "===== 网络连通性 ====="
ping -c 2 -W 2 <PHONE_IP> 2>&1 | tail -3

echo
echo "===== 22 端口 ====="
(echo > /dev/tcp/<PHONE_IP>/22) 2>/dev/null && echo "  22 开放" || echo "  22 不通（或在 WSL 里没有 /dev/tcp 支持）"
