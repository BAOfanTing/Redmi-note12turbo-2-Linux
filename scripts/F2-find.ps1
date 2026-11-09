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

Write-Output "=== baseline ARP ==="
$base = Get-ArpMap
Write-Output ("  entries: " + $base.Count)

Write-Output "=== UDP knock to populate ARP ==="
$udp = New-Object System.Net.Sockets.UdpClient
for ($i = 1; $i -le 254; $i++) {
    $b = [Text.Encoding]::ASCII.GetBytes('x')
    $udp.Send($b, 1, "$subnet.$i", 9) | Out-Null
}
$udp.Close()
Start-Sleep -Seconds 4

Write-Output "=== ARP diff ==="
$now = Get-ArpMap
$new = @()
foreach ($k in $now.Keys) {
    if (-not $base.ContainsKey($k)) { $new += $k }
}
Write-Output ("  new: " + ($new -join ', '))

Write-Output "=== probe TCP 22 ==="
$cand = $new
if ($cand.Count -eq 0) { $cand = $now.Keys }
$hits = @()
foreach ($ip in $cand) {
    if (Test-Ssh $ip) {
        $hits += $ip
        Write-Output ("  HIT " + $ip + "  MAC=" + $now[$ip])
    }
}
if ($hits.Count -eq 0) { Write-Output "  no host with port 22" }

Write-Output "=== mDNS marble.local ==="
$r = Resolve-DnsName -Name 'marble.local' -ErrorAction SilentlyContinue
if ($r) {
    $r | Select-Object Name,IPAddress | Format-Table -AutoSize | Out-String | Write-Output
} else {
    Write-Output "  resolve failed"
}
