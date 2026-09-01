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
$result = [ordered]@{
  source = $source
  target = $target
  verifiedFiles = $sourceFiles.Count
  copiedFiles = $copiedFiles
  mismatches = $mismatches
  executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
  executableSize = (Get-Item -LiteralPath $executable).Length
}
$result | ConvertTo-Json -Depth 4

if ($mismatches.Count -ne 0) {
  exit 1
}
