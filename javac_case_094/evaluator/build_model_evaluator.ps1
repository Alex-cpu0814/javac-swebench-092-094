$ErrorActionPreference = "Stop"

$EvaluatorDir = $PSScriptRoot
$CaseDir = Split-Path -Parent $EvaluatorDir
$LogDir = Join-Path $CaseDir "verification\evaluator"
$ImageName = "javac-case-094-jep:model-evaluator"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$stdout = Join-Path $LogDir "docker_build.stdout.log"
$stderr = Join-Path $LogDir "docker_build.stderr.log"
$process = Start-Process `
    -FilePath "docker.exe" `
    -ArgumentList @("build", "--progress=plain", "-f", "evaluator/Dockerfile", "-t", $ImageName, ".") `
    -WorkingDirectory $CaseDir `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr
if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout }
if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr }
if ($process.ExitCode -ne 0) {
    throw "Docker evaluator image build failed with exit code $($process.ExitCode). See $stderr"
}
Write-Host "Model evaluator image built: $ImageName" -ForegroundColor Green
