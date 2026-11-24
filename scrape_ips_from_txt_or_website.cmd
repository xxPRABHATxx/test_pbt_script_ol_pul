@echo off
setlocal EnableExtensions
color 0A
title IPv4 Scraper

:MAIN_MENU
cls
echo ==========================================
echo             IPv4 SCRAPER
echo ==========================================
echo.
echo Choose an input source:
echo   1. Extract IP addresses from a TXT file
echo   2. Scrape a website link once
echo   3. Search DNS by ASN
echo   0. Exit
echo.
choice /c 1230 /n /m "Select a mode [1/2/3/0]: "
if errorlevel 4 goto EXIT_SCRIPT
if errorlevel 3 goto ASN_MENU
if errorlevel 2 goto WEBSITE

goto TXT_FILE

:ASN_MENU
call :ASN_OPTION
title IPv4 Scraper
color 0A
goto MAIN_MENU

:EXIT_SCRIPT
exit /b 0

:ASN_OPTION
set "ASN_RUNTIME=%~dp0_asn_runtime_%RANDOM%_%RANDOM%.cmd"
set "ASN_MARK="
for /f "tokens=1 delims=:" %%A in ('findstr /n /x "#ASN_SOURCE" "%~f0"') do set "ASN_MARK=%%A"
if not defined ASN_MARK (
    echo ERROR: ASN section not found.
    pause
    exit /b 1
)
more +%ASN_MARK% "%~f0" > "%ASN_RUNTIME%"
call "%ASN_RUNTIME%"
del "%ASN_RUNTIME%" >nul 2>&1
exit /b 0

:TXT_FILE
title Extract IPv4 Addresses from TXT Files
echo.
echo Opening the Windows file picker...
echo.

powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQAgAD0AIAAnAFMAdABvAHAAJwANAAoAQQBkAGQALQBUAHkAcABlACAALQBBAHMAcwBlAG0AYgBsAHkATgBhAG0AZQAgAFMAeQBzAHQAZQBtAC4AVwBpAG4AZABvAHcAcwAuAEYAbwByAG0AcwANAAoAJABkAGkAYQBsAG8AZwAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBXAGkAbgBkAG8AdwBzAC4ARgBvAHIAbQBzAC4ATwBwAGUAbgBGAGkAbABlAEQAaQBhAGwAbwBnAA0ACgAkAGQAaQBhAGwAbwBnAC4AVABpAHQAbABlACAAPQAgACcAUwBlAGwAZQBjAHQAIABhACAAVABYAFQAIABmAGkAbABlACAAdABvACAAZQB4AHQAcgBhAGMAdAAgAEkAUAB2ADQAIABhAGQAZAByAGUAcwBzAGUAcwAnAA0ACgAkAGQAaQBhAGwAbwBnAC4ARgBpAGwAdABlAHIAIAA9ACAAJwBUAGUAeAB0ACAAZgBpAGwAZQBzACAAKAAqAC4AdAB4AHQAKQB8ACoALgB0AHgAdAAnAA0ACgAkAGQAaQBhAGwAbwBnAC4ATQB1AGwAdABpAHMAZQBsAGUAYwB0ACAAPQAgACQAZgBhAGwAcwBlAA0ACgAkAGQAaQBhAGwAbwBnAC4AQwBoAGUAYwBrAEYAaQBsAGUARQB4AGkAcwB0AHMAIAA9ACAAJAB0AHIAdQBlAA0ACgBpAGYAIAAoACQAZABpAGEAbABvAGcALgBTAGgAbwB3AEQAaQBhAGwAbwBnACgAKQAgAC0AbgBlACAAWwBTAHkAcwB0AGUAbQAuAFcAaQBuAGQAbwB3AHMALgBGAG8AcgBtAHMALgBEAGkAYQBsAG8AZwBSAGUAcwB1AGwAdABdADoAOgBPAEsAKQAgAHsADQAKACAAIAAgACAAVwByAGkAdABlAC0ASABvAHMAdAAgACcARgBpAGwAZQAgAHMAZQBsAGUAYwB0AGkAbwBuACAAYwBhAG4AYwBlAGwAbABlAGQALgAnAA0ACgAgACAAIAAgAGUAeABpAHQAIAAyAA0ACgB9AA0ACgAkAGkAbgBwAHUAdABQAGEAdABoACAAPQAgACQAZABpAGEAbABvAGcALgBGAGkAbABlAE4AYQBtAGUADQAKACQAcwBvAHUAcgBjAGUARABpAHIAZQBjAHQAbwByAHkAIAA9ACAAWwBJAE8ALgBQAGEAdABoAF0AOgA6AEcAZQB0AEQAaQByAGUAYwB0AG8AcgB5AE4AYQBtAGUAKAAkAGkAbgBwAHUAdABQAGEAdABoACkADQAKACQAcwBvAHUAcgBjAGUAQgBhAHMAZQBOAGEAbQBlACAAPQAgAFsASQBPAC4AUABhAHQAaABdADoAOgBHAGUAdABGAGkAbABlAE4AYQBtAGUAVwBpAHQAaABvAHUAdABFAHgAdABlAG4AcwBpAG8AbgAoACQAaQBuAHAAdQB0AFAAYQB0AGgAKQANAAoAJABvAHUAdABQAGEAdABoACAAPQAgAEoAbwBpAG4ALQBQAGEAdABoACAAJABzAG8AdQByAGMAZQBEAGkAcgBlAGMAdABvAHIAeQAgACgAJABzAG8AdQByAGMAZQBCAGEAcwBlAE4AYQBtAGUAIAArACAAJwBfAGUAeAB0AHIAYQBjAHQAZQBkAF8AaQBwAHMALgB0AHgAdAAnACkADQAKACQAdgBlAHIAcwBpAG8AbgAgAD0AIAAyAA0ACgB3AGgAaQBsAGUAIAAoAFQAZQBzAHQALQBQAGEAdABoACAALQBMAGkAdABlAHIAYQBsAFAAYQB0AGgAIAAkAG8AdQB0AFAAYQB0AGgAKQAgAHsADQAKACAAIAAgACAAJABvAHUAdABQAGEAdABoACAAPQAgAEoAbwBpAG4ALQBQAGEAdABoACAAJABzAG8AdQByAGMAZQBEAGkAcgBlAGMAdABvAHIAeQAgACgAJABzAG8AdQByAGMAZQBCAGEAcwBlAE4AYQBtAGUAIAArACAAJwBfAGUAeAB0AHIAYQBjAHQAZQBkAF8AaQBwAHMAXwAnACAAKwAgACQAdgBlAHIAcwBpAG8AbgAgACsAIAAnAC4AdAB4AHQAJwApAA0ACgAgACAAIAAgACQAdgBlAHIAcwBpAG8AbgArACsADQAKAH0ADQAKACQAdABlAHgAdAAgAD0AIABHAGUAdAAtAEMAbwBuAHQAZQBuAHQAIAAtAEwAaQB0AGUAcgBhAGwAUABhAHQAaAAgACQAaQBuAHAAdQB0AFAAYQB0AGgAIAAtAFIAYQB3AA0ACgAkAHAAYQB0AHQAZQByAG4AIAA9ACAAJwAoAD8APAAhAFsAXABkAC4AXQApACgAPwA6ADIANQBbADAALQA1AF0AfAAyAFsAMAAtADQAXQBcAGQAfAAxAFwAZABcAGQAfABbADEALQA5AF0APwBcAGQAKQAoAD8AOgBcAC4AKAA/ADoAMgA1AFsAMAAtADUAXQB8ADIAWwAwAC0ANABdAFwAZAB8ADEAXABkAFwAZAB8AFsAMQAtADkAXQA/AFwAZAApACkAewAzAH0AKAA/ACEAWwBcAGQALgBdACkAJwANAAoAJABpAHAAcwAgAD0AIABAACgAWwByAGUAZwBlAHgAXQA6ADoATQBhAHQAYwBoAGUAcwAoACQAdABlAHgAdAAsACAAJABwAGEAdAB0AGUAcgBuACkAIAB8ACAARgBvAHIARQBhAGMAaAAtAE8AYgBqAGUAYwB0ACAAewAgACQAXwAuAFYAYQBsAHUAZQAgAH0AIAB8ACAAUwBvAHIAdAAtAE8AYgBqAGUAYwB0ACAALQBVAG4AaQBxAHUAZQApAA0ACgBpAGYAIAAoACQAaQBwAHMALgBDAG8AdQBuAHQAIAAtAGcAdAAgADAAKQAgAHsAIABTAGUAdAAtAEMAbwBuAHQAZQBuAHQAIAAtAEwAaQB0AGUAcgBhAGwAUABhAHQAaAAgACQAbwB1AHQAUABhAHQAaAAgAC0AVgBhAGwAdQBlACAAJABpAHAAcwAgAC0ARQBuAGMAbwBkAGkAbgBnACAAQQBTAEMASQBJACAAfQAgAGUAbABzAGUAIAB7ACAAUwBlAHQALQBDAG8AbgB0AGUAbgB0ACAALQBMAGkAdABlAHIAYQBsAFAAYQB0AGgAIAAkAG8AdQB0AFAAYQB0AGgAIAAtAFYAYQBsAHUAZQAgACcAJwAgAC0ARQBuAGMAbwBkAGkAbgBnACAAQQBTAEMASQBJACAAfQANAAoAVwByAGkAdABlAC0ASABvAHMAdAAgACgAIgBGAG8AdQBuAGQAIAB7ADAAfQAgAHUAbgBpAHEAdQBlACAASQBQAHYANAAgAGEAZABkAHIAZQBzAHMAKABlAHMAKQAuACIAIAAtAGYAIAAkAGkAcABzAC4AQwBvAHUAbgB0ACkADQAKAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACIAUwBhAHYAZQBkACAAdABvADoAIAB7ADAAfQAiACAALQBmACAAJABvAHUAdABQAGEAdABoACkADQAKAA==
if errorlevel 2 (
    echo.
    echo File selection cancelled.
    set /p "RETURN=Press Enter to return to the main menu..."
    goto MAIN_MENU
)
if errorlevel 1 (
    echo.
    echo Extraction failed.
    set /p "RETURN=Press Enter to return to the main menu..."
    goto MAIN_MENU
)

echo.
echo Done.
set /p "RETURN=Press Enter to return to the main menu..."
goto MAIN_MENU

:WEBSITE
title Fresh DNS IP Fetcher
color 0A
set "URL="
set "OUTDIR=%~dp0"

echo.
echo ========================================
echo       FRESH DNS IP FETCHER
echo ========================================
echo.
set /p "URL=Enter website URL: "

if not defined URL (
    echo Error: Website URL cannot be empty.
    set /p "RETURN=Press Enter to return to the main menu..."
    goto MAIN_MENU
)

where powershell.exe >nul 2>&1 || (
    echo PowerShell is required.
    set /p "RETURN=Press Enter to return to the main menu..."
    goto MAIN_MENU
)

cls
echo ========================================
echo       FRESH DNS IP FETCHER
echo ========================================
echo Scraping once...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop'; try {" ^
 " $url=$env:URL; if ($url -notmatch '(?i)^https?://') { $url='https://'+$url }; $uri=[Uri]$url; $siteName=$uri.DnsSafeHost.ToLowerInvariant() -replace '^www\.', '' -replace '[^a-z0-9.-]', '_'; if (-not $siteName) {$siteName='website'}; $pathName=([Uri]::UnescapeDataString($uri.AbsolutePath)).ToLowerInvariant() -replace '^/+', '' -replace '/+$', ''; $pathName=$pathName -replace '[^a-z0-9._-]+', '_' -replace '_{2,}', '_'; if ($pathName) {$siteName += '_'+$pathName}; if ($siteName.Length -gt 180) {$siteName=$siteName.Substring(0,180)}; $outPath=Join-Path $env:OUTDIR ($siteName+'_ips.txt');" ^
 " $r=Invoke-WebRequest -Uri $url -TimeoutSec 20 -UseBasicParsing;" ^
 " $ips=[regex]::Matches($r.Content,'(?<![0-9.])(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?![0-9.])') | ForEach-Object {$_.Value} | Where-Object {$o=$_.Split('.'); ($o | Where-Object {[int]$_ -gt 255}).Count -eq 0} | Select-Object -Unique;" ^
 " if (-not $ips) {throw 'No IP addresses found on the page.'};" ^
 " $ips | Set-Content -LiteralPath $outPath -Encoding ASCII;" ^
 " Write-Host ('Website: '+$url);" ^
 " Write-Host ('Updated: '+(Get-Date));" ^
 " Write-Host ('IP addresses found: '+$ips.Count);" ^
 " Write-Host '';" ^
 " $ips | Select-Object -First 30;" ^
 " Write-Host '';" ^
 " Write-Host ('Saved to: '+$outPath);" ^
 "} catch {" ^
 " Write-Host ('Fetch failed: '+$_.Exception.Message) -ForegroundColor Red;" ^
 "}"

echo.
set /p "RETURN=Press Enter to return to the main menu..."
goto MAIN_MENU


#ASN_SOURCE

@echo off
setlocal EnableExtensions
title PublicDNS.info Parallel DNS Finder
color 0B

set "OUTPUT_DIR=%~dp0"
set "TEMPPS=%TEMP%\ASN_DNS_%RANDOM%_%RANDOM%.ps1"
set "MARK="

for /f "tokens=1 delims=:" %%A in ('findstr /n /x "#POWERSHELL" "%~f0"') do set "MARK=%%A"

if not defined MARK (
    echo ERROR: PowerShell section not found.
    pause
    exit /b 1
)

more +%MARK% "%~f0" > "%TEMPPS%"

:INPUT
cls
echo ============================================
echo    PUBLICDNS.INFO PARALLEL DNS FINDER
echo ============================================
echo.
echo Enter an ASN to search, or 0 to quit.
echo.
set "ASN_VALUE="
set /p "ASN_VALUE=ASN: "

if not defined ASN_VALUE goto INPUT
if "%ASN_VALUE%"=="0" goto END

set "ASN_VALUE=%ASN_VALUE:AS=%"
set "ASN_VALUE=%ASN_VALUE:as=%"

echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TEMPPS%"

echo.
echo ============================================
echo Scan finished.
echo Press any key to return to ASN input.
echo ============================================
pause >nul
goto INPUT

:END
del "%TEMPPS%" >nul 2>&1
echo Goodbye.
exit /b 0

#POWERSHELL
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$asn = ([string]$env:ASN_VALUE).Trim()
$outDir = [string]$env:OUTPUT_DIR
$outputFile = $null

try {
    if ($asn -notmatch '^\d{1,10}$') {
        throw 'Enter a valid ASN, such as AS15169 or 15169.'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Host "Searching PublicDNS.info for AS$asn ..." -ForegroundColor Cyan

    $response = Invoke-WebRequest `
        -Uri "https://publicdns.info/?q=AS$asn" `
        -UseBasicParsing `
        -TimeoutSec 25

    $html = [string]$response.Content
    $rows = [regex]::Matches($html, '(?is)<tr\b[^>]*>(.*?)</tr>')

    $candidates = New-Object 'System.Collections.Generic.HashSet[string]'
    $networkName = $null

    foreach ($tr in $rows) {
        $cells = [regex]::Matches(
            $tr.Groups[1].Value,
            '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>'
        )

        if ($cells.Count -lt 2) { continue }

        $values = @(
            foreach ($cell in $cells) {
                $v = [Net.WebUtility]::HtmlDecode(
                    [regex]::Replace($cell.Groups[1].Value, '<[^>]*>', ' ')
                )
                ($v -replace '\s+', ' ').Trim()
            }
        )

        if (($values -join ' ') -notmatch "(?i)(?:^|\W)AS?\s*0*$asn(?:\W|$)") {
            continue
        }

        $ip = $null
        foreach ($m in [regex]::Matches(
            ($values -join ' '),
            '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])'
        )) {
            $parsed = $null
            if (
                [Net.IPAddress]::TryParse($m.Value, [ref]$parsed) -and
                $parsed.AddressFamily -eq
                    [Net.Sockets.AddressFamily]::InterNetwork
            ) {
                $ip = $m.Value
                break
            }
        }

        if (-not $ip) { continue }
        [void]$candidates.Add($ip)

        # Derive the organization name from the matching result row.
        if (-not $networkName) {
            for ($i = 0; $i -lt $values.Count; $i++) {
                if ($values[$i] -match "(?i)(?:^|\W)AS?\s*0*$asn(?:\W|$)") {
                    for ($j = $i + 1; $j -lt $values.Count; $j++) {
                        if (
                            $values[$j] -and
                            $values[$j] -notmatch '^(?i)AS?\s*\d+$' -and
                            $values[$j] -notmatch '^(?:\d{1,3}\.){3}\d{1,3}$'
                        ) {
                            $networkName = $values[$j]
                            break
                        }
                    }
                }
                if ($networkName) { break }
            }
        }
    }

    $ips = @($candidates | Sort-Object)

    if ($ips.Count -eq 0) {
        throw 'NO_RESULTS: No matching DNS IPs found on the search page. The website HTML may have changed.'
    }

    if ([string]::IsNullOrWhiteSpace($networkName)) {
        throw 'NO_RESULTS: Matching IPs were found, but the organization name could not be identified.'
    }

    $safeName = $networkName -replace '[<>:"/\\|?*\x00-\x1F]', '_'
    $safeName = $safeName.Trim().TrimEnd('.')

    if (-not $safeName) {
        throw 'The organization name is not usable as a filename.'
    }

    $outputFile = Join-Path $outDir "$safeName available dns.txt"

    # Remove stale output before testing this ASN.
    Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue

    Write-Host "`nNetwork: $networkName" -ForegroundColor Cyan
    Write-Host "Candidate IPs: $($ips.Count)"
    Write-Host 'Testing all candidates in parallel...'
    Write-Host 'Ping timeout: 500 ms per server'
    Write-Host 'DNS timeout: 1200 ms per server'
    Write-Host ''

    # Each IP is tested on a separate .NET parallel worker.
    # DNS verification uses a direct UDP query to that specific server.
    if (-not ('ParallelDnsProbe' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Threading.Tasks;

public class DnsProbeResult
{
    public string IP;
    public bool PingOK;
    public long PingMs;
    public bool DnsOK;
    public double DnsMs;
    public string Status;
}

public static class ParallelDnsProbe
{
    static int nextId = 1000;

    static byte[] BuildQuery(ushort id)
    {
        var q = new List<byte>();
        q.Add((byte)(id >> 8)); q.Add((byte)id);
        q.Add(1); q.Add(0);       // standard query
        q.Add(0); q.Add(1);       // one question
        q.Add(0); q.Add(0);       // answers
        q.Add(0); q.Add(0);       // authority
        q.Add(0); q.Add(0);       // additional

        foreach (string label in "example.com".Split('.'))
        {
            byte[] b = System.Text.Encoding.ASCII.GetBytes(label);
            q.Add((byte)b.Length);
            q.AddRange(b);
        }

        q.Add(0);
        q.Add(0); q.Add(1);       // A record
        q.Add(0); q.Add(1);       // IN class
        return q.ToArray();
    }

    static bool TestDns(string ip, int timeoutMs, out double elapsedMs, out string status)
    {
        elapsedMs = 0;
        status = "DNS timeout/error";
        ushort id = (ushort)(System.Threading.Interlocked.Increment(ref nextId) & 0xFFFF);
        Stopwatch sw = Stopwatch.StartNew();

        try
        {
            using (UdpClient udp = new UdpClient(AddressFamily.InterNetwork))
            {
                udp.Client.ReceiveTimeout = timeoutMs;
                udp.Client.SendTimeout = timeoutMs;
                udp.Connect(IPAddress.Parse(ip), 53);

                byte[] query = BuildQuery(id);
                udp.Send(query, query.Length);

                IPEndPoint remote = new IPEndPoint(IPAddress.Any, 0);
                byte[] response = udp.Receive(ref remote);

                sw.Stop();
                elapsedMs = sw.Elapsed.TotalMilliseconds;

                if (response.Length < 12) {
                    status = "Invalid response";
                    return false;
                }

                int responseId = (response[0] << 8) | response[1];
                int flags = (response[2] << 8) | response[3];
                int answers = (response[6] << 8) | response[7];
                int rcode = flags & 15;

                if (responseId != id || (flags & 0x8000) == 0) {
                    status = "Invalid DNS response";
                    return false;
                }

                if (rcode != 0) {
                    status = "DNS error code " + rcode;
                    return false;
                }

                if (answers <= 0) {
                    status = "No answers";
                    return false;
                }

                status = "OK";
                return true;
            }
        }
        catch (SocketException ex)
        {
            sw.Stop();
            elapsedMs = sw.Elapsed.TotalMilliseconds;
            status = ex.SocketErrorCode == SocketError.TimedOut
                ? "DNS timeout" : ex.SocketErrorCode.ToString();
            return false;
        }
        catch (Exception ex)
        {
            sw.Stop();
            elapsedMs = sw.Elapsed.TotalMilliseconds;
            status = ex.GetType().Name;
            return false;
        }
    }

    public static DnsProbeResult[] Run(string[] ips, int maxParallel, int pingTimeoutMs, int dnsTimeoutMs)
    {
        var output = new ConcurrentBag<DnsProbeResult>();

        Parallel.ForEach(
            ips,
            new ParallelOptions { MaxDegreeOfParallelism = maxParallel },
            ip =>
            {
                var r = new DnsProbeResult();
                r.IP = ip;
                r.PingOK = false;
                r.PingMs = -1;

                // Ping independently; a ping failure does not exclude DNS.
                try {
                    using (Ping p = new Ping()) {
                        Stopwatch pw = Stopwatch.StartNew();
                        PingReply reply = p.Send(ip, pingTimeoutMs);
                        pw.Stop();
                        if (reply.Status == IPStatus.Success) {
                            r.PingOK = true;
                            r.PingMs = reply.RoundtripTime;
                        }
                    }
                } catch {}

                r.DnsOK = TestDns(ip, dnsTimeoutMs, out r.DnsMs, out r.Status);
                output.Add(r);
            });

        return output.ToArray();
    }
}
'@
    }

    $maxParallel = [Math]::Min(64, $ips.Count)

    $results = @(
        [ParallelDnsProbe]::Run(
            [string[]]$ips,
            $maxParallel,
            500,
            1200
        )
    )

    # Always print the complete table before considering output.
    $results = @($results | Sort-Object @{Expression={ if ($_.DnsOK) { 0 } else { 1 } }}, DnsMs)

    Write-Host "`n========== COMPLETE TEST RESULTS ==========" -ForegroundColor Cyan

    foreach ($r in $results) {
        $pingText = if ($r.PingOK) {
            "$($r.PingMs) ms"
        } else {
            'No reply'
        }

        if ($r.DnsOK) {
            Write-Host (
                "DNS OK    {0,-16} DNS {1,7:N1} ms | Ping: {2}" -f
                $r.IP, $r.DnsMs, $pingText
            ) -ForegroundColor Green
        } else {
            Write-Host (
                "DNS FAIL  {0,-16} {1,-20} | Ping: {2}" -f
                $r.IP, $r.Status, $pingText
            ) -ForegroundColor DarkGray
        }
    }

    $good = @($results | Where-Object { $_.DnsOK })

    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host ("Candidates tested: {0}" -f $results.Count)
    Write-Host ("DNS servers verified: {0}" -f $good.Count)

    if ($good.Count -gt 0) {
        $good = @($good | Sort-Object DnsMs)
        $goodIPs = [string[]]@($good | ForEach-Object { $_.IP })

        [IO.File]::WriteAllLines(
            $outputFile,
            $goodIPs,
            [Text.Encoding]::ASCII
        )

        Write-Host "`nVERIFIED DNS SERVERS (fastest first)" -ForegroundColor Green
        $good | ForEach-Object {
            Write-Host ("{0,-16} {1,7:N1} ms" -f $_.IP, $_.DnsMs)
        }

        Write-Host "`nSaved file: $outputFile" -ForegroundColor Green
    }
    else {
        Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
        Write-Host "`nNo DNS server passed verification." -ForegroundColor Yellow
        Write-Host 'No verified TXT file was created.'
    }
}
catch {
    if ($outputFile) {
        Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
    }

    if ($_.Exception.Message.StartsWith('NO_RESULTS:')) {
        Write-Host "`n$($_.Exception.Message.Substring(11))" -ForegroundColor Yellow
    }
    else {
        Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host 'No verified TXT file was retained.'
}

Write-Host ''
Read-Host 'Review the results above. Press Enter to return to ASN input'
