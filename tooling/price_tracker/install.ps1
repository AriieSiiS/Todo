param(
  [string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'Todo\price_tracker'),
  [string]$DataRoot = (Join-Path $env:USERPROFILE 'Documents\Todo'),
  [string]$Python = 'python',
  [switch]$SkipDependencies
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $RuntimeDirectory -Force | Out-Null
$runtimePath = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$venv = Join-Path $runtimePath 'venv'
$interpreter = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $interpreter -PathType Leaf)) {
  & $Python -m venv $venv
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el entorno de seguimiento.' }
}
if (-not $SkipDependencies) {
  & $interpreter -m pip install --quiet 'changedetection.io==0.60.8' 'playwright==1.58.0'
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar changedetection.io.' }
}
$existingTask = Get-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\' -ErrorAction SilentlyContinue
if ($existingTask -and $existingTask.State -eq 'Running') {
  & (Join-Path $PSScriptRoot 'stop.ps1') -RuntimeDirectory $runtimePath
}
& (Join-Path $PSScriptRoot 'stop.ps1') -RuntimeDirectory $runtimePath
foreach ($fileName in @('service.py', 'engine.py', 'notify.ps1', 'stop.ps1')) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $fileName) -Destination (Join-Path $runtimePath $fileName) -Force
}
# La tarea usa pythonw: ningún terminal visible al arrancar la sesión.
$pythonw = Join-Path $venv 'Scripts\pythonw.exe'
$arguments = '"{0}" --runtime "{1}" --data-root "{2}"' -f (Join-Path $runtimePath 'service.py'), $runtimePath, $DataRoot
$action = New-ScheduledTaskAction -Execute $pythonw -Argument $arguments -WorkingDirectory $runtimePath
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\' -Action $action `
  -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\'
[ordered]@{ installed = $true; runtime = $runtimePath; engineVersion = '0.60.8'; intervalHours = 24 } | ConvertTo-Json
