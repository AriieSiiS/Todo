param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$version = '18.3'
$archiveName = "haos_ova-$version.vhdx.zip"
$sourceUrl = "https://github.com/home-assistant/operating-system/releases/download/$version/$archiveName"
$expectedSha256 = 'f6218e9e32415c0d1ada87852a3ac2b16cdbc203481ee241b420c8de927b8d00'
$root = Join-Path $env:USERPROFILE 'Documents\HomeAssistant'
$archive = Join-Path $root $archiveName
$imageDirectory = Join-Path $root 'imagen'
$vmDirectory = Join-Path $root 'maquina'
$statusFile = Join-Path $root 'instalacion.json'
$vmName = 'Todo-Home-Assistant'
$switchName = 'Todo Home Assistant LAN'

function Write-InstallationStatus {
    param([string]$State, [string]$Message)
    [pscustomobject]@{
        estado = $State
        mensaje = $Message
        fecha = (Get-Date).ToString('o')
        version = $version
    } | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding utf8
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if (-not (Test-Path -LiteralPath $archive)) {
        Write-InstallationStatus 'descargando' 'Descargando la imagen oficial de Home Assistant OS.'
        & curl.exe --location --fail --retry 3 --output $archive $sourceUrl
        if ($LASTEXITCODE -ne 0) {
            throw 'No se pudo descargar la imagen oficial.'
        }
    }
    $actualSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $expectedSha256) {
        throw 'La imagen descargada no coincide con el SHA-256 publicado.'
    }
    New-Item -ItemType Directory -Path $imageDirectory -Force | Out-Null
    $image = Get-ChildItem -LiteralPath $imageDirectory -Filter '*.vhdx' -File |
        Select-Object -First 1
    if (-not $image) {
        Expand-Archive -LiteralPath $archive -DestinationPath $imageDirectory -Force
        $image = Get-ChildItem -LiteralPath $imageDirectory -Filter '*.vhdx' -File |
            Select-Object -First 1
    }
    if (-not $image) {
        throw 'No se encontró el disco VHDX dentro del archivo oficial.'
    }
    if (-not $Install) {
        Write-InstallationStatus 'preparado' 'Imagen oficial descargada y verificada. Falta configurar Hyper-V.'
        Write-Output $statusFile
        return
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Hyper-V necesita ejecutar este script como administrador.'
    }
    Import-Module Hyper-V -ErrorAction Stop
    $existing = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-InstallationStatus 'existente' 'La máquina virtual ya existe; no se ha modificado.'
        return
    }
    $network = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
    if (-not $network) {
        $network = New-VMSwitch -Name $switchName -NetAdapterName 'Ethernet 2' -AllowManagementOS $true
    }
    if ($network.SwitchType -ne 'External') {
        throw 'El conmutador existente no es de tipo externo.'
    }
    New-Item -ItemType Directory -Path $vmDirectory -Force | Out-Null
    $vmDisk = Join-Path $vmDirectory 'home-assistant.vhdx'
    Copy-Item -LiteralPath $image.FullName -Destination $vmDisk
    $disk = Get-VHD -Path $vmDisk
    if ($disk.Size -lt 32GB) {
        Resize-VHD -Path $vmDisk -SizeBytes 32GB
    }
    New-VM -Name $vmName -Generation 2 -MemoryStartupBytes 4GB -VHDPath $vmDisk `
        -SwitchName $switchName -Path $vmDirectory | Out-Null
    Set-VMProcessor -VMName $vmName -Count 2
    Set-VMFirmware -VMName $vmName -EnableSecureBoot Off
    Set-VM -Name $vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    Start-VM -Name $vmName
    Write-InstallationStatus 'iniciada' 'La máquina virtual está iniciada. Falta completar el asistente de Home Assistant.'
} catch {
    Write-InstallationStatus 'error' $_.Exception.Message
    throw
}
