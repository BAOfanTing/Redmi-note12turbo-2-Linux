# 在局域网里找手机：ping 扫描 + ARP 对比 + 探测 22 端口 + mDNS
$ErrorActionPreference = 'SilentlyContinue'
$subnet = '192.168.1'
$deadline = (Get-Date).AddMinutes(4)
$baseline = @{}

# 基线 ARP
function Get-ArpMap {
    $map = @{}
    $out = (arp -a) -join "`n"
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match '^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F-]{17})') {
            $map[$matches[1]] = $matches[2].ToUpper()
        }
    }
    return $map
}

$baseline = Get-ArpMap
"基线 ARP 条目数: $($baseline.Count)"

function Test-Port22($ip) {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $t = $c.ConnectAsync($ip, 22)
        if ($t.Wait(700) -and $c.Connected) { return $true }
    } catch {}
    finally { $c.Close() }
    return $false
}

$round = 0
while ((Get-Date) -lt $deadline) {
    $round++
    "[第 $round 轮 $(Get-Date -Format 'HH:mm:ss')] ping 扫描 $subnet.0/24 ..."

    # 并行 ping
    $tasks = @()
    for ($i = 1; $i -le 254; $i++) {
        $p = New-Object System.Net.NetworkInformation.Ping
        $tasks += [pscustomobject]@{ IP = "$subnet.$i"; Task = $p.SendPingAsync("$subnet.$i", 500) }
    }
    [Threading.Tasks.Task]::WaitAll(($tasks | ForEach-Object { $_.Task }), 6000) | Out-Null

    $alive = $tasks | Where-Object { $_.Task.Status -eq 'RanToCompletion' -and $_.Task.Result.Status -eq 'Success' } | ForEach-Object { $_.IP }
    "  在线主机: $($alive.Count)"

    $arp = Get-ArpMap
    $new = $arp.Keys | Where-Object { -not $baseline.ContainsKey($_) }

    # 新增 ARP 条目里找开 22 端口的
    $hits = @()
    foreach ($ip in $new) {
        if (Test-Port22 $ip) { $hits += $ip }
    }
    # 全部在线主机里也扫一遍 22（基线里可能有但那是别的机器）
    if (-not $hits) {
        foreach ($ip in $alive) { if (Test-Port22 $ip) { $hits += $ip } }
    }

    if ($new) { "  ARP 新条目: " + ($new -join ', ') }
    if ($hits) {
        "  ★ 检测到开放 22 端口: " + (($hits | Sort-Object -Unique) -join ', ')
        foreach ($h in ($hits | Sort-Object -Unique)) {
            $mac = if ($arp.ContainsKey($h)) { $arp[$h] } else { '?' }
            "     $h  MAC=$mac"
        }
        break
    }
    Start-Sleep -Seconds 10
}

"`n=== mDNS 试探 marble.local ==="
(Resolve-DnsName -Name 'marble.local' -ErrorAction SilentlyContinue | Select-Object Name,IPAddress | Format-Table -AutoSize | Out-String)
(ping -n 1 -w 1000 marble.local 2>&1 | Select-Object -First 3 | Out-String)
