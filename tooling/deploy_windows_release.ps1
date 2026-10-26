param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDirectory,
  [Parameter(Mandatory = $true)]
  [string]$TargetDirectory
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$target = (Resolve-Path -LiteralPath $TargetDirectory).Path

if (-not (Test-Path -LiteralPath (Join-Path $source 'todo.exe') -PathType Leaf)) {
  throw 'La compilación release no contiene todo.exe.'
}
if (-not (Test-Path -LiteralPath (Join-Path $target 'todo.exe') -PathType Leaf)) {
  throw 'La instalación de destino no contiene todo.exe.'
}

$mismatches = [System.Collections.Generic.List[string]]::new()
$copiedFiles = [System.Collections.Generic.List[string]]::new()
$sourceFiles = Get-ChildItem -LiteralPath $source -File -Recurse
foreach ($sourceFile in $sourceFiles) {
  $relativePath = $sourceFile.FullName.Substring($source.Length).TrimStart('\')
  $targetFile = Join-Path $target $relativePath
  if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
    if ($sourceHash -eq $targetHash) {
      continue
    }
  }
  $targetParent = Split-Path -Parent $targetFile
  if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
  }
  Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile -Force
  $copiedFiles.Add($relativePath)
}

foreach ($sourceFile in $sourceFiles) {
  $relativePath = $sourceFile.FullName.Substring($source.Length).TrimStart('\')
  $targetFile = Join-Path $target $relativePath
  if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
    $mismatches.Add($relativePath)
    continue
  }
  $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
  $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
  if ($sourceHash -ne $targetHash) {
    $mismatches.Add($relativePath)
  }
}

$executable = Join-Path $target 'todo.exe'
$agentExecutable = Join-Path $target 'todo_lan_agent.exe'
if (-not (Test-Path -LiteralPath $agentExecutable -PathType Leaf)) {
  throw 'La instalación no contiene todo_lan_agent.exe.'
}
$registrationScript = Join-Path $target 'register_lan_sync_agent.ps1'
if (-not (Test-Path -LiteralPath $registrationScript -PathType Leaf)) {
  throw 'La instalación no contiene register_lan_sync_agent.ps1.'
}
& powershell -NoProfile -ExecutionPolicy Bypass -File $registrationScript -InstallDirectory $target | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw 'No se pudo registrar el agente de sincronización local.'
}
$result = [ordered]@{
  source = $source
  target = $target
  verifiedFiles = $sourceFiles.Count
  copiedFiles = $copiedFiles
  mismatches = $mismatches
  executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
  executableSize = (Get-Item -LiteralPath $executable).Length
  lanAgentSha256 = (Get-FileHash -LiteralPath $agentExecutable -Algorithm SHA256).Hash
}
$result | ConvertTo-Json -Depth 4

if ($mismatches.Count -ne 0) {
  exit 1
}
