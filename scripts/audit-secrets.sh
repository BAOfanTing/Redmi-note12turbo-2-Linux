#!/bin/sh
# ============================================================================
# audit-secrets.sh —— 检查仓库里有没有泄露敏感信息
#
#   ./scripts/audit-secrets.sh
#
# 从 secrets.sh（已被 gitignore）读取真实值，所以本脚本自身不含任何明文。
# 需要 git 可用；脚本会和「工作区被跟踪的文件」以及「全部 git 历史」比对。
# ============================================================================
set -u
cd "$(dirname "$0")/.." || exit 1

SECRETS=./secrets.sh
if [ ! -f "$SECRETS" ]; then
    echo "缺少 $SECRETS —— 先执行: cp secrets.example.sh secrets.sh 并填写" >&2
    exit 2
fi

# 取出变量值（只解析 KEY='value' 形式）
val() { sed -n "s/^[[:space:]]*$1='\(.*\)'.*/\1/p" "$SECRETS" | head -1; }

PATS=""
for k in MARBLE_PASSWORD PHONE_IP WIFI_SSID WIFI_PSK; do
    v=$(val "$k")
    [ -n "$v" ] && PATS="$PATS $k=$v"
done

leak=0

echo "===== 1. 被跟踪的文件 ====="
git ls-files -z | while IFS= read -r -d '' f; do echo "$f"; done > /tmp/_tracked.txt
for kv in $PATS; do
    k=${kv%%=*}; v=${kv#*=}
    hits=$(grep -IlF -- "$v" $(cat /tmp/_tracked.txt | tr '\n' ' ') 2>/dev/null | grep -v '^secrets' || true)
    if [ -n "$hits" ]; then
        echo "  !! $k 出现在:"
        echo "$hits" | sed 's/^/       /'
        leak=1
    else
        echo "  ok  $k 未出现在跟踪文件里"
    fi
done

echo
echo "===== 2. git 历史 ====="
for kv in $PATS; do
    k=${kv%%=*}; v=${kv#*=}
    n=$(git log -p --all 2>/dev/null | grep -cF -- "$v" || true)
    # 作者邮箱等身份信息会自带子串，单独说明
    if [ "${n:-0}" -gt 0 ]; then
        echo "  !! $k 在历史中出现 ${n} 次（若是你自己的 commit 邮箱请另外评估）"
        leak=1
    else
        echo "  ok  $k 未出现在历史里"
    fi
done

echo
echo "===== 3. 敏感路径 ====="
for bad in secrets.sh out/credentials.txt marble-backup tmp logs tools; do
    if git ls-files | grep -qx "$bad" || git ls-files | grep -q "^$bad/"; then
        echo "  !! 被跟踪: $bad"; leak=1
    else
        echo "  ok  未跟踪: $bad"
    fi
done

echo
if [ "$leak" = "0" ]; then
    echo "结论：未发现泄露 ✅"
else
    echo "结论：存在疑似泄露 ❌ 请看上面逐项"
fi
exit "$leak"
