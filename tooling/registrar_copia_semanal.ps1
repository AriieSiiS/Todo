param(
  [string]$Hora = '04:00',
  [string]$Dia = 'Sunday'
)

# Registra la copia completa semanal. Si Todo está abierto, el script falla y
# la tarea lo reintenta cada hora hasta 6 veces.
$ErrorActionPreference = 'Stop'
$script = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'backup_todo_data_full.ps1')).Path
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $script)
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Dia -At $Hora
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
  -RestartCount 6 -RestartInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName 'CopiaSemanal' -TaskPath '\Todo\' -Action $action `
  -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
[ordered]@{ registrada = $true; tarea = '\Todo\CopiaSemanal'; dia = $Dia; hora = $Hora; script = $script } | ConvertTo-Json
