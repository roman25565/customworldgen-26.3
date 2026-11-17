# Generates the CustomWorldgen datapack for Minecraft 26.3 (and Horizon, which reads 26.3 datapacks)
# from the vanilla 26.3 worldgen files in _vanilla-26.3 (tools\Extract-Vanilla.ps1 refreshes them from server.jar).
# Re-run after changing any parameter below; the whole pack is rebuilt.
# -OutDir builds a separate copy of the pack (for tests); the *Override switches override the parameters below.
param(
    [string]$OutDir = '',
    [Nullable[double]]$ContinentsShiftOverride = $null,
    [Nullable[double]]$ErosionShiftOverride = $null,
    [Nullable[int]]$ClimateOctaveShiftOverride = $null,
    [Nullable[double]]$MassifStrengthOverride = $null,
    [Nullable[double]]$MountainAmplifyOverride = $null,
    [Nullable[int]]$TerrainCeilingOverride = $null,
    # Lighter pack for LOD (distant terrain), built into CustomWorldgen-26.3-lite: vanilla world height (Y -64..319,
    # terrain ceiling 320) and no tunnel caves in the density function (spaghetti, noodle, entrances), which far
    # terrain would otherwise evaluate at every sample point. Everything else is the same as the full pack.
    [switch]$Lite
)

# --- Pack --------------------------------------------------------------------
$PackFormat = 121                      # Minecraft 26.3 data pack format
$PackDescription = 'CustomWorldgen for 26.3 / Horizon: fewer caves, big smooth biomes, big ore veins'

# --- World height --------------------------------------------------------------
# Build limit of the overworld (dimension type). -64 + 720 = Y 656, room to build above the 512 terrain ceiling.
$WorldMinY = -64
$WorldHeight = 720

# --- Structures --------------------------------------------------------------
# random_spread grid: one attempt per Spacing x Spacing chunks, at least Separation chunks apart.
# Vanilla is 32/8 for both; 14/4 = about 5x as many witch huts and desert pyramids.
$StructureSpacing = @{
    swamp_huts      = @{ Spacing = 14; Separation = 4 }
    desert_pyramids = @{ Spacing = 14; Separation = 4 }
}

# --- Caves -------------------------------------------------------------------
# Noise caves survive only in regions where a 2D region noise is below a threshold. Lower = fewer regions.
# Big caves (cheese caverns and their pillars) and tunnels (spaghetti, noodle caves and cave entrances)
# have their own region noise, so their amounts are set separately.
# Share of the map the noise is below a threshold (measured on 4 million samples of this noise):
#   -0.19 = 28.1%   -0.35 = 14.1%   -0.54 = 4.7%   -0.63 = 2.3%
# Big caves 14.1% and tunnels 2.3% (half of 28.1% and 4.7%: the user asked for half as many caves).
$BigCaveKeepThreshold = -0.35
$TunnelKeepThreshold = -0.63
# How sharply caves fade out at a region edge (higher = steeper walls).
$CaveEdgeSharpness = 6.0
# Feature size of cave regions: base octave -8 = roughly 256-block patches.
$CaveRegionOctave = -8
# Multiplier for the classic carvers' probability: tunnel carvers (cave, cave_extra_underground) 1/30 of vanilla,
# canyons 1/10 (halved from 1/15 and 1/5).
$CarverScale = @{ cave = 0.2 / 6; cave_extra_underground = 0.2 / 6; canyon = 0.1 }

# --- Flat terrain ------------------------------------------------------------
# Share of hill height removed outside mountains (0.985 = hills keep 1.5% height).
$FlattenStrength = 0.985
# Offset above which terrain gets compressed (-0.47 = about Y 68).
$FlatBaseOffset = -0.47
# Extra factor outside mountains; factor x(1 + boost) shrinks 3D-noise bumps that many times (10 = 11x; was 5 = 6x).
$FlatFactorBoost = 10.0
# Erosion at or below this keeps full vanilla terrain. Vanilla erosion bands: < -0.78 and -0.78..-0.375 hold
# the peaks and most slopes; -0.375..-0.2225 mixes plains, forests and meadows with hilly vanilla terrain, so it
# is flattened too (with -0.2225 / -0.15 the plains there kept 20+ block hills)...
$MountainErosion = -0.45
# ...and at or above this is fully flattened (linear blend in between).
$FlatErosion = -0.375

# --- Rivers and lakes --------------------------------------------------------
# Rivers follow the zero line of the ridges (weirdness) noise. Stretching that noise by this factor puts
# rivers this many times farther apart; the value is then remapped so a river stays as wide as vanilla.
$RiverSpacing = 3.0
# Vanilla river band: |weirdness| < 0.05.
$RiverBand = 0.05
# Inland, away from rivers, terrain dips below this offset (-0.49 = about Y 65) are lifted...
$LakeFloorOffset = -0.49
# ...by this share of the dip (1 = fully filled). Fewer dips below sea level = fewer small lakes.
$LakeFill = 0.8

# --- Land and mountains ----------------------------------------------------------
# Added to continentalness everywhere. Positive = less ocean. 0 = vanilla land/ocean split.
$ContinentsShift = 0.0
# Added to erosion everywhere. Negative = more mountains and slopes, fewer flat lowlands.
# -0.1 with ClimateOctaveShift 3: 14 of seeds 1..100 hold a frozen-peaks area of 7000 x 3000 (seed 94 at spawn),
# 0 with shift 2 had none (benchmarks.csv, 2026-11-02, measured on 1.21.1; terrain functions are the same in 26.3).
$ErosionShift = -0.1
# Peak biomes only form on ridge lines of the "peaks and valleys" noise, so vanilla peaks are thin.
# In low-erosion (mountain) zones this pulls that noise onto the ridge, making whole massifs peaks.
# 0 = vanilla, 1 = full massifs. Full effect at erosion <= $MassifErosionFull, none above $MassifErosionStart.
$MassifStrength = 1.0
$MassifErosionFull = -0.55
$MassifErosionStart = -0.375
# Extra mountain height: offset above $MountainAmplifyBase (-0.2 = about Y 102) is multiplied by
# 1 + this, only where erosion is mountainous (full at <= $MountainErosion, none at >= $FlatErosion). 0 = vanilla.
$MountainAmplify = 0.7
$MountainAmplifyBase = -0.2
# Top of terrain generation (vanilla 256). Mountains fade out over the 16 blocks below it.
$TerrainCeiling = 512

# --- Climate scale -----------------------------------------------------------
# Octave shift for temperature, vegetation, continentalness and erosion.
# 2 = biomes and landforms 4x larger (same as vanilla Large Biomes), 3 = 8x larger.
$ClimateOctaveShift = 1

# --- Ores --------------------------------------------------------------------
# Every ore becomes rare giant veins while keeping the vanilla average ore per chunk.
# One ore blob is capped at size 64 (~680 blocks), so a giant vein is a cluster of blobs:
# $VeinBlobs blobs of size $VeinSize scattered up to +-$VeinSpread blocks around the vein centre
# (triangular spread, as the old random_patch feature did it).
# Measured in solid stone: size 37 single blob = ~150 blocks; 10 blobs of 64, spread 5 = ~3070 blocks.
$VeinSize = 64
$VeinBlobs = 10
$VeinSpread = 5
$VeinBlocks = 3074.0
# Ores that use a different vein size. Blobs = 1 means a single ore blob (Spread unused).
# Ancient debris: giant veins were ~1 per 2000 nether chunks, so it uses ~150-block veins instead.
$VeinOverride = @{
    ancient_debris = @{ Size = 37; Blobs = 1; Spread = 0; Blocks = 150.0 }
}
# Measured average blocks per placement of each vanilla ore feature (solid rock, 40 trials).
# Ore features (size, targets, placements) are the same in 26.3 as in 1.21.1, which these were measured on.
$VanillaVeinBlocks = @{
    ore_coal = 21.5; ore_coal_buried = 21.9; ore_iron = 6.9; ore_iron_small = 2.1
    ore_gold = 6.3; ore_gold_buried = 6.4; ore_redstone = 5.6; ore_lapis = 5.1; ore_lapis_buried = 5.4
    ore_diamond_small = 2.4; ore_diamond_medium = 6.0; ore_diamond_large = 12.0; ore_diamond_buried = 5.6
    ore_copper_small = 8.2; ore_copper_large = 34.6; ore_emerald = 0.5
    ore_quartz = 15.0; ore_nether_gold = 8.5; ore_ancient_debris_large = 1.4; ore_ancient_debris_small = 1.1
}
$OrePlacedFeatures = @(
    'ore_coal_upper', 'ore_coal_lower', 'ore_iron_upper', 'ore_iron_middle', 'ore_iron_small',
    'ore_gold', 'ore_gold_lower', 'ore_gold_extra', 'ore_redstone', 'ore_redstone_lower',
    'ore_lapis', 'ore_lapis_buried', 'ore_diamond', 'ore_diamond_buried', 'ore_diamond_large', 'ore_diamond_medium',
    'ore_copper', 'ore_copper_large', 'ore_emerald',
    'ore_quartz_nether', 'ore_quartz_deltas', 'ore_gold_nether', 'ore_gold_deltas', 'ore_ancient_debris_large', 'ore_debris_small'
)
# Vanilla overworld top; heights given as "below_top" are pinned to it so the taller world does not thin out ores.
$VanillaOverworldTop = 319
# Vanilla noise "ore veins" (iron+tuff, copper+granite) scatter single ore blocks; $false turns them off.
# In 26.3 they are two entries of the overworld material rule.
$NoiseOreVeins = $false
# Per-ore multiplier on giant-vein frequency, measured against vanilla ore per chunk
# (makes up for veins clipped by bedrock/surface and for the removed noise ore veins).
# Measured on 4096 overworld + 1024 nether chunks (1.21.1, same ore features), vanilla / giant-vein ore per chunk.
$OreCorrection = @{
    coal = 0.931; iron = 1.253; copper = 1.301; gold = 0.998; redstone = 1.077; lapis = 1.092
    diamond = 0.918; emerald = 1.0; quartz = 0.972; nether_gold = 1.243; ancient_debris = 1.0
}

# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$vanillaRoot = Join-Path $PSScriptRoot '_vanilla-26.3\data\minecraft'
$vanilla = Join-Path $vanillaRoot 'worldgen'
if (-not (Test-Path (Join-Path $vanilla 'noise_settings\overworld.json'))) {
    throw "Vanilla 26.3 worldgen not found in $vanilla. Run tools\Extract-Vanilla.ps1 -ServerJar <26.3 server.jar> first."
}
if ($null -ne $ContinentsShiftOverride) { $ContinentsShift = $ContinentsShiftOverride }
if ($null -ne $ErosionShiftOverride) { $ErosionShift = $ErosionShiftOverride }
if ($null -ne $ClimateOctaveShiftOverride) { $ClimateOctaveShift = $ClimateOctaveShiftOverride }
if ($null -ne $MassifStrengthOverride) { $MassifStrength = $MassifStrengthOverride }
if ($null -ne $MountainAmplifyOverride) { $MountainAmplify = $MountainAmplifyOverride }
if ($null -ne $TerrainCeilingOverride) { $TerrainCeiling = $TerrainCeilingOverride }
$NoTunnelNoise = $false
if ($Lite) { $WorldHeight = 384; $TerrainCeiling = 320; $NoTunnelNoise = $true }
# A new folder: the 1.21.1 pack in CustomWorldgen has files 26.3 cannot read.
$packRoot = if ($OutDir) { $OutDir } else { Join-Path $PSScriptRoot $(if ($Lite) { 'CustomWorldgen-26.3-lite' } else { 'CustomWorldgen-26.3' }) }
# The whole pack is generated: start from an empty folder so no file of an older format stays behind.
Remove-Item $packRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $packRoot | Out-Null
$pack = Join-Path $packRoot 'data'
$utf8 = New-Object Text.UTF8Encoding $false
$inv = [Globalization.CultureInfo]::InvariantCulture

function Save-Json([string]$relPath, $obj, [string]$root = $pack) {
    $path = Join-Path $root $relPath
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    $json = if ($obj -is [string]) { $obj } else { $obj | ConvertTo-Json -Depth 100 }
    [IO.File]::WriteAllText($path, $json, $utf8)
}

function Read-Vanilla([string]$relPath) {
    Get-Content (Join-Path $vanilla $relPath) -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Find-AllNodes($node, [scriptblock]$match) {
    if ($null -eq $node -or $node -is [string] -or $node -is [ValueType]) { return }
    if ($node -is [Array]) { foreach ($item in $node) { Find-AllNodes $item $match }; return }
    if (& $match $node) { $node }
    # Nodes this script built are ordered dictionaries: walk their values, not their .NET properties.
    if ($node -is [Collections.IDictionary]) { foreach ($v in @($node.Values)) { Find-AllNodes $v $match }; return }
    foreach ($p in $node.PSObject.Properties) { Find-AllNodes $p.Value $match }
}

# 26.3 density functions: two-argument functions take left/right, one-argument ones take input.
# "cache" replaced flat_cache/cache_2d; all inputs cached here depend on x and z only.
function Df2([string]$type, $left, $right) { [ordered]@{ type = "minecraft:$type"; left = $left; right = $right } }
function Add-Df($a, $b) { Df2 'add' $a $b }
function Mul-Df($a, $b) { Df2 'mul' $a $b }
function Max-Df($a, $b) { Df2 'max' $a $b }
function Cache-Df($a) { [ordered]@{ type = 'minecraft:cache'; input = $a } }

function Linear-Spline([string]$coordinate, [double[][]]$points) {
    [ordered]@{
        type = 'minecraft:spline'
        spline = [ordered]@{
            coordinate = $coordinate
            points = @($points | ForEach-Object { [ordered]@{ location = $_[0]; value = $_[1]; derivative = $_[2] } })
        }
    }
}

# 26.3 noise parameters. base_amplitude is vanilla's NormalNoise.computeParityBaseAmplitude, which keeps
# the 1.21/26.2 normalisation of {firstOctave, amplitudes}; it does not depend on the base octave.
function New-Noise([int]$baseOctave, [double[]]$amps) {
    $n = $amps.Count
    $a = [math]::Pow(0.5, -($n - 1)) / ([math]::Pow(0.5, -$n) - 1.0)
    $octaves = @(); foreach ($m in $amps) { if ($m -ne 0) { $octaves += $a * $m }; $a *= 0.5 }
    $target = 0.0; $c = 0.0
    foreach ($o in $octaves) { $t = [math]::Abs($o) - $c; $v = $target + $t; $c = ($v - $target) - $t; $target = $v }
    $target -= $c
    $variance = 0.0; foreach ($o in $octaves) { $l = 0.2702247831245211 * [math]::Abs($o); $variance += $l * $l }
    $new = $target * 0.3333333333333333 / ([math]::Sqrt($variance) * [math]::Sqrt(2.0))
    $idx = @(for ($i = 0; $i -lt $n; $i++) { if ($amps[$i] -ne 0) { $i } })
    $span = $idx[-1] - $idx[0]
    $parity = 0.5 * 0.3333333333333333 / (0.1 * (1.0 + 1.0 / ($span + 1)))
    $noise = [ordered]@{ base_amplitude = $parity / $new; base_octave = $baseOctave; octave_count = $n }
    if (@($amps | Where-Object { $_ -ne 1.0 }).Count -gt 0) { $noise.amplitude_modifiers = $amps }
    $noise
}

# --- pack.mcmeta, dimension type, structures -----------------------------------
Save-Json 'pack.mcmeta' ([ordered]@{ pack = [ordered]@{
    description = $PackDescription; pack_format = $PackFormat; min_format = @($PackFormat, 0); max_format = @($PackFormat, 0) } }) $packRoot

$dim = Get-Content (Join-Path $vanillaRoot 'dimension_type\overworld.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($WorldHeight % 16 -ne 0 -or $WorldMinY % 16 -ne 0 -or $WorldMinY + $WorldHeight -gt 2032) { throw 'world height must be multiples of 16 with top <= 2032' }
if ($WorldMinY + $WorldHeight -lt $TerrainCeiling) { throw 'world top is below the terrain ceiling' }
$dim.min_y = $WorldMinY; $dim.height = $WorldHeight; $dim.logical_height = $WorldHeight
Save-Json 'minecraft\dimension_type\overworld.json' $dim

foreach ($name in $StructureSpacing.Keys) {
    $set = Read-Vanilla "structure_set\$name.json"
    $set.placement.spacing = $StructureSpacing[$name].Spacing
    $set.placement.separation = $StructureSpacing[$name].Separation
    if ($set.placement.separation -ge $set.placement.spacing) { throw "$name separation must be below spacing" }
    Save-Json "minecraft\worldgen\structure_set\$name.json" $set
}

# --- Caves -------------------------------------------------------------------
# (kept 6 folders deep: the device file tools refuse deeper paths)
$bigSuppressor = 'custom:overworld/cave_suppressor'
$tunnelSuppressor = 'custom:overworld/tunnel_suppressor'
# Each noise id gets its own seed, so big-cave and tunnel regions are independent of each other.
foreach ($s in @(@('cave_regions', 'cave_suppressor', $BigCaveKeepThreshold), @('tunnel_regions', 'tunnel_suppressor', $TunnelKeepThreshold))) {
    Save-Json "custom\worldgen\noise\$($s[0]).json" (New-Noise $CaveRegionOctave @(1.0, 1.0))
    # Positive (solid) where the region noise is above the threshold.
    Save-Json "custom\worldgen\density_function\overworld\$($s[1]).json" (Cache-Df (Mul-Df $CaveEdgeSharpness (
        Add-Df (-$s[2]) ([ordered]@{ type = 'minecraft:noise'; noise = "custom:$($s[0])"; xz_scale = 1.0; y_scale = 0.0 }))))
}

$fd = Read-Vanilla 'density_function\overworld\final_density.json'
# add(min(squeeze(...), noodle), beardifier)
if ($fd.type -ne 'minecraft:add' -or $fd.right.type -ne 'minecraft:beardifier' -or $fd.left.right -ne 'minecraft:overworld/caves/noodle') {
    throw 'unexpected final_density shape (noodle)'
}
$choice = @(Find-AllNodes $fd { param($n) $n.type -eq 'minecraft:range_choice' -and $n.input -eq 'minecraft:overworld/sloped_cheese' })
if ($choice.Count -ne 1) { throw 'sloped_cheese range_choice not found in final_density' }
$choice = $choice[0]
# Near the surface: min(sloped_cheese, 5 * entrances). Entrances are tunnels.
if ($choice.when_in_range.right.left -ne 'minecraft:overworld/caves/entrances') { throw 'unexpected near-surface cave shape' }
$choice.when_in_range.right = Max-Df $choice.when_in_range.right $tunnelSuppressor
# Deeper: max(min(min(cheese, entrances), spaghetti_2d + roughness), pillars).
$deep = $choice.when_out_of_range
if ($deep.type -ne 'minecraft:max' -or $deep.left.type -ne 'minecraft:min' -or $deep.left.left.type -ne 'minecraft:min' -or
    $deep.left.left.right -ne 'minecraft:overworld/caves/entrances' -or $deep.left.right.left -ne 'minecraft:overworld/caves/spaghetti_2d') {
    throw 'unexpected deep cave shape'
}
$deep.left.left.left = Max-Df $deep.left.left.left $bigSuppressor        # cheese caverns
$deep.left.left.right = Max-Df $deep.left.left.right $tunnelSuppressor   # entrances
$deep.left.right = Max-Df $deep.left.right $tunnelSuppressor             # spaghetti 2d
$fd.left.right = Max-Df $fd.left.right $tunnelSuppressor                 # noodle caves
if ($NoTunnelNoise) {
    # No tunnel noise at all: entrances and spaghetti become "solid" (a huge density the min() never picks) and
    # the noodle term is dropped, so none of their noises is sampled. Big caves (cheese) and pillars stay.
    $choice.when_in_range.right = 1000000.0
    $deep.left.left.right = 1000000.0
    $deep.left.right = 1000000.0
    $fd.left = $fd.left.left
    Remove-Item (Join-Path $pack 'custom\worldgen\noise\tunnel_regions.json'), (Join-Path $pack 'custom\worldgen\density_function\overworld\tunnel_suppressor.json')
}

# Terrain ceiling: move the vanilla top fade (Y 240..256) of the density and of the preliminary surface under it.
$psl = Read-Vanilla 'density_function\overworld\preliminary_surface_level.json'
$fades = @(Find-AllNodes @($fd, $psl) { param($n) $n.type -eq 'minecraft:gradient' -and $n.axis -eq 'y' -and $n.from_coordinate -eq 240 -and $n.to_coordinate -eq 256 })
if ($fades.Count -ne 2) { throw "expected 2 top-fade gradients, found $($fades.Count)" }
foreach ($f in $fades) { $f.from_coordinate = $TerrainCeiling - 16; $f.to_coordinate = $TerrainCeiling }
Save-Json 'minecraft\worldgen\density_function\overworld\final_density.json' $fd
Save-Json 'minecraft\worldgen\density_function\overworld\preliminary_surface_level.json' $psl

$ns = Read-Vanilla 'noise_settings\overworld.json'
$ns.noise.height = $TerrainCeiling - $ns.noise.min_y
if ($ns.noise.height % 16 -ne 0) { throw 'TerrainCeiling + 64 must be a multiple of 16' }
Save-Json 'minecraft\worldgen\noise_settings\overworld.json' $ns

if (-not $NoiseOreVeins) {
    $rule = Read-Vanilla 'material_rule\overworld.json'
    $veinRules = 'minecraft:overworld/copper_ore_vein', 'minecraft:overworld/iron_ore_vein'
    $kept = @($rule.sequence | Where-Object { -not ($_ -is [string] -and $veinRules -contains $_) })
    if ($kept.Count -ne $rule.sequence.Count - 2) { throw 'ore vein entries not found in the overworld material rule' }
    $rule.sequence = $kept
    Save-Json 'minecraft\worldgen\material_rule\overworld.json' $rule
}

foreach ($name in 'cave', 'cave_extra_underground', 'canyon') {
    $c = Read-Vanilla "carver\$name.json"
    $c.probability = [math]::Round($c.probability * $CarverScale[$name], 5)
    Save-Json "minecraft\worldgen\carver\$name.json" $c
}

# --- Flat terrain ------------------------------------------------------------
$customDf = Join-Path $pack 'custom\worldgen\density_function\overworld'
New-Item -ItemType Directory -Force $customDf | Out-Null
Copy-Item (Join-Path $vanilla 'density_function\overworld\offset.json') (Join-Path $customDf 'offset_vanilla.json') -Force
Copy-Item (Join-Path $vanilla 'density_function\overworld\factor.json') (Join-Path $customDf 'factor_vanilla.json') -Force

# 0 in mountains (low erosion), 1 in flat-land erosion range.
Save-Json 'custom\worldgen\density_function\overworld\flatness.json' (Cache-Df (
    Linear-Spline 'minecraft:overworld/erosion' @(@($MountainErosion, 0.0, 0.0), @($FlatErosion, 1.0, 0.0))))

# offset - flatness * strength * max(offset - base, 0): squashes hills, keeps valleys and oceans.
Save-Json 'custom\worldgen\density_function\overworld\offset_flat.json' (Cache-Df (
    Add-Df 'custom:overworld/offset_vanilla' (Mul-Df 'custom:overworld/flatness' (Mul-Df (-$FlattenStrength) (
        Max-Df (Add-Df 'custom:overworld/offset_vanilla' (-$FlatBaseOffset)) 0.0)))))

# 1 inland and away from river corridors in flat land, 0 at coasts, rivers and mountains.
Save-Json 'custom\worldgen\density_function\overworld\lake_mask.json' (Cache-Df (
    Mul-Df 'custom:overworld/flatness' (Mul-Df (
        Linear-Spline 'minecraft:overworld/continents' @(@(-0.11, 0.0, 0.0), @(0.0, 1.0, 0.0))) (
        Linear-Spline 'minecraft:overworld/ridges' @(@(-0.2, 1.0, 0.0), @(-0.1, 0.0, 0.0), @(0.1, 0.0, 0.0), @(0.2, 1.0, 0.0))))))

# depth = vertical gradient + offset. Vanilla stops the gradient at Y 320, which would turn every column
# with a high offset into an endless pillar; extend it at the same slope up to the terrain ceiling.
$depth = Read-Vanilla 'density_function\overworld\depth.json'
$gradient = $depth.left
if ($gradient.type -ne 'minecraft:gradient' -or $gradient.axis -ne 'y') { throw 'unexpected depth shape' }
$slope = ($gradient.to_value - $gradient.from_value) / ($gradient.to_coordinate - $gradient.from_coordinate)
$top = [math]::Max($TerrainCeiling, $gradient.to_coordinate)
$gradient.to_value = $gradient.from_value + $slope * ($top - $gradient.from_coordinate)
$gradient.to_coordinate = $top
Save-Json 'minecraft\worldgen\density_function\overworld\depth.json' $depth

# offset_flat
#   + fill * lake_mask * max(floor - offset_flat, 0)              lifts inland dips that would hold small lakes
#   + amplify * mountain_weight * max(offset_flat - base, 0)       makes mountains taller
Save-Json 'custom\worldgen\density_function\overworld\mountain_weight.json' (Cache-Df (
    Linear-Spline 'minecraft:overworld/erosion' @(@($MountainErosion, 1.0, 0.0), @($FlatErosion, 0.0, 0.0))))
$lakeDip = Max-Df (Add-Df $LakeFloorOffset (Mul-Df (-1.0) 'custom:overworld/offset_flat')) 0.0
$lakeLift = Mul-Df 'custom:overworld/lake_mask' (Mul-Df $LakeFill $lakeDip)
$mountainRise = Max-Df (Add-Df 'custom:overworld/offset_flat' (-$MountainAmplifyBase)) 0.0
$mountainLift = Mul-Df 'custom:overworld/mountain_weight' (Mul-Df $MountainAmplify $mountainRise)
Save-Json 'minecraft\worldgen\density_function\overworld\offset.json' (Cache-Df (
    Add-Df (Add-Df 'custom:overworld/offset_flat' $lakeLift) $mountainLift))

# Rivers: stretch the ridges noise, then remap it so the river band keeps vanilla width.
$ridges = Read-Vanilla 'density_function\overworld\ridges.json'
if ($ridges.input.type -ne 'minecraft:noise') { throw 'unexpected ridges shape' }
$ridges.input.xz_scale = $ridges.input.xz_scale / $RiverSpacing
Save-Json 'custom\worldgen\density_function\overworld\ridges_stretched.json' $ridges
$inner = $RiverBand / $RiverSpacing                  # raw value that maps to the band edge
$outerSlope = (1.0 - $RiverBand) / (1.0 - $inner)
$knee = $inner + 0.05                                # short blend between the steep and the gentle part
$kneeValue = $RiverBand + $outerSlope * 0.05
$steep = 2.8 * $outerSlope                           # below the band slope (3x) so the spline stays monotonic
Save-Json 'custom\worldgen\density_function\overworld\ridges_rivers.json' (Cache-Df (
    Linear-Spline 'custom:overworld/ridges_stretched' @(
        @(-1.0, -1.0, $outerSlope), @(-$knee, -$kneeValue, $outerSlope), @(-$inner, -$RiverBand, $steep),
        @($inner, $RiverBand, $steep), @($knee, $kneeValue, $outerSlope), @(1.0, 1.0, $outerSlope))))
$rr = 'custom:overworld/ridges_rivers'

# Massifs: 1 in mountain-erosion zones (times $MassifStrength), 0 elsewhere.
Save-Json 'custom\worldgen\density_function\overworld\massif.json' (Cache-Df (Mul-Df $MassifStrength (
    Linear-Spline 'minecraft:overworld/erosion' @(@($MassifErosionFull, 1.0, 0.0), @($MassifErosionStart, 0.0, 0.0)))))
# Where pulled: ridges -> 0.667 + 0.15 * ridges. Positive weirdness picks frozen (not jagged) peaks in the cold,
# and |ridges| near 2/3 is the "high"/"peaks" part of the peaks-and-valleys curve.
Save-Json 'minecraft\worldgen\density_function\overworld\ridges.json' (Cache-Df (
    Add-Df $rr (Mul-Df 'custom:overworld/massif' (Add-Df 0.667 (Mul-Df (-0.85) $rr)))))

# --- Land share ----------------------------------------------------------------
foreach ($name in 'continents', 'erosion') {
    $shift = if ($name -eq 'continents') { $ContinentsShift } else { $ErosionShift }
    $df = Read-Vanilla "density_function\overworld\$name.json"
    if ($shift -ne 0) { $df.input = Add-Df $df.input $shift }
    Save-Json "minecraft\worldgen\density_function\overworld\$name.json" $df
}

# factor * (1 + boost * flatness): higher factor = smaller 3D-noise bumps.
Save-Json 'minecraft\worldgen\density_function\overworld\factor.json' (Cache-Df (
    Mul-Df 'custom:overworld/factor_vanilla' (Add-Df 1.0 (Mul-Df $FlatFactorBoost 'custom:overworld/flatness'))))

# --- Climate scale -----------------------------------------------------------
foreach ($name in 'temperature', 'vegetation', 'continentalness', 'erosion') {
    $n = Read-Vanilla "noise\$name.json"
    $n.base_octave = $n.base_octave - $ClimateOctaveShift
    Save-Json "minecraft\worldgen\noise\$name.json" $n
}

# --- Ores --------------------------------------------------------------------
$oreReport = foreach ($name in $OrePlacedFeatures) {
    $placed = Read-Vanilla "placed_feature\$name.json"
    $cfName = $placed.feature -replace '^minecraft:', ''
    $cf = Read-Vanilla "feature\$cfName.json"
    $state = [string]$cf.targets[0].state
    $family = ($state -replace '^minecraft:(deepslate_)?', '') -replace '_ore$', '' -replace '^nether_quartz$', 'quartz'
    if (-not $OreCorrection.ContainsKey($family)) { throw "no OreCorrection entry for '$family' ($name)" }
    if (-not $VanillaVeinBlocks.ContainsKey($cfName)) { throw "no VanillaVeinBlocks entry for '$cfName' ($name)" }
    $vein = if ($VeinOverride.ContainsKey($family)) { $VeinOverride[$family] } else { @{ Size = $VeinSize; Blobs = $VeinBlobs; Spread = $VeinSpread; Blocks = $VeinBlocks } }
    # Ancient debris is "scattered_ore" in vanilla (loose single blocks); veins must be solid blobs.
    $cf.type = 'minecraft:ore'
    $cf.size = $vein.Size
    $cf.discard_chance_on_air_exposure = 0.0
    Save-Json "custom\worldgen\feature\vein\$name.json" $cf

    # Vanilla veins per chunk: count (fixed or uniform) or 1-in-N rarity.
    $veins = 1.0
    $nether = $state -match 'nether|ancient_debris'
    $placement = foreach ($m in $placed.placement) {
        switch ($m.type) {
            'minecraft:count' {
                $veins = if ($m.count -is [ValueType]) { [double]$m.count } else { ($m.count.min_inclusive + $m.count.max_inclusive) / 2.0 }
                continue
            }
            'minecraft:rarity_filter' { $veins = 1.0 / $m.chance; continue }
            'minecraft:height_range' {
                if (-not $nether) {
                    foreach ($edge in 'min_inclusive', 'max_inclusive') {
                        $anchor = $m.height.$edge
                        if ($anchor -and $null -ne $anchor.below_top) {
                            $m.height.$edge = [ordered]@{ absolute = $VanillaOverworldTop - $anchor.below_top }
                        }
                    }
                }
                $m
            }
            default { $m }
        }
    }
    # A giant vein = $vein.Blobs ore blobs around the vein centre (26.3 dropped random_patch: count + offset does it).
    if ($vein.Blobs -gt 1) {
        $spread = [ordered]@{ type = 'minecraft:trapezoid'; max = $vein.Spread; min = -$vein.Spread; plateau = 0 }
        $placement = @($placement) + @(
            [ordered]@{ type = 'minecraft:count'; count = $vein.Blobs },
            [ordered]@{ type = 'minecraft:offset'; x = $spread; y = $spread; z = $spread })
    }
    # Big veins per chunk that keep the same ore blocks per chunk; a weighted list gives the exact mean.
    $bigVeins = $veins * $VanillaVeinBlocks[$cfName] / $vein.Blocks * $OreCorrection[$family]
    $low = [math]::Floor($bigVeins)
    $highWeight = [int][math]::Round(($bigVeins - $low) * 1000000)
    $distribution = @([ordered]@{ data = [int]$low; weight = 1000000 - $highWeight })
    if ($highWeight -gt 0) { $distribution += [ordered]@{ data = [int]$low + 1; weight = $highWeight } }
    $count = [ordered]@{ type = 'minecraft:count'; count = [ordered]@{ type = 'minecraft:weighted_list'; distribution = $distribution } }
    Save-Json "minecraft\worldgen\placed_feature\$name.json" ([ordered]@{ feature = "custom:vein/$name"; placement = @($count) + @($placement) })
    [string]::Format($inv, '{0,-26} vanilla {1,7:F3} veins x {2,5:F1} blocks = {3,8:F2} ore/chunk -> {4,7:F4} big veins/chunk (1 per {5:F1} chunks)',
        $name, $veins, $VanillaVeinBlocks[$cfName], $veins * $VanillaVeinBlocks[$cfName], $bigVeins, 1 / $bigVeins)
}

# --- Check every generated file parses back -----------------------------------
Get-ChildItem $packRoot -Recurse -File -Filter *.json | ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null }
Get-ChildItem $packRoot -Recurse -File -Filter *.mcmeta | ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null }
# ConvertTo-Json silently truncates deep trees: make sure the rewritten vanilla trees survived intact.
function Compact($o) { $o | ConvertTo-Json -Depth 100 -Compress }
$roundTrip = @{
    'density_function\overworld\preliminary_surface_level.json' = $psl
    'density_function\overworld\final_density.json' = $fd
}
foreach ($rel in $roundTrip.Keys) {
    $saved = Get-Content (Join-Path $pack "minecraft\worldgen\$rel") -Raw -Encoding UTF8 | ConvertFrom-Json
    if ((Compact $saved) -ne (Compact $roundTrip[$rel])) { throw "$rel changed during JSON round-trip" }
}
'Pack built: ' + (Get-ChildItem $packRoot -Recurse -File).Count + ' files in ' + $packRoot
$oreReport
