param(
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$SupabasePublishableKey = $env:SUPABASE_PUBLISHABLE_KEY,
  [string]$SupabaseAllowedEmail = $env:SUPABASE_ALLOWED_EMAIL,
  [string]$SupabaseRedirectUrl = "todo://login-callback"
)

$ErrorActionPreference = "Stop"

$argsList = @(
  "build",
  "apk",
  "--release",
  "--dart-define=SUPABASE_REDIRECT_URL=$SupabaseRedirectUrl"
)

if ($SupabaseUrl) {
  $argsList += "--dart-define=SUPABASE_URL=$SupabaseUrl"
}
if ($SupabasePublishableKey) {
  $argsList += "--dart-define=SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"
}
if ($SupabaseAllowedEmail) {
  $argsList += "--dart-define=SUPABASE_ALLOWED_EMAIL=$SupabaseAllowedEmail"
}

flutter @argsList

Write-Host ""
Write-Host "APK privada generada en build\app\outputs\flutter-apk\app-release.apk"
Write-Host "Si existe android\key.properties se firma con esa keystore; si no, Flutter usa la firma debug como fallback."
