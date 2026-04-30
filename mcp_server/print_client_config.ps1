param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $scriptDir 'start_mcp.ps1'

$config = @{
    mcpServers = @{
        todo = @{
            command = 'powershell'
            args = @(
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                $startScript
            )
        }
    }
}

$config | ConvertTo-Json -Depth 6
