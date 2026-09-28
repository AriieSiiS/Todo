$ErrorActionPreference = 'Stop'
$resultPath = Join-Path $env:USERPROFILE 'Documents\HomeAssistant\arranque_manual.json'

try {
    Import-Module Hyper-V -ErrorAction Stop
    $before = Get-VM -Name 'Todo-Home-Assistant' -ErrorAction Stop
    Set-VM -Name 'Todo-Home-Assistant' -AutomaticStartAction Nothing -ErrorAction Stop
    $after = Get-VM -Name 'Todo-Home-Assistant' -ErrorAction Stop
    if ($after.AutomaticStartAction -ne 'Nothing' -or $after.State -ne $before.State) {
        throw 'No se pudo verificar el arranque manual sin cambiar el estado de la máquina.'
    }
    [pscustomobject]@{
        estado = 'verificado'
        maquina = $after.Name
        encendida = ($after.State -eq 'Running')
        arranque = [string]$after.AutomaticStartAction
        apagado = [string]$after.AutomaticStopAction
    } | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding utf8
} catch {
    [pscustomobject]@{
        estado = 'error'
        mensaje = $_.Exception.Message
    } | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding utf8
    throw
}
