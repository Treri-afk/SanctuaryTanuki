"""Pin matsu (pine_tree, 9 m) : tronc tordu penche, nuages de feuillage plats etages. Objets : trunk, foliage, trunk-col."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *

reset_scene()

# ---------------------------------------------------------------- tronc tordu
tb = Builder()
main = [(0.0, 0.0, 0.0), (0.05, 0.0, 0.3), (0.25, 0.05, 1.0), (0.65, 0.10, 1.9), (0.75, 0.2, 2.8), (0.35, 0.28, 3.7),
        (-0.15, 0.18, 4.5), (-0.5, 0.0, 5.4), (-0.45, -0.2, 6.3), (-0.1, -0.22, 7.1), (0.2, -0.1, 7.9), (0.3, 0.0, 8.5)]
rad = [0.62, 0.50, 0.43, 0.38, 0.34, 0.31, 0.29, 0.26, 0.22, 0.17, 0.11, 0.05]
tb.tube(main, rad, sides=9, m="bark_pine")
# branches porteuses (vers le centre de chaque nuage)
br = [
    ([(0.72, 0.18, 2.7), (1.2, 0.0, 3.2), (1.6, -0.25, 3.75), (1.95, -0.4, 4.2)], [0.18, 0.14, 0.10, 0.06]),
    ([(-0.4, 0.05, 5.1), (-0.95, 0.25, 5.6), (-1.5, 0.4, 6.0), (-1.9, 0.5, 6.3)], [0.15, 0.12, 0.08, 0.05]),
    ([(-0.15, -0.2, 6.9), (0.4, -0.45, 7.2), (0.9, -0.6, 7.5), (1.2, -0.7, 7.7)], [0.12, 0.09, 0.07, 0.045]),
    ([(-0.55, 0.0, 3.5), (-1.0, -0.2, 3.9), (-1.4, -0.35, 4.2)], [0.10, 0.07, 0.04]),
]
for pts, rr in br:
    tb.tube(pts, rr, sides=6, m="bark_pine")
roots(tb, 4, 0.5, 0.0, "bark_pine", seed=2, length=0.8, rr=0.2, base=(0.0, 0.0))
ground_clamp(tb)
trunk = tb.build("trunk")

# ---------------------------------------------------------------- nuages plats
fb = Builder()


def cloud(c, R, h, seed, top_light=True, tilt=(0, 0, 0), sd=3, nsat=2):
    cx, cy, cz = c
    blob_rot(fb, c, (R, R * 0.85, h), "pine_green", rot=tilt, subdiv=sd, noise=0.07, seed=seed, bottom=0.35)
    # lobes peripheriques : bord festonne
    for k in range(nsat):
        a = seed + k * 2.2 + 0.4
        blob_rot(fb, (cx + R * 0.72 * math.cos(a), cy + R * 0.6 * math.sin(a), cz - 0.05 * h),
                 (R * 0.42, R * 0.38, h * 0.8), "pine_green", rot=tilt, subdiv=2, noise=0.1, seed=seed + k, bottom=0.35)
    if top_light:
        blob_rot(fb, (cx - 0.1 * R, cy + 0.05 * R, cz + h * 0.55), (R * 0.7, R * 0.55, h * 0.62),
                 "pine_green_light", rot=tilt, subdiv=2, noise=0.1, seed=seed + 9, bottom=0.3)


cloud((2.0, -0.4, 4.5), 1.65, 0.72, 1, tilt=(0.0, 0.05, 0.2))
cloud((-1.9, 0.5, 6.3), 1.5, 0.72, 3, tilt=(0.03, -0.06, 0.5))
cloud((1.2, -0.7, 7.8), 1.3, 0.65, 5, tilt=(0.0, 0.04, -0.3))
cloud((0.2, 0.1, 8.45), 1.0, 0.55, 7, sd=2)
cloud((-1.45, -0.4, 4.25), 0.85, 0.45, 11, top_light=False, sd=2, nsat=2)   # petit nuage bas cote gauche
foliage = fb.build("foliage")

cylinder("trunk-col", 0.45, 3.0, loc=(0.4, 0.08, 1.5), material=None, verts=10, bevel=0).display_type = "WIRE"
finish("pine_tree", expected_dims=(6.0, 3.5, 9.0), tri_limit=(100, 3000),
       angles={"trunk": math.radians(55), "foliage": math.radians(180)}, margin=1.05,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.05)), ("_side", dict(yaw=90, pitch=2, margin=1.05))])
