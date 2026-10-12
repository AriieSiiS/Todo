param(
  [string]$SourceDirectory = (Join-Path $env:USERPROFILE 'Documents\Todo'),
  [string]$DestinationRoot = (Join-Path $env:USERPROFILE 'Documents\Todo Backups'),
  [int]$WaitForProcessId = 0,
  [string]$RelaunchExecutable = '',
  [string]$StatusPath = '',
  [switch]$DeleteSelfWhenDone,
  # Cuántas copias completas se conservan en cada ubicación.
  [int]$Keep = 2,
  # Segunda ubicación en otro disco. Si no existe la unidad, se omite sin fallar.
  [string]$ExternalRoot = 'E:\Todo Backups externo'
)

$ErrorActionPreference = 'Stop'

function Get-ValidBackups([string]$Root) {
  # Solo cuentan las copias con manifiesto; las incompletas se tratan aparte.
  @(Get-ChildItem -LiteralPath $Root -Directory -Filter 'Todo-completo-*' -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'backup_manifest.json') -PathType Leaf } |
    Sort-Object Name -Descending)
}

function Remove-OldBackups([string]$Root, [string]$Protected, [int]$Keep) {
  $rootPath = (Resolve-Path -LiteralPath $Root).Path
  $valid = Get-ValidBackups $rootPath
  $incomplete = @(Get-ChildItem -LiteralPath $rootPath -Directory -Filter 'Todo-completo-*' -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-Path -LiteralPath (Join-Path $_.FullName 'backup_manifest.json') -PathType Leaf) })
  $remove = @($valid | Select-Object -Skip $Keep) + $incomplete
  foreach ($directory in $remove) {
    if ($directory.Name -eq (Split-Path -Leaf $Protected)) { continue }
    if (-not $directory.FullName.StartsWith($rootPath + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
    Remove-Item -LiteralPath $directory.FullName -Recurse -Force
  }
  return @($remove | ForEach-Object { $_.Name })
}

function Stop-PriceTracker {
  # El seguimiento de precios mantiene abierta una base SQLite que cambia durante la copia.
  $task = Get-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\' -ErrorAction SilentlyContinue
  if (-not $task) { return $false }
  $stopScript = Join-Path $env:LOCALAPPDATA 'Todo\price_tracker\stop.ps1'
  if (Test-Path -LiteralPath $stopScript -PathType Leaf) {
    & $stopScript -RuntimeDirectory (Join-Path $env:LOCALAPPDATA 'Todo\price_tracker')
  } elseif ($task.State -eq 'Running') {
    Stop-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\'
  }
  Start-Sleep -Seconds 3
  return $true
}

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
  $trackerStopped = Stop-PriceTracker
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
  # La rotación solo ocurre después de que la copia nueva esté verificada.
  $removed = Remove-OldBackups $destinationRootPath $destination $Keep

  $externalStatus = 'omitida_sin_disco'
  $externalRemoved = @()
  $externalDrive = if ($ExternalRoot) { Split-Path -Qualifier $ExternalRoot } else { '' }
  if ($externalDrive -and (Test-Path -LiteralPath "$externalDrive\" -PathType Container)) {
    try {
      New-Item -ItemType Directory -Path $ExternalRoot -Force | Out-Null
      $externalRootPath = (Resolve-Path -LiteralPath $ExternalRoot).Path
      $externalDestination = Join-Path $externalRootPath (Split-Path -Leaf $destination)
      robocopy $destination $externalDestination /E /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
      if ($LASTEXITCODE -ge 8) { throw 'robocopy no pudo copiar la copia al disco externo.' }
      foreach ($entry in $manifestFiles) {
        $copied = Join-Path $externalDestination $entry.path
        if (-not (Test-Path -LiteralPath $copied -PathType Leaf) -or
            (Get-FileHash -LiteralPath $copied -Algorithm SHA256).Hash -ne $entry.sha256) {
          throw "La verificación en el disco externo falló para $($entry.path)"
        }
      }
      Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $externalDestination 'backup_manifest.json') -Force
      $externalRemoved = Remove-OldBackups $externalRootPath $externalDestination $Keep
      $externalStatus = 'copiada_y_verificada'
    } catch {
      $externalStatus = 'error: ' + $_.Exception.Message
    }
  }

  $result = [ordered]@{
    destination=$destination; manifest=$manifestPath; counts=$manifest.counts
    verifiedFiles=$manifest.verifiedFiles; totalBytes=$totalBytes
    removedOldBackups=$removed; external=$externalStatus; externalRemoved=$externalRemoved
    status='copia_creada_y_verificada'
  }
  Write-BackupStatus ([ordered]@{
    status='correcta'; finishedAt=(Get-Date).ToString('o'); createdAt=$createdAt
    destination=$destination; verifiedFiles=$manifest.verifiedFiles; totalBytes=$totalBytes
    external=$externalStatus
  })
  $result | ConvertTo-Json -Depth 5
} catch {
  Write-BackupStatus ([ordered]@{
    status='error'; finishedAt=(Get-Date).ToString('o'); message=$_.Exception.Message
  })
  throw
} finally {
  if ($trackerStopped) {
    Start-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\' -ErrorAction SilentlyContinue
  }
  if (-not [string]::IsNullOrWhiteSpace($RelaunchExecutable) -and
      (Test-Path -LiteralPath $RelaunchExecutable -PathType Leaf)) {
    Start-Process -FilePath $RelaunchExecutable -ArgumentList '--section=settings'
  }
  if ($DeleteSelfWhenDone) {
    Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
  }
}
