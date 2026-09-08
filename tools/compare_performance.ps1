[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Baseline,
    [Parameter(Mandatory=$true)][string]$Candidate,
    [double]$Tolerance = 0.35,
    [double]$NoiseFloorMs = 2.0
)
$ErrorActionPreference = "Stop"
if ($Tolerance -lt 0 -or $NoiseFloorMs -lt 0) { throw "Tolerance and NoiseFloorMs must be nonnegative." }
$before = Get-Content -LiteralPath $Baseline -Raw | ConvertFrom-Json
$after = Get-Content -LiteralPath $Candidate -Raw | ConvertFrom-Json
foreach ($field in @('fixture','fixture_version','cpu','gpu','os','godot','display','renderer','viewport','ticks','stations')) {
    if ($null -eq $before.context.$field -or $null -eq $after.context.$field -or $before.context.$field -ne $after.context.$field) {
        throw "Incompatible benchmark context: $field"
    }
}
$regressions = @()
foreach ($name in @('engine_to_test_scene_ready_ms','fixture_create_ms','fixed_tick_ms','serialize_ms','save_verified_ms','load_verified_ms','optimized_frame_ms')) {
    $a = $before.metrics.$name
    $b = $after.metrics.$name
    if ($null -eq $a -and $null -eq $b -and $name -eq 'optimized_frame_ms' -and $before.context.display -eq 'headless') { continue }
    if ($null -eq $a -or $null -eq $b) { throw "Missing metric: $name" }
    foreach ($metric in @($a, $b)) {
        $value = [double]$metric.p95
        if ($metric.samples -lt 1 -or [double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -lt 0) { throw "Invalid metric: $name" }
    }
    if ($a.samples -ne $b.samples) { throw "Different sample counts: $name" }
    $limit = [double]$a.p95 * (1 + $Tolerance) + $NoiseFloorMs
    Write-Output ("{0}: P95 {1:N3} -> {2:N3} ms (local limit {3:N3})" -f $name,$a.p95,$b.p95,$limit)
    if ([double]$b.p95 -gt $limit) { $regressions += $name }
}
if ($regressions.Count -gt 0) { throw "Local performance regression: $($regressions -join ', ')" }
Write-Output 'LOCAL PERFORMANCE TREND PASSED'
