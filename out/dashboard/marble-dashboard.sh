#!/bin/sh
# ============================================================================
# marble-dashboard.sh —— 生成一个自包含的 HTML 状态面板
#
# 每 N 秒把当前系统状态写进 /run/marble-dashboard/index.html，
# 由 cage + cog（WPE WebKit kiosk 浏览器）全屏显示在手机屏幕上。
#
# 只依赖 busybox + 内核 sysfs，不需要 Python / Node。
# ============================================================================
set -u

OUTDIR="${OUTDIR:-/run/marble-dashboard}"
INTERVAL="${INTERVAL:-2}"
OUT="$OUTDIR/index.html"

mkdir -p "$OUTDIR"

# ---------------------------------------------------------------- 采集函数
num() { [ -r "$1" ] && cat "$1" 2>/dev/null || echo ""; }

cpu_load() {
    # /proc/loadavg 前三个数
    set -- $(cat /proc/loadavg)
    echo "$1 $2 $3"
}

cpu_freqs() {
    for c in /sys/devices/system/cpu/cpu[0-9]*; do
        f="$c/cpufreq/scaling_cur_freq"
        [ -r "$f" ] || continue
        printf '%s ' "$(( $(cat "$f") / 1000 ))"
    done
}

mem_info() {
    awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2}
         END {
            used = (t-a)/1024; tot = t/1024;
            printf "%.0f %.0f %.0f", used, tot, (tot>0 ? used*100/tot : 0)
            if (st>0) printf " %.0f %.0f", (st-sf)/1024, st/1024; else printf " 0 0"
         }' /proc/meminfo
}

temps() {
    n=0
    for z in /sys/class/thermal/thermal_zone*; do
        [ -r "$z/temp" ] || continue
        t=$(cat "$z/temp" 2>/dev/null) || continue
        [ -n "$t" ] || continue
        case "$t" in *[!0-9-]*) continue;; esac
        # 只显示能读出类型名的，且过滤掉明显无效值
        type=$(cat "$z/type" 2>/dev/null || basename "$z")
        c=$((t / 1000))
        [ "$c" -gt -20 ] && [ "$c" -lt 150 ] || continue
        printf '%s=%s ' "$type" "$c"
        n=$((n+1))
        [ "$n" -ge 6 ] && break
    done
}

batt() {
    # 不同内核/移植下设备名不一样：
    #   marble(mainline) -> /sys/class/power_supply/qcom-battmgr-bat
    #   其它常见         -> battery / BAT0 / bms
    # 所以按 type=Battery 自动找，别写死路径
    for b in /sys/class/power_supply/*; do
        [ -r "$b/type" ] || continue
        [ "$(cat "$b/type" 2>/dev/null)" = "Battery" ] || continue

        cap=$(num "$b/capacity"); st=$(num "$b/status")
        cur=$(num "$b/current_now")
        # current_now 单位 µA，转 mA 取绝对值
        ma="-"
        [ -n "$cur" ] && ma=$(( ${cur#-} / 1000 ))
        pw="-"
        p=$(num "$b/power_now")
        [ -n "$p" ] && pw=$(awk -v v="$p" 'BEGIN{printf "%.2f", (v<0?-v:v)/1000000}')
        echo "${cap:--} ${st:--} ${ma} ${pw}"
        return
    done
    echo "- - - -"
}

disks() {
    df -h 2>/dev/null | awk 'NR>1 && $1 ~ /^\/dev\// {
        printf "%s|%s|%s|%s ", $6, $2, $4, $5
    }'
}

netinfo() {
    for i in /sys/class/net/*; do
        n=$(basename "$i")
        [ "$n" = "lo" ] && continue
        s=$(cat "$i/operstate" 2>/dev/null)
        [ "$s" = "up" ] || continue
        ip=$(ip -4 -o addr show dev "$n" 2>/dev/null | awk '{print $4}' | head -1)
        printf '%s=%s ' "$n" "${ip:--}"
    done
}

svc_state() {
    for s in sshd nginx docker podman; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^$s\.service"; then
            st=$(systemctl is-active "$s" 2>/dev/null)
            printf '%s:%s ' "$s" "${st:-unknown}"
        fi
    done
}

# ---------------------------------------------------------------- HTML
read -r L1 L5 L15 <<EOF
$(cpu_load)
EOF

read -r MEM_USED MEM_TOTAL MEM_PCT SWAP_USED SWAP_TOTAL <<EOF
$(mem_info)
EOF

read -r BATT_CAP BATT_ST BATT_MA BATT_W <<EOF
$(batt)
EOF

HOST=$(hostname 2>/dev/null || echo marble)
KERNEL=$(uname -r)
UPTIME=$(uptime 2>/dev/null | sed 's/^ *//; s/,.*load/  load/' || echo "-")
NOW=$(date '+%Y-%m-%d %H:%M:%S')
FREQS=$(cpu_freqs)
TEMPS=$(temps)
DISKS=$(disks)
NETS=$(netinfo)
SVCS=$(svc_state)

# 温度着色
temp_color() {
    c=$1
    if [ "$c" -ge 70 ]; then echo "#ff4d4f"
    elif [ "$c" -ge 55 ]; then echo "#faad14"
    else echo "#52c41a"; fi
}

TEMPS_HTML=""
for kv in $TEMPS; do
    k=${kv%%=*}; v=${kv##*=}
    TEMPS_HTML="$TEMPS_HTML<div class=\"tile\"><div class=\"k\">${k}</div><div class=\"v\" style=\"color:$(temp_color "$v")\">${v}°C</div></div>"
done

DISKS_HTML=""
for d in $DISKS; do
    d=${d//|/ }
    set -- $d
    DISKS_HTML="$DISKS_HTML<div class=\"tile\"><div class=\"k\">$1</div><div class=\"v2\">$3 free / $2 ($4)</div></div>"
done

NETS_HTML=""
for nv in $NETS; do
    n=${nv%%=*}; v=${nv##*=}
    NETS_HTML="$NETS_HTML<div class=\"tile\"><div class=\"k\">${n}</div><div class=\"v2\">${v}</div></div>"
done

SVCS_HTML=""
for sv in $SVCS; do
    sv=${sv/:/ }
    set -- $sv
    col="#8c8c8c"
    [ "${2}" = "active" ] && col="#52c41a"
    SVCS_HTML="$SVCS_HTML<span class=\"pill\" style=\"border-color:${col};color:${col}\">${1} ${2}</span>"
done

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="zh"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta http-equiv="refresh" content="${INTERVAL}">
<title>$HOST</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  html,body { margin:0; padding:0; background:#000; color:#e6e6e6;
    font-family: ui-monospace,"DejaVu Sans Mono",monospace; }
  body { padding: 28px 24px 40px; }
  .hdr { display:flex; justify-content:space-between; align-items:baseline;
    border-bottom:1px solid #1f1f1f; padding-bottom:14px; margin-bottom:22px; }
  .host { font-size:34px; font-weight:700; letter-spacing:.5px; color:#40a9ff; }
  .clock { font-size:22px; color:#8c8c8c; }
  .sub { font-size:15px; color:#595959; margin-top:6px; }
  .grid { display:grid; grid-template-columns:repeat(2,1fr); gap:14px; }
  .tile { background:#0d0d0d; border:1px solid #1f1f1f; border-radius:14px;
    padding:16px 18px; }
  .k { font-size:15px; color:#7a7a7a; margin-bottom:8px; word-break:break-all; }
  .v { font-size:30px; font-weight:700; }
  .v2 { font-size:19px; color:#d9d9d9; word-break:break-all; }
  .big .v { font-size:44px; }
  .bar { height:10px; background:#1a1a1a; border-radius:6px; overflow:hidden; margin-top:10px; }
  .bar > i { display:block; height:100%; background:#40a9ff; }
  .row { margin-top:18px; }
  .pills { display:flex; flex-wrap:wrap; gap:10px; margin-top:8px; }
  .pill { border:1px solid #333; border-radius:999px; padding:6px 14px; font-size:15px; }
  .freqs { font-size:16px; color:#8c8c8c; margin-top:8px; letter-spacing:1px; }
  .ftr { position:fixed; left:24px; right:24px; bottom:16px; font-size:13px;
    color:#404040; display:flex; justify-content:space-between; }
</style>
</head><body>
  <div class="hdr">
    <div>
      <div class="host">$HOST</div>
      <div class="sub">Linux $KERNEL &nbsp;·&nbsp; $UPTIME</div>
    </div>
    <div class="clock">$NOW</div>
  </div>

  <div class="grid">
    <div class="tile big">
      <div class="k">负载 (1m / 5m / 15m)</div>
      <div class="v">$L1 <span style="font-size:22px;color:#8c8c8c">$L5 $L15</span></div>
      <div class="freqs">MHz: $FREQS</div>
    </div>
    <div class="tile big">
      <div class="k">内存</div>
      <div class="v">${MEM_PCT}%</div>
      <div class="bar"><i style="width:${MEM_PCT}%"></i></div>
      <div class="freqs">${MEM_USED} / ${MEM_TOTAL} MB &nbsp; swap ${SWAP_USED}/${SWAP_TOTAL} MB</div>
    </div>
    <div class="tile">
      <div class="k">电池</div>
      <div class="v">${BATT_CAP}%</div>
      <div class="freqs">${BATT_ST} &nbsp; ${BATT_MA} mA &nbsp; ${BATT_W} W</div>
    </div>
    <div class="tile">
      <div class="k">网络</div>
      <div class="v2">${NETS_HTML:-未连接}</div>
    </div>
    $TEMPS_HTML
  </div>

  <div class="row">
    <div class="k">磁盘</div>
    <div class="grid">$DISKS_HTML</div>
  </div>

  <div class="row">
    <div class="k">服务</div>
    <div class="pills">$SVCS_HTML</div>
  </div>

  <div class="ftr"><span>marble · postmarketOS/Nura</span><span>刷新 ${INTERVAL}s</span></div>
</body></html>
HTML

# 屏幕常亮 + 亮度（可选，失败忽略）
: "${BRIGHTNESS:=60}"
for bl in /sys/class/backlight/*; do
    [ -w "$bl/brightness" ] || continue
    max=$(cat "$bl/max_brightness" 2>/dev/null) || continue
    [ "$max" -gt 0 ] 2>/dev/null || continue
    echo $(( max * BRIGHTNESS / 100 )) > "$bl/brightness" 2>/dev/null || true
    break
done
