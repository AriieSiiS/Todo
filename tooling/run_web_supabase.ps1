param(
    [string]$Port = "4310"
)

$ErrorActionPreference = 'Stop'

$flutter = 'C:\Users\AlejandroAfonso\.puro\envs\stable\flutter\bin\flutter.bat'
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $flutter)) {
    throw "No se encontro Flutter en la ruta esperada: $flutter"
}

Set-Location $projectRoot

& $flutter run -d web-server --web-port $Port `
  --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hgdzwoieicreenpapese.supabase.co `
  --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_7QgBLNA353YvBgI2dPlnaw_R_tkfjtS `
  --dart-define=SUPABASE_ALLOWED_EMAIL=ariesix20@gmail.com `
  --dart-define=SUPABASE_REDIRECT_URL=http://127.0.0.1:$Port
