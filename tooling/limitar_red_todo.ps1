[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\Todo'))
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$program = [IO.Path]::GetFullPath((Join-Path $InstallDirectory 'todo_lan_agent.exe'))
if (-not (Test-Path -LiteralPath $program -PathType Leaf)) { throw 'No se encuentra el agente instalado de Todo.' }
if (-not $PSCmdlet.ShouldProcess($program, 'Permitir solo la red privada y desactivar las reglas antiguas')) { return }
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Windows requiere PowerShell como administrador para limitar el firewall de Todo.'
}
$names = @('Todo-LAN-Privada-TCP', 'Todo-LAN-Privada-MDNS')
$existing = @(Get-NetFirewallApplicationFilter -ErrorAction Stop |
  Where-Object { $_.Program -eq $program } | Get-NetFirewallRule -ErrorAction Stop |
  Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' })
foreach ($spec in @(
  @{Name=$names[0]; Protocol='TCP'; Port=47832},
  @{Name=$names[1]; Protocol='UDP'; Port=5353}
)) {
  $rule = Get-NetFirewallRule -Name $spec.Name -ErrorAction SilentlyContinue
  if ($rule) {
    $rule | Set-NetFirewallRule -Enabled True -Profile Private -Direction Inbound -Action Allow `
      -Program $program -EdgeTraversalPolicy Block -Protocol $spec.Protocol -LocalPort $spec.Port -RemoteAddress LocalSubnet | Out-Null
  } else {
    New-NetFirewallRule -Name $spec.Name -DisplayName ('Todo - red privada ' + $spec.Protocol) `
      -Description 'Conexión local de Todo con Android y Kindle.' -Enabled True -Profile Private `
      -Direction Inbound -Action Allow -Program $program -Protocol $spec.Protocol `
      -LocalPort $spec.Port -RemoteAddress LocalSubnet -EdgeTraversalPolicy Block | Out-Null
  }
}
foreach ($rule in $existing) {
  if ($names -notcontains $rule.Name) { $rule | Disable-NetFirewallRule | Out-Null }
}
foreach ($name in $names) {
  $rule = Get-NetFirewallRule -Name $name
  $address = $rule | Get-NetFirewallAddressFilter
  $application = $rule | Get-NetFirewallApplicationFilter
  if ($rule.Enabled -ne 'True' -or $rule.Profile -ne 'Private' -or
      $application.Program -ne $program -or @($address.RemoteAddress).Count -ne 1 -or
      @($address.RemoteAddress)[0] -ne 'LocalSubnet') { throw 'La regla privada no quedó verificada.' }
  $port = $rule | Get-NetFirewallPortFilter
  $expectedPort = if ($name -eq $names[0]) { '47832' } else { '5353' }
  $expectedProtocol = if ($name -eq $names[0]) { @('TCP','6') } else { @('UDP','17') }
  if (@($port.LocalPort).Count -ne 1 -or @($port.LocalPort)[0] -ne $expectedPort -or
      $expectedProtocol -notcontains [string]$port.Protocol) { throw 'Los puertos no quedaron verificados.' }
}
[ordered]@{estado='limitado_y_verificado';programa=$program;reglas=$names} | ConvertTo-Json
