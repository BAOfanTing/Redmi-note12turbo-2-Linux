#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== 候选浏览器包可用�?====="
for p in cog chromium netsurf netsurf-fb epiphany webkit2gtk-4.1 wpewebkit wpewebkit-dsp cog-dsp; do
    r=$(S apk search -x "$p" 2>/dev/null | head -2 | tr '\n' ' ')
    if [ -n "$r" ]; then echo "  �? $p  -> $r"; else echo "  �? $p"; fi
done

echo
echo "===== cage 版本 ====="
S apk info cage 2>/dev/null | head -3

echo
echo "===== chromium 大小 ====="
S apk info -s chromium 2>/dev/null | head -3

echo
echo "===== netsurf 大小 ====="
S apk info -s netsurf 2>/dev/null | head -3

echo
echo "===== 已装�?cage ====="
S apk info 2>/dev/null | grep -x cage && echo "  cage 已安�?
