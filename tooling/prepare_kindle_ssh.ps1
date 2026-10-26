param(
  [Parameter(Mandatory = $true)][string]$KindleRoot,
  [string]$PrivateDirectory = (Join-Path $env:LOCALAPPDATA 'Todo\kindle_ssh')
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$root = (Resolve-Path -LiteralPath $KindleRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $root 'system\version.txt') -PathType Leaf)) {
  throw 'La unidad no contiene un sistema Kindle. No se ha modificado nada.'
}
$reader = @('koreader', 'kmc\kpm\packages\koreader\koreader') |
  ForEach-Object { Join-Path $root $_ } |
  Where-Object {
    (Test-Path -LiteralPath (Join-Path $_ 'reader.lua') -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $_ 'dropbear') -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $_ 'plugins\SSH.koplugin\main.lua') -PathType Leaf)
  } | Select-Object -First 1
if (-not $reader) { throw 'No se encuentra el servidor SSH incluido en KOReader.' }
$settingsPath = Join-Path $reader 'settings.reader.lua'
$original = [System.IO.File]::ReadAllText($settingsPath, $utf8)
if ([regex]::Matches($original, '(?m)^return \{\r?$').Count -ne 1 -or
    $original -notmatch '\}\s*$') {
  throw 'El formato de preferencias no es el esperado. Se conserva sin cambios.'
}
$newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
$content = $original
$port = 2222
foreach ($name in @('SSH_port', 'SSH_allow_no_password', 'SSH_key_only_auth', 'SSH_autostart')) {
  $pattern = '(?m)^    \["' + $name + '"\] = (?<value>[^\r\n]+),\r?\n'
  $matchesForKey = [regex]::Matches($content, $pattern)
  $allForKey = [regex]::Matches($content, ('(?m)^    \["' + $name + '"\]'))
  if ($matchesForKey.Count -gt 1 -or $allForKey.Count -ne $matchesForKey.Count) {
    throw 'Hay preferencias SSH con un formato ambiguo. Se conservan sin cambios.'
  }
  if ($matchesForKey.Count -eq 1) {
    $value = $matchesForKey[0].Groups['value'].Value
    if ($name -eq 'SSH_port') {
      if ($value -notmatch '^"?[0-9]{1,5}"?$') { throw 'El puerto SSH guardado no es válido.' }
      $port = [int]$value.Trim('"')
      if ($port -lt 1024 -or $port -gt 65535) { throw 'El puerto SSH debe estar entre 1024 y 65535.' }
    } elseif ($value -notmatch '^(true|false)$') {
      throw 'Las opciones SSH no tienen un formato booleano válido.'
    }
    $content = [regex]::Replace($content, $pattern, '')
  }
}
$disabled = [regex]::Match($original, '(?s)\["plugins_disabled"\]\s*=\s*\{(?<entries>.*?)\}')
if ($disabled.Success -and $disabled.Groups['entries'].Value -match '\["SSH"\]\s*=\s*true') {
  throw 'El complemento SSH está deshabilitado en KOReader. No se han cambiado sus preferencias.'
}
$newSettings = @(
  ('    ["SSH_port"] = "' + $port + '",'),
  '    ["SSH_allow_no_password"] = false,',
  '    ["SSH_key_only_auth"] = true,',
  '    ["SSH_autostart"] = true,'
) -join $newline
$start = [regex]::Match($content, '(?m)^return \{\r?\n')
if (-not $start.Success) { throw 'Falta el inicio de las preferencias de KOReader.' }
$content = $content.Insert($start.Index + $start.Length, $newSettings + $newline)

$private = [System.IO.Path]::GetFullPath($PrivateDirectory)
if ($private -match '["\r\n]') { throw 'El directorio privado contiene caracteres no válidos.' }
$rootFull = [System.IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
if (($private.TrimEnd('\') + '\').StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'La clave privada debe guardarse en el PC, fuera de la unidad del Kindle.'
}
[System.IO.Directory]::CreateDirectory($private) | Out-Null
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = [System.Security.AccessControl.DirectorySecurity]::new()
$acl.SetAccessRuleProtection($true, $false)
$inheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
foreach ($allowedSid in @($sid, [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
  $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $allowedSid, 'FullControl', $inheritance, 'None', 'Allow')
  $acl.AddAccessRule($rule)
}
if ($PSVersionTable.PSEdition -eq 'Core') {
  [System.IO.FileSystemAclExtensions]::SetAccessControl([System.IO.DirectoryInfo]::new($private), $acl)
} else {
  [System.IO.Directory]::SetAccessControl($private, $acl)
}
$key = Join-Path $private 'todo_kindle'
$publicPath = $key + '.pub'
$keygen = Join-Path $env:WINDIR 'System32\OpenSSH\ssh-keygen.exe'
if (-not (Test-Path -LiteralPath $keygen -PathType Leaf)) { throw 'No se encuentra ssh-keygen de Windows.' }
function Invoke-GeneradorClave {
  param([string]$Arguments)
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $keygen
  $info.Arguments = $Arguments
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($info)
  try {
    $output = $process.StandardOutput.ReadToEnd()
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw ('No se ha podido validar o generar la clave SSH: ' + $errorText.Trim()) }
    return $output.Trim()
  } finally { $process.Dispose() }
}
if (-not (Test-Path -LiteralPath $key) -and -not (Test-Path -LiteralPath $publicPath)) {
  Invoke-GeneradorClave ('-q -t ecdsa -b 256 -N "" -C Todo-Kindle -f "' + $key + '"') | Out-Null
}
if (-not (Test-Path -LiteralPath $key -PathType Leaf) -or
    -not (Test-Path -LiteralPath $publicPath -PathType Leaf)) {
  throw 'La pareja de claves está incompleta. No se sobrescriben claves existentes.'
}
$fileAcl = [System.Security.AccessControl.FileSecurity]::new()
$fileAcl.SetAccessRuleProtection($true, $false)
$fileAcl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'Allow'))
if ($PSVersionTable.PSEdition -eq 'Core') {
  [System.IO.FileSystemAclExtensions]::SetAccessControl([System.IO.FileInfo]::new($key), $fileAcl)
} else {
  [System.IO.File]::SetAccessControl($key, $fileAcl)
}
$public = [System.IO.File]::ReadAllText($publicPath, $utf8).Trim()
if ($public -notmatch '^ecdsa-sha2-nistp256 [A-Za-z0-9+/=]+(?: [^\r\n]+)?$') {
  throw 'El formato de la clave pública no es válido.'
}
$derived = Invoke-GeneradorClave ('-y -P "" -f "' + $key + '"')
$identity = ($public -split ' ')[0..1] -join ' '
if ((($derived -split ' ')[0..1] -join ' ') -ne $identity) {
  throw 'La clave privada no corresponde a la clave pública. No se ha tocado el Kindle.'
}

$sshDirectory = Join-Path $reader 'settings\SSH'
$authorizedPath = Join-Path $sshDirectory 'authorized_keys'
$authorized = if (Test-Path -LiteralPath $authorizedPath) {
  [System.IO.File]::ReadAllText($authorizedPath, $utf8)
} else { '' }
$alreadyPresent = @($authorized -split '\r?\n' | Where-Object {
  $_ -notmatch '^\s*#' -and $_.Contains($identity)
}).Count -gt 0
if (-not $alreadyPresent) {
  if ($authorized.Length -gt 0 -and -not $authorized.EndsWith("`n")) { $authorized += "`n" }
  $authorized += $public + "`n"
}
$backup = Join-Path $private ('copias\' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-ffff'))
[System.IO.Directory]::CreateDirectory($backup) | Out-Null
Copy-Item -LiteralPath $settingsPath -Destination (Join-Path $backup 'settings.reader.lua')
if (Test-Path -LiteralPath $authorizedPath) {
  Copy-Item -LiteralPath $authorizedPath -Destination (Join-Path $backup 'authorized_keys')
}
[System.IO.Directory]::CreateDirectory($sshDirectory) | Out-Null
try {
  [System.IO.File]::WriteAllText($authorizedPath, $authorized, $utf8)
  if ([System.IO.File]::ReadAllText($authorizedPath, $utf8) -cne $authorized) { throw 'No se ha verificado la clave copiada.' }
  [System.IO.File]::WriteAllText($settingsPath, $content, $utf8)
  if ([System.IO.File]::ReadAllText($settingsPath, $utf8) -cne $content) { throw 'No se han verificado las preferencias copiadas.' }
} catch {
  Copy-Item -LiteralPath (Join-Path $backup 'settings.reader.lua') -Destination $settingsPath -Force
  if (Test-Path -LiteralPath (Join-Path $backup 'authorized_keys')) {
    Copy-Item -LiteralPath (Join-Path $backup 'authorized_keys') -Destination $authorizedPath -Force
  } else { Remove-Item -LiteralPath $authorizedPath -ErrorAction SilentlyContinue }
  throw
}
[ordered]@{
  estado = 'preparado_pendiente_de_abrir_koreader'
  koreader = $reader
  puerto = $port
  clave_privada = $key
  copia = $backup
  autenticacion = 'solo_clave'
} | ConvertTo-Json
