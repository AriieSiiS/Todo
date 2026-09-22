param(
  [string]$ProjectRoot = (Resolve-Path $PSScriptRoot\..).Path,
  [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $resolvedRoot 'build\windows\x64\runner\Release'
}
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$agentRoot = Join-Path $resolvedRoot 'lan_sync_agent'
Push-Location $agentRoot
try {
  dart pub get
  if ($LASTEXITCODE -ne 0) { throw 'No se pudieron resolver las dependencias del agente local.' }
  dart compile exe 'bin\todo_lan_agent.dart' -o (Join-Path $OutputDirectory 'todo_lan_agent.exe')
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el agente local.' }
}
finally {
  Pop-Location
}

Copy-Item -LiteralPath (Join-Path $resolvedRoot 'tooling\provision_lan_sync_certificate.ps1') `
  -Destination (Join-Path $OutputDirectory 'provision_lan_sync_certificate.ps1') -Force
Copy-Item -LiteralPath (Join-Path $resolvedRoot 'tooling\register_lan_sync_agent.ps1') `
  -Destination (Join-Path $OutputDirectory 'register_lan_sync_agent.ps1') -Force
