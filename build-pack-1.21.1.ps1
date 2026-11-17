# Generates the noise part of the CustomWorldgen datapack from the vanilla 1.21.1 files.
# Re-run after changing any parameter below; it rewrites only the files it owns.
# -OutDir builds a separate copy of the pack (for tests); the *Override switches and -NoIceRegion
# override the parameters below for that build.
param(
    [string]$OutDir = '',
    [Nullable[double]]$ContinentsShiftOverride = $null,
    [Nullable[double]]$ErosionShiftOverride = $null,
    [Nullable[int]]$ClimateOctaveShiftOverride = $null,
    [Nullable[double]]$MassifStrengthOverride = $null,
    [Nullable[double]]$MountainAmplifyOverride = $null,
    [Nullable[int]]$TerrainCeilingOverride = $null,
    [switch]$NoIceRegion
)

# --- Caves -------------------------------------------------------------------
# Noise caves survive only where the 2D "cave_regions" noise is below this value.
# Lower value = fewer cave regions. Tune with the cave-volume measurement.
$CaveKeepThreshold = -0.35
# How sharply caves fade out at a region edge (higher = steeper walls).
$CaveEdgeSharpness = 6.0
# Feature size of cave regions: firstOctave -8 = roughly 256-block patches.
$CaveRegionOctave = -8
# Multiplier for carver (classic cave/canyon) probability. 0.2 = 5x fewer.
$CarverScale = 0.2

# --- Flat terrain ------------------------------------------------------------
# Share of hill height removed outside mountains (0.925 = hills keep 7.5% height).
$FlattenStrength = 0.925
# Offset above which terrain gets compressed (-0.47 = about Y 68).
$FlatBaseOffset = -0.47
# Extra factor outside mountains; factor x6 shrinks 3D-noise bumps about 6x.
$FlatFactorBoost = 5.0
# Erosion at or below this keeps full vanilla terrain: -0.2225 is the top of the erosion bands
# that hold peaks, slopes, meadows and groves, so every mountain and slope biome stays vanilla...
$MountainErosion = -0.2225
# ...and at or above this is fully flattened (linear blend in between).
$FlatErosion = -0.15

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

# --- Ice mountain region ---------------------------------------------------------
# A rectangle forced to frozen peaks: cold, low erosion (mountains), far inland, high peaks.
# Needs the More Density Functions mod (moredfs) on the server. Off: the pack stays mod-free and
# big mountains are found in the natural generation instead (DatapackBiomesToPng /biomefind).
$IceRegion = @{ Enabled = $false; X0 = 16500; X1 = 23500; Z0 = -1500; Z1 = 1500; Blend = 600 }
$IceTemperature = -0.6   # below -0.45 = coldest temperature band
$IceErosion = -0.8       # below -0.78 = most mountainous erosion band
$IceContinents = 0.6     # far inland

# --- Land and mountains ----------------------------------------------------------
# Added to continentalness everywhere. Positive = less ocean and more land far inland, where
# mountains form, while plains keep their share. 0 = vanilla land/ocean split.
$ContinentsShift = 0.0
# Added to erosion everywhere. Negative = more mountains and slopes, fewer flat lowlands.
$ErosionShift = 0.0
# Peak biomes only form on ridge lines of the "peaks and valleys" noise, so vanilla peaks are thin.
# In low-erosion (mountain) zones this pulls that noise onto the ridge, making whole massifs peaks.
# 0 = vanilla, 1 = full massifs. Full effect at erosion <= $MassifErosionFull, none above $MassifErosionStart.
$MassifStrength = 1.0
$MassifErosionFull = -0.55
$MassifErosionStart = -0.375
# Extra mountain height: offset above $MountainAmplifyBase (-0.2 = about Y 102) is multiplied by
# 1 + this, only where erosion is mountainous (full at <= -0.375, none at >= -0.2225). 0 = vanilla.
$MountainAmplify = 0.7
$MountainAmplifyBase = -0.2
# Top of terrain generation (vanilla 256). Mountains fade out over the 16 blocks below it.
$TerrainCeiling = 512

# --- Climate scale -----------------------------------------------------------
# Octave shift for temperature, vegetation, continentalness and erosion.
# 2 = biomes and landforms 4x larger (same as vanilla Large Biomes).
$ClimateOctaveShift = 2

# --- Ores --------------------------------------------------------------------
# Every ore becomes rare giant veins while keeping the vanilla average ore per chunk.
# One ore blob is capped at size 64 (~680 blocks), so a giant vein is a cluster of blobs:
# $VeinBlobs blobs of size $VeinSize scattered up to +-$VeinSpread blocks around the vein centre.
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
# Measured average blocks per placement of each vanilla configured ore feature (solid rock, 40 trials).
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
$NoiseOreVeins = $false
# Per-ore multiplier on giant-vein frequency, measured against vanilla ore per chunk
# (makes up for veins clipped by bedrock/surface and for the removed noise ore veins).
# Measured on 4096 overworld + 1024 nether chunks, vanilla terrain, vanilla / giant-vein ore per chunk.
# Emerald and ancient debris had too few veins in the sample to measure, so they stay at 1.0.
$OreCorrection = @{
    coal = 0.931; iron = 1.253; copper = 1.301; gold = 0.998; redstone = 1.077; lapis = 1.092
    diamond = 0.918; emerald = 1.0; quartz = 0.972; nether_gold = 1.243; ancient_debris = 1.0
}

# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$vanilla = Join-Path $PSScriptRoot '_vanilla-1.21.1\data\minecraft\worldgen'
if ($null -ne $ContinentsShiftOverride) { $ContinentsShift = $ContinentsShiftOverride }
if ($null -ne $ErosionShiftOverride) { $ErosionShift = $ErosionShiftOverride }
if ($null -ne $ClimateOctaveShiftOverride) { $ClimateOctaveShift = $ClimateOctaveShiftOverride }
if ($null -ne $MassifStrengthOverride) { $MassifStrength = $MassifStrengthOverride }
if ($null -ne $MountainAmplifyOverride) { $MountainAmplify = $MountainAmplifyOverride }
if ($null -ne $TerrainCeilingOverride) { $TerrainCeiling = $TerrainCeilingOverride }
if ($NoIceRegion) { $IceRegion.Enabled = $false }
$packRoot = if ($OutDir) { $OutDir } else { Join-Path $PSScriptRoot 'CustomWorldgen' }
if ($OutDir) {
    # Hand-written files (pack.mcmeta, world height, structure spacing) come from the main pack.
    $main = Join-Path $PSScriptRoot 'CustomWorldgen'
    Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($rel in 'pack.mcmeta', 'data\minecraft\dimension_type', 'data\minecraft\worldgen\structure_set') {
        $target = Join-Path $OutDir $rel
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item (Join-Path $main $rel) $target -Recurse
    }
}
$pack = Join-Path $packRoot 'data'
# Remove everything this script generates, so a disabled feature leaves no stale files behind.
Remove-Item (Join-Path $pack 'custom') -Recurse -Force -ErrorAction SilentlyContinue
foreach ($rel in 'noise_settings', 'density_function', 'noise', 'configured_carver', 'placed_feature') {
    Remove-Item (Join-Path $pack "minecraft\worldgen\$rel") -Recurse -Force -ErrorAction SilentlyContinue
}
$utf8 = New-Object Text.UTF8Encoding $false
$inv = [Globalization.CultureInfo]::InvariantCulture

function Save-Json([string]$relPath, $obj) {
    $path = Join-Path $pack $relPath
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    $json = if ($obj -is [string]) { $obj } else { $obj | ConvertTo-Json -Depth 100 }
    [IO.File]::WriteAllText($path, $json, $utf8)
}

function Read-Vanilla([string]$relPath) {
    Get-Content (Join-Path $vanilla $relPath) -Raw | ConvertFrom-Json
}

function Find-Node($node, [scriptblock]$match) {
    if ($null -eq $node -or $node -is [string] -or $node -is [ValueType]) { return $null }
    if ($node -is [Array]) {
        foreach ($item in $node) { $r = Find-Node $item $match; if ($r) { return $r } }
        return $null
    }
    if (& $match $node) { return $node }
    foreach ($p in $node.PSObject.Properties) { $r = Find-Node $p.Value $match; if ($r) { return $r } }
    return $null
}

function Find-AllNodes($node, [scriptblock]$match) {
    if ($null -eq $node -or $node -is [string] -or $node -is [ValueType]) { return }
    if ($node -is [Array]) { foreach ($item in $node) { Find-AllNodes $item $match }; return }
    if (& $match $node) { $node }
    foreach ($p in $node.PSObject.Properties) { Find-AllNodes $p.Value $match }
}

function Max-Df($a, $b) { [ordered]@{ type = 'minecraft:max'; argument1 = $a; argument2 = $b } }

$iceMask = 'custom:overworld/ice_mask'
# Inside the ice region, pulls $raw down to $target (or up, with -Up); untouched outside.
function Pull-Toward($raw, [double]$target, [switch]$Up) {
    $gap = [ordered]@{ type = 'minecraft:add'; argument1 = $target; argument2 = [ordered]@{ type = 'minecraft:mul'; argument1 = -1.0; argument2 = $raw } }
    $limited = [ordered]@{ type = $(if ($Up) { 'minecraft:max' } else { 'minecraft:min' }); argument1 = $gap; argument2 = 0.0 }
    [ordered]@{ type = 'minecraft:add'; argument1 = $raw; argument2 = [ordered]@{ type = 'minecraft:mul'; argument1 = $iceMask; argument2 = $limited } }
}

# --- Caves -------------------------------------------------------------------
$suppressor = 'custom:overworld/caves/suppressor'

Save-Json 'custom\worldgen\noise\cave_regions.json' ([ordered]@{ firstOctave = $CaveRegionOctave; amplitudes = @(1.0, 1.0) })

# Positive (solid) where cave_regions noise is above the threshold.
Save-Json 'custom\worldgen\density_function\overworld\caves\suppressor.json' ([ordered]@{
    type = 'minecraft:cache_2d'
    argument = [ordered]@{
        type = 'minecraft:mul'
        argument1 = $CaveEdgeSharpness
        argument2 = [ordered]@{
            type = 'minecraft:add'
            argument1 = -$CaveKeepThreshold
            argument2 = [ordered]@{ type = 'minecraft:noise'; noise = 'custom:cave_regions'; xz_scale = 1.0; y_scale = 0.0 }
        }
    }
})

$ns = Read-Vanilla 'noise_settings\overworld.json'
$fd = $ns.noise_router.final_density
$choice = Find-Node $fd { param($n) $n.type -eq 'minecraft:range_choice' -and $n.input -eq 'minecraft:overworld/sloped_cheese' }
if (-not $choice) { throw 'sloped_cheese range_choice not found in final_density' }
# Near the surface: cave entrances. Deeper: cheese, spaghetti and pillars.
$choice.when_in_range.argument2 = Max-Df $choice.when_in_range.argument2 $suppressor
$choice.when_out_of_range = Max-Df $choice.when_out_of_range $suppressor
if ($fd.argument2 -ne 'minecraft:overworld/caves/noodle') { throw 'unexpected final_density shape (noodle)' }
$fd.argument2 = Max-Df $fd.argument2 $suppressor
$ns.ore_veins_enabled = $NoiseOreVeins

# Terrain ceiling: generate noise up to $TerrainCeiling and move the vanilla top fade (Y 240..256) under it.
$fades = @(Find-AllNodes $ns.noise_router { param($n) $n.type -eq 'minecraft:y_clamped_gradient' -and $n.from_y -eq 240 -and $n.to_y -eq 256 })
if ($fades.Count -ne 2) { throw "expected 2 top-fade gradients, found $($fades.Count)" }
foreach ($f in $fades) { $f.from_y = $TerrainCeiling - 16; $f.to_y = $TerrainCeiling }
$ns.noise.height = $TerrainCeiling - $ns.noise.min_y
if ($ns.noise.height % 16 -ne 0) { throw 'TerrainCeiling + 64 must be a multiple of 16' }
if ($IceRegion.Enabled) {
    Save-Json 'custom\worldgen\density_function\overworld\temperature_raw.json' $ns.noise_router.temperature
    $ns.noise_router.temperature = Pull-Toward 'custom:overworld/temperature_raw' $IceTemperature
}
Save-Json 'minecraft\worldgen\noise_settings\overworld.json' $ns

foreach ($name in 'cave', 'cave_extra_underground', 'canyon') {
    $c = Read-Vanilla "configured_carver\$name.json"
    $c.config.probability = [math]::Round($c.config.probability * $CarverScale, 5)
    Save-Json "minecraft\worldgen\configured_carver\$name.json" $c
}

# --- Flat terrain ------------------------------------------------------------
$customDf = Join-Path $pack 'custom\worldgen\density_function\overworld'
New-Item -ItemType Directory -Force $customDf | Out-Null
Copy-Item (Join-Path $vanilla 'density_function\overworld\offset.json') (Join-Path $customDf 'offset_vanilla.json') -Force
Copy-Item (Join-Path $vanilla 'density_function\overworld\factor.json') (Join-Path $customDf 'factor_vanilla.json') -Force

# 0 in mountains (low erosion), 1 in flat-land erosion range.
Save-Json 'custom\worldgen\density_function\overworld\flatness.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:spline'
        spline = [ordered]@{
            coordinate = 'minecraft:overworld/erosion'
            points = @(
                [ordered]@{ location = $MountainErosion; value = 0.0; derivative = 0.0 },
                [ordered]@{ location = $FlatErosion; value = 1.0; derivative = 0.0 }
            )
        }
    }
})

# offset - flatness * strength * max(offset - base, 0): squashes hills, keeps valleys and oceans.
Save-Json 'custom\worldgen\density_function\overworld\offset_flat.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:cache_2d'
        argument = [ordered]@{
            type = 'minecraft:add'
            argument1 = 'custom:overworld/offset_vanilla'
            argument2 = [ordered]@{
                type = 'minecraft:mul'
                argument1 = 'custom:overworld/flatness'
                argument2 = [ordered]@{
                    type = 'minecraft:mul'
                    argument1 = -$FlattenStrength
                    argument2 = Max-Df ([ordered]@{ type = 'minecraft:add'; argument1 = 'custom:overworld/offset_vanilla'; argument2 = -$FlatBaseOffset }) 0.0
                }
            }
        }
    }
})

function Linear-Spline([string]$coordinate, [double[][]]$points) {
    [ordered]@{
        type = 'minecraft:spline'
        spline = [ordered]@{
            coordinate = $coordinate
            points = @($points | ForEach-Object { [ordered]@{ location = $_[0]; value = $_[1]; derivative = $_[2] } })
        }
    }
}

# 1 inland and away from river corridors in flat land, 0 at coasts, rivers and mountains.
Save-Json 'custom\worldgen\density_function\overworld\lake_mask.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:mul'
        argument1 = 'custom:overworld/flatness'
        argument2 = [ordered]@{
            type = 'minecraft:mul'
            argument1 = Linear-Spline 'minecraft:overworld/continents' @(@(-0.11, 0.0, 0.0), @(0.0, 1.0, 0.0))
            argument2 = Linear-Spline 'minecraft:overworld/ridges' @(@(-0.2, 1.0, 0.0), @(-0.1, 0.0, 0.0), @(0.1, 0.0, 0.0), @(0.2, 1.0, 0.0))
        }
    }
})

# offset_flat
#   + fill * lake_mask * max(floor - offset_flat, 0)              lifts inland dips that would hold small lakes
#   + amplify * mountain_weight * max(offset_flat - base, 0)       makes mountains taller
# depth = vertical gradient + offset. Vanilla clamps the gradient at Y 320, which would turn every column
# with a high offset into an endless pillar; extend it at the same slope up to the terrain ceiling.
$depth = Read-Vanilla 'density_function\overworld\depth.json'
$gradient = $depth.argument1
$slope = ($gradient.to_value - $gradient.from_value) / ($gradient.to_y - $gradient.from_y)
$gradient.to_value = $gradient.from_value + $slope * ([math]::Max($TerrainCeiling, $gradient.to_y) - $gradient.from_y)
$gradient.to_y = [math]::Max($TerrainCeiling, $gradient.to_y)
Save-Json 'minecraft\worldgen\density_function\overworld\depth.json' $depth

Save-Json 'custom\worldgen\density_function\overworld\mountain_weight.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = Linear-Spline 'minecraft:overworld/erosion' @(@(-0.375, 1.0, 0.0), @(-0.2225, 0.0, 0.0))
})
Save-Json 'minecraft\worldgen\density_function\overworld\offset.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:cache_2d'
        argument = [ordered]@{
            type = 'minecraft:add'
            argument1 = [ordered]@{
                type = 'minecraft:add'
                argument1 = 'custom:overworld/offset_flat'
                argument2 = [ordered]@{
                    type = 'minecraft:mul'
                    argument1 = 'custom:overworld/lake_mask'
                    argument2 = [ordered]@{
                        type = 'minecraft:mul'
                        argument1 = $LakeFill
                        argument2 = Max-Df ([ordered]@{ type = 'minecraft:add'; argument1 = $LakeFloorOffset; argument2 = [ordered]@{ type = 'minecraft:mul'; argument1 = -1.0; argument2 = 'custom:overworld/offset_flat' } }) 0.0
                    }
                }
            }
            argument2 = [ordered]@{
                type = 'minecraft:mul'
                argument1 = 'custom:overworld/mountain_weight'
                argument2 = [ordered]@{
                    type = 'minecraft:mul'
                    argument1 = $MountainAmplify
                    argument2 = Max-Df ([ordered]@{ type = 'minecraft:add'; argument1 = 'custom:overworld/offset_flat'; argument2 = -$MountainAmplifyBase }) 0.0
                }
            }
        }
    }
})

# Rivers: stretch the ridges noise, then remap it so the river band keeps vanilla width.
$ridges = Read-Vanilla 'density_function\overworld\ridges.json'
$ridges.argument.xz_scale = $ridges.argument.xz_scale / $RiverSpacing
Save-Json 'custom\worldgen\density_function\overworld\ridges_stretched.json' $ridges
$inner = $RiverBand / $RiverSpacing                  # raw value that maps to the band edge
$outerSlope = (1.0 - $RiverBand) / (1.0 - $inner)
$knee = $inner + 0.05                                # short blend between the steep and the gentle part
$kneeValue = $RiverBand + $outerSlope * 0.05
$steep = 2.8 * $outerSlope                     # below the band slope (3x) so the spline stays monotonic
$riverRidges = [ordered]@{
    type = 'minecraft:flat_cache'
    argument = Linear-Spline 'custom:overworld/ridges_stretched' @(
        @(-1.0, -1.0, $outerSlope), @(-$knee, -$kneeValue, $outerSlope), @(-$inner, -$RiverBand, $steep),
        @($inner, $RiverBand, $steep), @($knee, $kneeValue, $outerSlope), @(1.0, 1.0, $outerSlope))
}
Save-Json 'custom\worldgen\density_function\overworld\ridges_rivers.json' $riverRidges
$rr = 'custom:overworld/ridges_rivers'

# Massifs: 1 in mountain-erosion zones (times $MassifStrength), 0 elsewhere.
Save-Json 'custom\worldgen\density_function\overworld\massif.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:mul'
        argument1 = $MassifStrength
        argument2 = Linear-Spline 'minecraft:overworld/erosion' @(@($MassifErosionFull, 1.0, 0.0), @($MassifErosionStart, 0.0, 0.0))
    }
})
$ridgePull = if ($IceRegion.Enabled) { Max-Df $iceMask 'custom:overworld/massif' } else { 'custom:overworld/massif' }
# Where pulled: ridges -> 0.667 + 0.15 * ridges. Positive weirdness picks frozen (not jagged) peaks in the cold,
# and |ridges| near 2/3 is the "high"/"peaks" part of the peaks-and-valleys curve.
Save-Json 'minecraft\worldgen\density_function\overworld\ridges.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:add'
        argument1 = $rr
        argument2 = [ordered]@{
            type = 'minecraft:mul'
            argument1 = $ridgePull
            argument2 = [ordered]@{ type = 'minecraft:add'; argument1 = 0.667; argument2 = [ordered]@{ type = 'minecraft:mul'; argument1 = -0.85; argument2 = $rr } }
        }
    }
})

# --- Land share ----------------------------------------------------------------
# continentalness + shift: more land far from the sea, where mountains form.
$continentsShifted = Read-Vanilla 'density_function\overworld\continents.json'
$continentsShifted.argument = [ordered]@{ type = 'minecraft:add'; argument1 = $continentsShifted.argument; argument2 = $ContinentsShift }
Save-Json 'custom\worldgen\density_function\overworld\continents_shifted.json' $continentsShifted
# erosion + shift: negative = more land in the low-erosion bands that hold peaks and slopes.
$erosionShifted = Read-Vanilla 'density_function\overworld\erosion.json'
$erosionShifted.argument = [ordered]@{ type = 'minecraft:add'; argument1 = $erosionShifted.argument; argument2 = $ErosionShift }
Save-Json 'custom\worldgen\density_function\overworld\erosion_shifted.json' $erosionShifted

# --- Ice mountain region -------------------------------------------------------
if ($IceRegion.Enabled) {
    $b = $IceRegion.Blend
    function Edge-Gradient([string]$axis, [int]$from, [int]$to, [double]$fromValue, [double]$toValue) {
        [ordered]@{ type = "moredfs:${axis}_clamped_gradient"; "from_$axis" = $from; "to_$axis" = $to; from_value = $fromValue; to_value = $toValue }
    }
    # 1 inside X0..X1 x Z0..Z1, fading to 0 over $b blocks outside it.
    Save-Json 'custom\worldgen\density_function\overworld\ice_mask.json' ([ordered]@{
        type = 'minecraft:flat_cache'
        argument = [ordered]@{
            type = 'minecraft:mul'
            argument1 = [ordered]@{ type = 'minecraft:min'; argument1 = (Edge-Gradient 'x' ($IceRegion.X0 - $b) $IceRegion.X0 0.0 1.0); argument2 = (Edge-Gradient 'x' $IceRegion.X1 ($IceRegion.X1 + $b) 1.0 0.0) }
            argument2 = [ordered]@{ type = 'minecraft:min'; argument1 = (Edge-Gradient 'z' ($IceRegion.Z0 - $b) $IceRegion.Z0 0.0 1.0); argument2 = (Edge-Gradient 'z' $IceRegion.Z1 ($IceRegion.Z1 + $b) 1.0 0.0) }
        }
    })
    foreach ($pair in @(@('continents', $IceContinents, $true, 'custom:overworld/continents_shifted'), @('erosion', $IceErosion, $false, 'custom:overworld/erosion_shifted'))) {
        Save-Json "minecraft\worldgen\density_function\overworld\$($pair[0]).json" ([ordered]@{
            type = 'minecraft:flat_cache'
            argument = (Pull-Toward $pair[3] $pair[1] -Up:$pair[2])
        })
    }
} else {
    Save-Json 'minecraft\worldgen\density_function\overworld\continents.json' $continentsShifted
    Save-Json 'minecraft\worldgen\density_function\overworld\erosion.json' $erosionShifted
}

# factor * (1 + boost * flatness): higher factor = smaller 3D-noise bumps.
Save-Json 'minecraft\worldgen\density_function\overworld\factor.json' ([ordered]@{
    type = 'minecraft:flat_cache'
    argument = [ordered]@{
        type = 'minecraft:cache_2d'
        argument = [ordered]@{
            type = 'minecraft:mul'
            argument1 = 'custom:overworld/factor_vanilla'
            argument2 = [ordered]@{
                type = 'minecraft:add'
                argument1 = 1.0
                argument2 = [ordered]@{ type = 'minecraft:mul'; argument1 = $FlatFactorBoost; argument2 = 'custom:overworld/flatness' }
            }
        }
    }
})

# --- Climate scale -----------------------------------------------------------
foreach ($name in 'temperature', 'vegetation', 'continentalness', 'erosion') {
    $n = Read-Vanilla "noise\$name.json"
    $n.firstOctave = $n.firstOctave - $ClimateOctaveShift
    Save-Json "minecraft\worldgen\noise\$name.json" $n
}

# --- Ores --------------------------------------------------------------------
$oreReport = foreach ($name in $OrePlacedFeatures) {
    $placed = Read-Vanilla "placed_feature\$name.json"
    $cfName = $placed.feature -replace '^minecraft:', ''
    $cf = Read-Vanilla "configured_feature\$cfName.json"
    $family = ($cf.config.targets[0].state.Name -replace '^minecraft:(deepslate_)?', '') -replace '_ore$', '' -replace '^nether_quartz$', 'quartz'
    if (-not $OreCorrection.ContainsKey($family)) { throw "no OreCorrection entry for '$family' ($name)" }
    $vein = if ($VeinOverride.ContainsKey($family)) { $VeinOverride[$family] } else { @{ Size = $VeinSize; Blobs = $VeinBlobs; Spread = $VeinSpread; Blocks = $VeinBlocks } }
    # Ancient debris is "scattered_ore" in vanilla (loose single blocks); veins must be solid blobs.
    $cf.type = 'minecraft:ore'
    $cf.config.size = $vein.Size
    $cf.config.discard_chance_on_air_exposure = 0.0
    $veinFeature = if ($vein.Blobs -le 1) { $cf } else {
        [ordered]@{
            type = 'minecraft:random_patch'
            config = [ordered]@{
                tries = $vein.Blobs
                xz_spread = $vein.Spread
                y_spread = $vein.Spread
                feature = [ordered]@{ feature = $cf; placement = @() }
            }
        }
    }
    Save-Json "custom\worldgen\configured_feature\vein\$name.json" $veinFeature

    # Vanilla veins per chunk: count (fixed or uniform) or 1-in-N rarity.
    $veins = 1.0
    $placement = foreach ($m in $placed.placement) {
        switch ($m.type) {
            'minecraft:count' {
                $veins = if ($m.count -is [ValueType]) { [double]$m.count } else { ($m.count.min_inclusive + $m.count.max_inclusive) / 2.0 }
                continue
            }
            'minecraft:rarity_filter' { $veins = 1.0 / $m.chance; continue }
            'minecraft:height_range' {
                $nether = $cf.config.targets[0].state.Name -match 'nether|ancient_debris'
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
    # Big veins per chunk that keep the same ore blocks per chunk; a weighted list gives the exact mean.
    $bigVeins = $veins * $VanillaVeinBlocks[$cfName] / $vein.Blocks * $OreCorrection[$family]
    $low = [math]::Floor($bigVeins)
    $highWeight = [int][math]::Round(($bigVeins - $low) * 1000000)
    $distribution = @([ordered]@{ data = [int]$low; weight = 1000000 - $highWeight })
    if ($highWeight -gt 0) { $distribution += [ordered]@{ data = [int]$low + 1; weight = $highWeight } }
    $count = [ordered]@{ type = 'minecraft:count'; count = [ordered]@{ type = 'minecraft:weighted_list'; distribution = $distribution } }
    Save-Json "minecraft\worldgen\placed_feature\$name.json" ([ordered]@{ feature = "custom:vein/$name"; placement = @($count) + @($placement) })
    [string]::Format($inv, '{0,-26} vanilla {1,7:F3} veins x {2,5:F1} blocks -> {3,7:F4} big veins/chunk (1 per {4:F1} chunks)', $name, $veins, $VanillaVeinBlocks[$cfName], $bigVeins, 1 / $bigVeins)
}

# --- Check every generated file parses back -----------------------------------
Get-ChildItem $pack -Recurse -File -Filter *.json | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null }
# ConvertTo-Json silently truncates deep trees, so make sure the surface rules survived intact.
$before = (Read-Vanilla 'noise_settings\overworld.json').surface_rule | ConvertTo-Json -Depth 100 -Compress
$after = (Get-Content (Join-Path $pack 'minecraft\worldgen\noise_settings\overworld.json') -Raw | ConvertFrom-Json).surface_rule | ConvertTo-Json -Depth 100 -Compress
if ($before -ne $after) { throw 'surface_rule changed during JSON round-trip' }
'Pack built: ' + (Get-ChildItem $pack -Recurse -File).Count + ' files'
$oreReport
