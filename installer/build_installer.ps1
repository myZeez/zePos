<#
.SYNOPSIS
    Membangun installer ZePOS untuk Windows.

.DESCRIPTION
    Menjalankan build release Flutter lalu mengemasnya menjadi satu berkas
    setup dengan Inno Setup. Hasilnya berada di folder dist.

.PARAMETER SkipBuild
    Lewati build Flutter dan langsung kemas hasil build yang sudah ada.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$issFile = Join-Path $PSScriptRoot 'zepos.iss'

function Find-Compiler {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw "Inno Setup 6 tidak ditemukan. Pasang lebih dulu: winget install JRSoftware.InnoSetup"
}

function Find-Flutter {
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    if (Test-Path -LiteralPath 'C:\src\Flutter\bin\flutter.bat') {
        return 'C:\src\Flutter\bin\flutter.bat'
    }
    throw 'Perintah flutter tidak ditemukan pada PATH.'
}

if (-not $SkipBuild) {
    $flutter = Find-Flutter
    Write-Host 'Membangun ZePOS versi release...' -ForegroundColor Cyan
    & $flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Build Flutter gagal dengan kode $LASTEXITCODE." }
}

if (-not (Test-Path -LiteralPath (Join-Path $releaseDir 'zepos.exe'))) {
    throw "Hasil build tidak ditemukan di $releaseDir. Jalankan tanpa -SkipBuild."
}

$compiler = Find-Compiler
Write-Host 'Mengemas installer...' -ForegroundColor Cyan
& $compiler $issFile
if ($LASTEXITCODE -ne 0) { throw "Inno Setup gagal dengan kode $LASTEXITCODE." }

$output = Get-ChildItem -Path (Join-Path $projectRoot 'dist') -Filter 'ZePOS-Setup-*.exe' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

Write-Host ''
Write-Host 'Installer selesai dibuat:' -ForegroundColor Green
Write-Host ("  {0}  ({1:N1} MB)" -f $output.FullName, ($output.Length / 1MB))
