param(
    [string]$InstallDirectory = "$env:LOCALAPPDATA\Programs\Todo"
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Split-Path -Parent $PSScriptRoot)
$webRoot = Join-Path $projectRoot 'web\home_twin'
$source = Join-Path $projectRoot 'assets\home_twin_web\scene.js'
$destination = Join-Path $InstallDirectory 'data\flutter_assets\assets\home_twin_web\scene.js'

if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw 'No se encuentra el visor 3D en la carpeta de Todo.'
}

Push-Location -LiteralPath $webRoot
try {
    & npm.cmd run build
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo compilar el visor 3D.'
    }
} finally {
    Pop-Location
}

Copy-Item -LiteralPath $source -Destination $destination -Force
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
if ($sourceHash -ne $destinationHash) {
    throw 'El visor 3D instalado difiere del compilado.'
}

Write-Output 'Visor 3D actualizado. Pulsa Actualizar maqueta en Todo.'
