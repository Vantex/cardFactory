param([string]$Version = '4.7.2-stable')
$ErrorActionPreference = 'Stop'
if ($Version -ne '4.7.2-stable') { throw 'Task 27 requires the matching frozen Godot 4.7.2 templates.' }
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cache = Join-Path $projectRoot '.godot/export-templates'
$null = New-Item -ItemType Directory -Force -Path $cache
$archiveName = "Godot_v${Version}_export_templates.tpz"
$archive = Join-Path $cache $archiveName
$checksums = Join-Path $cache 'SHA512-SUMS.txt'
$baseUrl = "https://github.com/godotengine/godot-builds/releases/download/$Version"
if (-not (Test-Path -LiteralPath $checksums)) {
    & curl.exe --silent --show-error --fail --location --retry 2 "$baseUrl/SHA512-SUMS.txt" --output $checksums
    if ($LASTEXITCODE -ne 0) { throw 'Official checksum download failed.' }
}
$line = Get-Content -LiteralPath $checksums | Where-Object { $_ -match ('\s+\*?' + [regex]::Escape($archiveName) + '$') }
if (@($line).Count -ne 1) { throw 'The official checksum list does not uniquely identify the template archive.' }
$expected = ($line -split '\s+')[0].ToLowerInvariant()
if (-not (Test-Path -LiteralPath $archive)) {
    Write-Output 'Downloading the official template archive into the ignored project cache.'
    $archiveSize = 1281349702
    $chunkBytes = 16MB
    $partial = "$archive.partial"
    $offset = if (Test-Path -LiteralPath $partial) { (Get-Item -LiteralPath $partial).Length } else { 0 }
    if ($offset -gt $archiveSize) { throw 'Partial download is larger than the official archive.' }
    while ($offset -lt $archiveSize) {
        $end = [Math]::Min($offset + $chunkBytes - 1, $archiveSize - 1)
        $chunk = "$archive.chunk"
        & curl.exe --silent --show-error --fail --location --retry 2 --retry-all-errors --retry-delay 1 --connect-timeout 30 --max-time 180 --range "$offset-$end" "$baseUrl/$archiveName" --output $chunk
        if ($LASTEXITCODE -ne 0) { throw 'Template chunk download failed; completed preceding chunks are retained for resuming. Final checksum validation remains pending.' }
        if ((Get-Item -LiteralPath $chunk).Length -ne ($end - $offset + 1)) { throw 'Server returned an unexpected range length.' }
        $output = [System.IO.File]::Open($partial, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
        $inputChunk = [System.IO.File]::OpenRead($chunk)
        try { $inputChunk.CopyTo($output) } finally { $inputChunk.Dispose(); $output.Dispose() }
        $offset = $end + 1
        Write-Output ("Template download: {0:N0}/{1:N0} bytes" -f $offset, $archiveSize)
    }
    $actual = (Get-FileHash -LiteralPath "$archive.partial" -Algorithm SHA512).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw 'Official template archive checksum mismatch.' }
    Move-Item -LiteralPath "$archive.partial" -Destination $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash.ToLowerInvariant() -ne $expected) { throw 'Cached archive checksum mismatch.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
$destination = [System.IO.Path]::GetFullPath((Join-Path $cache '4.7.2.stable'))
$null = New-Item -ItemType Directory -Force -Path $destination
$names = @('version.txt','icudt_godot.dat','windows_debug_x86_64.exe','windows_debug_x86_64_console.exe','windows_release_x86_64.exe','windows_release_x86_64_console.exe')
$files = @()
try {
    foreach ($name in $names) {
        $entry = $zip.GetEntry("templates/$name")
        if ($null -eq $entry) { throw "Missing official template dependency: $name" }
        $target = [System.IO.Path]::GetFullPath((Join-Path $destination $name))
        if (-not $target.StartsWith($destination + [System.IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Extraction path escaped the template cache.' }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
        if ((Get-Item -LiteralPath $target).Length -ne $entry.Length) { throw "Incomplete template extraction: $name" }
        $files += @{file=$name; sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
} finally { $zip.Dispose() }
if ((Get-Content -LiteralPath (Join-Path $destination 'version.txt') -Raw).Trim() -ne '4.7.2.stable') { throw 'Extracted template version mismatch.' }
$manifest = @{version='4.7.2.stable'; archive_sha512=$expected; files=$files}
[System.IO.File]::WriteAllText((Join-Path $destination 'manifest.json'),($manifest | ConvertTo-Json -Depth 4) + [Environment]::NewLine)
Write-Output "Verified official archive: $archive"
Write-Output "WINDOWS TEMPLATES PREPARED: $($files.Count) matching dependencies in $destination"
