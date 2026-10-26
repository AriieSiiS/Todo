param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDirectory
)

$ErrorActionPreference = 'Stop'
$resolvedDirectory = (Resolve-Path -LiteralPath $InstallDirectory).Path
$agentPath = Join-Path $resolvedDirectory 'todo_lan_agent.exe'
if (-not (Test-Path -LiteralPath $agentPath -PathType Leaf)) {
  throw 'La instalación no contiene todo_lan_agent.exe.'
}

$taskName = 'Todo - Android local'
$action = New-ScheduledTaskAction -Execute $agentPath -WorkingDirectory $resolvedDirectory
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartCount 5 `
  -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal `
  -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType Interactive `
  -RunLevel Limited

Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Principal $principal `
  -Description 'Comparte de forma cifrada y local las tareas de Todo con Android.' `
  -Force | Out-Null

try {
  & (Join-Path $resolvedDirectory 'limitar_red_todo.ps1') -InstallDirectory $resolvedDirectory | Out-Null
}
catch {
  Write-Warning 'No se ha limitado el firewall. Ejecuta limitar_red_todo.ps1 una vez desde PowerShell como administrador.'
}

Start-ScheduledTask -TaskName $taskName
