@echo off
setlocal EnableExtensions EnableDelayedExpansion
title DNS Scraper, Ping Tester and DNS Manager
color 0A

REM ===== SETTINGS =====
set "ADAPTER=Ethernet"
set "OUT=%~dp0combined_dns_manager_list.txt"
set "LASTDNS=%TEMP%\dns_manager_last_used_root_failover.txt"
set "VOTES=%~dp0dns_ip_votes.txt"
set "VOTETEMP=%TEMP%\dns_votes_%RANDOM%_%RANDOM%.txt"
set "PING_INPUT=%TEMP%\dns_ping_input_%RANDOM%_%RANDOM%.txt"
set "PING_OUTPUT=%TEMP%\dns_ping_output_%RANDOM%_%RANDOM%.txt"
set "INFO_INPUT=%TEMP%\dns_info_input_%RANDOM%_%RANDOM%.txt"
set "INFO_OUTPUT=%TEMP%\dns_info_output_%RANDOM%_%RANDOM%.txt"
set "DNS_NAV_FILE=%TEMP%\dns_navigation_%RANDOM%_%RANDOM%.txt"
set "DNS_INFO_FILE=%TEMP%\dns_info_%RANDOM%_%RANDOM%.txt"
set "DNS_LISTENER_ERR=%TEMP%\dns_listener_err_%RANDOM%_%RANDOM%.txt"
rem Saved provider/location per DNS IP. A name that was fetched once is kept and reused when the lookup is unavailable.
set "DNS_PROV_CACHE=%LOCALAPPDATA%\dns_manager_provider_cache.txt"
set "PING_SCRIPT=%TEMP%\dns_ping_parallel_%RANDOM%_%RANDOM%.ps1"
set "PING_THREADS=64"
set "PING_COUNT=4"
set "PING_TIMEOUT_MS=800"
set "PING_PROBE_TIMEOUT_MS=1200"
rem CONN ms / DNS ms columns: each server is asked to resolve this name (DNS ms), then a TCP connection is opened
rem to the address it returned (CONN ms).
set "DNS_TEST_ENDPOINT=glz-ap-1.ap.a.pvp.net"
set "DNS_TEST_TCP_PORT=443"
set "DNS_TEST_TCP_TIMEOUT_MS=1500"
rem Time one DNS server gets to answer the test lookup (UDP). Servers that do not answer in time show no CONN ms and are hidden.
set "DNS_TEST_DNS_TIMEOUT_MS=1200"
set "URL="

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo PowerShell is required but was not found.
    pause
    exit /b 1
)
rem ESC character used to colour the active DNS row (Windows 10 or newer). If it cannot be read, rows are just not coloured.
set "ESC="
for /f %%E in ('echo prompt $E ^| cmd') do set "ESC=%%E"
if defined ESC if not "!ESC:~1,1!"=="" set "ESC="

:START
cls
echo ============================================================
echo       DNS SCRAPER + PING TESTER + DNS MANAGER
echo ============================================================
echo.
echo This project scrapes IPv4 addresses from a webpage, tests
echo connectivity, then lets you select a DNS server.
echo.
if defined URL (
    echo Current website: !URL!
) else (
    echo No website selected yet.
)
echo.
echo 1. Enter or change website URL and scrape now
echo 2. Scrape current website and test all IPs
echo 3. Test the last saved combined_dns_manager_list.txt again
echo 4. Set Preferred DNS on !ADAPTER!
echo 5. Restore !ADAPTER! DNS to DHCP
echo 6. Show current DNS configuration
echo 7. DNS IP voting system
echo 8. Exit
echo.
set "MAINCHOICE="
set /p "MAINCHOICE=Select option: "
if "!MAINCHOICE!"=="1" goto SETURL
if "!MAINCHOICE!"=="2" goto SCRAPE
if "!MAINCHOICE!"=="3" goto LOADFILE
if "!MAINCHOICE!"=="4" goto SETDNS
if "!MAINCHOICE!"=="5" goto DHCPDNS
if "!MAINCHOICE!"=="6" goto SHOWDNS
if "!MAINCHOICE!"=="7" goto VOTING
if "!MAINCHOICE!"=="8" goto END
echo Invalid option.
pause
goto START

:SETURL
cls
echo Enter the full website URL to scrape.
echo Example: https://dnsmid.com/popular/
echo Example: https://dnsmid.com/asia/  europe/
echo.
set "NEWURL="
set /p "NEWURL=Website URL: "
if not defined NEWURL (
    echo URL cannot be empty.
    pause
    goto START
)
if /i "!NEWURL:~0,7!"=="http://" (
    set "URL=!NEWURL!"
) else if /i "!NEWURL:~0,8!"=="https://" (
    set "URL=!NEWURL!"
) else (
    set "URL=https://!NEWURL!"
)
goto SCRAPE

:SCRAPE
if not defined URL (
    echo Please enter a website URL first.
    pause
    goto SETURL
)
cls
echo ============================================================
echo SCRAPING WEBSITE
echo ============================================================
echo Website: !URL!
echo.
REM Pass URL as an environment variable to avoid PowerShell quoting issues.
set "DNS_SCRAPE_URL=!URL!"
set "DNS_SCRAPE_OUT=!OUT!"
powershell.exe -NoProfile -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQAgAD0AIAAnAFMAdABvAHAAJwAKAGYAdQBuAGMAdABpAG8AbgAgAFQAZQBzAHQALQBJAHAAKABbAHMAdAByAGkAbgBnAF0AJABzACkAIAB7AAoAIAAgACAAIAAkAG8AIAA9ACAAJABzAC4AUwBwAGwAaQB0ACgAJwAuACcAKQAKACAAIAAgACAAaQBmACAAKAAkAG8ALgBDAG8AdQBuAHQAIAAtAG4AZQAgADQAKQAgAHsAIAByAGUAdAB1AHIAbgAgACQAZgBhAGwAcwBlACAAfQAKACAAIAAgACAAJABuACAAPQAgAEAAKAApAAoAIAAgACAAIABmAG8AcgBlAGEAYwBoACAAKAAkAHAAIABpAG4AIAAkAG8AKQAgAHsACgAgACAAIAAgACAAIAAgACAAaQBmACAAKAAkAHAAIAAtAG4AbwB0AG0AYQB0AGMAaAAgACcAXgBcAGQAewAxACwAMwB9ACQAJwAgAC0AbwByACAAWwBpAG4AdABdACQAcAAgAC0AZwB0ACAAMgA1ADUAKQAgAHsAIAByAGUAdAB1AHIAbgAgACQAZgBhAGwAcwBlACAAfQAKACAAIAAgACAAIAAgACAAIAAkAG4AIAArAD0AIABbAGkAbgB0AF0AJABwAAoAIAAgACAAIAB9AAoAIAAgACAAIAByAGUAdAB1AHIAbgAgACgAJABuAFsAMABdACAALQBuAGUAIAAwACAALQBhAG4AZAAgACQAbgBbADAAXQAgAC0AbgBlACAAMQAyADcAIAAtAGEAbgBkACAAJABuAFsAMABdACAALQBsAHQAIAAyADIANAAgAC0AYQBuAGQAIAAtAG4AbwB0ACAAKAAkAG4AWwAwAF0AIAAtAGUAcQAgADEANgA5ACAALQBhAG4AZAAgACQAbgBbADEAXQAgAC0AZQBxACAAMgA1ADQAKQApAAoAfQAKAHQAcgB5ACAAewAKACAAIAAgACAAWwBOAGUAdAAuAFMAZQByAHYAaQBjAGUAUABvAGkAbgB0AE0AYQBuAGEAZwBlAHIAXQA6ADoAUwBlAGMAdQByAGkAdAB5AFAAcgBvAHQAbwBjAG8AbAAgAD0AIABbAE4AZQB0AC4AUwBlAHIAdgBpAGMAZQBQAG8AaQBuAHQATQBhAG4AYQBnAGUAcgBdADoAOgBTAGUAYwB1AHIAaQB0AHkAUAByAG8AdABvAGMAbwBsACAALQBiAG8AcgAgAFsATgBlAHQALgBTAGUAYwB1AHIAaQB0AHkAUAByAG8AdABvAGMAbwBsAFQAeQBwAGUAXQA6ADoAVABsAHMAMQAyAAoAIAAgACAAIAAkAHMAdABhAHIAdAAgAD0AIABbAFUAcgBpAF0AJABlAG4AdgA6AEQATgBTAF8AUwBDAFIAQQBQAEUAXwBVAFIATAAKACAAIAAgACAAaQBmACAAKAAkAHMAdABhAHIAdAAuAFMAYwBoAGUAbQBlACAALQBuAGUAIAAnAGgAdAB0AHAAJwAgAC0AYQBuAGQAIAAkAHMAdABhAHIAdAAuAFMAYwBoAGUAbQBlACAALQBuAGUAIAAnAGgAdAB0AHAAcwAnACkAIAB7ACAAdABoAHIAbwB3ACAAJwBPAG4AbAB5ACAAaAB0AHQAcAAgAGEAbgBkACAAaAB0AHQAcABzACAAYQBkAGQAcgBlAHMAcwBlAHMAIABhAHIAZQAgAGEAbABsAG8AdwBlAGQALgAnACAAfQAKACAAIAAgACAAJABiAGEAcwBlACAAPQAgAFsAcgBlAGcAZQB4AF0AOgA6AEUAcwBjAGEAcABlACgAKAAkAHMAdABhAHIAdAAuAEEAYgBzAG8AbAB1AHQAZQBQAGEAdABoACAALQByAGUAcABsAGEAYwBlACAAJwBcAC4AWwBBAC0AWgBhAC0AegAwAC0AOQBdACsAJAAnACwAIAAnACcAKQApAAoAIAAgACAAIAAkAHAAYQBnAGUAZAAgAD0AIAAnACgAPwBpACkAXgAnACAAKwAgACQAYgBhAHMAZQAgACsAIAAnAFsALQBfAC8AXQA/ACgAcABhAGcAZQBbAC0AXwAvAF0APwApAD8AXABkACsAKABcAC4AWwBBAC0AWgBhAC0AegAwAC0AOQBdACsAKQA/AC8APwAkACcACgAgACAAIAAgACQAbABpAG4AawAgAD0AIAAnACgAPwBpACkAaAByAGUAZgBcAHMAKgA9AFwAcwAqAFsAIgAnACcAXQAoAFsAXgAiACcAJwA8AD4AXABzACMAXQArACkAJwAKACAAIAAgACAAJABpAHAAcgBlACAAPQAgACcAKAA/ADwAIQBbADAALQA5AC4AXQApACgAPwA6AFsAMAAtADkAXQB7ADEALAAzAH0AXAAuACkAewAzAH0AWwAwAC0AOQBdAHsAMQAsADMAfQAoAD8AIQBbADAALQA5AC4AXQApACcACgAgACAAIAAgACQAcwBlAGUAbgAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAJwBTAHkAcwB0AGUAbQAuAEMAbwBsAGwAZQBjAHQAaQBvAG4AcwAuAEcAZQBuAGUAcgBpAGMALgBIAGEAcwBoAFMAZQB0AFsAcwB0AHIAaQBuAGcAXQAnAAoAIAAgACAAIAAkAGYAbwB1AG4AZAAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAJwBTAHkAcwB0AGUAbQAuAEMAbwBsAGwAZQBjAHQAaQBvAG4AcwAuAEcAZQBuAGUAcgBpAGMALgBIAGEAcwBoAFMAZQB0AFsAcwB0AHIAaQBuAGcAXQAnAAoAIAAgACAAIAAkAGkAcABzACAAPQAgAE4AZQB3AC0ATwBiAGoAZQBjAHQAIAAnAFMAeQBzAHQAZQBtAC4AQwBvAGwAbABlAGMAdABpAG8AbgBzAC4ARwBlAG4AZQByAGkAYwAuAEwAaQBzAHQAWwBzAHQAcgBpAG4AZwBdACcACgAgACAAIAAgACQAdABvAGQAbwAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAJwBTAHkAcwB0AGUAbQAuAEMAbwBsAGwAZQBjAHQAaQBvAG4AcwAuAEcAZQBuAGUAcgBpAGMALgBRAHUAZQB1AGUAWwBzAHQAcgBpAG4AZwBdACcACgAgACAAIAAgAFsAdgBvAGkAZABdACQAcwBlAGUAbgAuAEEAZABkACgAJABzAHQAYQByAHQALgBBAGIAcwBvAGwAdQB0AGUAVQByAGkAKQAKACAAIAAgACAAJAB0AG8AZABvAC4ARQBuAHEAdQBlAHUAZQAoACQAcwB0AGEAcgB0AC4AQQBiAHMAbwBsAHUAdABlAFUAcgBpACkACgAgACAAIAAgACQAcABhAGcAZQBzACAAPQAgADAACgAgACAAIAAgAHcAaABpAGwAZQAgACgAJAB0AG8AZABvAC4AQwBvAHUAbgB0ACAALQBnAHQAIAAwACAALQBhAG4AZAAgACQAcABhAGcAZQBzACAALQBsAHQAIAAzADAAKQAgAHsACgAgACAAIAAgACAAIAAgACAAaQBmACAAKAAkAHAAYQBnAGUAcwAgAC0AZwB0ACAAMAApACAAewAgAFMAdABhAHIAdAAtAFMAbABlAGUAcAAgAC0ATQBpAGwAbABpAHMAZQBjAG8AbgBkAHMAIAAyADUAMAAgAH0ACgAgACAAIAAgACAAIAAgACAAJAB1AHIAbAAgAD0AIAAkAHQAbwBkAG8ALgBEAGUAcQB1AGUAdQBlACgAKQAKACAAIAAgACAAIAAgACAAIAB0AHIAeQAgAHsAIAAkAHIAIAA9ACAASQBuAHYAbwBrAGUALQBXAGUAYgBSAGUAcQB1AGUAcwB0ACAALQBVAHIAaQAgACQAdQByAGwAIAAtAFQAaQBtAGUAbwB1AHQAUwBlAGMAIAAzADAAIAAtAFUAcwBlAEIAYQBzAGkAYwBQAGEAcgBzAGkAbgBnACAALQBNAGEAeABpAG0AdQBtAFIAZQBkAGkAcgBlAGMAdABpAG8AbgAgADMAIAB9AAoAIAAgACAAIAAgACAAIAAgAGMAYQB0AGMAaAAgAHsAIABpAGYAIAAoACQAcABhAGcAZQBzACAALQBlAHEAIAAwACkAIAB7ACAAdABoAHIAbwB3ACAAfQA7ACAAYwBvAG4AdABpAG4AdQBlACAAfQAKACAAIAAgACAAIAAgACAAIAAkAHAAYQBnAGUAcwArACsACgAgACAAIAAgACAAIAAgACAAJABoAHQAbQBsACAAPQAgAFsAcwB0AHIAaQBuAGcAXQAkAHIALgBDAG8AbgB0AGUAbgB0AAoAIAAgACAAIAAgACAAIAAgAGYAbwByAGUAYQBjAGgAIAAoACQAbQAgAGkAbgAgAFsAcgBlAGcAZQB4AF0AOgA6AE0AYQB0AGMAaABlAHMAKAAkAGgAdABtAGwALAAgACQAaQBwAHIAZQApACkAIAB7AAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAaQBmACAAKAAoAFQAZQBzAHQALQBJAHAAIAAkAG0ALgBWAGEAbAB1AGUAKQAgAC0AYQBuAGQAIAAkAGYAbwB1AG4AZAAuAEEAZABkACgAJABtAC4AVgBhAGwAdQBlACkAKQAgAHsAIAAkAGkAcABzAC4AQQBkAGQAKAAkAG0ALgBWAGEAbAB1AGUAKQAgAH0ACgAgACAAIAAgACAAIAAgACAAfQAKACAAIAAgACAAIAAgACAAIABmAG8AcgBlAGEAYwBoACAAKAAkAGgAIABpAG4AIABbAHIAZQBnAGUAeABdADoAOgBNAGEAdABjAGgAZQBzACgAJABoAHQAbQBsACwAIAAkAGwAaQBuAGsAKQApACAAewAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgAHQAcgB5ACAAewAgACQAYQAgAD0AIABbAFUAcgBpAF0AOgA6AG4AZQB3ACgAJABzAHQAYQByAHQALAAgACQAaAAuAEcAcgBvAHUAcABzAFsAMQBdAC4AVgBhAGwAdQBlACkAIAB9ACAAYwBhAHQAYwBoACAAewAgAGMAbwBuAHQAaQBuAHUAZQAgAH0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIABpAGYAIAAoACQAYQAuAEgAbwBzAHQAIAAtAG4AZQAgACQAcwB0AGEAcgB0AC4ASABvAHMAdAAgAC0AbwByACAAKAAkAGEALgBTAGMAaABlAG0AZQAgAC0AbgBlACAAJwBoAHQAdABwACcAIAAtAGEAbgBkACAAJABhAC4AUwBjAGgAZQBtAGUAIAAtAG4AZQAgACcAaAB0AHQAcABzACcAKQApACAAewAgAGMAbwBuAHQAaQBuAHUAZQAgAH0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAkAGkAcwBQAGEAZwBlACAAPQAgACgAJABhAC4AQQBiAHMAbwBsAHUAdABlAFAAYQB0AGgAIAAtAG0AYQB0AGMAaAAgACQAcABhAGcAZQBkACkAIAAtAG8AcgAgACgAJABhAC4AQQBiAHMAbwBsAHUAdABlAFAAYQB0AGgAIAAtAGUAcQAgACQAcwB0AGEAcgB0AC4AQQBiAHMAbwBsAHUAdABlAFAAYQB0AGgAIAAtAGEAbgBkACAAJABhAC4AUQB1AGUAcgB5ACAALQBtAGEAdABjAGgAIAAnACgAPwBpACkAWwA/ACYAXQAoAHAAYQBnAGUAfABwAHwAcABnACkAPQBcAGQAKwAnACkACgAgACAAIAAgACAAIAAgACAAIAAgACAAIABpAGYAIAAoACQAaQBzAFAAYQBnAGUAIAAtAGEAbgBkACAAJABzAGUAZQBuAC4AQwBvAHUAbgB0ACAALQBsAHQAIAA2ADAAIAAtAGEAbgBkACAAJABzAGUAZQBuAC4AQQBkAGQAKAAkAGEALgBBAGIAcwBvAGwAdQB0AGUAVQByAGkAKQApACAAewAgACQAdABvAGQAbwAuAEUAbgBxAHUAZQB1AGUAKAAkAGEALgBBAGIAcwBvAGwAdQB0AGUAVQByAGkAKQAgAH0ACgAgACAAIAAgACAAIAAgACAAfQAKACAAIAAgACAAfQAKACAAIAAgACAAaQBmACAAKAAkAGkAcABzAC4AQwBvAHUAbgB0ACAALQBlAHEAIAAwACkAIAB7ACAAdABoAHIAbwB3ACAAJwBOAG8AIAB2AGEAbABpAGQAIABJAFAAdgA0ACAAYQBkAGQAcgBlAHMAcwBlAHMAIABmAG8AdQBuAGQAIABvAG4AIAB0AGgAZQAgAHAAYQBnAGUALgAnACAAfQAKACAAIAAgACAAWwBTAHkAcwB0AGUAbQAuAEkATwAuAEYAaQBsAGUAXQA6ADoAVwByAGkAdABlAEEAbABsAEwAaQBuAGUAcwAoACQAZQBuAHYAOgBEAE4AUwBfAFMAQwBSAEEAUABFAF8ATwBVAFQALAAgAFsAcwB0AHIAaQBuAGcAWwBdAF0AJABpAHAAcwAsACAAWwBTAHkAcwB0AGUAbQAuAFQAZQB4AHQALgBFAG4AYwBvAGQAaQBuAGcAXQA6ADoAQQBTAEMASQBJACkACgAgACAAIAAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACIAUwBjAHIAYQBwAGUAIABzAHUAYwBjAGUAcwBzAGYAdQBsADoAIAB7ADAAfQAgAHUAbgBpAHEAdQBlACAASQBQAHYANAAgAGEAZABkAHIAZQBzAHMAKABlAHMAKQAgAGYAcgBvAG0AIAB7ADEAfQAgAHAAYQBnAGUAKABzACkAIABzAGEAdgBlAGQALgAiACAALQBmACAAJABpAHAAcwAuAEMAbwB1AG4AdAAsACAAJABwAGEAZwBlAHMAKQAKACAAIAAgACAAJABpAHAAcwAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBGAGkAcgBzAHQAIAA0ADAAIAB8ACAARgBvAHIARQBhAGMAaAAtAE8AYgBqAGUAYwB0ACAAewAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACIAIAAgAHsAMAB9ACIAIAAtAGYAIAAkAF8AKQAgAH0ACgB9AAoAYwBhAHQAYwBoACAAewAKACAAIAAgACAAVwByAGkAdABlAC0ASABvAHMAdAAgACgAIgBTAGMAcgBhAHAAZQAgAGYAYQBpAGwAZQBkADoAIAB7ADAAfQAiACAALQBmACAAJABfAC4ARQB4AGMAZQBwAHQAaQBvAG4ALgBNAGUAcwBzAGEAZwBlACkAIAAtAEYAbwByAGUAZwByAG8AdQBuAGQAQwBvAGwAbwByACAAUgBlAGQACgAgACAAIAAgAGUAeABpAHQAIAAxAAoAfQAKAA==
if errorlevel 1 (
    echo.
    echo Scraping failed. Check the URL and internet connection.
    pause
    goto START
)
echo.
echo Saved to: !OUT!
echo.
pause
goto LOADFILE

:LOADFILE
if not exist "!OUT!" (
    echo No saved combined_dns_manager_list.txt found. Scrape a website first.
    pause
    goto START
)
set /a COUNT=0
for /f "usebackq eol=# tokens=* delims=" %%I in ("!OUT!") do (
    set "LINE=%%I"
    if defined LINE (
        set /a COUNT+=1
        set "IP[!COUNT!]=!LINE!"
    )
)
if !COUNT! EQU 0 (
    echo No IP addresses found in combined_dns_manager_list.txt.
    pause
    goto START
)
goto TESTIPS

:TESTIPS
cls
echo ============================================================
echo       TESTING SCRAPED DNS IP ADDRESSES
echo ============================================================
echo IP list: !OUT!
echo.
echo Filter: only DNS servers with a readable CONN ms are kept (ping may fail).
echo.
set /a ONLINE=0
rem Write the IP list and extract the embedded runspace-pool tester.
>"!PING_INPUT!" (
    for /l %%N in (1,1,!COUNT!) do echo(!IP[%%N]!
)
for /l %%N in (1,1,!COUNT!) do set "IP[%%N]="
del "!PING_OUTPUT!" >nul 2>&1
call :EXTRACTPINGSCRIPT
if errorlevel 1 (
    echo.
    echo Could not extract the embedded PowerShell runspace-pool script.
    pause
    goto START
)
set "DNS_PING_INPUT=!PING_INPUT!"
set "DNS_PING_OUTPUT=!PING_OUTPUT!"
set "DNS_PING_COUNT=!PING_COUNT!"
set "DNS_PING_TIMEOUT_MS=!PING_TIMEOUT_MS!"
set "DNS_PING_PROBE_TIMEOUT_MS=!PING_PROBE_TIMEOUT_MS!"
set "DNS_PING_THREADS=!PING_THREADS!"
echo Testing !COUNT! DNS servers concurrently with !PING_THREADS! worker threads...
echo.
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "!PING_SCRIPT!"
set "PTRC=!errorlevel!"
del "!PING_SCRIPT!" >nul 2>&1
if not "!PTRC!"=="0" (
    echo.
    echo The parallel ping test failed to run.
    pause
    goto START
)
if not exist "!PING_OUTPUT!" (
    echo.
    echo The parallel ping test did not produce any results.
    pause
    goto START
)
for /f "usebackq tokens=1-9 delims=|" %%A in ("!PING_OUTPUT!") do (
    set "RIP=%%A"
    set "RCOUNT=%%B"
    set "RAVG=%%E"
    set "RLOSS=%%F"
    set "RDNS=%%H"
    set "RCONN=%%I"
    rem Only CONN ms decides: a server is listed only if CONN ms is a real number. Ping may fail (PING ms shows N/A) and it is still kept.
    set "CONNNUM="
    echo(!RCONN!| findstr /r "^[0-9][0-9]*$" >nul && set "CONNNUM=1"
    set "ACCEPT="
    if defined CONNNUM set "ACCEPT=1"
    if defined ACCEPT (
        set /a ONLINE+=1
        set "REF[!ONLINE!]=!RIP!"
        set "REFPROVIDER[!ONLINE!]=Unavailable"
        set "REFLOCATION[!ONLINE!]=Unavailable"
        set "REFAVG[!ONLINE!]=!RAVG!ms"
        if /i "!RAVG!"=="N/A" set "REFAVG[!ONLINE!]=N/A"
        set "REFLOSS[!ONLINE!]=!RLOSS!"
        set "REFDNS[!ONLINE!]=!RDNS!ms"
        if /i "!RDNS!"=="N/A" set "REFDNS[!ONLINE!]=N/A"
        set "REFCONN[!ONLINE!]=!RCONN!ms"
        if /i "!RCONN!"=="N/A" set "REFCONN[!ONLINE!]=N/A"
    )
)
del "!PING_INPUT!" "!PING_OUTPUT!" >nul 2>&1
call :LOOKUPINFO
goto RESULTS

:RESULTS
cls
echo ============================================================
echo                  ONLINE PING RESULTS
echo ============================================================
echo.
echo Tested !COUNT! DNS servers concurrently with !PING_THREADS! worker threads.
echo.
if !ONLINE! EQU 0 (
    echo No IPs with a readable CONN ms were found.
) else (
    echo( REF.    IP ADDRESS         CONN ms   DNS ms  PING ms  LOSS  PROVIDER                 LOCATION
    echo(--------------------------------------------------------------------------------------------------------------
    for /l %%N in (1,1,!ONLINE!) do (
        set "PAD=   %%N"
        set "CREF=!PAD:~-4!."
        set "PAD=!REF[%%N]!                "
        set "CIP=!PAD:~0,16!"
        set "PAD=        !REFCONN[%%N]!"
        set "CCONN=!PAD:~-8!"
        set "PAD=        !REFDNS[%%N]!"
        set "CDNS=!PAD:~-8!"
        set "PAD=        !REFAVG[%%N]!"
        set "CPING=!PAD:~-8!"
        set "PAD=    !REFLOSS[%%N]!"
        set "CLOSS=!PAD:~-5!"
        set "CPROV=!REFPROVIDER[%%N]!                        "
        set "CPROV=!CPROV:~0,24!"
        set "CLOC=!REFLOCATION[%%N]!                                  "
        set "CLOC=!CLOC:~0,34!"
        set "DNS_RESULT_LINE=!CREF!    !CIP! !CCONN! !CDNS! !CPING! !CLOSS! !CPROV! !CLOC!"
        set "DNS_RESULT_ACTIVE=0"
        for /l %%D in (1,1,!CURRENTDNSCOUNT!) do if /i "!REF[%%N]!"=="!CURRENTDNS[%%D]!" set "DNS_RESULT_ACTIVE=1"
        set "RS_PRE="
        set "RS_POST="
        if "!DNS_RESULT_ACTIVE!"=="1" if defined ESC (
            set "RS_PRE=!ESC![38;2;0;255;255m"
            set "RS_POST=!ESC![92;40m"
        )
        echo(!RS_PRE!!DNS_RESULT_LINE!!RS_POST!
    )
)
echo.
echo 1. Set Preferred DNS using an online result
echo 2. Re-test saved IP list
echo 3. Scrape website again
echo 4. Main menu
echo 5. DNS IP voting system
echo.
set "RCHOICE="
set /p "RCHOICE=Select option: "
if "!RCHOICE!"=="1" goto SETDNS
if "!RCHOICE!"=="2" goto LOADFILE
if "!RCHOICE!"=="3" goto SCRAPE
if "!RCHOICE!"=="4" goto START
if "!RCHOICE!"=="5" goto VOTING
echo Invalid option.
pause
goto RESULTS


:VOTING
cls
echo ============================================================
echo                    DNS IP VOTING SYSTEM
echo ============================================================
echo.
echo 1. View vote result list
echo 2. Search an IP and vote
echo 3. Return to main menu
echo.
set "VOTE_MENU_CHOICE="
set /p "VOTE_MENU_CHOICE=Select option: "
if "!VOTE_MENU_CHOICE!"=="1" goto VOTERESULTS
if "!VOTE_MENU_CHOICE!"=="2" goto VOTESEARCH
if "!VOTE_MENU_CHOICE!"=="3" goto START
goto VOTING

:VOTESEARCH
cls
echo ============================================================
echo                  SEARCH AND VOTE FOR DNS IP
echo ============================================================
echo.
set "VOTE_IP="
set /p "VOTE_IP=Enter IPv4 address (or Q to return): "
if /i "!VOTE_IP!"=="Q" goto VOTING
if not defined VOTE_IP goto VOTESEARCH
call :CHECKIPV4
if not defined IPOK (
    echo Please enter a valid IPv4 address, for example 8.8.8.8
    pause
    goto VOTESEARCH
)
call :GETVOTECOUNT
echo.
echo IP: !VOTE_IP!
echo Votes: !VOTE_COUNT!
echo.
echo 1. Vote for this IP
echo 2. Search another IP
echo 3. View vote result list
echo 4. Return to voting menu
set "VOTE_CHOICE="
set /p "VOTE_CHOICE=Select option: "
if "!VOTE_CHOICE!"=="2" goto VOTESEARCH
if "!VOTE_CHOICE!"=="3" goto VOTERESULTS
if "!VOTE_CHOICE!"=="4" goto VOTING
if not "!VOTE_CHOICE!"=="1" goto VOTESEARCH
call :CASTVOTE
echo.
echo Vote recorded successfully.
echo.
echo Updated vote result:
echo IP: !VOTE_IP!
echo Votes: !VOTE_COUNT!
echo.
echo ============================================================
echo                       ALL VOTE RESULTS
echo ============================================================
echo IP ADDRESS             VOTES
echo ------------------------------------------------------------
if exist "!VOTES!" (
    for /f "usebackq tokens=1,2 delims=|" %%A in ("!VOTES!") do echo %%A                  %%B
) else (
    echo No votes recorded yet.
)
echo.
pause
goto VOTESEARCH

:VOTERESULTS
cls
echo ============================================================
echo                       VOTE RESULTS
echo ============================================================
echo IP ADDRESS             VOTES
echo ------------------------------------
if not exist "!VOTES!" (
    echo No votes recorded yet.
) else (
    for /f "usebackq tokens=1,2 delims=|" %%A in ("!VOTES!") do echo %%A                  %%B
)
echo.
echo Counts only: IP address and total votes.
echo 1. Search and vote for an IP
 echo 2. Return to voting menu
set "VRCHOICE="
set /p "VRCHOICE=Select option: "
if "!VRCHOICE!"=="1" goto VOTESEARCH
if "!VRCHOICE!"=="2" goto VOTING
goto VOTERESULTS

:CHECKIPV4
rem IPOK=1 only when VOTE_IP looks like a plain IPv4 address (stops odd text from breaking the vote file).
set "IPOK="
if not "!VOTE_IP:~15,1!"=="" exit /b
echo(!VOTE_IP!| findstr /r /x "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul && set "IPOK=1"
exit /b

:GETVOTECOUNT
set "VOTE_COUNT=0"
if exist "!VOTES!" (
    for /f "usebackq tokens=1,2 delims=|" %%A in ("!VOTES!") do if /i "%%A"=="!VOTE_IP!" set "VOTE_COUNT=%%B"
)
exit /b

:CASTVOTE
call :GETVOTECOUNT
set /a NEW_VOTE_COUNT=VOTE_COUNT+1
if not exist "!VOTES!" type nul > "!VOTES!"
>"!VOTETEMP!" (
    set "VOTE_FOUND="
    for /f "usebackq tokens=1,2 delims=|" %%A in ("!VOTES!") do (
        if /i "%%A"=="!VOTE_IP!" (
            echo !VOTE_IP!^|!NEW_VOTE_COUNT!
            set "VOTE_FOUND=1"
        ) else (
            echo %%A^|%%B
        )
    )
    if not defined VOTE_FOUND echo !VOTE_IP!^|!NEW_VOTE_COUNT!
)
move /y "!VOTETEMP!" "!VOTES!" >nul
set "VOTE_COUNT=!NEW_VOTE_COUNT!"
exit /b

:SETDNS
if not defined ONLINE set "ONLINE=0"
if !ONLINE! LEQ 0 (
    echo No usable DNS servers with a readable CONN ms are available in the current results.
    echo You can scrape and test again, or use another DNS tool to verify a server.
    pause
    goto START
)
set "DNSINDEX=1"
set "LASTDNSIP="
if exist "!LASTDNS!" set /p "LASTDNSIP="<"!LASTDNS!"
if defined LASTDNSIP for /l %%N in (1,1,!ONLINE!) do if /i "!REF[%%N]!"=="!LASTDNSIP!" set "DNSINDEX=%%N"
cls
echo ============================================================
echo                 DNS SERVER SELECTION
echo ============================================================
echo DNS candidates are used in the numbered order below.
echo Press ENTER to start with server !DNSINDEX! (last used when available); press 0 to cancel.
echo During selection: ENTER = next DNS; BACKSPACE = previous DNS; Q = online ping results.
echo.
echo( REF.    IP ADDRESS         CONN ms   DNS ms  PING ms  PROVIDER                 LOCATION
echo(------------------------------------------------------------------------------------------------------------
call :LOOKUPINFO
for /l %%N in (1,1,!ONLINE!) do (
    set "PAD=   %%N"
    set "CREF=!PAD:~-4!."
    set "PAD=!REF[%%N]!                "
    set "CIP=!PAD:~0,16!"
    set "PAD=        !REFCONN[%%N]!"
    set "CCONN=!PAD:~-8!"
    set "PAD=        !REFDNS[%%N]!"
    set "CDNS=!PAD:~-8!"
    set "PAD=        !REFAVG[%%N]!"
    set "CPING=!PAD:~-8!"
    set "CPROV=!REFPROVIDER[%%N]!                        "
    set "CPROV=!CPROV:~0,24!"
    set "CLOC=!REFLOCATION[%%N]!                                  "
    set "CLOC=!CLOC:~0,34!"
    echo(!CREF!    !CIP! !CCONN! !CDNS! !CPING!  !CPROV! !CLOC!
)
echo.
echo Current DNS configuration:
echo DNS IP            CONN ms   DNS ms  PING ms  PROVIDER                 LOCATION
echo ----------------------------------------------------------------------------------------------------
call :PRINTCURRENTROWS
echo.
set "AUTOSTART="
set /p "AUTOSTART=Press ENTER to start (0 to cancel): "
if "!AUTOSTART!"=="0" goto RESULTS
if defined AUTOSTART (
    echo Please press ENTER to start, or 0 to cancel.
    pause
    goto SETDNS
)
:APPLYSELECTED
call :APPLYDNS
if errorlevel 1 (
    echo Failed to set the first DNS server. Check adapter name and run as Administrator.
    pause
    goto RESULTS
)
goto DNSMONITOR

:APPLYDNS
call :GETCURRENTDNS
cls
call :MONITORHEADER
netsh interface ipv4 set dnsservers name="!ADAPTER!" source=static address=!DNS! register=primary validate=no
if errorlevel 1 exit /b 1
set "CURRENTDNSCOUNT=1"
set "CURRENTDNS[1]=!DNS!"
set "CURRENTDNSPROVIDER[1]=Unavailable"
set "CURRENTDNSLOCATION[1]=Unavailable"
for /l %%K in (1,1,!ONLINE!) do if "!REF[%%K]!"=="!DNS!" (
    set "CURRENTDNSPROVIDER[1]=!REFPROVIDER[%%K]!"
    set "CURRENTDNSLOCATION[1]=!REFLOCATION[%%K]!"
)
rem Flush Windows DNS resolver cache after each successful DNS change (quiet).
ipconfig /flushdns >nul 2>&1
rem Record the new DNS only now (after set + flush).
>"!LASTDNS!" echo(!DNS!
rem Provider/location of the new DNS are already in REFPROVIDER/REFLOCATION (set above), so no
rem PowerShell lookup is done here - it ran on EVERY ENTER/BACKSPACE and was the main source of lag.
exit /b 0

:DNSMONITOR
cls
call :MONITORHEADER
del /q "!DNS_NAV_FILE!" >nul 2>&1
powershell.exe -NoProfile -NonInteractive -Command "$old=[Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput=$true; $q=[char]34; $n=[int]$env:ONLINE; $orig=[int]$env:DNSINDEX; $idx=$orig; $applied=$orig; $pend=$false; $last=[DateTime]::UtcNow; $tick=0; $result=0; $fail=0; $info=@{}; $cache=@{}; try{if(Test-Path -LiteralPath $env:DNS_PROV_CACHE){foreach($l in Get-Content -LiteralPath $env:DNS_PROV_CACHE -Encoding UTF8){$x=$l -split '\|',3; if($x.Count -eq 3 -and $x[0].Trim() -match '^\d{1,3}(\.\d{1,3}){3}$' -and $x[1].Trim() -and $x[2].Trim()){$cache[$x[0].Trim()]=@{p=($x[1] -replace '[^\p{L}\p{N} .,_/+-]',' ').Trim();l=($x[2] -replace '[^\p{L}\p{N} .,_/+-]',' ').Trim()}}}}}catch{}; $fetch=$null; $fetchWc=$null; $fetchIp=''; $fetchAt=[DateTime]::MinValue; $fetchStart=[DateTime]::MinValue; function GetIp($i){[Environment]::GetEnvironmentVariable('REF['+$i+']')} function Prov($i){$k=GetIp $i; if($info.ContainsKey($k)){return $info[$k].p}; $e=[Environment]::GetEnvironmentVariable('REFPROVIDER['+$i+']'); if((-not $e -or $e -eq 'Unavailable') -and $cache.ContainsKey($k)){return $cache[$k].p}; return $e} function Loc($i){$k=GetIp $i; if($info.ContainsKey($k)){return $info[$k].l}; $e=[Environment]::GetEnvironmentVariable('REFLOCATION['+$i+']'); if((-not $e -or $e -eq 'Unavailable') -and $cache.ContainsKey($k)){return $cache[$k].l}; return $e} function Run($e,$a,$w){$s=New-Object System.Diagnostics.ProcessStartInfo -ArgumentList $e,$a; $s.UseShellExecute=$false; $s.CreateNoWindow=$true; $s.RedirectStandardOutput=$true; $s.RedirectStandardError=$true; $p=[System.Diagnostics.Process]::Start($s); if($w){$null=$p.StandardOutput.ReadToEnd(); $null=$p.StandardError.ReadToEnd(); $p.WaitForExit(); return ($p.ExitCode -eq 0)}; return $true}; function Apply($i){$ok=Run 'netsh.exe' ('interface ipv4 set dnsservers name='+$q+$env:ADAPTER+$q+' source=static address='+(GetIp $i)+' register=primary validate=no') $true; if($ok){$null=Run 'ipconfig.exe' '/flushdns' $true; [IO.File]::WriteAllText($env:LASTDNS,(GetIp $i)+[Environment]::NewLine)}; return $ok}; function Stat($n,$i){$v=[Environment]::GetEnvironmentVariable($n+'['+$i+']'); if($v){$v}else{'N/A'}} function Draw{$e='='*60; [Console]::Clear(); [Console]::WriteLine($e); [Console]::WriteLine('                 DNS SERVER SELECTION'); [Console]::WriteLine($e); [Console]::WriteLine('Adapter: '+$env:ADAPTER); [Console]::WriteLine('Current DNS: '+(GetIp $idx)+' (server '+$idx+' of '+$n+')'); [Console]::WriteLine('Provider: '+(Prov $idx)); [Console]::WriteLine('Location: '+(Loc $idx)); [Console]::WriteLine('Latency: CONN '+(Stat 'REFCONN' $idx)+'   DNS '+(Stat 'REFDNS' $idx)+'   PING '+(Stat 'REFAVG' $idx)+'   LOSS '+(Stat 'REFLOSS' $idx)); [Console]::WriteLine('ENTER: next DNS   BACKSPACE: previous DNS   Q: online ping results'); [Console]::WriteLine('')}; if($cache.ContainsKey((GetIp $idx)) -and ([Environment]::GetEnvironmentVariable('REFPROVIDER['+$idx+']') -eq 'Unavailable')){Draw}; while($result -eq 0){ if([Console]::KeyAvailable){$k=[Console]::ReadKey($true); if($k.Key -eq [ConsoleKey]::C -and ($k.Modifiers -band [ConsoleModifiers]::Control)){$result=5} elseif($k.Key -eq [ConsoleKey]::Q){$result=4} elseif($k.Key -eq [ConsoleKey]::Enter -and $n -gt 1){$idx=$idx %% $n + 1; $pend=$true; $last=[DateTime]::UtcNow; Draw} elseif($k.Key -eq [ConsoleKey]::Backspace -and $n -gt 1){$idx=($idx + $n - 2) %% $n + 1; $pend=$true; $last=[DateTime]::UtcNow; Draw} } if($result -eq 0 -and $pend -and (([DateTime]::UtcNow-$last).TotalMilliseconds -gt 150)){$pend=$false; if($idx -ne $applied){$t=$idx; if(Apply $t){$applied=$t}else{$result=8; $fail=$t}}} if($fetch -ne $null){if($fetch.IsCompleted){try{if(-not $fetch.IsFaulted -and -not $fetch.IsCanceled){$j=$fetch.Result | ConvertFrom-Json; if($j.status -eq 'success'){$pv=$j.isp; if(-not $pv){$pv=$j.org}; if(-not $pv){$pv=$j.asname}; $lc=(@($j.city,$j.regionName,$j.country) | Where-Object {$_}) -join ', '; $bad=[string][char]33; $pv=([string]$pv -replace '[^\p{L}\p{N} .,_/+-]',' ').Replace($bad,' ').Trim(); $lc=($lc -replace '[^\p{L}\p{N} .,_/+-]',' ').Replace($bad,' ').Trim(); if($pv -and $lc){$info[$fetchIp]=@{p=$pv;l=$lc}; $cache[$fetchIp]=@{p=$pv;l=$lc}; try{[IO.File]::WriteAllLines($env:DNS_PROV_CACHE,[string[]]@($cache.Keys | ForEach-Object {$_+'|'+$cache[$_].p+'|'+$cache[$_].l}))}catch{}; if((GetIp $idx) -eq $fetchIp){Draw}}}}}catch{}; $fetch=$null; try{$fetchWc.Dispose()}catch{}}elseif(([DateTime]::UtcNow-$fetchStart).TotalSeconds -gt 6){try{$fetchWc.CancelAsync()}catch{}}}elseif($result -eq 0 -and -not $pend -and $idx -eq $applied -and (([DateTime]::UtcNow-$fetchAt).TotalSeconds -gt 5)){$cp=Prov $idx; $cl=Loc $idx; if(-not $cp -or $cp -eq 'Unavailable' -or -not $cl -or $cl -eq 'Unavailable'){$fetchAt=[DateTime]::UtcNow; $fetchStart=$fetchAt; $fetchIp=GetIp $idx; try{$fetchWc=New-Object System.Net.WebClient; $fetch=$fetchWc.DownloadStringTaskAsync('http://ip-api.com/json/'+$fetchIp+'?fields=status,country,regionName,city,isp,org,asname')}catch{$fetch=$null}}} $tick++; if($result -eq 0){Start-Sleep -Milliseconds 25} } if($result -ne 8 -and $idx -ne $applied){if(Apply $idx){$applied=$idx}else{$result=8; $fail=$idx}} if($result -eq 8){[IO.File]::WriteAllText($env:DNS_NAV_FILE,'F|'+$fail)}elseif($applied -ne $orig){[IO.File]::WriteAllText($env:DNS_NAV_FILE,'S|'+$applied)} for($z=1;$z -le $n;$z++){$k=GetIp $z; $ev=[Environment]::GetEnvironmentVariable('REFPROVIDER['+$z+']'); if((-not $ev -or $ev -eq 'Unavailable') -and $cache.ContainsKey($k) -and -not $info.ContainsKey($k)){$info[$k]=$cache[$k]}}; if($info.Count -gt 0){try{[IO.File]::WriteAllLines($env:DNS_INFO_FILE,[string[]]@($info.Keys | ForEach-Object {$_+'|'+$info[$_].p+'|'+$info[$_].l}))}catch{}} [Console]::TreatControlCAsInput=$old; exit $result" 2>"!DNS_LISTENER_ERR!"
set "PSRC=!errorlevel!"
call :SYNCSTEP
call :SYNCINFO
if not "!PSRC!"=="4" if not "!PSRC!"=="5" if not "!PSRC!"=="8" goto LISTENERFAILED
if "!PSRC!"=="8" goto BATCHNAV
if "!PSRC!"=="5" goto END
if "!PSRC!"=="4" goto BACKTORESULTS
goto DNSMONITOR

:LISTENERFAILED
cls
echo The ENTER / BACKSPACE key listener stopped unexpectedly (code !PSRC!).
if exist "!DNS_LISTENER_ERR!" (
    echo.
    echo Details:
    type "!DNS_LISTENER_ERR!"
)
echo.
pause
goto RESULTS

:BATCHNAV
set "KEY_DELTA="
if exist "!DNS_NAV_FILE!" set /p "KEY_DELTA="<"!DNS_NAV_FILE!"
del /q "!DNS_NAV_FILE!" >nul 2>&1
if not defined KEY_DELTA goto DNSMONITOR
if "!KEY_DELTA:~0,2!"=="F|" (
    set "DNSINDEX=!KEY_DELTA:~2!"
    goto STEPAPPLY
)
set /a DNSINDEX=((DNSINDEX-1+KEY_DELTA) %% ONLINE + ONLINE) %% ONLINE + 1
goto STEPAPPLY

:NEXTDNS
set /a DNSINDEX+=1
if !DNSINDEX! GTR !ONLINE! set "DNSINDEX=1"
goto STEPAPPLY

:PREVDNS
set /a DNSINDEX-=1
if !DNSINDEX! LSS 1 set "DNSINDEX=!ONLINE!"
goto STEPAPPLY

:STEPAPPLY
call :GETCURRENTDNS
goto APPLYSELECTED

:BACKTORESULTS
del /q "!DNS_NAV_FILE!" >nul 2>&1
goto RESULTS

:MONITORHEADER
echo ============================================================
echo                  DNS SERVER SELECTION
echo ============================================================
echo Adapter: !ADAPTER!
echo Current DNS: !DNS! (server !DNSINDEX! of !ONLINE!)
for %%N in (!DNSINDEX!) do (
    echo Provider: !REFPROVIDER[%%N]!
    echo Location: !REFLOCATION[%%N]!
    set "SCONN=!REFCONN[%%N]!"
    set "SDNS=!REFDNS[%%N]!"
    set "SPING=!REFAVG[%%N]!"
    set "SLOSS=!REFLOSS[%%N]!"
    if not defined SCONN set "SCONN=N/A"
    if not defined SDNS set "SDNS=N/A"
    if not defined SPING set "SPING=N/A"
    if not defined SLOSS set "SLOSS=N/A"
    echo Latency: CONN !SCONN!   DNS !SDNS!   PING !SPING!   LOSS !SLOSS!
)
echo ENTER: next DNS   BACKSPACE: previous DNS   Q: online ping results
echo.
exit /b

:GETCURRENTDNS
for %%N in (!DNSINDEX!) do set "DNS=!REF[%%N]!"
exit /b

:SYNCINFO
rem Provider/location the key listener fetched in the background (e.g. after starting offline).
if not exist "!DNS_INFO_FILE!" exit /b
for /f "usebackq tokens=1-3 delims=|" %%A in ("!DNS_INFO_FILE!") do (
    for /l %%N in (1,1,!ONLINE!) do if "!REF[%%N]!"=="%%A" (
        set "REFPROVIDER[%%N]=%%B"
        set "REFLOCATION[%%N]=%%C"
    )
)
del /q "!DNS_INFO_FILE!" >nul 2>&1
exit /b

:SYNCSTEP
rem The key listener now applies ENTER/BACKSPACE changes itself (no restart per press).
rem Pick up the server index it ended on so the rest of the script stays in step.
if not exist "!DNS_NAV_FILE!" exit /b
set "SYNCLINE="
set /p "SYNCLINE="<"!DNS_NAV_FILE!"
if not "!SYNCLINE:~0,2!"=="S|" exit /b
del /q "!DNS_NAV_FILE!" >nul 2>&1
set "DNSINDEX=!SYNCLINE:~2!"
call :GETCURRENTDNS
set "CURRENTDNSCOUNT=1"
set "CURRENTDNS[1]=!DNS!"
set "CURRENTDNSPROVIDER[1]=Unavailable"
set "CURRENTDNSLOCATION[1]=Unavailable"
for /l %%K in (1,1,!ONLINE!) do if "!REF[%%K]!"=="!DNS!" (
    set "CURRENTDNSPROVIDER[1]=!REFPROVIDER[%%K]!"
    set "CURRENTDNSLOCATION[1]=!REFLOCATION[%%K]!"
)
exit /b

:EXTRACTPINGSCRIPT
rem Copy the embedded runspace-pool tester (after the :PSRUNSPACEPING marker)
rem into a temporary .ps1 file. Delayed expansion is off so the script text
rem is copied without the batch parser touching it.
setlocal DisableDelayedExpansion
set "PSSKIP="
for /f "delims=:" %%N in ('findstr /n /b /c:":PSRUNSPACEPING" "%~f0"') do set "PSSKIP=%%N"
if not defined PSSKIP (
    endlocal
    exit /b 1
)
>"%PING_SCRIPT%" (
    for /f "usebackq skip=%PSSKIP% delims=" %%L in ("%~f0") do echo(%%L
)
endlocal
if not exist "%PING_SCRIPT%" exit /b 1
for %%F in ("%PING_SCRIPT%") do if %%~zF EQU 0 exit /b 1
exit /b 0

:LOOKUPINFO
if not defined ONLINE set "ONLINE=0"
if not defined CURRENTDNSCOUNT set "CURRENTDNSCOUNT=0"
>"!INFO_INPUT!" (
    for /l %%N in (1,1,!ONLINE!) do echo(!REF[%%N]!^|!REFPROVIDER[%%N]!^|!REFLOCATION[%%N]!
    for /l %%D in (1,1,!CURRENTDNSCOUNT!) do echo(!CURRENTDNS[%%D]!^|!CURRENTDNSPROVIDER[%%D]!^|!CURRENTDNSLOCATION[%%D]!
)
set /a CURRENTDNSCOUNT=0
set "DNS_INFO_INPUT=!INFO_INPUT!"
if exist "!DNS_PROV_CACHE!" powershell.exe -NoProfile -NonInteractive -Command "$c=@{}; foreach($l in Get-Content -LiteralPath $env:DNS_PROV_CACHE -Encoding UTF8){$x=$l -split '\|',3; if($x.Count -eq 3){$c[$x[0].Trim()]=$x}}; $o=foreach($l in Get-Content -LiteralPath $env:INFO_INPUT){$x=$l -split '\|',3; if($x.Count -eq 3 -and $c.ContainsKey($x[0].Trim()) -and (($x[1].Trim() -eq 'Unavailable') -or ($x[2].Trim() -eq 'Unavailable'))){$x[0]+'|'+$c[$x[0].Trim()][1]+'|'+$c[$x[0].Trim()][2]}else{$l}}; Set-Content -LiteralPath $env:INFO_INPUT -Value $o" >nul 2>&1
REM Embedded provider and location lookup (ip-api batch, with ipinfo fallback).
powershell.exe -NoProfile -NonInteractive -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJABpAG4AcAB1AHQASQBwAHMAPQBOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBDAG8AbABsAGUAYwB0AGkAbwBuAHMALgBHAGUAbgBlAHIAaQBjAC4ATABpAHMAdABbAHMAdAByAGkAbgBnAF0ACgAkAGMAYQBjAGgAZQA9AEAAewB9AAoAZgBvAHIAZQBhAGMAaAAoACQAbABpAG4AZQAgAGkAbgAgAEAAKABHAGUAdAAtAEMAbwBuAHQAZQBuAHQAIAAtAEwAaQB0AGUAcgBhAGwAUABhAHQAaAAgACQAZQBuAHYAOgBEAE4AUwBfAEkATgBGAE8AXwBJAE4AUABVAFQAKQApAHsAIAAkAHAAYQByAHQAcwA9ACQAbABpAG4AZQAgAC0AcwBwAGwAaQB0ACAAJwBcAHwAJwAsADMAOwAgAGkAZgAoACQAcABhAHIAdABzAC4AQwBvAHUAbgB0ACAALQBsAHQAIAAzACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACAAJABpAHAAPQAkAHAAYQByAHQAcwBbADAAXQAuAFQAcgBpAG0AKAApADsAIABpAGYAKAAhACQAaQBwACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACAAJABpAG4AcAB1AHQASQBwAHMALgBBAGQAZAAoACQAaQBwACkAOwAgACQAcAByAG8AdgBpAGQAZQByAD0AJABwAGEAcgB0AHMAWwAxAF0ALgBUAHIAaQBtACgAKQA7ACAAJABsAG8AYwBhAHQAaQBvAG4APQAkAHAAYQByAHQAcwBbADIAXQAuAFQAcgBpAG0AKAApADsAIABpAGYAKAAkAHAAcgBvAHYAaQBkAGUAcgAgAC0AZQBxACAAJwBVAG4AYQB2AGEAaQBsAGEAYgBsAGUAJwApAHsAJABwAHIAbwB2AGkAZABlAHIAPQAnACcAfQA7ACAAaQBmACgAJABsAG8AYwBhAHQAaQBvAG4AIAAtAGUAcQAgACcAVQBuAGEAdgBhAGkAbABhAGIAbABlACcAKQB7ACQAbABvAGMAYQB0AGkAbwBuAD0AJwAnAH0AOwAgAGkAZgAoACQAcAByAG8AdgBpAGQAZQByACAALQBvAHIAIAAkAGwAbwBjAGEAdABpAG8AbgApAHsAJABjAGEAYwBoAGUAWwAkAGkAcABdAD0AQAB7AHAAPQAkAHAAcgBvAHYAaQBkAGUAcgA7AGwAPQAkAGwAbwBjAGEAdABpAG8AbgB9AH0AIAB9AAoAJABjAHUAcgByAGUAbgB0AEQAbgBzAD0AQAAoAEcAZQB0AC0ARABuAHMAQwBsAGkAZQBuAHQAUwBlAHIAdgBlAHIAQQBkAGQAcgBlAHMAcwAgAC0ASQBuAHQAZQByAGYAYQBjAGUAQQBsAGkAYQBzACAAJABlAG4AdgA6AEEARABBAFAAVABFAFIAIAAtAEUAcgByAG8AcgBBAGMAdABpAG8AbgAgAFMAaQBsAGUAbgB0AGwAeQBDAG8AbgB0AGkAbgB1AGUAIAB8ACAARgBvAHIARQBhAGMAaAAtAE8AYgBqAGUAYwB0ACAAewAkAF8ALgBTAGUAcgB2AGUAcgBBAGQAZAByAGUAcwBzAGUAcwB9ACAAfAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAkAF8AfQAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBVAG4AaQBxAHUAZQApAAoAJABpAHAAcwA9AEAAKAAkAGkAbgBwAHUAdABJAHAAcwArACQAYwB1AHIAcgBlAG4AdABEAG4AcwAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBVAG4AaQBxAHUAZQApAAoAJAB0AG8AZABvAD0AQAAoACQAaQBwAHMAIAB8ACAAVwBoAGUAcgBlAC0ATwBiAGoAZQBjAHQAIAB7ACEAJABjAGEAYwBoAGUALgBDAG8AbgB0AGEAaQBuAHMASwBlAHkAKAAkAF8AKQAgAC0AbwByACAAIQAkAGMAYQBjAGgAZQBbACQAXwBdAC4AcAAgAC0AbwByACAAIQAkAGMAYQBjAGgAZQBbACQAXwBdAC4AbAB9ACkACgBmAG8AcgAoACQAcwB0AGEAcgB0AD0AMAA7ACQAcwB0AGEAcgB0ACAALQBsAHQAIAAkAHQAbwBkAG8ALgBDAG8AdQBuAHQAOwAkAHMAdABhAHIAdAArAD0AMQAwADAAKQB7ACAAJABsAGEAcwB0AD0AWwBNAGEAdABoAF0AOgA6AE0AaQBuACgAJABzAHQAYQByAHQAKwA5ADkALAAkAHQAbwBkAG8ALgBDAG8AdQBuAHQALQAxACkAOwAgACQAYwBoAHUAbgBrAD0AQAAoACQAdABvAGQAbwBbACQAcwB0AGEAcgB0AC4ALgAkAGwAYQBzAHQAXQApADsAIAB0AHIAeQAgAHsAIAAkAGEAbgBzAD0ASQBuAHYAbwBrAGUALQBSAGUAcwB0AE0AZQB0AGgAbwBkACAALQBVAHIAaQAgACcAaAB0AHQAcAA6AC8ALwBpAHAALQBhAHAAaQAuAGMAbwBtAC8AYgBhAHQAYwBoAD8AZgBpAGUAbABkAHMAPQBzAHQAYQB0AHUAcwAsAGMAbwB1AG4AdAByAHkALAByAGUAZwBpAG8AbgBOAGEAbQBlACwAYwBpAHQAeQAsAGkAcwBwACwAbwByAGcALABhAHMAbgBhAG0AZQAsAHEAdQBlAHIAeQAnACAALQBNAGUAdABoAG8AZAAgAFAAbwBzAHQAIAAtAEIAbwBkAHkAIAAoAEMAbwBuAHYAZQByAHQAVABvAC0ASgBzAG8AbgAgAC0ASQBuAHAAdQB0AE8AYgBqAGUAYwB0ACAAJABjAGgAdQBuAGsAIAAtAEMAbwBtAHAAcgBlAHMAcwApACAALQBDAG8AbgB0AGUAbgB0AFQAeQBwAGUAIAAnAGEAcABwAGwAaQBjAGEAdABpAG8AbgAvAGoAcwBvAG4AJwAgAC0AVABpAG0AZQBvAHUAdABTAGUAYwAgADIAMAA7ACAAZgBvAHIAZQBhAGMAaAAoACQAeAAgAGkAbgAgAEAAKAAkAGEAbgBzACkAKQB7ACAAaQBmACgAJAB4AC4AcwB0AGEAdAB1AHMAIAAtAG4AZQAgACcAcwB1AGMAYwBlAHMAcwAnACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACAAJABpAHAAPQBbAHMAdAByAGkAbgBnAF0AJAB4AC4AcQB1AGUAcgB5ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAC4AQwBvAG4AdABhAGkAbgBzAEsAZQB5ACgAJABpAHAAKQApAHsAJABjAGEAYwBoAGUAWwAkAGkAcABdAD0AQAB7AHAAPQAnACcAOwBsAD0AJwAnAH0AfQA7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBwACkAewAkAHAAcgBvAHYAaQBkAGUAcgA9ACQAeAAuAGkAcwBwADsAIABpAGYAKAAhACQAcAByAG8AdgBpAGQAZQByACkAewAkAHAAcgBvAHYAaQBkAGUAcgA9ACQAeAAuAG8AcgBnAH0AOwAgAGkAZgAoACEAJABwAHIAbwB2AGkAZABlAHIAKQB7ACQAcAByAG8AdgBpAGQAZQByAD0AJAB4AC4AYQBzAG4AYQBtAGUAfQA7ACAAJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AcAA9AFsAcwB0AHIAaQBuAGcAXQAkAHAAcgBvAHYAaQBkAGUAcgB9ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAPQAoAEAAKAAkAHgALgBjAGkAdAB5ACwAJAB4AC4AcgBlAGcAaQBvAG4ATgBhAG0AZQAsACQAeAAuAGMAbwB1AG4AdAByAHkAKQB8AFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAkAF8AfQApACAALQBqAG8AaQBuACAAJwAsACAAJwB9ACAAfQAgAH0AIABjAGEAdABjAGgAIAB7AH0AIAB9AAoAZgBvAHIAZQBhAGMAaAAoACQAaQBwACAAaQBuACAAJAB0AG8AZABvACkAewAgAGkAZgAoACEAJABjAGEAYwBoAGUALgBDAG8AbgB0AGEAaQBuAHMASwBlAHkAKAAkAGkAcAApACkAewAkAGMAYQBjAGgAZQBbACQAaQBwAF0APQBAAHsAcAA9ACcAJwA7AGwAPQAnACcAfQB9ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAHAAIAAtAG8AcgAgACEAJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AbAApAHsAIAB0AHIAeQAgAHsAIAAkAHgAPQBJAG4AdgBvAGsAZQAtAFIAZQBzAHQATQBlAHQAaABvAGQAIAAtAFUAcgBpACAAKAAnAGgAdAB0AHAAcwA6AC8ALwBpAHAAaQBuAGYAbwAuAGkAbwAvACcAKwBbAHUAcgBpAF0AOgA6AEUAcwBjAGEAcABlAEQAYQB0AGEAUwB0AHIAaQBuAGcAKAAkAGkAcAApACsAJwAvAGoAcwBvAG4AJwApACAALQBUAGkAbQBlAG8AdQB0AFMAZQBjACAAMgAwADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAHAAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAHAAPQBbAHMAdAByAGkAbgBnAF0AJAB4AC4AbwByAGcAfQA7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBsACkAewAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBsAD0AKABAACgAJAB4AC4AYwBpAHQAeQAsACQAeAAuAHIAZQBnAGkAbwBuACwAJAB4AC4AYwBvAHUAbgB0AHIAeQApAHwAVwBoAGUAcgBlAC0ATwBiAGoAZQBjAHQAIAB7ACQAXwB9ACkAIAAtAGoAbwBpAG4AIAAnACwAIAAnAH0AIAB9ACAAYwBhAHQAYwBoACAAewB9ACAAfQA7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBwACkAewAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBwAD0AJwBVAG4AYQB2AGEAaQBsAGEAYgBsAGUAJwB9ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAPQAnAFUAbgBhAHYAYQBpAGwAYQBiAGwAZQAnAH0AIAB9AAoAZgB1AG4AYwB0AGkAbwBuACAAVwByAGkAdABlAC0ASQBuAGYAbwBMAGkAbgBlACgAJABrAGkAbgBkACwAJABpAHAAKQB7ACAAJABwAD0AKABbAHMAdAByAGkAbgBnAF0AJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AcAAgAC0AcgBlAHAAbABhAGMAZQAgACcAXABzACoAXAAoAEEAUwBcAGQAKwBcACkAJwAsACcAJwAgAC0AcgBlAHAAbABhAGMAZQAgACcAWwBeAFwAcAB7AEwAfQBcAHAAewBOAH0AIAAuACwAXwAvACsALQBdACcALAAnACAAJwAgAC0AcgBlAHAAbABhAGMAZQAgACcAXABzACsAJwAsACcAIAAnACkALgBUAHIAaQBtACgAKQA7ACAAJABsAD0AKABbAHMAdAByAGkAbgBnAF0AJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AbAAgAC0AcgBlAHAAbABhAGMAZQAgACcAWwBeAFwAcAB7AEwAfQBcAHAAewBOAH0AIAAuACwAXwAvACsALQBdACcALAAnACAAJwAgAC0AcgBlAHAAbABhAGMAZQAgACcAXABzACsAJwAsACcAIAAnACkALgBUAHIAaQBtACgAKQA7ACAAaQBmACgAIQAkAHAAKQB7ACQAcAA9ACcAVQBuAGEAdgBhAGkAbABhAGIAbABlACcAfQA7ACAAaQBmACgAIQAkAGwAKQB7ACQAbAA9ACcAVQBuAGEAdgBhAGkAbABhAGIAbABlACcAfQA7ACAAJABrAGkAbgBkACsAJwB8ACcAKwAkAGkAcAArACcAfAAnACsAJABwACsAJwB8ACcAKwAkAGwAIAB9AAoAZgBvAHIAZQBhAGMAaAAoACQAaQBwACAAaQBuACAAJABpAG4AcAB1AHQASQBwAHMAKQB7ACAAVwByAGkAdABlAC0ASQBuAGYAbwBMAGkAbgBlACAAJwBJACcAIAAkAGkAcAAgAH0ACgBmAG8AcgBlAGEAYwBoACgAJABpAHAAIABpAG4AIAAkAGMAdQByAHIAZQBuAHQARABuAHMAKQB7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQAuAEMAbwBuAHQAYQBpAG4AcwBLAGUAeQAoACQAaQBwACkAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQA9AEAAewBwAD0AJwBVAG4AYQB2AGEAaQBsAGEAYgBsAGUAJwA7AGwAPQAnAFUAbgBhAHYAYQBpAGwAYQBiAGwAZQAnAH0AfQA7ACAAVwByAGkAdABlAC0ASQBuAGYAbwBMAGkAbgBlACAAJwBDACcAIAAkAGkAcAAgAH0A > "!INFO_OUTPUT!" 2>nul
if exist "!INFO_OUTPUT!" (
    for /f "usebackq tokens=1-4 delims=|" %%A in ("!INFO_OUTPUT!") do (
        if "%%A"=="I" for /l %%N in (1,1,!ONLINE!) do if "!REF[%%N]!"=="%%B" (
            set "REFPROVIDER[%%N]=%%C"
            set "REFLOCATION[%%N]=%%D"
        )
        if "%%A"=="C" (
            set /a CURRENTDNSCOUNT+=1
            set "CURRENTDNS[!CURRENTDNSCOUNT!]=%%B"
            set "CURRENTDNSPROVIDER[!CURRENTDNSCOUNT!]=%%C"
            set "CURRENTDNSLOCATION[!CURRENTDNSCOUNT!]=%%D"
        )
    )
)
if exist "!INFO_OUTPUT!" powershell.exe -NoProfile -NonInteractive -Command "$c=@{}; if(Test-Path -LiteralPath $env:DNS_PROV_CACHE){foreach($l in Get-Content -LiteralPath $env:DNS_PROV_CACHE -Encoding UTF8){$x=$l -split '\|',3; if($x.Count -eq 3){$c[$x[0].Trim()]=$l}}}; foreach($l in Get-Content -LiteralPath $env:INFO_OUTPUT){$x=$l -split '\|',4; if($x.Count -eq 4 -and $x[2].Trim() -and $x[2].Trim() -ne 'Unavailable' -and $x[3].Trim() -and $x[3].Trim() -ne 'Unavailable'){$c[$x[1].Trim()]=$x[1].Trim()+'|'+$x[2].Trim()+'|'+$x[3].Trim()}}; [IO.File]::WriteAllLines($env:DNS_PROV_CACHE,[string[]]@($c.Values))" >nul 2>&1
del "!INFO_INPUT!" "!INFO_OUTPUT!" >nul 2>&1
exit /b

:DHCPDNS
echo.
echo Restoring DNS to automatic DHCP for "!ADAPTER!"...
netsh interface ipv4 set dnsservers name="!ADAPTER!" source=dhcp
if errorlevel 1 (
    echo Failed to restore DNS. Check adapter name and Administrator permission.
) else (
    echo DNS is now configured for automatic DHCP.
    ipconfig /flushdns
)
pause
goto START

:PRINTCURRENTROWS
rem Rows for the DNS servers currently set. CONN/DNS/PING come from the last list test (N/A if that DNS was not in it).
if not defined ONLINE set "ONLINE=0"
if not defined CURRENTDNSCOUNT set "CURRENTDNSCOUNT=0"
if !CURRENTDNSCOUNT! EQU 0 echo No DNS servers detected.
for /l %%D in (1,1,!CURRENTDNSCOUNT!) do (
    set "SCONN=N/A"
    set "SDNS=N/A"
    set "SPING=N/A"
    for /l %%K in (1,1,!ONLINE!) do if "!REF[%%K]!"=="!CURRENTDNS[%%D]!" (
        if defined REFCONN[%%K] set "SCONN=!REFCONN[%%K]!"
        if defined REFDNS[%%K] set "SDNS=!REFDNS[%%K]!"
        if defined REFAVG[%%K] set "SPING=!REFAVG[%%K]!"
    )
    set "PAD=!CURRENTDNS[%%D]!                "
    set "CIP=!PAD:~0,16!"
    set "PAD=        !SCONN!"
    set "CCONN=!PAD:~-8!"
    set "PAD=        !SDNS!"
    set "CDNS=!PAD:~-8!"
    set "PAD=        !SPING!"
    set "CPING=!PAD:~-8!"
    set "CPROV=!CURRENTDNSPROVIDER[%%D]!                        "
    set "CPROV=!CPROV:~0,24!"
    echo(!CIP! !CCONN! !CDNS! !CPING!  !CPROV! !CURRENTDNSLOCATION[%%D]!
)
exit /b

:SHOWDNS
echo.
echo DNS servers configured on "!ADAPTER!":
call :LOOKUPINFO
echo DNS IP            CONN ms   DNS ms  PING ms  PROVIDER                 LOCATION
echo ----------------------------------------------------------------------------------------------------
call :PRINTCURRENTROWS
echo.
echo All Windows network adapter DNS entries:
ipconfig /all | findstr /i /c:"DNS Servers" /c:"DNS Server"
echo.
pause
goto START

:END
del "!PING_INPUT!" >nul 2>&1
del "!PING_OUTPUT!" >nul 2>&1
del "!PING_SCRIPT!" >nul 2>&1
del "!VOTETEMP!" >nul 2>&1
del "!DNS_LISTENER_ERR!" "!INFO_INPUT!" "!INFO_OUTPUT!" "!DNS_INFO_FILE!" "!DNS_NAV_FILE!" >nul 2>&1
endlocal
exit /b

:PSRUNSPACEPING
# Parallel DNS tester for auto_combined_dns_manager_failover.bat
# Per server: ping, one raw UDP DNS lookup (DNS ms) and a TCP connect (CONN ms).
# A bounded runspace pool does the work and only a small window of jobs exists at once.
$ErrorActionPreference = 'Stop'

function Get-IntSetting {
    param(
        [string]$Name,
        [int]$Default,
        [int]$Minimum,
        [int]$Maximum
    )
    $parsed = 0
    $raw = [string][Environment]::GetEnvironmentVariable($Name)
    if ([int]::TryParse($raw, [ref]$parsed)) {
        if ($parsed -lt $Minimum) { $parsed = $Minimum }
        if ($parsed -gt $Maximum) { $parsed = $Maximum }
        return $parsed
    }
    return $Default
}

$inputPath  = [string][Environment]::GetEnvironmentVariable('DNS_PING_INPUT')
$outputPath = [string][Environment]::GetEnvironmentVariable('DNS_PING_OUTPUT')
$pingCount  = Get-IntSetting 'DNS_PING_COUNT' 4 1 10
$timeoutMs  = Get-IntSetting 'DNS_PING_TIMEOUT_MS' 1800 200 10000
$probeMs    = Get-IntSetting 'DNS_PING_PROBE_TIMEOUT_MS' 1200 200 10000
$endpoint   = [string][Environment]::GetEnvironmentVariable('DNS_TEST_ENDPOINT')
if ($endpoint -notmatch '^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$') { $endpoint = 'glz-ap-1.ap.a.pvp.net' }
$tcpPort    = Get-IntSetting 'DNS_TEST_TCP_PORT' 443 0 65535
$tcpMs      = Get-IntSetting 'DNS_TEST_TCP_TIMEOUT_MS' 1500 200 10000
$dnsLimitMs = Get-IntSetting 'DNS_TEST_DNS_TIMEOUT_MS' 1200 200 10000
$maxThreads = Get-IntSetting 'DNS_PING_THREADS' 64 1 512

if ([string]::IsNullOrWhiteSpace($inputPath)) { exit 2 }
if ([string]::IsNullOrWhiteSpace($outputPath)) { exit 2 }
if (-not (Test-Path -LiteralPath $inputPath)) { exit 3 }

# Only real, public-looking IPv4 addresses are tested (no 0.x, 127.x, 169.254.x or 224+).
$ips = New-Object System.Collections.Generic.List[string]
$seen = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in [System.IO.File]::ReadAllLines($inputPath)) {
    $text = $line.Trim()
    $addr = $null
    if ($text -match '^\d{1,3}(\.\d{1,3}){3}$' -and [System.Net.IPAddress]::TryParse($text, [ref]$addr)) {
        $b = $addr.GetAddressBytes()
        if ($b.Length -eq 4 -and $b[0] -ne 0 -and $b[0] -ne 127 -and $b[0] -lt 224 -and -not ($b[0] -eq 169 -and $b[1] -eq 254)) {
            if ($seen.Add($addr.ToString())) { $ips.Add($addr.ToString()) }
        }
    }
}
if ($ips.Count -eq 0) { exit 4 }
if ($maxThreads -gt $ips.Count) { $maxThreads = $ips.Count }

# One job per DNS server. The first ping is a quick probe; the other pings are only sent when
# the server answers. DNS and CONN are tested whether or not the server answers ping.
$worker = {
    param(
        [string]$Ip,
        [int]$Count,
        [int]$TimeoutMs,
        [int]$ProbeMs,
        [string]$Endpoint,
        [int]$TcpPort,
        [int]$TcpMs,
        [int]$DnsLimitMs
    )

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

    $sent = 0
    $received = 0
    $min = [double]::MaxValue
    $max = [double]::MinValue
    $total = 0.0

    for ($i = 0; $i -lt $Count; $i++) {
        $limit = $TimeoutMs
        if ($i -eq 0) { $limit = $ProbeMs }

        $reply = $null
        $pinger = New-Object System.Net.NetworkInformation.Ping
        try {
            $reply = $pinger.Send($Ip, $limit)
        } catch {
            $reply = $null
        } finally {
            $pinger.Dispose()
        }

        $sent++
        if ($null -ne $reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            $rtt = [double]$reply.RoundtripTime
            $received++
            $total += $rtt
            if ($rtt -lt $min) { $min = $rtt }
            if ($rtt -gt $max) { $max = $rtt }
        } elseif ($i -eq 0) {
            break
        }
    }

    # DNS ms: best of 2 lookups (the first one can be a cold, recursive lookup). A failed first
    # lookup ends the test for this server. CONN ms: TCP connect to the address it returned.
    $dnsOut = 'N/A'
    $connOut = 'N/A'
    $addrOut = $null
    $best = $null
    for ($k = 0; $k -lt 2; $k++) {
        $res = Query-A $Ip $Endpoint $DnsLimitMs
        if ($null -eq $res) { break }
        $addrOut = $res.Addr
        if ($null -eq $best -or $res.Ms -lt $best) { $best = $res.Ms }
    }
    if ($null -ne $best) { $dnsOut = [int][math]::Round($best) }
    if ($null -ne $addrOut -and $TcpPort -gt 0) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $iar = $client.BeginConnect($addrOut, $TcpPort, $null, $null)
            if ($iar.AsyncWaitHandle.WaitOne($TcpMs) -and $client.Connected) {
                $client.EndConnect($iar)
                $watch.Stop()
                $connOut = [int][math]::Round($watch.Elapsed.TotalMilliseconds)
            }
        } catch { } finally { $client.Close() }
    }

    $lossPercent = 100
    if ($sent -gt 0) { $lossPercent = [int][math]::Round((($sent - $received) * 100.0) / $sent) }
    $minOut = 'N/A'
    $maxOut = 'N/A'
    $avgOut = 'N/A'
    if ($received -gt 0) {
        $minOut = [int][math]::Round($min)
        $maxOut = [int][math]::Round($max)
        $avgOut = [int][math]::Round($total / $received)
    }
    return [pscustomobject]@{
        IP       = $Ip
        Sent     = $sent
        Received = $received
        Min      = $minOut
        Max      = $maxOut
        Avg      = $avgOut
        Loss     = ('{0}%' -f $lossPercent)
        Dns      = $dnsOut
        Conn     = $connOut
    }
}

$workerScript = $worker.ToString()

$pool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
$pool.Open()

$writer = [System.IO.StreamWriter]::new($outputPath, $false, [System.Text.Encoding]::ASCII)
try {
    # Sliding window: jobs are queued ahead (twice the thread count) so the pool never waits for
    # a slow server, but only a few pipelines are alive at the same time. Results are written in input order.
    $total = $ips.Count
    $window = $maxThreads * 2
    $jobs = New-Object 'object[]' $total
    $submitted = 0
    for ($done = 0; $done -lt $total; $done++) {
        while ($submitted -lt $total -and ($submitted - $done) -lt $window) {
            $ip = $ips[$submitted]
            $shell = [powershell]::Create()
            $shell.RunspacePool = $pool
            [void]$shell.AddScript($workerScript)
            [void]$shell.AddArgument($ip)
            [void]$shell.AddArgument($pingCount)
            [void]$shell.AddArgument($timeoutMs)
            [void]$shell.AddArgument($probeMs)
            [void]$shell.AddArgument($endpoint)
            [void]$shell.AddArgument($tcpPort)
            [void]$shell.AddArgument($tcpMs)
            [void]$shell.AddArgument($dnsLimitMs)
            $jobs[$submitted] = [pscustomobject]@{
                IP     = $ip
                Shell  = $shell
                Handle = $shell.BeginInvoke()
            }
            $submitted++
        }

        $job = $jobs[$done]
        $jobs[$done] = $null
        $result = $null
        try {
            $output = @($job.Shell.EndInvoke($job.Handle))
            if ($output.Count -gt 0) {
                $result = $output[$output.Count - 1]
            }
        } catch {
            $result = $null
        }
        if ($null -eq $result) {
            $result = [pscustomobject]@{
                IP       = $job.IP
                Sent     = 0
                Received = 0
                Min      = 'N/A'
                Max      = 'N/A'
                Avg      = 'N/A'
                Loss     = '100%'
                Dns      = 'N/A'
                Conn     = 'N/A'
            }
        }
        $writer.WriteLine(('{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}' -f $result.IP, $result.Received, $result.Min, $result.Max, $result.Avg, $result.Loss, $result.Sent, $result.Dns, $result.Conn))
        $job.Shell.Dispose()
        if ((($done + 1) % 10) -eq 0 -or ($done + 1) -eq $total) {
            Write-Host -NoNewline ("`r  Tested {0} of {1}" -f ($done + 1), $total)
        }
    }
    $writer.Flush()
    Write-Host ''
} finally {
    $writer.Dispose()
    $pool.Close()
    $pool.Dispose()
}
exit 0
