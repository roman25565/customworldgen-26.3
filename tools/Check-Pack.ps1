# Static checks of the built 26.3 pack, without starting the game:
#  1. pack.mcmeta has the 26.3 data pack format;
#  2. no 1.21 / 26.2 worldgen syntax is left (old keys and function types that 26.3 refuses);
#  3. every density function, noise and feature the pack refers to exists in the pack or in vanilla 26.3;
#  4. what the pack changes: world height, terrain ceiling, structure spacing, carvers, ore veins per chunk.
# Usage: .\tools\Check-Pack.ps1 [-Pack ..\CustomWorldgen-26.3]
param(
    [string]$Pack = (Join-Path (Split-Path $PSScriptRoot) 'CustomWorldgen-26.3'),
    [string]$Vanilla = (Join-Path (Split-Path $PSScriptRoot) '_vanilla-26.3'),
    [int]$PackFormat = 121
)
$ErrorActionPreference = 'Stop'
$errors = New-Object Collections.Generic.List[string]
$warnings = New-Object Collections.Generic.List[string]
# The pack ships only the vanilla files build-pack.ps1 reads; tools\Extract-Vanilla.ps1 extracts all of them.
$vanillaComplete = Test-Path (Join-Path $Vanilla 'data\minecraft\worldgen\density_function\overworld\caves\entrances.json')
function Read-Json([string]$path) { Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json }

# 1. Format
$meta = Read-Json (Join-Path $Pack 'pack.mcmeta')
if ($meta.pack.pack_format -ne $PackFormat) { $errors.Add("pack.mcmeta: pack_format $($meta.pack.pack_format), expected $PackFormat") }
if ($meta.pack.min_format[0] -gt $PackFormat -or $meta.pack.max_format[0] -lt $PackFormat) { $errors.Add('pack.mcmeta: min_format..max_format does not include 26.3') }

# 2 + 3. Walk every worldgen file
$oldKeys = 'argument', 'argument1', 'argument2', 'firstOctave', 'amplitudes', 'config', 'Name', 'Properties', 'from_y', 'to_y', 'tries', 'xz_spread', 'y_spread'
$oldTypes = 'minecraft:flat_cache', 'minecraft:cache_2d', 'minecraft:cache_once', 'minecraft:cache_all_in_cell', 'minecraft:y_clamped_gradient', 'minecraft:shifted_noise', 'minecraft:random_patch', 'minecraft:invert', 'minecraft:end_islands'
function Test-Id([string]$registry, [string]$id) {
    $ns, $path = $id -split ':', 2
    foreach ($root in $Pack, $Vanilla) {
        if (Test-Path (Join-Path $root "data\$ns\worldgen\$registry\$path.json")) { return $true }
    }
    $false
}
function Walk($node, [string]$rel, [string]$registry, [string]$key) {
    if ($null -eq $node -or $node -is [ValueType]) { return }
    if ($node -is [string]) {
        # A bare id in a density function tree is a reference to another density function (or a noise).
        if ($registry -eq 'density_function' -and $key -ne 'type' -and $node -match '^(minecraft|custom):[a-z0-9_/]+$') {
            $reg = if ($key -eq 'noise') { 'noise' } else { 'density_function' }
            if (-not (Test-Id $reg $node)) {
                if (-not $vanillaComplete -and $node.StartsWith('minecraft:')) { $warnings.Add("${rel}: $reg $node not checked") }
                else { $errors.Add("${rel}: $reg $node not found") }
            }
        }
        return
    }
    if ($node -is [Array]) { foreach ($item in $node) { Walk $item $rel $registry $key }; return }
    foreach ($p in $node.PSObject.Properties) {
        if ($oldKeys -contains $p.Name) { $errors.Add("${rel}: old key '$($p.Name)'") }
        if ($p.Name -eq 'type' -and $oldTypes -contains $p.Value) { $errors.Add("${rel}: old type $($p.Value)") }
        Walk $p.Value $rel $registry $p.Name
    }
}
$files = Get-ChildItem (Join-Path $Pack 'data') -Recurse -File -Filter *.json
foreach ($f in $files) {
    $rel = $f.FullName.Substring($Pack.Length + 1)
    $json = Read-Json $f.FullName
    $registry = if ($rel -match 'worldgen[\\/]([a-z_]+)[\\/]') { $Matches[1] } else { '' }
    Walk $json $rel $registry ''
    if ($registry -eq 'placed_feature' -and -not (Test-Id 'feature' $json.feature)) { $errors.Add("${rel}: feature $($json.feature) not found") }
}
# A pack that does not replace noise_settings / dimension_type (the simple pack) uses the vanilla ones.
function Pack-Or-Vanilla([string]$rel) { $p = Join-Path $Pack $rel; if (Test-Path $p) { $p } else { Join-Path $Vanilla $rel } }
$noiseRouter = (Read-Json (Pack-Or-Vanilla 'data\minecraft\worldgen\noise_settings\overworld.json')).noise_router
foreach ($p in $noiseRouter.PSObject.Properties) {
    if ($p.Value -is [string] -and -not (Test-Id 'density_function' $p.Value)) {
        if (-not $vanillaComplete -and $p.Value.StartsWith('minecraft:')) { $warnings.Add("noise_router.$($p.Name) not checked") }
        else { $errors.Add("noise_router.$($p.Name): $($p.Value) not found") }
    }
}

# 4. Summary of what the pack sets
$dim = Read-Json (Pack-Or-Vanilla 'data\minecraft\dimension_type\overworld.json')
$ns = Read-Json (Pack-Or-Vanilla 'data\minecraft\worldgen\noise_settings\overworld.json')
"Files: $($files.Count)   pack format: $($meta.pack.pack_format)"
"World: Y $($dim.min_y)..$($dim.min_y + $dim.height - 1)   terrain generated up to Y $($ns.noise.min_y + $ns.noise.height)"
foreach ($s in Get-ChildItem (Join-Path $Pack 'data\minecraft\worldgen\structure_set') -Filter *.json) {
    $set = Read-Json $s.FullName
    $v = Read-Json (Join-Path $Vanilla "data\minecraft\worldgen\structure_set\$($s.Name)")
    $ratio = [math]::Pow($v.placement.spacing / $set.placement.spacing, 2)
    "Structures $($s.BaseName): spacing $($set.placement.spacing)/$($set.placement.separation) (vanilla $($v.placement.spacing)/$($v.placement.separation)) = about {0:F1}x as many" -f $ratio
}
foreach ($c in Get-ChildItem (Join-Path $Pack 'data\minecraft\worldgen\carver') -Filter *.json) {
    $p = (Read-Json $c.FullName).probability
    $v = (Read-Json (Join-Path $Vanilla "data\minecraft\worldgen\carver\$($c.Name)")).probability
    "Carver $($c.BaseName): probability $p (vanilla $v)"
}
$veins = 0.0
foreach ($pf in Get-ChildItem (Join-Path $Pack 'data\minecraft\worldgen\placed_feature') -Filter 'ore_*.json') {
    $count = (Read-Json $pf.FullName).placement[0].count
    $w = 0; $sum = 0.0
    foreach ($d in $count.distribution) { $w += $d.weight; $sum += $d.data * $d.weight }
    $veins += $sum / $w
}
"Ore: {0} placed ore features, {1:F3} giant veins per chunk in total (1 per {2:F1} chunks)" -f @(Get-ChildItem (Join-Path $Pack 'data\minecraft\worldgen\placed_feature') -Filter 'ore_*.json').Count, $veins, (1 / $veins)

''
if ($warnings.Count) { "$($warnings.Count) vanilla references not checked: _vanilla-26.3 is the short copy. Run tools\Extract-Vanilla.ps1 -ServerJar <server.jar> for the full check." }
if ($errors.Count) { "FAILED: $($errors.Count) problems"; $errors | Select-Object -First 50; exit 1 }
if ($warnings.Count) { 'OK: no old syntax, every reference checked resolves' } else { 'OK: no old syntax, every reference resolves' }
