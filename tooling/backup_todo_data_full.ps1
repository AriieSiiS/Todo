param(
  [string]$SourceDirectory = (Join-Path $env:USERPROFILE 'Documents\Todo'),
  [string]$DestinationRoot = (Join-Path $env:USERPROFILE 'Documents\Todo Backups')
)

$ErrorActionPreference = 'Stop'
if (Get-Process -Name todo -ErrorAction SilentlyContinue) {
  throw 'Cierra Todo antes de crear la copia.'
}
if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
  throw "No existe la carpeta de datos: $SourceDirectory"
}
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}
$destinationRootPath = (Resolve-Path -LiteralPath $DestinationRoot).Path
if ($destinationRootPath.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'La copia no puede guardarse dentro de los datos activos.'
}

$dataDirectories = @('runtime', 'covers', 'library_covers', 'wardrobe', 'recipes', 'household', 'knowledge')
$destination = Join-Path $destinationRootPath ("Todo-completo-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $destination | Out-Null
$manifestFiles = [System.Collections.Generic.List[object]]::new()
$totalBytes = [long]0

foreach ($directoryName in $dataDirectories) {
  $sourceDataDirectory = Join-Path $source $directoryName
  if (-not (Test-Path -LiteralPath $sourceDataDirectory -PathType Container)) { continue }
  $targetDataDirectory = Join-Path $destination $directoryName
  New-Item -ItemType Directory -Path $targetDataDirectory -Force | Out-Null
  foreach ($sourceEntry in Get-ChildItem -LiteralPath $sourceDataDirectory -Force) {
    Copy-Item -LiteralPath $sourceEntry.FullName -Destination $targetDataDirectory -Recurse -Force
  }
  foreach ($sourceFile in Get-ChildItem -LiteralPath $sourceDataDirectory -File -Recurse) {
    $relativePath = $sourceFile.FullName.Substring($source.Length).TrimStart('\')
    $targetFile = Join-Path $destination $relativePath
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf) -or
        (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash -ne $sourceHash) {
      throw "La verificación falló para $relativePath"
    }
    $manifestFiles.Add([ordered]@{path=$relativePath; size=$sourceFile.Length; sha256=$sourceHash})
    $totalBytes += $sourceFile.Length
  }
}

$snapshotPath = Join-Path $source 'runtime\todo_state.json'
if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
  throw 'No existe runtime\todo_state.json.'
}
$snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
$manifest = [ordered]@{
  format = 'todo-full-backup-v1'
  createdAt = (Get-Date).ToString('o')
  source = $source
  dataDirectories = $dataDirectories
  snapshotUpdatedAt = $snapshot.updatedAt
  counts = [ordered]@{
    tasks=@($snapshot.tasks).Count; projects=@($snapshot.projects).Count
    notes=@($snapshot.notes).Count; expenses=@($snapshot.expenses).Count
    libraryItems=@($snapshot.libraryItems).Count; libraryGoals=@($snapshot.libraryGoals).Count
    wardrobeItems=@($snapshot.wardrobeItems).Count; wardrobeOutfits=@($snapshot.wardrobeOutfits).Count
    householdItems=@($snapshot.householdItems).Count; recipes=@($snapshot.recipes).Count
    calendarEvents=@($snapshot.calendarEvents).Count
  }
  verifiedFiles = $manifestFiles.Count
  totalBytes = $totalBytes
  files = $manifestFiles
}
$manifestPath = Join-Path $destination 'backup_manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
[ordered]@{
  destination=$destination; manifest=$manifestPath; counts=$manifest.counts
  verifiedFiles=$manifest.verifiedFiles; totalBytes=$totalBytes
  status='copia_creada_y_verificada'
} | ConvertTo-Json -Depth 5
