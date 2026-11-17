"""Model check of CustomWorldgen-26.3-low: height range, histogram and neighbour steps on 3000x3000 blocks per seed."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcnoise import Normal, spline, monotone
import low_terrain as T
for seed in range(int(sys.argv[1]) if len(sys.argv) > 1 else 3):
    rng = np.random.default_rng(seed); a = Normal(rng, *T.RELIEF); b = Normal(rng, *T.REGION)
    x, z = np.meshgrid(np.arange(3000.) + seed * 1e5, np.arange(3000.), indexing='ij')
    h = spline(monotone(T.HEIGHT), a(x, z) + T.REGION_W * b(x, z)); top = np.ceil(h) - 1
    step = max(np.abs(np.diff(top, axis=0)).max(), np.abs(np.diff(top, axis=1)).max())
    grad = max(np.abs(np.diff(h, axis=0)).max(), np.abs(np.diff(h, axis=1)).max())
    hist = np.bincount(top.astype(int).ravel() - 63, minlength=18) / top.size
    print(f'seed {seed}: top Y {top.min():.0f}..{top.max():.0f}, max gradient {grad:.3f}, max neighbour step {step:.0f}')
    print('   ' + ' '.join(f'{63+i}:{100*p:.0f}%' for i, p in enumerate(hist)))
