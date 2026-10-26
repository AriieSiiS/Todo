param(
  [string]$ProjectRoot = (Resolve-Path $PSScriptRoot\..).Path,
  [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $resolvedRoot 'build\windows\x64\runner\Release'
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$agentRoot = Join-Path $resolvedRoot 'lan_sync_agent'
Push-Location $agentRoot
try {
  dart pub get
  if ($LASTEXITCODE -ne 0) { throw 'No se pudieron resolver las dependencias del agente local.' }
  dart compile exe 'bin\todo_lan_agent.dart' -o (Join-Path $OutputDirectory 'todo_lan_agent.exe')
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el agente local.' }

  # Dart genera un ejecutable de consola. El agente no tiene interfaz, por lo
  # que se marca como aplicación de Windows para evitar que aparezca una
  # consola vacía al iniciar sesión.
  $agentPath = Join-Path $OutputDirectory 'todo_lan_agent.exe'
  $stream = [System.IO.File]::Open(
    $agentPath,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
  )
  try {
    $reader = [System.IO.BinaryReader]::new($stream)
    $stream.Position = 0x3C
    $peOffset = $reader.ReadInt32()
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) {
      throw 'El ejecutable del agente no contiene una cabecera PE válida.'
    }
    $subsystemOffset = $peOffset + 24 + 68
    $stream.Position = $subsystemOffset
    $writer = [System.IO.BinaryWriter]::new($stream)
    $writer.Write([UInt16]2)
    $writer.Flush()
  }
  finally {
    $stream.Dispose()
  }
}
finally {
  Pop-Location
}

Copy-Item -LiteralPath (Join-Path $resolvedRoot 'tooling\provision_lan_sync_certificate.ps1') `
  -Destination (Join-Path $OutputDirectory 'provision_lan_sync_certificate.ps1') -Force
Copy-Item -LiteralPath (Join-Path $resolvedRoot 'tooling\register_lan_sync_agent.ps1') `
  -Destination (Join-Path $OutputDirectory 'register_lan_sync_agent.ps1') -Force
Copy-Item -LiteralPath (Join-Path $resolvedRoot 'tooling\install_kindle.ps1') `
  -Destination (Join-Path $OutputDirectory 'install_kindle.ps1') -Force
Copy-Item -LiteralPath (Join-Path $resolvedRoot 'tooling\limitar_red_todo.ps1') `
  -Destination (Join-Path $OutputDirectory 'limitar_red_todo.ps1') -Force
$kindleOutput = Join-Path $OutputDirectory 'kindle\todo.koplugin'
[System.IO.Directory]::CreateDirectory($kindleOutput) | Out-Null
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $resolvedRoot 'kindle\todo.koplugin') -File) {
  Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $kindleOutput $file.Name) -Force
}
