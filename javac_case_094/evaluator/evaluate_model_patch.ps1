param(
    [Parameter(Mandatory = $true)]
    [string]$PatchPath,
    [string]$ImageName = "",
    [string]$OutputRoot = "",
    [string]$RunId = "",
    [string]$Label = "",
    [int]$TimeoutSeconds = 1800,
    [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
    [string]$LogLevel = "INFO",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "evaluate_model_patch.py"
$arguments = @(
    $script,
    "--patch", $PatchPath,
    "--timeout", $TimeoutSeconds,
    "--log-level", $LogLevel
)
if ($ImageName) {
    $arguments += @("--image", $ImageName)
}
if ($OutputRoot) {
    $arguments += @("--output-root", $OutputRoot)
}
if ($RunId) {
    $arguments += @("--run-id", $RunId)
}
if ($Label) {
    $arguments += @("--label", $Label)
}
& $PythonExe @arguments
exit $LASTEXITCODE
