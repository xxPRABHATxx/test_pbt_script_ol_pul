@echo off
title IP Ping Statistics and DNS Manager
color 0A
REM ---- needs Administrator to change DNS; re-launch elevated once ----
fltmc >nul 2>&1 && goto :admin
if /i "%~1"=="/elevated" goto :noadmin
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/elevated' -Verb RunAs"
if errorlevel 1 (echo Elevation was cancelled. & pause)
exit /b
:noadmin
echo Administrator rights are required to change DNS settings.
pause
exit /b 1
:admin
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SELF); $i=$t.IndexOf('##PS'+'BEGIN##'); & ([scriptblock]::Create($t.Substring($i)))"
exit /b
##PSBEGIN##
# =====================================================================
#  IP Ping Statistics + DNS Manager   (PowerShell part, runs from the .cmd above)
#  Put .txt files (one IP per line, '#' = comment) next to this script.
# =====================================================================

# ---------------- CONFIG ----------------
$AdapterName = ''             # '' = auto-detect the adapter that carries the default route; or 'Ethernet' / 'Wi-Fi'
$Rounds      = 4              # probes per server
$TimeoutMs   = 1000           # per-probe timeout
$Threads     = 64             # servers probed at the same time (one thread each)
$ConnPort    = 443            # CONN ms = TCP connect time to this port on the address the DNS server returned
$ConnTimeoutMs = 1500         # TCP connect timeout
$ProbeName   = 'example.com'  # name used in the DNS test query
# ----------------------------------------

$Host.UI.RawUI.WindowTitle = 'IP Ping Statistics and DNS Manager'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ScriptDir = Split-Path -Parent $env:SELF
$DataDir   = Join-Path $env:LOCALAPPDATA 'PingDnsManager'
$GeoCache  = Join-Path $DataDir 'geo_cache.json'

$script:GeoOffline = $false
$script:Results    = @()
$script:Ips        = @()
$script:IpFile     = ''
$script:BadLines   = 0
$script:Elapsed    = 0
$script:Adapter    = ''
$script:CurDns     = @()
$script:Status     = ''

# ---------------- helpers ----------------
function Wait-Key { Write-Host ''; Write-Host 'Press any key to continue...'; [void][Console]::ReadKey($true) }

function Fit([string]$s, [int]$w) {
    $s = $s -replace '[\x00-\x1f]', ' '
    if ($s.Length -gt $w) { $s.Substring(0, $w) } else { $s }
}

function Fmt($v) { if ($null -eq $v) { '-' } else { "$v" } }

function Get-ActiveAdapter {
    if ($AdapterName) { return $AdapterName }
    $r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
         Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1
    if ($r) { return $r.InterfaceAlias }
    return 'Ethernet'
}

function Get-CurrentDns {
    $a = Get-DnsClientServerAddress -InterfaceAlias $script:Adapter -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($a) { @($a.ServerAddresses | Where-Object { $_ }) } else { @() }
}

# ---------------- IP list ----------------
function Select-IpFile {
    $files = @(Get-ChildItem -LiteralPath $ScriptDir -Filter *.txt -File | Sort-Object Name)
    if (-not $files.Count) {
        Clear-Host
        Write-Host 'No .txt files found in this folder.'
        Write-Host ''
        Write-Host 'Create a text file beside this script (e.g. dns-google.txt) with one IP per line.'
        Write-Host 'Lines starting with # are ignored.'
        Wait-Key
        return $null
    }
    if ($files.Count -eq 1) { return $files[0].FullName }
    while ($true) {
        Clear-Host
        Write-Host '====================================='
        Write-Host '        SELECT IP LIST FILE'
        Write-Host '====================================='
        Write-Host ''
        for ($i = 0; $i -lt $files.Count; $i++) { Write-Host ('{0}. {1}' -f ($i + 1), $files[$i].Name) }
        Write-Host ''
        Write-Host 'Q. Exit'
        Write-Host ''
        $c = Read-Host 'Choose an IP list'
        if ($c -match '^[qQ]$') { return $null }
        if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $files.Count) { return $files[[int]$c - 1].FullName }
        Write-Host 'Invalid selection.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}

function Read-IpList([string]$Path) {
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $list = New-Object 'System.Collections.Generic.List[string]'
    $script:BadLines = 0
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $t = ($line -replace '#.*$', '').Trim()
        if (-not $t) { continue }
        $tok  = ($t -split '[\s,;]+')[0]
        $addr = $null
        if ($tok -match '^\d{1,3}(\.\d{1,3}){3}$' -and [System.Net.IPAddress]::TryParse($tok, [ref]$addr)) {
            if ($seen.Add($addr.ToString())) { $list.Add($addr.ToString()) }
        } else { $script:BadLines++ }
    }
    $script:Ips = $list.ToArray()
}

# ---------------- probing ----------------
# One job per server, each in its own thread. Every ping, DNS lookup and TCP connect is timed by a
# blocking call, so the number is taken the moment the answer arrives (no batching delay in the times).
$Worker = {
    param([string]$Ip, [int]$Rounds, [int]$TimeoutMs, [string]$QName, [int]$Port, [int]$ConnLimitMs)

    function Skip-Name([byte[]]$d, [int]$p) {
        while ($p -lt $d.Length) {
            $l = $d[$p]
            if ($l -eq 0) { return ($p + 1) }
            if (($l -band 0xC0) -eq 0xC0) { return ($p + 2) }
            $p += $l + 1
        }
        return $p
    }

    # One A lookup sent straight to $Server on UDP port 53. Returns @{Ms; Addr} or $null.
    function Query-A([string]$Server, [string]$Name, [int]$LimitMs) {
        $udp = $null
        try {
            $rid = Get-Random -Minimum 1 -Maximum 65535
            $hi = [byte]($rid -shr 8)
            $lo = [byte]($rid -band 255)
            $q = New-Object System.Collections.Generic.List[byte]
            $q.Add($hi)
            $q.Add($lo)
            $q.AddRange([byte[]](1, 0, 0, 1, 0, 0, 0, 0, 0, 0))
            foreach ($label in $Name.Split('.')) {
                $lb = [System.Text.Encoding]::ASCII.GetBytes($label)
                $q.Add([byte]$lb.Length)
                $q.AddRange($lb)
            }
            $q.AddRange([byte[]](0, 0, 1, 0, 1))
            $pkt = $q.ToArray()
            $udp = New-Object System.Net.Sockets.UdpClient
            $udp.Client.ReceiveTimeout = $LimitMs
            $udp.Client.SendTimeout = $LimitMs
            $udp.Connect($Server, 53)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            [void]$udp.Send($pkt, $pkt.Length)
            $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            $r = $udp.Receive([ref]$ep)
            $sw.Stop()
            # valid reply: same ID, QR bit set, RCODE = 0 (NOERROR)
            if ($r.Length -lt 12 -or $r[0] -ne $hi -or $r[1] -ne $lo) { return $null }
            if (($r[2] -band 0x80) -eq 0) { return $null }
            if (($r[3] -band 0x0F) -ne 0) { return $null }
            $qd = ($r[4] * 256) + $r[5]
            $an = ($r[6] * 256) + $r[7]
            $p = 12
            for ($i = 0; $i -lt $qd; $i++) { $p = Skip-Name $r $p; $p += 4 }
            for ($i = 0; $i -lt $an; $i++) {
                $p = Skip-Name $r $p
                $type = ($r[$p] * 256) + $r[$p + 1]
                $rdlen = ($r[$p + 8] * 256) + $r[$p + 9]
                $p += 10
                if ($type -eq 1 -and $rdlen -eq 4) {
                    $text = '{0}.{1}.{2}.{3}' -f $r[$p], $r[$p + 1], $r[$p + 2], $r[$p + 3]
                    return @{ Ms = $sw.Elapsed.TotalMilliseconds; Addr = $text }
                }
                $p += $rdlen
            }
            return $null
        } catch {
            return $null
        } finally {
            if ($null -ne $udp) { $udp.Close() }
        }
    }

    $dns  = New-Object 'System.Collections.Generic.List[double]'
    $icmp = New-Object 'System.Collections.Generic.List[double]'
    $addr = $null
    for ($round = 0; $round -lt $Rounds; $round++) {
        $pinger = New-Object System.Net.NetworkInformation.Ping
        try {
            $reply = $pinger.Send($Ip, $TimeoutMs)
            if ($null -ne $reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $icmp.Add([double]$reply.RoundtripTime) }
        } catch { } finally { $pinger.Dispose() }

        $res = Query-A $Ip $QName $TimeoutMs
        if ($null -ne $res) { $dns.Add([double]$res.Ms); $addr = $res.Addr }

        # nothing came back in the first round: this server is down, do not spend more time on it
        if ($round -eq 0 -and $icmp.Count -eq 0 -and $dns.Count -eq 0) { break }
    }

    # CONN ms: TCP connect to the address this DNS server returned for the test name
    $connOut = $null
    if ($null -ne $addr -and $Port -gt 0) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $iar = $client.BeginConnect($addr, $Port, $null, $null)
            if ($iar.AsyncWaitHandle.WaitOne($ConnLimitMs) -and $client.Connected) {
                $client.EndConnect($iar)
                $watch.Stop()
                $connOut = [int][Math]::Round($watch.Elapsed.TotalMilliseconds)
            }
        } catch { } finally { $client.Close() }
    }

    $dnsOut = $null
    if ($dns.Count) { $dnsOut = [int][Math]::Round(($dns | Measure-Object -Average).Average) }
    $icmpOut = $null
    if ($icmp.Count) { $icmpOut = [int][Math]::Round(($icmp | Measure-Object -Average).Average) }
    [pscustomobject]@{
        Ip      = $Ip
        DnsAvg  = $dnsOut
        IcmpAvg = $icmpOut
        Conn    = $connOut
        Loss    = [int][Math]::Round(100.0 * ($Rounds - $dns.Count) / $Rounds)
    }
}

function Measure-Servers([string[]]$Ips) {
    $total    = $Ips.Count
    $nThreads = [Math]::Max(1, [Math]::Min($Threads, $total))
    $script1  = $Worker.ToString()
    $pool = [runspacefactory]::CreateRunspacePool(1, $nThreads)
    $pool.Open()
    $out = New-Object 'System.Collections.Generic.List[object]'
    try {
        # Jobs are queued ahead (twice the thread count) so the pool never waits; results stay in list order.
        $window    = $nThreads * 2
        $jobs      = New-Object 'object[]' $total
        $submitted = 0
        for ($done = 0; $done -lt $total; $done++) {
            while ($submitted -lt $total -and ($submitted - $done) -lt $window) {
                $shell = [powershell]::Create()
                $shell.RunspacePool = $pool
                [void]$shell.AddScript($script1)
                [void]$shell.AddArgument($Ips[$submitted])
                [void]$shell.AddArgument($Rounds)
                [void]$shell.AddArgument($TimeoutMs)
                [void]$shell.AddArgument($ProbeName)
                [void]$shell.AddArgument($ConnPort)
                [void]$shell.AddArgument($ConnTimeoutMs)
                $jobs[$submitted] = [pscustomobject]@{ Ip = $Ips[$submitted]; Shell = $shell; Handle = $shell.BeginInvoke() }
                $submitted++
            }
            $job = $jobs[$done]
            $jobs[$done] = $null
            $res = $null
            try {
                $o = @($job.Shell.EndInvoke($job.Handle))
                if ($o.Count -gt 0) { $res = $o[$o.Count - 1] }
            } catch { }
            try { $job.Shell.Dispose() } catch { }
            if ($null -eq $res) { $res = [pscustomobject]@{ Ip = $job.Ip; DnsAvg = $null; IcmpAvg = $null; Conn = $null; Loss = 100 } }
            $out.Add([pscustomobject]@{
                Ip       = $res.Ip
                DnsAvg   = $res.DnsAvg
                IcmpAvg  = $res.IcmpAvg
                ConnAvg  = $res.Conn
                Loss     = $res.Loss
                Provider = 'Unavailable'
                Location = 'Unavailable'
            })
            if ((($done + 1) % 10) -eq 0 -or ($done + 1) -eq $total) {
                Write-Host -NoNewline ("`r  Tested {0} of {1} servers ..." -f ($done + 1), $total)
            }
        }
    } finally {
        try { $pool.Close(); $pool.Dispose() } catch { }
    }
    Write-Host ''
    return $out.ToArray()
}

# ---------------- provider / location (cached on disk) ----------------
function Get-GeoInfo([string[]]$Ips) {
    $cache = @{}
    if (Test-Path -LiteralPath $GeoCache) {
        try {
            $saved = Get-Content -LiteralPath $GeoCache -Raw | ConvertFrom-Json
            foreach ($p in $saved.PSObject.Properties) {
                $cache[$p.Name] = @{ Provider = [string]$p.Value.Provider; Location = [string]$p.Value.Location }
            }
        } catch { }
    }
    $changed = $false
    $need = @($Ips | Where-Object { $_ -and -not $cache.ContainsKey($_) })

    if ($need.Count -and -not $script:GeoOffline) {
        for ($o = 0; $o -lt $need.Count; $o += 100) {
            $chunk = @($need[$o..([Math]::Min($o + 99, $need.Count - 1))])
            try {
                $ans = Invoke-RestMethod -Uri 'http://ip-api.com/batch?fields=status,country,regionName,city,isp,org,asname,query' `
                        -Method Post -Body (ConvertTo-Json -InputObject $chunk -Compress) -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
                foreach ($x in @($ans)) {
                    if ($x.status -ne 'success') { continue }
                    $prov = @($x.isp, $x.org, $x.asname) | Where-Object { $_ } | Select-Object -First 1
                    $loc  = (@($x.city, $x.regionName, $x.country) | Where-Object { $_ }) -join ', '
                    if ($prov -and $loc) { $cache[[string]$x.query] = @{ Provider = [string]$prov; Location = $loc }; $changed = $true }
                }
            } catch { $script:GeoOffline = $true; break }
        }
        # small fallback for anything ip-api could not answer
        if (-not $script:GeoOffline) {
            $left = @($need | Where-Object { -not $cache.ContainsKey($_) }) | Select-Object -First 15
            foreach ($ip in $left) {
                try {
                    $x    = Invoke-RestMethod -Uri "https://ipinfo.io/$ip/json" -TimeoutSec 5 -ErrorAction Stop
                    $prov = ([string]$x.org) -replace '^AS\d+\s+', ''
                    $loc  = (@($x.city, $x.region, $x.country) | Where-Object { $_ }) -join ', '
                    if ($prov -and $loc) { $cache[$ip] = @{ Provider = $prov; Location = $loc }; $changed = $true }
                } catch { }
            }
        }
    }
    if ($changed) {
        try {
            if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
            $cache | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $GeoCache -Encoding UTF8
        } catch { }
    }
    $out = @{}
    foreach ($ip in $Ips) {
        if ($cache.ContainsKey($ip)) { $out[$ip] = $cache[$ip] } else { $out[$ip] = @{ Provider = 'Unavailable'; Location = 'Unavailable' } }
    }
    return $out
}

function Invoke-Tests {
    Clear-Host
    Write-Host '====================================='
    Write-Host '        IP PING STATISTICS'
    Write-Host '====================================='
    Write-Host ''
    Write-Host ('Selected file: ' + (Split-Path -Leaf $script:IpFile))
    if ($script:BadLines) { Write-Host ("Skipped {0} line(s) that are not valid IPv4 addresses." -f $script:BadLines) -ForegroundColor Yellow }
    Write-Host ''
    $script:GeoOffline = $false
    $script:CurDns = @(Get-CurrentDns)
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $stats = @(Measure-Servers $script:Ips)
    $up = @($stats | Where-Object { $null -ne $_.DnsAvg -or $null -ne $_.IcmpAvg })
    if ($up.Count) {
        Write-Host '  Looking up provider / location ...'
        $geo = Get-GeoInfo @($up | ForEach-Object { $_.Ip })
        foreach ($r in $up) { $r.Provider = $geo[$r.Ip].Provider; $r.Location = $geo[$r.Ip].Location }
    }
    # keep the same order as the IP list file (no sorting)
    $script:Results = @($up)
    $script:Elapsed = [Math]::Round($clock.Elapsed.TotalSeconds, 1)
}

# ---------------- display ----------------
function Show-Results {
    $cur = @($script:CurDns)
    $W = 106
    $L = New-Object 'System.Collections.Generic.List[string]'
    $hot = New-Object 'System.Collections.Generic.HashSet[int]'
    $L.Add('=' * $W)
    $L.Add('                                  ONLINE DNS SERVER RESULTS')
    $L.Add('=' * $W)
    $L.Add(('List   : {0}   ({1} tested, {2} responding, {3}s)' -f (Split-Path -Leaf $script:IpFile), $script:Ips.Count, $script:Results.Count, $script:Elapsed))
    $L.Add(('Adapter: {0}     Current DNS: {1}' -f $script:Adapter, $(if ($cur.Count) { $cur -join ', ' } else { '(none / automatic)' })))
    $L.Add('')
    if (-not $script:Results.Count) {
        $L.Add('No server answered a ping or a DNS query.')
    } else {
        $fmt = '{0,-5}{1,-16}{2,8}{3,8}{4,8}{5,7}  {6,-22} {7}'
        $hdr = ($fmt -f 'REF', 'IP ADDRESS', 'CONN ms', 'DNS ms', 'PING ms', 'LOSS', 'PROVIDER', 'LOCATION')
        $n = $script:Results.Count
        $rowText = New-Object 'System.Collections.Generic.List[string]'
        $rowCur  = New-Object 'System.Collections.Generic.List[bool]'
        $ai = -1
        for ($j = 0; $j -lt $n; $j++) {
            $r = $script:Results[$j]
            $isCur = [bool]($cur -contains $r.Ip)
            if ($isCur -and $ai -lt 0) { $ai = $j }
            $mark = if ($isCur) { '*' } else { '' }
            $rowText.Add(($fmt -f ("{0}{1}" -f ($j + 1), $mark), $r.Ip, (Fmt $r.ConnAvg), (Fmt $r.DnsAvg), (Fmt $r.IcmpAvg), ("{0}%" -f $r.Loss), (Fit $r.Provider 22), (Fit $r.Location 30)))
            $rowCur.Add($isCur)
        }

        # the complete list, always
        $L.Add($hdr)
        $L.Add('-' * $W)
        for ($j = 0; $j -lt $n; $j++) {
            if ($rowCur[$j]) { [void]$hot.Add($L.Count) }
            $L.Add($rowText[$j])
        }

        # When the list is taller than the window, finish on the active DNS: its rows are repeated at the
        # very end, so after everything has loaded the screen is sitting on the active DNS (scroll up for the rest).
        $maxRows = 100000
        try { $maxRows = [Math]::Max(5, [Console]::WindowHeight - 21) } catch { }
        if ($n -gt $maxRows -and $ai -ge 0) {
            $first = [Math]::Max(0, [Math]::Min($ai - [int][Math]::Floor($maxRows / 2), $n - $maxRows))
            $last  = $first + $maxRows - 1
            $L.Add('=' * $W)
            $L.Add(('ACTIVE DNS: REF {0} of {1}   (REF {2}-{3} shown here, the full list is above)' -f ($ai + 1), $n, ($first + 1), ($last + 1)))
            $L.Add($hdr)
            $L.Add('-' * $W)
            for ($j = $first; $j -le $last; $j++) {
                if ($rowCur[$j]) { [void]$hot.Add($L.Count) }
                $L.Add($rowText[$j])
            }
        }
        $L.Add('')
        $L.Add('* = currently set (shown in bright cyan).  CONN ms = TCP connect time to the address that server returned for the test lookup.')
        $L.Add('DNS ms = answer time for a real DNS query.  PING ms = ICMP echo.  LOSS = % of DNS queries unanswered.')
    }
    if ($script:Status) { $L.Add(''); $L.Add($script:Status); $script:Status = '' }
    Clear-Host
    # plain lines go out in one block (fast); only the active rows are written separately, in colour
    $buf = New-Object 'System.Collections.Generic.List[string]'
    for ($k = 0; $k -lt $L.Count; $k++) {
        if ($hot.Contains($k)) {
            if ($buf.Count) { Write-Host ($buf -join "`n"); $buf.Clear() }
            Write-Host $L[$k] -ForegroundColor Cyan
        } else { $buf.Add($L[$k]) }
    }
    if ($buf.Count) { Write-Host ($buf -join "`n") }
}

# ---------------- DNS changes (fast: netsh with validate=no, no read-back, no pauses) ----------------
function Invoke-Netsh([string]$ArgLine) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo -ArgumentList 'netsh.exe', $ArgLine
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $o = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    [pscustomobject]@{ Code = $p.ExitCode; Out = $o.Trim() }
}

function Set-Dns([string[]]$Servers) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $q = '"' + $script:Adapter + '"'
    $r = Invoke-Netsh ('interface ipv4 set dnsservers name={0} source=static address={1} register=primary validate=no' -f $q, $Servers[0])
    for ($i = 1; $i -lt $Servers.Count -and $r.Code -eq 0; $i++) {
        $r = Invoke-Netsh ('interface ipv4 add dnsservers name={0} address={1} index={2} validate=no' -f $q, $Servers[$i], ($i + 1))
    }
    if ($r.Code -ne 0) {
        try { Set-DnsClientServerAddress -InterfaceAlias $script:Adapter -ServerAddresses $Servers -ErrorAction Stop }
        catch { $script:Status = 'FAILED to set DNS: ' + $_.Exception.Message + ' ' + $r.Out; return $false }
    }
    & ipconfig.exe /flushdns | Out-Null
    $script:CurDns = @($Servers)
    $script:Status = ('DNS set: {0}   ({1} ms)' -f ($Servers -join ', '), $clock.ElapsedMilliseconds)
    return $true
}

function Reset-Dns {
    $q = '"' + $script:Adapter + '"'
    $r = Invoke-Netsh ('interface ipv4 set dnsservers name={0} source=dhcp' -f $q)
    if ($r.Code -ne 0) {
        try { Set-DnsClientServerAddress -InterfaceAlias $script:Adapter -ResetServerAddresses -ErrorAction Stop }
        catch { $script:Status = 'FAILED to restore DNS: ' + $_.Exception.Message + ' ' + $r.Out; return }
    }
    & ipconfig.exe /flushdns | Out-Null
    $script:CurDns = @(Get-CurrentDns)
    $script:Status = 'DNS restored to automatic (DHCP).'
}

function Get-Best2 {
    @($script:Results | Where-Object { $null -ne $_.DnsAvg } | Sort-Object @{ Expression = { $_.Loss } }, @{ Expression = { $_.DnsAvg } } | Select-Object -First 2 | ForEach-Object { $_.Ip })
}

# Enter / Backspace on an empty prompt = step; quick repeated presses are merged into ONE move.
function Read-Choice([string]$Prompt) {
    Write-Host $Prompt -NoNewline
    $buf = ''
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Enter' -or ($k.Key -eq 'Backspace' -and $buf.Length -eq 0)) {
            if ($k.Key -eq 'Enter' -and $buf) { Write-Host ''; return $buf }
            $delta = if ($k.Key -eq 'Enter') { 1 } else { -1 }
            $until = [DateTime]::UtcNow.AddMilliseconds(100)
            while ([DateTime]::UtcNow -lt $until) {
                while ([Console]::KeyAvailable) {
                    $k2 = [Console]::ReadKey($true)
                    if ($k2.Key -eq 'Enter') { $delta++ } elseif ($k2.Key -eq 'Backspace') { $delta-- }
                }
                [Threading.Thread]::Sleep(5)
            }
            Write-Host ''
            return "STEP:$delta"
        }
        elseif ($k.Key -eq 'Escape') { Write-Host ''; return '0' }
        elseif ($k.Key -eq 'Backspace') {
            $buf = $buf.Substring(0, $buf.Length - 1)
            Write-Host "`b `b" -NoNewline
        }
        elseif ($k.KeyChar -match '^[0-9 ,]$') { $buf += $k.KeyChar; Write-Host $k.KeyChar -NoNewline }
        elseif ($k.KeyChar -match '^[bB]$' -and $buf.Length -eq 0) { Write-Host ''; return 'BEST' }
    }
}

function Invoke-SetDns {
    $n = $script:Results.Count
    if ($n -eq 0) { $script:Status = 'No responding servers to choose from.'; return }
    while ($true) {
        Show-Results
        Write-Host ''
        Write-Host 'Type a REF number (or two, e.g. "1 3" = primary + secondary).'
        Write-Host 'Enter = next server | Backspace = previous | B = the 2 fastest | Esc or 0 = back'
        $choice = Read-Choice 'REF: '
        if ($choice -eq '0') { return }

        $servers = @()
        $confirmed = $false
        if ($choice -like 'STEP:*') {
            $delta = [int]$choice.Substring(5)
            if ($delta -eq 0) { continue }
            $cur = @($script:CurDns)
            $idx = -1
            for ($i = 0; $i -lt $n; $i++) { if ($cur.Count -and $script:Results[$i].Ip -eq $cur[0]) { $idx = $i; break } }
            if ($idx -ge 0) { $start = $idx } elseif ($delta -gt 0) { $start = -1 } else { $start = 0 }
            $pick = ((($start + $delta) % $n) + $n) % $n
            $dir  = if ($delta -gt 0) { 1 } else { -1 }
            # servers that don't answer DNS are skipped unless you type y
            for ($t = 0; $t -lt $n; $t++) {
                $r = $script:Results[$pick]
                if ($null -ne $r.DnsAvg) { $servers = @($r.Ip); break }
                $yn = Read-Host ('{0} answers ping but not DNS. y = set it anyway, Enter = skip to next' -f $r.Ip)
                if ($yn -match '^[yY]') { $servers = @($r.Ip); break }
                $pick = (($pick + $dir) % $n + $n) % $n
            }
            $confirmed = $true
        }
        elseif ($choice -eq 'BEST') { $servers = Get-Best2 }
        else {
            $nums = @($choice -split '[\s,]+' | Where-Object { $_ })
            $bad  = ($nums.Count -eq 0 -or $nums.Count -gt 2)
            foreach ($x in $nums) { if ($x -notmatch '^\d+$' -or [int]$x -lt 1 -or [int]$x -gt $n) { $bad = $true } }
            if ($bad) { $script:Status = 'Invalid reference number.'; continue }
            $servers = @($nums | ForEach-Object { $script:Results[[int]$_ - 1].Ip } | Select-Object -Unique)
        }

        if (-not $servers.Count) {
            if (-not $confirmed) { $script:Status = 'No server answered a DNS query.' }
            continue
        }

        $warn = $false
        foreach ($s in $servers) { foreach ($r in $script:Results) { if ($r.Ip -eq $s -and $null -eq $r.DnsAvg) { $warn = $true } } }
        if ($warn -and -not $confirmed) {
            $yn = Read-Host 'A selected server answers ping but did not answer a DNS query. y = set it anyway, Enter = cancel'
            if ($yn -notmatch '^[yY]') { continue }
        }
        [void](Set-Dns $servers)
    }
}

# ---------------- main ----------------
function Main {
    $script:Adapter = Get-ActiveAdapter
    $quit = $false
    while (-not $quit) {
        $script:IpFile = Select-IpFile
        if (-not $script:IpFile) { break }
        Read-IpList $script:IpFile
        if (-not $script:Ips.Count) {
            Write-Host ('No valid IPv4 addresses found in ' + (Split-Path -Leaf $script:IpFile)) -ForegroundColor Yellow
            Wait-Key
            continue
        }
        Invoke-Tests
        $back = $false
        while (-not $back -and -not $quit) {
            Show-Results
            Write-Host ''
            Write-Host ('=' * 50)
            Write-Host '1. Set DNS on this adapter (pick from list)'
            Write-Host '2. Restore DNS to automatic (DHCP)'
            Write-Host '3. Refresh results'
            Write-Host '4. Choose / reload IP list'
            Write-Host '5. Exit'
            Write-Host 'B. Set the 2 best servers (primary + secondary)'
            Write-Host ('=' * 50)
            $c = (Read-Host 'Select option').Trim()
            if     ($c -eq '1') { Invoke-SetDns }
            elseif ($c -eq '2') { Reset-Dns }
            elseif ($c -eq '3') { Invoke-Tests }
            elseif ($c -eq '4') { $back = $true }
            elseif ($c -eq '5' -or $c -match '^[qQ]$') { $quit = $true }
            elseif ($c -match '^[bB]$') {
                $best = Get-Best2
                if ($best.Count) { [void](Set-Dns $best) } else { $script:Status = 'No server answered a DNS query.' }
            }
            else { Write-Host 'Invalid option.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
    }
}

try { Main }
catch {
    Write-Host ''
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    Read-Host 'Press Enter to close' | Out-Null
}
