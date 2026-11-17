import sys, numpy as np
from mcnoise import Normal, spline, monotone
import gentle_terrain as T
def sp(pts): return monotone(pts)
SP = {k: sp(getattr(T, k)) for k in ['BASE', 'HILL_AMP', 'PEAK_S1', 'PEAK_S2', 'MOUNT_OFF', 'FOOT', 'MICRO_AMP']}
class World:
    def __init__(s, seed):
        r = np.random.default_rng(seed)
        s.c = Normal(r, *T.CONTINENTALNESS[:2], T.CONTINENTALNESS[2]); s.e = Normal(r, *T.EROSION[:2], T.EROSION[2])
        s.w = Normal(r, *T.RIDGE[:2], T.RIDGE[2]); s.nh = Normal(r, *T.HILL[:2], T.HILL[2]); s.p1 = Normal(r, *T.PEAK1[:2], T.PEAK1[2]); s.p2 = Normal(r, *T.PEAK2[:2], T.PEAK2[2]); s.mi = Normal(r, *T.MICRO[:2], T.MICRO[2])
    def fields(s, x, z):
        return s.c(x, z), s.e(x, z) + T.EROSION_SHIFT, s.w(x, z), s.nh(x, z), (s.p1(x, z), s.p2(x, z))
    def h(s, x, z, parts=False):
        c, e, w, nh, (p1, p2) = s.fields(x, z)
        base = spline(SP['BASE'], c)
        hills = spline(SP['HILL_AMP'], e) * (nh + T.HILL_BIAS)
        mnt = np.maximum(0, spline(SP['PEAK_S1'], 1 - np.abs(p1)) + spline(SP['PEAK_S2'], 1 - np.abs(p2)) + spline(SP['MOUNT_OFF'], e)) + spline(SP['FOOT'], e)
        micro = spline(SP['MICRO_AMP'], e) * s.mi(x, z)
        land = base + np.minimum(hills + mnt + micro, T.COAST_K * np.maximum(0, c - T.COAST_C))
        river = T.RIVER_Y + T.RIVER_S * np.maximum(0, np.abs(w) - T.RIVER_W0)
        h = np.minimum(land, np.maximum(river, land - T.RIVER_DEPTH))
        h = np.where(h > T.TOP[0][0], spline(T.TOP, h), h)
        if parts: return h, dict(c=c, e=e, w=w, base=base, hills=hills, mnt=mnt, land=land)
        return h
def surface_blocks(world, x0, z0, n):
    """Block surface like the game: h at the 4-block cell corners, bilinear inside, top solid block = ceil(h)-1."""
    cx = np.arange(x0, x0 + n + 1, 4.0); cz = np.arange(z0, z0 + n + 1, 4.0)
    X, Z = np.meshgrid(cx, cz, indexing='ij'); H = world.h(X, Z)
    bx = np.arange(n); ix = bx // 4; fx = (bx % 4 + 0.0) / 4
    Hx = H[ix, :] * (1 - fx)[:, None] + H[ix + 1, :] * fx[:, None]
    Hb = Hx[:, ix] * (1 - fx)[None, :] + Hx[:, ix + 1] * fx[None, :]
    return np.ceil(Hb) - 1
if __name__ == '__main__':
    seeds = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    allh = []; grads = []; parts_all = []; worst = []; stepmax = 0; steps = []
    for seed in range(seeds):
        W = World(seed); r = np.random.default_rng(1000 + seed)
        X = r.random(300000) * 400000 - 200000; Z = r.random(300000) * 400000 - 200000
        h, p = W.h(X, Z, True); allh.append(h); parts_all.append(p)
        eps = 0.5
        gx = (W.h(X + eps, Z) - W.h(X - eps, Z)) / (2 * eps); gz = (W.h(X, Z + eps) - W.h(X, Z - eps)) / (2 * eps)
        g = np.hypot(gx, gz); grads.append(g)
        # block test on tiles around the steepest samples
        for k in np.argsort(g)[-6:]:
            sb = surface_blocks(W, np.floor(X[k]) - 128, np.floor(Z[k]) - 128, 256)
            d = max(np.abs(np.diff(sb, axis=0)).max(), np.abs(np.diff(sb, axis=1)).max()); steps.append(d)
    h = np.concatenate(allh); g = np.concatenate(grads)
    P = {k: np.concatenate([p[k] for p in parts_all]) for k in parts_all[0]}
    land = h >= 63
    print('ocean (h<63) %.1f%%  land %.1f%%' % (100 * (~land).mean(), 100 * land.mean()))
    print('mountains h>120: %.1f%%  h>200: %.2f%%' % (100 * (h > 120).mean(), 100 * (h > 200).mean()))
    print('height q', np.round(np.quantile(h, [0, .05, .25, .5, .75, .9, .95, .99, .999, 1]), 1))
    print('land height q', np.round(np.quantile(h[land], [.1, .25, .5, .75, .9, .99]), 1))
    print('gradient |grad h|: mean %.3f  q99 %.3f  q99.9 %.3f  q99.99 %.3f  max %.3f' % (g.mean(), *np.quantile(g, [.99, .999, .9999]), g.max()))
    print('max block step between neighbours near the steepest points:', max(steps), ' (all tiles: %s)' % sorted(set(steps)))
