param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [string]$NodePath = 'D:\Program Files\nodejs\node.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$versionStart = [System.Diagnostics.ProcessStartInfo]::new()
$versionStart.FileName = $GodotPath
$versionStart.Arguments = '--version'
$versionStart.UseShellExecute = $false
$versionStart.CreateNoWindow = $true
$versionStart.RedirectStandardOutput = $true
$versionStart.RedirectStandardError = $true
$versionProcess = [System.Diagnostics.Process]::new()
$versionProcess.StartInfo = $versionStart
try {
    $null = $versionProcess.Start()
    $version = $versionProcess.StandardOutput.ReadToEnd().Trim()
    $versionError = $versionProcess.StandardError.ReadToEnd()
    $versionProcess.WaitForExit()
    if ($versionProcess.ExitCode -ne 0 -or $version -ne '4.7.2.stable.official.ed1daf0bf') { throw "This preset requires the matching Godot 4.7.2 official editor: $version $versionError" }
} finally { $versionProcess.Dispose() }
$templates = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot/export-templates/4.7.2.stable'))
$manifestPath = Join-Path $templates 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Run tools/prepare_windows_templates.ps1 first.' }
$templatesManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($templatesManifest.version -ne '4.7.2.stable' -or @($templatesManifest.files).Count -ne 6) { throw 'Incomplete or incompatible template manifest.' }
foreach ($entry in $templatesManifest.files) {
    $file = [System.IO.Path]::GetFullPath((Join-Path $templates $entry.file))
    if (-not $file.StartsWith($templates + [System.IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Template path escaped the cache.' }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Template changed: $($entry.file)" }
}
$outputDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot/exports/windows'))
$null = New-Item -ItemType Directory -Force -Path $outputDirectory
$executable = Join-Path $outputDirectory 'CardFactory.exe'
$start = [System.Diagnostics.ProcessStartInfo]::new()
$start.FileName = $GodotPath
$start.Arguments = '--headless --path "{0}" --export-release "Windows Desktop" "{1}"' -f $projectRoot,$executable
$start.WorkingDirectory = $projectRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $start
try {
    $null = $process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $log = $stdout.Result + $stderr.Result
    [System.IO.File]::WriteAllText((Join-Path $outputDirectory 'export.log'),$log)
    if ($process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR|Parse Error|Export failed|resources still in use|ObjectDB instances were leaked') { throw "Windows export failed; see $outputDirectory/export.log" }
} finally { $process.Dispose() }
& $NodePath (Join-Path $PSScriptRoot 'inspect_windows_pack.mjs') (Join-Path $outputDirectory 'CardFactory.pck') (Join-Path $outputDirectory 'pack-inventory.json')
if ($LASTEXITCODE -ne 0) { throw 'Package content inspection failed.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/fixtures/parity/DSPONLINE_LICENSE.txt') -Destination (Join-Path $outputDirectory 'DSPONLINE_LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/fixtures/parity/NOTICE.md') -Destination (Join-Path $outputDirectory 'NOTICE.md')
$hashes = Get-ChildItem -LiteralPath $outputDirectory -File -Recurse | Where-Object { $_.Extension -in '.exe','.pck','.dll','.txt','.md' -and $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(),$_.FullName.Substring($outputDirectory.Length + 1).Replace('\','/')
}
[System.IO.File]::WriteAllLines((Join-Path $outputDirectory 'SHA256SUMS.txt'),$hashes)
Write-Output "WINDOWS EXPORT PREPARED: $outputDirectory; package journeys remain separate acceptance checks."
