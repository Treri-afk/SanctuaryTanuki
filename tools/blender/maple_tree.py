"""Erable japonais (momiji) d'automne, ~7,5 m. Objets separes : trunk, foliage, trunk-col (collision tronc seul)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from veg_utils import *

# teintes supplementaires locales (palette de common.py intacte sur disque)
PALETTE["foliage_light"] = "#E8AA3E"
PALETTE["foliage_deep"] = "#9E3524"

reset_scene()
V = Vector

# ---------------------------------------------------------------- tronc
tb = Builder()
main = [(0.0, 0.0, 0.0), (0.0, 0.0, 0.15), (0.04, 0.0, 0.32), (0.06, 0.02, 0.6), (0.12, 0.05, 1.2), (0.05, 0.12, 2.0),
        (-0.08, 0.10, 2.8), (-0.10, 0.0, 3.4), (-0.15, -0.25, 4.2), (-0.2, -0.6, 5.2), (-0.1, -0.9, 6.2)]
main_r = [0.80, 0.74, 0.60, 0.50, 0.43, 0.38, 0.35, 0.32, 0.25, 0.16, 0.09]
tb.tube(main, main_r, sides=11, m="wood_dark")

branches = [
    ([(-0.08, 0.06, 3.0), (-0.5, 0.2, 3.8), (-1.1, 0.35, 4.7), (-1.65, 0.3, 5.5)], [0.20, 0.17, 0.12, 0.07]),
    ([(-0.05, 0.08, 2.9), (0.45, -0.05, 3.7), (1.0, -0.15, 4.5), (1.75, -0.25, 5.3)], [0.20, 0.16, 0.11, 0.065]),
    ([(-0.10, 0.02, 3.5), (0.0, 0.5, 4.3), (0.2, 1.0, 5.1), (0.35, 1.5, 5.9)], [0.17, 0.13, 0.09, 0.06]),
    # ramilles
    ([(-1.1, 0.35, 4.7), (-2.0, 0.2, 5.0), (-2.8, 0.15, 5.4)], [0.08, 0.05, 0.03]),
    ([(1.0, -0.15, 4.5), (2.0, 0.0, 4.9), (2.75, 0.1, 5.3)], [0.08, 0.05, 0.03]),
    ([(-0.2, -0.6, 5.2), (0.7, -1.1, 5.4), (1.3, -1.4, 5.8)], [0.07, 0.045, 0.028]),
    ([(0.2, 1.0, 5.1), (-0.6, 1.6, 5.4), (-1.2, 1.9, 5.8)], [0.07, 0.045, 0.028]),
]
for pts, rr in branches:
    tb.tube(pts, [r * 1.2 for r in rr], sides=7, m="wood_dark")

# racines apparentes
for k in range(6):
    a = 2 * math.pi * k / 6 + 0.35 + 0.25 * math.sin(k * 2.3)
    L = 1.15 + 0.35 * math.sin(k * 1.7 + 1.0)
    ca, sa = math.cos(a), math.sin(a)
    pts = [(0.45 * ca, 0.45 * sa, 0.62), (0.75 * ca, 0.75 * sa, 0.33),
           (0.5 * (0.75 + L) * ca + 0.08 * sa, 0.5 * (0.75 + L) * sa - 0.08 * ca, 0.13),
           (0.93 * L * ca, 0.93 * L * sa, 0.075), (L * ca, L * sa, 0.055)]
    tb.tube(pts, [0.24, 0.20, 0.13, 0.07, 0.045], sides=7, m="wood_dark")

# placages de mousse sur la base (usure/age)
tb.blob((0.52, -0.28, 0.22), (0.16, 0.13, 0.07), "moss", subdiv=1, noise=0.12, seed=3, bottom=0.4)
tb.blob((-0.36, -0.46, 0.20), (0.14, 0.12, 0.06), "moss", subdiv=1, noise=0.12, seed=7, bottom=0.4)
tb.blob((-0.5, 0.35, 0.30), (0.12, 0.10, 0.06), "moss", subdiv=1, noise=0.12, seed=9, bottom=0.4)
trunk = tb.build("trunk")

# ---------------------------------------------------------------- feuillage
fb = Builder()
big = [  # centre, rayons, materiau, graine
    ((0.0, 0.1, 6.15), (1.8, 1.7, 1.35), "foliage_orange", 1),
    ((-1.95, 0.3, 5.4), (1.55, 1.45, 1.25), "foliage_red", 2),
    ((1.95, -0.2, 5.3), (1.6, 1.5, 1.25), "foliage_orange", 3),
    ((0.2, 1.65, 5.1), (1.45, 1.35, 1.15), "foliage_red", 4),
    ((-0.4, -1.65, 5.3), (1.45, 1.35, 1.2), "foliage_orange", 5),
    ((2.9, 0.5, 4.55), (1.05, 1.0, 0.95), "foliage_red", 6),
    ((-2.85, -0.3, 4.45), (1.1, 1.0, 0.95), "foliage_deep", 7),
    ((0.3, 0.1, 4.85), (1.5, 1.4, 1.0), "foliage_red", 8),
]
for c, s_, m, sd in big:
    fb.blob(c, s_, m, subdiv=3, noise=0.07, seed=sd, bottom=0.8)
small = [
    ((0.1, 0.3, 6.95), (0.95, 0.85, 0.6), "foliage_light", 11),
    ((-1.4, -0.4, 6.55), (0.85, 0.8, 0.55), "foliage_light", 12),
    ((1.5, 0.5, 6.4), (0.8, 0.75, 0.55), "foliage_light", 13),
    ((-2.4, 1.0, 6.0), (0.8, 0.75, 0.5), "foliage_orange", 14),
    ((2.5, -1.0, 5.9), (0.75, 0.7, 0.5), "foliage_light", 15),
    ((1.0, 2.1, 5.9), (0.8, 0.7, 0.5), "foliage_orange", 16),
    ((-1.3, -2.1, 5.8), (0.8, 0.7, 0.5), "foliage_light", 17),
    ((1.5, -2.0, 5.0), (0.75, 0.7, 0.5), "foliage_deep", 18),
    ((-1.7, 2.0, 4.9), (0.75, 0.7, 0.5), "foliage_deep", 19),
]
for c, s_, m, sd in small:
    fb.blob(c, s_, m, subdiv=2, noise=0.09, seed=sd, bottom=0.8)
foliage = fb.build("foliage")

# collision : tronc seulement (cylindre simple)
col = cylinder("trunk-col", 0.40, 3.0, loc=(0.05, 0.05, 1.5), material=None, verts=12, bevel=0)
col.display_type = "WIRE"

finish("maple_tree", expected_dims=(6.5, 6.5, 7.5), tri_limit=(500, 5000),
       angles={"trunk": math.radians(55), "foliage": math.radians(180)}, margin=1.1,
       extra_views=[("_b", dict(yaw=-130, pitch=2, margin=1.1))])
