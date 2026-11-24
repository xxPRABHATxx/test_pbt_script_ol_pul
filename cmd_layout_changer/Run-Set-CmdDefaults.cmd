@echo off
setlocal

set "script=%~dp0Set-CmdDefaults.ps1"
if not exist "%script%" (
    echo [FAILED] Could not find the required PowerShell script:
    echo "%script%"
    pause
    exit /b 1
)

cls
echo [92m                coded by[0m
echo [31m  _____           _     _           _[0m
echo [31m ^|  __ \         ^| ^|   ^| ^|         ^| ^|[0m
echo [31m ^| ^|__) ^| __ __ _^| ^|__ ^| ^|__   __ _^| ^|_ [0m
echo [31m ^|  ___/ '__/ _` ^| '_ \^| '_ \ / _` ^| __^|[0m
echo [31m ^| ^|   ^| ^| ^| (_^| ^| ^|_) ^| ^| ^| ^| (_^| ^| ^|_ [0m
echo [31m ^|_^|   ^|_^|  \__,_^|_.__/^|_^| ^|_^|\__,_^|\__^|[0m
echo [31m========================================[0m
echo [92m        Created: 22 november 2026[0m
echo +----------------------------------------------+
echo ^|          CMD WINDOW STYLE SETUP              ^|
echo +----------------------------------------------+
echo ^| Apply a layout or restore Windows defaults.  ^|
echo +----------------------------------------------+
set "setupStart="
set /p "setupStart=Press ENTER to open the menu: "

:menu
echo.
echo Command Prompt defaults
echo 1. Apply Style 1
echo 2. Apply Style 2 - three CMD positions
echo 3. Restore Style 0 - Windows default CMD
echo 0. Exit
choice /c 1230 /n /m "Select an option: "
if errorlevel 4 exit /b 0
if errorlevel 3 goto windows_default
if errorlevel 2 goto apply_style2
if errorlevel 1 goto apply_style1
goto menu

:apply_style1
echo.
call :show_style1
echo.
set "confirm="
set /p "confirm=Press ENTER to apply Style 1, or type anything to cancel: "
if defined confirm goto menu
echo.
echo Applying Style 1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Style Style1
if errorlevel 1 (
    echo [FAILED] Style 1 could not be applied.
) else (
    echo [SUCCESS] Style 1 was applied. Close and reopen CMD windows.
)
echo.
pause
goto menu

:apply_style2
call :show_style2
echo.
set "confirm="
set /p "confirm=Press ENTER to apply Style 2, or type anything to cancel: "
if defined confirm goto menu
echo.
echo Applying Style 2...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -Style Style2
if errorlevel 1 (
    echo [FAILED] Style 2 could not be applied.
) else (
    echo [SUCCESS] Style 2 was applied. Close and reopen CMD windows.
)
echo.
pause
goto menu

:windows_default
echo.
echo Restoring the original Windows console defaults and removing custom CMD styles...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" -RestoreWindowsDefault
if errorlevel 1 (
    echo [FAILED] Could not restore Windows default CMD style.
) else (
    echo [SUCCESS] Windows CMD defaults restored. Close this setup window, then reopen CMD.
)
echo.
pause
goto menu

:show_style1
cls
echo(+------------------------------------------------------------------------------------------+
echo(^|  o    +--------------------------------------------------+ +----------------------------+^|
echo(^|       ^|--------------------------------------------------^| ^|----------------------------^|^|
echo(^|  o    ^|                                                  ^| ^|                            ^|^|
echo(^|       ^|^>                                                 ^| ^|^>_                          ^|^|
for /l %%i in (1,1,18) do echo(^|       ^|                                                  ^| ^|                            ^|^|
echo(^|  o    ^|                                                  ^| ^|                            ^|^|
echo(^|       +--------------------------------------------------+ +----------------------------+^|
echo(^| [ ] [ ] [ ] [ ]                                             [ ] [ ]              [time] ^|
echo(+------------------------------------------------------------------------------------------+
exit /b 0

:show_style2
cls
echo(+--------------------------------------------------------------------------------------------------+
echo(^|  o     +---------------------------+ +---------------------------+ +----------------------------+^|
echo(^|        ^|---------------------------^| ^|---------------------------^| ^|----------------------------^|^|
echo(^|  o     ^|                           ^| ^|                           ^| ^|                            ^|^|
echo(^|        ^|^>                          ^| ^|^>                          ^| ^|^>                           ^|^|
for /l %%i in (1,1,18) do echo(^|        ^|                           ^| ^|                           ^| ^|                            ^|^|
echo(^|  o     ^|                           ^| ^|                           ^| ^|                            ^|^|
echo(^|        +---------------------------+ +---------------------------+ +----------------------------+^|
echo(^| [ ] [ ] [ ] [ ]                                                   [ ] [ ]              [time] ^|
echo(+--------------------------------------------------------------------------------------------------+
exit /b 0
