param(
  [string]$SourceDirectory = (Join-Path $env:USERPROFILE 'Documents\Todo'),
  [string]$DestinationRoot = (Join-Path $env:USERPROFILE 'Documents\Todo Backups'),
  [int]$WaitForProcessId = 0,
  [string]$RelaunchExecutable = '',
  [string]$StatusPath = '',
  [switch]$DeleteSelfWhenDone
)

$ErrorActionPreference = 'Stop'

function Write-BackupStatus([System.Collections.IDictionary]$Value) {
  if ([string]::IsNullOrWhiteSpace($StatusPath)) { return }
  $statusParent = Split-Path -Parent $StatusPath
  if (-not (Test-Path -LiteralPath $statusParent -PathType Container)) {
    New-Item -ItemType Directory -Path $statusParent -Force | Out-Null
  }
  $temporaryStatus = "$StatusPath.tmp"
  $Value | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryStatus -Encoding utf8
  Move-Item -LiteralPath $temporaryStatus -Destination $StatusPath -Force
}

try {
  if ($WaitForProcessId -gt 0) {
    Wait-Process -Id $WaitForProcessId -ErrorAction SilentlyContinue
  }
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

  $dataDirectories = @('runtime', 'covers', 'library_covers', 'wardrobe', 'recipes', 'household', 'shopping', 'plants', 'knowledge')
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
  $createdAt = (Get-Date).ToString('o')
  $manifest = [ordered]@{
    format = 'todo-full-backup-v1'
    createdAt = $createdAt
    source = $source
    dataDirectories = $dataDirectories
    snapshotUpdatedAt = $snapshot.updatedAt
    counts = [ordered]@{
      tasks=@($snapshot.tasks).Count; projects=@($snapshot.projects).Count
      notes=@($snapshot.notes).Count; expenses=@($snapshot.expenses).Count
      libraryItems=@($snapshot.libraryItems).Count; libraryGoals=@($snapshot.libraryGoals).Count
      wardrobeItems=@($snapshot.wardrobeItems).Count; wardrobeOutfits=@($snapshot.wardrobeOutfits).Count
      householdItems=@($snapshot.householdItems).Count; recipes=@($snapshot.recipes).Count
      plants=@($snapshot.plants).Count
      shoppingItems=@($snapshot.shoppingItems).Count
      calendarEvents=@($snapshot.calendarEvents).Count
    }
    verifiedFiles = $manifestFiles.Count
    totalBytes = $totalBytes
    files = $manifestFiles
  }
  $manifestPath = Join-Path $destination 'backup_manifest.json'
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
  $result = [ordered]@{
    destination=$destination; manifest=$manifestPath; counts=$manifest.counts
    verifiedFiles=$manifest.verifiedFiles; totalBytes=$totalBytes
    status='copia_creada_y_verificada'
  }
  Write-BackupStatus ([ordered]@{
    status='correcta'; finishedAt=(Get-Date).ToString('o'); createdAt=$createdAt
    destination=$destination; verifiedFiles=$manifest.verifiedFiles; totalBytes=$totalBytes
  })
  $result | ConvertTo-Json -Depth 5
} catch {
  Write-BackupStatus ([ordered]@{
    status='error'; finishedAt=(Get-Date).ToString('o'); message=$_.Exception.Message
  })
  throw
} finally {
  if (-not [string]::IsNullOrWhiteSpace($RelaunchExecutable) -and
      (Test-Path -LiteralPath $RelaunchExecutable -PathType Leaf)) {
    Start-Process -FilePath $RelaunchExecutable -ArgumentList '--section=settings'
  }
  if ($DeleteSelfWhenDone) {
    Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
  }
}
