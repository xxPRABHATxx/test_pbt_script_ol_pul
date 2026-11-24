@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Windows Terminal Hacker-Vibes Demo
color 0A

:MENU
cls
echo ============================================================
echo            WINDOWS TERMINAL HACKER-VIBES DEMO
echo ============================================================
echo This runs ordinary local diagnostics and cosmetic demos.
echo WSL effects run directly and do not install or configure WSL.
echo.
echo [1] Run the full sequence
echo [2] Recursive file listing (dir /s)
echo [3] Ping demo (12 requests)
echo [4] Continuous ping (Ctrl+C to stop)
echo [5] Matrix effect (cmatrix, WSL)
echo [6] Fake activity (safe built-in demo)
echo [7] Hollywood terminal effect (WSL)
echo [0] Exit
echo.
choice /c 12345670 /n /m "Select an option: "
if errorlevel 8 goto EXIT
if errorlevel 7 goto HOLLYWOOD_MENU
if errorlevel 6 goto FAKE_ACTIVITY
if errorlevel 5 goto CMATRIX_MENU
if errorlevel 4 goto PING_CONTINUOUS
if errorlevel 3 goto PING_ONCE
if errorlevel 2 goto DIR_LIST
if errorlevel 1 goto FULL
goto MENU

:FULL
call :DoDirList
echo.
pause
call :DoPingOnce
echo.
pause
call :DoCmatrix
echo.
pause
call :DoFakeActivity
echo.
pause
call :DoHollywood
echo.
pause
goto MENU

:DIR_LIST
call :DoDirList
goto AFTER_ONE

:PING_ONCE
call :DoPingOnce
goto AFTER_ONE

:PING_CONTINUOUS
call :DoPingContinuous
goto AFTER_ONE

:CMATRIX
call :DoCmatrix
goto AFTER_ONE

:FAKE_ACTIVITY
call :DoFakeActivity
goto AFTER_ONE

:HOLLYWOOD
call :DoHollywood
goto AFTER_ONE

:AFTER_ONE
echo.
pause
goto MENU

:CMATRIX_MENU
cls
echo MATRIX EFFECT - CMATRIX
echo.
echo Normal CMD command: wsl -e cmatrix
echo These actions use the current default WSL distribution only.
echo They do not check for or install WSL or Ubuntu.
echo.
echo [1] Install cmatrix and run it
echo [2] Run cmatrix
echo [3] Uninstall cmatrix
echo [0] Back
choice /c 1230 /n /m "Select an option: "
if errorlevel 4 goto MENU
if errorlevel 3 goto CMATRIX_UNINSTALL
if errorlevel 2 goto CMATRIX_RUN
if errorlevel 1 goto CMATRIX_INSTALL
goto CMATRIX_MENU

:CMATRIX_INSTALL
echo.
echo Installing cmatrix, then starting the effect...
wsl.exe -e bash -lc "sudo apt-get update && sudo apt-get install -y cmatrix && exec cmatrix"
echo.
pause
goto CMATRIX_MENU

:CMATRIX_RUN
echo.
wsl.exe -e cmatrix
echo.
pause
goto CMATRIX_MENU

:CMATRIX_UNINSTALL
echo.
wsl.exe -e bash -lc "sudo apt-get remove -y cmatrix"
echo.
pause
goto CMATRIX_MENU

:HOLLYWOOD_MENU
cls
echo HOLLYWOOD TERMINAL EFFECT
echo.
echo Normal CMD command: wsl -e hollywood
echo These actions use the current default WSL distribution only.
echo They do not check for or install WSL or Ubuntu.
echo.
echo [1] Install hollywood and run it
echo [2] Run hollywood
echo [3] Uninstall hollywood
echo [0] Back
choice /c 1230 /n /m "Select an option: "
if errorlevel 4 goto MENU
if errorlevel 3 goto HOLLYWOOD_UNINSTALL
if errorlevel 2 goto HOLLYWOOD_RUN
if errorlevel 1 goto HOLLYWOOD_INSTALL
goto HOLLYWOOD_MENU

:HOLLYWOOD_INSTALL
echo.
echo Installing hollywood, then starting the effect...
wsl.exe -e bash -lc "sudo apt-get update && sudo apt-get install -y hollywood && exec hollywood"
echo.
pause
goto HOLLYWOOD_MENU

:HOLLYWOOD_RUN
echo.
wsl.exe -e hollywood
echo.
pause
goto HOLLYWOOD_MENU

:HOLLYWOOD_UNINSTALL
echo.
wsl.exe -e bash -lc "sudo apt-get remove -y hollywood"
echo.
pause
goto HOLLYWOOD_MENU

:DoDirList
cls
echo RECURSIVE FILE LISTING
echo.
echo This lists files and folders under one directory. It can produce
echo a lot of output; choose a folder you are comfortable displaying.
set "SCANPATH="
set /p "SCANPATH=Folder path (Enter uses this BAT file's folder): "
if not defined SCANPATH set "SCANPATH=%~dp0"
if not exist "%SCANPATH%\." (
    echo.
    echo That folder was not found. Enter a path without surrounding quotes.
    exit /b
)
echo.
echo Listing: "%SCANPATH%"
choice /c YN /n /m "Start the recursive listing? [Y/N] "
if errorlevel 2 exit /b
dir /s /b "%SCANPATH%" 2>nul
exit /b

:DoPingOnce
cls
echo PING DEMO - 12 REQUESTS
echo.
call :ReadPingTarget
echo Press Ctrl+C to cancel if needed.
ping -n 12 "%PINGTARGET%"
exit /b

:DoPingContinuous
cls
echo CONTINUOUS PING
echo.
call :ReadPingTarget
echo Press Ctrl+C to stop. If CMD asks whether to terminate this batch,
echo answer N to return to the menu.
ping -t "%PINGTARGET%"
exit /b

:ReadPingTarget
set "PINGTARGET="
set /p "PINGTARGET=Host or IP [www.google.com]: "
if not defined PINGTARGET set "PINGTARGET=www.google.com"
exit /b

:DoCmatrix
cls
echo MATRIX EFFECT - CMATRIX
echo.
echo Running directly through the default WSL distribution.
wsl.exe -e cmatrix
exit /b

:DoFakeActivity
cls
echo SAFE FAKE ACTIVITY DEMO
echo.
echo Display-only simulation. It does not run commands or change files.
echo.
setlocal EnableDelayedExpansion
for /L %%i in (1,1,12) do (
    set /a "TASK=!random! %% 900 + 100"
    set /a "HASH=!random! %% 900000 + 100000"
    echo [SIMULATED] worker-!TASK! completed chunk %%i of 12 - hash !HASH!
    timeout /t 1 /nobreak >nul
)
endlocal
exit /b 0

:DoHollywood
cls
echo HOLLYWOOD TERMINAL EFFECT
echo.
echo Running directly through the default WSL distribution.
wsl.exe -e hollywood
exit /b

:EXIT
color 07
echo.
echo Demo finished.
endlocal
exit /b
