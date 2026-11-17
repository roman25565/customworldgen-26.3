#!/usr/bin/env python3
"""Builds CustomWorldgen-26.3-vanilla-terrain: the caves, ore and structure changes of CustomWorldgen-26.3 on top of
vanilla terrain, biomes, climate and world height (nothing of the surface generation is changed).

    python build-pack-vanilla-terrain.py        (needs the built CustomWorldgen-26.3 next to this script)

Taken unchanged from CustomWorldgen-26.3: tunnel and big-cave regions, carvers (fewer caves and canyons), ore as big single
clumps (and no noise ore veins), witch huts and desert pyramids 5x as common. final_density is the one of CustomWorldgen-26.3
with the top fade put back at vanilla's Y 240..256. Ore never touches air (discard_chance_on_air_exposure 1.0), and the stone types (granite, diorite, andesite, tuff) are
rare giant veins too, with the vanilla blocks per chunk. Not taken: climate noises, continents, erosion, ridges, offset, factor, depth,
preliminary surface, noise settings, dimension type (all vanilla).
"""
import json, os, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'CustomWorldgen-26.3')
OUT = os.path.join(HERE, 'CustomWorldgen-26.3-vanilla-terrain')
VANILLA = os.path.join(HERE, '_vanilla-26.3')
if not os.path.isdir(SRC): sys.exit('build CustomWorldgen-26.3 first (build-pack.ps1): ' + SRC)
shutil.rmtree(OUT, ignore_errors=True)
os.makedirs(OUT)
for rel in ['data/custom/worldgen/feature', 'data/custom/worldgen/noise/cave_regions.json', 'data/custom/worldgen/noise/tunnel_regions.json',
            'data/custom/worldgen/density_function/overworld/cave_suppressor.json', 'data/custom/worldgen/density_function/overworld/tunnel_suppressor.json',
            'data/minecraft/worldgen/carver', 'data/minecraft/worldgen/placed_feature', 'data/minecraft/worldgen/structure_set',
            'data/minecraft/worldgen/material_rule']:
    s, d = os.path.join(SRC, *rel.split('/')), os.path.join(OUT, *rel.split('/'))
    if os.path.isdir(s): shutil.copytree(s, d)
    else:
        os.makedirs(os.path.dirname(d), exist_ok=True); shutil.copyfile(s, d)
def load(p):
    with open(p, encoding='utf-8') as f: return json.load(f)
def save(p, o):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8', newline='\n') as f: json.dump(o, f, indent=2); f.write('\n')
# final density: the pack's cave changes, vanilla's top fade
rel = os.path.join('data', 'minecraft', 'worldgen', 'density_function', 'overworld', 'final_density.json')
fd = load(os.path.join(SRC, rel)); van = load(os.path.join(VANILLA, rel))
def fades(n, out):
    if isinstance(n, dict):
        if n.get('type') == 'minecraft:gradient' and n.get('axis') == 'y' and n.get('from_value') == 1.0 and n.get('to_value') == 0.0: out.append(n)
        for v in n.values(): fades(v, out)
    elif isinstance(n, list):
        for v in n: fades(v, out)
    return out
f, v = fades(fd, []), fades(van, [])
if len(f) != 1 or len(v) != 1: sys.exit('unexpected final_density shape: top fade not found once')
f[0]['from_coordinate'], f[0]['to_coordinate'] = v[0]['from_coordinate'], v[0]['to_coordinate']
save(os.path.join(OUT, rel), fd)
meta = load(os.path.join(SRC, 'pack.mcmeta'))
meta['pack']['description'] = 'CustomWorldgen 26.3: fewer caves, big ore clumps, more witch huts and pyramids (vanilla terrain)'
save(os.path.join(OUT, 'pack.mcmeta'), meta)

# --- ore never touches air ------------------------------------------------------
ORE_AIR_DISCARD = 1.0       # 1.0 = an ore block with air next to it is not placed; vanilla lets most ores (not all) touch air
STONE_AIR_DISCARD = 0.0     # stone veins may show in cave walls
vein_dir = os.path.join(OUT, 'data', 'custom', 'worldgen', 'feature', 'vein')
for name in sorted(os.listdir(vein_dir)):
    p = os.path.join(vein_dir, name); o = load(p); o['discard_chance_on_air_exposure'] = ORE_AIR_DISCARD; save(p, o)

# --- stone veins as giant veins, the same way as the ores (see build-pack.ps1, Ores) ----------------------------
# Vanilla features (26.3). A blob of size 64 is ~684 blocks in solid rock (the OreFeature algorithm, 300 trials), so the vanilla
# blocks per chunk is placements x 684, and a giant vein (10 blobs of 64, spread 5) is 3074 blocks as measured for the ores.
STONES = json.loads('{"granite":{"feature":{"type":"minecraft:ore","discard_chance_on_air_exposure":0.0,"size":64,"targets":[{"state":"minecraft:granite","target":{"predicate_type":"minecraft:tag_match","tag":"minecraft:base_stone_overworld"}}]},"placed":{"ore_granite_upper":[{"type":"minecraft:rarity_filter","chance":6},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":128},"min_inclusive":{"absolute":64}}},{"type":"minecraft:biome"}],"ore_granite_lower":[{"type":"minecraft:count","count":2},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":60},"min_inclusive":{"absolute":0}}},{"type":"minecraft:biome"}]}},"diorite":{"feature":{"type":"minecraft:ore","discard_chance_on_air_exposure":0.0,"size":64,"targets":[{"state":"minecraft:diorite","target":{"predicate_type":"minecraft:tag_match","tag":"minecraft:base_stone_overworld"}}]},"placed":{"ore_diorite_upper":[{"type":"minecraft:rarity_filter","chance":6},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":128},"min_inclusive":{"absolute":64}}},{"type":"minecraft:biome"}],"ore_diorite_lower":[{"type":"minecraft:count","count":2},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":60},"min_inclusive":{"absolute":0}}},{"type":"minecraft:biome"}]}},"andesite":{"feature":{"type":"minecraft:ore","discard_chance_on_air_exposure":0.0,"size":64,"targets":[{"state":"minecraft:andesite","target":{"predicate_type":"minecraft:tag_match","tag":"minecraft:base_stone_overworld"}}]},"placed":{"ore_andesite_upper":[{"type":"minecraft:rarity_filter","chance":6},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":128},"min_inclusive":{"absolute":64}}},{"type":"minecraft:biome"}],"ore_andesite_lower":[{"type":"minecraft:count","count":2},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":60},"min_inclusive":{"absolute":0}}},{"type":"minecraft:biome"}]}},"tuff":{"feature":{"type":"minecraft:ore","discard_chance_on_air_exposure":0.0,"size":64,"targets":[{"state":"minecraft:tuff","target":{"predicate_type":"minecraft:tag_match","tag":"minecraft:base_stone_overworld"}}]},"placed":{"ore_tuff":[{"type":"minecraft:count","count":2},{"type":"minecraft:in_square"},{"type":"minecraft:height_range","height":{"type":"minecraft:uniform","max_inclusive":{"absolute":0},"min_inclusive":{"above_bottom":0}}},{"type":"minecraft:biome"}]}}}')
BLOB_BLOCKS, VEIN_BLOCKS, VEIN_BLOBS, VEIN_SPREAD = 684.0, 3074.0, 10, 5
def mean_count(p):
    for m in p:
        if m['type'] == 'minecraft:count': return float(m['count']) if not isinstance(m['count'], dict) else (m['count']['min_inclusive'] + m['count']['max_inclusive']) / 2.0
        if m['type'] == 'minecraft:rarity_filter': return 1.0 / m['chance']
    return 1.0
report = []
for name, d in STONES.items():
    feat = dict(d['feature']); feat['discard_chance_on_air_exposure'] = STONE_AIR_DISCARD
    save(os.path.join(vein_dir, 'stone_%s.json' % name), feat)
    for placed, pl in d['placed'].items():
        big = mean_count(pl) * BLOB_BLOCKS / VEIN_BLOCKS
        low = int(big); hi = int(round((big - low) * 1000000))
        dist = [{'data': low, 'weight': 1000000 - hi}] + ([{'data': low + 1, 'weight': hi}] if hi else [])
        spread = {'type': 'minecraft:trapezoid', 'max': VEIN_SPREAD, 'min': -VEIN_SPREAD, 'plateau': 0}
        rest = [m for m in pl if m['type'] not in ('minecraft:count', 'minecraft:rarity_filter')]
        placement = [{'type': 'minecraft:count', 'count': {'type': 'minecraft:weighted_list', 'distribution': dist}}] + rest + \
            [{'type': 'minecraft:count', 'count': VEIN_BLOBS}, {'type': 'minecraft:offset', 'x': spread, 'y': spread, 'z': spread}]
        save(os.path.join(OUT, 'data', 'minecraft', 'worldgen', 'placed_feature', placed + '.json'), {'feature': 'custom:vein/stone_' + name, 'placement': placement})
        report.append('%-22s vanilla %7.3f placements x %.0f = %7.1f blocks/chunk -> %.4f giant veins/chunk (1 per %.1f chunks)' % (placed, mean_count(pl), BLOB_BLOCKS, mean_count(pl) * BLOB_BLOCKS, big, 1 / big))

print(sum(len(fs) for _, _, fs in os.walk(OUT)), 'files written to', OUT)
print('\n'.join(report))
