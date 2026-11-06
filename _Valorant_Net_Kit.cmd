@echo off
setlocal EnableExtensions
title Valorant Net Kit

rem ============================================================
rem VALORANT NET KIT
rem One tool: auto DNS optimizer, DNS list tools, manual DNS,
rem connection checks, tweaks and quick actions.
rem Usage:  Valorant_Net_Kit.cmd  [auto | kill | restore]
rem ============================================================

rem Remember where this CMD file is (ips.txt, the log and reports live next to it).
set "KIT_DIR=%~dp0"
set "SELF=%~f0"
set "ARG1=%~1"
set "MODE=%~1"
if /i "%ARG1%"=="elevated" set "MODE=%~2"

rem Request administrator privileges.
rem fltmc or net session only succeed when running as administrator.
set "ISADMIN="
fltmc >nul 2>&1 && set "ISADMIN=1"
if not defined ISADMIN net session >nul 2>&1 && set "ISADMIN=1"

if not defined ISADMIN (
    if /i "%ARG1%"=="elevated" (
        echo.
        echo FATAL ERROR: Could not get administrator privileges.
        pause
        exit /b 1
    )

    echo Requesting administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:SELF -ArgumentList ('elevated ' + $env:MODE) -Verb RunAs"

    if errorlevel 1 (
        echo.
        echo Administrator permission was not granted.
        pause
    )

    exit /b
)

rem Remove temporary scripts left behind by earlier runs.
del "%TEMP%\ValorantKit_*.ps1" >nul 2>&1

rem Extract embedded PowerShell to a temporary file.
set "PSFILE=%TEMP%\ValorantKit_%RANDOM%_%RANDOM%.ps1"
set "MARKERLINE="

for /f "tokens=1 delims=:" %%N in ('findstr /n /l /x /c:"#===POWERSHELL===" "%~f0"') do set "MARKERLINE=%%N"

if not defined MARKERLINE (
    echo FATAL ERROR: PowerShell section marker not found.
    pause
    exit /b 1
)

more +%MARKERLINE% "%~f0" > "%PSFILE%"

if errorlevel 1 (
    echo FATAL ERROR: Failed to extract PowerShell code.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
set "RC=%ERRORLEVEL%"

del "%PSFILE%" >nul 2>&1

if not "%RC%"=="0" (
    echo.
    echo Valorant Net Kit exited with error code %RC%.
    pause
)

exit /b %RC%

#===POWERSHELL===
$ErrorActionPreference = 'Stop'

# ======================= settings (edit here) =======================

# --- DNS test (used by the optimizer and the list tools) ---
$TargetName          = 'auth.riotgames.com'  # Riot host name used for the test
$ManualRiotIp        = ''                    # empty = use the IP each DNS server returns. Or type one IPv4 here, for example '1.2.3.4', to test that IP instead
$TimeoutMs           = 1200                  # how long to wait for each DNS server
$DnsPort             = 53
$ConnectPort         = 443                   # port used to time the connection to the Riot IP each DNS returns
$ConnectTimeoutMs    = 1200                  # how long to wait for that connection
$ConnectSamples      = 2                     # connection attempts per Riot IP (the fastest one counts)
$RankBy              = 'conn'                # 'conn' = lowest connection time wins (lookup time only breaks ties); 'total' = lookup + connection
$SwitchMarginMs      = 2                     # servers within this many ms of the best count as equal (the faster lookup wins); your current DNS stays if it is that close (0 = strict)
$AdapterName         = ''                    # empty = use the connection Windows is using now (Wi-Fi or Ethernet)
$MaxThreads          = 16                    # how many DNS servers are tested at the same time (1 = one by one, like before)

# --- Auto-optimizer ---
$TestIntervalSeconds = 15                    # seconds between test rounds
$RequiredWins        = 2                     # same winner this many rounds in a row before switching
$FailoverRounds      = 2                     # if the DNS you use stops answering for this many rounds, switch to the best one at once
$PauseAfterFails     = 3                     # a server that fails this many rounds in a row is paused ...
$PauseRounds         = 10                    # ... for this many rounds, so dead servers stop slowing every round
$UseBackupDns        = $false                # also set the 2nd best server as the backup DNS
$RestoreDnsOnStop    = $false                # go back to automatic DNS when you stop the optimizer
$ClearEveryRounds    = 2                     # clear the screen after this many rounds (0 = never clear)
$MaxRowsShown        = 6                     # rows of the result table to show (0 = show all)

# --- DNS list tools ---
$ImportMaxDnsMs      = 150                   # when adding new DNS servers, keep only those that answer faster than this
$ImportMaxPages      = 8                     # most pages read from a paged website list
$PickListMax         = 0                     # most servers shown in the "choose a DNS myself" list (0 = show all)
$PickPingCount       = 4                     # pings per server for the average ping (measured once, during the list test)
$ScanCacheMinutes    = 10                    # "Test every server now" reuses results from the previous scan for this many minutes (0 = always test everything again)
$InfoCacheDays       = 30                    # provider + location of a DNS IP is remembered this many days (0 = forever)
$PingCacheMinutes    = 0                     # 0 = "Choose a DNS myself" reuses the ping measured the first time for the whole session (only servers never pinged are measured). Or a number of minutes after which a ping is measured again
$PersistInfoCache    = $true                 # $true = remember provider + location between runs in a hidden file (ProgramData\ValorantNetKit); $false = only while the tool is open

# --- Connection check (packet loss and jitter) ---
$TestSeconds          = 60       # how long the check runs
$ProbeIntervalMs      = 500      # time between test rounds
$ProbeTimeoutMs       = 1000     # how long to wait for one reply (no reply = lost packet)
$RiotHost             = 'auth.riotgames.com'
$ExtraTargets         = @()      # optional: more IPs to ping, for example @('1.2.3.4')
$LossWarnPct          = 1.0      # packet loss at or above this counts as a problem
$RouterJitterWarnMs   = 5        # jitter above this to your router counts as a problem
$InternetJitterWarnMs = 8        # jitter above this to 1.1.1.1 / 8.8.8.8 counts as a problem
$RiotJitterWarnMs     = 12       # jitter above this to Riot counts as a problem
$SpikesWarn           = 3        # this many latency spikes in one check count as a problem
$RunTraceroute        = $true    # if a problem is found, also save a traceroute to Riot in the report

# --- Voice monitor ---
$MonitorSeconds       = 3                      # seconds between checks
$VoiceNoConnection    = 'No connection'        # what the PC says when the internet is down
$VoiceDnsProblem      = 'DNS problem'          # what the PC says when your DNS stops answering

# ======================= files and folders =======================
$KitDir        = if ($env:KIT_DIR) { $env:KIT_DIR } else { (Get-Location).Path }
$IpFile        = Join-Path $KitDir 'ips.txt'
$ListDir       = Join-Path $KitDir 'lists'
$LogFile       = Join-Path $KitDir 'netkit_log.txt'
$ReportFile    = Join-Path $KitDir 'valorant_lag_report.txt'
$BackupDir     = Join-Path $env:ProgramData 'ValorantNetKit'
$BackupFile    = Join-Path $BackupDir 'safe_tweaks_backup.json'
$AdvBackupFile = Join-Path $BackupDir 'advanced_tweaks_backup.json'
$IpInfoCacheFile = Join-Path $BackupDir 'dns_info.cache'
$OldInfoCacheFile = Join-Path $KitDir 'dns_info_cache.json'
$TaskName      = 'ValorantNetKit'

# Everything printed by the connection check is also kept here and saved to the report file.
$ReportLines = [System.Collections.Generic.List[string]]::new()

# Shown in the optimizer header after every screen clear.
$script:LastChangeText = ''

# Provider / location lookups already made (address -> info). The scan itself (lookup + connection time) is never cached.
$script:IpInfoCache = @{}
$script:IpInfoStamp = @{}
$script:IpInfoCacheLoaded = $false
$script:IpInfoDirty = $false

# Results of the last list scan (address -> test row + time). Used by "Test every server now" so a second scan is instant.
$script:ScanCache = @{}

# Ping results (address -> ms + time). Kept in memory only, never written to a file.
$script:PingCache = @{}

# ======================= DNS presets (collected from your old menu scripts) =======================
$Presets = @(
    @{ Name = 'Cloudflare';                  IPs = @('1.1.1.1', '1.0.0.1') },
    @{ Name = 'Google';                      IPs = @('8.8.8.8', '8.8.4.4') },
    @{ Name = 'Quad9';                       IPs = @('9.9.9.9', '149.112.112.112') },
    @{ Name = 'OpenDNS';                     IPs = @('208.67.222.222', '208.67.220.220') },
    @{ Name = 'Control D (unfiltered)';      IPs = @('76.76.2.0', '76.76.10.0') },
    @{ Name = 'AdGuard (blocks ads)';        IPs = @('94.140.14.14', '94.140.15.15') },
    @{ Name = 'AdGuard (no filtering)';      IPs = @('94.140.14.140', '94.140.14.141') },
    @{ Name = 'Verisign';                    IPs = @('64.6.64.6', '64.6.65.6') },
    @{ Name = 'Neustar UltraDNS';            IPs = @('156.154.70.1', '156.154.71.1') },
    @{ Name = 'Freenom World';               IPs = @('80.80.80.80', '80.80.81.81') },
    @{ Name = 'Alternate DNS';               IPs = @('76.76.19.19', '76.223.122.150') },
    @{ Name = 'Yandex';                      IPs = @('77.88.8.8', '77.88.8.1') },
    @{ Name = 'AliDNS (Alibaba)';            IPs = @('223.5.5.5', '223.6.6.6') },
    @{ Name = 'Baidu';                       IPs = @('180.76.76.76') },
    @{ Name = 'Hurricane Electric';          IPs = @('74.82.42.42') },
    @{ Name = 'Oracle Dyn';                  IPs = @('216.146.36.36') },
    @{ Name = 'Comodo Secure';               IPs = @('8.26.56.26', '8.20.247.10') },
    @{ Name = 'NTT';                         IPs = @('129.250.35.250') },
    @{ Name = 'NIC India';                   IPs = @('36.50.50.50') },
    @{ Name = 'Tata (from your lists)';      IPs = @('182.156.154.150', '182.156.153.39') },
    @{ Name = 'Hathway (from your lists)';   IPs = @('203.163.246.35') },
    @{ Name = 'Bell Teleservices (yours)';   IPs = @('203.201.60.5', '203.201.60.12') },
    @{ Name = 'Meghbela (from your lists)';  IPs = @('203.147.91.2') },
    @{ Name = 'Juweriyah Networks (yours)';  IPs = @('103.123.225.10', '103.123.226.10') },
    @{ Name = 'Qtime / Hostnet (yours)';     IPs = @('103.149.165.57', '103.171.180.48') },
    @{ Name = 'Alibaba 149.129.165.133';     IPs = @('149.129.165.133') },
    @{ Name = 'Local ISP 1 (from your lists)'; IPs = @('182.237.16.7') },
    @{ Name = 'Local ISP 2 (from your lists)'; IPs = @('103.165.4.82') },
    @{ Name = 'Local ISP 3 (from your lists)'; IPs = @('125.63.106.202') }
)

# Used to create ips.txt the first time, if it does not exist yet.
$DefaultIpList = @(
    '# One DNS server (IPv4) per line. Text after a # is ignored.',
    '# The optimizer tests every server here and uses the best one for Valorant.',
    '1.1.1.1          # Cloudflare',
    '1.0.0.1          # Cloudflare',
    '8.8.8.8          # Google',
    '8.8.4.4          # Google',
    '9.9.9.9          # Quad9',
    '149.112.112.112  # Quad9',
    '208.67.222.222   # OpenDNS',
    '208.67.220.220   # OpenDNS',
    '64.6.64.6        # Verisign',
    '64.6.65.6        # Verisign',
    '156.154.70.1     # Neustar UltraDNS',
    '156.154.71.1     # Neustar UltraDNS',
    '74.82.42.42      # Hurricane Electric',
    '223.5.5.5        # AliDNS',
    '223.6.6.6        # AliDNS',
    '94.140.14.14     # AdGuard',
    '45.90.29.77',
    '8.26.56.10       # Comodo',
    '8.26.56.26       # Comodo',
    '8.20.247.10      # Comodo',
    '129.250.35.250   # NTT',
    '103.123.225.10   # Juweriyah Networks'
)
# ======================= small helpers =======================

function Show-Banner {
    param([string]$Title)

    Clear-Host
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host (' ' + $Title) -ForegroundColor Cyan
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host ''
}

function Wait-Enter {
    Write-Host ''
    [void](Read-Host 'Press Enter to continue')
}

function Read-Choice {
    param([string]$Prompt = 'Choose')

    return ([string](Read-Host $Prompt)).Trim()
}

function Confirm-Yes {
    param([string]$Question)

    $answer = [string](Read-Host ($Question + ' (Y/N)'))

    return ($answer.Trim() -match '^[Yy]')
}

# True if Q was pressed (any other key is ignored).
function Test-StopKey {
    try {
        while ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            if ($key.Key -eq [ConsoleKey]::Q) {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

# Run a block; show an error instead of stopping the whole tool.
function Invoke-Safely {
    param([scriptblock]$Action)

    try {
        & $Action
    }
    catch {
        Write-Host ('Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
    }
}

function Write-Log {
    param([string]$Text)

    try {
        Add-Content -LiteralPath $LogFile -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Text) -Encoding ASCII
    }
    catch {
        # The log is optional: never stop because of it.
    }
}

function Test-IPv4String {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $clean = $Text.Trim()

    if ($clean -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        return $false
    }

    $parsed = $null

    return ([System.Net.IPAddress]::TryParse($clean, [ref]$parsed) -and $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
}

# False for addresses that cannot be public DNS servers (private, loopback, multicast, ...).
function Test-PublicIPv4 {
    param([string]$Ip)

    $p = $Ip.Split('.')
    $a = [int]$p[0]
    $b = [int]$p[1]

    if ($a -eq 0 -or $a -eq 10 -or $a -eq 127 -or $a -ge 224) { return $false }
    if ($a -eq 169 -and $b -eq 254) { return $false }
    if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { return $false }
    if ($a -eq 192 -and $b -eq 168) { return $false }
    if ($a -eq 100 -and $b -ge 64 -and $b -le 127) { return $false }

    return $true
}

# Every valid IPv4 address found in some text, without duplicates.
function Get-IPv4FromText {
    param(
        [string]$Text,
        [switch]$PublicOnly
    )

    $list = [System.Collections.Generic.List[string]]::new()

    foreach ($m in [regex]::Matches($Text, '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])')) {
        $parsed = $null

        if (-not [System.Net.IPAddress]::TryParse($m.Value, [ref]$parsed)) {
            continue
        }

        if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
            continue
        }

        $ip = $parsed.ToString()

        if ($PublicOnly -and -not (Test-PublicIPv4 -Ip $ip)) {
            continue
        }

        if (-not $list.Contains($ip)) {
            $list.Add($ip)
        }
    }

    return $list.ToArray()
}

function ConvertTo-PlainText {
    param([string]$Html)

    $text = [regex]::Replace($Html, '(?is)<script.*?</script>|<style.*?</style>', ' ')
    $text = [regex]::Replace($text, '(?s)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)

    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function Get-WebPage {
    param([string]$Url)

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30 -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36'

    return [string]$response.Content
}

# Check the settings at the top once, at start-up.
function Assert-Settings {
    $script:RankBy = ([string]$RankBy).Trim().ToLower()

    if ($script:RankBy -ne 'conn' -and $script:RankBy -ne 'total') {
        throw "RankBy must be 'conn' or 'total' (it is '$RankBy')."
    }

    if (-not [string]::IsNullOrWhiteSpace($ManualRiotIp) -and -not (Test-IPv4String $ManualRiotIp)) {
        throw "ManualRiotIp is not a valid IPv4 address: $ManualRiotIp"
    }
}

# The connection Windows is using right now (the one that holds the default route),
# unless a name was set in $AdapterName above.
function Get-ActiveAdapter {
    param([string]$Name = '')

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $named = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' } |
            Select-Object -First 1

        if ($named) {
            $gateway = $null

            $namedRoute = Get-NetRoute -InterfaceIndex $named.InterfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($namedRoute) {
                $gateway = $namedRoute.NextHop
            }

            return [pscustomobject]@{
                Name    = $named.Name
                Index   = $named.InterfaceIndex
                Gateway = $gateway
            }
        }

        return $null
    }

    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object { $_.RouteMetric + $_.InterfaceMetric } |
        Select-Object -First 1

    if ($route) {
        return [pscustomobject]@{
            Name    = $route.InterfaceAlias
            Index   = $route.InterfaceIndex
            Gateway = $route.NextHop
        }
    }

    return $null
}

# ======================= ips.txt (the list of DNS servers to test) =======================

function Initialize-IpFile {
    if (-not (Test-Path -LiteralPath $IpFile -PathType Leaf)) {
        Set-Content -LiteralPath $IpFile -Value $DefaultIpList -Encoding ASCII

        Write-Host 'ips.txt was not found, so a default list was created:' -ForegroundColor Yellow
        Write-Host "  $IpFile"
    }
}

# Add addresses to the end of ips.txt (only the ones that are not in it yet). Returns how many were added.
function Add-IpsToList {
    param(
        [string[]]$Ips,
        [string]$Source
    )

    Initialize-IpFile

    try {
        $existing = @(Get-IPv4Candidates -Path $IpFile)
    }
    catch {
        $existing = @()
    }

    $new = @($Ips | Where-Object { $existing -notcontains $_ } | Select-Object -Unique)

    if ($new.Count -eq 0) {
        return 0
    }

    $lines = @('', ('# added {0:yyyy-MM-dd} from {1}' -f (Get-Date), $Source)) + $new

    Add-Content -LiteralPath $IpFile -Value $lines -Encoding ASCII

    return $new.Count
}

# Take addresses out of ips.txt. A copy of the old file is kept as ips.txt.bak.
function Remove-IpsFromList {
    param([string[]]$Ips)

    $removeSet = @{}

    foreach ($ip in $Ips) {
        $removeSet[$ip] = $true
    }

    $lines = [System.IO.File]::ReadAllLines($IpFile)
    Copy-Item -LiteralPath $IpFile -Destination ($IpFile + '.bak') -Force

    $pattern = '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])'
    $out = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        $parts = $line -split '#', 2
        $code = $parts[0]
        $comment = $null

        if ($parts.Count -gt 1) {
            $comment = $parts[1]
        }

        $found = @([regex]::Matches($code, $pattern) | ForEach-Object { $_.Value })

        if ($found.Count -eq 0) {
            $out.Add($line)
            continue
        }

        $kept = @($found | Where-Object { -not $removeSet.ContainsKey($_) })

        if ($kept.Count -eq 0) {
            # Every address on this line was removed: drop the line.
            continue
        }

        if ($kept.Count -eq $found.Count) {
            $out.Add($line)
        }
        else {
            $text = $kept -join '  '

            if ($null -ne $comment) {
                $text += '  #' + $comment
            }

            $out.Add($text)
        }
    }

    [System.IO.File]::WriteAllLines($IpFile, $out.ToArray(), [System.Text.Encoding]::ASCII)
}

# ======================= manual DNS =======================

function Show-CurrentDns {
    $adapter = Get-ActiveAdapter -Name $AdapterName

    if (-not $adapter) {
        Write-Host 'No active network connection found.' -ForegroundColor Yellow
        return
    }

    $current = @(Get-CurrentDns -Index $adapter.Index)
    $text = '(automatic, from your router / provider)'

    if ($current.Count -gt 0) {
        $text = $current -join ', '
    }

    Write-Host ('Connection : {0}' -f $adapter.Name)
    Write-Host ('DNS servers: {0}' -f $text)
}

function Set-DnsFromList {
    param(
        [string[]]$Servers,
        [string]$Label
    )

    $adapter = Get-ActiveAdapter -Name $AdapterName

    if (-not $adapter) {
        Write-Host 'No active network connection found.' -ForegroundColor Yellow
        return
    }

    Set-PreferredDns -Index $adapter.Index -Servers $Servers

    Write-Host ('DNS on {0} set to {1} ({2}).' -f $adapter.Name, ($Servers -join ', '), $Label) -ForegroundColor Green
    Write-Log ('DNS on {0} set to {1} ({2})' -f $adapter.Name, ($Servers -join ', '), $Label)
}

function Set-CustomDns {
    $primary = Read-Choice 'Primary DNS IP'

    if (-not (Test-IPv4String $primary)) {
        Write-Host 'That is not a valid IPv4 address.' -ForegroundColor Yellow
        return
    }

    $servers = @($primary)
    $secondary = Read-Choice 'Secondary DNS IP (press Enter to skip)'

    if ($secondary) {
        if (-not (Test-IPv4String $secondary)) {
            Write-Host 'That is not a valid IPv4 address.' -ForegroundColor Yellow
            return
        }

        $servers += $secondary
    }

    Set-DnsFromList -Servers $servers -Label 'custom'
}

function Reset-DnsAutomatic {
    $adapter = Get-ActiveAdapter -Name $AdapterName

    if (-not $adapter) {
        Write-Host 'No active network connection found.' -ForegroundColor Yellow
        return
    }

    Set-DnsClientServerAddress -InterfaceIndex $adapter.Index -ResetServerAddresses
    Clear-DnsClientCache

    Write-Host ('DNS on {0} is back to automatic (from your router / internet provider).' -f $adapter.Name) -ForegroundColor Green
    Write-Log ('DNS on {0} reset to automatic' -f $adapter.Name)
}

# ======================= DNS test engine (lookup + connection to the Riot IP) =======================

function Get-IPv4Candidates {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "DNS list not found: $Path"
    }

    $addresses = [System.Collections.Generic.List[string]]::new()

    # Read individual lines; also accept multiple IPs on one line.
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $content = ($line -split '#', 2)[0].Trim()

        if ([string]::IsNullOrWhiteSpace($content)) {
            continue
        }

        $found = [regex]::Matches(
            $content,
            '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])'
        )

        foreach ($match in $found) {
            $parsed = $null

            if (
                [System.Net.IPAddress]::TryParse($match.Value, [ref]$parsed) -and
                $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
            ) {
                $ip = $parsed.ToString()

                if (-not $addresses.Contains($ip)) {
                    $addresses.Add($ip)
                }
            }
        }
    }

    if ($addresses.Count -eq 0) {
        throw "No valid IPv4 addresses found in: $Path"
    }

    # No leading comma here: the IPs must come out one by one.
    return $addresses.ToArray()
}

# Position just after a DNS name that starts at $Pos (a name ends with a 0 byte or a 2-byte pointer).
function Skip-DnsName {
    param(
        [byte[]]$Data,
        [int]$Pos
    )

    while ($Pos -lt $Data.Length) {
        $len = [int]$Data[$Pos]

        if ($len -eq 0) {
            return $Pos + 1
        }

        if (($len -band 0xC0) -eq 0xC0) {
            return $Pos + 2
        }

        $Pos += $len + 1
    }

    return -1
}

# All IPv4 addresses (A records) in the answer section of a DNS reply.
function Get-DnsAnswerIPv4 {
    param([byte[]]$Reply)

    $found = [System.Collections.Generic.List[string]]::new()

    if ($Reply.Length -ge 12) {
        $questions = ([int]$Reply[4] * 256) + [int]$Reply[5]
        $answers = ([int]$Reply[6] * 256) + [int]$Reply[7]
        $pos = 12

        # Skip the question section.
        for ($i = 0; $i -lt $questions -and $pos -ge 0; $i++) {
            $pos = Skip-DnsName -Data $Reply -Pos $pos

            if ($pos -ge 0) {
                $pos += 4
            }
        }

        # Walk the answer records.
        for ($i = 0; $i -lt $answers -and $pos -ge 0; $i++) {
            $pos = Skip-DnsName -Data $Reply -Pos $pos

            if ($pos -lt 0 -or ($pos + 10) -gt $Reply.Length) {
                break
            }

            $type = ([int]$Reply[$pos] * 256) + [int]$Reply[$pos + 1]
            $dataLength = ([int]$Reply[$pos + 8] * 256) + [int]$Reply[$pos + 9]
            $pos += 10

            if (($pos + $dataLength) -gt $Reply.Length) {
                break
            }

            if ($type -eq 1 -and $dataLength -eq 4) {
                $found.Add(('{0}.{1}.{2}.{3}' -f $Reply[$pos], $Reply[$pos + 1], $Reply[$pos + 2], $Reply[$pos + 3]))
            }

            $pos += $dataLength
        }
    }

    return $found.ToArray()
}

# Ask one DNS server for the A record of $Name and time its answer.
function Test-DnsUdp {
    param(
        [string]$Server,
        [string]$Name,
        [int]$Timeout
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $udp = $null
    $async = $null

    try {
        # Build the DNS question name.
        $question = [System.Collections.Generic.List[byte]]::new()

        foreach ($label in $Name.TrimEnd('.').Split('.')) {
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($label)

            if ($bytes.Length -gt 63) {
                throw 'Invalid DNS label'
            }

            $question.Add([byte]$bytes.Length)

            foreach ($b in $bytes) {
                $question.Add($b)
            }
        }

        $question.Add([byte]0)

        # Generate a random DNS transaction ID.
        $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $idBytes = New-Object byte[] 2
        $random.GetBytes($idBytes)
        $random.Dispose()

        $packet = [System.Collections.Generic.List[byte]]::new()

        $packet.Add($idBytes[0])
        $packet.Add($idBytes[1])

        # Recursion desired, one question, zero answer/authority/additional.
        foreach ($b in [byte[]]@(1,0,0,1,0,0,0,0,0,0)) {
            $packet.Add($b)
        }

        foreach ($b in $question) {
            $packet.Add($b)
        }

        # QTYPE A, QCLASS IN.
        foreach ($b in [byte[]]@(0,1,0,1)) {
            $packet.Add($b)
        }

        $endpoint = [System.Net.IPEndPoint]::new(
            [System.Net.IPAddress]::Parse($Server),
            $DnsPort
        )

        $udp = [System.Net.Sockets.UdpClient]::new(
            [System.Net.Sockets.AddressFamily]::InterNetwork
        )

        $udp.Client.SendTimeout = $Timeout
        $udp.Client.ReceiveTimeout = $Timeout
        $udp.Connect($endpoint)

        $data = $packet.ToArray()
        [void]$udp.Send($data, $data.Length)

        $async = $udp.BeginReceive($null, $null)

        if (-not $async.AsyncWaitHandle.WaitOne($Timeout)) {
            throw [System.TimeoutException]::new('DNS query timed out')
        }

        $remote = [System.Net.IPEndPoint]::new(
            [System.Net.IPAddress]::Any,
            0
        )

        $reply = $udp.EndReceive($async, [ref]$remote)
        $watch.Stop()

        if ($reply.Length -lt 12) {
            throw 'Invalid DNS response'
        }

        # Build the 16-bit values with [int] math. In Windows PowerShell, -shl on a [byte]
        # stays a byte and drops the high bits, which broke the flags check.
        $receivedId = ([int]$reply[0] * 256) + [int]$reply[1]
        $sentId = ([int]$idBytes[0] * 256) + [int]$idBytes[1]

        if ($receivedId -ne $sentId) {
            throw 'Mismatched DNS transaction ID'
        }

        $flags = ([int]$reply[2] * 256) + [int]$reply[3]
        $rcode = $flags -band 0x000F

        if (($flags -band 0x8000) -eq 0) {
            throw 'Response is not a DNS reply'
        }

        if ($rcode -ne 0) {
            throw "DNS response code $rcode"
        }

        # The IPv4 addresses this DNS server gave for the name.
        $answerIps = @(Get-DnsAnswerIPv4 -Reply $reply)

        if ($answerIps.Count -eq 0) {
            throw 'No IPv4 answer in the reply'
        }

        return [pscustomobject]@{
            IP      = $Server
            Success = $true
            Ms      = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
            Status  = 'SUCCESS'
            Answers = $answerIps
        }
    }
    catch {
        $watch.Stop()

        return [pscustomobject]@{
            IP      = $Server
            Success = $false
            Ms      = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
            Status  = $_.Exception.Message
            Answers = @()
        }
    }
    finally {
        if ($null -ne $async) {
            $async.AsyncWaitHandle.Close()
        }

        if ($null -ne $udp) {
            $udp.Dispose()
        }
    }
}

# Time a TCP connection to Address:Port (the fastest of a few attempts, in ms).
function Test-TcpConnect {
    param(
        [string]$Address,
        [int]$Port,
        [int]$Timeout,
        [int]$Samples = 2
    )

    $best = $null
    $problem = 'connect failed'

    for ($attempt = 0; $attempt -lt $Samples; $attempt++) {
        $tcp = $null
        $async = $null

        try {
            $tcp = [System.Net.Sockets.TcpClient]::new(
                [System.Net.Sockets.AddressFamily]::InterNetwork
            )

            $watch = [System.Diagnostics.Stopwatch]::StartNew()

            $async = $tcp.BeginConnect(
                [System.Net.IPAddress]::Parse($Address),
                $Port,
                $null,
                $null
            )

            if (-not $async.AsyncWaitHandle.WaitOne($Timeout)) {
                throw [System.TimeoutException]::new('timed out')
            }

            $tcp.EndConnect($async)
            $watch.Stop()

            $ms = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)

            if ($null -eq $best -or $ms -lt $best) {
                $best = $ms
            }
        }
        catch {
            if ($_.Exception -is [System.TimeoutException]) {
                $problem = 'timed out'
            }
            else {
                $problem = 'connect failed'
            }

            break
        }
        finally {
            if ($null -ne $tcp) {
                $tcp.Close()
            }

            if ($null -ne $async -and $async.IsCompleted) {
                $async.AsyncWaitHandle.Close()
            }
        }
    }

    if ($null -eq $best) {
        return [pscustomobject]@{
            Success = $false
            Ms      = 0
            Status  = $problem
        }
    }

    return [pscustomobject]@{
        Success = $true
        Ms      = $best
        Status  = 'OK'
    }
}

# Connection time to a Riot IP; every IP is only timed once per round (several DNS servers often return the same one).
# Safe to call from several threads at once: the first thread times the IP, the others wait for that result.
function Get-ConnectResult {
    param(
        [string]$Address,
        [hashtable]$Cache
    )

    $holder = $null
    $root = $Cache.SyncRoot

    [System.Threading.Monitor]::Enter($root)

    try {
        if (-not $Cache.ContainsKey($Address)) {
            $Cache[$Address] = [pscustomobject]@{
                Result = $null
                Done   = $false
            }
        }

        $holder = $Cache[$Address]
    }
    finally {
        [System.Threading.Monitor]::Exit($root)
    }

    [System.Threading.Monitor]::Enter($holder)

    try {
        if (-not $holder.Done) {
            $holder.Result = Test-TcpConnect `
                -Address $Address `
                -Port $ConnectPort `
                -Timeout $ConnectTimeoutMs `
                -Samples $ConnectSamples

            $holder.Done = $true
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($holder)
    }

    return $holder.Result
}

# One DNS server: look the name up on it, then time a connection to the Riot IP it returned.
function Test-DnsServer {
    param(
        [string]$Server,
        [string]$Name,
        [hashtable]$Cache
    )

    $dns = Test-DnsUdp -Server $Server -Name $Name -Timeout $TimeoutMs

    $row = [pscustomobject]@{
        IP      = $Server
        Success = $false
        DnsMs   = $dns.Ms
        ConnMs  = $null
        TotalMs = $null
        Score   = $null
        Ping    = $null
        RiotIP  = ''
        Status  = $dns.Status
    }

    if (-not $dns.Success) {
        return $row
    }

    # Normally the IP this DNS server returned; or the fixed IP typed in $ManualRiotIp.
    $target = [string]$dns.Answers[0]

    if (-not [string]::IsNullOrWhiteSpace($ManualRiotIp)) {
        $target = $ManualRiotIp.Trim()
    }

    $row.RiotIP = $target

    $conn = Get-ConnectResult -Address $target -Cache $Cache

    if (-not $conn.Success) {
        $row.Status = 'Riot IP ' + $conn.Status
        return $row
    }

    $row.ConnMs = $conn.Ms
    $row.TotalMs = [math]::Round($dns.Ms + $conn.Ms, 1)
    $row.Score = if ($RankBy -eq 'total') { $row.TotalMs } else { $row.ConnMs }
    $row.Success = $true
    $row.Status = 'OK'

    return $row
}

function Get-CurrentDns {
    param([int]$Index)

    try {
        $config = Get-DnsClientServerAddress `
            -InterfaceIndex $Index `
            -AddressFamily IPv4 `
            -ErrorAction Stop

        return @($config.ServerAddresses)
    }
    catch {
        return @()
    }
}

function Set-PreferredDns {
    param(
        [int]$Index,
        [string[]]$Servers
    )

    Set-DnsClientServerAddress `
        -InterfaceIndex $Index `
        -ServerAddresses $Servers `
        -ErrorAction Stop

    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

# ======================= connection check (packet loss and jitter) =======================

# Print a line and remember it for the report.
function Say {
    param(
        [string]$Text = '',
        [string]$Color = ''
    )

    if ($Color) {
        Write-Host $Text -ForegroundColor $Color
    }
    else {
        Write-Host $Text
    }

    $ReportLines.Add($Text)
}

# One ping. Returns the round-trip time in ms, or $null if there was no reply.
function Test-Icmp {
    param(
        [string]$Address,
        [int]$Timeout
    )

    $ping = [System.Net.NetworkInformation.Ping]::new()

    try {
        $reply = $ping.Send($Address, $Timeout)

        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            return [double]$reply.RoundtripTime
        }

        return $null
    }
    catch {
        return $null
    }
    finally {
        $ping.Dispose()
    }
}

# One TCP connection attempt. Returns the time to connect in ms, or $null if it failed or timed out.
function Test-TcpHandshake {
    param(
        [string]$Address,
        [int]$Port,
        [int]$Timeout
    )

    $tcp = $null
    $async = $null

    try {
        $tcp = [System.Net.Sockets.TcpClient]::new(
            [System.Net.Sockets.AddressFamily]::InterNetwork
        )

        $watch = [System.Diagnostics.Stopwatch]::StartNew()

        $async = $tcp.BeginConnect(
            [System.Net.IPAddress]::Parse($Address),
            $Port,
            $null,
            $null
        )

        if (-not $async.AsyncWaitHandle.WaitOne($Timeout)) {
            return $null
        }

        $tcp.EndConnect($async)
        $watch.Stop()

        return [double]$watch.Elapsed.TotalMilliseconds
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $tcp) {
            $tcp.Close()
        }

        if ($null -ne $async -and $async.IsCompleted) {
            $async.AsyncWaitHandle.Close()
        }
    }
}

function New-Target {
    param(
        [string]$Name,
        [string]$Kind,
        [string]$Address
    )

    return [pscustomobject]@{
        Name    = $Name
        Kind    = $Kind
        Address = $Address
        Sent    = 0
        Rtts    = [System.Collections.Generic.List[double]]::new()
    }
}

# Loss, min/avg/max, jitter (average change between neighbouring replies) and latency spikes.
function Get-TargetStats {
    param($Target)

    $values = @($Target.Rtts)
    $received = $values.Count
    $sent = [int]$Target.Sent

    $loss = 100.0

    if ($sent -gt 0) {
        $loss = [math]::Round(100.0 * ($sent - $received) / $sent, 1)
    }

    if ($received -eq 0) {
        return [pscustomobject]@{
            Name     = $Target.Name
            Sent     = $sent
            Received = 0
            Loss     = 100.0
            Min      = $null
            Avg      = $null
            Max      = $null
            Jitter   = $null
            Spikes   = 0
        }
    }

    $sorted = @($values | Sort-Object)
    $median = $sorted[[int][math]::Floor(($received - 1) / 2)]
    $average = ($values | Measure-Object -Average).Average

    $sum = 0.0

    for ($i = 1; $i -lt $received; $i++) {
        $sum += [math]::Abs($values[$i] - $values[$i - 1])
    }

    $jitter = 0.0

    if ($received -gt 1) {
        $jitter = $sum / ($received - 1)
    }

    # A spike is a reply that took more than twice the usual time (and at least 30 ms more).
    $limit = [math]::Max(2 * $median, $median + 30)
    $spikes = @($values | Where-Object { $_ -gt $limit }).Count

    return [pscustomobject]@{
        Name     = $Target.Name
        Sent     = $sent
        Received = $received
        Loss     = $loss
        Min      = $sorted[0]
        Avg      = [math]::Round($average, 1)
        Max      = $sorted[$received - 1]
        Jitter   = [math]::Round($jitter, 1)
        Spikes   = $spikes
    }
}

# True when loss, jitter or spikes are above the limits in the settings.
function Test-Bad {
    param(
        $Stats,
        [double]$JitterLimit
    )

    return ($Stats.Loss -ge $LossWarnPct) -or ($Stats.Jitter -gt $JitterLimit) -or ($Stats.Spikes -ge $SpikesWarn)
}

# Option 1: measure packet loss and jitter to your router, the internet and Riot, and say where the problem is.
function Invoke-ConnectionCheck {
    $ReportLines.Clear()

    $adapter = Get-ActiveAdapter -Name $AdapterName

    if (-not $adapter) {
        Write-Host 'No active network connection found.' -ForegroundColor Red
        return
    }

    $targets = @()

    if ($adapter.Gateway -and $adapter.Gateway -ne '0.0.0.0') {
        $targets += New-Target -Name ('Router ' + $adapter.Gateway) -Kind 'icmp' -Address $adapter.Gateway
    }

    $targets += New-Target -Name 'Cloudflare 1.1.1.1' -Kind 'icmp' -Address '1.1.1.1'
    $targets += New-Target -Name 'Google 8.8.8.8' -Kind 'icmp' -Address '8.8.8.8'

    # Riot servers do not answer ping, so the Riot login server is timed with a TCP connection instead.
    $riotIp = $null

    try {
        $riotIp = [System.Net.Dns]::GetHostAddresses($RiotHost) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            Select-Object -First 1
    }
    catch {
        $riotIp = $null
    }

    if ($riotIp) {
        $targets += New-Target -Name ('Riot login ' + $riotIp.IPAddressToString) -Kind 'tcp' -Address $riotIp.IPAddressToString
    }
    else {
        Write-Host "Could not look up $RiotHost, so the Riot part is skipped." -ForegroundColor Yellow
    }

    foreach ($extra in $ExtraTargets) {
        $targets += New-Target -Name ('Extra ' + $extra) -Kind 'icmp' -Address ([string]$extra)
    }

    Write-Host ''
    Write-Host "Checking your connection for $TestSeconds seconds. You can keep playing - it only sends tiny test packets." -ForegroundColor Cyan

    $started = Get-Date
    $stopAt = $started.AddSeconds($TestSeconds)

    while ((Get-Date) -lt $stopAt) {
        $cycle = [System.Diagnostics.Stopwatch]::StartNew()

        foreach ($t in $targets) {
            if ($t.Kind -eq 'tcp') {
                $ms = Test-TcpHandshake -Address $t.Address -Port 443 -Timeout $ProbeTimeoutMs
            }
            else {
                $ms = Test-Icmp -Address $t.Address -Timeout $ProbeTimeoutMs
            }

            $t.Sent++

            if ($null -ne $ms) {
                $t.Rtts.Add([double]$ms)
            }
        }

        $elapsed = ((Get-Date) - $started).TotalSeconds
        $percent = [int][math]::Min(100, [math]::Round(100 * $elapsed / $TestSeconds))

        Write-Progress -Activity 'Checking your connection' -Status ('{0:N0} of {1} seconds' -f $elapsed, $TestSeconds) -PercentComplete $percent

        $wait = $ProbeIntervalMs - $cycle.ElapsedMilliseconds

        if ($wait -gt 0) {
            Start-Sleep -Milliseconds ([int]$wait)
        }
    }

    Write-Progress -Activity 'Checking your connection' -Completed

    $stats = @($targets | ForEach-Object { Get-TargetStats -Target $_ })

    Say ''
    Say ('Connection check {0:yyyy-MM-dd HH:mm}   adapter: {1}   duration: {2} s' -f (Get-Date), $adapter.Name, $TestSeconds)
    Say ('{0,-28} {1,5} {2,6} {3,6} {4,6} {5,6} {6,7} {7,7}' -f 'TARGET', 'SENT', 'LOSS%', 'MIN', 'AVG', 'MAX', 'JITTER', 'SPIKES')
    Say ('-' * 78)

    foreach ($s in $stats) {
        if ($s.Received -eq 0) {
            Say ('{0,-28} {1,5} {2,6}   no reply (this target may block ping)' -f $s.Name, $s.Sent, '100.0') 'DarkGray'
        }
        else {
            $color = if ($s.Loss -ge $LossWarnPct -or $s.Spikes -ge $SpikesWarn) { 'Red' } else { 'Green' }

            Say ('{0,-28} {1,5} {2,6:N1} {3,6:N0} {4,6:N0} {5,6:N0} {6,7:N1} {7,7}' -f $s.Name, $s.Sent, $s.Loss, $s.Min, $s.Avg, $s.Max, $s.Jitter, $s.Spikes) $color
        }
    }

    $routerS = $stats | Where-Object { $_.Name -like 'Router*' } | Select-Object -First 1
    $inetS = @($stats | Where-Object { $_.Name -like 'Cloudflare*' -or $_.Name -like 'Google*' })
    $riotS = $stats | Where-Object { $_.Name -like 'Riot*' } | Select-Object -First 1

    $routerBad = $null -ne $routerS -and $routerS.Received -gt 0 -and (Test-Bad -Stats $routerS -JitterLimit $RouterJitterWarnMs)
    $inetAlive = @($inetS | Where-Object { $_.Received -gt 0 }).Count -gt 0
    $inetBad = @($inetS | Where-Object { $_.Received -gt 0 -and (Test-Bad -Stats $_ -JitterLimit $InternetJitterWarnMs) }).Count -gt 0
    $riotBad = $null -ne $riotS -and ($riotS.Received -eq 0 -or (Test-Bad -Stats $riotS -JitterLimit $RiotJitterWarnMs))

    Say ''

    if ($null -ne $routerS -and $routerS.Received -eq 0) {
        Say 'Note: your router does not answer ping, so your home network could not be measured.' 'Yellow'
    }

    if ($routerBad) {
        Say 'RESULT: the problem is inside your home network (PC cable, router or Wi-Fi).' 'Red'
        Say 'Try: a different LAN cable and router port, restart the router, unplug busy devices,'
        Say 'and update the network card driver. The safe tweaks (Tweaks menu) also turn off its power saving.'
    }
    elseif ($inetBad) {
        Say 'RESULT: your router is fine, but the line beyond it loses packets or has jitter.' 'Red'
        Say 'Try: restart the fiber box and router. If it keeps happening, send valorant_lag_report.txt'
        Say 'to your internet provider and ask them to check the line and the route to Riot.'
    }
    elseif (-not $inetAlive -and ($null -eq $riotS -or $riotS.Received -eq 0)) {
        Say 'RESULT: no replies from the internet during the check - your connection was down.' 'Red'
    }
    elseif ($riotBad) {
        Say 'RESULT: the internet looks stable, but the path to Riot is not.' 'Red'
        Say 'Check status.riotgames.com. A gaming route optimizer or VPN can sometimes avoid a bad'
        Say 'provider-to-Riot path, and your provider can be asked about the route to Riot.'
    }
    else {
        Say 'RESULT: clean - no packet loss or jitter spikes on your side during this check.' 'Green'
        Say 'If rubber-banding still happens, run this again at the moment it happens, and watch'
        Say "Valorant's own Packet Loss and Network Buffering graphs (Settings > Video > Stats)."
    }

    # With a problem found, also record the route to Riot: this is what providers ask for.
    if (($routerBad -or $inetBad -or $riotBad) -and $RunTraceroute -and $riotIp) {
        Say ''
        Say ('Traceroute to {0} (saved in the report):' -f $riotIp.IPAddressToString) 'Cyan'

        & tracert.exe -d -h 12 -w 800 $riotIp.IPAddressToString | ForEach-Object { Say ([string]$_) }
    }

    try {
        $ReportLines | Out-File -LiteralPath $ReportFile -Append -Encoding ASCII

        Write-Host ''
        Write-Host "Report saved: $ReportFile" -ForegroundColor Cyan
    }
    catch {
        Write-Host 'Could not save the report file.' -ForegroundColor Yellow
    }
}

# ======================= safe tweaks =======================

# Option 2: a few safe Windows changes that remove common causes of random lag spikes. All can be undone.
function Invoke-ApplyTweaks {
    if (Test-Path -LiteralPath $BackupFile) {
        Write-Host 'The safe tweaks are already applied (a backup exists). Undo them first to start over.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host 'This makes three changes. The undo option puts all of them back.'
    Write-Host ' 1. Windows power plan: High performance (on a laptop, use it only while plugged in)'
    Write-Host ' 2. Network card: turns off Energy-Efficient Ethernet and similar power saving'
    Write-Host '    (your connection drops for a few seconds while the card restarts)'
    Write-Host ' 3. Windows Update: stops sharing update files with other PCs over your upload'
    Write-Host ''
    Write-Host 'These remove common causes of random spikes. They do not lower your base ping.'
    Write-Host ''

    $answer = Read-Host 'Continue? (Y/N)'

    if ($answer -notmatch '^[Yy]') {
        Write-Host 'Cancelled.'
        return
    }

    $backup = [ordered]@{
        PowerScheme          = $null
        Nic                  = $null
        DeliveryOptimization = $null
    }

    # 1) Power plan
    try {
        $guidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
        $highPerformance = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'

        $current = (& powercfg.exe /getactivescheme 2>$null) -join ' '

        if ($current -match $guidPattern) {
            $backup.PowerScheme = $Matches[0]
        }

        & powercfg.exe /setactive $highPerformance 2>$null

        if ($LASTEXITCODE -ne 0) {
            # Some PCs hide the High performance plan: create it from the built-in template.
            $copy = (& powercfg.exe /duplicatescheme $highPerformance 2>$null) -join ' '

            if ($copy -match $guidPattern) {
                & powercfg.exe /setactive $Matches[0] 2>$null
            }
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host '1. Power plan set to High performance.' -ForegroundColor Green
        }
        else {
            Write-Host '1. Could not change the power plan.' -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ('1. Power plan not changed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    # 2) Network card power saving
    try {
        $adapter = Get-ActiveAdapter -Name $AdapterName

        if ($adapter) {
            $nicPattern = '(?i)energy.?efficient|green ethernet|power saving|ultra low power|\bEEE\b'
            $changed = @()

            $props = @(
                Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -match $nicPattern }
            )

            foreach ($prop in $props) {
                $off = $prop.ValidDisplayValues | Where-Object { $_ -match '^(Disabled|Off)$' } | Select-Object -First 1

                if ($off -and $prop.DisplayValue -ne $off) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $off -NoRestart

                    $changed += [pscustomobject]@{
                        DisplayName = $prop.DisplayName
                        OldValue    = $prop.DisplayValue
                    }
                }
            }

            if ($changed.Count -gt 0) {
                $backup.Nic = [ordered]@{
                    Adapter = $adapter.Name
                    Changed = $changed
                }

                Write-Host '2. Restarting the network card (the connection drops for a few seconds)...'
                Restart-NetAdapter -Name $adapter.Name

                Write-Host ('2. Turned off {0} power saving setting(s) on {1}.' -f $changed.Count, $adapter.Name) -ForegroundColor Green
            }
            else {
                Write-Host '2. Your network card has no such power saving settings turned on - nothing to change.'
            }
        }
        else {
            Write-Host '2. No active network connection found - skipped.' -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ('2. Network card not changed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    # 3) Windows Update sharing (Delivery Optimization): HTTP only, no sharing with other PCs
    try {
        $doKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'

        $doInfo = [ordered]@{
            KeyExisted = (Test-Path -LiteralPath $doKey)
            HadValue   = $false
            OldValue   = $null
        }

        if ($doInfo.KeyExisted) {
            $existing = Get-ItemProperty -LiteralPath $doKey -Name 'DODownloadMode' -ErrorAction SilentlyContinue

            if ($null -ne $existing -and $null -ne $existing.DODownloadMode) {
                $doInfo.HadValue = $true
                $doInfo.OldValue = [int]$existing.DODownloadMode
            }
        }
        else {
            New-Item -Path $doKey -Force | Out-Null
        }

        Set-ItemProperty -LiteralPath $doKey -Name 'DODownloadMode' -Value 0 -Type DWord

        $backup.DeliveryOptimization = $doInfo

        Write-Host '3. Windows Update sharing turned off.' -ForegroundColor Green
    }
    catch {
        Write-Host ('3. Windows Update sharing not changed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $backup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $BackupFile -Encoding ASCII

    Write-Host ''
    Write-Host 'Done. Run the connection check again to see if your connection is steadier.' -ForegroundColor Cyan
}

# Option 3: put everything back the way it was.
function Invoke-UndoTweaks {
    if (-not (Test-Path -LiteralPath $BackupFile)) {
        Write-Host 'No backup found, so there is nothing to undo.' -ForegroundColor Yellow
        return
    }

    $backup = Get-Content -LiteralPath $BackupFile -Raw | ConvertFrom-Json

    # 1) Power plan
    try {
        if ($backup.PowerScheme) {
            & powercfg.exe /setactive $backup.PowerScheme 2>$null

            if ($LASTEXITCODE -eq 0) {
                Write-Host '1. Power plan restored.' -ForegroundColor Green
            }
            else {
                Write-Host '1. Could not restore the power plan.' -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host ('1. Power plan not restored: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    # 2) Network card settings
    try {
        if ($backup.Nic) {
            $name = [string]$backup.Nic.Adapter

            foreach ($item in @($backup.Nic.Changed)) {
                Set-NetAdapterAdvancedProperty -Name $name -DisplayName ([string]$item.DisplayName) -DisplayValue ([string]$item.OldValue) -NoRestart
            }

            Write-Host '2. Restarting the network card (the connection drops for a few seconds)...'
            Restart-NetAdapter -Name $name

            Write-Host '2. Network card settings restored.' -ForegroundColor Green
        }
    }
    catch {
        Write-Host ('2. Network card settings not restored: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    # 3) Windows Update sharing
    try {
        if ($backup.DeliveryOptimization) {
            $doKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
            $info = $backup.DeliveryOptimization

            if ($info.HadValue) {
                Set-ItemProperty -LiteralPath $doKey -Name 'DODownloadMode' -Value ([int]$info.OldValue) -Type DWord
            }
            else {
                Remove-ItemProperty -LiteralPath $doKey -Name 'DODownloadMode' -ErrorAction SilentlyContinue

                if (-not $info.KeyExisted) {
                    $left = Get-Item -LiteralPath $doKey -ErrorAction SilentlyContinue

                    if ($null -ne $left -and $left.ValueCount -eq 0 -and $left.SubKeyCount -eq 0) {
                        Remove-Item -LiteralPath $doKey -ErrorAction SilentlyContinue
                    }
                }
            }

            Write-Host '3. Windows Update sharing restored.' -ForegroundColor Green
        }
    }
    catch {
        Write-Host ('3. Windows Update sharing not restored: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    Remove-Item -LiteralPath $BackupFile -Force

    Write-Host ''
    Write-Host 'Done. Everything is back to how it was.' -ForegroundColor Cyan
}
# ======================= DNS rounds (used by the optimizer and the list tools) =======================

# ======================= multithreading helper =======================

# Runs $Work once for every item, several at the same time (a runspace pool).
# $Work gets two parameters: the item and $Context. $Functions / $Variables are copied into every thread.
# Returns Results (same order as $Items, $null if a thread failed or did not finish), Finished and Stopped (Q pressed).
function Invoke-ParallelWork {
    param(
        [object[]]$Items,
        [scriptblock]$Work,
        $Context = $null,
        [string[]]$Functions = @(),
        [string[]]$Variables = @(),
        [int]$Threads = 8,
        [string]$Activity = 'Working',
        [switch]$ShowProgress,
        [switch]$AllowStop
    )

    $count = @($Items).Count
    $results = New-Object 'object[]' $count
    $finished = New-Object 'bool[]' $count
    $stopped = $false

    if ($count -eq 0) {
        return [pscustomobject]@{ Results = $results; Finished = $finished; Stopped = $false }
    }

    $state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

    foreach ($name in $Functions) {
        $definition = (Get-Command -Name $name -CommandType Function).Definition
        $state.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($name, $definition))
    }

    foreach ($name in $Variables) {
        $value = Get-Variable -Name $name -ValueOnly -ErrorAction SilentlyContinue
        $state.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($name, $value, ''))
    }

    $size = [math]::Max(1, [math]::Min($Threads, $count))
    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $size, $state, $Host)
    $shells = New-Object 'object[]' $count
    $handles = New-Object 'object[]' $count
    $scriptText = $Work.ToString()

    try {
        $pool.Open()

        for ($i = 0; $i -lt $count; $i++) {
            $shell = [System.Management.Automation.PowerShell]::Create()
            $shell.RunspacePool = $pool
            [void]$shell.AddScript($scriptText).AddArgument($Items[$i]).AddArgument($Context)
            $shells[$i] = $shell
            $handles[$i] = $shell.BeginInvoke()
        }

        while ($true) {
            $done = 0

            for ($i = 0; $i -lt $count; $i++) {
                if ($handles[$i].IsCompleted) {
                    $done++
                }
            }

            if ($ShowProgress) {
                Write-Progress -Activity $Activity -Status ('{0} of {1} done   (press Q to stop)' -f $done, $count) -PercentComplete ([int](100 * $done / $count))
            }

            if ($done -ge $count) {
                break
            }

            if ($AllowStop -and (Test-StopKey)) {
                $stopped = $true
                break
            }

            Start-Sleep -Milliseconds 25
        }

        for ($i = 0; $i -lt $count; $i++) {
            if (-not $handles[$i].IsCompleted) {
                continue
            }

            $finished[$i] = $true

            try {
                $out = $shells[$i].EndInvoke($handles[$i])

                if ($null -ne $out -and $out.Count -gt 0) {
                    $results[$i] = $out[0]
                }
            }
            catch {
                $results[$i] = $null
            }
        }
    }
    finally {
        if ($ShowProgress) {
            Write-Progress -Activity $Activity -Completed
        }

        for ($i = 0; $i -lt $count; $i++) {
            $shell = $shells[$i]

            if ($null -eq $shell) {
                continue
            }

            try {
                if (-not $handles[$i].IsCompleted) {
                    [void]$shell.BeginStop($null, $null)
                }

                $shell.Dispose()
            }
            catch {
            }
        }

        try {
            $pool.Close()
            $pool.Dispose()
        }
        catch {
        }
    }

    return [pscustomobject]@{ Results = $results; Finished = $finished; Stopped = $stopped }
}

# Test every server once (lookup, then a connection to the Riot IP it returned) and rank them.
# The servers are tested in parallel ($MaxThreads at a time); the ranking is the same as before.
function Get-DnsRound {
    param(
        [string[]]$Servers,
        [switch]$ShowProgress,
        [switch]$MeasurePing,
        [switch]$UseCache,
        [switch]$Refresh
    )

    $rows = @()
    $stopped = $false
    $parallel = $null

    # With -UseCache, servers tested in the previous scan (same settings, not too old) are not tested again.
    # -Refresh ignores the saved results but still saves the new ones.
    $cachedRows = @()
    $cacheOn = ($UseCache -and $ScanCacheMinutes -gt 0)
    $signature = '{0}|{1}|{2}|{3}|{4}' -f $TargetName, $ManualRiotIp, $RankBy, $ConnectPort, [bool]$MeasurePing
    $oldestAge = 0

    if ($cacheOn -and -not $Refresh) {
        $now = [DateTime]::UtcNow
        $toTest = @()

        foreach ($candidate in @($Servers)) {
            $hit = $script:ScanCache[$candidate]

            if ($null -ne $hit -and $hit.Sig -eq $signature -and ($now - $hit.Time).TotalMinutes -lt $ScanCacheMinutes) {
                $cachedRows += $hit.Row
                $age = ($now - $hit.Time).TotalSeconds

                if ($age -gt $oldestAge) {
                    $oldestAge = $age
                }
            }
            else {
                $toTest += $candidate
            }
        }

        $Servers = [string[]]$toTest
    }

    if (@($Servers).Count -gt 1 -and $MaxThreads -gt 1) {
        try {
            $context = [pscustomobject]@{
                Name        = $TargetName
                Cache       = [hashtable]::Synchronized(@{})
                MeasurePing = [bool]$MeasurePing
                PingCount   = $PickPingCount
            }

            $work = {
                param($server, $ctx)

                $row = Test-DnsServer -Server $server -Name $ctx.Name -Cache $ctx.Cache

                # For the "choose a DNS myself" list: measure the average ping now, in this same pass.
                if ($ctx.MeasurePing -and $row.Success) {
                    $row.Ping = Get-AvgPing -Address $server -Count $ctx.PingCount
                }

                return $row
            }

            $parallel = Invoke-ParallelWork `
                -Items @($Servers) `
                -Work $work `
                -Context $context `
                -Functions @('Test-DnsServer', 'Test-DnsUdp', 'Get-DnsAnswerIPv4', 'Skip-DnsName', 'Get-ConnectResult', 'Test-TcpConnect', 'Test-Icmp', 'Get-AvgPing') `
                -Variables @('TargetName', 'ManualRiotIp', 'TimeoutMs', 'DnsPort', 'ConnectPort', 'ConnectTimeoutMs', 'ConnectSamples', 'RankBy', 'PickPingCount') `
                -Threads $MaxThreads `
                -Activity 'Testing DNS servers' `
                -ShowProgress:$ShowProgress `
                -AllowStop
        }
        catch {
            # The thread pool could not start: fall back to testing one by one below.
            $parallel = $null
        }
    }

    if ($null -ne $parallel) {
        $stopped = [bool]$parallel.Stopped

        for ($i = 0; $i -lt @($Servers).Count; $i++) {
            if (-not $parallel.Finished[$i]) {
                continue
            }

            if ($null -ne $parallel.Results[$i]) {
                $rows += $parallel.Results[$i]
            }
            else {
                $rows += [pscustomobject]@{
                    IP      = $Servers[$i]
                    Success = $false
                    DnsMs   = 0
                    ConnMs  = $null
                    TotalMs = $null
                    Score   = $null
                    Ping    = $null
                    RiotIP  = ''
                    Status  = 'test failed'
                }
            }
        }
    }
    else {
        $cache = @{}
        $i = 0

        foreach ($server in $Servers) {
            $i++

            if ($ShowProgress) {
                Write-Progress -Activity 'Testing DNS servers' -Status ('{0} of {1}: {2}   (press Q to stop)' -f $i, $Servers.Count, $server) -PercentComplete ([int](100 * $i / $Servers.Count))
            }

            $row = Test-DnsServer -Server $server -Name $TargetName -Cache $cache

            # For the "choose a DNS myself" list: measure the average ping now, in this same pass.
            if ($MeasurePing -and $row.Success) {
                $row.Ping = Get-AvgPing -Address $server -Count $PickPingCount
            }

            $rows += $row

            if (Test-StopKey) {
                $stopped = $true
                break
            }
        }

        if ($ShowProgress) {
            Write-Progress -Activity 'Testing DNS servers' -Completed
        }
    }

    # Save the fresh results for the next scan, then add the reused ones.
    if ($cacheOn) {
        $stamp = [DateTime]::UtcNow

        foreach ($row in $rows) {
            if ($row.Success) {
                $script:ScanCache[$row.IP] = [pscustomobject]@{ Row = $row; Time = $stamp; Sig = $signature }
            }
            else {
                $script:ScanCache.Remove($row.IP)
            }
        }
    }

    $rows = @($cachedRows) + @($rows)

    # Passed servers first, ordered by the ranking value ($RankBy); lookup time breaks ties.
    $sorted = @(
        $rows |
        Sort-Object `
            @{Expression = { if ($_.Success) { 0 } else { 1 } }}, `
            @{Expression = { if ($_.Success) { $_.Score } else { $_.DnsMs } }}, `
            DnsMs, `
            IP
    )

    $ranked = @($sorted | Where-Object { $_.Success })

    # The winner has the lowest ranking value. Anything within $SwitchMarginMs of it counts as
    # equal, and among those the server with the fastest lookup wins.
    $winner = $null
    $bestScore = $null

    if ($ranked.Count -gt 0) {
        $bestScore = $ranked[0].Score

        $winner = $ranked |
            Where-Object { $_.Score -le ($bestScore + $SwitchMarginMs) } |
            Sort-Object DnsMs, Score, IP |
            Select-Object -First 1
    }

    return [pscustomobject]@{
        Rows      = $sorted
        Ranked    = $ranked
        Winner    = $winner
        BestScore = $bestScore
        Stopped   = $stopped
        CachedCount     = @($cachedRows).Count
        CacheAgeSeconds = [int]$oldestAge
    }
}

# Print the result table (best first). $MaxRows = 0 shows every row.
function Write-DnsTable {
    param(
        $Rows,
        $Winner,
        [int]$MaxRows = 0
    )

    $all = @($Rows)
    $shown = $all

    if ($MaxRows -gt 0) {
        $shown = @($all | Select-Object -First $MaxRows)
    }

    # Always show the chosen server, even if it is not among the first rows.
    if ($null -ne $Winner -and @($shown | Where-Object { $_.IP -eq $Winner.IP }).Count -eq 0) {
        $shown = @($shown) + $Winner
    }

    Write-Host ('{0,-16} {1,8} {2,9} {3,9}  {4,-15}  {5}' -f 'DNS SERVER', 'DNS ms', 'CONN ms', 'TOTAL ms', 'RIOT IP', 'RESULT')
    Write-Host ('-' * 78)

    foreach ($row in $shown) {
        if ($row.Success) {
            $okText = 'OK'

            if ($null -ne $Winner -and $row.IP -eq $Winner.IP) {
                $okText = 'OK  <- best'
            }

            Write-Host (
                '{0,-16} {1,8:N1} {2,9:N1} {3,9:N1}  {4,-15}  {5}' -f
                $row.IP, $row.DnsMs, $row.ConnMs, $row.TotalMs, $row.RiotIP, $okText
            ) -ForegroundColor Green
        }
        else {
            Write-Host (
                '{0,-16} {1,8:N1} {2,9} {3,9}  {4,-15}  {5}' -f
                $row.IP, $row.DnsMs, '-', '-', $row.RiotIP, $row.Status
            ) -ForegroundColor DarkGray
        }
    }

    $hidden = $all.Count - $shown.Count
    $failedTotal = @($all | Where-Object { -not $_.Success }).Count

    if ($hidden -gt 0) {
        Write-Host (
            '  ... {0} more not shown ({1} failed in total)' -f
            $hidden, $failedTotal
        ) -ForegroundColor DarkGray
    }
}

# ======================= auto-optimizer =======================

function Show-OptimizerHeader {
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host ' VALORANT AUTO-OPTIMIZER   (press Q to stop)' -ForegroundColor Cyan

    if ($script:LastChangeText) {
        Write-Host (' Last DNS change: ' + $script:LastChangeText) -ForegroundColor Cyan
    }
    else {
        Write-Host ' Last DNS change: none yet' -ForegroundColor Cyan
    }

    Write-Host '============================================' -ForegroundColor Cyan
}

# Keeps the best DNS for Valorant set, round after round, until you press Q.
function Invoke-AutoOptimizer {
    Initialize-IpFile
    [string[]]$ips = @(Get-IPv4Candidates -Path $IpFile)

    $scoreLabel = if ($RankBy -eq 'total') { 'total' } else { 'connection' }

    $script:LastChangeText = ''
    $failStreak = @{}
    $pausedUntil = @{}
    $lastWinner = ''
    $winnerStreak = 0
    $lastAdapter = ''
    $currentFailRounds = 0
    $round = 0
    $stop = $false

    Clear-Host
    Show-OptimizerHeader
    Write-Host "DNS list : $IpFile  ($($ips.Count) servers)"

    if ([string]::IsNullOrWhiteSpace($ManualRiotIp)) {
        Write-Host "Test     : look up $TargetName on each DNS server, then connect to the IP it returns (port $ConnectPort)"
    }
    else {
        Write-Host "Test     : look up $TargetName on each DNS server, then connect to your fixed Riot IP $($ManualRiotIp.Trim()) (port $ConnectPort)"
    }

    if ($RankBy -eq 'total') {
        Write-Host 'Ranking  : lookup time + connection time, lowest total wins'
    }
    else {
        Write-Host 'Ranking  : lowest connection time wins (lookup time only breaks ties)'
    }

    Write-Host "Margin   : $SwitchMarginMs ms - servers this close to the best count as equal (faster lookup wins), and your current DNS stays if it is that close"
    Write-Host "Switch   : same winner $RequiredWins rounds in a row, or at once if your current DNS stops answering"
    Write-Host 'Dead servers are paused for a while so they do not slow the rounds.'

    while (-not $stop) {
        $round++
        $roundStart = Get-Date

        try {
            # Keep the window short: clear it every few rounds and show the small header again.
            if ($ClearEveryRounds -gt 0 -and $round -gt 1 -and (($round - 1) % $ClearEveryRounds) -eq 0) {
                Clear-Host
                Show-OptimizerHeader
            }

            Write-Host ''

            $adapter = Get-ActiveAdapter -Name $AdapterName

            if (-not $adapter) {
                Write-Host (
                    '[{0:HH:mm:ss}] ROUND {1}   No active network connection found. Waiting...' -f
                    $roundStart, $round
                ) -ForegroundColor Red

                $lastWinner = ''
                $winnerStreak = 0
                $currentFailRounds = 0
            }
            else {
                # A different connection starts a new stability count.
                if ($adapter.Name -ne $lastAdapter) {
                    $lastAdapter = $adapter.Name
                    $lastWinner = ''
                    $winnerStreak = 0
                    $currentFailRounds = 0
                }

                $currentDns = @(Get-CurrentDns -Index $adapter.Index)
                $currentText = if ($currentDns.Count -gt 0) { $currentDns -join ', ' } else { '(none)' }

                # Servers that keep failing are paused for a while (the DNS you use now is always tested).
                $active = @(
                    $ips | Where-Object {
                        -not ($pausedUntil.ContainsKey($_) -and $pausedUntil[$_] -gt $round) -or
                        ($currentDns.Count -gt 0 -and $_ -eq $currentDns[0])
                    }
                )

                if ($active.Count -eq 0) {
                    $pausedUntil.Clear()
                    $active = $ips
                }

                $pausedNote = ''

                if ($active.Count -lt $ips.Count) {
                    $pausedNote = ('   ({0} paused)' -f ($ips.Count - $active.Count))
                }

                Write-Host (
                    '[{0:HH:mm:ss}] ROUND {1}   {2}   DNS now: {3}{4}' -f
                    $roundStart, $round, $adapter.Name, $currentText, $pausedNote
                ) -ForegroundColor Yellow

                $res = Get-DnsRound -Servers $active

                if ($res.Stopped) {
                    $stop = $true
                }

                # Remember which servers keep failing.
                foreach ($row in $res.Rows) {
                    if ($row.Success) {
                        $failStreak[$row.IP] = 0
                    }
                    else {
                        $failCount = 1 + [int]$failStreak[$row.IP]

                        if ($failCount -ge $PauseAfterFails) {
                            $pausedUntil[$row.IP] = $round + $PauseRounds + 1
                            $failStreak[$row.IP] = 0
                        }
                        else {
                            $failStreak[$row.IP] = $failCount
                        }
                    }
                }

                Write-DnsTable -Rows $res.Rows -Winner $res.Winner -MaxRows $MaxRowsShown

                $ranked = $res.Ranked
                $winner = $res.Winner
                $bestScore = $res.BestScore

                if ($stop) {
                    Write-Host 'Stopped - nothing was changed in this round.'
                }
                elseif ($ranked.Count -eq 0) {
                    Write-Host 'No DNS server passed both tests. Current DNS unchanged.' -ForegroundColor Red

                    $lastWinner = ''
                    $winnerStreak = 0
                }
                else {
                    # The DNS you use now (if it is in the list) and how it did this round.
                    $currentAny = $null
                    $currentRow = $null

                    if ($currentDns.Count -gt 0) {
                        $currentAny = $res.Rows | Where-Object { $_.IP -eq $currentDns[0] } | Select-Object -First 1
                        $currentRow = $ranked | Where-Object { $_.IP -eq $currentDns[0] } | Select-Object -First 1
                    }

                    if ($null -ne $currentAny -and -not $currentAny.Success) {
                        $currentFailRounds++
                    }
                    else {
                        $currentFailRounds = 0
                    }

                    if ($winner.IP -eq $lastWinner) {
                        $winnerStreak++
                    }
                    else {
                        $lastWinner = $winner.IP
                        $winnerStreak = 1
                    }

                    $failover = ($currentFailRounds -ge $FailoverRounds)

                    if (-not $failover -and $null -ne $currentRow -and ($currentRow.Score - $bestScore) -le $SwitchMarginMs) {
                        if ($currentRow.IP -eq $winner.IP) {
                            Write-Host (
                                'Best: {0} ({1} {2:N1} ms) - already the main DNS.' -f
                                $winner.IP, $scoreLabel, $winner.Score
                            ) -ForegroundColor Green
                        }
                        else {
                            Write-Host (
                                'Best: {0} ({1} {2:N1} ms). Your DNS {3} is only {4:N1} ms behind - keeping it.' -f
                                $winner.IP, $scoreLabel, $winner.Score, $currentRow.IP, ($currentRow.Score - $bestScore)
                            ) -ForegroundColor Green
                        }

                        $lastWinner = ''
                        $winnerStreak = 0
                    }
                    elseif ($failover -or $winnerStreak -ge $RequiredWins) {
                        $servers = @($winner.IP)

                        if ($UseBackupDns) {
                            # Backup DNS: the best remaining server, picked by the same rule as the winner.
                            $others = @($ranked | Where-Object { $_.IP -ne $winner.IP })

                            $backup = $others |
                                Where-Object { $_.Score -le ($bestScore + $SwitchMarginMs) } |
                                Sort-Object DnsMs, Score, IP |
                                Select-Object -First 1

                            if ($null -eq $backup) {
                                $backup = $others | Select-Object -First 1
                            }

                            if ($null -ne $backup) {
                                $servers += $backup.IP
                            }
                        }

                        $why = if ($failover) { 'your old DNS stopped answering' } else { ('{0} wins in a row' -f $RequiredWins) }

                        try {
                            Set-PreferredDns -Index $adapter.Index -Servers $servers

                            $script:LastChangeText = (
                                '{0:HH:mm:ss}  {1}: {2}' -f
                                (Get-Date), $adapter.Name, ($servers -join ', ')
                            )

                            Write-Host (
                                'DNS on {0} changed to {1} ({2}).' -f
                                $adapter.Name, ($servers -join ', '), $why
                            ) -ForegroundColor Cyan

                            Write-Log ('Optimizer: DNS on {0} changed from {1} to {2} ({3} {4:N1} ms; {5})' -f $adapter.Name, $currentText, ($servers -join ', '), $scoreLabel, $winner.Score, $why)
                        }
                        catch {
                            Write-Host (
                                'Could not change DNS: {0}' -f $_.Exception.Message
                            ) -ForegroundColor Red
                        }

                        $lastWinner = ''
                        $winnerStreak = 0
                        $currentFailRounds = 0
                    }
                    else {
                        Write-Host (
                            'Best: {0} ({1} {2:N1} ms) - stability {3}/{4}, DNS unchanged.' -f
                            $winner.IP, $scoreLabel, $winner.Score, $winnerStreak, $RequiredWins
                        ) -ForegroundColor Green
                    }
                }
            }
        }
        catch {
            Write-Host ('Round error: {0}' -f $_.Exception.Message) -ForegroundColor Red
        }

        if ($stop) {
            break
        }

        # Wait for the next round (press Q to stop).
        $waitMs = [int][math]::Max(0, $TestIntervalSeconds * 1000 - ((Get-Date) - $roundStart).TotalMilliseconds)
        $waitWatch = [System.Diagnostics.Stopwatch]::StartNew()

        while ($waitWatch.ElapsedMilliseconds -lt $waitMs) {
            if (Test-StopKey) {
                $stop = $true
                break
            }

            Start-Sleep -Milliseconds 100
        }
    }

    Write-Host ''
    Write-Host 'Auto-optimizer stopped.' -ForegroundColor Cyan

    if ($RestoreDnsOnStop) {
        Invoke-Safely { Reset-DnsAutomatic }
    }
}

# ======================= DNS list tools =======================

# ======================= provider, location and ping of DNS servers =======================

# Short text for a table column (cut with a ~ when it is too long).
function Format-Cell {
    param(
        [string]$Text,
        [int]$Width
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return '-'
    }

    if ($Text.Length -le $Width) {
        return $Text
    }

    return $Text.Substring(0, $Width - 1) + '~'
}

function New-IpInfo {
    param(
        [string]$AsText,
        [string]$Provider,
        [string]$City,
        [string]$Region,
        [string]$Country
    )

    $asn = ''
    $name = $Provider

    # The AS text looks like "AS13335 Cloudflare, Inc.": the number first, then the name.
    if ($AsText -match '^AS(\d+)\s*(.*)$') {
        $asn = 'AS' + $Matches[1]

        if ($Matches[2]) {
            $name = $Matches[2]
        }
    }

    $where = @()

    if ($City) {
        $where += $City
    }
    elseif ($Region) {
        $where += $Region
    }

    if ($Country) {
        $where += $Country
    }

    return [pscustomobject]@{
        Asn      = $asn
        Provider = $name
        Location = ($where -join ', ')
    }
}

# ---- provider / location cache (kept in dns_info_cache.json next to this file) ----

function Import-IpInfoCache {
    if ($script:IpInfoCacheLoaded) {
        return
    }

    $script:IpInfoCacheLoaded = $true

    try {
        # The old cache file next to this script is no longer used.
        if (Test-Path -LiteralPath $OldInfoCacheFile -PathType Leaf) {
            Remove-Item -LiteralPath $OldInfoCacheFile -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
    }

    if (-not $PersistInfoCache) {
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $IpInfoCacheFile -PathType Leaf)) {
            return
        }

        $raw = [System.IO.File]::ReadAllText($IpInfoCacheFile)

        if ([string]::IsNullOrWhiteSpace($raw)) {
            return
        }

        $data = $raw | ConvertFrom-Json
        $now = [DateTime]::UtcNow

        if ($null -eq $data) {
            return
        }

        foreach ($prop in $data.PSObject.Properties) {
            $entry = $prop.Value

            if ($null -eq $entry) {
                continue
            }

            $stamp = $null

            try {
                if ($entry.Saved -is [DateTime]) {
                    $stamp = $entry.Saved.ToUniversalTime()
                }
                else {
                    $stamp = [DateTime]::Parse([string]$entry.Saved, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
                }
            }
            catch {
                $stamp = $null
            }

            # Old entries are dropped so they get looked up again.
            if ($InfoCacheDays -gt 0 -and ($null -eq $stamp -or ($now - $stamp).TotalDays -gt $InfoCacheDays)) {
                continue
            }

            if ($null -eq $stamp) {
                $stamp = $now
            }

            $script:IpInfoCache[[string]$prop.Name] = [pscustomobject]@{
                Asn      = [string]$entry.Asn
                Provider = [string]$entry.Provider
                Location = [string]$entry.Location
            }

            $script:IpInfoStamp[[string]$prop.Name] = $stamp
        }
    }
    catch {
        # A damaged cache file is simply ignored; it is rewritten after the next lookup.
    }
}

function Save-IpInfoCache {
    if (-not $script:IpInfoDirty -or -not $PersistInfoCache) {
        return
    }

    try {
        $data = [ordered]@{}

        foreach ($ip in @($script:IpInfoCache.Keys | Sort-Object)) {
            $entry = $script:IpInfoCache[$ip]

            $data[$ip] = [ordered]@{
                Asn      = $entry.Asn
                Provider = $entry.Provider
                Location = $entry.Location
                Saved    = $script:IpInfoStamp[$ip].ToString('o')
            }
        }

        $json = $data | ConvertTo-Json -Depth 4

        if (-not (Test-Path -LiteralPath $BackupDir)) {
            [void](New-Item -ItemType Directory -Path $BackupDir -Force)
        }

        if (Test-Path -LiteralPath $IpInfoCacheFile) {
            (Get-Item -LiteralPath $IpInfoCacheFile -Force).Attributes = 'Normal'
        }

        [System.IO.File]::WriteAllText($IpInfoCacheFile, $json, [System.Text.UTF8Encoding]::new($false))
        (Get-Item -LiteralPath $IpInfoCacheFile -Force).Attributes = 'Hidden'
        $script:IpInfoDirty = $false
    }
    catch {
        # Could not write the cache (read-only folder?): it still works for this session.
    }
}

function Set-IpInfoEntry {
    param(
        [string]$Ip,
        $Info
    )

    $script:IpInfoCache[$Ip] = $Info
    $script:IpInfoStamp[$Ip] = [DateTime]::UtcNow
    $script:IpInfoDirty = $true
}

# Provider (ASN name) and location of IP addresses. Uses ip-api.com (free, no key, up to 100 per request)
# and falls back to ipinfo.io. Returns a table: address -> info.
# Addresses that are already in the cache (this session or dns_info_cache.json) are not looked up again;
# the ones that are missing are looked up in parallel.
function Get-IpInfo {
    param([string[]]$Ips)

    Import-IpInfoCache

    $todo = @($Ips | Where-Object { -not $script:IpInfoCache.ContainsKey($_) })

    if ($todo.Count -gt 0) {
        # 1) ip-api.com: one request for up to 100 addresses (several requests go out at the same time)
        $chunks = [System.Collections.Generic.List[object]]::new()

        for ($start = 0; $start -lt $todo.Count; $start += 100) {
            $last = [math]::Min($start + 99, $todo.Count - 1)
            $chunks.Add(@($todo[$start..$last]))
        }

        $batchWork = {
            param($chunk, $ctx)

            $json = '[' + (($chunk | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'

            try {
                $answer = Invoke-RestMethod -Uri 'http://ip-api.com/batch?fields=status,country,regionName,city,isp,org,as,asname,query' -Method Post -Body $json -ContentType 'application/json' -TimeoutSec 20
                return [pscustomobject]@{ Answer = $answer }
            }
            catch {
                return $null
            }
        }

        $batch = $null

        try {
            $batch = Invoke-ParallelWork -Items $chunks.ToArray() -Work $batchWork -Threads 4
        }
        catch {
            $batch = $null
        }

        if ($null -ne $batch) {
            foreach ($reply in $batch.Results) {
                if ($null -eq $reply) {
                    continue
                }

                foreach ($item in @($reply.Answer)) {
                    if ($item.status -ne 'success') {
                        continue
                    }

                    $provider = $item.isp

                    if (-not $provider) {
                        $provider = $item.org
                    }

                    if (-not $provider) {
                        $provider = $item.asname
                    }

                    Set-IpInfoEntry -Ip ([string]$item.query) -Info (New-IpInfo -AsText ([string]$item.as) -Provider ([string]$provider) -City ([string]$item.city) -Region ([string]$item.regionName) -Country ([string]$item.country))
                }
            }
        }

        # 2) anything still missing: ipinfo.io, a few addresses at a time (stops early if that service does not answer)
        $left = @($todo | Where-Object { -not $script:IpInfoCache.ContainsKey($_) })

        if ($left.Count -gt 40) {
            $left = @($left | Select-Object -First 40)
        }

        $singleWork = {
            param($ip, $ctx)

            try {
                $item = Invoke-RestMethod -Uri ('https://ipinfo.io/{0}/json' -f $ip) -TimeoutSec 6
                return [pscustomobject]@{ Ok = $true; Item = $item }
            }
            catch {
                return [pscustomobject]@{ Ok = $false; Item = $null }
            }
        }

        $failures = 0

        for ($start = 0; $start -lt $left.Count -and $failures -lt 2; $start += 8) {
            $last = [math]::Min($start + 7, $left.Count - 1)
            $wave = @($left[$start..$last])
            $got = $null

            try {
                $got = Invoke-ParallelWork -Items $wave -Work $singleWork -Threads 8
            }
            catch {
                break
            }

            for ($k = 0; $k -lt $wave.Count; $k++) {
                $reply = $got.Results[$k]

                if ($null -eq $reply -or -not $reply.Ok) {
                    # No info for this one: it is shown with a dash.
                    $failures++
                    continue
                }

                $item = $reply.Item

                if ($item.org) {
                    Set-IpInfoEntry -Ip $wave[$k] -Info (New-IpInfo -AsText ([string]$item.org) -Provider ([string]$item.org) -City ([string]$item.city) -Region ([string]$item.region) -Country ([string]$item.country))
                }
            }
        }

        Save-IpInfoCache
    }

    $result = @{}

    foreach ($ip in $Ips) {
        if ($script:IpInfoCache.ContainsKey($ip)) {
            $result[$ip] = $script:IpInfoCache[$ip]
        }
    }

    return $result
}

# Average of a few pings to one address (ms), or $null if it does not answer ping.
function Get-AvgPing {
    param(
        [string]$Address,
        [int]$Count = 4,
        [int]$Timeout = 800
    )

    $values = @()

    for ($i = 0; $i -lt $Count; $i++) {
        $ms = Test-Icmp -Address $Address -Timeout $Timeout

        if ($null -ne $ms) {
            $values += $ms
        }
        elseif ($i -ge 1 -and $values.Count -eq 0) {
            # Two misses in a row at the start: this server does not answer ping.
            break
        }
    }

    if ($values.Count -eq 0) {
        return $null
    }

    return [math]::Round(($values | Measure-Object -Average).Average, 1)
}

# Average ping of several servers at once. Pings are remembered for $PingCacheMinutes (in memory only), so only
# servers without a recent ping are measured, all at the same time.
# Returns a table: address -> ms (or $null when the server does not answer ping).
function Get-ServerPings {
    param([string[]]$Ips)

    $list = @($Ips)
    $now = [DateTime]::UtcNow
    $need = @()

    foreach ($ip in $list) {
        $hit = $script:PingCache[$ip]

        if ($null -eq $hit -or ($PingCacheMinutes -gt 0 -and ($now - $hit.Time).TotalMinutes -ge $PingCacheMinutes)) {
            $need += $ip
        }
    }

    if ($need.Count -gt 0) {
        $stamp = [DateTime]::UtcNow
        $done = $false

        if ($need.Count -gt 1 -and $MaxThreads -gt 1) {
            try {
                $work = {
                    param($ip, $count)
                    return [pscustomobject]@{ Ms = (Get-AvgPing -Address $ip -Count $count) }
                }

                $got = Invoke-ParallelWork `
                    -Items $need `
                    -Work $work `
                    -Context $PickPingCount `
                    -Functions @('Get-AvgPing', 'Test-Icmp') `
                    -Threads $MaxThreads `
                    -Activity 'Measuring ping' `
                    -ShowProgress

                for ($k = 0; $k -lt $need.Count; $k++) {
                    if ($got.Finished[$k] -and $null -ne $got.Results[$k]) {
                        $script:PingCache[$need[$k]] = [pscustomobject]@{ Ms = $got.Results[$k].Ms; Time = $stamp }
                    }
                }

                $done = $true
            }
            catch {
                $done = $false
            }
        }

        if (-not $done) {
            foreach ($ip in $need) {
                $script:PingCache[$ip] = [pscustomobject]@{ Ms = (Get-AvgPing -Address $ip -Count $PickPingCount); Time = $stamp }
            }
        }
    }

    $result = @{}

    foreach ($ip in $list) {
        $hit = $script:PingCache[$ip]

        if ($null -ne $hit) {
            $result[$ip] = $hit.Ms
        }
        else {
            $result[$ip] = $null
        }
    }

    return $result
}

function Write-PickTable {
    param(
        $Entries,
        [string[]]$Current = @()
    )

    Write-Host ('{0,3}  {1,-16} {2,-9} {3,-26} {4,-22} {5,7} {6,7} {7,8}' -f '#', 'DNS SERVER', 'ASN', 'PROVIDER', 'LOCATION', 'PING', 'DNS ms', 'CONN ms')
    Write-Host ('-' * 117)

    $n = 0

    foreach ($e in $Entries) {
        $n++

        $asn = '-'
        $provider = '-'
        $location = '-'

        if ($null -ne $e.Info) {
            $asn = Format-Cell -Text $e.Info.Asn -Width 9
            $provider = Format-Cell -Text $e.Info.Provider -Width 26
            $location = Format-Cell -Text $e.Info.Location -Width 22
        }

        $ping = 'n/a'

        if ($null -ne $e.Ping) {
            $ping = '{0:N1}' -f $e.Ping
        }

        $mark = ''
        $color = 'White'

        if ($Current.Count -gt 0 -and $e.Row.IP -eq $Current[0]) {
            $mark = '<- in use'
            $color = 'Cyan'
        }
        elseif ($Current.Count -gt 1 -and $e.Row.IP -eq $Current[1]) {
            $mark = '<- backup'
            $color = 'Cyan'
        }
        elseif ($n -eq 1) {
            $color = 'Green'
        }

        Write-Host (
            '{0,3}  {1,-16} {2,-9} {3,-26} {4,-22} {5,7} {6,7:N1} {7,8:N1}  {8}' -f
            $n, $e.Row.IP, $asn, $provider, $location, $ping, $e.Row.DnsMs, $e.Row.ConnMs, $mark
        ) -ForegroundColor $color
    }

    Write-Host ''
    Write-Host 'PING = average ping to the server (n/a = it does not answer ping). DNS ms and CONN ms = lookup time, and' -ForegroundColor DarkGray
    Write-Host 'connection time to the Riot IP it gave. LOCATION is where the address is registered: big services (Cloudflare,' -ForegroundColor DarkGray
    Write-Host 'Google, Quad9 ...) answer from the nearest of many places, so trust PING more. Row 1 is the best by the test.' -ForegroundColor DarkGray
}

# Lists every server that passed the test (provider, location, ping) and lets you pick the DNS yourself.
# It stays open after each pick, so you can switch again; 0 goes back. Nothing is measured again here:
# the ping and the DNS / connection times come from the test that was just run.
function Select-DnsManually {
    param($Rows)

    $passed = @($Rows | Where-Object { $_.Success })

    if ($PickListMax -gt 0) {
        $passed = @($passed | Select-Object -First $PickListMax)
    }

    if ($passed.Count -eq 0) {
        Write-Host 'No server passed the test, so there is nothing to choose from.' -ForegroundColor Yellow
        Wait-Enter
        return
    }

    # Ping, provider and location come from the cache when known; only the missing ones are measured / looked up (in parallel).
    Write-Host ''
    Write-Host 'Getting ping, provider and location...'

    $passedIps = @($passed | ForEach-Object { $_.IP })
    $pings = Get-ServerPings -Ips $passedIps
    $info = Get-IpInfo -Ips $passedIps

    $entries = @(
        $passed | ForEach-Object {
            [pscustomobject]@{
                Row  = $_
                Info = $info[$_.IP]
                Ping = $pings[$_.IP]
            }
        }
    )

    $message = ''
    $messageColor = 'Green'

    while ($true) {
        $adapter = Get-ActiveAdapter -Name $AdapterName
        $current = @()

        if ($adapter) {
            $current = @(Get-CurrentDns -Index $adapter.Index)
        }

        Show-Banner 'CHOOSE A DNS YOURSELF'
        Write-Host ('{0} server(s) that passed the test. This list is the result of that test - nothing is measured again.' -f $entries.Count) -ForegroundColor DarkGray
        Write-Host ''
        Write-PickTable -Entries $entries -Current $current
        Write-Host ''

        if ($info.Count -eq 0) {
            Write-Host 'Provider names could not be looked up (no internet, or the lookup service is busy).' -ForegroundColor Yellow
            Write-Host ''
        }

        if ($message) {
            Write-Host $message -ForegroundColor $messageColor
            Write-Host ''
        }

        Write-Host 'Type a number to use that DNS. Add a second number after a comma for a backup DNS (for example 3,7).'
        Write-Host ' [0] Back to the DNS list menu'
        Write-Host ''

        $choice = Read-Choice 'Number'

        if (-not $choice -or $choice -eq '0') {
            return
        }

        $parts = @($choice -split '[,\s]+' | Where-Object { $_ })
        $valid = ($parts.Count -ge 1 -and $parts.Count -le 2)

        foreach ($part in $parts) {
            if ($part -notmatch '^\d+$' -or [int]$part -lt 1 -or [int]$part -gt $entries.Count) {
                $valid = $false
            }
        }

        if (-not $valid) {
            $message = 'That is not a number from the list.'
            $messageColor = 'Yellow'
            continue
        }

        if (-not $adapter) {
            $message = 'No active network connection found.'
            $messageColor = 'Yellow'
            continue
        }

        $servers = @($entries[[int]$parts[0] - 1].Row.IP)

        if ($parts.Count -eq 2 -and [int]$parts[1] -ne [int]$parts[0]) {
            $servers += $entries[[int]$parts[1] - 1].Row.IP
        }

        try {
            Set-PreferredDns -Index $adapter.Index -Servers $servers
            Write-Log ('DNS on {0} set to {1} (chosen by you)' -f $adapter.Name, ($servers -join ', '))

            $message = ('DNS on {0} is now {1}.' -f $adapter.Name, ($servers -join ', '))
            $messageColor = 'Green'
        }
        catch {
            $message = ('Could not change DNS: {0}' -f $_.Exception.Message)
            $messageColor = 'Red'
        }
    }
}

# Test every server in ips.txt once and show the full ranking, then let you set a DNS.
function Invoke-ListBenchmark {
    param([switch]$Fresh)

    Initialize-IpFile
    [string[]]$ips = @(Get-IPv4Candidates -Path $IpFile)

    Write-Host ('Testing {0} DNS server(s): lookup and connection to the Riot IP it returns (press Q to stop)...' -f $ips.Count)
    Write-Host ''

    $res = Get-DnsRound -Servers $ips -ShowProgress -UseCache -Refresh:$Fresh

    Write-DnsTable -Rows $res.Rows -Winner $res.Winner -MaxRows 0
    Write-Host ''

    if ($res.CachedCount -gt 0) {
        if ($res.CacheAgeSeconds -ge 90) {
            $ageText = '{0} min' -f [math]::Round($res.CacheAgeSeconds / 60)
        }
        else {
            $ageText = '{0} s' -f $res.CacheAgeSeconds
        }

        Write-Host ('{0} of {1} server(s) came from the previous scan (up to {2} old); {3} tested now. Choose [3] below to scan everything again.' -f $res.CachedCount, $ips.Count, $ageText, ($ips.Count - $res.CachedCount)) -ForegroundColor DarkGray
        Write-Host ''
    }

    if ($res.Stopped) {
        Write-Host 'Stopped early - this ranking is incomplete.' -ForegroundColor Yellow
        Wait-Enter
        return
    }

    # Check the failures once more before calling them dead (one lost packet should not remove a good server).
    $failed = @($res.Rows | Where-Object { -not $_.Success } | ForEach-Object { $_.IP })
    $dead = @()

    if ($failed.Count -gt 0) {
        Write-Host ('{0} server(s) did not pass. Checking them once more...' -f $failed.Count)

        $again = Get-DnsRound -Servers $failed

        $dead = @($again.Rows | Where-Object { -not $_.Success } | ForEach-Object { $_.IP })
    }

    if ($dead.Count -gt 0) {
        Write-Host ('{0} server(s) still fail: {1}' -f $dead.Count, ($dead -join ', ')) -ForegroundColor Yellow

        $removeAnswer = ([string](Read-Host 'Remove them from ips.txt? Type Y or remove and press Enter (just Enter = keep them; a copy is kept as ips.txt.bak)')).Trim()

        if ($removeAnswer -ieq 'y' -or $removeAnswer -ieq 'remove') {
            Remove-IpsFromList -Ips $dead
            Write-Host 'Removed.' -ForegroundColor Green
        }
    }

    if (@($res.Ranked).Count -eq 0) {
        Write-Host 'No server passed the test.' -ForegroundColor Yellow
        Wait-Enter
        return
    }

    while ($true) {
        Write-Host ''
        Write-Host 'What next?'

        if ($null -ne $res.Winner) {
            Write-Host (' [1] Set the best server as my DNS ({0})' -f $res.Winner.IP)
        }

        Write-Host ' [2] Choose a DNS myself (provider, location and ping of every server; stays open so you can switch again)'

        if ($res.CachedCount -gt 0) {
            Write-Host ' [3] Scan again now (ignore the saved results)'
        }

        Write-Host ' [0] Back'
        Write-Host ''

        $next = Read-Choice 'Choose'

        if ($next -eq '1' -and $null -ne $res.Winner) {
            Set-DnsFromList -Servers @($res.Winner.IP) -Label 'best from the list test'
            Wait-Enter
            return
        }
        elseif ($next -eq '2') {
            Select-DnsManually -Rows $res.Rows
            return
        }
        elseif ($next -eq '3' -and $res.CachedCount -gt 0) {
            Invoke-ListBenchmark -Fresh
            return
        }
        elseif (-not $next -or $next -eq '0') {
            return
        }
    }
}

# Test candidate DNS servers and add the good ones to ips.txt (after you confirm).
function Add-VerifiedServers {
    param(
        [string[]]$Candidates,
        [string]$Source
    )

    $unique = @($Candidates | Select-Object -Unique)

    try {
        $existing = @(Get-IPv4Candidates -Path $IpFile)
    }
    catch {
        $existing = @()
    }

    $fresh = @($unique | Where-Object { $existing -notcontains $_ })

    Write-Host ('Found {0} address(es); {1} of them are not in ips.txt yet.' -f $unique.Count, $fresh.Count)

    if ($fresh.Count -eq 0) {
        return
    }

    Write-Host ('Testing them now (a good DNS server answers in under {0} ms). Press Q to stop.' -f $ImportMaxDnsMs)

    $good = @()
    $count = 0

    foreach ($ip in $fresh) {
        $count++

        Write-Progress -Activity 'Testing new DNS servers' -Status ('{0} of {1}: {2}' -f $count, $fresh.Count, $ip) -PercentComplete ([int](100 * $count / $fresh.Count))

        $r = Test-DnsUdp -Server $ip -Name $TargetName -Timeout 800

        if ($r.Success -and $r.Ms -lt $ImportMaxDnsMs) {
            $good += $r
        }

        if (Test-StopKey) {
            Write-Host 'Stopped.' -ForegroundColor Yellow
            break
        }
    }

    Write-Progress -Activity 'Testing new DNS servers' -Completed

    if ($good.Count -eq 0) {
        Write-Host 'None of them answered fast enough.' -ForegroundColor Yellow
        return
    }

    $good = @($good | Sort-Object Ms)

    Write-Host ''
    Write-Host ('{0} server(s) passed:' -f $good.Count) -ForegroundColor Green

    foreach ($g in @($good | Select-Object -First 20)) {
        Write-Host ('  {0,-16} {1,7:N1} ms' -f $g.IP, $g.Ms)
    }

    if ($good.Count -gt 20) {
        Write-Host ('  ... and {0} more' -f ($good.Count - 20))
    }

    Write-Host ''

    if (Confirm-Yes ('Add these {0} server(s) to ips.txt?' -f $good.Count)) {
        $added = Add-IpsToList -Ips @($good | ForEach-Object { $_.IP }) -Source $Source
        Write-Host ('Added {0} server(s) to ips.txt.' -f $added) -ForegroundColor Green
    }
}

function Import-IpsFromFile {
    $files = @()

    foreach ($dir in @($KitDir, $ListDir)) {
        if (Test-Path -LiteralPath $dir) {
            $files += @(
                Get-ChildItem -LiteralPath $dir -Filter '*.txt' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne 'ips.txt' -and $_.Name -notlike 'netkit_log*' -and $_.Name -notlike 'valorant_lag_report*' }
            )
        }
    }

    Write-Host 'Text files next to this tool (and in its lists folder):'

    $n = 0

    foreach ($f in $files) {
        $n++
        Write-Host (' [{0}] {1}' -f $n, $f.FullName)
    }

    Write-Host ' [P] Type or drag in the path of another file'
    Write-Host ' [0] Back'
    Write-Host ''

    $c = Read-Choice 'Choose'
    $path = $null

    if (-not $c -or $c -eq '0') {
        return
    }
    elseif ($c -match '^[Pp]$') {
        $path = (Read-Choice 'Path of the text file').Trim('"').Trim()
    }
    elseif ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $files.Count) {
        $path = $files[[int]$c - 1].FullName
    }
    else {
        Write-Host 'Not a valid choice.' -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host 'File not found.' -ForegroundColor Yellow
        return
    }

    $text = [System.IO.File]::ReadAllText($path)
    $found = @(Get-IPv4FromText -Text $text)

    if ($found.Count -eq 0) {
        Write-Host 'No IP addresses found in that file.' -ForegroundColor Yellow
        return
    }

    Add-VerifiedServers -Candidates $found -Source ([System.IO.Path]::GetFileName($path))
}

function Import-IpsFromUrl {
    $url = Read-Choice 'Web address of a page that lists DNS servers (press Enter to cancel)'

    if (-not $url) {
        return
    }

    if ($url -notmatch '^https?://') {
        $url = 'https://' + $url
    }

    Write-Host ('Reading {0} ...' -f $url)

    $html = Get-WebPage -Url $url
    $found = @(Get-IPv4FromText -Text $html -PublicOnly)

    if ($found.Count -eq 0) {
        Write-Host 'No IP addresses found on that page.' -ForegroundColor Yellow
        return
    }

    Add-VerifiedServers -Candidates $found -Source $url
}

# DNS servers that belong to one internet provider (looked up by its ASN on publicdns.info).
function Import-IpsFromAsn {
    $asnText = Read-Choice 'ASN number, for example 4755 or AS4755 (press Enter to cancel)'

    if (-not $asnText) {
        return
    }

    $asn = $asnText -replace '(?i)^AS', ''

    if ($asn -notmatch '^\d+$') {
        Write-Host 'An ASN is a number, for example 4755.' -ForegroundColor Yellow
        return
    }

    $url = 'https://publicdns.info/?q=AS' + $asn

    Write-Host ('Reading {0} ...' -f $url)

    $html = Get-WebPage -Url $url
    $found = [System.Collections.Generic.List[string]]::new()
    $asnPattern = '(?i)(?:^|\W)AS?\s*0*' + $asn + '(?:\W|$)'

    foreach ($row in [regex]::Matches($html, '(?is)<tr\b[^>]*>(.*?)</tr>')) {
        $text = ConvertTo-PlainText -Html $row.Groups[1].Value

        if ($text -notmatch $asnPattern) {
            continue
        }

        foreach ($ip in @(Get-IPv4FromText -Text $text -PublicOnly)) {
            if (-not $found.Contains($ip)) {
                $found.Add($ip)
            }
        }
    }

    if ($found.Count -eq 0) {
        Write-Host ('No public DNS servers found for AS{0}.' -f $asn) -ForegroundColor Yellow
        return
    }

    Add-VerifiedServers -Candidates $found.ToArray() -Source ('publicdns.info AS' + $asn)
}

# The public India DNS list on publicdns.info (several pages).
function Import-IpsIndiaList {
    $pageUrl = 'https://publicdns.info/country/in.html'
    $visited = @{}
    $found = [System.Collections.Generic.List[string]]::new()
    $page = 1
    $anchorPattern = '(?is)<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>(.*?)</a>'

    while ($pageUrl -and -not $visited.ContainsKey($pageUrl) -and $page -le $ImportMaxPages) {
        $visited[$pageUrl] = $true

        Write-Host ('Reading page {0}: {1}' -f $page, $pageUrl)

        $html = Get-WebPage -Url $pageUrl

        # Addresses in the first cell of each table row; if the page has no such table, take every address.
        $before = $found.Count

        foreach ($row in [regex]::Matches($html, '(?is)<tr\b[^>]*>(.*?)</tr>')) {
            $cell = [regex]::Match($row.Groups[1].Value, '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')

            if (-not $cell.Success) {
                continue
            }

            foreach ($ip in @(Get-IPv4FromText -Text (ConvertTo-PlainText -Html $cell.Groups[1].Value) -PublicOnly)) {
                if (-not $found.Contains($ip)) {
                    $found.Add($ip)
                }
            }
        }

        if ($found.Count -eq $before) {
            foreach ($ip in @(Get-IPv4FromText -Text (ConvertTo-PlainText -Html $html) -PublicOnly)) {
                if (-not $found.Contains($ip)) {
                    $found.Add($ip)
                }
            }
        }

        # Find the link to the next page.
        $nextUrl = $null

        foreach ($a in [regex]::Matches($html, $anchorPattern)) {
            $label = (ConvertTo-PlainText -Html $a.Groups[2].Value).ToLower()

            try {
                $full = ([System.Uri]::new([System.Uri]$pageUrl, $a.Groups[1].Value)).AbsoluteUri
            }
            catch {
                continue
            }

            if ($visited.ContainsKey($full) -or $full -notlike '*publicdns.info/country/in*') {
                continue
            }

            if ($label -match '^(next|next\s*[\u00BB\u203A>]+|[\u00BB\u203A>]+)$' -or $label -eq [string]($page + 1)) {
                $nextUrl = $full
                break
            }
        }

        $pageUrl = $nextUrl
        $page++

        if ($pageUrl) {
            Start-Sleep -Milliseconds 800
        }
    }

    if ($found.Count -eq 0) {
        Write-Host 'No DNS servers found on the list pages.' -ForegroundColor Yellow
        return
    }

    Add-VerifiedServers -Candidates $found.ToArray() -Source 'publicdns.info India list'
}

function Invoke-DnsListMenu {
    while ($true) {
        Initialize-IpFile

        $count = 0

        try {
            $count = @(Get-IPv4Candidates -Path $IpFile).Count
        }
        catch {
            $count = 0
        }

        Show-Banner 'DNS LIST (the servers the optimizer tests)'
        Write-Host (' List file: {0}' -f $IpFile)
        Write-Host (' Servers  : {0}' -f $count)
        Write-Host ''
        Write-Host ' [1] Test every server now, show the ranking, and set a DNS (the best one, or one you choose)'
        Write-Host ' [2] Add servers from a text file'
        Write-Host ' [3] Add servers from a web page (any page that lists DNS IPs)'
        Write-Host ' [4] Find the DNS servers of an internet provider by its ASN number'
        Write-Host ' [5] Add the public India DNS list (publicdns.info)'
        Write-Host ' [6] Open ips.txt in Notepad'
        Write-Host ' [0] Back'
        Write-Host ''

        switch (Read-Choice 'Choose') {
            '1' {
                try {
                    Invoke-ListBenchmark
                }
                catch {
                    Write-Host ('Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
                    Wait-Enter
                }
            }
            '2' { Invoke-Safely { Import-IpsFromFile }; Wait-Enter }
            '3' { Invoke-Safely { Import-IpsFromUrl }; Wait-Enter }
            '4' { Invoke-Safely { Import-IpsFromAsn }; Wait-Enter }
            '5' { Invoke-Safely { Import-IpsIndiaList }; Wait-Enter }
            '6' { Invoke-Safely { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $IpFile + '"') } }
            '0' { return }
        }
    }
}
# ======================= manual DNS menu =======================

function Invoke-PresetMenu {
    while ($true) {
        Show-Banner 'SET DNS MANUALLY'
        Show-CurrentDns
        Write-Host ''

        $n = 0

        foreach ($p in $Presets) {
            $n++
            Write-Host (' [{0,2}] {1,-30} {2}' -f $n, $p.Name, ($p.IPs -join ', '))
        }

        Write-Host ''
        Write-Host ' [C] Type my own DNS IPs'
        Write-Host ' [A] Go back to automatic DNS (from your router / provider)'
        Write-Host ' [0] Back'
        Write-Host ''

        $c = Read-Choice 'Choose a number or letter'

        if ($c -eq '0') {
            return
        }
        elseif ($c -match '^[Cc]$') {
            Invoke-Safely { Set-CustomDns }
            Wait-Enter
        }
        elseif ($c -match '^[Aa]$') {
            Invoke-Safely { Reset-DnsAutomatic }
            Wait-Enter
        }
        elseif ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $Presets.Count) {
            $chosen = $Presets[[int]$c - 1]
            Invoke-Safely { Set-DnsFromList -Servers @($chosen.IPs) -Label $chosen.Name }
            Wait-Enter
        }
    }
}

# ======================= voice monitor =======================

# Windows' own internet test: a small text file from Microsoft with known content.
function Test-MicrosoftConnectivity {
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        $response = Invoke-WebRequest -Uri 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 4

        return ([string]$response.Content).Contains('Microsoft Connect Test')
    }
    catch {
        return $false
    }
}

# Checks your DNS and the internet every few seconds and speaks a warning when something fails.
function Invoke-VoiceMonitor {
    Add-Type -AssemblyName System.Speech

    $voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $log = [System.Collections.Generic.List[object]]::new()
    $stop = $false

    try {
        while (-not $stop) {
            $time = '{0:HH:mm:ss}' -f (Get-Date)
            $adapter = Get-ActiveAdapter -Name $AdapterName
            $speak = $null
            $color = 'Green'

            if (-not $adapter) {
                $text = '[{0}] NO CONNECTION - no active network found' -f $time
                $speak = $VoiceNoConnection
                $color = 'Red'
            }
            else {
                $dns = @(Get-CurrentDns -Index $adapter.Index) | Select-Object -First 1
                $dnsOk = $true

                if ($dns) {
                    $check = Test-DnsUdp -Server $dns -Name 'google.com' -Timeout 1500
                    $dnsOk = [bool]$check.Success
                }

                if (-not $dnsOk) {
                    $text = '[{0}] DNS FAILURE - {1} could not resolve google.com' -f $time, $dns
                    $speak = $VoiceDnsProblem
                    $color = 'Red'
                }
                elseif (-not (Test-MicrosoftConnectivity)) {
                    $text = '[{0}] NO CONNECTION - Microsoft connectivity test failed' -f $time
                    $speak = $VoiceNoConnection
                    $color = 'Red'
                }
                else {
                    $dnsText = if ($dns) { $dns } else { 'automatic DNS' }
                    $text = '[{0}] OK - internet reachable, DNS {1} works' -f $time, $dnsText
                }
            }

            $log.Add([pscustomobject]@{ Text = $text; Color = $color })

            while ($log.Count -gt 5) {
                $log.RemoveAt(0)
            }

            Clear-Host
            Write-Host '============================================' -ForegroundColor Cyan
            Write-Host ' VOICE MONITOR   (press Q to stop)' -ForegroundColor Cyan
            Write-Host (' Checks DNS and the internet every {0} seconds and speaks when something fails.' -f $MonitorSeconds) -ForegroundColor Cyan
            Write-Host '============================================' -ForegroundColor Cyan
            Write-Host ''

            foreach ($item in $log) {
                Write-Host $item.Text -ForegroundColor $item.Color
            }

            if ($speak) {
                $voice.Speak($speak)
            }

            $waitWatch = [System.Diagnostics.Stopwatch]::StartNew()

            while ($waitWatch.Elapsed.TotalSeconds -lt $MonitorSeconds) {
                if (Test-StopKey) {
                    $stop = $true
                    break
                }

                Start-Sleep -Milliseconds 100
            }
        }
    }
    finally {
        $voice.Dispose()
    }

    Write-Host ''
    Write-Host 'Voice monitor stopped.' -ForegroundColor Cyan
}

# ======================= bufferbloat test =======================

function Get-BloatGrade {
    param([double]$Increase)

    if ($Increase -lt 15) { return 'A (excellent)' }
    if ($Increase -lt 40) { return 'B (good)' }
    if ($Increase -lt 100) { return 'C (noticeable)' }
    if ($Increase -lt 200) { return 'D (bad)' }

    return 'F (very bad)'
}

# Ping for some seconds while a script block keeps the line busy.
function Get-LoadedPings {
    param(
        [string]$Label,
        [string]$Address,
        [int]$Seconds,
        [scriptblock]$KeepBusy
    )

    $values = [System.Collections.Generic.List[double]]::new()
    $sent = 0
    $watch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($watch.Elapsed.TotalSeconds -lt $Seconds) {
        if ($null -ne $KeepBusy) {
            & $KeepBusy
        }

        $ms = Test-Icmp -Address $Address -Timeout 2000
        $sent++

        if ($null -ne $ms) {
            $values.Add([double]$ms)
        }

        Start-Sleep -Milliseconds 150
    }

    return [pscustomobject]@{
        Name = $Label
        Sent = $sent
        Rtts = $values
    }
}

# Measures how much your ping rises while your line is busy (bufferbloat), using Cloudflare's speed test files.
function Invoke-BufferbloatTest {
    Show-Banner 'BUFFERBLOAT TEST'

    Write-Host 'Bufferbloat is when your ping jumps while something uses your internet (a download, an upload,'
    Write-Host 'a stream). In a game that feels like rubber-banding. This test pings 1.1.1.1 while it'
    Write-Host 'downloads and then uploads test data from speed.cloudflare.com for about 12 seconds each.'
    Write-Host 'It uses roughly 100 to 400 MB of data, depending on your speed.'
    Write-Host ''

    if (-not (Confirm-Yes 'Start the test?')) {
        return
    }

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::DefaultConnectionLimit = 32

    $target = '1.1.1.1'
    $downUrl = 'https://speed.cloudflare.com/__down?bytes=10485760'
    $upUrl = 'https://speed.cloudflare.com/__up'
    $payload = New-Object byte[] 4194304

    Write-Host ''
    Write-Host 'Step 1 of 3: idle ping (8 seconds)...'

    $idle = Get-LoadedPings -Label 'Idle' -Address $target -Seconds 8
    $idleStats = Get-TargetStats -Target $idle

    if ($idleStats.Received -eq 0) {
        Write-Host 'No replies from 1.1.1.1 (ping may be blocked), so the test cannot continue.' -ForegroundColor Yellow
        return
    }

    # Four parallel transfers keep the line full.
    $clients = @()

    for ($i = 0; $i -lt 4; $i++) {
        $client = New-Object System.Net.WebClient
        $client.Headers.Add('User-Agent', 'Mozilla/5.0')
        $clients += $client
    }

    $downStats = $null
    $upStats = $null

    try {
        Write-Host 'Step 2 of 3: ping while downloading (12 seconds)...'

        $keepDown = {
            foreach ($c in $clients) {
                if (-not $c.IsBusy) {
                    try { $c.DownloadDataAsync([System.Uri]$downUrl) } catch { }
                }
            }
        }

        $down = Get-LoadedPings -Label 'Download' -Address $target -Seconds 12 -KeepBusy $keepDown
        $downStats = Get-TargetStats -Target $down

        foreach ($c in $clients) { try { $c.CancelAsync() } catch { } }
        Start-Sleep -Seconds 2

        Write-Host 'Step 3 of 3: ping while uploading (12 seconds)...'

        $keepUp = {
            foreach ($c in $clients) {
                if (-not $c.IsBusy) {
                    try { $c.UploadDataAsync([System.Uri]$upUrl, 'POST', $payload) } catch { }
                }
            }
        }

        $up = Get-LoadedPings -Label 'Upload' -Address $target -Seconds 12 -KeepBusy $keepUp
        $upStats = Get-TargetStats -Target $up

        foreach ($c in $clients) { try { $c.CancelAsync() } catch { } }
        Start-Sleep -Seconds 2
    }
    finally {
        foreach ($c in $clients) { try { $c.Dispose() } catch { } }
    }

    Write-Host ''
    Write-Host ('{0,-16} {1,8} {2,8} {3,8} {4,8}   {5}' -f 'WHEN', 'AVG ms', 'MAX ms', 'LOSS %', 'EXTRA', 'GRADE')
    Write-Host ('-' * 66)
    Write-Host ('{0,-16} {1,8:N0} {2,8:N0} {3,8:N1} {4,8}' -f 'Idle', $idleStats.Avg, $idleStats.Max, $idleStats.Loss, '-')

    $worst = 0.0

    foreach ($row in @(@('While downloading', $downStats), @('While uploading', $upStats))) {
        $label = $row[0]
        $s = $row[1]

        if ($null -eq $s -or $s.Received -eq 0) {
            Write-Host ('{0,-16}   no replies - the line was too busy to measure' -f $label) -ForegroundColor Red
            $worst = [math]::Max($worst, 500)
            continue
        }

        $extra = [double]$s.Avg - [double]$idleStats.Avg
        $worst = [math]::Max($worst, $extra)
        $grade = Get-BloatGrade -Increase $extra
        $color = if ($extra -lt 40) { 'Green' } elseif ($extra -lt 100) { 'Yellow' } else { 'Red' }

        Write-Host (
            '{0,-16} {1,8:N0} {2,8:N0} {3,8:N1} {4,8:N0}   {5}' -f
            $label, $s.Avg, $s.Max, $s.Loss, $extra, $grade
        ) -ForegroundColor $color
    }

    Write-Host ''

    if ($worst -lt 40) {
        Write-Host 'Your ping stays steady when the line is busy. Bufferbloat is not your problem.' -ForegroundColor Green
    }
    else {
        Write-Host 'Your ping rises a lot when the line is busy. When anything uses your internet while you play,' -ForegroundColor Yellow
        Write-Host 'the game feels laggy. The real fix is in your router: turn on SQM / Smart Queue (fq_codel or CAKE)' -ForegroundColor Yellow
        Write-Host 'or set its speed limit to about 90-95% of your line speed. Until then, avoid downloads, updates' -ForegroundColor Yellow
        Write-Host 'and uploads (cloud backup, streaming) while you play.' -ForegroundColor Yellow
    }
}

# ======================= advanced tweaks =======================

# Optional tweaks that trade a little CPU for lower latency. All can be undone.
function Invoke-ApplyAdvancedTweaks {
    if (Test-Path -LiteralPath $AdvBackupFile) {
        Write-Host 'The advanced tweaks are already applied (a backup exists). Undo them first to start over.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host 'These optional tweaks trade a little CPU for lower latency. Undo puts everything back.'
    Write-Host ' 1. Network card: turns off Interrupt Moderation and Large Send Offload'
    Write-Host '    (your connection drops for a few seconds while the card restarts)'
    Write-Host ' 2. Windows: turns off Receive Segment Coalescing'
    Write-Host ''
    Write-Host 'Not every network card has these settings, and the effect can be small.'
    Write-Host 'Left out on purpose: turning off TCP auto-tuning (it can slow your downloads on fiber)'
    Write-Host 'and the TcpAckFrequency / TcpNoDelay values (they only affect TCP; Valorant plays over UDP).'
    Write-Host ''

    if (-not (Confirm-Yes 'Continue?')) {
        Write-Host 'Cancelled.'
        return
    }

    $backup = [ordered]@{
        Nic = $null
        Rsc = $null
    }

    # 1) Network card
    try {
        $adapter = Get-ActiveAdapter -Name $AdapterName

        if ($adapter) {
            $nicPattern = '(?i)^interrupt moderation$|^large send offload'
            $changed = @()

            $props = @(
                Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -match $nicPattern }
            )

            foreach ($prop in $props) {
                $off = $prop.ValidDisplayValues | Where-Object { $_ -match '^(Disabled|Off)$' } | Select-Object -First 1

                if ($off -and $prop.DisplayValue -ne $off) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $off -NoRestart

                    $changed += [pscustomobject]@{
                        DisplayName = $prop.DisplayName
                        OldValue    = $prop.DisplayValue
                    }
                }
            }

            if ($changed.Count -gt 0) {
                $backup.Nic = [ordered]@{
                    Adapter = $adapter.Name
                    Changed = $changed
                }

                Write-Host '1. Restarting the network card (the connection drops for a few seconds)...'
                Restart-NetAdapter -Name $adapter.Name

                Write-Host ('1. Changed {0} setting(s) on {1}.' -f $changed.Count, $adapter.Name) -ForegroundColor Green
            }
            else {
                Write-Host '1. Your network card does not have these settings turned on - nothing to change.'
            }
        }
        else {
            Write-Host '1. No active network connection found - skipped.' -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ('1. Network card not changed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    # 2) Receive Segment Coalescing
    try {
        $setting = Get-NetOffloadGlobalSetting
        $old = [string]$setting.ReceiveSegmentCoalescing

        if ($old -eq 'Enabled') {
            Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disabled
            $backup.Rsc = $old

            Write-Host '2. Receive Segment Coalescing turned off.' -ForegroundColor Green
        }
        else {
            Write-Host '2. Receive Segment Coalescing is already off - nothing to change.'
        }
    }
    catch {
        Write-Host ('2. Receive Segment Coalescing not changed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    if ($null -ne $backup.Nic -or $null -ne $backup.Rsc) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        $backup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $AdvBackupFile -Encoding ASCII
    }

    Write-Host ''
    Write-Host 'Done. Run the connection check again to compare.' -ForegroundColor Cyan
}

function Invoke-UndoAdvancedTweaks {
    if (-not (Test-Path -LiteralPath $AdvBackupFile)) {
        Write-Host 'No backup found, so there is nothing to undo.' -ForegroundColor Yellow
        return
    }

    $backup = Get-Content -LiteralPath $AdvBackupFile -Raw | ConvertFrom-Json

    try {
        if ($backup.Nic) {
            $name = [string]$backup.Nic.Adapter

            foreach ($item in @($backup.Nic.Changed)) {
                Set-NetAdapterAdvancedProperty -Name $name -DisplayName ([string]$item.DisplayName) -DisplayValue ([string]$item.OldValue) -NoRestart
            }

            Write-Host '1. Restarting the network card (the connection drops for a few seconds)...'
            Restart-NetAdapter -Name $name

            Write-Host '1. Network card settings restored.' -ForegroundColor Green
        }
    }
    catch {
        Write-Host ('1. Network card settings not restored: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    try {
        if ($backup.Rsc) {
            Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing ([string]$backup.Rsc)

            Write-Host '2. Receive Segment Coalescing restored.' -ForegroundColor Green
        }
    }
    catch {
        Write-Host ('2. Receive Segment Coalescing not restored: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }

    Remove-Item -LiteralPath $AdvBackupFile -Force

    Write-Host ''
    Write-Host 'Done. Everything is back to how it was.' -ForegroundColor Cyan
}

# ======================= quick actions =======================

function Stop-RiotProcesses {
    $names = @('RiotClientServices', 'RiotClientUx', 'RiotClientUxRender', 'VALORANT-Win64-Shipping', 'VALORANT', 'vgc')
    $closed = 0

    foreach ($name in $names) {
        $found = @(Get-Process -Name $name -ErrorAction SilentlyContinue)

        foreach ($proc in $found) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Write-Host ('Closed {0}' -f $name)
                $closed++
            }
            catch {
                Write-Host ('Could not close {0}: {1}' -f $name, $_.Exception.Message) -ForegroundColor Yellow
            }
        }
    }

    if ($closed -eq 0) {
        Write-Host 'Valorant and Riot Client were not running.'
    }
}

# Deletes Riot Client's local data folder (not your Valorant game settings). You will have to sign in again.
function Clear-RiotCache {
    $folder = Join-Path $env:LOCALAPPDATA 'Riot Games'

    if (-not (Test-Path -LiteralPath $folder)) {
        Write-Host 'There is no Riot Games cache folder to clear.'
        return
    }

    Write-Host 'This closes Riot Client and Valorant, then deletes:'
    Write-Host ('  {0}' -f $folder)
    Write-Host 'You will have to sign in to Riot Client again. Your Valorant game settings are kept.'
    Write-Host ''

    if (-not (Confirm-Yes 'Continue?')) {
        Write-Host 'Cancelled.'
        return
    }

    Stop-RiotProcesses
    Start-Sleep -Seconds 1

    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $folder) {
        Write-Host 'Some files could not be deleted (they are in use). Close everything from Riot and try again.' -ForegroundColor Yellow
    }
    else {
        Write-Host 'Riot cache cleared.' -ForegroundColor Green
    }
}

function Restart-ActiveAdapter {
    $adapter = Get-ActiveAdapter -Name $AdapterName

    if (-not $adapter) {
        Write-Host 'No active network connection found.' -ForegroundColor Yellow
        return
    }

    if (-not (Confirm-Yes ('Restart {0}? Your connection drops for a few seconds.' -f $adapter.Name))) {
        return
    }

    Restart-NetAdapter -Name $adapter.Name

    Write-Host 'Done.' -ForegroundColor Green
}

function Invoke-QuickMenu {
    while ($true) {
        Show-Banner 'QUICK ACTIONS'
        Write-Host ' [1] Close Valorant and Riot Client'
        Write-Host ' [2] Clear the Riot Client cache (you sign in again)'
        Write-Host ' [3] Flush the DNS cache'
        Write-Host ' [4] Restart the network adapter'
        Write-Host ' [5] Show my IP configuration'
        Write-Host ' [0] Back'
        Write-Host ''

        switch (Read-Choice 'Choose') {
            '1' { Invoke-Safely { Stop-RiotProcesses }; Wait-Enter }
            '2' { Invoke-Safely { Clear-RiotCache }; Wait-Enter }
            '3' { Invoke-Safely { Clear-DnsClientCache; Write-Host 'DNS cache flushed.' -ForegroundColor Green }; Wait-Enter }
            '4' { Invoke-Safely { Restart-ActiveAdapter }; Wait-Enter }
            '5' { Invoke-Safely { & ipconfig.exe /all | Out-Host }; Wait-Enter }
            '0' { return }
        }
    }
}

# ======================= settings / start with Windows =======================

function Test-StartupTask {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    return ($null -ne $task)
}

# Starts the auto-optimizer minimized every time you sign in (no permission prompt).
function Enable-StartupTask {
    $user = '{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME

    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c start "" /min "{0}" auto' -f $env:SELF)
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $taskSettings -Description 'Valorant Net Kit auto-optimizer' -Force | Out-Null

    Write-Host 'The auto-optimizer will now start (minimized) every time you sign in.' -ForegroundColor Green
}

function Disable-StartupTask {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

    Write-Host 'Start with Windows turned off.' -ForegroundColor Green
}

function Open-KitFile {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $Path + '"')
    }
    else {
        Write-Host ('{0} does not exist yet.' -f $Path) -ForegroundColor Yellow
    }
}

function Invoke-SettingsMenu {
    while ($true) {
        $enabled = Test-StartupTask
        $state = if ($enabled) { 'ON' } else { 'OFF' }

        Show-Banner 'SETTINGS'
        Write-Host (' Start the auto-optimizer with Windows: {0}' -f $state)
        Write-Host ''
        Write-Host ' [1] Turn "start with Windows" on or off'
        Write-Host ' [2] Open ips.txt (the DNS list)'
        Write-Host ' [3] Open the change log (every DNS change the optimizer made)'
        Write-Host ' [4] Open the last connection report'
        Write-Host ' [5] Open this tool in Notepad to change the settings at the top'
        Write-Host ' [0] Back'
        Write-Host ''

        switch (Read-Choice 'Choose') {
            '1' {
                if ($enabled) {
                    Invoke-Safely { Disable-StartupTask }
                }
                else {
                    Invoke-Safely { Enable-StartupTask }
                }

                Wait-Enter
            }
            '2' { Invoke-Safely { Initialize-IpFile; Open-KitFile -Path $IpFile } }
            '3' { Invoke-Safely { Open-KitFile -Path $LogFile }; Wait-Enter }
            '4' { Invoke-Safely { Open-KitFile -Path $ReportFile }; Wait-Enter }
            '5' { Invoke-Safely { Open-KitFile -Path $env:SELF } }
            '0' { return }
        }
    }
}

# ======================= menus =======================

function Invoke-ConnectionMenu {
    while ($true) {
        Show-Banner 'CONNECTION TOOLS'
        Write-Host ' [1] Connection check: packet loss and jitter, and where the problem is (about a minute)'
        Write-Host ' [2] Voice monitor: speaks a warning when your DNS or the internet fails'
        Write-Host ' [3] Bufferbloat test: your ping while the line is busy (uses data)'
        Write-Host ' [0] Back'
        Write-Host ''

        switch (Read-Choice 'Choose') {
            '1' { Invoke-Safely { Invoke-ConnectionCheck }; Wait-Enter }
            '2' { Invoke-Safely { Invoke-VoiceMonitor }; Wait-Enter }
            '3' { Invoke-Safely { Invoke-BufferbloatTest }; Wait-Enter }
            '0' { return }
        }
    }
}

function Invoke-TweaksMenu {
    while ($true) {
        Show-Banner 'TWEAKS (all can be undone)'
        Write-Host (' Safe tweaks     : {0}' -f $(if (Test-Path -LiteralPath $BackupFile) { 'applied' } else { 'not applied' }))
        Write-Host (' Advanced tweaks : {0}' -f $(if (Test-Path -LiteralPath $AdvBackupFile) { 'applied' } else { 'not applied' }))
        Write-Host ''
        Write-Host ' [1] Apply the safe tweaks (power plan, network card power saving, update sharing)'
        Write-Host ' [2] Undo the safe tweaks'
        Write-Host ' [3] Apply the advanced tweaks (interrupt moderation, large send offload, RSC)'
        Write-Host ' [4] Undo the advanced tweaks'
        Write-Host ' [0] Back'
        Write-Host ''

        switch (Read-Choice 'Choose') {
            '1' { Invoke-Safely { Invoke-ApplyTweaks }; Wait-Enter }
            '2' { Invoke-Safely { Invoke-UndoTweaks }; Wait-Enter }
            '3' { Invoke-Safely { Invoke-ApplyAdvancedTweaks }; Wait-Enter }
            '4' { Invoke-Safely { Invoke-UndoAdvancedTweaks }; Wait-Enter }
            '0' { return }
        }
    }
}

function Invoke-MainMenu {
    while ($true) {
        Show-Banner 'VALORANT NET KIT'
        Show-CurrentDns
        Write-Host ''
        Write-Host ' [1] Auto-optimizer     keeps the best DNS for Valorant set (press Q to stop it)'
        Write-Host ' [2] DNS list           find, add, test and clean the DNS servers it uses'
        Write-Host ' [3] Set DNS manually   presets, your own IPs, back to automatic'
        Write-Host ' [4] Connection tools   packet loss check, voice monitor, bufferbloat test'
        Write-Host ' [5] Tweaks             safe and advanced Windows / network card tweaks'
        Write-Host ' [6] Quick actions      close Valorant, clear cache, flush DNS, restart adapter'
        Write-Host ' [7] Settings           start with Windows, open files'
        Write-Host ' [0] Exit'
        Write-Host ''

        switch (Read-Choice 'Choose') {
            '1' { Invoke-Safely { Invoke-AutoOptimizer }; Wait-Enter }
            '2' { Invoke-DnsListMenu }
            '3' { Invoke-PresetMenu }
            '4' { Invoke-ConnectionMenu }
            '5' { Invoke-TweaksMenu }
            '6' { Invoke-QuickMenu }
            '7' { Invoke-SettingsMenu }
            '0' { exit 0 }
        }
    }
}

# ======================= start =======================

try {
    Assert-Settings

    switch ($env:MODE) {
        'auto' {
            Invoke-Safely { Invoke-AutoOptimizer }
        }
        'kill' {
            Stop-RiotProcesses
            Start-Sleep -Seconds 2
            exit 0
        }
        'restore' {
            Invoke-Safely { Reset-DnsAutomatic }
            Start-Sleep -Seconds 3
            exit 0
        }
    }

    Invoke-MainMenu
}
catch {
    Write-Host ''
    Write-Host ('FATAL ERROR: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
