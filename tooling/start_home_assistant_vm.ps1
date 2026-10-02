param(
    [switch]$Elevated,
    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$vmName = 'Todo-Home-Assistant'
$configPath = Join-Path $env:USERPROFILE 'Documents\Todo\household\twin\home_assistant.json'
$defaultEndpoint = 'http://homeassistant.local'

function Get-HomeAssistantEndpoint {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return $defaultEndpoint
    }
    $configuration = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 |
        ConvertFrom-Json
    $candidate = [string]$configuration.endpoint
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $defaultEndpoint
    }
    $uri = $null
    if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https')) {
        throw 'La dirección de Home Assistant guardada no es válida.'
    }
    return $uri.AbsoluteUri.TrimEnd('/')
}

function Test-HomeAssistant {
    param([string]$Endpoint)
    try {
        $response = Invoke-WebRequest -Uri $Endpoint -UseBasicParsing -TimeoutSec 5
        return $response.StatusCode -eq 200 -and
            $response.Content -match 'Home Assistant'
    } catch {
        return $false
    }
}

function Write-StartResult {
    param([string]$State, [string]$Message)
    [pscustomobject]@{
        estado = $State
        maquina = $vmName
        mensaje = $Message
    } | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding utf8
}

if ($Elevated) {
    if ([string]::IsNullOrWhiteSpace($ResultPath)) {
        throw 'Falta la ruta del resultado del arranque.'
    }
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if (-not $principal.IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Hyper-V requiere permisos de administrador.'
        }
        Import-Module Hyper-V -ErrorAction Stop
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        if ($vm.State -eq 'Paused') {
            Resume-VM -Name $vmName -ErrorAction Stop | Out-Null
        } elseif ($vm.State -eq 'Off' -or $vm.State -eq 'Saved') {
            Start-VM -Name $vmName -ErrorAction Stop | Out-Null
        } elseif ($vm.State -ne 'Running') {
            throw "La máquina está en estado $($vm.State) y no se puede iniciar con seguridad."
        }
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        if ($vm.State -ne 'Running') {
            throw "La máquina quedó en estado $($vm.State)."
        }
        Write-StartResult 'iniciada' 'La máquina virtual está en marcha.'
        exit 0
    } catch {
        Write-StartResult 'error' $_.Exception.Message
        exit 1
    }
}

try {
    $endpoint = Get-HomeAssistantEndpoint
} catch {
    Write-Error "No se pudo leer la dirección de Home Assistant: $($_.Exception.Message)"
    exit 1
}

if (Test-HomeAssistant -Endpoint $endpoint) {
    Write-Output "Home Assistant ya está disponible en $endpoint."
    exit 0
}

$resultPath = Join-Path $env:TEMP (
    'todo_home_assistant_inicio_{0}.json' -f [guid]::NewGuid().ToString('N'))
$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    ('"{0}"' -f $PSCommandPath), '-Elevated', '-ResultPath',
    ('"{0}"' -f $resultPath)
)
try {
    $process = Start-Process -FilePath $powerShell -ArgumentList $arguments `
        -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
} catch {
    Write-Error 'No se concedieron los permisos de administrador. Home Assistant no se ha iniciado.'
    exit 1
}

try {
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        throw 'El arranque de la máquina virtual no devolvió un resultado.'
    }
    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding utf8 |
        ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or $result.estado -ne 'iniciada') {
        throw [string]$result.mensaje
    }
} catch {
    Write-Error "No se pudo iniciar Home Assistant: $($_.Exception.Message)"
    exit 1
} finally {
    Remove-Item -LiteralPath $resultPath -ErrorAction SilentlyContinue
}

$deadline = (Get-Date).AddMinutes(3)
do {
    if (Test-HomeAssistant -Endpoint $endpoint) {
        Write-Output "Home Assistant está listo en $endpoint."
        exit 0
    }
    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $deadline)

Write-Error "La máquina virtual está encendida, pero Home Assistant aún no responde en $endpoint."
exit 2
