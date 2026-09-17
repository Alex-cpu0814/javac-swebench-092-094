$ErrorActionPreference = "Stop"

$CaseDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DockerDir = Join-Path $CaseDir "docker"
$LogDir = Join-Path $CaseDir "verification\docker"
$ImageName = "javac-case-094-jep:py353-jdk8"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Invoke-DockerLogged {
    param([string]$Name, [string[]]$Arguments)
    $stdout = Join-Path $LogDir "$Name.stdout.log"
    $stderr = Join-Path $LogDir "$Name.stderr.log"
    $process = Start-Process `
        -FilePath "docker.exe" `
        -ArgumentList $Arguments `
        -WorkingDirectory $CaseDir `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr
    if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout }
    if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr }
    if ($process.ExitCode -ne 0) {
        throw "Docker command failed with exit code $($process.ExitCode). See $stderr"
    }
}

Invoke-DockerLogged "docker_build" @("build", "--progress=plain", "-f", "docker/Dockerfile", "-t", $ImageName, ".")
Invoke-DockerLogged "docker_run" @("run", "--rm", "--name", "javac-case-094-jep", $ImageName)
Write-Host "Docker validation completed. Logs: $LogDir"
