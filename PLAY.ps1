# Bent Chrome - everyday launcher (Windows).
#
# Run this every time you want to play (double-click PLAY.cmd, or run it from a
# terminal). It applies any update you downloaded from Settings -> CHECK FOR
# UPDATES while the game is closed, reimports assets, then boots the game. With
# no pending update it just launches.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$RepoDir = $PSScriptRoot
$UpdatesDir = Join-Path $RepoDir '.updates'
$PendingZip = Join-Path $UpdatesDir 'pending.zip'
$ApplyJson = Join-Path $UpdatesDir 'apply.json'
$InstallDir = Join-Path $env:LOCALAPPDATA 'BentChrome\Godot\4.7'

function Write-Info([string]$m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok([string]$m) { Write-Host "[ok] $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err([string]$m) { Write-Host "[x] $m" -ForegroundColor Red }

function Resolve-Godot {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $cmd) { return $cmd.Source }
    if (Test-Path -LiteralPath $InstallDir) {
        $console = Get-ChildItem -LiteralPath $InstallDir -Filter '*console*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $console) { return $console.FullName }
    }
    return $null
}

function Apply-PendingUpdate {
    if (-not ((Test-Path -LiteralPath $PendingZip) -and (Test-Path -LiteralPath $ApplyJson))) { return }

    $godot = Resolve-Godot
    if ($null -eq $godot) { throw "Godot 4.7 isn't installed - run RUNME.cmd first." }

    $meta = Get-Content -LiteralPath $ApplyJson -Raw | ConvertFrom-Json
    $version = $meta.version
    $expected = $meta.sha256

    Write-Info "Applying update $version..."

    if (-not [string]::IsNullOrWhiteSpace($expected)) {
        $actual = (Get-FileHash -LiteralPath $PendingZip -Algorithm SHA256).Hash
        if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Err 'Update checksum mismatch - refusing to apply. Nothing was changed.'
            Write-Warn "Re-download from Settings -> CHECK FOR UPDATES, or delete $UpdatesDir to skip."
            throw 'checksum mismatch'
        }
        Write-Ok 'checksum verified'
    } else {
        Write-Warn 'No checksum on this update - applying without verification.'
    }

    # Let the just-closed game fully exit before overwriting files.
    Start-Sleep -Seconds 1

    Write-Info 'Unpacking over the game folder...'
    Expand-Archive -LiteralPath $PendingZip -DestinationPath $RepoDir -Force

    Write-Info 'Reimporting assets...'
    & $godot --headless --path $RepoDir --import | Out-Null

    Remove-Item -LiteralPath $PendingZip, $ApplyJson -Force -ErrorAction SilentlyContinue
    if ((Test-Path -LiteralPath $UpdatesDir) -and -not (Get-ChildItem -LiteralPath $UpdatesDir -Force)) {
        Remove-Item -LiteralPath $UpdatesDir -Force -ErrorAction SilentlyContinue
    }
    Write-Ok "update applied - you're on $version"
}

# A failed apply must not block launching the (still-working) current build.
try { Apply-PendingUpdate } catch { Write-Warn 'Update was not applied - launching the current build.' }

$godot = Resolve-Godot
if ($null -eq $godot) { Write-Err "Godot 4.7 isn't installed - run RUNME.cmd first."; exit 1 }
& $godot --path $RepoDir
