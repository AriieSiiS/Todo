param(
    [string]$KeyPath = (Join-Path $env:LOCALAPPDATA 'Todo\ChatGPT\runtime.key')
)

$ErrorActionPreference = 'Stop'
$destination = [IO.Path]::GetFullPath($KeyPath)
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($destination.StartsWith($repository + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'La clave debe guardarse fuera del repositorio.'
}
if (Test-Path -LiteralPath $destination) {
    throw 'El archivo de la clave ya existe. Utilízalo o elige otra ruta para no sobrescribirlo.'
}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
$secret = Read-Host 'Introduce la clave de ejecución de OpenAI (entrada oculta)' -AsSecureString
if ($secret.Length -eq 0) {
    throw 'No se ha introducido ninguna clave.'
}
# Se crea primero un archivo vacío con acceso exclusivo del usuario actual.
[IO.File]::WriteAllText($destination, '', [Text.UTF8Encoding]::new($false))
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = [Security.AccessControl.FileSecurity]::new()
$acl.SetOwner($sid)
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'Allow'))
Set-Acl -LiteralPath $destination -AclObject $acl
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
    [IO.File]::WriteAllText($destination, [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer), [Text.UTF8Encoding]::new($false))
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secret.Dispose()
}
Write-Output 'La clave se ha guardado fuera del repositorio, con permisos exclusivos del usuario.'
