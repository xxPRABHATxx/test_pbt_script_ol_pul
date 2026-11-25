# Manage-CustomApps.ps1
# Helper for Fresh-Windows-Option1-Updates-Runtimes.cmd. Keep it in the same folder as the .cmd file.
#
#   -Action Add        Option 5, Add: ask for an app, find it in Winget (or ask for a download link)
#                      and save it in a category, so it shows up in that category from now on.
#   -Action Remove     Option 5, Remove: list the apps you added to a category, let you pick the ones to
#                      take off the list, and delete their lines from the script. Nothing is uninstalled.
#   -Action Install    Download and install an app that was added from a link (-Force installs it again).
#   -Action Uninstall  Uninstall an app that was added from a link.
#   -Action Migrate    One time: move apps from the old Custom-Apps.txt into the script.
#
# The apps you add are stored inside the .cmd script itself: one line per app at the very end of the
# file, in the form ::APP|category|type|id|name|link|switches. Add appends a line. Remove deletes the
# chosen lines and rewrites only the end of the file, so the code above it is never touched.
#
# Exit codes: 0 = done, 1 = cancelled (Add and Remove only), 2 = error, 3010 = done but a restart is needed.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Remove', 'Install', 'Uninstall', 'Migrate')]
    [string]$Action,
    [string]$Category = '',
    [string]$Key = '',
    [string]$ScriptFile = '',
    [string]$LegacyFile = '',
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$script:ExitCode = 0
$CategoryNames = @{
    daily    = 'Everyday apps'
    dev      = 'IDEs and development tools'
    security = 'Security and network analysis tools'
}
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FreshWindowsSetup'

# ------------------------------------------------------------------ small helpers

function Read-Answer([string]$Prompt) {
    $answer = Read-Host $Prompt
    if ($null -eq $answer) { return '' }
    return $answer.Trim()
}

function Clean-Name([string]$Text) {
    if (-not $Text) { return '' }
    $clean = $Text -replace '[^A-Za-z0-9 .+_-]', ''
    $clean = ($clean -replace '\s+', ' ').Trim()
    if ($clean.Length -gt 40) { $clean = $clean.Substring(0, 40).Trim() }
    return $clean
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LastInt($Values) {
    $list = @($Values)
    if ($list.Count -eq 0) { return 1 }
    return [int]$list[$list.Count - 1]
}

# ------------------------------------------------------------------ the list of added apps

function Get-Entries {
    $items = @()
    if ($ScriptFile -and (Test-Path -LiteralPath $ScriptFile)) {
        foreach ($line in (Get-Content -LiteralPath $ScriptFile)) {
            $text = [string]$line
            if (-not $text.StartsWith('::APP|', [System.StringComparison]::Ordinal)) { continue }
            $f = $text.Substring(6).Trim().Split('|')
            if ($f.Count -lt 4) { continue }
            $url = ''
            $switches = ''
            if ($f.Count -ge 5) { $url = $f[4] }
            if ($f.Count -ge 6) { $switches = ($f[5..($f.Count - 1)] -join '|') }
            $items += [pscustomobject]@{
                Category = $f[0]
                Type     = $f[1]
                Id       = $f[2]
                Name     = $f[3]
                Url      = $url
                Switches = $switches
            }
        }
    }
    return $items
}

function Find-Entry([string]$Id) {
    foreach ($entry in @(Get-Entries)) {
        if ($entry.Id -ieq $Id) { return $entry }
    }
    return $null
}

function Find-EntryByName([string]$Name) {
    foreach ($entry in @(Get-Entries)) {
        if ($entry.Name -ieq $Name) { return $entry }
    }
    return $null
}

function Find-BuiltInCategory([string]$Id) {
    $lists = @(
        @{ Category = 'daily'; Ids = $env:BUILTIN_DAILY },
        @{ Category = 'dev'; Ids = $env:BUILTIN_DEV },
        @{ Category = 'security'; Ids = $env:BUILTIN_SECURITY }
    )
    foreach ($list in $lists) {
        if (-not $list.Ids) { continue }
        foreach ($builtIn in ($list.Ids -split '\s+')) {
            if ($builtIn -and ($builtIn -ieq $Id)) { return $list.Category }
        }
    }
    return $null
}

function Add-ScriptLine([string]$Line) {
    $text = $Line + "`r`n"
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            $stream = [System.IO.File]::Open($ScriptFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
            try {
                $prefix = ''
                if ($stream.Length -gt 0) {
                    [void]$stream.Seek(-1, [System.IO.SeekOrigin]::End)
                    if ($stream.ReadByte() -ne 10) { $prefix = "`r`n" }
                }
                $bytes = [System.Text.Encoding]::ASCII.GetBytes($prefix + $text)
                [void]$stream.Seek(0, [System.IO.SeekOrigin]::End)
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Flush()
            } finally {
                $stream.Close()
            }
            return
        } catch {
            if ($attempt -ge 5) { throw }
            Start-Sleep -Milliseconds 300
        }
    }
}

function Save-Entry([string]$CategoryKey, [string]$Type, [string]$Id, [string]$Name, [string]$Url, [string]$Switches) {
    $fields = @($CategoryKey, $Type, $Id, $Name, $Url, $Switches)
    Add-ScriptLine ('::APP|' + ($fields -join '|'))
}

# ------------------------------------------------------------------ Winget

function Get-WingetText([string[]]$WingetArgs) {
    $text = ''
    $previous = $null
    try {
        $previous = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch { }
    try {
        $text = (& winget.exe @WingetArgs 2>&1 | Out-String)
    } catch {
        $text = ''
    }
    if ($previous) {
        try { [Console]::OutputEncoding = $previous } catch { }
    }
    return $text
}

function Convert-WingetTable([string]$Text) {
    $found = @()
    if (-not $Text) { return $found }
    $lines = @()
    foreach ($rawLine in ($Text -split "`n")) {
        $line = $rawLine.TrimEnd([char]13)
        $cr = $line.LastIndexOf([char]13)
        if ($cr -ge 0) { $line = $line.Substring($cr + 1) }
        $line = $line -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
        $lines += $line
    }
    $sep = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^-{5,}\s*$') { $sep = $i; break }
    }
    if ($sep -lt 1) { return $found }
    $header = $lines[$sep - 1]
    $cols = [regex]::Matches($header, '\S+')
    if ($cols.Count -lt 3) { return $found }
    $idStart = $cols[1].Index
    $versionStart = $cols[2].Index
    for ($j = $sep + 1; $j -lt $lines.Count; $j++) {
        $row = $lines[$j]
        if ($row.Trim().Length -eq 0) { break }
        if ($row.Length -le $idStart) { continue }
        $end = [Math]::Min($versionStart, $row.Length)
        if ($end -le $idStart) { continue }
        $id = $row.Substring($idStart, $end - $idStart).Trim()
        $name = $row.Substring(0, $idStart).Trim()
        if ($id -match '^[A-Za-z0-9][A-Za-z0-9.+_-]{0,125}[A-Za-z0-9+_-]$') {
            $found += [pscustomobject]@{ Name = $name; Id = $id }
        }
    }
    return $found
}

function Search-Winget([string]$Query) {
    $text = Get-WingetText @('search', $Query, '--source', 'winget', '--accept-source-agreements', '--disable-interactivity')
    return (Convert-WingetTable $text)
}

function Get-WingetDetails([string]$Id) {
    $details = [pscustomobject]@{ Found = $false; Name = ''; Version = ''; Url = '' }
    $text = Get-WingetText @('show', '--id', $Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity')
    $details.Found = ($LASTEXITCODE -eq 0)
    $m = [regex]::Match($text, '(?im)^\s*Installer Url:\s*(\S+)')
    if ($m.Success) { $details.Url = $m.Groups[1].Value }
    $m = [regex]::Match($text, '(?im)^\s*Version:\s*([^\r\n]+)')
    if ($m.Success) { $details.Version = $m.Groups[1].Value.Trim() }
    $m = [regex]::Match($text, '(?m)^\S+\s+(.+?)\s+\[' + [regex]::Escape($Id) + '\]')
    if ($m.Success) { $details.Name = $m.Groups[1].Value.Trim() }
    return $details
}

# ------------------------------------------------------------------ download links

function Get-LinkInfo([string]$Url) {
    foreach ($method in @('HEAD', 'GET')) {
        $response = $null
        try {
            $request = [System.Net.HttpWebRequest]::Create($Url)
            $request.Method = $method
            $request.AllowAutoRedirect = $true
            $request.MaximumAutomaticRedirections = 10
            $request.Timeout = 30000
            $request.UserAgent = $UserAgent
            if ($method -eq 'GET') { $request.AddRange(0, 0) }
            $response = $request.GetResponse()

            $info = [pscustomobject]@{ ContentType = [string]$response.ContentType; FileName = ''; Size = [long]0 }

            $fileName = ''
            $disposition = [string]$response.Headers['Content-Disposition']
            if ($disposition) {
                $m = [regex]::Match($disposition, 'filename="?([^";]+)"?', 'IgnoreCase')
                if ($m.Success) { $fileName = $m.Groups[1].Value.Trim() }
                $m = [regex]::Match($disposition, "filename\*=UTF-8''([^;]+)", 'IgnoreCase')
                if ($m.Success) { $fileName = [Uri]::UnescapeDataString($m.Groups[1].Value.Trim()) }
            }
            if (-not $fileName) {
                $leaf = [System.IO.Path]::GetFileName($response.ResponseUri.AbsolutePath)
                if ($leaf) { $fileName = [Uri]::UnescapeDataString($leaf) }
            }
            $info.FileName = $fileName

            $size = [long]$response.ContentLength
            $range = [string]$response.Headers['Content-Range']
            if ($range -match '/(\d+)\s*$') { $size = [long]$Matches[1] }
            if ($size -lt 0) { $size = 0 }
            $info.Size = $size

            return $info
        } catch {
        } finally {
            if ($response) { $response.Close() }
        }
    }
    return $null
}

function Get-FileKind([string]$Path) {
    $head = New-Object byte[] 4
    $count = 0
    $stream = [System.IO.File]::OpenRead($Path)
    try { $count = $stream.Read($head, 0, 4) } finally { $stream.Close() }
    if ($count -ge 2 -and $head[0] -eq 0x4D -and $head[1] -eq 0x5A) { return 'exe' }
    if ($count -ge 4 -and $head[0] -eq 0xD0 -and $head[1] -eq 0xCF -and $head[2] -eq 0x11 -and $head[3] -eq 0xE0) { return 'msi' }
    if ($count -ge 2 -and $head[0] -eq 0x50 -and $head[1] -eq 0x4B) {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
            try {
                foreach ($entry in $zip.Entries) {
                    if ($entry.FullName -ieq 'AppxMetadata/AppxBundleManifest.xml') { return 'msixbundle' }
                    if ($entry.FullName -ieq 'AppxManifest.xml') { return 'msix' }
                }
            } finally { $zip.Dispose() }
        } catch { }
        return 'zip'
    }
    return 'unknown'
}

function Get-AutoSwitches([string]$Path) {
    $limit = 16MB
    $buffer = $null
    $count = 0
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $size = [int][Math]::Min($stream.Length, $limit)
        $buffer = New-Object byte[] $size
        $count = $stream.Read($buffer, 0, $size)
    } finally { $stream.Close() }
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString($buffer, 0, $count)
    if ($text.Contains('Inno Setup Setup Data')) { return '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' }
    if ($text.Contains('Nullsoft Install System')) { return '/S' }
    if ($text.Contains('.wixburn')) { return '/quiet /norestart' }
    return ''
}

# ------------------------------------------------------------------ Action: Add

function Add-FromWinget($Pick, $Details = $null) {
    $id = [string]$Pick.Id
    $name = Clean-Name ([string]$Pick.Name)
    if (-not $name) { $name = Clean-Name $id }
    if (-not $name) { $name = $id }

    $existing = Find-Entry $id
    if ($existing) {
        Write-Host ''
        Write-Host ("{0} is already in '{1}'. Nothing was added." -f $existing.Name, $CategoryNames[$existing.Category])
        $script:ExitCode = 1
        return
    }
    $builtInCategory = Find-BuiltInCategory $id
    if ($builtInCategory) {
        Write-Host ''
        Write-Host ("{0} is already included in '{1}'. Nothing was added." -f $name, $CategoryNames[$builtInCategory])
        $script:ExitCode = 1
        return
    }

    if ($null -eq $Details) {
        Write-Host ''
        Write-Host 'Reading the package details from Winget...'
        $Details = Get-WingetDetails $id
    }
    Write-Host ''
    Write-Host ('  App:      {0}' -f $name)
    Write-Host ('  Winget:   {0}' -f $id)
    if ($Details.Version) { Write-Host ('  Version:  {0}' -f $Details.Version) }
    if ($Details.Url) {
        Write-Host ('  Download: {0}' -f $Details.Url)
    } else {
        Write-Host '  Download: Winget fetches the installer itself.'
    }
    Write-Host ''
    $answer = Read-Answer ("Add this app to '{0}'? [Y/n]" -f $CategoryNames[$Category])
    if ($answer -match '^(n|no)$') {
        Write-Host 'Cancelled. Nothing was added.'
        $script:ExitCode = 1
        return
    }
    try {
        Save-Entry $Category 'winget' $id $name '' ''
    } catch {
        Write-Host ('Could not save the app inside the script: {0}' -f $ScriptFile)
        Write-Host $_.Exception.Message
        Write-Host 'The script file must be writable. Move the setup folder somewhere you can write to (Desktop, Documents or a USB drive) and try again.'
        $script:ExitCode = 2
        return
    }
    Write-Host ''
    Write-Host ("Added {0} to '{1}'." -f $name, $CategoryNames[$Category])
    Write-Host 'It now shows up in that category: pick it there to install, update or uninstall it.'
    Write-Host '"Install all" in that category includes it too.'
    Write-Host ('Saved inside this script: {0}' -f $ScriptFile)
    Write-Host 'To remove it later, use option 5 in the menu and choose Remove an app.'
}

function Add-FromLink([string]$Query) {
    $name = Clean-Name $Query
    if (-not $name) {
        Write-Host 'The app name needs at least one letter or digit.'
        $script:ExitCode = 1
        return
    }
    $already = Find-EntryByName $name
    if ($already) {
        Write-Host ("{0} is already in '{1}'. Nothing was added." -f $already.Name, $CategoryNames[$already.Category])
        $script:ExitCode = 1
        return
    }

    Write-Host ''
    Write-Host ("To add '{0}' you need the direct download link of its installer (.exe, .msi or .msix)." -f $name)
    Write-Host 'Only use links from the official website of the app.'
    Write-Host 'If you know the exact Winget package ID, you can type that here instead.'

    $url = ''
    for ($attempt = 1; $attempt -le 3 -and -not $url; $attempt++) {
        $text = Read-Answer 'Download link or Winget ID (press Enter to cancel)'
        if ($text.Length -eq 0) {
            Write-Host 'Cancelled. Nothing was added.'
            $script:ExitCode = 1
            return
        }
        $text = $text.Trim([char[]]@('"', "'", ' '))

        if (($text -notmatch '^(?i)https?://') -and ($text -match '^[A-Za-z0-9][A-Za-z0-9+_-]*(\.[A-Za-z0-9+_-]+)+$')) {
            if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
                Write-Host 'Winget is not available on this PC right now, so that ID cannot be checked.'
                continue
            }
            Write-Host ("Checking Winget for '{0}'..." -f $text)
            $details = Get-WingetDetails $text
            if (-not $details.Found) {
                Write-Host ("Winget has no package with the ID '{0}'." -f $text)
                continue
            }
            $pick = [pscustomobject]@{ Name = $details.Name; Id = $text }
            Add-FromWinget -Pick $pick -Details $details
            return
        }

        $uri = $null
        $validUri = [Uri]::TryCreate($text, [UriKind]::Absolute, [ref]$uri)
        if (-not $validUri -or (($uri.Scheme -ne 'https') -and ($uri.Scheme -ne 'http'))) {
            Write-Host 'That is not a web link. It must start with https://'
            continue
        }
        if ($uri.Scheme -eq 'http') {
            Write-Host 'This link is not encrypted (http). An https link from the official site is safer.'
            $go = Read-Answer 'Use it anyway? [y/N]'
            if ($go -notmatch '^(y|yes)$') { continue }
        }
        Write-Host 'Checking the link...'
        $info = Get-LinkInfo $uri.AbsoluteUri
        if ($null -eq $info) {
            Write-Host 'The link could not be checked. The site may block automated checks, or it is not reachable.'
            $go = Read-Answer 'Save it anyway? [y/N]'
            if ($go -notmatch '^(y|yes)$') { continue }
        } elseif ($info.ContentType -match '^text/html') {
            Write-Host 'That link opens a web page, not a file. Use the direct link to the installer file.'
            continue
        } else {
            Write-Host 'Link check: OK'
            if ($info.FileName) { Write-Host ('  File: {0}' -f $info.FileName) }
            if ($info.Size -gt 0) { Write-Host ('  Size: {0:N1} MB' -f ($info.Size / 1MB)) }
        }
        $url = $uri.AbsoluteUri
    }
    if (-not $url) {
        Write-Host 'No usable link was given. Nothing was added.'
        $script:ExitCode = 1
        return
    }

    Write-Host ''
    Write-Host 'Silent install switches, so the install needs no clicks:'
    Write-Host '  Enter = detect them automatically when installing (MSI, MSIX, Inno Setup, NSIS and WiX are recognized)'
    Write-Host '  or type the switches yourself, for example /S or /VERYSILENT /NORESTART'
    Write-Host '  none  = run the installer normally and click through it yourself'
    $switches = Read-Answer 'Switches'
    if ($switches.Length -eq 0) {
        $switches = 'auto'
    } elseif ($switches -ieq 'none') {
        $switches = 'none'
    } else {
        $switches = ($switches -replace '[^\x20-\x7E]', '') -replace '\|', ''
        $switches = $switches.Trim()
        if ($switches.Length -gt 200) { $switches = $switches.Substring(0, 200) }
        if ($switches.Length -eq 0) { $switches = 'auto' }
    }

    $slug = ($name.ToLower() -replace '[^a-z0-9]+', '-').Trim([char]45)
    if (-not $slug) { $slug = 'app' }
    $key = 'url-' + $slug
    $number = 2
    while (Find-Entry $key) {
        $key = 'url-' + $slug + '-' + $number
        $number++
    }

    Write-Host ''
    Write-Host ('  App:      {0}' -f $name)
    Write-Host ('  Link:     {0}' -f $url)
    Write-Host ('  Switches: {0}' -f $switches)
    Write-Host ''
    $answer = Read-Answer ("Add this app to '{0}'? [Y/n]" -f $CategoryNames[$Category])
    if ($answer -match '^(n|no)$') {
        Write-Host 'Cancelled. Nothing was added.'
        $script:ExitCode = 1
        return
    }
    try {
        Save-Entry $Category 'url' $key $name $url $switches
    } catch {
        Write-Host ('Could not save the app inside the script: {0}' -f $ScriptFile)
        Write-Host $_.Exception.Message
        Write-Host 'The script file must be writable. Move the setup folder somewhere you can write to (Desktop, Documents or a USB drive) and try again.'
        $script:ExitCode = 2
        return
    }
    Write-Host ''
    Write-Host ("Added {0} to '{1}'." -f $name, $CategoryNames[$Category])
    Write-Host 'It now shows up in that category: pick it there to install, update or uninstall it.'
    Write-Host 'Update downloads the saved link again and runs its installer. "Install all" includes it too.'
    Write-Host ('Saved inside this script: {0}' -f $ScriptFile)
    Write-Host 'To remove it later, use option 5 in the menu and choose Remove an app.'
}

function Invoke-Add {
    if (-not $CategoryNames.ContainsKey($Category)) {
        Write-Host ("Unknown category '{0}'." -f $Category)
        $script:ExitCode = 2
        return
    }
    Write-Host ''
    Write-Host ('Add an app to: {0}' -f $CategoryNames[$Category])
    Write-Host 'The app is looked up in Winget first. If Winget does not have it, you can paste a download link.'
    Write-Host ''
    $query = (Read-Answer 'App name to add (press Enter to cancel)').Replace('"', '').TrimStart([char]45).Trim()
    if ($query.Length -eq 0) {
        Write-Host 'Cancelled. Nothing was added.'
        $script:ExitCode = 1
        return
    }

    $results = @()
    $wingetAvailable = [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
    if ($wingetAvailable) {
        Write-Host ''
        Write-Host ("Looking for '{0}' in Winget..." -f $query)
        $results = @(Search-Winget $query)
    } else {
        Write-Host ''
        Write-Host 'Winget is not available on this PC right now, so a download link is needed.'
    }
    if ($results.Count -eq 0) {
        if ($wingetAvailable) { Write-Host ("Winget has no package that matches '{0}'." -f $query) }
        Add-FromLink $query
        return
    }

    $shown = @($results | Select-Object -First 9)
    $default = 1
    for ($i = 0; $i -lt $shown.Count; $i++) {
        if (($shown[$i].Name -ieq $query) -or ($shown[$i].Id -ieq $query)) { $default = $i + 1; break }
    }
    Write-Host ''
    Write-Host 'Winget found these matches:'
    for ($i = 0; $i -lt $shown.Count; $i++) {
        Write-Host ('  {0}. {1}  [{2}]' -f ($i + 1), $shown[$i].Name, $shown[$i].Id)
    }
    Write-Host '  0. None of these - use a download link instead'
    while ($true) {
        $answer = Read-Answer ('Choose a number (press Enter for {0}, Q to cancel)' -f $default)
        if ($answer -match '^[Qq]$') {
            Write-Host 'Cancelled. Nothing was added.'
            $script:ExitCode = 1
            return
        }
        if ($answer.Length -eq 0) {
            $choice = $shown[$default - 1]
            Add-FromWinget -Pick $choice
            return
        }
        if ($answer -match '^\d+$') {
            $number = [int]$answer
            if ($number -eq 0) {
                Add-FromLink $query
                return
            }
            if ($number -ge 1 -and $number -le $shown.Count) {
                $choice = $shown[$number - 1]
                Add-FromWinget -Pick $choice
                return
            }
        }
        Write-Host 'Please type one of the numbers above.'
    }
}

# ------------------------------------------------------------------ Action: Remove

function Read-StreamText([System.IO.Stream]$Stream) {
    # The whole file as text. Latin-1 turns every byte into exactly one character, so a position in the
    # text is a position in the file, and writing text back changes nothing that was not meant to change.
    [void]$Stream.Seek(0, [System.IO.SeekOrigin]::Begin)
    $size = [int]$Stream.Length
    $buffer = New-Object byte[] $size
    $done = 0
    while ($done -lt $size) {
        $got = $Stream.Read($buffer, $done, $size - $done)
        if ($got -le 0) { break }
        $done += $got
    }
    return [System.Text.Encoding]::GetEncoding(28591).GetString($buffer, 0, $done)
}

function Read-ScriptText {
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            $stream = [System.IO.File]::Open($ScriptFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                return (Read-StreamText $stream)
            } finally {
                $stream.Close()
            }
        } catch {
            if ($attempt -ge 5) { throw }
            Start-Sleep -Milliseconds 300
        }
    }
}

function Get-ScriptLineInfo([string]$Content) {
    # Splits the script text into lines. For each line: where it starts, the full text with its line
    # ending, and the text without the line ending.
    $lines = @()
    $pos = 0
    while ($pos -lt $Content.Length) {
        $lf = $Content.IndexOf([char]10, $pos)
        if ($lf -lt 0) { $end = $Content.Length } else { $end = $lf + 1 }
        $full = $Content.Substring($pos, $end - $pos)
        $lines += [pscustomobject]@{
            Start = $pos
            Full  = $full
            Text  = $full.TrimEnd([char[]]@([char]13, [char]10))
        }
        $pos = $end
    }
    return $lines
}

function Get-AddedApps([string]$Content) {
    # Every ::APP| line of the script, in file order.
    $apps = @()
    foreach ($line in (Get-ScriptLineInfo $Content)) {
        if (-not $line.Text.StartsWith('::APP|', [System.StringComparison]::Ordinal)) { continue }
        $f = $line.Text.Substring(6).Trim().Split('|')
        if ($f.Count -lt 4) { continue }
        $apps += [pscustomobject]@{
            Category = $f[0]
            Type     = $f[1]
            Id       = $f[2]
            Name     = $f[3]
            Start    = $line.Start
            Text     = $line.Text
        }
    }
    return $apps
}

function Write-AppColumns($Apps) {
    # Prints the numbered app names in as many columns as fit in the window, so a long list stays on screen.
    $labels = @()
    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $labels += ('{0,3}. {1}' -f ($i + 1), $Apps[$i].Name)
    }
    $widest = 0
    foreach ($label in $labels) {
        if ($label.Length -gt $widest) { $widest = $label.Length }
    }
    $cell = $widest + 3
    $width = 100
    try { $width = [int]$Host.UI.RawUI.WindowSize.Width } catch { }
    if ($width -lt 40) { $width = 100 }
    $columns = [Math]::Max(1, [int][Math]::Floor([double]($width - 2) / $cell))
    $rows = [int][Math]::Ceiling([double]$labels.Count / $columns)
    for ($r = 0; $r -lt $rows; $r++) {
        $text = '  '
        for ($c = 0; $c -lt $columns; $c++) {
            $index = $c * $rows + $r
            if ($index -ge $labels.Count) { continue }
            $text += $labels[$index].PadRight($cell)
        }
        Write-Host $text.TrimEnd()
    }
}

function Read-Selection([int]$Count) {
    # Asks which apps to remove. Accepts 3, or 2 5 9, or 4-8, or a mix, or A for all.
    # Returns the chosen numbers (sorted, no repeats), or $null when the answer is empty (cancel).
    while ($true) {
        $answer = Read-Answer 'Numbers to remove, like 3 or 2 5 9 or 4-8 (A = all, Enter = cancel)'
        if ($answer.Length -eq 0) { return $null }
        if ($answer -match '^(a|all)$') { return @(1..$Count) }
        $answer = $answer -replace '\s*-\s*', '-'
        $picked = @{}
        $bad = $false
        foreach ($part in ($answer -split '[\s,;]+')) {
            if ($part.Length -eq 0) { continue }
            $low = 0
            $high = 0
            if ($part -match '^(\d{1,4})$') {
                $low = [int]$Matches[1]
                $high = $low
            } elseif ($part -match '^(\d{1,4})-(\d{1,4})$') {
                $low = [int]$Matches[1]
                $high = [int]$Matches[2]
            } else {
                $bad = $true
                break
            }
            if ($low -lt 1 -or $high -gt $Count -or $low -gt $high) {
                $bad = $true
                break
            }
            for ($n = $low; $n -le $high; $n++) { $picked[$n] = $true }
        }
        if ($bad -or $picked.Count -eq 0) {
            Write-Host ('Please type numbers from 1 to {0}, ranges like 4-8, or A for all.' -f $Count)
            continue
        }
        return @($picked.Keys | Sort-Object)
    }
}

function Remove-ScriptApps($Chosen) {
    # Deletes the chosen ::APP| lines from the script and returns how many were deleted (0 = nothing changed).
    # Only the part of the file from the first deleted line to the end is rewritten. Everything above it,
    # which includes the code that is running right now, is not touched.
    $latin1 = [System.Text.Encoding]::GetEncoding(28591)
    $stream = $null
    for ($attempt = 1; $attempt -le 5 -and $null -eq $stream; $attempt++) {
        try {
            $stream = [System.IO.File]::Open($ScriptFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
        } catch {
            if ($attempt -ge 5) { throw }
            Start-Sleep -Milliseconds 300
        }
    }
    try {
        $content = Read-StreamText $stream
        $current = @(Get-AddedApps $content)

        # Find every chosen line again in the file as it is right now.
        $drop = @{}
        foreach ($app in $Chosen) {
            $hit = $null
            foreach ($candidate in $current) {
                if ($drop.ContainsKey($candidate.Start)) { continue }
                if ($candidate.Text -ceq $app.Text) { $hit = $candidate; break }
            }
            if ($null -eq $hit) { return 0 }
            $drop[$hit.Start] = $true
        }

        $first = [int]::MaxValue
        foreach ($position in $drop.Keys) {
            if ($position -lt $first) { $first = $position }
        }
        $tail = New-Object System.Text.StringBuilder
        foreach ($line in (Get-ScriptLineInfo $content)) {
            if ($line.Start -lt $first) { continue }
            if ($drop.ContainsKey($line.Start)) { continue }
            [void]$tail.Append($line.Full)
        }
        $bytes = $latin1.GetBytes($tail.ToString())
        [void]$stream.Seek([long]$first, [System.IO.SeekOrigin]::Begin)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.SetLength([long]$first + $bytes.Length)
        $stream.Flush()
    } finally {
        $stream.Close()
    }
    return $drop.Count
}

function Invoke-Remove {
    if (-not $CategoryNames.ContainsKey($Category)) {
        Write-Host ("Unknown category '{0}'." -f $Category)
        $script:ExitCode = 2
        return
    }
    if (-not $ScriptFile -or -not (Test-Path -LiteralPath $ScriptFile)) {
        Write-Host 'The setup script was not found, so nothing can be removed.'
        $script:ExitCode = 2
        return
    }
    $categoryName = $CategoryNames[$Category]
    $apps = @(Get-AddedApps (Read-ScriptText) | Where-Object { $_.Category -ieq $Category })

    try { Clear-Host } catch { }
    Write-Host '============================================================'
    Write-Host ('Option 5 - Remove an app from: {0}' -f $categoryName)
    Write-Host '============================================================'
    if ($apps.Count -eq 0) {
        Write-Host ("No apps have been added to '{0}' yet, so there is nothing to remove." -f $categoryName)
        Write-Host 'Only apps that were added with "Add an app" can be removed here. The apps built into the script stay.'
        $script:ExitCode = 1
        return
    }
    Write-Host 'Only apps that were added with "Add an app" are listed. The apps built into the script stay.'
    Write-Host 'Removing an app only takes it off the list. It is not uninstalled from this PC.'
    Write-Host ''
    Write-AppColumns $apps
    Write-Host ''

    $numbers = Read-Selection $apps.Count
    if ($null -eq $numbers) {
        Write-Host 'Cancelled. Nothing was removed.'
        $script:ExitCode = 1
        return
    }
    $chosen = @()
    foreach ($n in @($numbers)) { $chosen += $apps[$n - 1] }

    Write-Host ''
    Write-Host ("You are about to remove {0} app(s) from '{1}':" -f $chosen.Count, $categoryName)
    $show = [Math]::Min($chosen.Count, 12)
    for ($i = 0; $i -lt $show; $i++) {
        if ($chosen[$i].Type -eq 'url') {
            Write-Host ('  {0}  (download link)' -f $chosen[$i].Name)
        } else {
            Write-Host ('  {0}  [{1}]' -f $chosen[$i].Name, $chosen[$i].Id)
        }
    }
    if ($chosen.Count -gt $show) { Write-Host ('  ... and {0} more' -f ($chosen.Count - $show)) }
    Write-Host ''
    $answer = Read-Answer 'Remove them from the list? They are not uninstalled. [y/N]'
    if ($answer -notmatch '^(y|yes)$') {
        Write-Host 'Cancelled. Nothing was removed.'
        $script:ExitCode = 1
        return
    }

    $removed = 0
    try {
        $removed = Get-LastInt (Remove-ScriptApps $chosen)
    } catch {
        Write-Host ('Could not change the script: {0}' -f $ScriptFile)
        Write-Host $_.Exception.Message
        Write-Host 'The script file must be writable. Move the setup folder somewhere you can write to (Desktop, Documents or a USB drive) and try again.'
        $script:ExitCode = 2
        return
    }
    if ($removed -lt 1) {
        Write-Host 'The script changed while you were choosing, so nothing was removed. Open Remove again and try once more.'
        $script:ExitCode = 2
        return
    }
    Write-Host ''
    Write-Host ("Removed {0} app(s) from '{1}'." -f $removed, $categoryName)
    Write-Host 'They no longer show up in that category, and "Install all" skips them.'
    Write-Host 'They were not uninstalled from this PC. To put one back, use Add an app.'
}

# ------------------------------------------------------------------ Action: Install

function Install-Exe([string]$Path, [string]$Switches) {
    $argLine = ''
    if ($Switches -ieq 'auto') {
        $argLine = Get-AutoSwitches $Path
        if ($argLine) {
            Write-Host ('Detected silent switches: {0}' -f $argLine)
        } else {
            Write-Host 'Silent switches could not be detected. The installer opens normally; finish it in its window.'
        }
    } elseif ($Switches -ieq 'none') {
        Write-Host 'Running the installer normally; finish it in its window.'
    } else {
        $argLine = $Switches
        Write-Host ('Using your switches: {0}' -f $argLine)
    }
    Write-Host 'Running the installer...'
    try {
        if ($argLine) {
            $process = Start-Process -FilePath $Path -ArgumentList $argLine -Wait -PassThru -ErrorAction Stop
        } else {
            $process = Start-Process -FilePath $Path -Wait -PassThru -ErrorAction Stop
        }
    } catch {
        Write-Host ('Could not start the installer: {0}' -f $_.Exception.Message)
        return 1223
    }
    return [int]$process.ExitCode
}

function Install-Msi([string]$Path, [string]$Switches) {
    $extra = '/qn /norestart'
    if ($Switches -ieq 'none') {
        $extra = ''
    } elseif ($Switches -and ($Switches -ine 'auto')) {
        $extra = $Switches
    }
    $argLine = ('/i "{0}" {1}' -f $Path, $extra).Trim()
    Write-Host ('Running: msiexec.exe {0}' -f $argLine)
    try {
        if (Test-Admin) {
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argLine -Wait -PassThru -ErrorAction Stop
        } else {
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argLine -Wait -PassThru -Verb RunAs -ErrorAction Stop
        }
    } catch {
        Write-Host ('Could not start the installer: {0}' -f $_.Exception.Message)
        return 1223
    }
    return [int]$process.ExitCode
}

function Install-Msix([string]$Path) {
    Write-Host 'Installing the package...'
    try {
        Add-AppxPackage -Path $Path -ErrorAction Stop
        return 0
    } catch {
        Write-Host ('Could not install the package: {0}' -f $_.Exception.Message)
        return 1
    }
}

function Find-Installed([string]$Name) {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $pattern = '*' + $Name + '*'
    $hits = @()
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($item in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -LiteralPath $item.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $p) { continue }
            $display = [string]$p.DisplayName
            if (-not $display) { continue }
            if ($p.SystemComponent -eq 1) { continue }
            if ($display -like $pattern) {
                $hits += [pscustomobject]@{
                    DisplayName = $display
                    Quiet       = [string]$p.QuietUninstallString
                    Uninstall   = [string]$p.UninstallString
                }
            }
        }
    }
    return @($hits | Sort-Object DisplayName -Unique)
}

function Invoke-Install {
    $entry = Find-Entry $Key
    if ($null -eq $entry -or $entry.Type -ne 'url') {
        Write-Host ("No saved download link was found for '{0}' in {1}" -f $Key, $ScriptFile)
        $script:ExitCode = 2
        return
    }
    $name = $entry.Name
    if (-not $Force) {
        $installed = @(Find-Installed $name)
        if ($installed.Count -gt 0) {
            Write-Host ("{0} looks installed already ({1}). Skipping. Use Update to install it again." -f $name, $installed[0].DisplayName)
            return
        }
    }

    $work = Join-Path $env:TEMP ('FreshWindowsCustom-' + [Guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $work -Force)
    try {
        $download = Join-Path $work 'download.bin'
        Write-Host ('Downloading {0}...' -f $name)
        Write-Host ('  {0}' -f $entry.Url)
        Invoke-WebRequest -Uri $entry.Url -OutFile $download -UseBasicParsing -MaximumRedirection 10 -UserAgent $UserAgent -ErrorAction Stop

        $kind = Get-FileKind $download
        Write-Host ('Downloaded. File type: {0}' -f $kind)
        $code = 1
        switch ($kind) {
            'exe' {
                $file = Join-Path $work 'setup.exe'
                Move-Item -LiteralPath $download -Destination $file -Force
                $code = Get-LastInt (Install-Exe $file $entry.Switches)
            }
            'msi' {
                $file = Join-Path $work 'setup.msi'
                Move-Item -LiteralPath $download -Destination $file -Force
                $code = Get-LastInt (Install-Msi $file $entry.Switches)
            }
            'msix' {
                $file = Join-Path $work 'setup.msix'
                Move-Item -LiteralPath $download -Destination $file -Force
                $code = Get-LastInt (Install-Msix $file)
            }
            'msixbundle' {
                $file = Join-Path $work 'setup.msixbundle'
                Move-Item -LiteralPath $download -Destination $file -Force
                $code = Get-LastInt (Install-Msix $file)
            }
            default {
                throw ('The downloaded file is a {0} file, not an installer (.exe, .msi or .msix). Add the app again with the direct link to the installer.' -f $kind)
            }
        }

        if ($code -eq 0 -or $code -eq 1641) {
            Write-Host ('{0} was installed.' -f $name)
        } elseif ($code -eq 3010) {
            Write-Host ('{0} was installed. Restart Windows to finish.' -f $name)
            $script:ExitCode = 3010
        } else {
            Write-Host ('The installer for {0} returned exit code {1}.' -f $name, $code)
            $script:ExitCode = $code
        }
    } catch {
        Write-Host ('Could not install {0}: {1}' -f $name, $_.Exception.Message)
        $script:ExitCode = 2
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------------ Action: Uninstall

function Get-UninstallCommand($Target) {
    if ($Target.Quiet) { return $Target.Quiet }
    $text = $Target.Uninstall
    if (-not $text) { return '' }
    $guid = [regex]::Match($text, '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}')
    if (($text -match '(?i)msiexec') -and $guid.Success) {
        return ('msiexec.exe /x ' + $guid.Value + ' /qn /norestart')
    }
    if ($text -match '(?i)unins\d{3}\.exe') { return ($text + ' /VERYSILENT /SUPPRESSMSGBOXES /NORESTART') }
    if ($text -match '(?i)uninst(all)?\.exe') { return ($text + ' /S') }
    return $text
}

function Invoke-UninstallCommand([string]$CommandLine) {
    $argLine = '/d /s /c "' + $CommandLine + '"'
    try {
        if (Test-Admin) {
            $process = Start-Process -FilePath 'cmd.exe' -ArgumentList $argLine -Wait -PassThru -ErrorAction Stop
        } else {
            $process = Start-Process -FilePath 'cmd.exe' -ArgumentList $argLine -Wait -PassThru -Verb RunAs -ErrorAction Stop
        }
    } catch {
        Write-Host ('Could not start the uninstaller: {0}' -f $_.Exception.Message)
        return 1223
    }
    return [int]$process.ExitCode
}

function Invoke-Uninstall {
    $entry = Find-Entry $Key
    if ($null -eq $entry) {
        Write-Host ("'{0}' is not in {1}" -f $Key, $ScriptFile)
        $script:ExitCode = 2
        return
    }
    $name = $entry.Name
    $hits = @(Find-Installed $name)
    if ($hits.Count -eq 0) {
        Write-Host ("{0} was not found in the installed programs list, so there is nothing to uninstall." -f $name)
        Write-Host 'If it was installed as an app package, remove it in Settings, Apps, Installed apps.'
        return
    }

    $target = $null
    $exact = @($hits | Where-Object { $_.DisplayName -ieq $name })
    if ($exact.Count -eq 1) {
        $target = $exact[0]
    } elseif ($hits.Count -eq 1) {
        $target = $hits[0]
    } else {
        Write-Host 'More than one installed program matches:'
        for ($i = 0; $i -lt $hits.Count; $i++) {
            Write-Host ('  {0}. {1}' -f ($i + 1), $hits[$i].DisplayName)
        }
        Write-Host '  0. Cancel'
        $answer = Read-Answer 'Which one should be uninstalled'
        if ($answer -match '^\d+$') {
            $number = [int]$answer
            if ($number -ge 1 -and $number -le $hits.Count) { $target = $hits[$number - 1] }
        }
        if ($null -eq $target) {
            Write-Host 'Cancelled. Nothing was uninstalled.'
            return
        }
    }

    $answer = Read-Answer ("Uninstall '{0}'? [Y/n]" -f $target.DisplayName)
    if ($answer -match '^(n|no)$') {
        Write-Host 'Cancelled. Nothing was uninstalled.'
        return
    }
    $command = Get-UninstallCommand $target
    if (-not $command) {
        Write-Host 'Windows has no uninstall command for this program. Remove it in Settings, Apps, Installed apps.'
        $script:ExitCode = 2
        return
    }
    Write-Host ('Uninstalling {0}...' -f $target.DisplayName)
    $code = Get-LastInt (Invoke-UninstallCommand $command)
    if ($code -eq 0 -or $code -eq 1641) {
        Write-Host ('{0} was uninstalled.' -f $target.DisplayName)
    } elseif ($code -eq 3010) {
        Write-Host ('{0} was uninstalled. Restart Windows to finish.' -f $target.DisplayName)
        $script:ExitCode = 3010
    } else {
        Write-Host ('The uninstaller returned exit code {0}.' -f $code)
        $script:ExitCode = $code
    }
}

# ------------------------------------------------------------------ Action: Migrate

function Invoke-Migrate {
    if (-not $LegacyFile -or -not (Test-Path -LiteralPath $LegacyFile)) { return }
    $moved = 0
    foreach ($line in (Get-Content -LiteralPath $LegacyFile)) {
        $text = ([string]$line).Trim()
        if ($text.Length -eq 0 -or $text.StartsWith('#', [System.StringComparison]::Ordinal)) { continue }
        if ($text -notmatch '^[\x20-\x7E]+$') { continue }
        $f = $text.Split('|')
        if ($f.Count -lt 4) { continue }
        if ($f[0] -notmatch '^(daily|dev|security)$') { continue }
        if ($f[1] -notmatch '^(winget|url)$') { continue }
        if ($f[2] -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]*$') { continue }
        if (Find-Entry $f[2]) { continue }
        Add-ScriptLine ('::APP|' + $text)
        $moved++
    }
    Move-Item -LiteralPath $LegacyFile -Destination ($LegacyFile + '.migrated') -Force
    Write-Host ('Moved {0} app(s) from Custom-Apps.txt into this script. The old file was renamed to Custom-Apps.txt.migrated.' -f $moved)
}

# ------------------------------------------------------------------ run

try {
    switch ($Action) {
        'Add'       { Invoke-Add }
        'Remove'    { Invoke-Remove }
        'Install'   { Invoke-Install }
        'Uninstall' { Invoke-Uninstall }
        'Migrate'   { Invoke-Migrate }
    }
} catch {
    Write-Host ('Something went wrong: {0}' -f $_.Exception.Message)
    $script:ExitCode = 2
}
exit $script:ExitCode
