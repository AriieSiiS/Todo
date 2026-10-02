param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^tunnel_[A-Za-z0-9_-]+$')]
    [string]$TunnelId,
    [Parameter(Mandatory = $true)]
    [string]$RuntimeKeyFile
)

$ErrorActionPreference = 'Stop'
$binary = Join-Path $PSScriptRoot '.tunnel-client\tunnel-client.exe'
$python = Join-Path $PSScriptRoot '.venv-chatgpt\Scripts\python.exe'
$server = Join-Path $PSScriptRoot 'chatgpt_server.py'
foreach ($required in @($binary, $python, $server, $RuntimeKeyFile)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw 'Falta un archivo requerido. Revisa mcp_server/CHATGPT.md.'
    }
}
$keyPath = (Resolve-Path -LiteralPath $RuntimeKeyFile).ProviderPath
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($keyPath.StartsWith($repository + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'La clave de ejecución debe guardarse fuera del repositorio.'
}
$runner = Join-Path $PSScriptRoot 'chatgpt_tunnel.py'
# El cliente oficial supervisa el proceso; solo recibe una referencia a la clave.
& $python $runner --tunnel-id $TunnelId --key-file $keyPath
exit $LASTEXITCODE
