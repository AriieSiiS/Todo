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
  $wardrobeUri = 'https://127.0.0.1:47832/v1/wardrobe-snapshot'
  $unauthorized = Invoke-WebRequest `
    -Method Get `
    -Uri $wardrobeUri `
    -SkipCertificateCheck `
    -SkipHttpErrorCheck
  if ($unauthorized.StatusCode -ne 401) {
    throw 'Ropa permite una petición sin autenticar.'
  }
  $wardrobeResponse = Invoke-WebRequest `
    -Method Get `
    -Uri $wardrobeUri `
    -Headers $headers `
    -SkipCertificateCheck
  $wardrobe = $wardrobeResponse.Content | ConvertFrom-Json
  if ($wardrobe.serverId -ne $status.serverId -or $wardrobe.wardrobeVersion -ne 1) {
    throw 'Ropa respondió con una identidad o versión incorrecta.'
  }
  foreach ($name in @('notes', 'expenses', 'wardrobeWearLogs', 'wardrobeImportBatches')) {
    if ($wardrobe.PSObject.Properties.Name -contains $name) {
      throw "Ropa contiene el campo no permitido: $name"
    }
  }
  foreach ($item in $wardrobe.items) {
    if ($item.PSObject.Properties.Name -contains 'imagePath') {
      throw 'Ropa expuso una ruta local de imagen.'
    }
  }
  $notModified = Invoke-WebRequest `
    -Method Get `
    -Uri $wardrobeUri `
    -Headers @{ Authorization = "Bearer $($pairing.token)"; 'If-None-Match' = $wardrobeResponse.Headers.ETag[0] } `
    -SkipCertificateCheck `
    -SkipHttpErrorCheck
  if ($notModified.StatusCode -ne 304) {
    throw 'Ropa no respetó If-None-Match.'
  }
  $photoVerified = $false
  $photo = @($wardrobe.items | Where-Object { $_.imageAvailable -and $_.imageSha256 }) | Select-Object -First 1
  if ($photo) {
    $temporaryPhoto = [System.IO.Path]::GetTempFileName()
    try {
      Invoke-WebRequest `
        -Method Get `
        -Uri "https://127.0.0.1:47832/v1/wardrobe-image/$($photo.id)?variant=original" `
        -Headers $headers `
        -SkipCertificateCheck `
        -OutFile $temporaryPhoto
      $photoVerified = (Get-FileHash -LiteralPath $temporaryPhoto -Algorithm SHA256).Hash -eq $photo.imageSha256
      if (-not $photoVerified) { throw 'La foto no coincide con su SHA-256.' }
    }
    finally {
      Remove-Item -LiteralPath $temporaryPhoto -ErrorAction SilentlyContinue
    }
  }
  $blockedImage = Invoke-WebRequest `
    -Method Get `
    -Uri "https://127.0.0.1:47832/v1/wardrobe-image/$($photo.id)?variant=original" `
    -SkipCertificateCheck `
    -SkipHttpErrorCheck
  if ($blockedImage.StatusCode -ne 401) {
    throw 'Una foto permite una petición sin autenticar.'
  }
  $invalidImage = Invoke-WebRequest `
    -Method Get `
    -Uri 'https://127.0.0.1:47832/v1/wardrobe-image/..%2Fsecret?variant=original' `
    -Headers $headers `
    -SkipCertificateCheck `
    -SkipHttpErrorCheck
  if ($invalidImage.StatusCode -eq 200) {
    throw 'Una ruta manipulada devolvió una foto.'
  }
  [ordered]@{
    paired = ($pairing.protocolVersion -eq 1)
    serverIdMatches = ($pairing.serverId -eq $status.serverId)
    revisionPresent = (-not [string]::IsNullOrWhiteSpace($snapshot.revision))
    tasks = @($snapshot.tasks).Count
    categories = @($snapshot.categories).Count
    projects = @($snapshot.projects).Count
    forbiddenFieldsAbsent = $true
    wardrobeItems = @($wardrobe.items).Count
    packingLists = @($wardrobe.packingLists).Count
    wardrobeEtag = ($notModified.StatusCode -eq 304)
    photoVerified = $photoVerified
    imageAccessRestricted = $true
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
