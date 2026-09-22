param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigDirectory,
  [Parameter(Mandatory = $true)]
  [string]$ServerId
)

$ErrorActionPreference = 'Stop'
$resolvedDirectory = [System.IO.Path]::GetFullPath($ConfigDirectory)
[System.IO.Directory]::CreateDirectory($resolvedDirectory) | Out-Null

$pfxPath = Join-Path $resolvedDirectory 'server.pfx'
$cerPath = Join-Path $resolvedDirectory 'server.cer'
$configPath = Join-Path $resolvedDirectory 'certificate.json'

if ((Test-Path -LiteralPath $pfxPath -PathType Leaf) -and
    (Test-Path -LiteralPath $cerPath -PathType Leaf) -and
    (Test-Path -LiteralPath $configPath -PathType Leaf)) {
  exit 0
}

$passwordBytes = New-Object byte[] 32
$randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $randomGenerator.GetBytes($passwordBytes)
}
finally {
  $randomGenerator.Dispose()
}
$password = [Convert]::ToBase64String($passwordBytes)
$dnsName = "todo-$ServerId.local"
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
try {
  $distinguishedName = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new("CN=$dnsName")
  $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
    $distinguishedName,
    $rsa,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
  )
  $constraints = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true)
  $usage = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
    [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
    [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment,
    $true
  )
  $serverAuthOid = [System.Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.1')
  $enhancedUsageOids = [System.Security.Cryptography.OidCollection]::new()
  $enhancedUsageOids.Add($serverAuthOid) | Out-Null
  $enhancedUsage = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new(
    $enhancedUsageOids,
    $false
  )
  $subjectAlternativeNames = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
  $subjectAlternativeNames.AddDnsName($dnsName)
  $subjectAlternativeNames.AddDnsName('localhost')
  $request.CertificateExtensions.Add($constraints)
  $request.CertificateExtensions.Add($usage)
  $request.CertificateExtensions.Add($enhancedUsage)
  $request.CertificateExtensions.Add($subjectAlternativeNames.Build())
  $certificate = $request.CreateSelfSigned(
    [DateTimeOffset]::UtcNow.AddMinutes(-5),
    [DateTimeOffset]::UtcNow.AddYears(5)
  )
  $pfxBytes = $certificate.Export(
    [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx,
    $password
  )
  $cerBytes = $certificate.Export(
    [System.Security.Cryptography.X509Certificates.X509ContentType]::Cert
  )
  [System.IO.File]::WriteAllBytes($pfxPath, $pfxBytes)
  [System.IO.File]::WriteAllBytes($cerPath, $cerBytes)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $fingerprintBytes = $sha256.ComputeHash($cerBytes)
    $fingerprint = ([System.BitConverter]::ToString($fingerprintBytes) -replace '-', '').ToLowerInvariant()
  }
  finally {
    $sha256.Dispose()
  }
  $config = [ordered]@{
    pfxPath = $pfxPath
    pfxPassword = $password
    certificatePath = $cerPath
    fingerprintSha256 = $fingerprint
    createdAt = [DateTime]::UtcNow.ToString('o')
  }
  $json = $config | ConvertTo-Json -Depth 4
  [System.IO.File]::WriteAllText(
    $configPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
  )
}
finally {
  if ($null -ne $certificate) { $certificate.Dispose() }
  $rsa.Dispose()
}
