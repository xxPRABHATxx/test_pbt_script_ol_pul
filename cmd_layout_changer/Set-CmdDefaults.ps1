# Applies the Command Prompt appearance shown in the supplied screenshots to
# this Windows account's cmd.exe console profiles.
# Run in PowerShell. Use -WhatIf to preview the registry changes.

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Style1', 'Style2')]
    [string]$Style = 'Style1',
    [switch]$RestoreWindowsDefault
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Host "[FAILED] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkRed
    exit 1
}

$consoleRoot = 'HKCU:\Console'
$commandProcessorPath = 'HKCU:\Software\Microsoft\Command Processor'
if ($RestoreWindowsDefault) {
    if (-not $PSCmdlet.ShouldProcess($consoleRoot, 'Restore the original Windows CMD console defaults')) {
        Write-Host '[PREVIEW] Would restore the original Windows CMD console defaults.' -ForegroundColor Cyan
        return
    }

    if (Test-Path -LiteralPath $consoleRoot) {
        # Remove shared user overrides so CMD can use Windows' built-in defaults.
        $consoleKey = Get-Item -LiteralPath $consoleRoot
        foreach ($valueName in $consoleKey.GetValueNames()) {
            Remove-ItemProperty -LiteralPath $consoleRoot -Name $valueName -ErrorAction SilentlyContinue
        }

        Get-ChildItem -LiteralPath $consoleRoot |
            Where-Object { $_.PSChildName -match '(?i)_cmd\.exe$' } |
            ForEach-Object { Remove-Item -LiteralPath $_.PSPath -Recurse -Force }

        foreach ($title in @('Command Prompt', 'Administrator: Command Prompt', '%%Startup')) {
            $customPath = Join-Path $consoleRoot $title
            if (Test-Path -LiteralPath $customPath) {
                Remove-Item -LiteralPath $customPath -Recurse -Force
            }
        }
        $consoleKey = Get-Item -LiteralPath $consoleRoot -ErrorAction SilentlyContinue
        if ($consoleKey -and $consoleKey.GetValueNames().Count -eq 0 -and
            @(Get-ChildItem -LiteralPath $consoleRoot -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $consoleRoot -Force
        }
    }

    if (Test-Path -LiteralPath $commandProcessorPath) {
        $autoRunProperty = Get-ItemProperty -LiteralPath $commandProcessorPath -Name AutoRun -ErrorAction SilentlyContinue
        if ($autoRunProperty -and $autoRunProperty.AutoRun -match '(?i)Apply-CmdWindowStyle\.cmd') {
            $selectorPattern = '(?i)(?:^|&)\s*(?:call\s+)?(?:"[^"]*Apply-CmdWindowStyle\.cmd"|[^\s&]*Apply-CmdWindowStyle\.cmd)\s*(?=&|$)'
            $remainingAutoRun = [regex]::Replace([string]$autoRunProperty.AutoRun, $selectorPattern, '').Trim().Trim('&').Trim()
            if ([string]::IsNullOrWhiteSpace($remainingAutoRun)) {
                Remove-ItemProperty -LiteralPath $commandProcessorPath -Name AutoRun -ErrorAction SilentlyContinue
            } else {
                New-ItemProperty -LiteralPath $commandProcessorPath `
                    -Name AutoRun `
                    -Value $remainingAutoRun `
                    -PropertyType String `
                    -Force | Out-Null
            }
        }
        Remove-ItemProperty -LiteralPath $commandProcessorPath -Name CmdWindowStyleMode -ErrorAction SilentlyContinue

        $processorKey = Get-Item -LiteralPath $commandProcessorPath
        $processorSubkeys = @(Get-ChildItem -LiteralPath $commandProcessorPath -ErrorAction SilentlyContinue)
        if ($processorKey.GetValueNames().Count -eq 0 -and $processorSubkeys.Count -eq 0) {
            Remove-Item -LiteralPath $commandProcessorPath -Force
        }
    }

    Write-Host '[SUCCESS] Restored the Windows CMD defaults and removed the custom styles.' -ForegroundColor Green
    return
}

$standardProfileName = '%SystemRoot%_System32_cmd.exe'
$wow64ProfileName = '%SystemRoot%_SysWOW64_cmd.exe'

# Include the standard 64-bit and 32-bit Command Prompt profiles, plus any
# existing per-path cmd.exe profiles in this account's Console registry key.
$profileNames = @($standardProfileName, $wow64ProfileName)
if (Test-Path -LiteralPath $consoleRoot) {
    $profileNames += Get-ChildItem -LiteralPath $consoleRoot |
        Where-Object { $_.PSChildName -match '(?i)_cmd\.exe$' } |
        ForEach-Object { $_.PSChildName }
}
$profileNames = $profileNames | Sort-Object -Unique
$profiles = @(
    [pscustomobject]@{
        Label = 'shared console defaults'
        Path  = $consoleRoot
    }
)
foreach ($profileName in $profileNames) {
    $profiles += [pscustomobject]@{
        Label = $profileName
        Path  = Join-Path $consoleRoot $profileName
    }
}

# Values are packed in the same format used by the Windows Console registry.
$settings = [ordered]@{
    FaceName         = @{ Value = 'Consolas';        Type = 'String' }
    FontFamily       = @{ Value = 54;                Type = 'DWord' }
    FontSize         = @{ Value = 0x00140000;        Type = 'DWord' } # 20 px
    FontWeight       = @{ Value = 400;               Type = 'DWord' }
    ScreenBufferSize = @{ Value = 0x003D0079;        Type = 'DWord' } # 121 x 61
    WindowSize       = @{ Value = 0x00310079;        Type = 'DWord' } # 121 x 49
    WindowPosition   = @{ Value = 0x000B009B;        Type = 'DWord' } # left 155, top 11
    ScreenColors     = @{ Value = 0x0000000A;        Type = 'DWord' } # bright green on black
    PopupColors      = @{ Value = 0x0000000C;        Type = 'DWord' } # red on black
    ColorTable00     = @{ Value = 0x00000000;        Type = 'DWord' } # black background
    LineWrap         = @{ Value = 0;                 Type = 'DWord' } # unchecked in Layout tab
    DefaultForeground = @{ Value = 0xFFFFFFFF;       Type = 'DWord' } # separate terminal color disabled
    DefaultBackground = @{ Value = 0xFFFFFFFF;       Type = 'DWord' } # separate terminal color disabled
    CursorColor      = @{ Value = 0xFFFFFFFF;        Type = 'DWord' } # invert color
    TerminalScrolling = @{ Value = 0;                Type = 'DWord' } # scroll-forward enabled
    WindowAlpha      = @{ Value = 255;               Type = 'DWord' } # 100% opacity
}

# The second screenshot is the title-specific "Command Prompt" window profile.
$commandPromptTitleSettings = [ordered]@{
    FaceName                  = @{ Value = 'Consolas';        Type = 'String' }
    FontFamily                = @{ Value = 54;                Type = 'DWord' }
    FontSize                  = @{ Value = 0x00140000;        Type = 'DWord' }
    FontWeight                = @{ Value = 400;               Type = 'DWord' }
    ScreenBufferSize          = @{ Value = 0x003D0079;        Type = 'DWord' } # 121 x 61
    WindowSize                = @{ Value = 0x00300045;        Type = 'DWord' } # 69 x 48
    WindowPosition            = @{ Value = 0x000B04F9;        Type = 'DWord' } # left 1273, top 11
    ScreenColors              = @{ Value = 0x0000000A;        Type = 'DWord' }
    PopupColors               = @{ Value = 0x0000000C;        Type = 'DWord' }
    ColorTable00              = @{ Value = 0x000C0C0C;        Type = 'DWord' } # RGB 12, 12, 12
    LineWrap                  = @{ Value = 0;                 Type = 'DWord' }
    WindowAlpha               = @{ Value = 255;               Type = 'DWord' }
    CursorSize                = @{ Value = 25;                Type = 'DWord' } # Small
    CursorColor               = @{ Value = 0xFFFFFFFF;        Type = 'DWord' } # invert color
    DefaultForeground         = @{ Value = 0xFFFFFFFF;        Type = 'DWord' }
    DefaultBackground         = @{ Value = 0xFFFFFFFF;        Type = 'DWord' }
    TerminalScrolling         = @{ Value = 0;                 Type = 'DWord' }
    HistoryBufferSize         = @{ Value = 50;                Type = 'DWord' }
    NumberOfHistoryBuffers    = @{ Value = 4;                 Type = 'DWord' }
    HistoryNoDup              = @{ Value = 0;                 Type = 'DWord' }
    QuickEdit                 = @{ Value = 1;                 Type = 'DWord' }
    InsertMode                = @{ Value = 1;                 Type = 'DWord' }
    CtrlKeyShortcutsDisabled  = @{ Value = 0;                 Type = 'DWord' }
    FilterOnPaste             = @{ Value = 1;                 Type = 'DWord' }
    ExtendedEditKeyCustom     = @{ Value = 0;                 Type = 'DWord' }
    LineSelection             = @{ Value = 1;                 Type = 'DWord' }
    ExtendedEditKey           = @{ Value = 1;                 Type = 'DWord' }
    CodePage                  = @{ Value = 437;               Type = 'DWord' }
    ForceV2                   = @{ Value = 1;                 Type = 'DWord' }
}

if ($Style -eq 'Style2') {
    $style2WindowSize = @{ Value = 0x0030003E; Type = 'DWord' } # 62 x 48
    $style2WindowPosition = @{ Value = 0x000B00A8; Type = 'DWord' } # left 168, top 11
    $style2Background = @{ Value = 0x000C0C0C; Type = 'DWord' } # RGB 12, 12, 12
    $settings['WindowSize'] = $style2WindowSize
    $settings['WindowPosition'] = $style2WindowPosition
    $settings['ColorTable00'] = $style2Background
    $commandPromptTitleSettings['WindowSize'] = $style2WindowSize
    $commandPromptTitleSettings['WindowPosition'] = $style2WindowPosition
    $commandPromptTitleSettings['ColorTable00'] = $style2Background
}
foreach ($title in @('Command Prompt', 'Administrator: Command Prompt')) {
    $profiles += [pscustomobject]@{
        Label    = "title-specific '$title' window"
        Path     = Join-Path $consoleRoot $title
        Settings = $commandPromptTitleSettings
    }
}

$appliedProfileCount = 0
foreach ($profile in $profiles) {
    if (-not $PSCmdlet.ShouldProcess($profile.Path, "Set Command Prompt defaults ($($profile.Label))")) {
        continue
    }

    if (-not (Test-Path -LiteralPath $profile.Path)) {
        New-Item -Path $profile.Path | Out-Null
    }
    $profileSettings = $settings
    if ($profile.Settings) {
        $profileSettings = $profile.Settings
    }
    foreach ($entry in $profileSettings.GetEnumerator()) {
        New-ItemProperty -LiteralPath $profile.Path `
            -Name $entry.Key `
            -Value $entry.Value.Value `
            -PropertyType $entry.Value.Type `
            -Force | Out-Null
    }

    Write-Host "Applied defaults to: $($profile.Label)"
    $appliedProfileCount++
}

$startupPath = Join-Path $consoleRoot '%%Startup'
if ($PSCmdlet.ShouldProcess($startupPath, 'Set the default terminal application to Windows Console Host')) {
    if (-not (Test-Path -LiteralPath $startupPath)) {
        New-Item -Path $startupPath | Out-Null
    }
    $consoleHostId = '{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}'
    foreach ($name in @('DelegationTerminal', 'DelegationConsole')) {
        New-ItemProperty -LiteralPath $startupPath `
            -Name $name `
            -Value $consoleHostId `
            -PropertyType String `
            -Force | Out-Null
    }
    Write-Host 'Applied default terminal application: Windows Console Host'
    $appliedProfileCount++
}

$windowStyleCmd = Join-Path $PSScriptRoot 'Apply-CmdWindowStyle.cmd'
if (-not (Test-Path -LiteralPath $windowStyleCmd)) {
    throw "Automatic style selector is missing: $windowStyleCmd"
}
$commandProcessorPath = 'HKCU:\Software\Microsoft\Command Processor'
$styleModePath = Join-Path $commandProcessorPath 'CmdWindowStyleMode'
if ($PSCmdlet.ShouldProcess($styleModePath, "Set automatic CMD layout mode to $Style")) {
    if (-not (Test-Path -LiteralPath $commandProcessorPath)) {
        New-Item -Path $commandProcessorPath | Out-Null
    }
    New-ItemProperty -LiteralPath $commandProcessorPath `
        -Name CmdWindowStyleMode `
        -Value $Style `
        -PropertyType String `
        -Force | Out-Null
    Write-Host "Saved automatic CMD layout mode: $Style"
    $appliedProfileCount++
}

$existingAutoRun = $null
if (Test-Path -LiteralPath $commandProcessorPath) {
    $autoRunProperty = Get-ItemProperty -LiteralPath $commandProcessorPath -Name AutoRun -ErrorAction SilentlyContinue
    if ($autoRunProperty) {
        $existingAutoRun = [string]$autoRunProperty.AutoRun
    }
}

$autoRunCommand = 'call "' + $windowStyleCmd + '"'
$selectorInstalled = $existingAutoRun -and $existingAutoRun.IndexOf('Apply-CmdWindowStyle.cmd', [StringComparison]::OrdinalIgnoreCase) -ge 0
if (-not $selectorInstalled) {
    $autoRunPath = Join-Path $commandProcessorPath 'AutoRun'
    if ($PSCmdlet.ShouldProcess($autoRunPath, 'Run the selected CMD layout at startup')) {
        if (-not (Test-Path -LiteralPath $commandProcessorPath)) {
            New-Item -Path $commandProcessorPath | Out-Null
        }

        $autoRunPrefix = [string]$existingAutoRun
        while ($autoRunPrefix.TrimEnd().EndsWith('&')) {
            $autoRunPrefix = $autoRunPrefix.TrimEnd().TrimEnd('&').TrimEnd()
        }
        $newAutoRun = if ([string]::IsNullOrWhiteSpace($autoRunPrefix)) {
            $autoRunCommand
        } else {
            $autoRunPrefix + ' & ' + $autoRunCommand
        }
        New-ItemProperty -LiteralPath $commandProcessorPath `
            -Name AutoRun `
            -Value $newAutoRun `
            -PropertyType String `
            -Force | Out-Null
        Write-Host 'Installed automatic first/second CMD window style selection.'
        $appliedProfileCount++
    }
} else {
    Write-Host 'Automatic first/second CMD window style selection is already installed.'
}

if ($WhatIfPreference) {
    Write-Host '[PREVIEW] Complete. No registry values were changed.' -ForegroundColor Cyan
} elseif ($appliedProfileCount -gt 0) {
    Write-Host 'Close and reopen Command Prompt windows for the settings to take effect.'
    Write-Host "[SUCCESS] $Style settings were applied." -ForegroundColor Green
}
