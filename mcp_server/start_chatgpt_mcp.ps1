param(
    [switch]$Sandbox,
    [switch]$Live,
    [string]$StatePath
)

$ErrorActionPreference = 'Stop'
if ($Sandbox -and $Live) {
    throw 'Los modos de prueba y de escritura real son excluyentes.'
}
$pythonPath = Join-Path $PSScriptRoot '.venv-chatgpt\Scripts\python.exe'
$serverPath = Join-Path $PSScriptRoot 'chatgpt_server.py'
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw 'Falta el entorno Python del adaptador. Sigue mcp_server/CHATGPT.md para instalarlo.'
}
$serverArguments = @('-u', $serverPath)
if ($Sandbox) {
    $serverArguments += '--sandbox'
}
if ($Live) {
    $serverArguments += '--live'
}
if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
    $serverArguments += @('--state-path', $StatePath)
}
$env:TODO_MCP_DISABLE_REMOTE = '1'
$env:PYTHONUTF8 = '1'
& $pythonPath @serverArguments
exit $LASTEXITCODE
