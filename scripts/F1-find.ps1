$ErrorActionPreference = 'SilentlyContinue'
$subnet = '192.168.1'

function Get-ArpMap {
    $map = @{}
    $out = (arp -a) -join "`n"
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match '^\s+(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F-]{17})') {
            $map[$matches[1]] = $matches[2].ToUpper()
        }
    }
    return $map
}

function Test-Ssh($ip) {
    $c = New-Object System.Net.Sockets.TcpClient
    $ok = $false
    try {
        $t = $c.ConnectAsync($ip, 22)
        if ($t.Wait(800) -eq $true) {
            if ($c.Connected -eq $true) { $ok = $true }
        }
    } catch {
        $ok = $false
    }
    $c.Close()
    return $ok
}

Write-Output "=== 基线 ARP ==="
$base = Get-ArpMap
Write-Output ("  已有条目: " + $base.Count)

Write-Output "=== UDP 敲门，触发 ARP 解析 ==="
$udp = New-Object System.Net.Sockets.UdpClient
for ($i = 1; $i -le 254; $i++) {
    $b = [Text.Encoding]::ASCII.GetBytes('x')
    $udp.Send($b, 1, "$subnet.$i", 9) | Out-Null
}
$udp.Close()
Start-Sleep -Seconds 4

Write-Output "=== 对比 ARP ==="
$now = Get-ArpMap
$new = @()
foreach ($k in $now.Keys) {
    if (-not $base.ContainsKey($k)) { $new += $k }
}
Write-Output ("  新条目: " + ($new -join ', '))

Write-Output "=== 探测 22 端口（新条目优先，其次全部在线）==="
$cand = $new
if ($cand.Count -eq 0) { $cand = $now.Keys }
$hits = @()
foreach ($ip in $cand) {
    if (Test-Ssh $ip) {
        $hits += $ip
        Write-Output ("  ★ " + $ip + "  MAC=" + $now[$ip])
    }
}
if ($hits.Count -eq 0) { Write-Output "  未发现开放 22 的主机" }

Write-Output "=== mDNS: marble.local ==="
$r = Resolve-DnsName -Name 'marble.local' -ErrorAction SilentlyContinue
if ($r) { $r | Select-Object Name,IPAddress | Format-Table -AutoSize | Out-String } else { Write-Output "  解析失败" }
