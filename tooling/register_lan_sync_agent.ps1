param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDirectory,
  [switch]$SkipFirewall
)

$ErrorActionPreference = 'Stop'
$resolvedDirectory = (Resolve-Path -LiteralPath $InstallDirectory).Path
$agentPath = Join-Path $resolvedDirectory 'todo_lan_agent.exe'
if (-not (Test-Path -LiteralPath $agentPath -PathType Leaf)) {
  throw 'La instalación no contiene todo_lan_agent.exe.'
}

$taskName = 'Todo - Android local'
$action = New-ScheduledTaskAction -Execute $agentPath -WorkingDirectory $resolvedDirectory
$triggers = @(
  (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME),
  (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 1))
)
$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -MultipleInstances IgnoreNew `
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
  -Trigger $triggers `
  -Settings $settings `
  -Principal $principal `
  -Description 'Mantiene la conexión local cifrada de Todo con Android y Kindle y recupera el agente si se detiene.' `
  -Force | Out-Null

if (-not $SkipFirewall) {
  try {
    & (Join-Path $resolvedDirectory 'limitar_red_todo.ps1') -InstallDirectory $resolvedDirectory | Out-Null
  }
  catch {
    Write-Warning 'No se ha limitado el firewall. Ejecuta limitar_red_todo.ps1 una vez desde PowerShell como administrador.'
  }
}

Start-ScheduledTask -TaskName $taskName
