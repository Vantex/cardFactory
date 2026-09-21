[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Program Files\Godot\Godot.exe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$testCases = @(
    @{
        Name = "Blueprint persistence"
        ScenePath = Join-Path $repoRoot "scenes\test\TestBlueprintPersistence.tscn"
        ResourcePath = "res://scenes/test/TestBlueprintPersistence.tscn"
        SuccessMarker = "BLUEPRINT PERSISTENCE TESTS PASSED"
        FailureMarker = "BLUEPRINT PERSISTENCE TESTS FAILED"
    },
    @{
        Name = "Editing history"
        ScenePath = Join-Path $repoRoot "scenes\test\TestEditingHistory.tscn"
        ResourcePath = "res://scenes/test/TestEditingHistory.tscn"
        SuccessMarker = "EDITING HISTORY TESTS PASSED"
        FailureMarker = "EDITING HISTORY TESTS FAILED"
    },
    @{
        Name = "Content parity"
        ScenePath = Join-Path $repoRoot "scenes\test\TestContentParity.tscn"
        ResourcePath = "res://scenes/test/TestContentParity.tscn"
        SuccessMarker = "CONTENT PARITY TESTS PASSED"
        FailureMarker = "CONTENT PARITY TESTS FAILED"
    },
    @{
        Name = "Power grids"
        ScenePath = Join-Path $repoRoot "scenes\test\TestPowerGrids.tscn"
        ResourcePath = "res://scenes/test/TestPowerGrids.tscn"
        SuccessMarker = "POWER GRID TESTS PASSED"
        FailureMarker = "POWER GRID TESTS FAILED"
    },
    @{
        Name = "Save recovery"
        ScenePath = Join-Path $repoRoot "scenes\test\TestSaveRecovery.tscn"
        ResourcePath = "res://scenes/test/TestSaveRecovery.tscn"
        SuccessMarker = "SAVE RECOVERY TESTS PASSED"
        FailureMarker = "SAVE RECOVERY TESTS FAILED"
    },
    @{
        Name = "DSPONLINE parity"
        ScenePath = Join-Path $repoRoot "scenes\test\TestDSPOnlineParity.tscn"
        ResourcePath = "res://scenes/test/TestDSPOnlineParity.tscn"
        SuccessMarker = "DSPONLINE PARITY TESTS PASSED"
        FailureMarker = "DSPONLINE PARITY TESTS FAILED"
    },
    @{
        Name = "Performance budgets"
        ScenePath = Join-Path $repoRoot "scenes\test\TestPerformanceBudgets.tscn"
        ResourcePath = "res://scenes/test/TestPerformanceBudgets.tscn"
        SuccessMarker = "PERFORMANCE BUDGET TESTS PASSED"
        FailureMarker = "PERFORMANCE BUDGET TESTS FAILED"
    },
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
    },
    @{
        Name = "State persistence"
        ScenePath = Join-Path $repoRoot "scenes\test\TestStatePersistence.tscn"
        ResourcePath = "res://scenes/test/TestStatePersistence.tscn"
        SuccessMarker = "STATE PERSISTENCE TESTS PASSED"
        FailureMarker = "STATE PERSISTENCE TESTS FAILED"
    },
    @{
        Name = "Simulation core"
        ScenePath = Join-Path $repoRoot "scenes\test\TestSimulationCore.tscn"
        ResourcePath = "res://scenes/test/TestSimulationCore.tscn"
        SuccessMarker = "SIMULATION CORE TESTS PASSED"
        FailureMarker = "SIMULATION CORE TESTS FAILED"
    },
    @{
        Name = "Inventory construction"
        ScenePath = Join-Path $repoRoot "scenes\test\TestInventoryConstruction.tscn"
        ResourcePath = "res://scenes/test/TestInventoryConstruction.tscn"
        SuccessMarker = "INVENTORY CONSTRUCTION TESTS PASSED"
        FailureMarker = "INVENTORY CONSTRUCTION TESTS FAILED"
    },
    @{
        Name = "Advanced canvas"
        ScenePath = Join-Path $repoRoot "scenes\test\TestAdvancedCanvas.tscn"
        ResourcePath = "res://scenes/test/TestAdvancedCanvas.tscn"
        SuccessMarker = "ADVANCED CANVAS TESTS PASSED"
        FailureMarker = "ADVANCED CANVAS TESTS FAILED"
    },
    @{
        Name = "Blueprints"
        ScenePath = Join-Path $repoRoot "scenes\test\TestBlueprints.tscn"
        ResourcePath = "res://scenes/test/TestBlueprints.tscn"
        SuccessMarker = "BLUEPRINT TESTS PASSED"
        FailureMarker = "BLUEPRINT TESTS FAILED"
    },
    @{
        Name = "Progression"
        ScenePath = Join-Path $repoRoot "scenes\test\TestProgression.tscn"
        ResourcePath = "res://scenes/test/TestProgression.tscn"
        SuccessMarker = "PROGRESSION TESTS PASSED"
        FailureMarker = "PROGRESSION TESTS FAILED"
    },
    @{
        Name = "Statistics codex"
        ScenePath = Join-Path $repoRoot "scenes\test\TestStatisticsCodex.tscn"
        ResourcePath = "res://scenes/test/TestStatisticsCodex.tscn"
        SuccessMarker = "STATISTICS CODEX TESTS PASSED"
        FailureMarker = "STATISTICS CODEX TESTS FAILED"
    }
    @{
        Name = "Galaxy logistics"
        ScenePath = Join-Path $repoRoot "scenes\test\TestGalaxyLogistics.tscn"
        ResourcePath = "res://scenes/test/TestGalaxyLogistics.tscn"
        SuccessMarker = "GALAXY LOGISTICS TESTS PASSED"
        FailureMarker = "GALAXY LOGISTICS TESTS FAILED"
    },
    @{
        Name = "Dyson engineering"
        ScenePath = Join-Path $repoRoot "scenes\test\TestDysonEndgame.tscn"
        ResourcePath = "res://scenes/test/TestDysonEndgame.tscn"
        SuccessMarker = "DYSON ENDGAME TESTS PASSED"
        FailureMarker = "DYSON ENDGAME TESTS FAILED"
    },
    @{
        Name = "Offline settlement"
        ScenePath = Join-Path $repoRoot "scenes\test\TestOfflineSettlement.tscn"
        ResourcePath = "res://scenes/test/TestOfflineSettlement.tscn"
        SuccessMarker = "OFFLINE SETTLEMENT TESTS PASSED"
        FailureMarker = "OFFLINE SETTLEMENT TESTS FAILED"
    },
    @{
        Name = "Product shell"
        ScenePath = Join-Path $repoRoot "scenes\test\TestProductShell.tscn"
        ResourcePath = "res://scenes/test/TestProductShell.tscn"
        SuccessMarker = "PRODUCT SHELL TESTS PASSED"
        FailureMarker = "PRODUCT SHELL TESTS FAILED"
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

$importStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$importStartInfo.FileName = $GodotPath
$importStartInfo.Arguments = '--headless --path "{0}" --editor --quit' -f $repoRoot
$importStartInfo.WorkingDirectory = $repoRoot
$importStartInfo.UseShellExecute = $false
$importStartInfo.RedirectStandardOutput = $true
$importStartInfo.RedirectStandardError = $true
$importStartInfo.CreateNoWindow = $true

$importProcess = New-Object System.Diagnostics.Process
$importProcess.StartInfo = $importStartInfo

try {
    if (-not $importProcess.Start()) {
        [Console]::Error.WriteLine("Failed to start Godot import: $GodotPath")
        exit 1
    }

    $importStdoutTask = $importProcess.StandardOutput.ReadToEndAsync()
    $importStderrTask = $importProcess.StandardError.ReadToEndAsync()
    $importProcess.WaitForExit()

    $importStandardOutput = $importStdoutTask.Result
    $importStandardError = $importStderrTask.Result
    $importExitCode = $importProcess.ExitCode
} catch {
    [Console]::Error.WriteLine("Failed to import the Godot project: $($_.Exception.Message)")
    exit 1
} finally {
    $importProcess.Dispose()
}

[Console]::Out.Write($importStandardOutput)
[Console]::Error.Write($importStandardError)
$importOutputText = $importStandardOutput + $importStandardError

if ($importExitCode -ne 0 -or $importOutputText -match "SCRIPT ERROR|Parse Error") {
    [Console]::Error.WriteLine("Godot project import failed.")
    exit 1
}

foreach ($testCase in $testCases) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $GodotPath
    $startInfo.Arguments = '--headless --path "{0}" --quit-after 600 "{1}" -- --device-settings=res://.godot/gate-device-settings-{2}.cfg' -f $repoRoot, $testCase.ResourcePath, ([guid]::NewGuid().ToString("N"))
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

    $hasLifecycleLeak = $outputText -match "ObjectDB instances were leaked|resources still in use at exit"

    if ($godotExitCode -ne 0 -or $outputText -match "SCRIPT ERROR|Parse Error" -or $hasLifecycleLeak -or $outputText.Contains($testCase.FailureMarker) -or $successMarkerCount -ne 1) {
        exit 1
    }
}

exit 0
