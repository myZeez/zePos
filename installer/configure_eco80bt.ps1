[CmdletBinding()]
param(
    [string]$PrinterName = '80Label Printer',
    [string]$ExpectedDriver = '80Label',
    [string]$LogDirectory = "$env:ProgramData\ZePOS"
)

$ErrorActionPreference = 'Stop'

function Write-SetupLog {
    param([string]$Message)

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath (Join-Path $LogDirectory 'eco80bt-setup.log') -Value "[$timestamp] $Message"
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdministrator) {
    throw 'Jalankan script ini sebagai Administrator.'
}

$printer = Get-Printer -Name $PrinterName -ErrorAction Stop
if ($printer.DriverName -ne $ExpectedDriver) {
    throw "Queue '$PrinterName' memakai driver '$($printer.DriverName)', bukan '$ExpectedDriver'."
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDirectory = Join-Path $LogDirectory "backup-$timestamp"
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$configuration = Get-PrintConfiguration -PrinterName $PrinterName
$configuration.PrintTicketXML | Set-Content -LiteralPath (
    Join-Path $backupDirectory 'PrintTicket.xml'
) -Encoding UTF8

$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$PrinterName\PrinterDriverData"
if (-not (Test-Path -LiteralPath $registryPath)) {
    throw "Registry driver untuk '$PrinterName' tidak ditemukan."
}
$registryBackup = Get-ItemProperty -LiteralPath $registryPath
$registryBackup | Select-Object `
    'DeviceCapabilities.PaperName', `
    'DeviceCapabilities.PaperWidth', `
    'DeviceCapabilities.PaperLength', `
    'DEVMODE.ForceUseDriverSelectedPaperSize', `
    'oemuni.HorizontalPrintAlignment', `
    'oemuni.HorizontalPrintOffset' |
    ConvertTo-Json |
    Set-Content -LiteralPath (Join-Path $backupDirectory 'PrinterDriverData.json') -Encoding UTF8

Set-ItemProperty -LiteralPath $registryPath -Name 'DeviceCapabilities.PaperName' -Value '40.00x20.00(mm)'
Set-ItemProperty -LiteralPath $registryPath -Name 'DeviceCapabilities.PaperWidth' -Value 400
Set-ItemProperty -LiteralPath $registryPath -Name 'DeviceCapabilities.PaperLength' -Value 200
Set-ItemProperty -LiteralPath $registryPath -Name 'DEVMODE.ForceUseDriverSelectedPaperSize' -Value 1
Set-ItemProperty -LiteralPath $registryPath -Name 'oemuni.HorizontalPrintAlignment' -Value 0
Set-ItemProperty -LiteralPath $registryPath -Name 'oemuni.HorizontalPrintOffset' -Value 0

[xml]$ticket = $configuration.PrintTicketXML
$namespace = [System.Xml.XmlNamespaceManager]::new($ticket.NameTable)
$namespace.AddNamespace(
    'psf',
    'http://schemas.microsoft.com/windows/2003/08/printing/printschemaframework'
)
$mediaFeature = $ticket.SelectSingleNode(
    "//psf:Feature[@name='psk:PageMediaSize']",
    $namespace
)
if ($null -eq $mediaFeature) {
    throw 'PageMediaSize tidak ditemukan pada PrintTicket driver.'
}
$mediaOption = $mediaFeature.SelectSingleNode('./psf:Option', $namespace)
$mediaValues = $mediaOption.SelectNodes('.//psf:Value', $namespace)
if ($mediaValues.Count -lt 2) {
    throw 'Dimensi media tidak ditemukan pada PrintTicket driver.'
}

# This option is the driver's built-in 40.00x20.00(mm) media.
$mediaOption.SetAttribute('name', 'ns0000:User0000000257')
$mediaValues[0].InnerText = '40000'
$mediaValues[1].InnerText = '20000'
Set-PrintConfiguration -PrinterName $PrinterName -PrintTicketXml $ticket.OuterXml

$verified = Get-PrintConfiguration -PrinterName $PrinterName
[xml]$verifiedTicket = $verified.PrintTicketXML
$verifiedNamespace = [System.Xml.XmlNamespaceManager]::new($verifiedTicket.NameTable)
$verifiedNamespace.AddNamespace(
    'psf',
    'http://schemas.microsoft.com/windows/2003/08/printing/printschemaframework'
)
$verifiedFeature = $verifiedTicket.SelectSingleNode(
    "//psf:Feature[@name='psk:PageMediaSize']",
    $verifiedNamespace
)
$verifiedValues = $verifiedFeature.SelectNodes('.//psf:Value', $verifiedNamespace)
if ($verifiedValues[0].InnerText -ne '40000' -or $verifiedValues[1].InnerText -ne '20000') {
    throw 'Verifikasi media 40x20 mm gagal. Backup tidak dihapus.'
}

Write-SetupLog "Queue '$PrinterName' siap: media 40x20 mm, alignment kiri, port $($printer.PortName). Backup: $backupDirectory"
Write-Output "OK: $PrinterName memakai media 40x20 mm pada port $($printer.PortName)."
Write-Output "Backup: $backupDirectory"
