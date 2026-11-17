# The test server is Fabric 1.21.1 (DatapackBiomesToPng), so this measures the 1.21.1 builder, build-pack-1.21.1.ps1.
# Benchmarks build-pack-1.21.1.ps1 settings: builds the pack into a fresh test world, measures the 3 nearest
# frozen-peaks and mountain areas around spawn (fixed seed), optionally searches seeds 1..N for a big
# mountain area, and adds one row to ..\benchmarks.csv with the key pack parameters.
# -ContinentsShift / -ErosionShift / -ClimateOctaveShift override build-pack.ps1 for this run only.
param(
    [string]$Note = '',
    [string]$Target = 'frozen_peaks',
    [string]$Quality = 'long',
    [int]$Radius = 30000,
    [Nullable[double]]$ContinentsShift = $null,
    [Nullable[double]]$ErosionShift = $null,
    [Nullable[int]]$ClimateOctaveShift = $null,
    [Nullable[double]]$MassifStrength = $null,
    [Nullable[double]]$MountainAmplify = $null,
    [Nullable[int]]$TerrainCeiling = $null,
    [int]$Seeds = 0,                 # also search seeds 1..N (quick preset)
    [int]$WantLong = 7000,
    [int]$WantShort = 3000
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$server = 'F:\MinecraftServers\TestServers\natural'
$world = 'world_bench'
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

# Key parameters straight from build-pack.ps1 (top-level "$Name = value" lines), then this run's overrides.
$params = [ordered]@{}
foreach ($m in Select-String -Path "$root\build-pack-1.21.1.ps1" -Pattern '^\$(ContinentsShift|ErosionShift|ClimateOctaveShift|MassifStrength|MountainAmplify|TerrainCeiling|RiverSpacing|FlattenStrength|FlatFactorBoost|MountainErosion|FlatErosion|LakeFill|CaveKeepThreshold) = (\S+)') {
    $params[$m.Matches[0].Groups[1].Value] = $m.Matches[0].Groups[2].Value
}
$build = @{ OutDir = "$server\$world\datapacks\CustomWorldgen" }
if ($null -ne $ContinentsShift) { $build.ContinentsShiftOverride = $ContinentsShift; $params.ContinentsShift = $ContinentsShift }
if ($null -ne $ErosionShift) { $build.ErosionShiftOverride = $ErosionShift; $params.ErosionShift = $ErosionShift }
if ($null -ne $ClimateOctaveShift) { $build.ClimateOctaveShiftOverride = $ClimateOctaveShift; $params.ClimateOctaveShift = $ClimateOctaveShift }
if ($null -ne $MassifStrength) { $build.MassifStrengthOverride = $MassifStrength; $params.MassifStrength = $MassifStrength }
if ($null -ne $MountainAmplify) { $build.MountainAmplifyOverride = $MountainAmplify; $params.MountainAmplify = $MountainAmplify }
if ($null -ne $TerrainCeiling) { $build.TerrainCeilingOverride = $TerrainCeiling; $params.TerrainCeiling = $TerrainCeiling }

# Fresh world with these pack settings and the latest mod build.
Remove-Item "$server\$world" -Recurse -Force -ErrorAction SilentlyContinue
& "$root\build-pack-1.21.1.ps1" @build | Select-Object -First 1 | Out-Null
Copy-Item "$root\DatapackBiomesToPng\build\libs\DatapackBiomesToPng-1.0-SNAPSHOT.jar" "$server\mods\" -Force
(Get-Content "$server\server.properties") -replace '^level-name=.*', "level-name=$world" -replace '^initial-enabled-packs=.*', 'initial-enabled-packs=vanilla,file/CustomWorldgen' |
    Set-Content "$server\server.properties" -Encoding ASCII
$seed = (@(Get-Content "$server\server.properties") -match '^level-seed=' | Select-Object -First 1) -replace '^level-seed=', ''

$commands = @(
    "biomefind $Quality $Radius $Target",
    "biomefind $Quality $Radius mountain",
    "biomemap quick -$Radius -$Radius $Radius $Radius bench"
)
if ($Seeds -gt 0) { $commands += "biomefind quick $Radius $Target $WantLong $WantShort seeds 1 $Seeds" }
$output = & "$PSScriptRoot\Invoke-TestServer.ps1" -ServerDir $server -RconPort 25598 -Commands $commands
$output | Where-Object { $_ -notmatch '^\s+minecraft:' }

function Parse-Metric([string]$line) {
    $kv = @{}
    foreach ($m in [regex]::Matches($line, '(\w+)=(\S+)')) { $kv[$m.Groups[1].Value] = $m.Groups[2].Value }
    $kv
}
$metrics = @{}
foreach ($line in $output -match '^METRIC ') { $kv = Parse-Metric $line; $metrics[$kv.target] = $kv }
if (-not $metrics[$Target] -or -not $metrics['mountain']) { throw 'METRIC lines missing from the report' }
$seedMetric = $output -match '^METRIC_SEEDS ' | Select-Object -First 1

$row = [ordered]@{ time = $stamp; note = $Note; seed = $seed }
foreach ($k in $params.Keys) { $row[$k] = $params[$k] }
foreach ($t in @($Target, 'mountain')) {
    $p = if ($t -eq 'mountain') { 'mtn' } else { 'target' }
    $row["${p}_mean_area_km2"] = $metrics[$t].mean_area_km2
    $row["${p}_mean_rect_km2"] = $metrics[$t].mean_rect_km2
    $row["${p}_mean_distance"] = $metrics[$t].mean_distance
    $row["${p}_max_height"] = $metrics[$t].mean_max_height
    $row["${p}_median_height"] = $metrics[$t].mean_median_height
    $row["${p}_share_pct"] = $metrics[$t].share_pct
}
if ($seedMetric) {
    $kv = Parse-Metric $seedMetric
    $row.seeds_checked = $kv.seeds
    $row.seeds_fit = $kv.fits
    $row.nearest_fit_seed = $kv.nearest_fit_seed
    $row.nearest_fit_distance = $kv.nearest_fit_distance
    $row.biggest_rect = $kv.biggest_rect
    $row.biggest_rect_seed = $kv.biggest_rect_seed
}

# Rewrite the whole table so rows with new columns keep every column.
$csv = "$root\benchmarks.csv"
$rows = @(if (Test-Path $csv) { Import-Csv $csv }) + [pscustomobject]$row
$columns = [System.Collections.Generic.List[string]]::new()
foreach ($r in $rows) { foreach ($p in $r.PSObject.Properties.Name) { if (-not $columns.Contains($p)) { $columns.Add($p) } } }
$rows | Select-Object -Property $columns | Export-Csv $csv -NoTypeInformation -Encoding UTF8

New-Item -ItemType Directory -Force "$root\benchmarks" | Out-Null
Copy-Item "$server\$world\biomemaps\bench_biomes.png" "$root\benchmarks\${stamp}_biomes.png"
''
"Row added to $csv"
[pscustomobject]$row | Format-List | Out-String
