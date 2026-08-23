[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Program Files\Godot\Godot.exe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$scenePath = Join-Path $repoRoot "scenes\test\TestBaseline.tscn"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot executable not found: $GodotPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $scenePath -PathType Leaf)) {
    Write-Error "Baseline test scene not found: $scenePath"
    exit 1
}

$output = & $GodotPath --headless --path $repoRoot "res://scenes/test/TestBaseline.tscn" 2>&1
$godotExitCode = $LASTEXITCODE
$outputText = $output | Out-String

$output | Write-Output

if ($godotExitCode -ne 0 -or $outputText -match "SCRIPT ERROR|Parse Error|BASELINE TESTS FAILED") {
    exit 1
}

exit 0
