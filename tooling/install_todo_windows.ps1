param(
    [string]$SourceDirectory = 'build\windows\x64\runner\Release',
    [string]$InstallDirectory = "$env:LOCALAPPDATA\Programs\Todo"
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path.TrimEnd('\')
$destination = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $source 'todo.exe'))) {
    throw 'La compilación de Windows no contiene todo.exe.'
}
# La compilación de depuración ocupa el doble de memoria: solo se instala la final.
if (Test-Path -LiteralPath (Join-Path $source 'data\flutter_assets\kernel_blob.bin')) {
    throw 'Es una compilación de depuración. Instala la final: flutter build windows --release.'
}
if (Get-Process -Name 'todo' -ErrorAction SilentlyContinue) {
    throw 'Cierra Todo antes de actualizar la instalación.'
}
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'build_lan_sync_agent.ps1') -ProjectRoot $projectRoot -OutputDirectory $source
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo actualizar el agente local antes de instalar Todo.'
}
$agentPath = Join-Path $destination 'todo_lan_agent.exe'
# La tarea programada reinicia el agente en segundos: se pausa mientras se copia.
$agentTask = Get-ScheduledTask -TaskName 'Todo - Android local' -ErrorAction SilentlyContinue
if ($agentTask) {
    Stop-ScheduledTask -InputObject $agentTask
    Disable-ScheduledTask -InputObject $agentTask | Out-Null
}
$agents = @(Get-Process -Name 'todo_lan_agent' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $agentPath })
foreach ($agent in $agents) {
    Stop-Process -Id $agent.Id -Force
    $agent.WaitForExit()
}
try {
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
    # Restos de una instalación de depuración anterior que la final no usa.
    Remove-Item -LiteralPath (Join-Path $destination 'data\flutter_assets\kernel_blob.bin') -Force -ErrorAction SilentlyContinue
}
finally {
    if ($agentTask) {
        Enable-ScheduledTask -InputObject $agentTask | Out-Null
        Start-ScheduledTask -InputObject $agentTask
    }
    elseif ($agents.Count -gt 0) {
        Start-Process -FilePath $agentPath -WorkingDirectory $destination -WindowStyle Hidden
    }
}
Write-Output "Instalación actualizada y verificada: $copied archivos."
