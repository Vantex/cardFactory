[CmdletBinding()]
param(
 [string]$GodotPath='C:\Program Files\Godot\Godot.exe',
 [string]$ManifestPath='res://tests/fixtures/parity/dsponline_single_player_manifest.json',
 [string]$SourcePath,
 [switch]$RequireComplete
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if($SourcePath){
 $snapshot=Get-Content -LiteralPath (Join-Path $root 'tests/fixtures/parity/dsponline_source_catalog.json') -Encoding UTF8 -Raw | ConvertFrom-Json
 foreach($file in $snapshot.source.files.PSObject.Properties){
  $path=Join-Path $SourcePath $file.Name
  if(-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.Value){throw "Source drift: $($file.Name)"}
 }
 Write-Output 'FROZEN SOURCE FILES MATCH'
}
function Invoke-Godot([string]$Arguments){
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName=$GodotPath
 $info.Arguments=$Arguments
 $info.WorkingDirectory=$root
 $info.UseShellExecute=$false
 $info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true
 $info.RedirectStandardError=$true
 $process=New-Object Diagnostics.Process
 $process.StartInfo=$info
 try {
  $null=$process.Start()
  $a=$process.StandardOutput.ReadToEndAsync()
  $b=$process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  return @{Code=$process.ExitCode;Text=$a.Result+$b.Result}
 } finally {$process.Dispose()}
}
$import=Invoke-Godot '--headless --editor --path . --quit'
if($import.Code -ne 0 -or $import.Text -match 'SCRIPT ERROR|Parse Error'){Write-Output $import.Text;exit 1}
$arguments='--headless --path . --quit-after 600 res://scenes/test/TestDSPOnlineParity.tscn -- --device-settings=res://.godot/parity-device-settings.cfg --parity-manifest="{0}"' -f $ManifestPath
if($RequireComplete){$arguments+=' --parity-require-complete'}
$result=Invoke-Godot $arguments
Write-Output $result.Text
$markers=@(($result.Text -split '\r?\n') | Where-Object {$_ -ceq 'DSPONLINE PARITY TESTS PASSED'}).Count
if($result.Code -ne 0 -or $markers -ne 1 -or $result.Text -match 'SCRIPT ERROR|Parse Error|TESTS FAILED|ObjectDB instances were leaked|resources still in use'){exit 1}
exit 0
