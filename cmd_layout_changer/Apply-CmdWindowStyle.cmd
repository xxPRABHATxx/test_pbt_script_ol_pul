@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-CmdWindowStyle.ps1"
exit /b %errorlevel%
