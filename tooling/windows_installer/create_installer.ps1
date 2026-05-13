param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutputDir = "",
    [string]$InstallerName = "Todo-Setup.exe"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $ProjectRoot "dist\windows"
}

$releaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$stageDir = Join-Path $ProjectRoot "build\installer_stage"
$payloadDir = Join-Path $stageDir "payload_source"
$payloadZip = Join-Path $stageDir "payload.zip"
$installScriptSource = Join-Path $PSScriptRoot "install.cmd"
$installScriptStage = Join-Path $stageDir "install.cmd"
$sedPath = Join-Path $stageDir "todo_installer.sed"
$targetExe = Join-Path $OutputDir $InstallerName
$portableZip = Join-Path $OutputDir "Todo-Windows-Portable.zip"
$iexpress = "C:\Windows\System32\iexpress.exe"

if (-not (Test-Path $releaseDir)) {
    throw "No existe la build de Windows en: $releaseDir"
}

if (-not (Test-Path $iexpress)) {
    throw "No se encontro IExpress en: $iexpress"
}

if (Test-Path $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}

New-Item -ItemType Directory -Path $stageDir | Out-Null
New-Item -ItemType Directory -Path $payloadDir | Out-Null
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Copy-Item -Path (Join-Path $releaseDir "*") -Destination $payloadDir -Recurse -Force
Copy-Item -LiteralPath $installScriptSource -Destination $installScriptStage -Force

if (Test-Path $payloadZip) {
    Remove-Item -LiteralPath $payloadZip -Force
}

Compress-Archive -Path (Join-Path $payloadDir "*") -DestinationPath $payloadZip -CompressionLevel Optimal -Force
Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $portableZip -CompressionLevel Optimal -Force

$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$targetExe
FriendlyName=Instalador de Todo
AppLaunched=cmd.exe /c install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=cmd.exe /c install.cmd
UserQuietInstCmd=cmd.exe /c install.cmd
FILE0=payload.zip
FILE1=install.cmd
[SourceFiles]
SourceFiles0=$stageDir\
[SourceFiles0]
%FILE0%=
%FILE1%=
"@

Set-Content -LiteralPath $sedPath -Value $sed -Encoding ASCII

& $iexpress /N /Q $sedPath | Out-Null

if (-not (Test-Path $targetExe)) {
    throw "No se genero el instalador en: $targetExe"
}

Write-Output "Instalador: $targetExe"
Write-Output "Portable: $portableZip"
