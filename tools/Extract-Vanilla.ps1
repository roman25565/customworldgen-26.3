# Extracts the vanilla worldgen data (data\minecraft\worldgen and data\minecraft\dimension_type) from a
# Minecraft server.jar (or client jar) into ..\_vanilla-<version>, which build-pack.ps1 builds the pack from.
# The 26.x server.jar is a bundler: the game jar is inside it (META-INF\versions\<v>\server-<v>.jar).
# Usage: .\tools\Extract-Vanilla.ps1 -ServerJar C:\Users\me\Downloads\server.jar
param(
    [Parameter(Mandatory)] [string]$ServerJar,
    [string]$Version = '26.3'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$out = Join-Path (Split-Path $PSScriptRoot) "_vanilla-$Version"
$prefixes = 'data/minecraft/worldgen/', 'data/minecraft/dimension_type/'

function Open-GameJar([IO.Compression.ZipArchive]$zip) {
    if ($zip.Entries | Where-Object { $_.FullName -like 'data/minecraft/worldgen/*' } | Select-Object -First 1) { return $zip }
    $inner = $zip.Entries | Where-Object { $_.FullName -like "META-INF/versions/*/*.jar" } | Select-Object -First 1
    if (-not $inner) { throw "$ServerJar holds neither data/minecraft/worldgen nor a bundled game jar" }
    if ($inner.FullName -notlike "*/$Version/*") { Write-Warning "bundled jar is $($inner.FullName), not version $Version" }
    $ms = New-Object IO.MemoryStream
    $s = $inner.Open(); $s.CopyTo($ms); $s.Close(); $ms.Position = 0
    New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
}

$outer = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $ServerJar))
try {
    $game = Open-GameJar $outer
    Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
    $n = 0
    foreach ($e in $game.Entries) {
        $name = $e.FullName
        if (-not ($prefixes | Where-Object { $name.StartsWith($_) }) -or $name.EndsWith('/')) { continue }
        $target = Join-Path $out ($name.Replace('/', [IO.Path]::DirectorySeparatorChar))
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
        $n++
    }
    $versionJson = $game.Entries | Where-Object { $_.FullName -eq 'version.json' } | Select-Object -First 1
    if ($versionJson) { [IO.Compression.ZipFileExtensions]::ExtractToFile($versionJson, (Join-Path $out 'version.json'), $true) }
} finally { $outer.Dispose() }
if ($n -eq 0) { throw 'no worldgen files found' }
"$n files extracted to $out"
if (Test-Path (Join-Path $out 'version.json')) {
    $v = Get-Content (Join-Path $out 'version.json') -Raw | ConvertFrom-Json
    "game version $($v.id), data pack format $($v.data_pack_version)"
}
