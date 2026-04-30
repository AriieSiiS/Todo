param()

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$serverPath = Join-Path $scriptDir 'server.py'
$workspacePython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

function Resolve-Python {
    if (Test-Path $workspacePython) {
        return $workspacePython
    }

    $pyCommand = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCommand) {
        return @($pyCommand.Source, '-3')
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        return $pythonCommand.Source
    }

    throw "No se encontró Python. Instala Python 3 o usa el runtime de Codex."
}

$python = Resolve-Python
Set-Location $repoRoot

if ($python -is [Array]) {
    & $python[0] $python[1] $serverPath
}
else {
    & $python $serverPath
}
