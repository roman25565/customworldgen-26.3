# Shared terrain definition for the "simple" pack: used by the pack generator and by the slope simulation.
import numpy as np, math

# (continentalness, height) : coast to deep ocean to inland plains
C_POINTS = [(-1.2, 6.0), (-0.70, 6.0), (-0.455, 26.0), (-0.19, 50.0), (-0.12, 62.0), (-0.06, 65.5), (0.03, 67.0), (1.2, 69.0)]
# erosion -> mountain height added on top (only inland)
M_POINTS = [(-1.2, 170.0), (-0.85, 170.0), (-0.6, 120.0), (-0.4, 40.0), (-0.28, 0.0), (1.2, 0.0)]
# continentalness -> how much of the mountain is allowed
G_POINTS = [(-0.05, 0.0), (0.2, 1.0)]
RIVER_Y = 59.0
RIVER_W = [(0.04, 1.0), (0.14, 0.0)]       # |ridges| -> river strength
RIVER_H = [(72.0, 1.0), (84.0, 0.0)]       # raw terrain height -> river allowed
DETAIL_AMP = 0.5
# mountains also get ridges and valleys: erosion -> how much of the peak noise is used, and its size in blocks
PW_POINTS = [(-0.6, 1.0), (-0.3, 0.0)]
PEAK_AMP = 55.0

def hermite(points, x):
    """Cubic Hermite spline with zero derivatives (what a Minecraft spline with derivative 0 gives)."""
    xs = np.array([p[0] for p in points]); ys = np.array([p[1] for p in points])
    x = np.clip(x, xs[0], xs[-1])
    i = np.clip(np.searchsorted(xs, x) - 1, 0, len(xs) - 2)
    t = (x - xs[i]) / (xs[i + 1] - xs[i])
    s = t * t * (3 - 2 * t)
    return ys[i] + (ys[i + 1] - ys[i]) * s

def terrain(c, e, w, detail, peaks):
    raw = (hermite(C_POINTS, c) + hermite(M_POINTS, e) * hermite(G_POINTS, c) + detail * DETAIL_AMP
           + hermite(PW_POINTS, e) * hermite(G_POINTS, c) * peaks * PEAK_AMP)
    rf = hermite(RIVER_W, np.abs(w)) * hermite(RIVER_H, raw)
    return raw + (np.minimum(raw, RIVER_Y) - raw) * rf
