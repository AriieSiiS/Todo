param(
    [string]$KeyPath = (Join-Path $env:LOCALAPPDATA 'Todo\ChatGPT\runtime.key')
)

$ErrorActionPreference = 'Stop'
$destination = [IO.Path]::GetFullPath($KeyPath)
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($destination.StartsWith($repository + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'La clave debe guardarse fuera del repositorio.'
}
if ([IO.Directory]::Exists($destination) -or ([IO.File]::Exists($destination) -and ([IO.FileInfo]::new($destination)).Length -gt 0)) {
    throw 'El archivo de la clave ya existe. Utilízalo o elige otra ruta para no sobrescribirlo.'
}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
$secret = Read-Host 'Introduce la clave de ejecución de OpenAI (entrada oculta)' -AsSecureString
if ($secret.Length -eq 0) {
    throw 'No se ha introducido ninguna clave.'
}
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
    $keyValue = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ($keyValue -cnotmatch '^sk-[A-Za-z0-9_-]+$') {
        throw 'La entrada no tiene formato de clave de OpenAI. Copia únicamente la clave completa; no se ha guardado.'
    }
    # Los permisos se aplican antes de escribir la credencial.
    [IO.File]::WriteAllText($destination, '', [Text.UTF8Encoding]::new($false))
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = [Security.AccessControl.FileSecurity]::new()
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'Allow'))
    $keyFile = [IO.FileInfo]::new($destination)
    if ($PSVersionTable.PSEdition -eq 'Core') {
        [IO.FileSystemAclExtensions]::SetAccessControl($keyFile, $acl)
    } else {
        $keyFile.SetAccessControl($acl)
    }
    [IO.File]::WriteAllText($destination, $keyValue, [Text.UTF8Encoding]::new($false))
} finally {
    $keyValue = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secret.Dispose()
}
Write-Output 'Clave guardada localmente con permisos exclusivos. La autenticación se comprobará al conectar el túnel.'
