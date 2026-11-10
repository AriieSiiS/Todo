param(
  [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\Todo'),
  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath (Join-Path $InstallDirectory 'todo_lan_agent.exe')).Path
$task = Get-ScheduledTask -TaskName 'Todo - Android local'
if ($task.Settings.MultipleInstances -ne 'IgnoreNew' -or
    -not ($task.Triggers | Where-Object { $_.Repetition.Interval -eq 'PT1M' })) {
  throw 'La tarea no tiene recuperación cada minuto con una sola instancia.'
}
$processes = @(Get-Process -Name todo_lan_agent -ErrorAction SilentlyContinue |
  Where-Object { $_.Path -eq $target })
if ($processes.Count -ne 1) { throw 'Se esperaba exactamente un agente instalado antes de la prueba.' }
$oldId = $processes[0].Id
Stop-Process -Id $oldId -Force
$processes[0].WaitForExit()
Write-Output 'Caída simulada: esperando la recuperación de Windows sin abrir Todo.'
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
  Start-Sleep -Seconds 1
  $processes = @(Get-Process -Name todo_lan_agent -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $target })
  if ($processes.Count -gt 1) { throw 'Se han iniciado varios agentes.' }
  $listeners = @(Get-NetTCPConnection -LocalPort 47832 -State Listen -ErrorAction SilentlyContinue)
  if ($processes.Count -eq 1 -and $processes[0].Id -ne $oldId -and
      ($listeners | Where-Object { $_.OwningProcess -eq $processes[0].Id })) {
    [ordered]@{ estado='recuperado_y_verificado'; anterior=$oldId; actual=$processes[0].Id;
      puerto=47832; instancias=1 } | ConvertTo-Json
    exit 0
  }
} while ((Get-Date) -lt $deadline)
Start-ScheduledTask -TaskName 'Todo - Android local'
throw 'La recuperación automática no terminó en el plazo esperado; se ha solicitado el arranque de rescate.'
