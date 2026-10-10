param([Parameter(Mandatory = $true)][string]$RuntimeDirectory)

$ErrorActionPreference = 'Stop'
$runtimePath = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$task = Get-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\' -ErrorAction SilentlyContinue
if ($task -and $task.State -eq 'Running') {
  Stop-ScheduledTask -TaskName 'SeguimientoCompras' -TaskPath '\Todo\'
}
# Solo procesos del servicio y del perfil Edge privado, nunca el navegador personal.
$enginePath = Join-Path $runtimePath 'engine.py'
$profilePath = Join-Path $runtimePath 'browser-profile'
$processes = @(Get-CimInstance Win32_Process)
$targets = @($processes | Where-Object {
  ($_.Name -in @('python.exe', 'pythonw.exe') -and $_.CommandLine.Contains($enginePath)) -or
  ($_.Name -eq 'msedge.exe' -and $_.CommandLine.Contains($profilePath))
})
foreach ($process in $targets) {
  Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}
