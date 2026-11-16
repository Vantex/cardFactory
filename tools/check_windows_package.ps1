param([switch]$Graphics, [switch]$DefaultRenderer, [ValidateSet('new','resume','rounding','world','worldcommands','discard','routequeries','resourceplacement','resourcemining','resourcemode','resourcecapacity')][string[]]$Phases = @('new','resume','rounding','world','worldcommands','discard','routequeries','resourceplacement','resourcemining','resourcemode','resourcecapacity'), [string]$NodePath = 'D:\Program Files\nodejs\node.exe', [string]$CheckDirectory = '')
$ErrorActionPreference = 'Stop'
if ($Graphics -and $DefaultRenderer) { throw 'Choose either OpenGL Graphics or DefaultRenderer.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$product = [IO.Path]::GetFullPath((Join-Path $root '.godot/exports/windows'))
$checks = if ($CheckDirectory) { [IO.Path]::GetFullPath($CheckDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root '.godot/windows-package-check')) }
$check = Join-Path $checks ([Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Force -Path $check
foreach ($name in @('CardFactory.exe','CardFactory.pck')) {
    Copy-Item -LiteralPath (Join-Path $product $name) -Destination (Join-Path $check $name)
    if ((Get-FileHash -LiteralPath (Join-Path $product $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $check $name)).Hash) { throw "Copied package differs: $name" }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'WindowsPackageProbe.gd') -Destination (Join-Path $check 'package_probe.gd')
Copy-Item -LiteralPath (Join-Path $root 'tests/fixtures/task27-legacy-metadata-save.json') -Destination (Join-Path $check 'legacy-metadata-save.json')
if ('worldcommands' -in $Phases) {
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_world_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled world command fixture preparation failed.' }
}
if ('discard' -in $Phases) {
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_discard_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled inventory discard fixture preparation failed.' }
}
if ('routequeries' -in $Phases) {
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_route_query_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled route query fixture preparation failed.' }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_sail_lifetime_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled sail lifetime fixture preparation failed.' }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_capacity_query_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled capacity query fixture preparation failed.' }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_slot_capacity_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled slot capacity query fixture preparation failed.' }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_item_input_capacity_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled per-item input capacity query fixture preparation failed.' }
}
if ('resourceplacement' -in $Phases) {
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_resource_placement_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Controlled resource placement instrumentation preparation failed.' }
}
if ('resourcemining' -in $Phases) {
    if ('resourceplacement' -notin $Phases) {
        & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_resource_placement_cases.mjs') $check $checks
        if ($LASTEXITCODE -ne 0) { throw 'Mining resource adapter preparation failed.' }
    }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_mining_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Mining instrumentation preparation failed.' }
}
if ('resourcemode' -in $Phases) {
    if ('resourceplacement' -notin $Phases -and 'resourcemining' -notin $Phases) {
        & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_resource_placement_cases.mjs') $check $checks
        if ($LASTEXITCODE -ne 0) { throw 'Resource mode adapter preparation failed.' }
    }
    if ('resourcemining' -notin $Phases) {
        & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_mining_cases.mjs') $check $checks
        if ($LASTEXITCODE -ne 0) { throw 'Resource mode mining adapter preparation failed.' }
    }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_resource_mode_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Resource mode instrumentation preparation failed.' }
}
if ('resourcecapacity' -in $Phases) {
    if ('resourceplacement' -notin $Phases -and 'resourcemining' -notin $Phases -and 'resourcemode' -notin $Phases) {
        & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_resource_placement_cases.mjs') $check $checks
        if ($LASTEXITCODE -ne 0) { throw 'Initial capacity resource adapter preparation failed.' }
    }
    if ('resourcemining' -notin $Phases -and 'resourcemode' -notin $Phases) {
        & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_mining_cases.mjs') $check $checks
        if ($LASTEXITCODE -ne 0) { throw 'Initial capacity old primary adapter preparation failed.' }
    }
    & $NodePath (Join-Path $PSScriptRoot 'prepare_windows_resource_capacity_cases.mjs') $check $checks
    if ($LASTEXITCODE -ne 0) { throw 'Initial capacity instrumentation preparation failed.' }
}
[IO.File]::WriteAllText((Join-Path $check 'override.cfg'), "[autoload]`nPackageProbe=`"*res://package_probe.gd`"`n")
$roaming = Join-Path $check 'profile/Roaming'
$local = Join-Path $check 'profile/Local'
$null = New-Item -ItemType Directory -Force -Path $roaming,$local
foreach ($phase in $Phases) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $check 'CardFactory.exe'
    $driver = if ($DefaultRenderer) { '' } elseif ($Graphics) { '--rendering-driver opengl3' } else { '--headless' }
    $start.Arguments = '{0} --quit-after 3600 --log-file "{1}" -- --probe-root="{2}" --probe-phase={3} --device-settings="{4}"' -f $driver,(Join-Path $check "$phase-engine.log"),$check,$phase,(Join-Path $check 'device.cfg')
    $start.WorkingDirectory = $check
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['APPDATA'] = $roaming
    $start.EnvironmentVariables['LOCALAPPDATA'] = $local
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $a = $process.StandardOutput.ReadToEndAsync()
        $b = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $log = $a.Result + $b.Result
        [IO.File]::WriteAllText((Join-Path $check "$phase.log"),$log)
        Write-Output $log
        $marker = "WINDOWS PACKAGE $($phase.ToUpperInvariant()) TESTS PASSED"
        $markers = @(($log -split '\r?\n') | Where-Object { $_ -ceq $marker }).Count
        $unexpectedErrors = @(($log -split '\r?\n') | Where-Object { $_ -match '^ERROR:' -and $_ -cne 'ERROR: Failed to read the root certificate store.' })
        if ($process.ExitCode -ne 0 -or $markers -ne 1 -or $unexpectedErrors.Count -gt 0 -or $log -match 'SCRIPT ERROR|Parse Error|PACKAGE FAIL|ObjectDB instances were leaked|resources still in use') { throw "Exported package $phase failed: $check/$phase.log" }
    } finally { $process.Dispose() }
}
$jsonArguments = @((Join-Path $PSScriptRoot 'check_saved_json.mjs'), $check)
if ('world' -in $Phases) { $jsonArguments += '--world' }
& $NodePath @jsonArguments
if ($LASTEXITCODE -ne 0) { throw "Standard saved JSON verification failed: $check" }
$renderer = if ($DefaultRenderer) { 'project default' } elseif ($Graphics) { 'opengl3' } else { 'headless' }
$record = @{ checked_at=[DateTime]::UtcNow.ToString('o'); graphics=([bool]$Graphics -or [bool]$DefaultRenderer); renderer=$renderer; executable_sha256=(Get-FileHash -LiteralPath (Join-Path $check 'CardFactory.exe')).Hash.ToLowerInvariant(); pck_sha256=(Get-FileHash -LiteralPath (Join-Path $check 'CardFactory.pck')).Hash.ToLowerInvariant(); phases=$Phases; instrumentation='Temporary autoload override and actual synthetic legacy fixtures outside the byte-identical product PCK; automatic controls, not human input. Rounding, world, worldcommands and discard phases are controlled save/metadata/command regressions; routequeries includes controlled read-only entity capacity, station slot capacity, route and sail lifetime comparisons without legal-save or dispatch claims, separate from the new/resume journey. Resourceplacement covers funded16extractor bindings,15atomic boundaries,formal16Inspector targets and32actual primary saves,not earned growth or throughput. Resourcemining adds16actual paid count-one/fullEngine partial/resumed resources,32primary roundtrips,3actual old primary loads/3continuation saves/27debt rejects/3fraction boundaries;controlled source technology/funding,not full11520numeric corpus/nativegroup/publicresourcemode/earnedgrowth.' }
if ('resourcemode' -in $Phases) {
    $record.instrumentation += ' Resourcemode executes all4328query/36fixture rejects/48controlled-capacity fullEngine mode sequences and144primary/312manual resource-domain projections and6primary/5legal old fractional profiles and35primary/formal actual exported Main setting buttons and3save operations.187distinct primary+1UI backup;initial source capacities are validated separately by resourcecapacity;manual output destination difference remains;not full key or earned growth acceptance.'
}
if ('resourcecapacity' -in $Phases) {
    $record.instrumentation += ' Resourcecapacity verifies12source initial states/1268generated andregistered reserves/12actual initial primary reloads/19fixture drift rejects/3actual old primary copies with3resaves and3fullEngine60tick continuation primarys/36capacity rejects.18new primary+3old backups;colony prerequisites supplied,not earned colonization/growth or full query key acceptance.'
}
[IO.File]::WriteAllText((Join-Path $check 'result.json'),($record | ConvertTo-Json) + [Environment]::NewLine)
$completeJourney = ($Phases.Count -eq 11 -and -not (@('new','resume','rounding','world','worldcommands','discard','routequeries','resourceplacement','resourcemining','resourcemode','resourcecapacity') | Where-Object { $_ -notin $Phases }))
if ($completeJourney) { Write-Output "WINDOWS PACKAGE AUTOMATIC JOURNEY PASSED: $check" }
else { Write-Output "WINDOWS PACKAGE SELECTED PHASES PASSED: $check" }
