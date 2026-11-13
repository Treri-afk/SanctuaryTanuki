"""Erables d'automne : maple_small (5 m, couronne ronde) et maple_red (6 m, couronne haute et etroite).
Objets : trunk, foliage, trunk-col."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *


def foliage_blobs(fb, big, small, sd1=3, sd2=2, n_hi=99):
    for n, (c, s_, m, sd) in enumerate(big):
        fb.blob(c, s_, m, subdiv=sd1 if n < n_hi else 2, noise=0.07, seed=sd, bottom=0.8)
    for c, s_, m, sd in small:
        fb.blob(c, s_, m, subdiv=sd2, noise=0.09, seed=sd, bottom=0.8)


# ================================================================ maple_small
reset_scene()
tb = Builder()
main = [(0.0, 0.0, 0.0), (0.0, 0.0, 0.12), (0.03, 0.0, 0.3), (0.06, 0.02, 0.7), (0.10, 0.04, 1.2), (0.03, 0.08, 1.7),
        (-0.05, 0.06, 2.2), (-0.08, 0.0, 2.6), (-0.1, -0.1, 3.0)]
tb.tube(main, [0.46, 0.40, 0.31, 0.26, 0.23, 0.2, 0.18, 0.16, 0.12], sides=9, m="bark_cedar")
for pts, rr in [
    ([(-0.06, 0.05, 2.2), (-0.5, 0.15, 2.7), (-0.95, 0.2, 3.2), (-1.3, 0.2, 3.55)], [0.12, 0.10, 0.07, 0.04]),
    ([(-0.04, 0.06, 2.1), (0.4, -0.05, 2.65), (0.85, -0.12, 3.15), (1.25, -0.15, 3.5)], [0.12, 0.10, 0.07, 0.04]),
    ([(-0.08, 0.02, 2.6), (0.0, 0.45, 3.1), (0.12, 0.8, 3.5)], [0.10, 0.07, 0.04]),
    ([(-0.1, -0.08, 2.9), (-0.2, -0.45, 3.4), (-0.25, -0.75, 3.75)], [0.09, 0.065, 0.04]),
]:
    tb.tube(pts, rr, sides=6, m="bark_cedar")
roots(tb, 4, 0.34, 0.0, "bark_cedar", seed=5, length=0.75, rr=0.17)
tb.blob((0.3, -0.25, 0.14), (0.14, 0.11, 0.06), "moss", subdiv=1, noise=0.12, seed=3, bottom=0.4)
ground_clamp(tb)
tb.build("trunk")
fb = Builder()
big = [
    ((0.0, 0.05, 3.85), (1.55, 1.45, 1.1), "foliage_orange", 1),
    ((-1.45, 0.25, 3.35), (1.05, 1.0, 0.88), "foliage_red", 2),
    ((1.4, -0.15, 3.3), (1.1, 1.05, 0.88), "foliage_orange", 3),
    ((0.2, 1.3, 3.25), (1.0, 0.95, 0.82), "foliage_red", 4),
    ((-0.3, -1.3, 3.35), (1.0, 0.95, 0.82), "foliage_deep", 5),
]
small = [
    ((0.1, 0.15, 4.55), (0.85, 0.8, 0.5), "foliage_light", 11),
    ((-0.85, -0.5, 4.2), (0.65, 0.6, 0.42), "foliage_light", 12),
    ((0.95, 0.6, 4.05), (0.65, 0.6, 0.42), "foliage_red", 13),
]
foliage_blobs(fb, big, small)
fb.build("foliage")
cylinder("trunk-col", 0.32, 2.4, loc=(0.03, 0.03, 1.2), material=None, verts=10, bevel=0).display_type = "WIRE"
finish("maple_small", expected_dims=(4.4, 4.4, 5.0), tri_limit=(100, 2500),
       angles={"trunk": math.radians(55), "foliage": math.radians(180)}, margin=1.1,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.1))])

# ================================================================ maple_red
reset_scene()
tb = Builder()
main = [(0.0, 0.0, 0.0), (0.0, 0.0, 0.12), (0.03, 0.0, 0.3), (0.05, 0.03, 0.8), (0.0, 0.07, 1.4), (-0.06, 0.05, 2.0),
        (-0.05, 0.0, 2.6), (0.0, -0.03, 3.2)]
tb.tube(main, [0.38, 0.33, 0.26, 0.22, 0.19, 0.17, 0.15, 0.11], sides=9, m="bark_cedar")
for pts, rr in [
    ([(-0.06, 0.05, 2.0), (-0.35, 0.15, 2.6), (-0.65, 0.2, 3.3), (-0.8, 0.2, 3.9)], [0.12, 0.10, 0.07, 0.04]),
    ([(-0.05, 0.03, 2.1), (0.3, -0.08, 2.7), (0.6, -0.12, 3.4), (0.75, -0.12, 4.0)], [0.12, 0.10, 0.07, 0.04]),
    ([(0.0, -0.02, 3.0), (0.05, 0.1, 3.9), (0.0, 0.1, 4.7), (-0.05, 0.05, 5.2)], [0.11, 0.08, 0.055, 0.03]),
]:
    tb.tube(pts, rr, sides=6, m="bark_cedar")
roots(tb, 4, 0.3, 0.0, "bark_cedar", seed=9, length=0.65, rr=0.15)
tb.blob((-0.3, -0.25, 0.12), (0.13, 0.10, 0.06), "moss", subdiv=1, noise=0.12, seed=7, bottom=0.4)
ground_clamp(tb)
tb.build("trunk")
fb = Builder()
big = [
    ((0.0, 0.0, 3.5), (1.2, 1.15, 0.95), "foliage_deep", 1),
    ((-0.8, 0.2, 3.0), (0.85, 0.8, 0.75), "foliage_red", 2),
    ((0.8, -0.25, 3.05), (0.85, 0.8, 0.75), "foliage_deep", 3),
    ((0.05, 0.0, 4.6), (1.15, 1.05, 1.05), "foliage_red", 4),
    ((0.0, 0.05, 5.4), (0.78, 0.72, 0.62), "foliage_red", 5),
]
small = [
    ((0.55, -0.7, 4.1), (0.75, 0.65, 0.6), "foliage_orange", 11),
    ((-0.45, -0.6, 4.95), (0.7, 0.62, 0.55), "foliage_orange", 12),
    ((0.5, 0.25, 5.2), (0.65, 0.6, 0.5), "foliage_light", 13),
    ((-0.55, 0.55, 3.9), (0.6, 0.55, 0.5), "foliage_deep", 14),
    ((0.25, -0.95, 3.0), (0.55, 0.5, 0.4), "foliage_deep", 15),
    ((-0.2, 0.9, 5.0), (0.55, 0.5, 0.45), "foliage_deep", 16),
    ((-0.25, -0.4, 5.75), (0.5, 0.47, 0.4), "foliage_light", 17),
]
foliage_blobs(fb, big, small, n_hi=4)
fb.build("foliage")
cylinder("trunk-col", 0.3, 2.4, loc=(0.03, 0.03, 1.2), material=None, verts=10, bevel=0).display_type = "WIRE"
finish("maple_red", expected_dims=(3.0, 3.0, 6.0), tri_limit=(100, 2500),
       angles={"trunk": math.radians(55), "foliage": math.radians(180)}, margin=1.1,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.1))])
