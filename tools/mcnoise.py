"""Minecraft-like ImprovedNoise / PerlinNoise / NormalNoise in numpy (random permutations: statistics match, seeds don't)."""
import numpy as np
G = np.array([[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],[1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],[0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1],[1,1,0],[0,-1,1],[-1,1,0],[0,-1,-1]], float)
def _fade(t): return t*t*t*(t*(t*6-15)+10)
class Improved:
    def __init__(s, rng):
        s.o = rng.random(3)*256; p = rng.permutation(256); s.p = np.concatenate([p, p])
    def __call__(s, x, z):
        x = x + s.o[0]; y = s.o[1] + 0*x; z = z + s.o[2]
        xi = np.floor(x).astype(np.int64); yi = np.floor(y).astype(np.int64); zi = np.floor(z).astype(np.int64)
        xf = x - xi; yf = y - yi; zf = z - zi
        P = s.p; xi &= 255; yi &= 255; zi &= 255
        a = P[xi]; b = P[xi+1]
        aa = P[(a+yi)&255]; ab = P[(a+yi+1)&255]; ba = P[(b+yi)&255]; bb = P[(b+yi+1)&255]
        def g(h, dx, dy, dz):
            v = G[h & 15]; return v[..., 0]*dx + v[..., 1]*dy + v[..., 2]*dz
        u, v, w = _fade(xf), _fade(yf), _fade(zf)
        L = lambda t, p0, p1: p0 + t*(p1-p0)
        x1 = L(u, g(P[(aa+zi)&255], xf, yf, zf), g(P[(ba+zi)&255], xf-1, yf, zf))
        x2 = L(u, g(P[(ab+zi)&255], xf, yf-1, zf), g(P[(bb+zi)&255], xf-1, yf-1, zf))
        y1 = L(v, x1, x2)
        x1 = L(u, g(P[(aa+zi+1)&255], xf, yf, zf-1), g(P[(ba+zi+1)&255], xf-1, yf, zf-1))
        x2 = L(u, g(P[(ab+zi+1)&255], xf, yf-1, zf-1), g(P[(bb+zi+1)&255], xf-1, yf-1, zf-1))
        y2 = L(v, x1, x2)
        return L(w, y1, y2)
class Perlin:
    def __init__(s, rng, first, amps):
        s.first, s.amps = first, amps; s.oct = [Improved(rng) if a else None for a in amps]
    def __call__(s, x, z):
        n = len(s.amps); lf = 2.0**s.first; vf = 2.0**(n-1)/(2.0**n-1); tot = 0
        for o, a in zip(s.oct, s.amps):
            if a: tot = tot + a*vf*o(x*lf, z*lf)
            lf *= 2; vf /= 2
        return tot
class Normal:
    """NormalNoise(first, amps) sampled at (x*xz, z*xz)."""
    def __init__(s, rng, first, amps, xz=1.0):
        s.a = Perlin(rng, first, amps); s.b = Perlin(rng, first, amps); s.xz = xz
        idx = [i for i, a in enumerate(amps) if a]; span = max(idx)-min(idx)
        s.vf = (1/6)/(0.1*(1+1/(span+1)))
    def __call__(s, x, z):
        x = x*s.xz; z = z*s.xz; f = 1.0181268882175227
        return (s.a(x, z) + s.b(x*f, z*f))*s.vf

def spline(points, x):
    """Minecraft cubic spline: points (loc, value, derivative); linear extrapolation with end derivatives."""
    xs = np.array([p[0] for p in points]); ys = np.array([p[1] for p in points]); ds = np.array([p[2] for p in points])
    x = np.asarray(x, float)
    i = np.clip(np.searchsorted(xs, x) - 1, 0, len(xs)-2)
    x0, x1, y0, y1, d0, d1 = xs[i], xs[i+1], ys[i], ys[i+1], ds[i], ds[i+1]
    t = (x - x0)/(x1 - x0)
    a = d0*(x1-x0) - (y1-y0); b = -d1*(x1-x0) + (y1-y0)
    inside = y0 + t*(y1-y0) + t*(1-t)*(a + t*(b-a))
    out = np.where(x < xs[0], ys[0] + ds[0]*(x - xs[0]), np.where(x > xs[-1], ys[-1] + ds[-1]*(x - xs[-1]), inside))
    return out

def monotone(pts):
    """(loc, value) list -> (loc, value, derivative) with Fritsch-Carlson monotone derivatives, 0 at the ends."""
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]; n = len(pts)
    m = [(ys[k+1]-ys[k])/(xs[k+1]-xs[k]) for k in range(n-1)]
    d = [0.0]*n
    for k in range(1, n-1):
        if m[k-1]*m[k] <= 0: d[k] = 0.0
        else:
            w1 = 2*(xs[k+1]-xs[k]) + (xs[k]-xs[k-1]); w2 = (xs[k+1]-xs[k]) + 2*(xs[k]-xs[k-1])
            d[k] = (w1+w2)/(w1/m[k-1] + w2/m[k])
    return [(xs[k], ys[k], d[k]) for k in range(n)]
