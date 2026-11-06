@echo off
if /i "%~1"=="--connection-monitor" goto :CM_ENTRY
setlocal EnableExtensions EnableDelayedExpansion
title DNS Scraper, Ping Tester and Automatic DNS Failover Manager
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
set "CONNECTION_MONITOR_PIDFILE=%TEMP%\dns_connection_monitor_%RANDOM%_%RANDOM%.pid"
set "DNS_MONITOR_STATUS_FILE=%TEMP%\dns_connection_status_%RANDOM%_%RANDOM%.txt"
set "DNS_NAV_FILE=%TEMP%\dns_navigation_%RANDOM%_%RANDOM%.txt"
set "MONITOR_VISIBLE=0"
set "PING_SCRIPT=%TEMP%\dns_ping_parallel_%RANDOM%_%RANDOM%.ps1"
set "PING_THREADS=128"
set "PING_COUNT=4"
set "PING_TIMEOUT_MS=800"
set "PING_PROBE_TIMEOUT_MS=1200"
set "URL="

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo PowerShell is required but was not found.
    pause
    exit /b 1
)

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
echo Example: https://publicdns.info/country/in.html
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
powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQAgAD0AIAAnAFMAdABvAHAAJwAKAHQAcgB5ACAAewAKACAAIAAgACAAJAB1ACAAPQAgACQAZQBuAHYAOgBEAE4AUwBfAFMAQwBSAEEAUABFAF8AVQBSAEwACgAgACAAIAAgACQAZABlAHMAdAAgAD0AIAAkAGUAbgB2ADoARABOAFMAXwBTAEMAUgBBAFAARQBfAE8AVQBUAAoAIAAgACAAIAAkAHIAIAA9ACAASQBuAHYAbwBrAGUALQBXAGUAYgBSAGUAcQB1AGUAcwB0ACAALQBVAHIAaQAgACQAdQAgAC0AVABpAG0AZQBvAHUAdABTAGUAYwAgADMAMAAgAC0AVQBzAGUAQgBhAHMAaQBjAFAAYQByAHMAaQBuAGcACgAgACAAIAAgACQAbQBhAHQAYwBoAGUAcwAgAD0AIABbAHIAZQBnAGUAeABdADoAOgBNAGEAdABjAGgAZQBzACgAWwBzAHQAcgBpAG4AZwBdACQAcgAuAEMAbwBuAHQAZQBuAHQALAAgACcAKAA/ADwAIQBbADAALQA5AC4AXQApACgAPwA6AFsAMAAtADkAXQB7ADEALAAzAH0AXAAuACkAewAzAH0AWwAwAC0AOQBdAHsAMQAsADMAfQAoAD8AIQBbADAALQA5AC4AXQApACcAKQAKACAAIAAgACAAJABpAHAAcwAgAD0AIABAACgACgAgACAAIAAgACAAIAAgACAAZgBvAHIAZQBhAGMAaAAgACgAJABtACAAaQBuACAAJABtAGEAdABjAGgAZQBzACkAIAB7AAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAJABpAHAAIAA9ACAAJABtAC4AVgBhAGwAdQBlAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAJABvAGMAdABlAHQAcwAgAD0AIAAkAGkAcAAuAFMAcABsAGkAdAAoACcALgAnACkACgAgACAAIAAgACAAIAAgACAAIAAgACAAIABpAGYAIAAoACgAJABvAGMAdABlAHQAcwAgAHwAIABXAGgAZQByAGUALQBPAGIAagBlAGMAdAAgAHsAIAAkAF8AIAAtAG4AbwB0AG0AYQB0AGMAaAAgACcAXgBcAGQAewAxACwAMwB9ACQAJwAgAC0AbwByACAAWwBpAG4AdABdACQAXwAgAC0AZwB0ACAAMgA1ADUAIAB9ACkALgBDAG8AdQBuAHQAIAAtAGUAcQAgADAAKQAgAHsAIAAkAGkAcAAgAH0ACgAgACAAIAAgACAAIAAgACAAfQAKACAAIAAgACAAKQAKACAAIAAgACAAJABpAHAAcwAgAD0AIABAACgAJABpAHAAcwAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBVAG4AaQBxAHUAZQApAAoAIAAgACAAIABpAGYAIAAoACQAaQBwAHMALgBDAG8AdQBuAHQAIAAtAGUAcQAgADAAKQAgAHsAIAB0AGgAcgBvAHcAIAAnAE4AbwAgAHYAYQBsAGkAZAAgAEkAUAB2ADQAIABhAGQAZAByAGUAcwBzAGUAcwAgAGYAbwB1AG4AZAAgAG8AbgAgAHQAaABlACAAcABhAGcAZQAuACcAIAB9AAoAIAAgACAAIABbAFMAeQBzAHQAZQBtAC4ASQBPAC4ARgBpAGwAZQBdADoAOgBXAHIAaQB0AGUAQQBsAGwATABpAG4AZQBzACgAJABkAGUAcwB0ACwAIABbAHMAdAByAGkAbgBnAFsAXQBdACQAaQBwAHMALAAgAFsAUwB5AHMAdABlAG0ALgBUAGUAeAB0AC4ARQBuAGMAbwBkAGkAbgBnAF0AOgA6AEEAUwBDAEkASQApAAoAIAAgACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAKAAiAFMAYwByAGEAcABlACAAcwB1AGMAYwBlAHMAcwBmAHUAbAA6ACAAewAwAH0AIAB1AG4AaQBxAHUAZQAgAEkAUAB2ADQAIABhAGQAZAByAGUAcwBzACgAZQBzACkAIABzAGEAdgBlAGQALgAiACAALQBmACAAJABpAHAAcwAuAEMAbwB1AG4AdAApAAoAIAAgACAAIAAkAGkAcABzACAAfAAgAFMAZQBsAGUAYwB0AC0ATwBiAGoAZQBjAHQAIAAtAEYAaQByAHMAdAAgADQAMAAgAHwAIABGAG8AcgBFAGEAYwBoAC0ATwBiAGoAZQBjAHQAIAB7ACAAVwByAGkAdABlAC0ASABvAHMAdAAgACgAIgAgACAAewAwAH0AIgAgAC0AZgAgACQAXwApACAAfQAKAH0ACgBjAGEAdABjAGgAIAB7AAoAIAAgACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAKAAiAFMAYwByAGEAcABlACAAZgBhAGkAbABlAGQAOgAgAHsAMAB9ACIAIAAtAGYAIAAkAF8ALgBFAHgAYwBlAHAAdABpAG8AbgAuAE0AZQBzAHMAYQBnAGUAKQAgAC0ARgBvAHIAZQBnAHIAbwB1AG4AZABDAG8AbABvAHIAIABSAGUAZAAKACAAIAAgACAAZQB4AGkAdAAgADEACgB9AA==
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
echo Optional average-ping filter:
echo - Enter a maximum average ping in milliseconds (for example 50).
echo - Press ENTER to skip the limit and keep all ping-responsive IPs.
:ASKPINGLIMIT
set "PINGLIMIT="
set /p "PINGLIMIT=Maximum average ping in ms (ENTER = no limit): "
if not defined PINGLIMIT (
    echo No average-ping limit selected. All ping-responsive IPs with readable ping results will be kept.
) else (
    echo(!PINGLIMIT!| findstr /r "^[0-9][0-9]*$" >nul
    if errorlevel 1 (
        echo Please enter a whole number, or press ENTER to skip the limit.
        goto ASKPINGLIMIT
    )
    echo Only IPs with average ping below !PINGLIMIT! ms will be shown.
)
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
if errorlevel 1 (
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
for /f "usebackq tokens=1-6 delims=|" %%A in ("!PING_OUTPUT!") do (
    set "RIP=%%A"
    set "RCOUNT=%%B"
    set "RMIN=%%C"
    set "RMAX=%%D"
    set "RAVG=%%E"
    set "RLOSS=%%F"
    set "AVGNUM=!RAVG!"
    set "ISNUM="
    echo(!AVGNUM!| findstr /r "^[0-9][0-9]*$" >nul && set "ISNUM=1"
    set "ACCEPT="
    if not "!RCOUNT!"=="0" if defined ISNUM set "ACCEPT=1"
    if defined PINGLIMIT if defined ISNUM if !AVGNUM! GEQ !PINGLIMIT! set "ACCEPT="
    if defined ACCEPT (
        set /a ONLINE+=1
        set "REF[!ONLINE!]=!RIP!"
        set "REFPROVIDER[!ONLINE!]=Unavailable"
        set "REFLOCATION[!ONLINE!]=Unavailable"
        set "REFMIN[!ONLINE!]=!RMIN!ms"
        set "REFMAX[!ONLINE!]=!RMAX!ms"
        set "REFAVG[!ONLINE!]=!RAVG!ms"
        set "REFLOSS[!ONLINE!]=!RLOSS!"
    )
)
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
    if defined PINGLIMIT (
        echo No IP addresses met the requirement of responding with average ping below !PINGLIMIT! ms.
    ) else (
        echo No ping-responsive IPs with readable average-ping results were found.
    )
    echo Note: some DNS servers block ICMP ping but could still answer DNS queries.
) else (
    echo( REF.    IP ADDRESS            MIN      MAX      AVG  LOSS  PROVIDER                 LOCATION
    echo(--------------------------------------------------------------------------------------------------------------
    for /l %%N in (1,1,!ONLINE!) do (
        set "PAD=   %%N"
        set "CREF=!PAD:~-4!."
        set "PAD=!REF[%%N]!                "
        set "CIP=!PAD:~0,16!"
        set "PAD=        !REFMIN[%%N]!"
        set "CMIN=!PAD:~-8!"
        set "PAD=        !REFMAX[%%N]!"
        set "CMAX=!PAD:~-8!"
        set "PAD=        !REFAVG[%%N]!"
        set "CAVG=!PAD:~-8!"
        set "PAD=    !REFLOSS[%%N]!"
        set "CLOSS=!PAD:~-5!"
        set "CPROV=!REFPROVIDER[%%N]!                        "
        set "CPROV=!CPROV:~0,24!"
        set "CLOC=!REFLOCATION[%%N]!                                  "
        set "CLOC=!CLOC:~0,34!"
        echo(!CREF!    !CIP! !CMIN! !CMAX! !CAVG! !CLOSS! !CPROV! !CLOC!
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
    echo No ping-responsive IPs are available in the current results.
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
echo( REF.    IP ADDRESS       AVG PING  PROVIDER                 LOCATION
echo(------------------------------------------------------------------------------------------------------------
call :LOOKUPINFO
for /l %%N in (1,1,!ONLINE!) do (
    set "PAD=   %%N"
    set "CREF=!PAD:~-4!."
    set "PAD=!REF[%%N]!                "
    set "CIP=!PAD:~0,16!"
    set "PAD=        !REFAVG[%%N]!"
    set "CAVG=!PAD:~-8!"
    set "CPROV=!REFPROVIDER[%%N]!                        "
    set "CPROV=!CPROV:~0,24!"
    set "CLOC=!REFLOCATION[%%N]!                                  "
    set "CLOC=!CLOC:~0,34!"
    echo(!CREF!    !CIP! !CAVG!  !CPROV! !CLOC!
)
echo.
echo Current DNS configuration:
echo DNS IP             PROVIDER                 LOCATION
echo ---------------------------------------------------------------
if !CURRENTDNSCOUNT! EQU 0 echo No DNS servers detected.
for /l %%D in (1,1,!CURRENTDNSCOUNT!) do echo !CURRENTDNS[%%D]!  !CURRENTDNSPROVIDER[%%D]!  !CURRENTDNSLOCATION[%%D]!
echo.
set "AUTOSTART="
set /p "AUTOSTART=Press ENTER to start (0 to cancel): "
if "!AUTOSTART!"=="0" goto RESULTS
if defined AUTOSTART (
    echo Please press ENTER to start, or 0 to cancel.
    pause
    goto SETDNS
)
if defined START_CONNECTION_MONITOR goto MONITORCHOICE_DONE
:ASKCONNECTIONMONITOR
 echo.
 echo Start with connection monitor? (Press ENTER for Yes, 1 for No)
 set "MONITORCHOICE="
 set /p "MONITORCHOICE=Choice: "
 if not defined MONITORCHOICE set "START_CONNECTION_MONITOR=1"
 if "!MONITORCHOICE!"=="1" set "START_CONNECTION_MONITOR=0"
 if defined MONITORCHOICE if not "!MONITORCHOICE!"=="1" (
     echo Press ENTER to start with monitor, or 1 to start without it.
     goto ASKCONNECTIONMONITOR
 )
goto MONITORCHOICE_DONE
:MONITORCHOICE_DONE
call :APPLYDNS
if errorlevel 1 (
    echo Failed to set the first DNS server. Check adapter name and run as Administrator.
    pause
    goto RESULTS
)
if "!START_CONNECTION_MONITOR!"=="1" if not defined CONNECTION_MONITOR_STARTED (
    set "CONNECTION_MONITOR=%~f0"
        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwB0AG8AcAAnAAoAJABwAGEAcgBlAG4AdAA9ACgARwBlAHQALQBDAGkAbQBJAG4AcwB0AGEAbgBjAGUAIAAtAEMAbABhAHMAcwBOAGEAbQBlACAAVwBpAG4AMwAyAF8AUAByAG8AYwBlAHMAcwAgAC0ARgBpAGwAdABlAHIAIAAoACcAUAByAG8AYwBlAHMAcwBJAGQAIAA9ACAAJwArACQAUABJAEQAKQApAC4AUABhAHIAZQBuAHQAUAByAG8AYwBlAHMAcwBJAGQACgAkAHAAYQByAGUAbgB0AFMAdABhAHIAdAA9ACgARwBlAHQALQBQAHIAbwBjAGUAcwBzACAALQBJAGQAIAAkAHAAYQByAGUAbgB0ACkALgBTAHQAYQByAHQAVABpAG0AZQAuAFQAaQBjAGsAcwAKACQAYwBtAGQAQQByAGcAcwA9ACcALwBjACAAIgAiACcAKwAkAGUAbgB2ADoAQwBPAE4ATgBFAEMAVABJAE8ATgBfAE0ATwBOAEkAVABPAFIAKwAnACIAIAAtAC0AYwBvAG4AbgBlAGMAdABpAG8AbgAtAG0AbwBuAGkAdABvAHIAIgAnAAoAJABtAG8AbgBpAHQAbwByAD0AUwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcwAgAC0ARgBpAGwAZQBQAGEAdABoACAAJABlAG4AdgA6AEMAbwBtAFMAcABlAGMAIAAtAEEAcgBnAHUAbQBlAG4AdABMAGkAcwB0ACAAJABjAG0AZABBAHIAZwBzACAALQBXAGkAbgBkAG8AdwBTAHQAeQBsAGUAIABIAGkAZABkAGUAbgAgAC0AUABhAHMAcwBUAGgAcgB1AAoAWwBJAE8ALgBGAGkAbABlAF0AOgA6AFcAcgBpAHQAZQBBAGwAbABUAGUAeAB0ACgAJABlAG4AdgA6AEMATwBOAE4ARQBDAFQASQBPAE4AXwBNAE8ATgBJAFQATwBSAF8AUABJAEQARgBJAEwARQAsAFsAcwB0AHIAaQBuAGcAXQAkAG0AbwBuAGkAdABvAHIALgBJAGQAKQAKACQAZQBuAHYAOgBEAE4AUwBfAE0ATwBOAEkAVABPAFIAXwBQAEEAUgBFAE4AVABfAFAASQBEAD0AWwBzAHQAcgBpAG4AZwBdACQAcABhAHIAZQBuAHQACgAkAGUAbgB2ADoARABOAFMAXwBNAE8ATgBJAFQATwBSAF8AUABBAFIARQBOAFQAXwBTAFQAQQBSAFQAPQBbAHMAdAByAGkAbgBnAF0AJABwAGEAcgBlAG4AdABTAHQAYQByAHQACgAkAGUAbgB2ADoARABOAFMAXwBNAE8ATgBJAFQATwBSAF8AQwBIAEkATABEAF8AUABJAEQAPQBbAHMAdAByAGkAbgBnAF0AJABtAG8AbgBpAHQAbwByAC4ASQBkAAoAJAB3AGEAdABjAGgAZQByAD0AJwAkAG0APQBbAGkAbgB0AF0AJABlAG4AdgA6AEQATgBTAF8ATQBPAE4ASQBUAE8AUgBfAFAAQQBSAEUATgBUAF8AUABJAEQAOwAkAHQAPQBbAGwAbwBuAGcAXQAkAGUAbgB2ADoARABOAFMAXwBNAE8ATgBJAFQATwBSAF8AUABBAFIARQBOAFQAXwBTAFQAQQBSAFQAOwAkAGMAPQBbAGkAbgB0AF0AJABlAG4AdgA6AEQATgBTAF8ATQBPAE4ASQBUAE8AUgBfAEMASABJAEwARABfAFAASQBEADsAJABmAD0AJABlAG4AdgA6AEMATwBOAE4ARQBDAFQASQBPAE4AXwBNAE8ATgBJAFQATwBSAF8AUABJAEQARgBJAEwARQA7AHcAaABpAGwAZQAoACQAdAByAHUAZQApAHsAJABwAD0ARwBlAHQALQBQAHIAbwBjAGUAcwBzACAALQBJAGQAIAAkAG0AIAAtAEUAcgByAG8AcgBBAGMAdABpAG8AbgAgAFMAaQBsAGUAbgB0AGwAeQBDAG8AbgB0AGkAbgB1AGUAOwBpAGYAKAAhACQAcAAgAC0AbwByACAAJABwAC4AUwB0AGEAcgB0AFQAaQBtAGUALgBUAGkAYwBrAHMAIAAtAG4AZQAgACQAdAApAHsAJgAgAHQAYQBzAGsAawBpAGwAbAAuAGUAeABlACAALwBQAEkARAAgACQAYwAgAC8AVAAgAC8ARgAgAD4AJABuAHUAbABsACAAMgA+ACYAMQA7AFIAZQBtAG8AdgBlAC0ASQB0AGUAbQAgAC0ATABpAHQAZQByAGEAbABQAGEAdABoACAAJABmACAALQBGAG8AcgBjAGUAIAAtAEUAcgByAG8AcgBBAGMAdABpAG8AbgAgAFMAaQBsAGUAbgB0AGwAeQBDAG8AbgB0AGkAbgB1AGUAOwBiAHIAZQBhAGsAfQA7AGkAZgAoACEAKABHAGUAdAAtAFAAcgBvAGMAZQBzAHMAIAAtAEkAZAAgACQAYwAgAC0ARQByAHIAbwByAEEAYwB0AGkAbwBuACAAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQApACkAewBSAGUAbQBvAHYAZQAtAEkAdABlAG0AIAAtAEwAaQB0AGUAcgBhAGwAUABhAHQAaAAgACQAZgAgAC0ARgBvAHIAYwBlACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlADsAYgByAGUAYQBrAH0AOwBTAHQAYQByAHQALQBTAGwAZQBlAHAAIAAtAFMAZQBjAG8AbgBkAHMAIAAyAH0AJwAKACQAdwBhAHQAYwBoAGUAcgBFAG4AYwBvAGQAZQBkAD0AWwBDAG8AbgB2AGUAcgB0AF0AOgA6AFQAbwBCAGEAcwBlADYANABTAHQAcgBpAG4AZwAoAFsAVABlAHgAdAAuAEUAbgBjAG8AZABpAG4AZwBdADoAOgBVAG4AaQBjAG8AZABlAC4ARwBlAHQAQgB5AHQAZQBzACgAJAB3AGEAdABjAGgAZQByACkAKQAKAFMAdABhAHIAdAAtAFAAcgBvAGMAZQBzAHMAIAAtAEYAaQBsAGUAUABhAHQAaAAgACcAcABvAHcAZQByAHMAaABlAGwAbAAuAGUAeABlACcAIAAtAFcAaQBuAGQAbwB3AFMAdAB5AGwAZQAgAEgAaQBkAGQAZQBuACAALQBBAHIAZwB1AG0AZQBuAHQATABpAHMAdAAgACgAJwAtAE4AbwBQAHIAbwBmAGkAbABlACAALQBOAG8AbgBJAG4AdABlAHIAYQBjAHQAaQB2AGUAIAAtAEUAbgBjAG8AZABlAGQAQwBvAG0AbQBhAG4AZAAgACcAKwAkAHcAYQB0AGMAaABlAHIARQBuAGMAbwBkAGUAZAApAA==
    if exist "!CONNECTION_MONITOR_PIDFILE!" set "CONNECTION_MONITOR_STARTED=1"
)
goto DNSMONITOR

:APPLYDNS
call :GETCURRENTDNS
cls
call :MONITORHEADER
netsh interface ipv4 set dnsservers name="!ADAPTER!" source=static address=!DNS! register=primary validate=no
if errorlevel 1 exit /b 1
if "!MONITOR_VISIBLE!"=="1" (
    set "DNS_MONITOR_WINDOW_ACTION=show"
    call :SETMONITORWINDOW
)
>"!LASTDNS!" echo(!DNS!
set "CURRENTDNSCOUNT=1"
set "CURRENTDNS[1]=!DNS!"
set "CURRENTDNSPROVIDER[1]=Unavailable"
set "CURRENTDNSLOCATION[1]=Unavailable"
for /l %%K in (1,1,!ONLINE!) do if "!REF[%%K]!"=="!DNS!" (
    set "CURRENTDNSPROVIDER[1]=!REFPROVIDER[%%K]!"
    set "CURRENTDNSLOCATION[1]=!REFLOCATION[%%K]!"
)
rem Flush Windows DNS resolver cache after each successful DNS change.
ipconfig /flushdns
if errorlevel 1 echo Warning: DNS changed, but the resolver cache could not be flushed.
call :LOOKUPINFO
exit /b 0

:DNSMONITOR
cls
call :MONITORHEADER
if defined AUTOFAILOVER (echo Automatically switched after two consecutive endpoint failures. & set "AUTOFAILOVER=")
powershell.exe -NoProfile -NonInteractive -Command "$oldTreat=[Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput=$true; $result=0; $next=0; $prev=0; while($result -eq 0){ if([Console]::KeyAvailable){$key=[Console]::ReadKey($true); if($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)){$result=5} elseif($key.Key -eq [ConsoleKey]::Q){$result=4} elseif($key.Key -eq [ConsoleKey]::S){$result=7} elseif($key.Key -eq [ConsoleKey]::Enter){$next++} elseif($key.Key -eq [ConsoleKey]::Backspace){$prev++}; if(($next+$prev) -gt 0 -and $result -eq 0){$until=[DateTime]::UtcNow.AddMilliseconds(120); while([DateTime]::UtcNow -lt $until){while([Console]::KeyAvailable){$key=[Console]::ReadKey($true); if($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)){$result=5} elseif($key.Key -eq [ConsoleKey]::Q){$result=4} elseif($key.Key -eq [ConsoleKey]::S){$result=7} elseif($key.Key -eq [ConsoleKey]::Enter){$next++} elseif($key.Key -eq [ConsoleKey]::Backspace){$prev++}}; Start-Sleep -Milliseconds 5}; $delta=$next-$prev; if($delta -ne 0 -and $result -eq 0){[IO.File]::WriteAllText($env:DNS_NAV_FILE,[string]$delta); $result=8}}}; if($result -eq 0 -and $env:DNS_MONITOR_STATUS_FILE -and (Test-Path -LiteralPath $env:DNS_MONITOR_STATUS_FILE)){$status=[IO.File]::ReadAllText($env:DNS_MONITOR_STATUS_FILE).Trim(); if($status -match '^([0-9]+)\|(.+)$' -and [int]$Matches[1] -ge 2 -and $Matches[2] -eq $env:DNS){$result=6}}; if($result -eq 0){Start-Sleep -Milliseconds 200}}; [Console]::TreatControlCAsInput=$oldTreat; exit $result" >nul 2>&1
if errorlevel 8 goto BATCHNAV
if errorlevel 7 goto TOGGLEMONITOR
if errorlevel 6 goto AUTONEXTDNS
if errorlevel 5 goto END
if errorlevel 4 goto STOPMONITORANDMENU
if errorlevel 3 goto PREVDNS
if errorlevel 2 goto NEXTDNS
goto DNSMONITOR

:TOGGLEMONITOR
if "!MONITOR_VISIBLE!"=="1" (
    set "MONITOR_VISIBLE=0"
    set "DNS_MONITOR_WINDOW_ACTION=hide"
) else (
    set "MONITOR_VISIBLE=1"
    set "DNS_MONITOR_WINDOW_ACTION=show"
)
call :SETMONITORWINDOW
goto DNSMONITOR
:SETMONITORWINDOW
powershell.exe -NoProfile -NonInteractive -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJAByAGEAdwA9AEcAZQB0AC0AQwBvAG4AdABlAG4AdAAgAC0ATABpAHQAZQByAGEAbABQAGEAdABoACAAJABlAG4AdgA6AEMATwBOAE4ARQBDAFQASQBPAE4AXwBNAE8ATgBJAFQATwBSAF8AUABJAEQARgBJAEwARQAgAC0AVABvAHQAYQBsAEMAbwB1AG4AdAAgADEACgAkAHQAYQByAGcAZQB0AD0AMAAKAGkAZgAoAC0AbgBvAHQAIABbAGkAbgB0AF0AOgA6AFQAcgB5AFAAYQByAHMAZQAoAFsAcwB0AHIAaQBuAGcAXQAkAHIAYQB3ACwAWwByAGUAZgBdACQAdABhAHIAZwBlAHQAKQApAHsAZQB4AGkAdAAgADEAfQAKACQAdAB5AHAAZQA9ACcAdQBzAGkAbgBnACAAUwB5AHMAdABlAG0AOwAgAHUAcwBpAG4AZwAgAFMAeQBzAHQAZQBtAC4AUgB1AG4AdABpAG0AZQAuAEkAbgB0AGUAcgBvAHAAUwBlAHIAdgBpAGMAZQBzADsAIABwAHUAYgBsAGkAYwAgAHMAdABhAHQAaQBjACAAYwBsAGEAcwBzACAARABuAHMATQBvAG4AaQB0AG8AcgBXAGkAbgBkAG8AdwBBAHAAaQAgAHsAIABbAEQAbABsAEkAbQBwAG8AcgB0ACgAIgBrAGUAcgBuAGUAbAAzADIALgBkAGwAbAAiACwAIABTAGUAdABMAGEAcwB0AEUAcgByAG8AcgA9AHQAcgB1AGUAKQBdACAAcAB1AGIAbABpAGMAIABzAHQAYQB0AGkAYwAgAGUAeAB0AGUAcgBuACAAYgBvAG8AbAAgAEYAcgBlAGUAQwBvAG4AcwBvAGwAZQAoACkAOwAgAFsARABsAGwASQBtAHAAbwByAHQAKAAiAGsAZQByAG4AZQBsADMAMgAuAGQAbABsACIALAAgAFMAZQB0AEwAYQBzAHQARQByAHIAbwByAD0AdAByAHUAZQApAF0AIABwAHUAYgBsAGkAYwAgAHMAdABhAHQAaQBjACAAZQB4AHQAZQByAG4AIABiAG8AbwBsACAAQQB0AHQAYQBjAGgAQwBvAG4AcwBvAGwAZQAoAHUAaQBuAHQAIABwAHIAbwBjAGUAcwBzAEkAZAApADsAIABbAEQAbABsAEkAbQBwAG8AcgB0ACgAIgBrAGUAcgBuAGUAbAAzADIALgBkAGwAbAAiACkAXQAgAHAAdQBiAGwAaQBjACAAcwB0AGEAdABpAGMAIABlAHgAdABlAHIAbgAgAEkAbgB0AFAAdAByACAARwBlAHQAQwBvAG4AcwBvAGwAZQBXAGkAbgBkAG8AdwAoACkAOwAgAFsARABsAGwASQBtAHAAbwByAHQAKAAiAHUAcwBlAHIAMwAyAC4AZABsAGwAIgApAF0AIABwAHUAYgBsAGkAYwAgAHMAdABhAHQAaQBjACAAZQB4AHQAZQByAG4AIABiAG8AbwBsACAAUwBoAG8AdwBXAGkAbgBkAG8AdwAoAEkAbgB0AFAAdAByACAAaABXAG4AZAAsAGkAbgB0ACAAbgBDAG0AZABTAGgAbwB3ACkAOwAgAH0AJwAKAEEAZABkAC0AVAB5AHAAZQAgAC0AVAB5AHAAZQBEAGUAZgBpAG4AaQB0AGkAbwBuACAAJAB0AHkAcABlACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlAAoAWwB2AG8AaQBkAF0AWwBEAG4AcwBNAG8AbgBpAHQAbwByAFcAaQBuAGQAbwB3AEEAcABpAF0AOgA6AEYAcgBlAGUAQwBvAG4AcwBvAGwAZQAoACkACgBpAGYAKAAtAG4AbwB0ACAAWwBEAG4AcwBNAG8AbgBpAHQAbwByAFcAaQBuAGQAbwB3AEEAcABpAF0AOgA6AEEAdAB0AGEAYwBoAEMAbwBuAHMAbwBsAGUAKABbAHUAaQBuAHQAMwAyAF0AJAB0AGEAcgBnAGUAdAApACkAewBlAHgAaQB0ACAAMQB9AAoAJABoAGEAbgBkAGwAZQA9AFsARABuAHMATQBvAG4AaQB0AG8AcgBXAGkAbgBkAG8AdwBBAHAAaQBdADoAOgBHAGUAdABDAG8AbgBzAG8AbABlAFcAaQBuAGQAbwB3ACgAKQAKAGkAZgAoACQAaABhAG4AZABsAGUAIAAtAGUAcQAgAFsASQBuAHQAUAB0AHIAXQA6ADoAWgBlAHIAbwApAHsAWwB2AG8AaQBkAF0AWwBEAG4AcwBNAG8AbgBpAHQAbwByAFcAaQBuAGQAbwB3AEEAcABpAF0AOgA6AEYAcgBlAGUAQwBvAG4AcwBvAGwAZQAoACkAOwBlAHgAaQB0ACAAMQB9AAoAJABjAG8AbQBtAGEAbgBkAD0AMAAKAGkAZgAoACQAZQBuAHYAOgBEAE4AUwBfAE0ATwBOAEkAVABPAFIAXwBXAEkATgBEAE8AVwBfAEEAQwBUAEkATwBOACAALQBlAHEAIAAnAHMAaABvAHcAJwApAHsAJABjAG8AbQBtAGEAbgBkAD0ANQB9AAoAWwB2AG8AaQBkAF0AWwBEAG4AcwBNAG8AbgBpAHQAbwByAFcAaQBuAGQAbwB3AEEAcABpAF0AOgA6AFMAaABvAHcAVwBpAG4AZABvAHcAKAAkAGgAYQBuAGQAbABlACwAJABjAG8AbQBtAGEAbgBkACkACgBbAHYAbwBpAGQAXQBbAEQAbgBzAE0AbwBuAGkAdABvAHIAVwBpAG4AZABvAHcAQQBwAGkAXQA6ADoARgByAGUAZQBDAG8AbgBzAG8AbABlACgAKQAKAGUAeABpAHQAIAAwAA== >nul 2>&1
exit /b

:AUTONEXTDNS
set "AUTOFAILOVER=1"
goto NEXTDNS

:BATCHNAV
set "KEY_DELTA="
if exist "!DNS_NAV_FILE!" set /p "KEY_DELTA="<"!DNS_NAV_FILE!"
del /q "!DNS_NAV_FILE!" >nul 2>&1
if not defined KEY_DELTA goto DNSMONITOR
set /a DNSINDEX=((DNSINDEX-1+KEY_DELTA) %% ONLINE + ONLINE) %% ONLINE + 1
call :GETCURRENTDNS
if defined START_CONNECTION_MONITOR goto MONITORCHOICE_DONE
:ASKCONNECTIONMONITOR
 echo.
 echo Start with connection monitor? (Press ENTER for Yes, 1 for No)
 set "MONITORCHOICE="
 set /p "MONITORCHOICE=Choice: "
 if not defined MONITORCHOICE set "START_CONNECTION_MONITOR=1"
 if "!MONITORCHOICE!"=="1" set "START_CONNECTION_MONITOR=0"
 if defined MONITORCHOICE if not "!MONITORCHOICE!"=="1" (
     echo Press ENTER to start with monitor, or 1 to start without it.
     goto ASKCONNECTIONMONITOR
 )
goto MONITORCHOICE_DONE
:MONITORCHOICE_DONE
call :APPLYDNS
if errorlevel 1 (
    echo Failed to set DNS. Check adapter name and run as Administrator.
    pause
    goto RESULTS
)
goto DNSMONITOR

:NEXTDNS
set /a DNSINDEX+=1
if !DNSINDEX! GTR !ONLINE! set "DNSINDEX=1"
call :GETCURRENTDNS
if defined START_CONNECTION_MONITOR goto MONITORCHOICE_DONE
:ASKCONNECTIONMONITOR
 echo.
 echo Start with connection monitor? (Press ENTER for Yes, 1 for No)
 set "MONITORCHOICE="
 set /p "MONITORCHOICE=Choice: "
 if not defined MONITORCHOICE set "START_CONNECTION_MONITOR=1"
 if "!MONITORCHOICE!"=="1" set "START_CONNECTION_MONITOR=0"
 if defined MONITORCHOICE if not "!MONITORCHOICE!"=="1" (
     echo Press ENTER to start with monitor, or 1 to start without it.
     goto ASKCONNECTIONMONITOR
 )
goto MONITORCHOICE_DONE
:MONITORCHOICE_DONE
call :APPLYDNS
if errorlevel 1 (
    echo Failed to set DNS. Check adapter name and run as Administrator.
    pause
    goto RESULTS
)
goto DNSMONITOR

:PREVDNS
set /a DNSINDEX-=1
if !DNSINDEX! LSS 1 set "DNSINDEX=!ONLINE!"
call :GETCURRENTDNS
if defined START_CONNECTION_MONITOR goto MONITORCHOICE_DONE
:ASKCONNECTIONMONITOR
 echo.
 echo Start with connection monitor? (Press ENTER for Yes, 1 for No)
 set "MONITORCHOICE="
 set /p "MONITORCHOICE=Choice: "
 if not defined MONITORCHOICE set "START_CONNECTION_MONITOR=1"
 if "!MONITORCHOICE!"=="1" set "START_CONNECTION_MONITOR=0"
 if defined MONITORCHOICE if not "!MONITORCHOICE!"=="1" (
     echo Press ENTER to start with monitor, or 1 to start without it.
     goto ASKCONNECTIONMONITOR
 )
goto MONITORCHOICE_DONE
:MONITORCHOICE_DONE
call :APPLYDNS
if errorlevel 1 (
    echo Failed to set DNS. Check adapter name and run as Administrator.
    pause
    goto RESULTS
)
goto DNSMONITOR
:STOPMONITORANDMENU
call :STOPCONNECTIONMONITOR
goto RESULTS

:STOPCONNECTIONMONITOR
if exist "!CONNECTION_MONITOR_PIDFILE!" (
    for /f "usebackq delims=" %%P in ("!CONNECTION_MONITOR_PIDFILE!") do taskkill /PID %%P /T /F >nul 2>&1
    del /q "!CONNECTION_MONITOR_PIDFILE!" >nul 2>&1
)
del /q "!DNS_MONITOR_STATUS_FILE!" >nul 2>&1
set "CONNECTION_MONITOR_STARTED="
del /q "!DNS_NAV_FILE!" >nul 2>&1
exit /b

:MONITORHEADER
echo ============================================================
echo                  DNS SERVER SELECTION
echo ============================================================
echo Adapter: !ADAPTER!
echo Current DNS: !DNS! (server !DNSINDEX! of !ONLINE!)
for %%N in (!DNSINDEX!) do (
    echo Provider: !REFPROVIDER[%%N]!
    echo Location: !REFLOCATION[%%N]!
)
echo ENTER: next DNS   BACKSPACE: previous DNS   S: show/hide checker   Q: online ping results
echo.
exit /b

:GETCURRENTDNS
for %%N in (!DNSINDEX!) do set "DNS=!REF[%%N]!"
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
REM Embedded provider and location lookup (ip-api batch, with ipinfo fallback).
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJABpAG4AcAB1AHQASQBwAHMAPQBOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBDAG8AbABsAGUAYwB0AGkAbwBuAHMALgBHAGUAbgBlAHIAaQBjAC4ATABpAHMAdABbAHMAdAByAGkAbgBnAF0ACgAkAGMAYQBjAGgAZQA9AEAAewB9AAoAZgBvAHIAZQBhAGMAaAAoACQAbABpAG4AZQAgAGkAbgAgAEAAKABHAGUAdAAtAEMAbwBuAHQAZQBuAHQAIAAtAEwAaQB0AGUAcgBhAGwAUABhAHQAaAAgACQAZQBuAHYAOgBEAE4AUwBfAEkATgBGAE8AXwBJAE4AUABVAFQAKQApAHsAIAAkAHAAYQByAHQAcwA9ACQAbABpAG4AZQAgAC0AcwBwAGwAaQB0ACAAJwBcAHwAJwAsADMAOwAgAGkAZgAoACQAcABhAHIAdABzAC4AQwBvAHUAbgB0ACAALQBsAHQAIAAzACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACAAJABpAHAAPQAkAHAAYQByAHQAcwBbADAAXQAuAFQAcgBpAG0AKAApADsAIABpAGYAKAAhACQAaQBwACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACAAJABpAG4AcAB1AHQASQBwAHMALgBBAGQAZAAoACQAaQBwACkAOwAgACQAcAByAG8AdgBpAGQAZQByAD0AJABwAGEAcgB0AHMAWwAxAF0ALgBUAHIAaQBtACgAKQA7ACAAJABsAG8AYwBhAHQAaQBvAG4APQAkAHAAYQByAHQAcwBbADIAXQAuAFQAcgBpAG0AKAApADsAIABpAGYAKAAkAHAAcgBvAHYAaQBkAGUAcgAgAC0AZQBxACAAJwBVAG4AYQB2AGEAaQBsAGEAYgBsAGUAJwApAHsAJABwAHIAbwB2AGkAZABlAHIAPQAnACcAfQA7ACAAaQBmACgAJABsAG8AYwBhAHQAaQBvAG4AIAAtAGUAcQAgACcAVQBuAGEAdgBhAGkAbABhAGIAbABlACcAKQB7ACQAbABvAGMAYQB0AGkAbwBuAD0AJwAnAH0AOwAgAGkAZgAoACQAcAByAG8AdgBpAGQAZQByACAALQBvAHIAIAAkAGwAbwBjAGEAdABpAG8AbgApAHsAJABjAGEAYwBoAGUAWwAkAGkAcABdAD0AQAB7AHAAPQAkAHAAcgBvAHYAaQBkAGUAcgA7AGwAPQAkAGwAbwBjAGEAdABpAG8AbgB9AH0AIAB9AAoAJABjAHUAcgByAGUAbgB0AEQAbgBzAD0AQAAoAEcAZQB0AC0ARABuAHMAQwBsAGkAZQBuAHQAUwBlAHIAdgBlAHIAQQBkAGQAcgBlAHMAcwAgAC0ASQBuAHQAZQByAGYAYQBjAGUAQQBsAGkAYQBzACAAJABlAG4AdgA6AEEARABBAFAAVABFAFIAIAAtAEUAcgByAG8AcgBBAGMAdABpAG8AbgAgAFMAaQBsAGUAbgB0AGwAeQBDAG8AbgB0AGkAbgB1AGUAIAB8ACAARgBvAHIARQBhAGMAaAAtAE8AYgBqAGUAYwB0ACAAewAkAF8ALgBTAGUAcgB2AGUAcgBBAGQAZAByAGUAcwBzAGUAcwB9ACAAfAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAkAF8AfQAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBVAG4AaQBxAHUAZQApAAoAJABpAHAAcwA9AEAAKAAkAGkAbgBwAHUAdABJAHAAcwArACQAYwB1AHIAcgBlAG4AdABEAG4AcwAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBVAG4AaQBxAHUAZQApAAoAJAB0AG8AZABvAD0AQAAoACQAaQBwAHMAIAB8ACAAVwBoAGUAcgBlAC0ATwBiAGoAZQBjAHQAIAB7ACEAJABjAGEAYwBoAGUALgBDAG8AbgB0AGEAaQBuAHMASwBlAHkAKAAkAF8AKQAgAC0AbwByACAAIQAkAGMAYQBjAGgAZQBbACQAXwBdAC4AcAAgAC0AbwByACAAIQAkAGMAYQBjAGgAZQBbACQAXwBdAC4AbAB9ACkACgBmAG8AcgAoACQAcwB0AGEAcgB0AD0AMAA7ACQAcwB0AGEAcgB0ACAALQBsAHQAIAAkAHQAbwBkAG8ALgBDAG8AdQBuAHQAOwAkAHMAdABhAHIAdAArAD0AMQAwADAAKQB7ACAAJABsAGEAcwB0AD0AWwBNAGEAdABoAF0AOgA6AE0AaQBuACgAJABzAHQAYQByAHQAKwA5ADkALAAkAHQAbwBkAG8ALgBDAG8AdQBuAHQALQAxACkAOwAgACQAYwBoAHUAbgBrAD0AQAAoACQAdABvAGQAbwBbACQAcwB0AGEAcgB0AC4ALgAkAGwAYQBzAHQAXQApADsAIAB0AHIAeQAgAHsAIAAkAGEAbgBzAD0ASQBuAHYAbwBrAGUALQBSAGUAcwB0AE0AZQB0AGgAbwBkACAALQBVAHIAaQAgACcAaAB0AHQAcAA6AC8ALwBpAHAALQBhAHAAaQAuAGMAbwBtAC8AYgBhAHQAYwBoAD8AZgBpAGUAbABkAHMAPQBzAHQAYQB0AHUAcwAsAGMAbwB1AG4AdAByAHkALAByAGUAZwBpAG8AbgBOAGEAbQBlACwAYwBpAHQAeQAsAGkAcwBwACwAbwByAGcALABhAHMAbgBhAG0AZQAsAHEAdQBlAHIAeQAnACAALQBNAGUAdABoAG8AZAAgAFAAbwBzAHQAIAAtAEIAbwBkAHkAIAAoAEMAbwBuAHYAZQByAHQAVABvAC0ASgBzAG8AbgAgAC0ASQBuAHAAdQB0AE8AYgBqAGUAYwB0ACAAJABjAGgAdQBuAGsAIAAtAEMAbwBtAHAAcgBlAHMAcwApACAALQBDAG8AbgB0AGUAbgB0AFQAeQBwAGUAIAAnAGEAcABwAGwAaQBjAGEAdABpAG8AbgAvAGoAcwBvAG4AJwAgAC0AVABpAG0AZQBvAHUAdABTAGUAYwAgADIAMAA7ACAAZgBvAHIAZQBhAGMAaAAoACQAeAAgAGkAbgAgAEAAKAAkAGEAbgBzACkAKQB7ACAAaQBmACgAJAB4AC4AcwB0AGEAdAB1AHMAIAAtAG4AZQAgACcAcwB1AGMAYwBlAHMAcwAnACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACAAJABpAHAAPQBbAHMAdAByAGkAbgBnAF0AJAB4AC4AcQB1AGUAcgB5ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAC4AQwBvAG4AdABhAGkAbgBzAEsAZQB5ACgAJABpAHAAKQApAHsAJABjAGEAYwBoAGUAWwAkAGkAcABdAD0AQAB7AHAAPQAnACcAOwBsAD0AJwAnAH0AfQA7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBwACkAewAkAHAAcgBvAHYAaQBkAGUAcgA9ACQAeAAuAGkAcwBwADsAIABpAGYAKAAhACQAcAByAG8AdgBpAGQAZQByACkAewAkAHAAcgBvAHYAaQBkAGUAcgA9ACQAeAAuAG8AcgBnAH0AOwAgAGkAZgAoACEAJABwAHIAbwB2AGkAZABlAHIAKQB7ACQAcAByAG8AdgBpAGQAZQByAD0AJAB4AC4AYQBzAG4AYQBtAGUAfQA7ACAAJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AcAA9AFsAcwB0AHIAaQBuAGcAXQAkAHAAcgBvAHYAaQBkAGUAcgB9ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAPQAoAEAAKAAkAHgALgBjAGkAdAB5ACwAJAB4AC4AcgBlAGcAaQBvAG4ATgBhAG0AZQAsACQAeAAuAGMAbwB1AG4AdAByAHkAKQB8AFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAkAF8AfQApACAALQBqAG8AaQBuACAAJwAsACAAJwB9ACAAfQAgAH0AIABjAGEAdABjAGgAIAB7AH0AIAB9AAoAZgBvAHIAZQBhAGMAaAAoACQAaQBwACAAaQBuACAAJAB0AG8AZABvACkAewAgAGkAZgAoACEAJABjAGEAYwBoAGUALgBDAG8AbgB0AGEAaQBuAHMASwBlAHkAKAAkAGkAcAApACkAewAkAGMAYQBjAGgAZQBbACQAaQBwAF0APQBAAHsAcAA9ACcAJwA7AGwAPQAnACcAfQB9ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAHAAIAAtAG8AcgAgACEAJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AbAApAHsAIAB0AHIAeQAgAHsAIAAkAHgAPQBJAG4AdgBvAGsAZQAtAFIAZQBzAHQATQBlAHQAaABvAGQAIAAtAFUAcgBpACAAKAAnAGgAdAB0AHAAcwA6AC8ALwBpAHAAaQBuAGYAbwAuAGkAbwAvACcAKwBbAHUAcgBpAF0AOgA6AEUAcwBjAGEAcABlAEQAYQB0AGEAUwB0AHIAaQBuAGcAKAAkAGkAcAApACsAJwAvAGoAcwBvAG4AJwApACAALQBUAGkAbQBlAG8AdQB0AFMAZQBjACAAMgAwADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAHAAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAHAAPQBbAHMAdAByAGkAbgBnAF0AJAB4AC4AbwByAGcAfQA7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBsACkAewAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBsAD0AKABAACgAJAB4AC4AYwBpAHQAeQAsACQAeAAuAHIAZQBnAGkAbwBuACwAJAB4AC4AYwBvAHUAbgB0AHIAeQApAHwAVwBoAGUAcgBlAC0ATwBiAGoAZQBjAHQAIAB7ACQAXwB9ACkAIAAtAGoAbwBpAG4AIAAnACwAIAAnAH0AIAB9ACAAYwBhAHQAYwBoACAAewB9ACAAfQA7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBwACkAewAkAGMAYQBjAGgAZQBbACQAaQBwAF0ALgBwAD0AJwBVAG4AYQB2AGEAaQBsAGEAYgBsAGUAJwB9ADsAIABpAGYAKAAhACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQAuAGwAPQAnAFUAbgBhAHYAYQBpAGwAYQBiAGwAZQAnAH0AIAB9AAoAZgB1AG4AYwB0AGkAbwBuACAAVwByAGkAdABlAC0ASQBuAGYAbwBMAGkAbgBlACgAJABrAGkAbgBkACwAJABpAHAAKQB7ACAAJABwAD0AKABbAHMAdAByAGkAbgBnAF0AJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AcAAgAC0AcgBlAHAAbABhAGMAZQAgACcAXABzACoAXAAoAEEAUwBcAGQAKwBcACkAJwAsACcAJwAgAC0AcgBlAHAAbABhAGMAZQAgACcAWwB8AFwAdABcAHIAXABuAF0AJwAsACcAIAAnACkALgBUAHIAaQBtACgAKQA7ACAAJABsAD0AKABbAHMAdAByAGkAbgBnAF0AJABjAGEAYwBoAGUAWwAkAGkAcABdAC4AbAAgAC0AcgBlAHAAbABhAGMAZQAgACcAWwB8AFwAdABcAHIAXABuAF0AJwAsACcAIAAnACkALgBUAHIAaQBtACgAKQA7ACAAaQBmACgAIQAkAHAAKQB7ACQAcAA9ACcAVQBuAGEAdgBhAGkAbABhAGIAbABlACcAfQA7ACAAaQBmACgAIQAkAGwAKQB7ACQAbAA9ACcAVQBuAGEAdgBhAGkAbABhAGIAbABlACcAfQA7ACAAJABrAGkAbgBkACsAJwB8ACcAKwAkAGkAcAArACcAfAAnACsAJABwACsAJwB8ACcAKwAkAGwAIAB9AAoAZgBvAHIAZQBhAGMAaAAoACQAaQBwACAAaQBuACAAJABpAG4AcAB1AHQASQBwAHMAKQB7ACAAVwByAGkAdABlAC0ASQBuAGYAbwBMAGkAbgBlACAAJwBJACcAIAAkAGkAcAAgAH0ACgBmAG8AcgBlAGEAYwBoACgAJABpAHAAIABpAG4AIAAkAGMAdQByAHIAZQBuAHQARABuAHMAKQB7ACAAaQBmACgAIQAkAGMAYQBjAGgAZQAuAEMAbwBuAHQAYQBpAG4AcwBLAGUAeQAoACQAaQBwACkAKQB7ACQAYwBhAGMAaABlAFsAJABpAHAAXQA9AEAAewBwAD0AJwBVAG4AYQB2AGEAaQBsAGEAYgBsAGUAJwA7AGwAPQAnAFUAbgBhAHYAYQBpAGwAYQBiAGwAZQAnAH0AfQA7ACAAVwByAGkAdABlAC0ASQBuAGYAbwBMAGkAbgBlACAAJwBDACcAIAAkAGkAcAAgAH0A > "!INFO_OUTPUT!" 2>nul
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

:SHOWDNS
echo.
echo DNS servers configured on "!ADAPTER!":
call :LOOKUPINFO
echo DNS IP             PROVIDER                 LOCATION
echo ---------------------------------------------------------------
if !CURRENTDNSCOUNT! EQU 0 echo No DNS servers detected.
for /l %%D in (1,1,!CURRENTDNSCOUNT!) do echo !CURRENTDNS[%%D]!  !CURRENTDNSPROVIDER[%%D]!  !CURRENTDNSLOCATION[%%D]!
echo.
echo All Windows network adapter DNS entries:
ipconfig /all | findstr /i /c:"DNS Servers" /c:"DNS Server"
echo.
pause
goto START

:END
call :STOPCONNECTIONMONITOR
del "!PING_INPUT!" >nul 2>&1
del "!PING_OUTPUT!" >nul 2>&1
del "!PING_SCRIPT!" >nul 2>&1
del "!VOTETEMP!" >nul 2>&1
endlocal
exit /b

:CM_ENTRY
setlocal EnableExtensions EnableDelayedExpansion
shift
rem Scan interval in seconds; change this value in the editor (use a number greater than 0).
set "SCAN_INTERVAL_SECONDS=1"
set "VALORANT_TCP_PORT=443"
set "TCP_TIMEOUT_MS=300"
set "DNS_CHECK_TIMEOUT_MS=3000"

rem Active check: Google, using normal DNS resolution only.
rem set "VALORANT_ENDPOINT=google.com"
rem set "CHECK_TCP=0"

rem To change the target, comment out the two active lines above and uncomment ONE target below.
rem Standard VALORANT hostname, DNS-only:
rem set "VALORANT_ENDPOINT=playvalorant.com"
rem set "CHECK_TCP=0"

rem AP shared service, DNS + TCP:
rem set "VALORANT_ENDPOINT=shared.ap.a.pvp.net"
rem set "CHECK_TCP=1"

rem AP Player Data, DNS + TCP:
rem set "VALORANT_ENDPOINT=pd.ap.a.pvp.net"
rem set "CHECK_TCP=1"

rem AP Game Lobby / Matchmaking, DNS + TCP:
set "VALORANT_ENDPOINT=glz-ap-1.ap.a.pvp.net"
set "CHECK_TCP=1"

title DNS Endpoint Monitor - %VALORANT_ENDPOINT%

rem Leave TARGET empty to use the DNS server your PC is using right now.
rem Or put an IP here, for example 8.8.8.8, to always test that DNS server instead.
set "TARGET="

rem What the PC says out loud when the connection is lost. Change it to anything you like.
set "MESSAGE=No connection"
set "FAILURES=0"
set "WARNING_SPOKEN="

if /i "%~1"=="test" goto :CM_test

call :CM_DISPLAYHEADER

set "DNS="
set "KNOWN="
set "LOG1="
set "LOG2="
set "LOG3="
set "LOG4="
set "LOG5="
if defined DNS_MONITOR_STATUS_FILE >"%DNS_MONITOR_STATUS_FILE%" echo 0^|%DNS%

:CM_loop
rem Detect the DNS server in use right now, so network or DNS changes are picked up
call :CM_getdns
set "now=%time: =0%"

if not defined DNS (
    if defined KNOWN set "DNS=%KNOWN%"
    call :CM_recordfailure
    set "ENTRY=[%now:~0,8%] NO CONNECTION - no active network or DNS server found"
    call :CM_log "%ENTRY%"
    call :CM_beep
    goto :CM_wait
)

rem Reset consecutive failures when the active DNS changes
if defined KNOWN if not "%KNOWN%"=="%DNS%" call :CM_resetfailures
rem Report a DNS change; the new server is used for this check
if defined KNOWN if not "%KNOWN%"=="%DNS%" (set "ENTRY=[%now:~0,8%] DNS server changed: %KNOWN% to %DNS%" & call :CM_log "%ENTRY%")
set "KNOWN=%DNS%"

rem Resolve the selected hostname with the active DNS server, then use TCP when enabled.
powershell -NoProfile -NonInteractive -Command "$worker={param($name,$server,$tcp,$port,$limit); try {Import-Module DnsClient -ErrorAction Stop; $r=Resolve-DnsName -Name $name -Server $server -DnsOnly -Type A -QuickTimeout -ErrorAction Stop | Where-Object {$_.IPAddress} | Select-Object -First 1} catch {return 1}; if(-not $r){return 1}; if($tcp -ne '1'){return 0}; $c=New-Object System.Net.Sockets.TcpClient; try {$a=$c.BeginConnect([string]$r.IPAddress,[int]$port,$null,$null); if(-not $a.AsyncWaitHandle.WaitOne([int]$limit)){return 2}; $c.EndConnect($a); return 0} catch {return 2} finally {$c.Close()}}; $pool=[runspacefactory]::CreateRunspacePool(2,2); $pool.Open(); $jobs=@(); for($i=0;$i -lt 2;$i++){$p=[powershell]::Create(); $p.RunspacePool=$pool; [void]$p.AddScript($worker.ToString()); [void]$p.AddArgument($env:VALORANT_ENDPOINT); [void]$p.AddArgument($env:DNS); [void]$p.AddArgument($env:CHECK_TCP); [void]$p.AddArgument($env:VALORANT_TCP_PORT); [void]$p.AddArgument($env:TCP_TIMEOUT_MS); $jobs+= [pscustomobject]@{P=$p;H=$p.BeginInvoke();Done=$false}}; $deadline=[DateTime]::UtcNow.AddMilliseconds([int]$env:DNS_CHECK_TIMEOUT_MS); $done=0; $success=$false; while(-not $success -and $done -lt 2 -and [DateTime]::UtcNow -lt $deadline){foreach($j in $jobs){if(-not $j.Done -and $j.H.IsCompleted){$j.Done=$true; $done++; try{$r=@($j.P.EndInvoke($j.H)); if($r.Count -gt 0 -and [int]$r[$r.Count-1] -eq 0){$success=$true}}catch{}; $j.P.Dispose()}}; if(-not $success){Start-Sleep -Milliseconds 25}}; if($success){foreach($j in $jobs){if(-not $j.Done){try{[void]$j.P.BeginStop($null,$null)}catch{}}}; exit 0}; if($done -eq 2){$pool.Close(); $pool.Dispose()}else{foreach($j in $jobs){if(-not $j.Done){try{[void]$j.P.BeginStop($null,$null)}catch{}}}}; exit 1" >nul 2>&1
if errorlevel 1 goto :CM_endpointfailed
call :CM_resetfailures
if "%CHECK_TCP%"=="1" (
    set "ENTRY=[%now:~0,8%] OK - %DNS% resolved %VALORANT_ENDPOINT% and TCP %VALORANT_TCP_PORT% connected"
) else (
    set "ENTRY=[%now:~0,8%] OK - %DNS% resolved %VALORANT_ENDPOINT%"
)
call :CM_log "%ENTRY%"
goto :CM_wait

:CM_endpointfailed
call :CM_recordfailure
call :CM_recordfailure
set "ENTRY=[%now:~0,8%] BOTH CHECK THREADS FAILED/TIMED OUT - %DNS% could not verify %VALORANT_ENDPOINT%"
call :CM_log "%ENTRY%"
call :CM_beep
goto :CM_wait

:CM_recordfailure
set /a FAILURES+=1
call :CM_writefailurestate
exit /b

:CM_resetfailures
set "FAILURES=0"
set "WARNING_SPOKEN="
call :CM_writefailurestate
exit /b

:CM_writefailurestate
if not defined DNS_MONITOR_STATUS_FILE exit /b
>"%DNS_MONITOR_STATUS_FILE%" echo !FAILURES!^|!DNS!
exit /b

:CM_wait
timeout /t %SCAN_INTERVAL_SECONDS% /nobreak >nul
goto :CM_loop


:CM_log
rem Keep and display only the five most recent log records.
set "LOG5=%LOG4%"
set "LOG4=%LOG3%"
set "LOG3=%LOG2%"
set "LOG2=%LOG1%"
set "LOG1=%~1"
cls
call :CM_DISPLAYHEADER
if defined LOG5 echo %LOG5%
if defined LOG4 echo %LOG4%
if defined LOG3 echo %LOG3%
if defined LOG2 echo %LOG2%
if defined LOG1 echo %LOG1%
exit /b

:CM_DISPLAYHEADER
echo ============================================================
echo  DNS endpoint monitor - checks every %SCAN_INTERVAL_SECONDS% seconds
echo  Re-detects the DNS server your PC is using on every check,
echo  Selected target: %VALORANT_ENDPOINT%
if "%CHECK_TCP%"=="1" (
    echo  Check mode: DNS resolution plus TCP handshake on port %VALORANT_TCP_PORT%
) else (
    echo  Check mode: normal DNS resolution only
)
echo  Press Ctrl+C to stop.   To try the voice: %~nx0 --connection-monitor test
echo ============================================================
echo.
exit /b

:CM_getdns
rem Uses the DNS server of the adapter that holds the default route, the one in use
set "DNS=%TARGET%"
if defined DNS exit /b
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1; if ($r) { (Get-DnsClientServerAddress -InterfaceIndex $r.InterfaceIndex -AddressFamily IPv4).ServerAddresses | Select-Object -First 1 }" 2^>nul`) do set "DNS=%%i"
exit /b


:CM_beep
rem Speak once per consecutive failure streak, asynchronously so it cannot delay failover.
if defined WARNING_SPOKEN exit /b
set "WARNING_SPOKEN=1"
start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak($env:MESSAGE)"
exit /b


:CM_test
echo Speaking: %MESSAGE%
call :CM_beep
exit /b

:PSRUNSPACEPING
# Parallel DNS ping tester for auto_combined_dns_manager_failover.bat
# Tests every DNS server concurrently with a PowerShell runspace pool.
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
$maxThreads = Get-IntSetting 'DNS_PING_THREADS' 128 1 512

if ([string]::IsNullOrWhiteSpace($inputPath)) { exit 2 }
if ([string]::IsNullOrWhiteSpace($outputPath)) { exit 2 }
if (-not (Test-Path -LiteralPath $inputPath)) { exit 3 }

$ips = New-Object System.Collections.Generic.List[string]
foreach ($line in [System.IO.File]::ReadAllLines($inputPath)) {
    $ip = $line.Trim()
    if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
        if (-not $ips.Contains($ip)) { $ips.Add($ip) }
    }
}
if ($ips.Count -eq 0) { exit 4 }
if ($maxThreads -gt $ips.Count) { $maxThreads = $ips.Count }

# One runspace job per DNS server. The first packet is a quick probe, then the
# remaining packets are sent only when the server answers, like the old loop.
$worker = {
    param(
        [string]$Ip,
        [int]$Count,
        [int]$TimeoutMs,
        [int]$ProbeMs
    )

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

    if ($received -eq 0) {
        return [pscustomobject]@{
            IP       = $Ip
            Sent     = $sent
            Received = 0
            Min      = 'N/A'
            Max      = 'N/A'
            Avg      = 'N/A'
            Loss     = '100%'
        }
    }

    $lossPercent = [int][math]::Round((($sent - $received) * 100.0) / $sent)
    return [pscustomobject]@{
        IP       = $Ip
        Sent     = $sent
        Received = $received
        Min      = [int][math]::Round($min)
        Max      = [int][math]::Round($max)
        Avg      = [int][math]::Round($total / $received)
        Loss     = ('{0}%' -f $lossPercent)
    }
}

$workerScript = $worker.ToString()

$pool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
$pool.Open()

$writer = [System.IO.StreamWriter]::new($outputPath, $false, [System.Text.Encoding]::ASCII)
try {
    # Keep at most one worker's worth of PowerShell pipelines in memory.
    for ($batchStart = 0; $batchStart -lt $ips.Count; $batchStart += $maxThreads) {
        $batchEnd = [Math]::Min($batchStart + $maxThreads, $ips.Count) - 1
        $jobs = New-Object System.Collections.Generic.List[object]

        for ($index = $batchStart; $index -le $batchEnd; $index++) {
            $ip = $ips[$index]
            $shell = [powershell]::Create()
            $shell.RunspacePool = $pool
            [void]$shell.AddScript($workerScript)
            [void]$shell.AddArgument($ip)
            [void]$shell.AddArgument($pingCount)
            [void]$shell.AddArgument($timeoutMs)
            [void]$shell.AddArgument($probeMs)
            $jobs.Add([pscustomobject]@{
                IP     = $ip
                Shell  = $shell
                Handle = $shell.BeginInvoke()
            })
        }

        # Collect this batch in input order, then release its pipeline objects.
        foreach ($job in $jobs) {
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
                }
            }
            $writer.WriteLine(('{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $result.IP, $result.Received, $result.Min, $result.Max, $result.Avg, $result.Loss, $result.Sent))
            $job.Shell.Dispose()
        }
        $writer.Flush()
    }
} finally {
    $writer.Dispose()
    $pool.Close()
    $pool.Dispose()
}
exit 0
