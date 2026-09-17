param(
    [Parameter(Mandatory = $true)]
    [string]$PatchPath,
    [string]$ImageName = "javac-case-092-jep:model-evaluator",
    [string]$OutputPath = "..\verification\evaluator\model_patch_summary.json"
)

$ErrorActionPreference = "Stop"
if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
    throw "docker.exe was not found. Start Docker Desktop and ensure docker is on PATH."
}

$EvaluatorDir = $PSScriptRoot
$CaseDir = Split-Path -Parent $EvaluatorDir
$Patch = (Resolve-Path -LiteralPath $PatchPath).Path
if ([IO.Path]::IsPathRooted($OutputPath)) {
    $Output = [IO.Path]::GetFullPath($OutputPath)
} else {
    $Output = [IO.Path]::GetFullPath((Join-Path $EvaluatorDir $OutputPath))
}
$OutputDir = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (-not (Test-Path -LiteralPath $Patch -PathType Leaf)) {
    throw "Model patch does not exist: $Patch"
}
docker image inspect $ImageName | Out-Null

$PatchMount = "type=bind,source=$Patch,target=/opt/javac_case_092/model_patch.diff,readonly"
$OutputMount = "type=bind,source=$OutputDir,target=/opt/javac_case_092/host_results"
$ResultPath = "/opt/javac_case_092/host_results/" + (Split-Path -Leaf $Output)
$Arguments = @(
    "run", "--rm", "--name", "javac-case-092-model-eval",
    "--mount", $PatchMount,
    "--mount", $OutputMount,
    "--env", "MODEL_PATCH_PATH=/opt/javac_case_092/model_patch.diff",
    "--env", "RESULT_DIR=/opt/javac_case_092/host_results",
    "--env", "RESULT_PATH=$ResultPath",
    $ImageName
)
$LogDir = Join-Path $CaseDir "verification\evaluator"
$stdout = Join-Path $LogDir "docker_run.stdout.log"
$stderr = Join-Path $LogDir "docker_run.stderr.log"
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
if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) {
    throw "The container did not produce a result file: $Output"
}
Write-Host "Evaluation result: $Output"
if ($process.ExitCode -ne 0) {
    Write-Host "Model patch status: failed (container exit code $($process.ExitCode))" -ForegroundColor Red
    exit $process.ExitCode
}
Write-Host "Model patch status: resolved" -ForegroundColor Green
