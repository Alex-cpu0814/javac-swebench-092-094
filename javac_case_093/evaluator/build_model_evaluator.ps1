param(
    [string]$ImageName = "",
    [string]$RepoUrl = "",
    [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
    [string]$LogLevel = "INFO",
    [int]$TimeoutSeconds = 1800,
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "build_model_evaluator.py"
$arguments = @($script, "--log-level", $LogLevel, "--timeout", $TimeoutSeconds)
if ($ImageName) {
    $arguments += @("--image", $ImageName)
}
if ($RepoUrl) {
    $arguments += @("--repo-url", $RepoUrl)
}
& $PythonExe @arguments
exit $LASTEXITCODE
