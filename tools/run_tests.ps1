[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Program Files\Godot\Godot.exe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$scenePath = Join-Path $repoRoot "scenes\test\TestBaseline.tscn"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    [Console]::Error.WriteLine("Godot executable not found: $GodotPath")
    exit 1
}

if (-not (Test-Path -LiteralPath $scenePath -PathType Leaf)) {
    [Console]::Error.WriteLine("Baseline test scene not found: $scenePath")
    exit 1
}

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $GodotPath
$startInfo.Arguments = '--headless --path "{0}" --quit-after 600 "res://scenes/test/TestBaseline.tscn"' -f $repoRoot
$startInfo.WorkingDirectory = $repoRoot
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo

try {
    if (-not $process.Start()) {
        [Console]::Error.WriteLine("Failed to start Godot: $GodotPath")
        exit 1
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()

    $standardOutput = $stdoutTask.Result
    $standardError = $stderrTask.Result
    $godotExitCode = $process.ExitCode
} catch {
    [Console]::Error.WriteLine("Failed to run baseline test: $($_.Exception.Message)")
    exit 1
} finally {
    $process.Dispose()
}

[Console]::Out.Write($standardOutput)
[Console]::Error.Write($standardError)
$outputText = $standardOutput + $standardError

if ($godotExitCode -ne 0 -or $outputText -match "SCRIPT ERROR|Parse Error|BASELINE TESTS FAILED") {
    exit 1
}

exit 0
