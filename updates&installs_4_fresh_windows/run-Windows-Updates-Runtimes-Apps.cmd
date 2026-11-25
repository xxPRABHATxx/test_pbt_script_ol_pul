@echo off
rem NOTE: keep this file saved with Windows CRLF line endings. Unix LF endings make cmd.exe lose GOTO and CALL labels.
setlocal EnableExtensions

rem ======================================================================
rem SETTINGS - change the value below in a text editor, save, then run the script.
rem   ADD_REMOVE   on  = the main menu shows Option 5, Add or remove an app in a category.
rem                off = Option 5 is hidden and cannot be used.
rem   Anything other than on counts as off. Keep the quotes exactly as they are.
rem   Apps you already added stay in their category menus either way.
rem ======================================================================
set "ADD_REMOVE=off"

title Fresh Windows setup - Options 1 to 5
if /I not "%ADD_REMOVE%"=="on" title Fresh Windows setup - Options 1 to 4

set "SELF=%~f0"
set "SELF_DIR=%~dp0"
for %%I in ("%SELF%") do set "FWS_RUN=call %%I --app-worker & timeout /t 30"
set "BUILTIN_DAILY=Google.Chrome Mozilla.Firefox VideoLAN.VLC 7zip.7zip Notepad++.Notepad++ TheDocumentFoundation.LibreOffice SumatraPDF.SumatraPDF"
set "BUILTIN_DEV=Microsoft.VisualStudioCode Microsoft.VisualStudio.Community Git.Git Python.Python.3.14 OpenJS.NodeJS.LTS Microsoft.DotNet.SDK.10 EclipseAdoptium.Temurin.25.JDK Docker.DockerDesktop"
set "BUILTIN_SECURITY=WiresharkFoundation.Wireshark ZAP.ZAP Microsoft.Sysinternals.Suite Insecure.Nmap"

if /I "%~1"=="--app-worker" goto app_worker
if /I "%~1"=="--option1" goto option1_run
if exist "%SELF_DIR%Custom-Apps.txt" call :custom_migrate
goto main_menu

:app_worker
rem The launcher passes the task in FWS_ACTION, FWS_ID, FWS_NAME and FWS_TYPE. Old style arguments still work.
if not defined FWS_ACTION set "FWS_ACTION=%~2"
if not defined FWS_ID set "FWS_ID=%~3"
if not defined FWS_NAME set "FWS_NAME=%~4"
title %FWS_NAME% - %FWS_ACTION%
mode con: cols=100 lines=30 >nul 2>&1
if exist "%SELF_DIR%Position-AppWorkerWindow.ps1" start "" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SELF_DIR%Position-AppWorkerWindow.ps1" >nul 2>&1
set "HAS_ERRORS=0"
echo Starting %FWS_ACTION% for %FWS_NAME%...
if not defined FWS_ID (
    echo No app was selected for this task.
    set "HAS_ERRORS=1"
    goto app_worker_finish
)
if /I "%FWS_TYPE%"=="url" goto app_worker_url
call :winget_ready
if errorlevel 1 goto app_worker_finish
if /I "%FWS_ACTION%"=="install" call :install_package "%FWS_ID%" "%FWS_NAME%"
if /I "%FWS_ACTION%"=="update" call :update_package "%FWS_ID%" "%FWS_NAME%"
if /I "%FWS_ACTION%"=="uninstall" call :uninstall_package "%FWS_ID%" "%FWS_NAME%"
goto app_worker_finish

:app_worker_url
if /I "%FWS_ACTION%"=="install" call :install_custom_url "%FWS_ID%" "%FWS_NAME%"
if /I "%FWS_ACTION%"=="update" call :update_custom_url "%FWS_ID%" "%FWS_NAME%"
if /I "%FWS_ACTION%"=="uninstall" call :uninstall_custom_url "%FWS_ID%" "%FWS_NAME%"

:app_worker_finish
echo.
if "%HAS_ERRORS%"=="1" (
    echo The app task reported an error. Review the messages above.
    echo This window closes by itself and returns to the main menu. Press any key to close it now.
    timeout /t 30
    exit 1
)
echo The app task completed.
echo Closing this window in 3 seconds.
timeout /t 3 /nobreak >nul
exit 0

:main_menu
cls
echo ============================================================
echo Fresh Windows setup
echo ============================================================
echo.
echo 1. Windows Update and common runtimes
echo 2. Everyday apps
echo 3. IDEs and development tools
echo 4. Security and network analysis tools
if /I "%ADD_REMOVE%"=="on" echo 5. Add or remove an app in a category
echo 0. Exit
echo.
set "MENU_KEYS=12340"
if /I "%ADD_REMOVE%"=="on" set "MENU_KEYS=123450"
choice /C %MENU_KEYS% /N /M "Choose an option: "
if /I not "%ADD_REMOVE%"=="on" if errorlevel 5 goto exit_script
if errorlevel 6 goto exit_script
if errorlevel 5 goto app_manage_menu
if errorlevel 4 goto security_menu
if errorlevel 3 goto dev_menu
if errorlevel 2 goto daily_menu
if errorlevel 1 call :option1_run
goto main_menu

:exit_script
exit /b 0

:option1_run
fltmc >nul 2>&1
if errorlevel 1 (
    echo.
    echo Administrator permission is required. Approve the Windows prompt.
    set "SCRIPT_PATH=%SELF%"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:SCRIPT_PATH -ArgumentList '--option1' -Verb RunAs"
    exit /b
)

set "HAS_ERRORS=0"
set "NEED_RESTART=0"
set "NATIVE_ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "NATIVE_ARCH=%PROCESSOR_ARCHITEW6432%"
set "DOTNET_ARCHES=x86"
set "VC_ARCHES=x86"
if /I "%NATIVE_ARCH%"=="AMD64" (
    set "DOTNET_ARCHES=x64 x86"
    set "VC_ARCHES=x64 x86"
)
if /I "%NATIVE_ARCH%"=="ARM64" (
    set "DOTNET_ARCHES=arm64 x64 x86"
    set "VC_ARCHES=x64 x86"
)
set "RUN_ID=%RANDOM%-%RANDOM%"
set "WORKDIR=%TEMP%\FreshWindowsOption1-%RUN_ID%"
if exist "%WORKDIR%\." (
    echo Temporary setup folder already exists. Close this window and run the script again.
    set "HAS_ERRORS=1"
    goto finish
)
mkdir "%WORKDIR%" >nul 2>&1
if errorlevel 1 (
    echo Could not create a temporary setup folder.
    set "HAS_ERRORS=1"
    goto finish
)

echo.
echo This option installs updates and common application runtimes.
echo It needs an internet connection. Windows may require a restart.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if ((Get-CimInstance Win32_OperatingSystem).ProductType -ne 1) { exit 1 }; if ([int](Get-CimInstance Win32_OperatingSystem).BuildNumber -lt 10240) { exit 1 }"
if errorlevel 1 (
    echo This script supports Windows 10 and Windows 11 desktop editions.
    set "HAS_ERRORS=1"
    goto finish
)

echo [1/6] Searching, downloading, and installing Windows updates...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $session=New-Object -ComObject Microsoft.Update.Session; $searcher=$session.CreateUpdateSearcher(); for($pass=1;$pass -le 5;$pass++){ Write-Host ('Windows Update scan '+$pass+' of 5'); $result=$searcher.Search('IsInstalled=0 and IsHidden=0'); $updates=New-Object -ComObject Microsoft.Update.UpdateColl; foreach($update in $result.Updates){ if(!$update.EulaAccepted){ $update.AcceptEula() }; [void]$updates.Add($update) }; if($updates.Count -eq 0){ Write-Host 'No more applicable updates found.'; exit 0 }; Write-Host ('Downloading '+$updates.Count+' update(s)...'); $downloader=$session.CreateUpdateDownloader(); $downloader.Updates=$updates; $downloadResult=$downloader.Download(); if($downloadResult.ResultCode -ge 4){ throw ('Download failed with result code '+$downloadResult.ResultCode) }; Write-Host 'Installing updates...'; $installer=$session.CreateUpdateInstaller(); $installer.Updates=$updates; $installResult=$installer.Install(); Write-Host ('Install result code: '+$installResult.ResultCode); if($installResult.RebootRequired){ Write-Host 'A restart is required before more updates can be applied.'; exit 3010 }; if($installResult.ResultCode -ge 4){ exit 1 } }; Write-Host 'Five update scans completed. Run this option again after restarting to check for remaining updates.'; exit 0 } catch { Write-Error $_; exit 1 }"
set "WU_EXIT=%ERRORLEVEL%"
if "%WU_EXIT%"=="3010" set "NEED_RESTART=1"
if not "%WU_EXIT%"=="0" if not "%WU_EXIT%"=="3010" (
    echo Windows Update reported an error. You can retry from Windows Settings.
    set "HAS_ERRORS=1"
)

echo.
echo [2/6] Installing Microsoft Visual C++ runtimes...
for %%A in (%VC_ARCHES%) do call :install_vc2005 %%A
for %%A in (%VC_ARCHES%) do call :install_vc14 %%A
for %%A in (%VC_ARCHES%) do call :install_vc2013 %%A
for %%A in (%VC_ARCHES%) do call :install_vc2012 %%A
for %%A in (%VC_ARCHES%) do call :install_vc2010 %%A
for %%A in (%VC_ARCHES%) do call :install_vc2008 %%A

echo.
echo [3/6] Installing .NET Desktop Runtime 10 and 11...
for %%A in (%DOTNET_ARCHES%) do call :install_dotnet 10.0 %%A
for %%A in (%DOTNET_ARCHES%) do call :install_dotnet 11.0 %%A

echo.
echo [4/6] Installing .NET Framework 4.8.1 and enabling 3.5...
if /I not "%NATIVE_ARCH%"=="ARM64" call :install_exe "https://download.microsoft.com/download/4/b/2/cd00d4ed-ebdd-49ee-8a33-eabc3d1030e3/NDP481-x86-x64-AllOS-ENU.exe" "ndp481.exe" "/q /norestart" ".NET Framework 4.8.1"
set "WINDOWS_BUILD=0"
for /f "tokens=3" %%B in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do set "WINDOWS_BUILD=%%B"
if %WINDOWS_BUILD% GEQ 28000 (
    call :install_exe "https://go.microsoft.com/fwlink/?LinkID=2337635" "DotNet35Setup.exe" "/quiet /norestart" ".NET Framework 3.5"
) else (
    dism.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart
    set "DISM_EXIT=%ERRORLEVEL%"
    if "%DISM_EXIT%"=="3010" set "NEED_RESTART=1"
    if not "%DISM_EXIT%"=="0" if not "%DISM_EXIT%"=="3010" (
        echo .NET Framework 3.5 could not be enabled.
        set "HAS_ERRORS=1"
    )
)

echo.
echo [5/6] Installing legacy DirectX and OpenAL components...
call :install_directx
call :install_openal

echo.
echo [6/6] Upgrading installed applications with Winget...
where winget.exe >nul 2>&1
if errorlevel 1 (
    echo Winget is not available. Opening the Microsoft Store App Installer page.
    start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    echo Install or update App Installer, then run this option again for app upgrades.
    set "HAS_ERRORS=1"
) else (
    winget source update
    if errorlevel 1 set "HAS_ERRORS=1"
    winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
    set "WINGET_EXIT=%ERRORLEVEL%"
    if not "%WINGET_EXIT%"=="0" (
        echo Winget reported one or more packages could not be upgraded.
        set "HAS_ERRORS=1"
    )
)

:finish
echo.
echo OpenGL, Vulkan, and OpenCL support comes from the graphics driver.
echo Windows Update may install a driver; for the newest driver, use your PC or GPU maker's official support page.
echo.
echo Windows Update can offer more updates after a restart. Run Option 1 again until it reports no remaining updates.
echo Winget upgrades only apps that are already installed and that its configured sources can identify.
echo Windows Update Agent installs may not appear in the Settings update history.
echo The Visual C++ 2005-2013 and DirectX June 2010 packages are legacy compatibility runtimes.
echo.
if "%NEED_RESTART%"=="1" (
    echo A restart is required. Save your work, restart Windows, then run Option 1 again.
)
if "%HAS_ERRORS%"=="1" (
    echo One or more steps reported an error. Review the messages above and retry the affected step.
) else (
    echo The selected setup steps completed.
)
echo.
pause
exit /b 0

:install_vc14
if /I "%~1"=="x64" set "VC_URL=https://aka.ms/vc14/vc_redist.x64.exe"
if /I "%~1"=="x86" set "VC_URL=https://aka.ms/vc14/vc_redist.x86.exe"
call :install_exe "%VC_URL%" "vc14-%~1.exe" "/install /quiet /norestart" "Visual C++ v14 %~1"
exit /b

:install_vc2005
if /I "%~1"=="x86" set "VC_URL=https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.exe"
if /I "%~1"=="x64" set "VC_URL=https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.exe"
call :install_exe "%VC_URL%" "vc2005-%~1.exe" "/q" "Visual C++ 2005 %~1"
exit /b

:install_vc2013
call :install_exe "https://aka.ms/highdpimfc2013%~1enu" "vc2013-%~1.exe" "/install /quiet /norestart" "Visual C++ 2013 %~1"
exit /b

:install_vc2012
if /I "%~1"=="x86" set "VC_URL=https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe"
if /I "%~1"=="x64" set "VC_URL=https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
call :install_exe "%VC_URL%" "vc2012-%~1.exe" "/quiet /norestart" "Visual C++ 2012 %~1"
exit /b

:install_vc2010
if /I "%~1"=="x86" set "VC_URL=https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe"
if /I "%~1"=="x64" set "VC_URL=https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe"
call :install_exe "%VC_URL%" "vc2010-%~1.exe" "/q /norestart" "Visual C++ 2010 %~1"
exit /b

:install_vc2008
if /I "%~1"=="x86" set "VC_URL=https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe"
if /I "%~1"=="x64" set "VC_URL=https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe"
call :install_exe "%VC_URL%" "vc2008-%~1.exe" "/q" "Visual C++ 2008 %~1"
exit /b

:install_dotnet
call :install_exe "https://aka.ms/dotnet/%~1/windowsdesktop-runtime-win-%~2.exe" "dotnet-%~1-%~2.exe" "/install /quiet /norestart" ".NET Desktop Runtime %~1 %~2"
exit /b

:install_directx
call :download_file "https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe" "%WORKDIR%\directx_Jun2010_redist.exe"
if errorlevel 1 (
    set "HAS_ERRORS=1"
    exit /b 1
)
mkdir "%WORKDIR%\DirectX" >nul 2>&1
echo Extracting DirectX June 2010 legacy components...
start /wait "" "%WORKDIR%\directx_Jun2010_redist.exe" /Q /T:"%WORKDIR%\DirectX"
if not exist "%WORKDIR%\DirectX\DXSETUP.exe" (
    echo DirectX archive extraction failed.
    set "HAS_ERRORS=1"
    exit /b 1
)
start /wait "" "%WORKDIR%\DirectX\DXSETUP.exe" /silent
set "INSTALL_EXIT=%ERRORLEVEL%"
if "%INSTALL_EXIT%"=="3010" set "NEED_RESTART=1"
if not "%INSTALL_EXIT%"=="0" if not "%INSTALL_EXIT%"=="3010" (
    echo DirectX setup returned exit code %INSTALL_EXIT%.
    set "HAS_ERRORS=1"
)
del /q "%WORKDIR%\directx_Jun2010_redist.exe" >nul 2>&1
rmdir /s /q "%WORKDIR%\DirectX" >nul 2>&1
exit /b

:install_openal
call :download_file "https://www.openal.org/downloads/oalinst.zip" "%WORKDIR%\oalinst.zip"
if errorlevel 1 (
    set "HAS_ERRORS=1"
    exit /b 1
)
mkdir "%WORKDIR%\OpenAL" >nul 2>&1
set "OPENAL_DIR=%WORKDIR%\OpenAL"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { Expand-Archive -LiteralPath $env:SETUP_FILE -DestinationPath $env:OPENAL_DIR -Force; exit 0 } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
    echo OpenAL archive extraction failed.
    set "HAS_ERRORS=1"
    exit /b 1
)
if not exist "%WORKDIR%\OpenAL\oalinst.exe" (
    echo OpenAL installer was not found in the downloaded archive.
    set "HAS_ERRORS=1"
    exit /b 1
)
echo Installing OpenAL 1.1 compatibility runtime...
start /wait "" "%WORKDIR%\OpenAL\oalinst.exe" /SILENT
set "INSTALL_EXIT=%ERRORLEVEL%"
if "%INSTALL_EXIT%"=="3010" set "NEED_RESTART=1"
if not "%INSTALL_EXIT%"=="0" if not "%INSTALL_EXIT%"=="3010" (
    echo OpenAL setup returned exit code %INSTALL_EXIT%.
    set "HAS_ERRORS=1"
)
del /q "%WORKDIR%\oalinst.zip" >nul 2>&1
rmdir /s /q "%WORKDIR%\OpenAL" >nul 2>&1
exit /b

:install_exe
echo Installing %~4...
call :download_file "%~1" "%WORKDIR%\%~2"
if errorlevel 1 (
    echo Download failed: %~4
    set "HAS_ERRORS=1"
    exit /b 1
)
start /wait "" "%WORKDIR%\%~2" %~3
set "INSTALL_EXIT=%ERRORLEVEL%"
if "%INSTALL_EXIT%"=="3010" set "NEED_RESTART=1"
if not "%INSTALL_EXIT%"=="0" if not "%INSTALL_EXIT%"=="3010" if not "%INSTALL_EXIT%"=="1638" (
    echo %~4 setup returned exit code %INSTALL_EXIT%.
    set "HAS_ERRORS=1"
)
del /q "%WORKDIR%\%~2" >nul 2>&1
exit /b

:download_file
set "SETUP_URL=%~1"
set "SETUP_FILE=%~2"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -UseBasicParsing -Uri $env:SETUP_URL -OutFile $env:SETUP_FILE; exit 0 } catch { Write-Error $_; exit 1 }"
exit /b %ERRORLEVEL%

:daily_menu
call :custom_load daily
cls
echo ============================================================
echo Option 2 - Everyday apps
echo ============================================================
echo Apps: Chrome, Firefox, VLC, 7-Zip, Notepad++, LibreOffice, SumatraPDF
if defined CUSTOM_NAMES echo Added by you: %CUSTOM_NAMES%
echo 1. Install all listed apps
echo 2. Uninstall all listed apps
echo 3. Choose one app - install, update, or uninstall
echo 0. Back
echo.
choice /C 1230 /N /M "Choose an option: "
if errorlevel 4 goto main_menu
if errorlevel 3 goto daily_individual
if errorlevel 2 goto daily_uninstall_all
if errorlevel 1 goto daily_install_all

:daily_install_all
set "DAILY_IDS=Google.Chrome Mozilla.Firefox VideoLAN.VLC 7zip.7zip Notepad++.Notepad++ TheDocumentFoundation.LibreOffice SumatraPDF.SumatraPDF"
call :run_app_list install "%DAILY_IDS%" daily
goto daily_menu

:daily_uninstall_all
set "DAILY_IDS=Google.Chrome Mozilla.Firefox VideoLAN.VLC 7zip.7zip Notepad++.Notepad++ TheDocumentFoundation.LibreOffice SumatraPDF.SumatraPDF"
call :run_app_list uninstall "%DAILY_IDS%" daily
goto daily_menu

:daily_individual
call :custom_load daily
cls
echo Option 2 - Choose an everyday app
echo 1. Google Chrome
echo 2. Mozilla Firefox
echo 3. VLC media player
echo 4. 7-Zip
echo 5. Notepad++
echo 6. LibreOffice
echo 7. SumatraPDF
call :custom_print 7
echo 0. Back
echo.
set /a PICK_MAX=7+CUSTOM_COUNT
call :ask_number "Type the number of the app and press Enter: " %PICK_MAX%
if "%PICK%"=="0" goto daily_menu
if %PICK% GTR 7 goto daily_custom_pick
if %PICK% EQU 7 goto daily_app7
if %PICK% EQU 6 goto daily_app6
if %PICK% EQU 5 goto daily_app5
if %PICK% EQU 4 goto daily_app4
if %PICK% EQU 3 goto daily_app3
if %PICK% EQU 2 goto daily_app2
if %PICK% EQU 1 goto daily_app1
goto daily_individual

:daily_custom_pick
set /a CUSTOM_PICK=PICK-7
call :custom_open %CUSTOM_PICK%
goto daily_individual

:daily_app1
call :single_app_menu "Google.Chrome" "Google Chrome"
goto daily_individual
:daily_app2
call :single_app_menu "Mozilla.Firefox" "Mozilla Firefox"
goto daily_individual
:daily_app3
call :single_app_menu "VideoLAN.VLC" "VLC media player"
goto daily_individual
:daily_app4
call :single_app_menu "7zip.7zip" "7-Zip"
goto daily_individual
:daily_app5
call :single_app_menu "Notepad++.Notepad++" "Notepad++"
goto daily_individual
:daily_app6
call :single_app_menu "TheDocumentFoundation.LibreOffice" "LibreOffice"
goto daily_individual
:daily_app7
call :single_app_menu "SumatraPDF.SumatraPDF" "SumatraPDF"
goto daily_individual

:dev_menu
call :custom_load dev
cls
echo ============================================================
echo Option 3 - IDEs and development tools
echo ============================================================
echo Apps: VS Code, Visual Studio Community, Git, Python, Node.js, .NET SDK 10,
echo       Temurin JDK, Docker Desktop
if defined CUSTOM_NAMES echo Added by you: %CUSTOM_NAMES%
echo Install all includes Visual Studio Community with the C++ desktop workload
echo and Docker Desktop. These can take a while and use several GB of disk space.
echo.
echo 1. Install all listed tools
echo 2. Uninstall all listed tools
echo 3. Choose one tool - install, update, or uninstall
echo 0. Back
echo.
choice /C 1230 /N /M "Choose an option: "
if errorlevel 4 goto main_menu
if errorlevel 3 goto dev_individual
if errorlevel 2 goto dev_uninstall_all
if errorlevel 1 goto dev_install_all

:dev_install_all
set "DEV_IDS=Microsoft.VisualStudioCode Microsoft.VisualStudio.Community Git.Git Python.Python.3.14 OpenJS.NodeJS.LTS Microsoft.DotNet.SDK.10 EclipseAdoptium.Temurin.25.JDK Docker.DockerDesktop"
call :run_app_list install "%DEV_IDS%" dev
goto dev_menu

:dev_uninstall_all
set "DEV_IDS=Docker.DockerDesktop EclipseAdoptium.Temurin.25.JDK Microsoft.DotNet.SDK.10 OpenJS.NodeJS.LTS Python.Python.3.14 Git.Git Microsoft.VisualStudio.Community Microsoft.VisualStudioCode"
call :run_app_list uninstall "%DEV_IDS%" dev
goto dev_menu

:dev_individual
call :custom_load dev
cls
echo Option 3 - Choose a development tool
echo 1. Visual Studio Code
echo 2. Visual Studio Community with C++ desktop workload
echo 3. Git
echo 4. Python 3.14
echo 5. Node.js LTS
echo 6. .NET SDK 10 LTS
echo 7. Eclipse Temurin JDK 25
echo 8. Docker Desktop
call :custom_print 8
echo 0. Back
echo.
set /a PICK_MAX=8+CUSTOM_COUNT
call :ask_number "Type the number of the tool and press Enter: " %PICK_MAX%
if "%PICK%"=="0" goto dev_menu
if %PICK% GTR 8 goto dev_custom_pick
if %PICK% EQU 8 goto dev_app8
if %PICK% EQU 7 goto dev_app7
if %PICK% EQU 6 goto dev_app6
if %PICK% EQU 5 goto dev_app5
if %PICK% EQU 4 goto dev_app4
if %PICK% EQU 3 goto dev_app3
if %PICK% EQU 2 goto dev_app2
if %PICK% EQU 1 goto dev_app1
goto dev_individual

:dev_custom_pick
set /a CUSTOM_PICK=PICK-8
call :custom_open %CUSTOM_PICK%
goto dev_individual

:dev_app1
call :single_app_menu "Microsoft.VisualStudioCode" "Visual Studio Code"
goto dev_individual
:dev_app2
call :single_app_menu "Microsoft.VisualStudio.Community" "Visual Studio Community with C++ desktop workload"
goto dev_individual
:dev_app3
call :single_app_menu "Git.Git" "Git"
goto dev_individual
:dev_app4
call :single_app_menu "Python.Python.3.14" "Python 3.14"
goto dev_individual
:dev_app5
call :single_app_menu "OpenJS.NodeJS.LTS" "Node.js LTS"
goto dev_individual
:dev_app6
call :single_app_menu "Microsoft.DotNet.SDK.10" ".NET SDK 10 LTS"
goto dev_individual
:dev_app7
call :single_app_menu "EclipseAdoptium.Temurin.25.JDK" "Eclipse Temurin JDK 25"
goto dev_individual
:dev_app8
call :single_app_menu "Docker.DockerDesktop" "Docker Desktop"
goto dev_individual

:security_menu
call :custom_load security
cls
echo ============================================================
echo Option 4 - Security and network analysis
echo ============================================================
echo Apps: Wireshark, OWASP ZAP, Sysinternals Suite, Nmap
if defined CUSTOM_NAMES echo Added by you: %CUSTOM_NAMES%
echo Use these tools only on systems and networks you own or are authorized to test.
echo.
echo 1. Install all listed tools
echo 2. Uninstall all listed tools
echo 3. Choose one tool - install, update, or uninstall
echo 0. Back
echo.
choice /C 1230 /N /M "Choose an option: "
if errorlevel 4 goto main_menu
if errorlevel 3 goto security_individual
if errorlevel 2 goto security_uninstall_all
if errorlevel 1 goto security_install_all

:security_install_all
set "SECURITY_IDS=WiresharkFoundation.Wireshark ZAP.ZAP Microsoft.Sysinternals.Suite Insecure.Nmap"
call :run_app_list install "%SECURITY_IDS%" security
goto security_menu

:security_uninstall_all
set "SECURITY_IDS=Insecure.Nmap Microsoft.Sysinternals.Suite ZAP.ZAP WiresharkFoundation.Wireshark"
call :run_app_list uninstall "%SECURITY_IDS%" security
goto security_menu

:security_individual
call :custom_load security
cls
echo Option 4 - Choose a security/network tool
echo 1. Wireshark - packet analyzer
echo 2. OWASP ZAP - web application testing proxy
echo 3. Microsoft Sysinternals Suite - Windows diagnostics
echo 4. Nmap - network scanner; packet capture may need Npcap
call :custom_print 4
echo 0. Back
echo.
set /a PICK_MAX=4+CUSTOM_COUNT
call :ask_number "Type the number of the tool and press Enter: " %PICK_MAX%
if "%PICK%"=="0" goto security_menu
if %PICK% GTR 4 goto security_custom_pick
if %PICK% EQU 4 goto security_app4
if %PICK% EQU 3 goto security_app3
if %PICK% EQU 2 goto security_app2
if %PICK% EQU 1 goto security_app1
goto security_individual

:security_custom_pick
set /a CUSTOM_PICK=PICK-4
call :custom_open %CUSTOM_PICK%
goto security_individual

:security_app1
call :single_app_menu "WiresharkFoundation.Wireshark" "Wireshark"
goto security_individual
:security_app2
call :single_app_menu "ZAP.ZAP" "OWASP ZAP"
goto security_individual
:security_app3
call :single_app_menu "Microsoft.Sysinternals.Suite" "Microsoft Sysinternals Suite"
goto security_individual
:security_app4
call :single_app_menu "Insecure.Nmap" "Nmap"
goto security_individual

:run_app_list
set "HAS_ERRORS=0"
call :winget_ready
if errorlevel 1 goto app_list_summary
if /I "%~1"=="install" (
    for %%P in (%~2) do call :install_package "%%P" "%%P"
    call :custom_run install %~3
) else (
    call :custom_run uninstall %~3
    for %%P in (%~2) do call :uninstall_package "%%P" "%%P"
)
:app_list_summary
if "%HAS_ERRORS%"=="1" (
    echo One or more apps could not be processed automatically.
    echo Check the package ID and Winget log folder:
    echo "%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
) else (
    echo App operation completed.
)
echo.
pause
exit /b

:single_app_menu
if /I "%~3"=="url" goto single_app_menu_show
where winget.exe >nul 2>&1
if errorlevel 1 (
    call :winget_ready
    if errorlevel 1 (
        pause
        exit /b 1
    )
)
:single_app_menu_show
cls
echo %~2
echo.
if /I "%~3"=="url" goto single_app_menu_link
echo Current Winget match, if installed:
winget list --id "%~1" --exact --source winget --accept-source-agreements --disable-interactivity
goto single_app_menu_choose
:single_app_menu_link
echo This app was added from a download link, so Winget is not used for it.
echo Update downloads the saved link again and runs its installer.
:single_app_menu_choose
echo.
echo Each action runs in its own Command Prompt window.
echo 1. Install (skip if already installed)
echo 2. Update
echo 3. Uninstall
echo 0. Back
choice /C 1230 /N /M "Choose an action: "
set "APP_ACTION=%ERRORLEVEL%"
if "%APP_ACTION%"=="4" exit /b 0
if "%APP_ACTION%"=="1" call :launch_app_worker install "%~1" "%~2" "%~3"
if "%APP_ACTION%"=="2" call :launch_app_worker update "%~1" "%~2" "%~3"
if "%APP_ACTION%"=="3" call :launch_app_worker uninstall "%~1" "%~2" "%~3"
if errorlevel 1 (
    echo Could not open the app task window.
    pause
) else (
    echo The app task is running in a separate Command Prompt window.
)
echo.
exit /b

:launch_app_worker
set "FWS_ACTION=%~1"
set "FWS_ID=%~2"
set "FWS_NAME=%~3"
set "FWS_TYPE=%~4"
echo Opening the task window...
if not exist "%SystemRoot%\System32\conhost.exe" goto launch_app_worker_plain
start "%FWS_NAME% - %FWS_ACTION%" "%SystemRoot%\System32\conhost.exe" cmd.exe /D /C %%FWS_RUN%%
exit /b 0

:launch_app_worker_plain
start "%FWS_NAME% - %FWS_ACTION%" "%SystemRoot%\System32\cmd.exe" /D /C %%FWS_RUN%%
exit /b 0

:winget_ready
where winget.exe >nul 2>&1
if errorlevel 1 powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop } catch {}"
where winget.exe >nul 2>&1
if errorlevel 1 (
    echo Winget is not available. Opening Microsoft Store App Installer.
    start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    echo Install or update App Installer, then return to this menu.
    set "HAS_ERRORS=1"
    exit /b 1
)
winget source update --name winget --disable-interactivity
if errorlevel 1 (
    echo Winget source refresh failed; continuing with cached sources and retrying per app.
)
exit /b 0

:install_package
echo.
echo Checking whether %~2 is already installed...
winget list --id "%~1" --exact --source winget --accept-source-agreements --disable-interactivity 2>nul | findstr /I /L /C:"%~1" >nul
if not errorlevel 1 (
    echo %~2 is already installed; skipping.
    exit /b 0
)
echo Installing %~2...
call :winget_install_once "%~1"
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" exit /b 0
if "%APP_EXIT%"=="-1978335135" (
    echo %~2 is already installed; skipping.
    exit /b 0
)
echo First attempt failed with code %APP_EXIT%. Refreshing the source and trying repair/reinstall.
winget source update --name winget --disable-interactivity
winget repair --id "%~1" --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
call :winget_install_once "%~1"
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" (
    echo Recovered: %~2 installed after retry.
    exit /b 0
)
echo Could not install %~2. Winget error code: %APP_EXIT%.
set "HAS_ERRORS=1"
exit /b 1

:winget_install_once
if /I "%~1"=="Microsoft.VisualStudio.Community" (
    winget install --id "%~1" --exact --source winget --silent --accept-source-agreements --accept-package-agreements --no-upgrade --disable-interactivity --override "--quiet --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --wait"
) else (
    winget install --id "%~1" --exact --source winget --silent --accept-source-agreements --accept-package-agreements --no-upgrade --disable-interactivity
)
exit /b %ERRORLEVEL%

:update_package
echo.
echo Checking whether %~2 is installed and has an update...
winget list --id "%~1" --exact --source winget --accept-source-agreements --disable-interactivity 2>nul | findstr /I /L /C:"%~1" >nul
if errorlevel 1 (
    echo %~2 is not installed; there is nothing to update.
    exit /b 0
)
winget upgrade --id "%~1" --exact --source winget --include-unknown --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" exit /b 0
if "%APP_EXIT%"=="-1978335189" (
    echo %~2 is already up to date.
    exit /b 0
)
echo Update attempt failed with code %APP_EXIT%. Refreshing the source and retrying.
winget source update --name winget --disable-interactivity
winget upgrade --id "%~1" --exact --source winget --include-unknown --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="-1978335189" (
    echo %~2 is already up to date.
    exit /b 0
)
if "%APP_EXIT%"=="0" (
    echo Recovered: %~2 updated after retry.
    exit /b 0
)
echo Could not update %~2. Winget error code: %APP_EXIT%.
set "HAS_ERRORS=1"
exit /b 1

:uninstall_package
echo.
echo Checking %~2...
winget list --id "%~1" --exact --source winget --accept-source-agreements --disable-interactivity 2>nul | findstr /I /L /C:"%~1" >nul
if errorlevel 1 (
    echo %~2 is not installed; skipping.
    exit /b 0
)
echo Uninstalling %~2...
winget uninstall --id "%~1" --exact --source winget --silent --accept-source-agreements --disable-interactivity
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" exit /b 0
echo Uninstall retry after a source refresh; first exit code was %APP_EXIT%.
winget source update --name winget --disable-interactivity
winget uninstall --id "%~1" --exact --source winget --silent --accept-source-agreements --disable-interactivity
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" (
    echo Recovered: %~2 uninstalled after retry.
    exit /b 0
)
echo Could not uninstall %~2. Winget error code: %APP_EXIT%.
set "HAS_ERRORS=1"
exit /b 1

:app_manage_menu
if /I not "%ADD_REMOVE%"=="on" goto main_menu
cls
echo ============================================================
echo Option 5 - Add or remove an app in a category
echo ============================================================
echo The apps you add are saved inside this script, at the very end.
echo.
echo 1. Add an app to a category
echo 2. Remove an app from a category
echo 0. Back
echo.
choice /C 120 /N /M "Choose an option: "
if errorlevel 3 goto main_menu
if errorlevel 2 goto remove_app_menu
if errorlevel 1 goto add_app_menu
goto app_manage_menu

:remove_app_menu
cls
echo ============================================================
echo Option 5 - Remove an app from a category
echo ============================================================
echo Pick a category, then pick the apps to take off its list.
echo Only apps that were added with Add an app can be removed here. The apps
echo that come with this script stay in their category.
echo Removing an app only takes it off the list. It is not uninstalled from
echo this PC. To uninstall it too, do that first from the category menu.
echo.
echo 1. Everyday apps
echo 2. IDEs and development tools
echo 3. Security and network analysis tools
echo 0. Back
echo.
choice /C 1230 /N /M "Remove an app from which category: "
set "PICK=%ERRORLEVEL%"
if "%PICK%"=="4" goto app_manage_menu
set "REMOVE_CATEGORY=daily"
if "%PICK%"=="2" set "REMOVE_CATEGORY=dev"
if "%PICK%"=="3" set "REMOVE_CATEGORY=security"
call :custom_ps_ready
if errorlevel 1 (
    echo.
    pause
    goto remove_app_menu
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SELF_DIR%Manage-CustomApps.ps1" -Action Remove -Category %REMOVE_CATEGORY% -ScriptFile "%SELF%"
echo.
pause
goto remove_app_menu

:add_app_menu
cls
echo ============================================================
echo Option 5 - Add an app to a category
echo ============================================================
echo The app is looked up in Winget first, and its download is found automatically.
echo If Winget does not have it, you can paste a download link instead.
echo The app is saved inside this script, at the very end, so it is there next time.
echo.
echo 1. Everyday apps
echo 2. IDEs and development tools
echo 3. Security and network analysis tools
echo 0. Back
echo.
choice /C 1230 /N /M "Add the app to which category: "
set "PICK=%ERRORLEVEL%"
if "%PICK%"=="4" goto app_manage_menu
set "ADD_CATEGORY=daily"
if "%PICK%"=="2" set "ADD_CATEGORY=dev"
if "%PICK%"=="3" set "ADD_CATEGORY=security"
call :custom_ps_ready
if errorlevel 1 (
    echo.
    pause
    goto add_app_menu
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SELF_DIR%Manage-CustomApps.ps1" -Action Add -Category %ADD_CATEGORY% -ScriptFile "%SELF%"
echo.
pause
goto add_app_menu

:custom_ps_ready
if exist "%SELF_DIR%Manage-CustomApps.ps1" exit /b 0
echo Manage-CustomApps.ps1 was not found next to this script. Keep all the setup files in the same folder.
set "HAS_ERRORS=1"
exit /b 1

:custom_migrate
if not exist "%SELF_DIR%Manage-CustomApps.ps1" exit /b 0
echo Moving the apps you added earlier from Custom-Apps.txt into this script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SELF_DIR%Manage-CustomApps.ps1" -Action Migrate -ScriptFile "%SELF%" -LegacyFile "%SELF_DIR%Custom-Apps.txt"
exit /b 0

:ask_number
rem Reads a whole number (1, 2 ... 10 ... 100 and so on, or 0) and puts it in PICK. Anything else asks again.
set "PICK="
set "ASK_RAW="
set /p "ASK_RAW=%~1"
if not defined ASK_RAW goto ask_number
set "ASK_RAW=%ASK_RAW:"=%"
set "ASK_WORD="
for /f "tokens=1" %%T in ("%ASK_RAW%") do set "ASK_WORD=%%T"
if not defined ASK_WORD goto ask_number
if "%ASK_WORD%"=="0" set "PICK=0"
for /l %%N in (1,1,%~2) do if "%ASK_WORD%"=="%%N" set "PICK=%%N"
if defined PICK exit /b 0
echo Please type one of the numbers shown above.
goto ask_number

:custom_load
set "CUSTOM_COUNT=0"
set "CUSTOM_NAMES="
for /f "usebackq tokens=1-5 delims=|" %%A in ("%SELF%") do if "%%A"=="::APP" if /I "%%B"=="%~1" call :custom_load_one "%%C" "%%D" "%%E"
exit /b 0

:custom_load_one
set /a CUSTOM_COUNT+=1
set "CUSTOM_TYPE_%CUSTOM_COUNT%=%~1"
set "CUSTOM_ID_%CUSTOM_COUNT%=%~2"
set "CUSTOM_NAME_%CUSTOM_COUNT%=%~3"
if defined CUSTOM_NAMES (
    set "CUSTOM_NAMES=%CUSTOM_NAMES%, %~3"
) else (
    set "CUSTOM_NAMES=%~3"
)
exit /b 0

:custom_print
set "CUSTOM_PRINT_BASE=%~1"
set "CUSTOM_PRINT_I=0"
:custom_print_next
set /a CUSTOM_PRINT_I+=1
if %CUSTOM_PRINT_I% GTR %CUSTOM_COUNT% exit /b 0
set /a CUSTOM_PRINT_N=CUSTOM_PRINT_BASE+CUSTOM_PRINT_I
call echo %CUSTOM_PRINT_N%. %%CUSTOM_NAME_%CUSTOM_PRINT_I%%% - added by you
goto custom_print_next

:custom_open
call set "CUSTOM_OPEN_TYPE=%%CUSTOM_TYPE_%~1%%"
call set "CUSTOM_OPEN_ID=%%CUSTOM_ID_%~1%%"
call set "CUSTOM_OPEN_NAME=%%CUSTOM_NAME_%~1%%"
call :single_app_menu "%CUSTOM_OPEN_ID%" "%CUSTOM_OPEN_NAME%" "%CUSTOM_OPEN_TYPE%"
exit /b 0

:custom_run
if "%~2"=="" exit /b 0
for /f "usebackq tokens=1-5 delims=|" %%A in ("%SELF%") do if "%%A"=="::APP" if /I "%%B"=="%~2" call :custom_run_one %~1 "%%C" "%%D" "%%E"
exit /b 0

:custom_run_one
if /I "%~2"=="url" goto custom_run_one_url
if /I "%~1"=="install" call :install_package "%~3" "%~4"
if /I "%~1"=="uninstall" call :uninstall_package "%~3" "%~4"
exit /b 0
:custom_run_one_url
if /I "%~1"=="install" call :install_custom_url "%~3" "%~4"
if /I "%~1"=="uninstall" call :uninstall_custom_url "%~3" "%~4"
exit /b 0

:install_custom_url
echo.
echo Installing %~2 from its saved download link...
call :custom_ps_ready
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SELF_DIR%Manage-CustomApps.ps1" -Action Install -Key "%~1" -ScriptFile "%SELF%" %CUSTOM_FORCE%
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" exit /b 0
if "%APP_EXIT%"=="3010" (
    echo %~2 is done, but a restart is needed to finish.
    exit /b 0
)
echo Could not install %~2. Exit code: %APP_EXIT%.
set "HAS_ERRORS=1"
exit /b 1

:update_custom_url
echo.
echo Updating %~2 by downloading its saved link again...
set "CUSTOM_FORCE=-Force"
call :install_custom_url "%~1" "%~2"
set "UPDATE_EXIT=%ERRORLEVEL%"
set "CUSTOM_FORCE="
exit /b %UPDATE_EXIT%

:uninstall_custom_url
echo.
echo Uninstalling %~2...
call :custom_ps_ready
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SELF_DIR%Manage-CustomApps.ps1" -Action Uninstall -Key "%~1" -ScriptFile "%SELF%"
set "APP_EXIT=%ERRORLEVEL%"
if "%APP_EXIT%"=="0" exit /b 0
if "%APP_EXIT%"=="3010" (
    echo %~2 is done, but a restart is needed to finish.
    exit /b 0
)
echo Could not uninstall %~2. Exit code: %APP_EXIT%.
set "HAS_ERRORS=1"
exit /b 1

exit /b
:: ======================================================================
:: ADDED APPS - option 5 saves the apps you add right below, one per line.
:: Never put any code below this line. Option 5 can also remove an app, or delete its line yourself.
:: A line looks like:  ::APP|category|type|id|name|download link|switches
:: ======================================================================
::APP|daily|winget|RARLab.WinRAR|WinRAR||
::APP|daily|winget|Microsoft.Edge|Microsoft Edge||
::APP|daily|winget|Brave.Brave|Brave||
::APP|daily|winget|Opera.Opera|Opera||
::APP|daily|winget|Vivaldi.Vivaldi|Vivaldi||
::APP|daily|winget|Microsoft.Office|Microsoft 365||
::APP|daily|winget|Kingsoft.WPSOffice|WPS Office||
::APP|daily|winget|Microsoft.OneDrive|OneDrive||
::APP|daily|winget|Google.GoogleDrive|Google Drive for desktop||
::APP|daily|winget|Dropbox.Dropbox|Dropbox||
::APP|daily|winget|Telegram.TelegramDesktop|Telegram||
::APP|daily|winget|OpenWhisperSystems.Signal|Signal||
::APP|daily|winget|Discord.Discord|Discord||
::APP|daily|winget|SlackTechnologies.Slack|Slack||
::APP|daily|winget|Microsoft.Teams|Microsoft Teams||
::APP|daily|winget|Zoom.Zoom|Zoom Workplace||
::APP|daily|winget|Mozilla.Thunderbird|Mozilla Thunderbird||
::APP|daily|winget|Proton.ProtonMail|Proton Mail||
::APP|daily|winget|Spotify.Spotify|Spotify||
::APP|daily|winget|TIDALMusicAS.TIDAL|TIDAL||
::APP|daily|winget|Plex.Plex|Plex||
::APP|daily|winget|XBMCFoundation.Kodi|Kodi||
::APP|daily|winget|Adobe.Acrobat.Reader.64-bit|Adobe Acrobat Reader||
::APP|daily|winget|Bitwarden.Bitwarden|Bitwarden||
::APP|daily|winget|Notion.Notion|Notion||
::APP|daily|winget|Obsidian.Obsidian|Obsidian||
::APP|daily|winget|Evernote.Evernote|Evernote||
::APP|daily|winget|Doist.Todoist|Todoist||
::APP|daily|winget|AnyDeskSoftwareGmbH.AnyDesk|AnyDesk||
::APP|daily|winget|TeamViewer.TeamViewer|TeamViewer||
::APP|daily|winget|ShareX.ShareX|ShareX||
::APP|daily|winget|Greenshot.Greenshot|Greenshot||
::APP|daily|winget|dotPDN.PaintDotNet|Paint.NET||
::APP|daily|winget|GIMP.GIMP.3|GIMP||
::APP|daily|winget|OBSProject.OBSStudio|OBS Studio||
::APP|daily|winget|Audacity.Audacity|Audacity||
::APP|dev|winget|JetBrains.IntelliJIDEA.Ultimate|IntelliJ IDEA||
::APP|dev|winget|JetBrains.PyCharm|PyCharm||
::APP|dev|winget|Google.AndroidStudio|Android Studio||
::APP|dev|winget|EclipseFoundation.Eclipse.Java|Eclipse IDE||
::APP|dev|winget|Apache.NetBeans|Apache NetBeans||
::APP|dev|winget|SublimeHQ.SublimeText.4|Sublime Text||
::APP|dev|winget|vim.vim|Vim||
::APP|dev|winget|Neovim.Neovim|Neovim||
::APP|dev|winget|GNU.Emacs|Emacs||
::APP|dev|winget|Anysphere.Cursor|Cursor||
::APP|dev|winget|Zed.Zed|Zed||
::APP|dev|winget|JetBrains.WebStorm|WebStorm||
::APP|dev|winget|JetBrains.Rider|Rider||
::APP|dev|winget|JetBrains.CLion|CLion||
::APP|dev|winget|JetBrains.GoLand|GoLand||
::APP|dev|winget|JetBrains.PhpStorm|PhpStorm||
::APP|dev|winget|JetBrains.RustRover|RustRover||
::APP|dev|winget|Anaconda.Anaconda3|Anaconda Navigator||
::APP|dev|winget|GitHub.GitHubDesktop|GitHub Desktop||
::APP|dev|winget|Atlassian.Sourcetree|Sourcetree||
::APP|dev|winget|TortoiseGit.TortoiseGit|TortoiseGit||
::APP|dev|winget|Axosoft.GitKraken|GitKraken||
::APP|dev|winget|Fork.Fork|Fork||
::APP|dev|winget|Microsoft.WindowsTerminal|Windows Terminal||
::APP|dev|winget|Microsoft.PowerShell|PowerShell 7||
::APP|dev|winget|Microsoft.WSL|Windows Subsystem for Linux||
::APP|dev|winget|RedHat.Podman-Desktop|Podman Desktop||
::APP|dev|winget|SUSE.RancherDesktop|Rancher Desktop||
::APP|dev|winget|Mirantis.Lens|Lens||
::APP|dev|winget|Postman.Postman|Postman||
::APP|dev|winget|Insomnia.Insomnia|Insomnia||
::APP|dev|winget|Bruno.Bruno|Bruno||
::APP|dev|winget|dbeaver.dbeaver|DBeaver||
::APP|dev|winget|Oracle.MySQLWorkbench|MySQL Workbench||
::APP|dev|winget|PostgreSQL.pgAdmin|pgAdmin||
::APP|dev|winget|MongoDB.Compass.Full|MongoDB Compass||
::APP|dev|winget|Redis.RedisInsight|Redis Insight||
::APP|dev|winget|HeidiSQL.HeidiSQL|HeidiSQL||
::APP|dev|winget|WinSCP.WinSCP|WinSCP||
::APP|dev|winget|TimKosse.FileZilla.Client|FileZilla||
::APP|dev|winget|PuTTY.PuTTY|PuTTY||
::APP|security|winget|Malwarebytes.Malwarebytes|Malwarebytes||
::APP|security|winget|Microsoft.Sysinternals.Autoruns|Autoruns||
::APP|security|winget|Microsoft.Sysinternals.ProcessExplorer|Process Explorer||
::APP|security|winget|Microsoft.Sysinternals.ProcessMonitor|Process Monitor||
::APP|security|winget|Microsoft.Sysinternals.TCPView|TCPView||
::APP|security|winget|Microsoft.Sysinternals.Sigcheck|Sigcheck||
::APP|security|winget|Microsoft.Sysinternals.Sysmon|Sysmon||
::APP|security|winget|Sandboxie.Plus|Sandboxie-Plus||
::APP|security|winget|Insecure.Npcap|Npcap||
::APP|security|winget|angryziber.AngryIPScanner|Angry IP Scanner||
::APP|security|winget|Famatech.AdvancedIPScanner|Advanced IP Scanner||
::APP|security|winget|PortSwigger.BurpSuite.Community|Burp Suite Community Edition||
::APP|security|winget|Telerik.FiddlerEverywhere|Fiddler Everywhere||
::APP|security|winget|mitmproxy.mitmproxy|mitmproxy||
::APP|security|winget|Tenable.Nessus|Nessus Essentials||
::APP|security|winget|NationalSecurityAgency.Ghidra|Ghidra||
::APP|security|winget|x64dbg.x64dbg|x64dbg||
::APP|security|winget|Microsoft.WinDbg|WinDbg||
::APP|security|winget|Hex-Rays.IDA.Free|IDA Free||
::APP|security|winget|Rizin.Cutter|Cutter||
::APP|security|winget|horsicq.DIE-engine|Detect It Easy||
::APP|security|winget|hasherezade.PE-bear|PE-bear||
::APP|security|winget|dnSpyEx.dnSpy|dnSpyEx||
::APP|security|winget|icsharpcode.ILSpy|ILSpy||
::APP|security|winget|skylot.jadx|JADX||
::APP|security|winget|AngusJohnson.ResourceHacker|Resource Hacker||
::APP|security|winget|MH-Software.HxD|HxD||
::APP|security|winget|WerWolv.ImHex|ImHex||
::APP|security|winget|SleuthKit.Autopsy|Autopsy||
::APP|security|winget|IDRIX.VeraCrypt|VeraCrypt||
::APP|security|winget|KeePassXCTeam.KeePassXC|KeePassXC||
::APP|security|winget|GnuPG.Gpg4win|Gpg4win||
::APP|security|winget|WireGuard.WireGuard|WireGuard||
::APP|security|winget|Yubico.YubiKeyManager|YubiKey Manager||
