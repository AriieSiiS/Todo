$ErrorActionPreference = "Stop"

flutter build apk --release
if ($LASTEXITCODE -ne 0) {
  throw 'No se pudo generar la APK privada.'
}

Write-Host ""
Write-Host "APK privada generada en build\app\outputs\flutter-apk\app-release.apk"
Write-Host "La APK no contiene datos de Supabase y solo usa la red Wi-Fi local."
Write-Host "Si existe android\key.properties se firma con esa keystore; si no, Flutter usa la firma debug como fallback."
