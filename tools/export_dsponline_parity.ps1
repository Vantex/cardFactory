param([string]$SourcePath = (Join-Path $PSScriptRoot '../../DSPONLINE'))
$ErrorActionPreference='Stop'
$source=(Resolve-Path -LiteralPath $SourcePath).Path
$commit=git -c "safe.directory=$($source.Replace('\','/'))" -C $source rev-parse HEAD
if($LASTEXITCODE -ne 0){throw 'Cannot read source commit'}
$dirty=git -c "safe.directory=$($source.Replace('\','/'))" -C $source status --porcelain
if($LASTEXITCODE -ne 0 -or $dirty){throw 'Source must be clean'}
node (Join-Path $PSScriptRoot 'export_dsponline_parity.mjs') $source $commit
exit $LASTEXITCODE
