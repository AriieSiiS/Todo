param(
  [Parameter(Mandatory = $true)]
  [string]$Etiqueta,
  [string]$Snapshot = (Join-Path $env:USERPROFILE 'Documents\Todo\runtime\todo_state.json'),
  [string]$DestinationRoot = (Join-Path $env:USERPROFILE 'Documents\Todo Backups'),
  [int]$Keep = 10
)

# Foto rápida del snapshot antes de un cambio grande. No sustituye a la copia completa.
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Snapshot -PathType Leaf)) {
  throw "No existe el snapshot: $Snapshot"
}
$safeLabel = ($Etiqueta -replace '[^\p{L}\p{N}-]+', '-').Trim('-')
if (-not $safeLabel) { throw 'La etiqueta no es válida.' }
$folder = Join-Path $DestinationRoot '_antes-de-cambios'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$target = Join-Path $folder ("todo_state-{0}-{1}.json" -f $safeLabel, (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $Snapshot -Destination $target
if ((Get-FileHash -LiteralPath $Snapshot).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
  Remove-Item -LiteralPath $target -Force
  throw 'La verificación de la copia falló.'
}
Get-ChildItem -LiteralPath $folder -File -Filter 'todo_state-*.json' |
  Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep |
  Remove-Item -Force
[ordered]@{ status = 'guardado_y_verificado'; path = $target } | ConvertTo-Json
