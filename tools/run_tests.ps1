[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Program Files\Godot\Godot.exe",
    [string[]]$Test = @()
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$testCases = @(
    @{
        Name = "TestParityResourceManual"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceManual.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceManual.tscn"
        SuccessMarker = "PARITY RESOURCE MANUAL TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MANUAL TESTS FAILED"
    },
    @{
        Name = "TestParityResourceCollection"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceCollection.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceCollection.tscn"
        SuccessMarker = "PARITY RESOURCE COLLECTION TESTS PASSED"
        FailureMarker = "PARITY RESOURCE COLLECTION TESTS FAILED"
    },
    @{
        Name = "TestParityResourceOwnership"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceOwnership.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceOwnership.tscn"
        SuccessMarker = "PARITY RESOURCE OWNERSHIP TESTS PASSED"
        FailureMarker = "PARITY RESOURCE OWNERSHIP TESTS FAILED"
    },
    @{
        Name = "TestParityResourceOutputUI"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceOutputUI.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceOutputUI.tscn"
        SuccessMarker = "PARITY RESOURCE OUTPUT UI TESTS PASSED"
        FailureMarker = "PARITY RESOURCE OUTPUT UI TESTS FAILED"
    },
    @{
        Name = "TestParityResourceOutputBoundaries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceOutputBoundaries.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceOutputBoundaries.tscn"
        SuccessMarker = "PARITY RESOURCE OUTPUT BOUNDARY TESTS PASSED"
        FailureMarker = "PARITY RESOURCE OUTPUT BOUNDARY TESTS FAILED"
    },
    @{
        Name = "TestParityResourceOutputFractions"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceOutputFractions.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceOutputFractions.tscn"
        SuccessMarker = "PARITY RESOURCE OUTPUT FRACTION TESTS PASSED"
        FailureMarker = "PARITY RESOURCE OUTPUT FRACTION TESTS FAILED"
    },
    @{
        Name = "TestParityResourceJourney"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceJourney.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceJourney.tscn"
        SuccessMarker = "PARITY RESOURCE JOURNEY TESTS PASSED"
        FailureMarker = "PARITY RESOURCE JOURNEY TESTS FAILED"
    },
    @{
        Name = "TestParityResourceInitialCapacity"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceInitialCapacity.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceInitialCapacity.tscn"
        SuccessMarker = "PARITY RESOURCE INITIAL CAPACITY TESTS PASSED"
        FailureMarker = "PARITY RESOURCE INITIAL CAPACITY TESTS FAILED"
    },
    @{
        Name = "TestParityResourceCapacityLegacy"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceCapacityLegacy.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceCapacityLegacy.tscn"
        SuccessMarker = "PARITY RESOURCE CAPACITY LEGACY TESTS PASSED"
        FailureMarker = "PARITY RESOURCE CAPACITY LEGACY TESTS FAILED"
    },
    @{
        Name = "Resource mode query source/compatibility regression"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceModeQuery.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceModeQuery.tscn"
        SuccessMarker = "PARITY RESOURCE MODE QUERY TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MODE QUERY TESTS FAILED"
    },
    @{
        Name = "Resource mode flow source/compatibility regression"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceModeFlow.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceModeFlow.tscn"
        SuccessMarker = "PARITY RESOURCE MODE FLOW TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MODE FLOW TESTS FAILED"
    },
    @{
        Name = "Resource mode manual source/compatibility regression"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceModeManual.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceModeManual.tscn"
        SuccessMarker = "PARITY RESOURCE MODE MANUAL TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MODE MANUAL TESTS FAILED"
    },
    @{
        Name = "Resource mode ui source/compatibility regression"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceModeUI.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceModeUI.tscn"
        SuccessMarker = "PARITY RESOURCE MODE UI TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MODE UI TESTS FAILED"
    },
    @{
        Name = "Resource mode legacy source/compatibility regression"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceModeLegacy.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceModeLegacy.tscn"
        SuccessMarker = "PARITY RESOURCE MODE LEGACY TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MODE LEGACY TESTS FAILED"
    },
    @{
        Name = "Source integer mining, real paid saves and legacy compatibility"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourceMining.tscn"
        ResourcePath = "res://scenes/test/TestParityResourceMining.tscn"
        SuccessMarker = "PARITY RESOURCE MINING TESTS PASSED"
        FailureMarker = "PARITY RESOURCE MINING TESTS FAILED"
    },
    @{
        Name = "Source resource paid placement and formal target selection"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResourcePlacement.tscn"
        ResourcePath = "res://scenes/test/TestParityResourcePlacement.tscn"
        SuccessMarker = "PARITY RESOURCE PLACEMENT TESTS PASSED"
        FailureMarker = "PARITY RESOURCE PLACEMENT TESTS FAILED"
    },
    @{
        Name = "Source per-item input capacity, paid belts and real persistence"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityItemInputCapacity.tscn"
        ResourcePath = "res://scenes/test/TestParityItemInputCapacity.tscn"
        SuccessMarker = "PARITY ITEM INPUT CAPACITY TESTS PASSED"
        FailureMarker = "PARITY ITEM INPUT CAPACITY TESTS FAILED"
    },
    @{
        Name = "Source station slot capacity query and real paid boundaries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParitySlotCapacity.tscn"
        ResourcePath = "res://scenes/test/TestParitySlotCapacity.tscn"
        SuccessMarker = "PARITY SLOT CAPACITY TESTS PASSED"
        FailureMarker = "PARITY SLOT CAPACITY TESTS FAILED"
    },
    @{
        Name = "Source entity buffer and capacity queries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityCapacityQueries.tscn"
        ResourcePath = "res://scenes/test/TestParityCapacityQueries.tscn"
        SuccessMarker = "PARITY CAPACITY QUERY TESTS PASSED"
        FailureMarker = "PARITY CAPACITY QUERY TESTS FAILED"
    },
    @{
        Name = "Source solar sail lifetime query"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParitySailLifetime.tscn"
        ResourcePath = "res://scenes/test/TestParitySailLifetime.tscn"
        SuccessMarker = "PARITY SAIL LIFETIME TESTS PASSED"
        FailureMarker = "PARITY SAIL LIFETIME TESTS FAILED"
    },
    @{
        Name = "Source interstellar trip and route economics queries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityRouteQueries.tscn"
        ResourcePath = "res://scenes/test/TestParityRouteQueries.tscn"
        SuccessMarker = "PARITY ROUTE QUERY TESTS PASSED"
        FailureMarker = "PARITY ROUTE QUERY TESTS FAILED"
    },
    @{
        Name = "Source logistics cargo capacity and local trip scalars"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityLogisticsScalars.tscn"
        ResourcePath = "res://scenes/test/TestParityLogisticsScalars.tscn"
        SuccessMarker = "PARITY LOGISTICS SCALAR TESTS PASSED"
        FailureMarker = "PARITY LOGISTICS SCALAR TESTS FAILED"
    },
    @{
        Name = "Source technology effect and difficulty queries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityEffectQueries.tscn"
        ResourcePath = "res://scenes/test/TestParityEffectQueries.tscn"
        SuccessMarker = "PARITY EFFECT QUERY TESTS PASSED"
        FailureMarker = "PARITY EFFECT QUERY TESTS FAILED"
    },
    @{
        Name = "Source tray batch and construction stack deletion"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityInventoryDiscard.tscn"
        ResourcePath = "res://scenes/test/TestParityInventoryDiscard.tscn"
        SuccessMarker = "PARITY INVENTORY DISCARD TESTS PASSED"
        FailureMarker = "PARITY INVENTORY DISCARD TESTS FAILED"
    },
    @{
        Name = "Source world exploration colonization and active planet commands"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityWorldCommands.tscn"
        ResourcePath = "res://scenes/test/TestParityWorldCommands.tscn"
        SuccessMarker = "PARITY WORLD COMMAND TESTS PASSED"
        FailureMarker = "PARITY WORLD COMMAND TESTS FAILED"
    },
    @{
        Name = "Source world display and tray controls"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityWorldControls.tscn"
        ResourcePath = "res://scenes/test/TestParityWorldControls.tscn"
        SuccessMarker = "PARITY WORLD CONTROL TESTS PASSED"
        FailureMarker = "PARITY WORLD CONTROL TESTS FAILED"
    },
    @{
        Name = "Source world and tray queries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityWorldQueries.tscn"
        ResourcePath = "res://scenes/test/TestParityWorldQueries.tscn"
        SuccessMarker = "PARITY WORLD QUERY TESTS PASSED"
        FailureMarker = "PARITY WORLD QUERY TESTS FAILED"
    },
    @{
        Name = "Source campaign controls"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityCampaignControls.tscn"
        ResourcePath = "res://scenes/test/TestParityCampaignControls.tscn"
        SuccessMarker = "PARITY CAMPAIGN CONTROL DOMAIN TESTS PASSED"
        FailureMarker = "PARITY CAMPAIGN CONTROL DOMAIN TESTS FAILED"
    },
    @{
        Name = "Source campaign UI"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityCampaignUI.tscn"
        ResourcePath = "res://scenes/test/TestParityCampaignUI.tscn"
        SuccessMarker = "PARITY CAMPAIGN UI TESTS PASSED"
        FailureMarker = "PARITY CAMPAIGN UI TESTS FAILED"
    },
    @{
        Name = "Campaign save compatibility"
        ScenePath = Join-Path $repoRoot "scenes\test\TestCampaignPersistence.tscn"
        ResourcePath = "res://scenes/test/TestCampaignPersistence.tscn"
        SuccessMarker = "CAMPAIGN PERSISTENCE TESTS PASSED"
        FailureMarker = "CAMPAIGN PERSISTENCE TESTS FAILED"
    },
    @{
        Name = "Source campaign and achievements"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityProgression.tscn"
        ResourcePath = "res://scenes/test/TestParityProgression.tscn"
        SuccessMarker = "PARITY PROGRESSION TESTS PASSED"
        FailureMarker = "PARITY PROGRESSION TESTS FAILED"
    },
    @{
        Name = "Source research controls"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResearchControls.tscn"
        ResourcePath = "res://scenes/test/TestParityResearchControls.tscn"
        SuccessMarker = "PARITY RESEARCH CONTROL TESTS PASSED"
        FailureMarker = "PARITY RESEARCH CONTROL TESTS FAILED"
    },
    @{
        Name = "Source research boundaries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResearchBoundaries.tscn"
        ResourcePath = "res://scenes/test/TestParityResearchBoundaries.tscn"
        SuccessMarker = "PARITY RESEARCH BOUNDARY TESTS PASSED"
        FailureMarker = "PARITY RESEARCH BOUNDARY TESTS FAILED"
    },
    @{
        Name = "Source research queries"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResearchQueries.tscn"
        ResourcePath = "res://scenes/test/TestParityResearchQueries.tscn"
        SuccessMarker = "PARITY RESEARCH QUERY TESTS PASSED"
        FailureMarker = "PARITY RESEARCH QUERY TESTS FAILED"
    },
    @{
        Name = "Infinite source research"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityInfiniteResearch.tscn"
        ResourcePath = "res://scenes/test/TestParityInfiniteResearch.tscn"
        SuccessMarker = "PARITY INFINITE RESEARCH TESTS PASSED"
        FailureMarker = "PARITY INFINITE RESEARCH TESTS FAILED"
    },
    @{
        Name = "Source research commands"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityResearchCommands.tscn"
        ResourcePath = "res://scenes/test/TestParityResearchCommands.tscn"
        SuccessMarker = "PARITY RESEARCH COMMAND TESTS PASSED"
        FailureMarker = "PARITY RESEARCH COMMAND TESTS FAILED"
    },
    @{
        Name = "Finite source research"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityFiniteResearch.tscn"
        ResourcePath = "res://scenes/test/TestParityFiniteResearch.tscn"
        SuccessMarker = "PARITY FINITE RESEARCH TESTS PASSED"
        FailureMarker = "PARITY FINITE RESEARCH TESTS FAILED"
    },
    @{
        Name = "Dedicated source production"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParitySpecialProduction.tscn"
        ResourcePath = "res://scenes/test/TestParitySpecialProduction.tscn"
        SuccessMarker = "PARITY SPECIAL PRODUCTION TESTS PASSED"
        FailureMarker = "PARITY SPECIAL PRODUCTION TESTS FAILED"
    },
    @{
        Name = "Source recipe commands"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityRecipeChanges.tscn"
        ResourcePath = "res://scenes/test/TestParityRecipeChanges.tscn"
        SuccessMarker = "PARITY RECIPE COMMAND TESTS PASSED"
        FailureMarker = "PARITY RECIPE COMMAND TESTS FAILED"
    },
    @{
        Name = "Source production parity"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityProduction.tscn"
        ResourcePath = "res://scenes/test/TestParityProduction.tscn"
        SuccessMarker = "PARITY PRODUCTION TESTS PASSED"
        FailureMarker = "PARITY PRODUCTION TESTS FAILED"
    },
    @{
        Name = "Production planning"
        ScenePath = Join-Path $repoRoot "scenes\test\TestProductionPlanning.tscn"
        ResourcePath = "res://scenes/test/TestProductionPlanning.tscn"
        SuccessMarker = "PRODUCTION PLANNING TESTS PASSED"
        FailureMarker = "PRODUCTION PLANNING TESTS FAILED"
    },
    @{
        Name = "Source startup parity"
        ScenePath = Join-Path $repoRoot "scenes\test\TestParityStartup.tscn"
        ResourcePath = "res://scenes/test/TestParityStartup.tscn"
        SuccessMarker = "PARITY STARTUP TESTS PASSED"
        FailureMarker = "PARITY STARTUP TESTS FAILED"
    },
    @{
        Name = "Local content packs"
        ScenePath = Join-Path $repoRoot "scenes\test\TestLocalContentPacks.tscn"
        ResourcePath = "res://scenes/test/TestLocalContentPacks.tscn"
        SuccessMarker = "LOCAL CONTENT PACK TESTS PASSED"
        FailureMarker = "LOCAL CONTENT PACK TESTS FAILED"
    },
    @{
        Name = "Single player modes"
        ScenePath = Join-Path $repoRoot "scenes\test\TestSinglePlayerModes.tscn"
        ResourcePath = "res://scenes/test/TestSinglePlayerModes.tscn"
        SuccessMarker = "SINGLE PLAYER MODES TESTS PASSED"
        FailureMarker = "SINGLE PLAYER MODES TESTS FAILED"
    },
    @{
        Name = "Progression parity"
        ScenePath = Join-Path $repoRoot "scenes\test\TestProgressionParity.tscn"
        ResourcePath = "res://scenes/test/TestProgressionParity.tscn"
        SuccessMarker = "PROGRESSION PARITY TESTS PASSED"
        FailureMarker = "PROGRESSION PARITY TESTS FAILED"
    },
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

if ($Test.Count -gt 0) {
    foreach ($requested in $Test) {
        $matches = @($testCases | Where-Object { $_.Name -eq $requested -or [IO.Path]::GetFileNameWithoutExtension($_.ScenePath) -eq $requested })
        if ($matches.Count -ne 1) { throw "Unknown or ambiguous test: $requested" }
    }
    $testCases = @($testCases | Where-Object { $Test -contains $_.Name -or $Test -contains [IO.Path]::GetFileNameWithoutExtension($_.ScenePath) })
    [Console]::Out.WriteLine("Selected related checks: $($testCases.Count); this run is not the full release gate.")
} else {
    [Console]::Out.WriteLine("Full test gate: $($testCases.Count) scenes.")
}

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
    # Product UI visits every workspace at six resolutions and three font scales.
    $frameLimit = if ($testCase.Name -in @("Product shell", "TestParityResourceOutputUI")) { 1200 } else { 600 }
    $startInfo.Arguments = '--headless --path "{0}" --quit-after {3} "{1}" -- --device-settings=res://.godot/gate-device-settings-{2}.cfg' -f $repoRoot, $testCase.ResourcePath, ([guid]::NewGuid().ToString("N")), $frameLimit
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
