"""Terrain definition of CustomWorldgen-26.3-gentle, shared by the pack builder and the slope check.

Height map h(x, z), built only from add / min / max / splines of 2D noises, so its steepest slope is bounded:
  land = base(c) + min(hills + mountains + micro, COAST_K * max(0, c - COAST_C))         coast ramp caps the relief
  h = min(land, max(RIVER_Y + RIVER_S * max(0, |w| - RIVER_W0), land - RIVER_DEPTH))   V-shaped river valleys, then TOP
  micro     = MICRO_AMP(e) * n_micro                small bumps, rocky in the mountains
  hills     = HILL_AMP(e) * (n_hill + HILL_BIAS)    hills, ~130 blocks wide, smaller in the mountains
  mountains = max(0, PEAK_S1(1 - |n_peak1|) + PEAK_S2(1 - |n_peak2|) + MOUNT_OFF(e)) + FOOT(e)
              ridged peaks and crests (~1700 and ~900 blocks apart), up to Y ~315,
              gentle low slopes and steep knife-edge tops (up to ~80 degrees) that rise out of the ground where erosion is low;
              between them flat green valleys at the foothill level
"""
# noises: (base octave, amplitudes, xz scale)
CONTINENTALNESS = (-12, [1, 1, 2, 2, 2], 0.25)   # vanilla is -9: x8 bigger
EROSION = (-12, [1, 1, 1, 0.5, 0.5], 0.25)       # vanilla is -9: x8
RIDGE = (-10, [1, 2, 1], 0.25)                   # weirdness, vanilla -7: x8 (rivers and biome variants)
HILL = (-7, [1], 1.0)                            # hills: one octave, ~130 blocks (steep but walkable)
PEAK1 = (-10, [1], 0.6)                          # main crests ~1700 blocks apart
PEAK2 = (-9, [1], 0.55)                          # side crests ~900 blocks apart
MICRO = (-5, [1, 1], 1.0)                        # micro chaos: bumps ~32 / 16 blocks
EROSION_SHIFT = -0.1

# (location, value) points; derivatives are filled in (monotone) by the builder
BASE = [(-1.2, 8.0), (-0.75, 8.0), (-0.455, 30.0), (-0.3, 50.0), (-0.19, 61.5), (-0.15, 63.5), (-0.11, 64.5), (0.03, 66.5), (0.3, 68.0), (1.2, 72.0)]
HILL_AMP = [(-1.2, 8.0), (-0.5, 10.0), (-0.3, 35.0), (1.2, 35.0)]   # erosion -> hill size (small in the mountains)
PEAK_S1 = [(0.3, 0.0), (0.75, 75.0), (0.96, 130.0), (1.0, 230.0)]     # 1 - |noise| -> peak height
PEAK_S2 = [(0.6, 0.0), (0.95, 12.0), (1.0, 45.0)]   # knife-edge tops: walls up to ~75-80 degrees near the crests
MOUNT_OFF = [(-1.2, 10.0), (-0.65, 0.0), (-0.45, -45.0), (-0.3, -275.0), (1.2, -275.0)]   # erosion -> peaks rise / sink
MICRO_AMP = [(-1.2, 6.0), (-0.5, 5.0), (-0.3, 1.2), (1.2, 1.2)]   # erosion -> micro bump size (rocky in the mountains)
FOOT = [(-1.2, 20.0), (-0.5, 20.0), (-0.3, 0.0), (1.2, 0.0)]   # erosion -> foothill level (valley floors in the mountains)
HILL_BIAS = 0.25      # hills = HILL_AMP(e) * (n_hill + HILL_BIAS): mostly up, few dry-land dips below sea level
COAST_C = -0.15        # relief starts here (c of the shore)
COAST_K = 320.0        # blocks of relief allowed per unit of c inland
RIVER_Y = 59.0
RIVER_W0 = 0.025
RIVER_S = 160.0
TOP = [(280.0, 280.0, 1.0), (400.0, 316.0, 0.0)]   # final height above 280 is squeezed under the world top (Y 319)
RIVER_DEPTH = 24.0     # a river valley is at most this deep: rivers fill with water only in low land
