param(
  [string]$ConfigDirectory = (Join-Path $env:LOCALAPPDATA 'Todo\lan_sync')
)

$ErrorActionPreference = 'Stop'
$statusPath = Join-Path $ConfigDirectory 'status.json'
$devicesPath = Join-Path $ConfigDirectory 'paired_devices.json'
if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  throw 'El agente local no ha publicado su estado.'
}

$status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
$pairBody = [ordered]@{
  secret = $status.pairingSecret
  deviceName = 'Prueba automatizada'
} | ConvertTo-Json

$pairing = Invoke-RestMethod `
  -Method Post `
  -Uri 'https://127.0.0.1:47832/v1/pair' `
  -ContentType 'application/json' `
  -Body $pairBody `
  -SkipCertificateCheck

try {
  $headers = @{ Authorization = "Bearer $($pairing.token)" }
  $snapshot = Invoke-RestMethod `
    -Method Get `
    -Uri 'https://127.0.0.1:47832/v1/task-snapshot' `
    -Headers $headers `
    -SkipCertificateCheck

  $forbidden = @(
    'notes',
    'expenses',
    'libraryItems',
    'wardrobeItems',
    'householdItems',
    'plants',
    'recipes',
    'calendarSettings',
    'notificationSettings'
  )
  foreach ($name in $forbidden) {
    if ($snapshot.PSObject.Properties.Name -contains $name) {
      throw "El snapshot local contiene el campo no permitido: $name"
    }
  }
  [ordered]@{
    paired = ($pairing.protocolVersion -eq 1)
    serverIdMatches = ($pairing.serverId -eq $status.serverId)
    revisionPresent = (-not [string]::IsNullOrWhiteSpace($snapshot.revision))
    tasks = @($snapshot.tasks).Count
    categories = @($snapshot.categories).Count
    projects = @($snapshot.projects).Count
    forbiddenFieldsAbsent = $true
  } | ConvertTo-Json
}
finally {
  if (Test-Path -LiteralPath $devicesPath -PathType Leaf) {
    $devicesDocument = Get-Content -LiteralPath $devicesPath -Raw | ConvertFrom-Json
    $remaining = @($devicesDocument.devices | Where-Object { $_.id -ne $pairing.deviceId })
    $cleanDocument = [ordered]@{ devices = $remaining } | ConvertTo-Json -Depth 8
    $temporaryPath = "$devicesPath.test.tmp"
    [System.IO.File]::WriteAllText(
      $temporaryPath,
      $cleanDocument,
      [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $devicesPath -Force
  }
}
