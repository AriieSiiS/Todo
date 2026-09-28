param(
    [string]$SourceDirectory = 'build\windows\x64\runner\Debug',
    [string]$InstallDirectory = "$env:LOCALAPPDATA\Programs\Todo"
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path.TrimEnd('\')
$destination = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $source 'todo.exe'))) {
    throw 'La compilación de Windows no contiene todo.exe.'
}
if (Get-Process -Name 'todo' -ErrorAction SilentlyContinue) {
    throw 'Cierra Todo antes de actualizar la instalación.'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$copied = 0
foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\')
    $target = Join-Path $destination $relative
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $existingHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($sourceHash -eq $existingHash) {
            $copied++
            continue
        }
    }
    New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force |
        Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "Falló la verificación de $relative."
    }
    $copied++
}
Write-Output "Instalación actualizada y verificada: $copied archivos."
