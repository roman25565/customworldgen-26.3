"""Worst-case slope bound of the gentle height map (every octave at its steepest at once)."""
import numpy as np, gentle_terrain as T
from mcnoise import spline, monotone
G1 = 3.06   # max |grad| of one ImprovedNoise octave per unit input (sampled 2M points)
V1 = 0.90   # max |value| of one octave
def nb(oct_):
    first, amps, xz = oct_; n = len(amps); idx = [i for i, a in enumerate(amps) if a]; span = idx[-1]-idx[0]
    vfn = (1/6)/(0.1*(1+1/(span+1))); vf0 = 2.0**(n-1)/(2.0**n-1)
    g = sum(a*vf0*0.5**i * 2.0**(first+i) for i, a in enumerate(amps)) * xz * G1 * (1 + 1.0181268882175227) * vfn
    v = sum(a*vf0*0.5**i for i, a in enumerate(amps)) * V1 * 2 * vfn
    return g, v
def dmax(pts):
    sp = monotone(pts); x = np.linspace(pts[0][0], pts[-1][0], 200001); y = spline(sp, x); return np.abs(np.diff(y)/np.diff(x)).max(), np.abs(y).max()
gc, _ = nb(T.CONTINENTALNESS); ge, _ = nb(T.EROSION); gw, _ = nb(T.RIDGE); gh, vh = nb(T.HILL); g1, _ = nb(T.PEAK1); g2, _ = nb(T.PEAK2)
db, _ = dmax(T.BASE); dha, ha = dmax(T.HILL_AMP); d1, _ = dmax(T.PEAK_S1); d2, _ = dmax(T.PEAK_S2); do, _ = dmax(T.MOUNT_OFF); df_, _ = dmax(T.FOOT)
Lbase = db*gc; Lhills = dha*ge*(vh+T.HILL_BIAS) + ha*gh; Lm = d1*g1 + d2*g2 + (do + df_)*ge; Lramp = T.COAST_K*gc
Lland = Lbase + max(Lhills + Lm, Lramp); Lriver = T.RIVER_S*gw
print(f'noise grad bounds per block: c {gc:.2e} e {ge:.2e} w {gw:.2e} hill {gh:.2e} peaks {g1:.2e} {g2:.2e}')
print(f'base {Lbase:.3f} hills {Lhills:.3f} mountains {Lm:.3f} coast ramp {Lramp:.3f} river {Lriver:.3f}')
print(f'worst case |grad h| <= {max(Lland, Lriver):.3f}')
