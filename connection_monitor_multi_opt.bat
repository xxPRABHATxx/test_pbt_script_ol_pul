@echo off
setlocal EnableExtensions
title Connection Monitor - DNS testing every 3 seconds

rem What the PC says out loud when the connection is lost. Change it to anything you like.
set "MESSAGE=No connection"
if /i "%~1"=="test" goto :test

rem Choose the hostname checked through the DNS server currently in use.
:choose_endpoint
cls
echo [92m                coded by[0m
echo [31m  _____           _     _           _[0m
echo [31m ^|  __ \         ^| ^|   ^| ^|         ^| ^|[0m
echo [31m ^| ^|__) ^| __ __ _^| ^|__ ^| ^|__   __ _^| ^|_ [0m
echo [31m ^|  ___/ '__/ _` ^| '_ \^| '_ \ / _` ^| __^|[0m
echo [31m ^| ^|   ^| ^| ^| (_^| ^| ^|_) ^| ^| ^| ^| (_^| ^| ^|_ [0m
echo [31m ^|_^|   ^|_^|  \__,_^|_.__/^|_^| ^|_^|\__,_^|\__^|[0m
echo [31m========================================[0m
echo [92m        Created: 15 october 2022[0m
echo ============================================================
echo       SELECT CONNECTION VERIFICATION ENDPOINT
echo ============================================================
echo 1. Google (google.com) - default
echo 2. VALORANT (playvalorant.com)
echo 3. VALORANT AP shared service (shared.ap.a.pvp.net)
echo 4. VALORANT AP player data (pd.ap.a.pvp.net)
echo 5. VALORANT AP game lobby (glz-ap-1.ap.a.pvp.net)
echo 0. Quit
echo.
set "ENDPOINT_CHOICE="
set /p "ENDPOINT_CHOICE=Choose endpoint (ENTER = Google): "
if not defined ENDPOINT_CHOICE set "ENDPOINT_CHOICE=1"
if "%ENDPOINT_CHOICE%"=="0" exit /b
if "%ENDPOINT_CHOICE%"=="1" set "VERIFY_HOST=google.com"
if "%ENDPOINT_CHOICE%"=="2" set "VERIFY_HOST=playvalorant.com"
if "%ENDPOINT_CHOICE%"=="3" set "VERIFY_HOST=shared.ap.a.pvp.net"
if "%ENDPOINT_CHOICE%"=="4" set "VERIFY_HOST=pd.ap.a.pvp.net"
if "%ENDPOINT_CHOICE%"=="5" set "VERIFY_HOST=glz-ap-1.ap.a.pvp.net"
if not defined VERIFY_HOST (
    echo Invalid choice. Select 1 through 5.
    timeout /t 2 /nobreak >nul
    goto choose_endpoint
)


echo ============================================================
echo  Connection monitor - checks every 3 seconds
echo  Re-detects the DNS server your PC is using on every check,
echo  verifies %VERIFY_HOST% through the active DNS server.
echo  Press 0 anytime to return to endpoint selection.  Ctrl+C to exit.
echo ============================================================
echo.

set "DNS="
set "KNOWN="
set "LOG1="
set "LOG2="
set "LOG3="
set "LOG4="
set "LOG5="

:loop
rem Detect the DNS server in use right now, so network or DNS changes are picked up
call :getdns
set "now=%time: =0%"

if not defined DNS (
    set "ENTRY=[%now:~0,8%] NO CONNECTION - no active network or DNS server found"
    call :log "%ENTRY%"
    call :beep
    goto :wait
)

rem Report a DNS change; the new server is used for this check
if defined KNOWN if not "%KNOWN%"=="%DNS%" (set "ENTRY=[%now:~0,8%] DNS server changed: %KNOWN% to %DNS%" & call :log "%ENTRY%")
set "KNOWN=%DNS%"

rem Verify DNS in the background so key 0 remains available during the lookup.
call :checkdns
if "%DNS_RESULT%"=="FAIL" (
    set "ENTRY=[%now:~0,8%] DNS FAILURE - %DNS% could not resolve %VERIFY_HOST%"
    call :log "%ENTRY%"
    call :beep
) else (
    set "ENTRY=[%now:~0,8%] OK - %DNS% resolved %VERIFY_HOST% successfully"
    call :log "%ENTRY%"
)

:wait
set "WAIT_TICKS=0"
:wait_tick
choice /c 0X /n /t 1 /d X >nul
if errorlevel 2 goto wait_tick_continue
goto choose_endpoint
:wait_tick_continue
set /a WAIT_TICKS+=1
if %WAIT_TICKS% LSS 3 goto wait_tick
goto :loop


:checkdns
set "DNS_RESULT="
set "DNS_RESULT_FILE=%TEMP%\connection_monitor_dns_%RANDOM%.tmp"
start "" /b powershell -NoProfile -Command "try { Resolve-DnsName -Name $env:VERIFY_HOST -Server $env:DNS -DnsOnly -Quick -ErrorAction Stop | Out-Null; [IO.File]::WriteAllText($env:DNS_RESULT_FILE, 'OK') } catch { [IO.File]::WriteAllText($env:DNS_RESULT_FILE, 'FAIL') }"
:checkdns_poll
if exist "%DNS_RESULT_FILE%" (
    set /p "DNS_RESULT="<"%DNS_RESULT_FILE%"
    del "%DNS_RESULT_FILE%" >nul 2>&1
    exit /b
)
choice /c 0X /n /t 1 /d X >nul
if errorlevel 2 goto checkdns_poll
goto choose_endpoint
:log
rem Keep and display only the five most recent log records.
set "LOG5=%LOG4%"
set "LOG4=%LOG3%"
set "LOG3=%LOG2%"
set "LOG2=%LOG1%"
set "LOG1=%~1"
cls
echo [92m                coded by[0m
echo [31m  _____           _     _           _[0m
echo [31m ^|  __ \         ^| ^|   ^| ^|         ^| ^|[0m
echo [31m ^| ^|__) ^| __ __ _^| ^|__ ^| ^|__   __ _^| ^|_ [0m
echo [31m ^|  ___/ '__/ _` ^| '_ \^| '_ \ / _` ^| __^|[0m
echo [31m ^| ^|   ^| ^| ^| (_^| ^| ^|_) ^| ^| ^| ^| (_^| ^| ^|_ [0m
echo [31m ^|_^|   ^|_^|  \__,_^|_.__/^|_^| ^|_^|\__,_^|\__^|[0m
echo [31m========================================[0m
echo [92m        Created: 15 october 2022[0m
echo ============================================================
echo  Connection monitor - DNS testing every 3 seconds
echo  Re-detects the DNS server your PC is using on every check,
echo  verifies %VERIFY_HOST% through the active DNS server.
echo  Press 0 anytime to return to endpoint selection.  Ctrl+C to exit.
echo ============================================================
echo.
if defined LOG5 echo %LOG5%
if defined LOG4 echo %LOG4%
if defined LOG3 echo %LOG3%
if defined LOG2 echo %LOG2%
if defined LOG1 echo %LOG1%
exit /b

:getdns
rem Uses the DNS server of the adapter that holds the default route, the one in use
set "DNS=%TARGET%"
if defined DNS exit /b
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1; if ($r) { (Get-DnsClientServerAddress -InterfaceIndex $r.InterfaceIndex -AddressFamily IPv4).ServerAddresses | Select-Object -First 1 }" 2^>nul`) do set "DNS=%%i"
exit /b


:beep
rem Speaks the message out loud; this works even when beeps and system sounds are silent
powershell -NoProfile -Command "Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak($env:MESSAGE)"
exit /b


:test
echo Speaking: %MESSAGE%
call :beep
exit /b
