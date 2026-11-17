"""Terrain parameters of CustomWorldgen-26.3-low (shared by build-pack-low.py and simulate_low.py)."""
RELIEF = (-8, [1, 1, 1])      # hills: octaves of ~256 / 128 / 64 blocks
REGION = (-10, [1, 1])        # lowland / upland regions: ~1000 / 500 blocks
REGION_W = 0.6
# noise value -> height; h in (63, 64] gives top block 63, h in (80, 81] gives 80; flat (derivative 0) at both ends
HEIGHT = [(-0.45, 63.5), (-0.15, 65.5), (0.15, 70.0), (0.45, 76.5), (0.75, 80.5)]
CONT_K, CONT_B, CONT_MIN = 0.45, 0.48, -0.1     # continentalness -> -0.06..1: inland only (coast ends at -0.11)
ERO_K, ERO_B, ERO_MIN = 0.6, 0.4, -0.22         # erosion -> -0.22..1: no peak / slope / plateau biomes
RIDGE_GAP = 0.06                                # |weirdness| >= 0.06: no river / valley biomes
NOISE_TOP = 96                                  # terrain noise is computed for Y -64..96
