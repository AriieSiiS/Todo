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
  $applicationFilters = Get-NetFirewallApplicationFilter -ErrorAction Stop |
    Where-Object { $_.Program -eq $agentPath }
  $firewallRules = @($applicationFilters | Get-NetFirewallRule -ErrorAction Stop)
  if ($firewallRules.Count -eq 0) {
    $firewallRules = @(
      New-NetFirewallRule `
        -DisplayName 'Todo - Android local' `
        -Description 'Permite compartir tareas solo en la red privada local.' `
        -Direction Inbound `
        -Program $agentPath `
        -Action Allow `
        -Profile Private `
        -RemoteAddress LocalSubnet `
        -Protocol TCP `
        -LocalPort 47832
    )
  }
  foreach ($firewallRule in $firewallRules) {
    $firewallRule | Set-NetFirewallRule `
      -Enabled True `
      -Profile Private `
      -Direction Inbound `
      -Action Allow | Out-Null
    $firewallRule | Get-NetFirewallAddressFilter |
      Set-NetFirewallAddressFilter -RemoteAddress LocalSubnet | Out-Null
  }
}
catch {
  Write-Warning 'No fue posible limitar la regla de red. Revisa el Firewall de Windows.'
}

Start-ScheduledTask -TaskName $taskName
