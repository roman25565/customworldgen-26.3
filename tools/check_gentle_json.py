"""Evaluate the pack's 2D density functions from JSON (subset) and compare with the model in sim_gentle."""
import json, os, sys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate_gentle as S
from mcnoise import spline
PACK = sys.argv[1]
def load(ns, kind, path):
    return json.load(open(os.path.join(PACK, 'data', ns, 'worldgen', kind, path + '.json')))
W = S.World(3)
NOISE = {'minecraft:continentalness': W.c, 'minecraft:erosion': W.e, 'minecraft:ridge': W.w, 'custom:hills': W.nh, 'custom:peaks': W.p1, 'custom:side_peaks': W.p2, 'custom:micro': W.mi}
def ev(node, x, z):
    if isinstance(node, (int, float)): return np.full_like(x, float(node))
    if isinstance(node, str):
        ns, p = node.split(':'); return ev(load(ns, 'density_function', p), x, z)
    t = node['type'][10:]
    if t in ('add', 'mul', 'min', 'max'):
        a, b = ev(node['left'], x, z), ev(node['right'], x, z)
        return {'add': a + b, 'mul': a * b, 'min': np.minimum(a, b), 'max': np.maximum(a, b)}[t]
    if t == 'cache': return ev(node['input'], x, z)
    if t == 'abs': return np.abs(ev(node['input'], x, z))
    if t == 'noise':
        n = NOISE[node['noise']]; xz = node['xz_scale']
        assert abs(xz - n.xz) < 1e-12, (node['noise'], xz, n.xz)
        return n(x, z)
    if t == 'spline':
        sp = node['spline']; c = ev(sp['coordinate'], x, z)
        return spline([(p['location'], p['value'], p['derivative']) for p in sp['points']], c)
    raise ValueError(t)
r = np.random.default_rng(0); X = r.random(200000) * 4e5 - 2e5; Z = r.random(200000) * 4e5 - 2e5
hj = ev('custom:overworld/terrain_h', X, Z); hm = W.h(X, Z)
print('max |json - model| = %.2e blocks' % np.abs(hj - hm).max())
