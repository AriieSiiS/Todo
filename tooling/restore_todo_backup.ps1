param(
  [Parameter(Mandatory = $true)]
  [string]$BackupDirectory,
  [string]$TargetDirectory = (Join-Path $env:USERPROFILE 'Documents\Todo'),
  [string]$SafetyBackupRoot = (Join-Path $env:USERPROFILE 'Documents\Todo Backups'),
  [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
if (Get-Process -Name todo -ErrorAction SilentlyContinue) {
  throw 'Cierra Todo antes de restaurar. No se modificó ningún dato.'
}
if (-not (Test-Path -LiteralPath $BackupDirectory -PathType Container) -or
    -not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
  throw 'No existe la copia o la carpeta activa indicada.'
}
$backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
$target = (Resolve-Path -LiteralPath $TargetDirectory).Path
$manifestPath = Join-Path $backup 'backup_manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw 'La copia no tiene backup_manifest.json.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (@($manifest.files).Count -eq 0) { throw 'El manifiesto no contiene archivos.' }
$allowed = @('runtime', 'covers', 'library_covers', 'wardrobe', 'recipes', 'household', 'plants', 'knowledge')
$backupPrefix = $backup + '\'

foreach ($entry in $manifest.files) {
  $relative = [string]$entry.path
  if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains('..') -or
      ($relative -split '[\\/]')[0] -notin $allowed) {
    throw "Ruta no segura: $relative"
  }
  $file = [IO.Path]::GetFullPath((Join-Path $backup $relative))
  if (-not $file.StartsWith($backupPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Falta un archivo: $relative"
  }
  $item = Get-Item -LiteralPath $file
  $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
  if ($item.Length -ne [long]$entry.size -or $hash -ne [string]$entry.sha256) {
    throw "La copia está dañada: $relative"
  }
}

if ($ValidateOnly) {
  [ordered]@{
    backup=$backup; verifiedFiles=@($manifest.files).Count
    counts=$manifest.counts; status='copia_validada'
  } | ConvertTo-Json -Depth 5
  exit 0
}

$backupScript = Join-Path $PSScriptRoot 'backup_todo_data_full.ps1'
$safetyBackup = (& $backupScript -SourceDirectory $target -DestinationRoot $SafetyBackupRoot) | ConvertFrom-Json
$targetPrefix = $target + '\'
foreach ($directoryName in $allowed) {
  $sourceDataDirectory = Join-Path $backup $directoryName
  if (-not (Test-Path -LiteralPath $sourceDataDirectory -PathType Container)) { continue }
  $targetDataDirectory = [IO.Path]::GetFullPath((Join-Path $target $directoryName))
  if (-not $targetDataDirectory.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Destino no seguro: $targetDataDirectory"
  }
  if (Test-Path -LiteralPath $targetDataDirectory) {
    Remove-Item -LiteralPath $targetDataDirectory -Recurse -Force
  }
  New-Item -ItemType Directory -Path $targetDataDirectory | Out-Null
  foreach ($sourceEntry in Get-ChildItem -LiteralPath $sourceDataDirectory -Force) {
    Copy-Item -LiteralPath $sourceEntry.FullName -Destination $targetDataDirectory -Recurse -Force
  }
}

foreach ($entry in $manifest.files) {
  $relative = [string]$entry.path
  $file = [IO.Path]::GetFullPath((Join-Path $target $relative))
  if (-not $file.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $file -PathType Leaf) -or
      (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne [string]$entry.sha256) {
    throw "La verificación final falló: $relative"
  }
}

[ordered]@{
  restoredFrom=$backup; restoredTo=$target; safetyBackup=$safetyBackup.destination
  restoredFiles=@($manifest.files).Count; counts=$manifest.counts
  status='restaurado_y_verificado'
} | ConvertTo-Json -Depth 5
