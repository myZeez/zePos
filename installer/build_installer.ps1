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
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        # winget memasang per pengguna bila tanpa hak administrator.
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
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

# Sidik jari berkas aplikasi, ikut dipasang ke folder aplikasi.
#
# Ini bukan sidik jari installer-nya: nilai itu baru ada setelah installer
# selesai dirakit, sehingga memasukkannya ke dalam dirinya sendiri mustahil.
# Daftar ini gunanya memeriksa berkas yang sudah terpasang masih utuh.
Write-Host 'Menghitung sidik jari berkas aplikasi...' -ForegroundColor Cyan
$appFiles = Get-ChildItem -LiteralPath $releaseDir -Recurse -File |
    Where-Object { $_.Extension -in '.exe', '.dll' } |
    Sort-Object Name
$appHashes = foreach ($file in $appFiles) {
    "$((Get-FileHash -Algorithm SHA256 $file.FullName).Hash) *$($file.Name)"
}
$header = @(
    '# Sidik jari SHA-256 berkas aplikasi ZePOS yang terpasang.',
    '#',
    '# Periksa keutuhan berkas dengan menjalankan perintah berikut pada',
    '# folder aplikasi, lalu bandingkan hasilnya dengan daftar di bawah:',
    '#',
    '#   Get-ChildItem -Include *.exe,*.dll -Recurse | Get-FileHash -Algorithm SHA256',
    '#',
    '# Daftar ini tidak memuat sidik jari berkas pemasang itu sendiri, sebab',
    '# nilainya baru terbentuk setelah pemasang selesai dirakit. Sidik jari',
    '# pemasang disertakan terpisah di samping berkas unduhannya.',
    ''
)
($header + $appHashes) | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'app-files.sha256') -Encoding ascii

$compiler = Find-Compiler
Write-Host 'Mengemas installer...' -ForegroundColor Cyan
& $compiler $issFile
if ($LASTEXITCODE -ne 0) { throw "Inno Setup gagal dengan kode $LASTEXITCODE." }

$output = Get-ChildItem -Path (Join-Path $projectRoot 'dist') -Filter 'ZePOS-Setup-*.exe' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

# Sidik jari sebagai pengganti tanda tangan digital.
#
# Installer ini tidak ditandatangani secara digital, sehingga Windows
# SmartScreen menampilkan peringatan "Unknown publisher". Menandatanganinya
# memerlukan sertifikat berbayar dari otoritas tepercaya; sertifikat yang
# dibuat sendiri tidak menghilangkan peringatan itu karena SmartScreen menilai
# reputasi penerbitnya, bukan sekadar ada tidaknya tanda tangan.
#
# Nilai SHA-256 di bawah memungkinkan penerima memastikan berkas yang mereka
# unduh sama persis dengan yang dibuat di sini.
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output.FullName).Hash
$checksumFile = "$($output.FullName).sha256"
"$hash *$($output.Name)" | Set-Content -LiteralPath $checksumFile -Encoding ascii

Write-Host ''
Write-Host 'Installer selesai dibuat:' -ForegroundColor Green
Write-Host ("  {0}  ({1:N1} MB)" -f $output.FullName, ($output.Length / 1MB))
Write-Host ("  SHA-256: {0}" -f $hash)
Write-Host ("  Checksum disimpan di: {0}" -f $checksumFile)
Write-Host ''
Write-Host 'Bagikan nilai SHA-256 bersama installer-nya. Penerima dapat memeriksa' -ForegroundColor Yellow
Write-Host 'keaslian berkas dengan perintah berikut sebelum memasang:' -ForegroundColor Yellow
Write-Host ("  Get-FileHash -Algorithm SHA256 '{0}'" -f $output.Name)
