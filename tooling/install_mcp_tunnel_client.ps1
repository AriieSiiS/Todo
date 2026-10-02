param(
    [string]$InstallDirectory = (Join-Path $PSScriptRoot '..\mcp_server\.tunnel-client')
)

$ErrorActionPreference = 'Stop'
$architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/openai/tunnel-client/releases/latest'
$pattern = '^tunnel-client-v[0-9.]+-windows-' + $architecture + '\.zip$'
$asset = @($release.assets | Where-Object { $_.name -match $pattern })
if ($asset.Count -ne 1 -or $asset[0].digest -notmatch '^sha256:[a-f0-9]{64}$') {
    throw 'La publicación oficial no contiene un cliente Windows con hash verificable.'
}
$destination = [IO.Path]::GetFullPath($InstallDirectory)
[IO.Directory]::CreateDirectory($destination) | Out-Null
$archive = Join-Path $destination $asset[0].name
Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $archive
$actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedHash = $asset[0].digest.Substring(7)
if ($actualHash -ne $expectedHash) {
    throw 'El archivo descargado no coincide con el hash de la publicación oficial.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
$binary = @(Get-ChildItem -LiteralPath $destination -Filter 'tunnel-client.exe' -File -Recurse)
if ($binary.Count -ne 1) {
    throw 'No se encontró un único ejecutable del cliente oficial.'
}
[pscustomobject]@{
    version = $release.tag_name
    executable = $binary[0].FullName
    archiveSha256 = $actualHash
    executableSha256 = (Get-FileHash -LiteralPath $binary[0].FullName -Algorithm SHA256).Hash
} | ConvertTo-Json
