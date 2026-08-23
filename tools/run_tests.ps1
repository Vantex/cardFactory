[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Program Files\Godot\Godot.exe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$testCases = @(
    @{
        Name = "Baseline"
        ScenePath = Join-Path $repoRoot "scenes\test\TestBaseline.tscn"
        ResourcePath = "res://scenes/test/TestBaseline.tscn"
        SuccessMarker = "BASELINE TESTS PASSED"
        FailureMarker = "BASELINE TESTS FAILED"
    },
    @{
        Name = "Factory workspace"
        ScenePath = Join-Path $repoRoot "scenes\test\TestFactoryWorkspace.tscn"
        ResourcePath = "res://scenes/test/TestFactoryWorkspace.tscn"
        SuccessMarker = "FACTORY WORKSPACE TESTS PASSED"
        FailureMarker = "FACTORY WORKSPACE TESTS FAILED"
    }
)

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    [Console]::Error.WriteLine("Godot executable not found: $GodotPath")
    exit 1
}

foreach ($testCase in $testCases) {
    if (-not (Test-Path -LiteralPath $testCase.ScenePath -PathType Leaf)) {
        [Console]::Error.WriteLine("$($testCase.Name) test scene not found: $($testCase.ScenePath)")
        exit 1
    }
}

foreach ($testCase in $testCases) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $GodotPath
    $startInfo.Arguments = '--headless --path "{0}" --quit-after 600 "{1}"' -f $repoRoot, $testCase.ResourcePath
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
        [Console]::Error.WriteLine("Failed to run $($testCase.Name) test: $($_.Exception.Message)")
        exit 1
    } finally {
        $process.Dispose()
    }

    [Console]::Out.Write($standardOutput)
    [Console]::Error.Write($standardError)
    $outputText = $standardOutput + $standardError
    $outputLines = ($standardOutput + [Environment]::NewLine + $standardError) -split "\r?\n"
    $successMarkerCount = @($outputLines | Where-Object { $_ -ceq $testCase.SuccessMarker }).Count

    if ($successMarkerCount -eq 0) {
        [Console]::Error.WriteLine("$($testCase.Name) success marker missing: expected exactly one complete line '$($testCase.SuccessMarker)'.")
    } elseif ($successMarkerCount -ne 1) {
        [Console]::Error.WriteLine("$($testCase.Name) success marker count invalid: expected exactly one complete line '$($testCase.SuccessMarker)', found $successMarkerCount.")
    }

    if ($godotExitCode -ne 0 -or $outputText -match "SCRIPT ERROR|Parse Error" -or $outputText.Contains($testCase.FailureMarker) -or $successMarkerCount -ne 1) {
        exit 1
    }
}

exit 0
