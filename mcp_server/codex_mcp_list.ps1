param()

$ErrorActionPreference = 'Stop'

$codexPath = 'C:\Program Files\WindowsApps\OpenAI.Codex_26.422.3464.0_x64__2p2nqsd0c76g0\app\resources\codex.exe'

if (-not (Test-Path $codexPath)) {
    throw "No se encontro codex.exe en la ruta esperada: $codexPath"
}

& $codexPath mcp list
