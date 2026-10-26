param(
  [Parameter(Mandatory = $true)][string]$KindleRoot,
  [string]$ConfigDirectory = (Join-Path $env:LOCALAPPDATA 'Todo\lan_sync'),
  [string]$SourceDirectory = '',
  [string]$DeviceName = 'Kindle',
  [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
function Get-HuellaArchivo {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  $stream = [System.IO.File]::OpenRead($LiteralPath)
  try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
  finally { $stream.Dispose(); $algorithm.Dispose() }
}
$root = (Resolve-Path -LiteralPath $KindleRoot).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $root 'system\version.txt') -PathType Leaf)) {
  throw 'La unidad no contiene la versión del sistema Kindle. No se ha copiado nada.'
}
$candidates = @(
  (Join-Path $root 'koreader'),
  (Join-Path $root 'kmc\kpm\packages\koreader\koreader')
)
$reader = @($candidates | Where-Object {
  (Test-Path -LiteralPath (Join-Path $_ 'reader.lua') -PathType Leaf) -and
  (Test-Path -LiteralPath (Join-Path $_ 'plugins') -PathType Container)
}) | Select-Object -First 1
if (-not $reader) { throw 'No se encuentra una instalación de KOReader. No se ha modificado el Kindle.' }
if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
  $SourceDirectory = Join-Path $PSScriptRoot 'kindle\todo.koplugin'
  if (-not (Test-Path -LiteralPath $SourceDirectory)) {
    $SourceDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'kindle\todo.koplugin'
  }
}
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$files = @(Get-ChildItem -LiteralPath $source -File -Filter '*.lua')
if ($files.Count -lt 5) { throw 'El paquete del complemento está incompleto.' }
$target = Join-Path $reader 'plugins\todo.koplugin'
$settings = Join-Path $reader 'settings\todo'
$version = [System.IO.File]::ReadAllText((Join-Path $root 'system\version.txt')).Trim()
if ($ValidateOnly) {
  [ordered]@{ estado='detectado'; version=$version; koreader=$reader; destino=$target; archivos=$files.Count } |
    ConvertTo-Json
  exit 0
}

$statusPath = Join-Path $ConfigDirectory 'status.json'
$certificatePath = Join-Path $ConfigDirectory 'server.cer'
if (-not (Test-Path -LiteralPath $statusPath) -or -not (Test-Path -LiteralPath $certificatePath)) {
  throw 'Falta el agente local o su certificado. Inicia el agente de Todo antes de instalar.'
}
$status = [System.IO.File]::ReadAllText($statusPath) | ConvertFrom-Json
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
  $fingerprint = ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($certificatePath)))).Replace('-', '').ToLowerInvariant()
} finally { $sha.Dispose() }
if ($fingerprint -ne $status.certificateFingerprint) { throw 'La huella del certificado no coincide con el agente.' }
$addresses = @($status.addresses | Where-Object { $_ -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' })
if ($addresses.Count -eq 0) { throw 'El PC no tiene una dirección de red privada disponible.' }
# Preferir la interfaz física para evitar los conmutadores virtuales de Hyper-V.
$physicalAddresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.InterfaceAlias -notmatch 'vEthernet|Loopback|VPN' -and $addresses -contains $_.IPAddress } |
  Select-Object -ExpandProperty IPAddress)
$addresses = @($physicalAddresses + $addresses | Select-Object -Unique)

[System.IO.Directory]::CreateDirectory($settings) | Out-Null
[System.IO.Directory]::CreateDirectory($target) | Out-Null
$backup = Join-Path (Split-Path -Parent $ConfigDirectory) ('kindle_backups\' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-ffff'))
$oldFiles = @(Get-ChildItem -LiteralPath $target -File)
if ($oldFiles.Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $settings 'config.json'))) {
  [System.IO.Directory]::CreateDirectory($backup) | Out-Null
  foreach ($file in $oldFiles) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $backup $file.Name) }
  if (Test-Path -LiteralPath (Join-Path $settings 'config.json')) {
    Copy-Item -LiteralPath (Join-Path $settings 'config.json') -Destination (Join-Path $backup 'config.json')
  }
}

$devicesPath = Join-Path $ConfigDirectory 'paired_devices.json'
$devices = @()
if (Test-Path -LiteralPath $devicesPath) {
  $devices = @(([System.IO.File]::ReadAllText($devicesPath) | ConvertFrom-Json).devices)
}
$configPath = Join-Path $settings 'config.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
  $existing = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
  if ($existing.token -match '^[A-Za-z0-9_-]{43}$' -and $existing.device_id -match '^[A-Za-z0-9_-]+$') {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $oldHash = ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($existing.token)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
    if (@($devices | Where-Object { $_.id -eq $existing.device_id -and $_.tokenHash -eq $oldHash -and $_.profile -eq 'kindle' }).Count -eq 1) {
      $config = $existing
    }
  }
}
if ($null -eq $config) {
  $bytes = New-Object byte[] 32
  $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $random.GetBytes($bytes) } finally { $random.Dispose() }
  $token = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
  if ($token -notmatch '^[A-Za-z0-9_-]{43}$') { throw 'La credencial generada no es válida.' }
  $deviceId = 'kindle-' + [Guid]::NewGuid().ToString('N')
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $hash = ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($token)))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
  $devices += [ordered]@{id=$deviceId; name=$DeviceName; profile='kindle'; tokenHash=$hash; pairedAt=[DateTime]::UtcNow.ToString('o')}
  $config = [pscustomobject]@{device_id=$deviceId; token=$token}
}
$packageConfig = [ordered]@{protocol_version=1; device_id=$config.device_id; token=$config.token;
  fingerprint=$fingerprint; addresses=$addresses; port=47832}
foreach ($file in $files) {
  $destination = Join-Path $target $file.Name
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
  if ((Get-HuellaArchivo -LiteralPath $destination) -ne
      (Get-HuellaArchivo -LiteralPath $file.FullName)) { throw 'Falló la verificación del complemento.' }
}
Copy-Item -LiteralPath $certificatePath -Destination (Join-Path $settings 'server.cer') -Force
if ((Get-HuellaArchivo -LiteralPath (Join-Path $settings 'server.cer')) -ne $fingerprint) {
  throw 'Falló la verificación del certificado copiado.'
}
$temporaryConfig = $configPath + '.tmp'
[System.IO.File]::WriteAllText($temporaryConfig, ($packageConfig | ConvertTo-Json -Depth 5), $utf8)
Move-Item -LiteralPath $temporaryConfig -Destination $configPath -Force
$verified = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
if ($verified.token -ne $packageConfig.token -or $verified.fingerprint -ne $fingerprint) { throw 'Falló la verificación de la configuración USB.' }
$temporaryDevices = $devicesPath + '.kindle.tmp'
[System.IO.File]::WriteAllText($temporaryDevices, (@{devices=@($devices)} | ConvertTo-Json -Depth 8), $utf8)
Move-Item -LiteralPath $temporaryDevices -Destination $devicesPath -Force
[System.IO.File]::WriteAllText((Join-Path $ConfigDirectory 'kindle_enabled'), '1', $utf8)
[ordered]@{estado='copiado_y_verificado'; autenticacion='pendiente_de_abrir_en_kindle';
  dispositivo=$packageConfig.device_id; version=$version; koreader=$reader; archivos=$files.Count;
  copia_anterior=$(if (Test-Path -LiteralPath $backup) { $backup } else { $null })} | ConvertTo-Json
