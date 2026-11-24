@echo off
setlocal DisableDelayedExpansion
title WSL Fixer - Install / Uninstall
set "SELF=%~f0"
set "WSLFIX_ARGS=%*"
set "WSLFIX_PS1=%TEMP%\WslFix_run.ps1"

rem ===========================================================================
rem  Fix-WSL-Virtualization.bat
rem
rem  Menu driven helper for WSL on Windows. Double-click it and choose:
rem
rem    1. Install or repair WSL and Ubuntu. Fixes the WSL 2 error
rem       HCS_E_HYPERV_NOT_INSTALLED, falls back to WSL 1 when virtualization
rem       cannot be used, and installs cmatrix and hollywood.
rem    2. Uninstall. Removes Ubuntu only, or everything WSL related.
rem
rem  What it can change on this PC. It tells you before each change:
rem    - Boot option hypervisorlaunchtype, using bcdedit
rem    - Windows features: Windows Subsystem for Linux, Virtual Machine Platform
rem    - WSL components, Linux distros, and the cmatrix and hollywood packages
rem  It asks before restarting Windows. After an install restart it continues
rem  by itself.
rem
rem  The one thing no script can do is switch virtualization on inside the BIOS.
rem  If that is the problem, the install option can restart straight into the
rem  BIOS for you, or install Ubuntu with WSL 1, which needs no virtualization.
rem ===========================================================================

rem --- 1. Administrator rights are needed for bcdedit, DISM and WSL setup
fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting Administrator permission...
    powershell.exe -NoProfile -Command "Start-Process -FilePath $env:SELF -ArgumentList ('elevated ' + $env:WSLFIX_ARGS) -Verb RunAs"
    if errorlevel 1 (
        echo.
        echo Administrator permission was not granted.
        echo Right-click this file and choose "Run as administrator".
        pause
    )
    exit /b
)

rem --- 2. Unpack the PowerShell part of this same file, everything below the marker line
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c = [IO.File]::ReadAllText($env:SELF); $p = ($c -split '(?m)^#PSBEGIN[ \t]*\r?$', 2)[1]; [IO.File]::WriteAllText($env:WSLFIX_PS1, $p)"
if errorlevel 1 (
    echo Could not unpack the PowerShell part of this script.
    pause
    exit /b 1
)

rem --- 3. Run it
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WSLFIX_PS1%"
set "RC=%errorlevel%"
del "%WSLFIX_PS1%" >nul 2>&1
echo.
pause
exit /b %RC%

#PSBEGIN
# ---------------------------------------------------------------------------
#  PowerShell part. The batch header above copies everything below the marker
#  line into a temporary .ps1 file and runs it.
# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$Self       = $env:SELF
$Resumed    = ("$env:WSLFIX_ARGS" -match 'resume')
$RunOnceKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$LxssKey    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$FixerKey   = 'HKCU:\Software\WslFixer'
$WslAppPattern = '^(MicrosoftCorporationII\.WindowsSubsystemForLinux|CanonicalGroupLimited\.Ubuntu|TheDebianProject\.DebianGNULinux|KaliLinux|SUSE|openSUSE|OracleLinux|FedoraRemix|WhitewaterFoundry\.Pengwin|AlpineWSL)'
$S = @{ NeedReboot = $false; UseWsl1 = $false; Distro = $null }

# ------------------------------- helpers -----------------------------------
function Write-Step([string]$Text) { Write-Host ''; Write-Host ('=== {0} ===' -f $Text) -ForegroundColor White }
function Write-Ok([string]$Text)   { Write-Host ('[ OK ] {0}' -f $Text) -ForegroundColor Green }
function Write-Fix([string]$Text)  { Write-Host ('[FIX ] {0}' -f $Text) -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host ('[ .. ] {0}' -f $Text) -ForegroundColor Cyan }
function Write-Warn([string]$Text) { Write-Host ('[WARN] {0}' -f $Text) -ForegroundColor Yellow }
function Write-Bad([string]$Text)  { Write-Host ('[FAIL] {0}' -f $Text) -ForegroundColor Red }

function Ask-YesNo([string]$Prompt, [bool]$Default = $true) {
    $hint = '[y/N]'
    if ($Default) { $hint = '[Y/n]' }
    while ($true) {
        $a = ('' + (Read-Host ($Prompt + ' ' + $hint))).Trim().ToLower()
        if ($a -eq '') { return $Default }
        if ($a -eq 'y' -or $a -eq 'yes') { return $true }
        if ($a -eq 'n' -or $a -eq 'no')  { return $false }
        Write-Host 'Please type y or n.'
    }
}

function Ask-Choice([string]$Prompt, [string[]]$Valid) {
    while ($true) {
        $a = ('' + (Read-Host $Prompt)).Trim().ToUpper()
        if ($Valid -contains $a) { return $a }
        Write-Host ('Please type one of: {0}' -f ($Valid -join ', '))
    }
}

# Used before anything gets deleted: the exact word must be typed.
function Confirm-Typed([string]$Word) {
    Write-Host ''
    $a = ('' + (Read-Host ('Type {0} to continue, or just press Enter to cancel' -f $Word))).Trim()
    return ($a -eq $Word)
}

function Reset-State {
    $S.NeedReboot = $false
    $S.UseWsl1    = $false
    $S.Distro     = $null
}

# After an install restart Windows runs this fixer again (RunOnce) so you do not have to.
function Register-Resume {
    $cmd = 'cmd.exe /c ""' + $Self + '" resume"'
    try {
        Set-ItemProperty -Path $RunOnceKey -Name 'WslFixResume' -Value $cmd -ErrorAction Stop
        Write-Info 'This fixer reopens after you sign in (approve the Administrator prompt) and continues.'
    } catch {
        Write-Warn 'Could not schedule the automatic continue. Run this fixer again after Windows starts.'
    }
}

function Remove-Resume {
    Remove-ItemProperty -Path $RunOnceKey -Name 'WslFixResume' -ErrorAction SilentlyContinue
}

function Start-WindowsRestart([string]$Message, [bool]$ToFirmware = $false, [bool]$AutoContinue = $true) {
    if ($AutoContinue) { Register-Resume }
    if ($ToFirmware) {
        & shutdown.exe /r /fw /t 15 /c $Message 2>&1 | Out-Null
    } else {
        & shutdown.exe /r /t 15 /c $Message 2>&1 | Out-Null
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Info 'Restarting in 15 seconds. To cancel, run in a terminal: shutdown /a'
        return $true
    }
    if ($AutoContinue) { Remove-Resume }
    return $false
}

# Returns $true when a restart was started.
function Ask-Restart([string]$Reason, [bool]$AutoContinue = $true) {
    Write-Host ''
    Write-Warn $Reason
    $q = 'Restart Windows now? Save your work first.'
    if ($AutoContinue) { $q = $q + ' This fixer reopens after you sign in.' }
    if (-not (Ask-YesNo $q $true)) { return $false }
    if (Start-WindowsRestart 'Restarting to finish the WSL changes' $false $AutoContinue) { return $true }
    Write-Warn 'Could not start the restart. Please restart Windows yourself (use Restart, not Shut down).'
    return $false
}

# WSL 1 does not use virtualization, so it works when WSL 2 cannot.
# Returns $true when the user picked WSL 1, $false when they went back.
function Offer-Wsl1([string]$Reason) {
    Write-Host ''
    Write-Warn $Reason
    Write-Host '       WSL 1 needs no virtualization and is enough for cmatrix and hollywood.'
    Write-Host '       [W] Install Ubuntu with WSL 1 instead'
    Write-Host '       [Q] Back to the main menu'
    if ((Ask-Choice 'Choose W or Q' @('W','Q')) -eq 'Q') { return $false }
    $S.UseWsl1 = $true
    return $true
}

function Ensure-Feature([string]$Name, [string]$Label) {
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
    } catch {
        Write-Bad ('Could not read the feature {0}: {1}' -f $Label, $_.Exception.Message)
        return
    }
    $state = '' + $f.State
    if ($state -eq 'Enabled') {
        Write-Ok ('{0} is enabled.' -f $Label)
    } elseif ($state -eq 'EnablePending') {
        Write-Warn ('{0} is enabled but still waits for a restart.' -f $Label)
        $S.NeedReboot = $true
    } else {
        Write-Info ('Enabling {0} (this can take a minute)...' -f $Label)
        try {
            $null = Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart -ErrorAction Stop
            Write-Fix ('{0} enabled (active after a restart).' -f $Label)
            $S.NeedReboot = $true
        } catch {
            Write-Bad ('Could not enable {0}: {1}' -f $Label, $_.Exception.Message)
        }
    }
}

function Disable-Feature([string]$Name, [string]$Label) {
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
    } catch {
        Write-Bad ('Could not read the feature {0}: {1}' -f $Label, $_.Exception.Message)
        return
    }
    $state = '' + $f.State
    if ($state -eq 'Disabled' -or $state -eq 'DisabledWithPayloadRemoved') {
        Write-Ok ('{0} is already off.' -f $Label)
    } elseif ($state -eq 'DisablePending') {
        Write-Warn ('{0} is already switched off and waits for a restart.' -f $Label)
        $S.NeedReboot = $true
    } else {
        Write-Info ('Turning off {0} (this can take a minute)...' -f $Label)
        try {
            $null = Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop
            Write-Fix ('{0} turned off (active after a restart).' -f $Label)
            $S.NeedReboot = $true
        } catch {
            Write-Bad ('Could not turn off {0}: {1}' -f $Label, $_.Exception.Message)
        }
    }
}

function Get-FeatureState([string]$Name) {
    try {
        return ('' + (Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop).State)
    } catch {
        return ''
    }
}

# True when WSL itself is really installed. This is decided WITHOUT running wsl.exe, because the
# wsl.exe that Windows ships is only a stub when WSL is missing (it asks to press a key to install).
function Test-WslRuntime {
    if (Get-AppxPackage -Name 'MicrosoftCorporationII.WindowsSubsystemForLinux' -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path (Join-Path $env:ProgramFiles 'WSL\wsl.exe')) { return $true }
    $st = Get-FeatureState 'Microsoft-Windows-Subsystem-Linux'
    if ($st -eq 'Enabled' -or $st -eq 'EnablePending') { return $true }
    return $false
}

# All WSL distros registered for this Windows account (name + WSL version).
function Get-WslDistros {
    $list = @()
    if (Test-Path $LxssKey) {
        foreach ($k in (Get-ChildItem $LxssKey -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.DistributionName) {
                $list += [pscustomobject]@{ Name = [string]$p.DistributionName; Version = $p.Version }
            }
        }
    }
    return $list
}

function Format-Distro($d) {
    $v = '?'
    if ($d.Version) { $v = '' + $d.Version }
    return ('{0} (WSL {1})' -f $d.Name, $v)
}

function Get-UbuntuInfo {
    foreach ($d in @(Get-WslDistros)) {
        if ($d.Name -like 'Ubuntu*') { return $d }
    }
    return $null
}

# Remembers the boot option value from before this fixer changed it, so the
# uninstall can offer to put it back. Only the first value is kept.
function Save-PrevLaunchType([string]$Value) {
    try {
        if (-not (Test-Path $FixerKey)) { $null = New-Item -Path $FixerKey -Force -ErrorAction Stop }
        $old = (Get-ItemProperty -Path $FixerKey -ErrorAction Stop).PrevHypervisorLaunchType
        if (-not $old) { Set-ItemProperty -Path $FixerKey -Name 'PrevHypervisorLaunchType' -Value $Value -ErrorAction Stop }
    } catch { }
}

# Sets $S.Distro when Ubuntu is registered with WSL afterwards.
function Install-Ubuntu {
    $S.Distro = Get-UbuntuInfo
    if ($S.Distro) { return }

    # The Ubuntu app can be installed but not set up yet (typical after a failed first try).
    $app = Get-AppxPackage -Name 'CanonicalGroupLimited.Ubuntu*' -ErrorAction SilentlyContinue | Select-Object -First 1
    $exe = Get-Command ubuntu.exe -ErrorAction SilentlyContinue
    if ($app -and $exe) {
        Write-Info 'The Ubuntu app is installed but not set up yet. Starting its first-run setup...'
        Write-Host '       Create a Linux username and password when asked. At the Ubuntu prompt type: exit'
        & $exe.Source
        $S.Distro = Get-UbuntuInfo
        if ($S.Distro) { return }
    }

    Write-Info 'Installing Ubuntu: wsl --install -d Ubuntu'
    Write-Host '       Create a Linux username and password when asked. At the Ubuntu prompt type: exit'
    & wsl.exe --install -d Ubuntu
    $S.Distro = Get-UbuntuInfo
}

function Stop-Wsl {
    Write-Info 'Stopping WSL: wsl --shutdown'
    & wsl.exe --shutdown 2>&1 | Out-Null
}

function Remove-Distro([string]$Name) {
    Write-Info ('Removing distro: {0}' -f $Name)
    & wsl.exe --unregister $Name
    if ($LASTEXITCODE -eq 0) {
        Write-Fix ('Distro {0} removed.' -f $Name)
    } else {
        Write-Bad ('Could not remove {0}. Close programs that use it (for example Docker Desktop) and try again.' -f $Name)
    }
}

function Remove-AppxByPattern([string]$Pattern, [string]$Label) {
    try {
        $found = @(Get-AppxPackage -ErrorAction Stop | Where-Object { $_.Name -match $Pattern })
    } catch {
        Write-Warn ('Could not list the installed apps: {0}' -f $_.Exception.Message)
        return
    }
    if ($found.Count -eq 0) {
        Write-Info ('No {0} app packages found.' -f $Label)
        return
    }
    foreach ($pk in $found) {
        try {
            Remove-AppxPackage -Package $pk.PackageFullName -ErrorAction Stop
            Write-Fix ('Removed app package {0}' -f $pk.Name)
        } catch {
            Write-Warn ('Could not remove {0}: {1}' -f $pk.Name, $_.Exception.Message)
        }
    }
}

# ------------------------------- INSTALL -----------------------------------
function Invoke-Install {
    Reset-State

    if ($Resumed) {
        Write-Info 'Continuing after the restart...'
    } else {
        Write-Host ''
        Write-Host 'Install / repair may:'
        Write-Host '  - set the boot option "hypervisorlaunchtype" to Auto'
        Write-Host '  - turn on the Windows features "Windows Subsystem for Linux" and "Virtual Machine Platform"'
        Write-Host '  - install or update WSL, install Ubuntu, and install cmatrix + hollywood'
        Write-Host 'It asks before restarting Windows.'
        Write-Host ''
        if (-not (Ask-YesNo 'Continue?' $true)) { return }
    }

    # ------------------------- Step 1: look at the PC ----------------------
    Write-Step 'Step 1 of 6: Checking your PC'
    try {
        $os  = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cs  = Get-CimInstance -ClassName Win32_ComputerSystem  -ErrorAction Stop
        $cpu = Get-CimInstance -ClassName Win32_Processor       -ErrorAction Stop | Select-Object -First 1
    } catch {
        Write-Bad ('Could not read system information: {0}' -f $_.Exception.Message)
        return
    }
    $build     = [int]$os.BuildNumber
    $hvPresent = [bool]$cs.HypervisorPresent
    $fwEnabled = $cpu.VirtualizationFirmwareEnabled
    $isVM      = ('{0} {1}' -f $cs.Manufacturer, $cs.Model) -match 'VMware|VirtualBox|innotek|Virtual|KVM|QEMU|Xen|HVM|Bochs|Parallels'

    Write-Info ('Windows : {0} (build {1})' -f $os.Caption, $build)
    Write-Info ('Computer: {0} {1}' -f $cs.Manufacturer, $cs.Model)

    if ($build -lt 19041) {
        Write-Bad 'This Windows version is too old for the "wsl --install" command (needs Windows 10 version 2004, build 19041 or newer, or Windows 11).'
        Write-Host '       Run Windows Update, then run this fixer again.'
        return
    }

    if ($isVM) {
        Write-Warn 'This looks like a virtual machine. WSL 2 inside a VM needs "nested virtualization" turned on in the host VM settings:'
        Write-Host '       VMware    : VM settings > Processors > Virtualize Intel VT-x/EPT or AMD-V/RVI'
        Write-Host '       VirtualBox: Settings > System > Processor > Enable Nested VT-x/AMD-V'
        Write-Host '       Hyper-V   : Set-VMProcessor -VMName <name> -ExposeVirtualizationExtensions $true'
        Write-Host '       If the host cannot do that, this fixer will offer WSL 1 instead.'
    } elseif ($hvPresent) {
        Write-Ok 'The Windows hypervisor is running, so virtualization is on.'
    } elseif ($fwEnabled -eq $false) {
        Write-Bad 'Virtualization is switched OFF in BIOS/UEFI (Intel VT-x / AMD-V / SVM).'
    } else {
        Write-Ok 'Virtualization is switched on in BIOS/UEFI.'
        Write-Warn 'But the Windows hypervisor is not running yet. Checking the Windows settings next.'
    }

    # ------------------- Step 2: Windows settings WSL 2 needs --------------
    Write-Step 'Step 2 of 6: Checking the Windows settings WSL 2 needs'

    $hlt = $null
    try {
        $bcd = (& bcdedit.exe /enum '{current}' 2>&1 | Out-String)
        if ($bcd -match '(?im)^\s*hypervisorlaunchtype\s+(\S+)') { $hlt = $Matches[1] }
    } catch { }

    $shown = 'not set'
    if ($hlt) { $shown = $hlt }
    if ($hlt -eq 'Auto') {
        Write-Ok 'Boot option hypervisorlaunchtype is Auto.'
    } elseif ($hvPresent -and (-not $isVM)) {
        Write-Ok ('The Windows hypervisor already runs (boot option hypervisorlaunchtype is {0}), nothing to change.' -f $shown)
    } else {
        Write-Warn ('Boot option hypervisorlaunchtype is {0}, so Windows is not told to start its hypervisor.' -f $shown)
        & bcdedit.exe /set hypervisorlaunchtype auto | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Save-PrevLaunchType $shown
            Write-Fix 'Set hypervisorlaunchtype to Auto (active after a restart).'
            $S.NeedReboot = $true
        } else {
            Write-Bad 'bcdedit could not change it.'
        }
    }

    Ensure-Feature 'Microsoft-Windows-Subsystem-Linux' 'Windows Subsystem for Linux'
    Ensure-Feature 'VirtualMachinePlatform'            'Virtual Machine Platform'

    # ------------------- Step 3: BIOS and restart decisions ----------------
    Write-Step 'Step 3 of 6: Restart check'

    $biosBlocked = (-not $isVM) -and (-not $hvPresent) -and ($fwEnabled -eq $false)
    if ($biosBlocked) {
        Write-Host ''
        Write-Bad 'Virtualization is OFF in BIOS/UEFI. WSL 2 cannot work until it is switched on, and no script can change that setting.'
        Write-Host '       In the BIOS look for "Intel Virtualization Technology" (VT-x) or "SVM Mode" / "AMD-V" and set it to Enabled.'
        Write-Host ''
        Write-Host '       [B] Restart now straight into the BIOS/UEFI settings (this fixer reopens afterwards)'
        Write-Host '       [W] Skip it and use WSL 1 instead (needs no virtualization)'
        Write-Host '       [Q] Back to the main menu'
        $c = Ask-Choice 'Choose B, W or Q' @('B','W','Q')
        if ($c -eq 'Q') { return }
        if ($c -eq 'B') {
            if (Start-WindowsRestart 'Restarting into the BIOS/UEFI firmware settings' $true) { exit 0 }
            Write-Warn 'This PC cannot restart straight into its firmware settings from Windows.'
            Write-Host '       Hold Shift while clicking Restart > Troubleshoot > Advanced options > UEFI Firmware Settings,'
            Write-Host '       or restart and press the BIOS key of your PC (often F2, F10, Del or Esc).'
            Write-Host '       Then run this fixer again.'
            return
        }
        $S.UseWsl1 = $true
    }

    if ($S.NeedReboot -and (-not $Resumed)) {
        if (Ask-Restart 'Windows settings were changed. A restart is needed before WSL can use them.') { exit 0 }
        Write-Info 'When you are ready: restart Windows (use Restart, not Shut down) and run this fixer again.'
        return
    }
    if ($S.NeedReboot -and $Resumed) {
        Write-Warn 'Windows still reports a pending change after the restart. Continuing anyway.'
    } else {
        Write-Ok 'No restart needed right now.'
    }

    # ------------------ Step 4: WSL package and hypervisor check -----------
    Write-Step 'Step 4 of 6: Updating WSL and checking the hypervisor'

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Bad 'wsl.exe was not found. Update Windows, then run this fixer again.'
        return
    }
    Write-Info 'Running: wsl --install --no-distribution'
    & wsl.exe --install --no-distribution
    if ($LASTEXITCODE -ne 0) { Write-Warn 'That command reported a problem (no internet?). Continuing.' }

    if ($isVM) {
        Write-Info 'Virtual machine: the Ubuntu install in the next step is the real test of nested virtualization.'
    } elseif ($hvPresent) {
        Write-Ok 'The Windows hypervisor is running.'
    } elseif (-not $S.UseWsl1) {
        Write-Bad 'The Windows hypervisor is still not running, so WSL 2 cannot start.'
        if (-not $Resumed) {
            Write-Host '       The settings look right now, so Windows probably just needs one restart to start it.'
            if (Ask-Restart 'Windows needs a restart to start its hypervisor.') { exit 0 }
        } else {
            Write-Host '       It still does not start after a restart. Common causes: another program (an Android emulator,'
            Write-Host '       an old VirtualBox or VMware) turned it off, or a Windows update problem. Check Windows Update.'
        }
        if (-not (Offer-Wsl1 'WSL 2 is not possible on this PC right now.')) { return }
    }

    # ----------------------- Step 5: Ubuntu on WSL -------------------------
    Write-Step 'Step 5 of 6: Ubuntu on WSL'

    if ($S.UseWsl1) {
        Write-Info 'Using WSL 1: wsl --set-default-version 1'
        & wsl.exe --set-default-version 1
    }
    Install-Ubuntu

    if ((-not $S.Distro) -and (-not $S.UseWsl1)) {
        Write-Bad 'Ubuntu could not be installed with WSL 2 (see the messages above).'
        if (-not (Offer-Wsl1 'Trying WSL 1 instead may work.')) { return }
        Write-Info 'Using WSL 1: wsl --set-default-version 1'
        & wsl.exe --set-default-version 1
        Install-Ubuntu
    }
    if (-not $S.Distro) {
        Write-Bad 'Ubuntu is still not installed. Please copy the messages above and ask for help.'
        return
    }

    $name = $S.Distro.Name
    Write-Ok ("Ubuntu is installed as '{0}'." -f $name)

    & wsl.exe -d $name -e true | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Info 'Ubuntu did not start yet. Opening it so the first-run setup (or the real error message) shows. Type exit to come back here.'
        & wsl.exe -d $name
        & wsl.exe -d $name -e true | Out-Null
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Ok 'Ubuntu starts correctly.'
    } else {
        Write-Bad 'Ubuntu still does not start. Read the error message above.'
        if ($S.Distro.Version -eq 2) {
            Write-Host ('       This is a WSL 2 distribution. If WSL 2 cannot run on this PC, remove it with:  wsl --unregister {0}' -f $name)
            Write-Host '       (that deletes its files), then run this fixer again to reinstall it with WSL 1.'
            Write-Host '       The Uninstall option in the main menu can do that for you.'
        }
        return
    }

    # ----------------------- Step 6: terminal effects ----------------------
    Write-Step 'Step 6 of 6: Terminal effects for your demo (cmatrix, hollywood)'

    # Only install what is missing. "command -v" is the same check the demo script uses.
    $missing = @()
    foreach ($pkg in @('cmatrix', 'hollywood')) {
        & wsl.exe -d $name -e bash -lc ('command -v {0} >/dev/null 2>&1' -f $pkg)
        if ($LASTEXITCODE -eq 0) {
            Write-Ok ('{0} is already installed.' -f $pkg)
        } else {
            $missing += $pkg
        }
    }

    # $effectsOk means: cmatrix is available for the quick test at the end.
    $effectsOk = ($missing -notcontains 'cmatrix')
    if (($missing.Count -gt 0) -and (Ask-YesNo ('Install {0} inside Ubuntu now? (runs as root, no password needed)' -f ($missing -join ' and ')) $true)) {
        Write-Info 'Running apt inside Ubuntu (this can take a few minutes)...'
        $aptCmd = 'export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y ' + ($missing -join ' ')
        & wsl.exe -d $name -u root -e bash -c $aptCmd
        if ($LASTEXITCODE -eq 0) {
            Write-Ok ('{0} installed.' -f ($missing -join ' and '))
            $effectsOk = $true
        } else {
            Write-Warn ('apt reported a problem. Open Ubuntu and run:  sudo apt update && sudo apt install {0}' -f ($missing -join ' '))
        }
    }

    Write-Host ''
    Write-Info 'Your WSL distributions:'
    & wsl.exe -l -v

    Write-Host ''
    Write-Host '=====================================================' -ForegroundColor Green
    Write-Host '  ALL DONE - WSL is ready.' -ForegroundColor Green
    Write-Host '  Run Windows-Hacker-Vibes-Demo.bat and pick option 5 (cmatrix) or 7 (hollywood).' -ForegroundColor Green
    Write-Host '=====================================================' -ForegroundColor Green
    if ($S.UseWsl1) {
        Write-Info 'You are on WSL 1. Once virtualization works, upgrade with:  wsl --set-version Ubuntu 2'
    }

    if ($effectsOk -and (Ask-YesNo 'Start cmatrix now as a quick test? (press Q to quit it)' $false)) {
        & wsl.exe -d $name -e cmatrix
    }
}

# ------------------------------ UNINSTALL ----------------------------------
function Invoke-Uninstall {
    $S.NeedReboot = $false

    # Look at what exists first. Nothing in this part runs wsl.exe: when WSL is not installed,
    # the wsl.exe that Windows ships only shows a "press any key to install" prompt.
    Write-Step 'Uninstall: what is installed right now'
    Write-Info 'Checking...'
    $wslPresent = Test-WslRuntime
    $all        = @(Get-WslDistros)
    $ubuntus    = @($all | Where-Object { $_.Name -like 'Ubuntu*' })
    $wslApps    = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $WslAppPattern })
    $ubuApps    = @($wslApps | Where-Object { $_.Name -like 'CanonicalGroupLimited.Ubuntu*' })

    if ($wslPresent) {
        Write-Info 'WSL program: installed'
    } else {
        Write-Info 'WSL program: not installed'
    }
    if ($all.Count -eq 0) {
        Write-Info 'WSL distributions: none'
    } else {
        foreach ($d in $all) { Write-Host ('       - ' + (Format-Distro $d)) }
    }

    # Nothing there: say so and stop. No wsl.exe, no prompts.
    if ((-not $wslPresent) -and ($all.Count -eq 0) -and ($wslApps.Count -eq 0)) {
        Write-Host ''
        Write-Ok 'WSL and Ubuntu are not installed. Nothing to remove.'
        if ((Get-FeatureState 'Microsoft-Windows-Subsystem-Linux') -eq 'DisablePending') {
            Write-Warn 'Windows still needs a restart to finish turning off the WSL feature.'
        }
        return
    }

    Write-Host ''
    Write-Host 'What should be removed?'
    Write-Host '  [1] Ubuntu only  - deletes the Ubuntu distro and everything inside it. WSL itself stays installed.'
    Write-Host '  [2] Everything   - deletes ALL WSL distros, removes the WSL program and turns off the WSL Windows feature.'
    Write-Host '  [B] Back to the main menu'
    $c = Ask-Choice 'Choose 1, 2 or B' @('1','2','B')
    if ($c -eq 'B') { return }

    # ------------------------- 1: Ubuntu only -----------------------------
    if ($c -eq '1') {
        if (($ubuntus.Count -eq 0) -and ($ubuApps.Count -eq 0)) {
            Write-Info 'Ubuntu is not installed. Nothing to remove.'
            return
        }
        Write-Host ''
        Write-Warn 'This permanently deletes these Ubuntu distros and ALL files, settings and software inside them:'
        foreach ($d in $ubuntus) { Write-Host ('       - {0}' -f $d.Name) }
        if ($ubuntus.Count -eq 0) { Write-Host '       (no distro files, only a leftover Ubuntu app)' }
        if (-not (Confirm-Typed 'REMOVE')) {
            Write-Info 'Cancelled. Nothing was removed.'
            return
        }
        Write-Step 'Removing Ubuntu'
        if ($ubuntus.Count -gt 0) {
            if ($wslPresent) {
                Stop-Wsl
                foreach ($d in $ubuntus) { Remove-Distro $d.Name }
            } else {
                Write-Warn 'WSL itself is not installed, so the Ubuntu distro entries cannot be unregistered from here.'
            }
        }
        if ($ubuApps.Count -gt 0) { Remove-AppxByPattern '^CanonicalGroupLimited\.Ubuntu' 'Ubuntu' }
        $left = @(Get-WslDistros | Where-Object { $_.Name -like 'Ubuntu*' })
        if ($left.Count -gt 0) {
            Write-Bad 'Some Ubuntu distros are still registered. Check them with:  wsl --list --verbose'
        } elseif ($wslPresent) {
            Write-Ok 'Ubuntu has been removed. WSL itself is still installed.'
        } else {
            Write-Ok 'Ubuntu has been removed.'
        }
        return
    }

    # --------------------------- 2: everything ----------------------------
    $docker = @($all | Where-Object { $_.Name -like 'docker-desktop*' })
    $prevHv = $null
    try { $prevHv = (Get-ItemProperty -Path $FixerKey -ErrorAction Stop).PrevHypervisorLaunchType } catch { }

    Write-Host ''
    Write-Warn 'This permanently deletes ALL files, settings and Linux software inside EVERY WSL distro listed above.'
    if ($docker.Count -gt 0) {
        Write-Bad 'Docker Desktop keeps its data in WSL. Your Docker images, containers and volumes will be deleted too.'
    }
    if (Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue) {
        Write-Warn 'Docker Desktop is running. Quit it first (tray icon, Quit Docker Desktop), or it can recreate its WSL data.'
    }
    Write-Host '       It also removes the WSL program and turns off the Windows feature "Windows Subsystem for Linux".'
    Write-Host '       Windows must restart to finish.'
    Write-Host ''
    $offVmp = Ask-YesNo 'Also turn off Virtual Machine Platform? Docker, Windows Sandbox and Android emulators may use it.' $false
    $restoreHv = $false
    if ($prevHv) {
        $restoreHv = Ask-YesNo ('Also put the boot option hypervisorlaunchtype back to its old value ({0})? Say no if you use Docker, Hyper-V or Windows Sandbox.' -f $prevHv) $false
    }
    if (-not (Confirm-Typed 'REMOVE')) {
        Write-Info 'Cancelled. Nothing was removed.'
        return
    }

    Write-Step 'Removing WSL'
    if ($wslPresent) {
        Stop-Wsl
        foreach ($d in $all) { Remove-Distro $d.Name }
        Write-Info 'Removing the WSL program: wsl --uninstall'
        & wsl.exe --uninstall
        if ($LASTEXITCODE -ne 0) { Write-Warn 'wsl --uninstall is not available here or reported a problem. Continuing.' }
    } elseif ($all.Count -gt 0) {
        Write-Warn 'WSL itself is not installed, so the leftover distro entries cannot be unregistered from here.'
    }
    Remove-AppxByPattern $WslAppPattern 'WSL and Linux distro'
    Disable-Feature 'Microsoft-Windows-Subsystem-Linux' 'Windows Subsystem for Linux'
    if ($offVmp) { Disable-Feature 'VirtualMachinePlatform' 'Virtual Machine Platform' }

    if ($restoreHv) {
        if ($prevHv -eq 'not set') {
            & bcdedit.exe /deletevalue hypervisorlaunchtype | Out-Null
        } else {
            & bcdedit.exe /set hypervisorlaunchtype $prevHv | Out-Null
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Fix ('Boot option hypervisorlaunchtype put back ({0}).' -f $prevHv)
            Remove-Item -Path $FixerKey -Recurse -ErrorAction SilentlyContinue
            $S.NeedReboot = $true
        } else {
            Write-Bad 'bcdedit could not put hypervisorlaunchtype back.'
        }
    }

    $left = @(Get-WslDistros)
    if ($left.Count -gt 0) {
        Write-Warn ('{0} distro(s) are still registered. Close the programs that use them and run the uninstall again.' -f $left.Count)
    }

    Write-Host ''
    Write-Ok 'Removal finished.'
    if ($S.NeedReboot) {
        if (Ask-Restart 'Windows must restart to finish removing WSL.' $false) { exit 0 }
        Write-Info 'OK. Restart Windows yourself (use Restart, not Shut down) to finish.'
        exit 0
    }
}

# ---------------------------------- main -----------------------------------
Clear-Host
Write-Host '=====================================================' -ForegroundColor Green
Write-Host '   WSL FIXER  -  install / repair / uninstall' -ForegroundColor Green
Write-Host '   (fixes HCS_E_HYPERV_NOT_INSTALLED, WSL 1 fallback)' -ForegroundColor Green
Write-Host '=====================================================' -ForegroundColor Green
Remove-Resume

# Coming back after an install restart: carry on with the install.
if ($Resumed) {
    Invoke-Install
    $Resumed = $false
}

while ($true) {
    $now   = @(Get-WslDistros)
    $names = @()
    foreach ($d in $now) { $names += (Format-Distro $d) }
    Write-Host ''
    if ($names.Count -eq 0) {
        Write-Info 'Installed WSL distros: none'
    } else {
        Write-Info ('Installed WSL distros: ' + ($names -join ', '))
    }
    Write-Host 'What do you want to do?' -ForegroundColor White
    Write-Host '  [1] Install / repair WSL + Ubuntu   (fixes the virtualization error, adds cmatrix + hollywood)'
    Write-Host '  [2] Uninstall                       (remove Ubuntu only, or all of WSL)'
    Write-Host '  [0] Exit'
    $choice = Ask-Choice 'Choose 1, 2 or 0' @('1','2','0')
    if ($choice -eq '1') {
        Invoke-Install
    } elseif ($choice -eq '2') {
        Invoke-Uninstall
    } else {
        break
    }
}
exit 0
