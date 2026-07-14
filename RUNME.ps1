[CmdletBinding()]
param(
    [switch]$Play,
    [switch]$Yes,
    [switch]$NoLaunch
)

# Bent Chrome - one-shot Windows player installer.
# Compatible with the Windows PowerShell 5.1 included with Windows 10 and 11.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$GodotVersion = '4.7-stable'
$GodotVersionTag = '4.7.stable'
$ReleaseBase = "https://github.com/godotengine/godot-builds/releases/download/$GodotVersion"
$RepoDir = $PSScriptRoot
$InstallDir = Join-Path $env:LOCALAPPDATA 'BentChrome\Godot\4.7'
$BinDir = Join-Path $env:LOCALAPPDATA 'BentChrome\bin'
$ShimPath = Join-Path $BinDir 'godot.cmd'

function Write-Info([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "OK  $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "WARN $Message" -ForegroundColor Yellow }

function Confirm-YesNo {
    param([string]$Prompt, [bool]$DefaultYes = $true)
    if ($Yes) {
        Write-Host "$Prompt [auto: $DefaultYes]"
        return $DefaultYes
    }
    $hint = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $reply = Read-Host "$Prompt $hint"
    if ([string]::IsNullOrWhiteSpace($reply)) { return $DefaultYes }
    return $reply.StartsWith('y', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ArchitectureDetails {
    $architecture = $env:PROCESSOR_ARCHITEW6432
    if ([string]::IsNullOrWhiteSpace($architecture)) {
        $architecture = $env:PROCESSOR_ARCHITECTURE
    }
    switch ($architecture.ToUpperInvariant()) {
        'AMD64' {
            return @{
                Asset = "Godot_v${GodotVersion}_win64.exe.zip"
                Gui = "Godot_v${GodotVersion}_win64.exe"
                Console = "Godot_v${GodotVersion}_win64_console.exe"
            }
        }
        'ARM64' {
            return @{
                Asset = "Godot_v${GodotVersion}_windows_arm64.exe.zip"
                Gui = "Godot_v${GodotVersion}_windows_arm64.exe"
                Console = "Godot_v${GodotVersion}_windows_arm64_console.exe"
            }
        }
        default { throw "Unsupported Windows architecture '$architecture'. Bent Chrome supports x64 and ARM64." }
    }
}

function Get-InstalledGodot {
    $details = Get-ArchitectureDetails
    $installedConsole = Join-Path $InstallDir $details.Console
    if (Test-Path -LiteralPath $installedConsole -PathType Leaf) { return $installedConsole }
    $command = Get-Command godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) { return $command.Source }
    return $null
}

function Test-GodotVersion([string]$GodotPath) {
    if ([string]::IsNullOrWhiteSpace($GodotPath)) { return $false }
    try {
        $reported = (& $GodotPath --version 2>$null | Select-Object -First 1)
        return "$reported".StartsWith($GodotVersionTag, [System.StringComparison]::Ordinal)
    } catch {
        return $false
    }
}

function Install-Godot {
    Write-Info "Setting up Godot $GodotVersion..."
    $details = Get-ArchitectureDetails
    $managedGodot = Join-Path $InstallDir $details.Console
    if ((Test-GodotVersion $managedGodot) -and -not (Confirm-YesNo 'Godot 4.7 is already installed. Re-download and reinstall anyway?' $false)) {
        Write-Ok 'Godot 4.7 already installed'
        return
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("bentchrome-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        $archivePath = Join-Path $tempDir $details.Asset
        $sumsPath = Join-Path $tempDir 'SHA512-SUMS.txt'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        Write-Info "Downloading $($details.Asset)..."
        Invoke-WebRequest -UseBasicParsing -Uri "$ReleaseBase/$($details.Asset)" -OutFile $archivePath
        Write-Info 'Downloading checksums...'
        Invoke-WebRequest -UseBasicParsing -Uri "$ReleaseBase/SHA512-SUMS.txt" -OutFile $sumsPath

        Write-Info 'Verifying SHA512...'
        $escapedAsset = [regex]::Escape($details.Asset)
        $sumLine = Get-Content -LiteralPath $sumsPath | Where-Object { $_ -match "\s+$escapedAsset`$" } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($sumLine)) { throw "Could not find a checksum for $($details.Asset)." }
        $expected = ($sumLine -split '\s+')[0]
        $actual = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA512).Hash
        if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Checksum mismatch - refusing to install.'
        }
        Write-Ok 'checksum verified'

        $extractDir = Join-Path $tempDir 'extracted'
        Write-Info 'Extracting...'
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
        $guiSource = Get-ChildItem -LiteralPath $extractDir -Filter $details.Gui -File -Recurse | Select-Object -First 1
        $consoleSource = Get-ChildItem -LiteralPath $extractDir -Filter $details.Console -File -Recurse | Select-Object -First 1
        if (($null -eq $guiSource) -or ($null -eq $consoleSource)) {
            throw 'Could not find the expected Godot executables inside the zip.'
        }

        if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Copy-Item -LiteralPath $guiSource.FullName -Destination (Join-Path $InstallDir $details.Gui)
        Copy-Item -LiteralPath $consoleSource.FullName -Destination (Join-Path $InstallDir $details.Console)
        Write-Ok "installed -> $InstallDir"
    } finally {
        if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
    }
}

function Install-GodotCommand {
    $details = Get-ArchitectureDetails
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $shim = "@`"%LOCALAPPDATA%\BentChrome\Godot\4.7\$($details.Console)`" %*`r`n"
    Set-Content -LiteralPath $ShimPath -Value $shim -Encoding Ascii -NoNewline

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @()
    if (-not [string]::IsNullOrWhiteSpace($userPath)) { $entries = $userPath -split ';' }
    $alreadyPresent = $entries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }
    if (-not $alreadyPresent) {
        $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $BinDir } else { "$userPath;$BinDir" }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Ok "added to user PATH -> $BinDir"
    } else {
        Write-Ok 'Godot command directory already on user PATH'
    }
    if (-not (($env:Path -split ';') | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') })) {
        $env:Path = "$env:Path;$BinDir"
    }
}

function Import-Project {
    $godot = Get-InstalledGodot
    if (-not (Test-GodotVersion $godot)) { throw 'Godot 4.7 is not available after installation.' }
    Write-Info 'Importing project assets...'
    & $godot --headless --path $RepoDir --import
    if ($LASTEXITCODE -ne 0) { throw "Godot project import failed with exit code $LASTEXITCODE." }
    Write-Ok 'assets imported'
}

function Show-Summary {
    $godot = Get-InstalledGodot
    Write-Host ''
    Write-Info 'Environment summary:'
    if (Test-GodotVersion $godot) {
        $version = (& $godot --version 2>$null | Select-Object -First 1)
        Write-Host "  OK  godot   $godot ($version)" -ForegroundColor Green
    } else {
        Write-Host '  ERR godot   (not installed)' -ForegroundColor Red
    }
}

function Show-LaunchHint {
    $details = Get-ArchitectureDetails
    $gui = Join-Path $InstallDir $details.Gui
    Write-Host ''
    Write-Ok 'Setup complete.'
    Write-Host '  Open a new terminal, then run:'
    Write-Host "      cd `"$RepoDir`""
    Write-Host '      godot'
    if ($NoLaunch) { return }
    if (Confirm-YesNo "Setup's locked and loaded. LET'S BEND SOME CHROME! Launch now?" $true) {
        Start-Process -FilePath $gui -ArgumentList @('--path', ('"{0}"' -f $RepoDir))
    }
}

function Start-PlayerSetup {
    Install-Godot
    Install-GodotCommand
    Import-Project
    Show-Summary
    Show-LaunchHint
}

Write-Host '== Bent Chrome - Windows Installer ==' -ForegroundColor Cyan
Write-Host 'Top-down vehicular combat, built in Godot 4.7.'
Write-Host ''

if ($Play) {
    Start-PlayerSetup
    exit 0
}

Write-Host '  1) Just Play! - install everything needed to run the game'
Write-Host '  2) Quit'
Write-Host ''
$choice = Read-Host 'Choose [1/2]'
switch ($choice) {
    '1' { Start-PlayerSetup }
    { $_ -in @('2', 'q', 'Q') } { Write-Host 'Bye.' }
    default { throw "Unrecognized choice: '$choice'" }
}
