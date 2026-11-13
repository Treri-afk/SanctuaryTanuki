"""Renard de pierre (kitsune) assis, 0,8 m : oreilles dressees, queue enroulee, bavoir rouge, socle, mousse. Avant = -Y.
Lancer : blender --background --python tools/blender/fox_statue.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

reset_scene()
S, SD = "stone", "stone_dark"
Z0 = 0.24                   # dessus du socle

# ---------------------------------------------------------------- socle (2 etages, de travers)
lo = box("base_low", (0.84, 0.56, 0.12), (0, 0, 0.06), SD, bevel=0.035)
hi = box("base_high", (0.74, 0.48, 0.13), (0, 0, 0.175), S, bevel=0.03)
for o, sd in ((lo, 3), (hi, 5)):
    jitter(o, 0.006, sd)
hi.rotation_euler = (0, 0, math.radians(-3))
lo.rotation_euler = (math.radians(0.6), 0, math.radians(2))

# ---------------------------------------------------------------- renard
f = Mesh()
N = 20
# torse : revolution, elargi aux hanches, affine au cou ; un peu plus profond vers l'arriere
bprof = [(0.160, Z0 - 0.01), (0.185, Z0 + 0.04), (0.176, Z0 + 0.12), (0.152, Z0 + 0.22), (0.126, Z0 + 0.31),
         (0.112, Z0 + 0.37), (0.106, Z0 + 0.40)]
f.lathe(bprof, N, S, center=(0, 0.0), scale=(1.0, 0.88))
# hanches / cuisses repliees
for sx in (-1, 1):
    f.blob((sx * 0.115, 0.045, Z0 + 0.10), (0.092, 0.16, 0.11), S, subdiv=2, noise=0.04, seed=sx + 3)
f.blob((0, 0.09, Z0 + 0.115), (0.13, 0.12, 0.115), S, subdiv=2, noise=0.04, seed=9)
# pattes avant droites (tubes legerement coniques) + pieds
for sx in (-1, 1):
    pts = [(sx * 0.072, -0.060, Z0 + 0.33), (sx * 0.078, -0.100, Z0 + 0.20), (sx * 0.080, -0.125, Z0 + 0.06),
           (sx * 0.082, -0.130, Z0 + 0.012)]
    f.tube(pts, [0.056, 0.048, 0.046, 0.046], 10, S, squash=0.9)
    f.blob((sx * 0.082, -0.158, Z0 + 0.020), (0.050, 0.070, 0.032), S, subdiv=2, noise=0.03, seed=sx + 20)
# tete
HC = (0.0, -0.045, Z0 + 0.425)
f.blob(HC, (0.116, 0.104, 0.092), S, subdiv=2, noise=0.03, seed=30)
# museau : tube conique legerement releve
f.tube([(0.0, -0.105, Z0 + 0.405), (0.0, -0.170, Z0 + 0.396), (0.0, -0.232, Z0 + 0.386)],
       [0.060, 0.045, 0.028], 10, S, squash=0.80, ref=(0, 0, 1))
f.blob((0.0, -0.240, Z0 + 0.389), (0.026, 0.024, 0.019), SD, subdiv=1, noise=0.0)
# joues (touffes)
for sx in (-1, 1):
    f.blob((sx * 0.104, -0.045, Z0 + 0.385), (0.036, 0.062, 0.045), S, subdiv=1, noise=0.0,
           quat=Quaternion((0, 0, 1), sx * 0.5))
# oreilles dressees, un peu ecartees
for sx in (-1, 1):
    pts = [(sx * 0.066, -0.020, Z0 + 0.455), (sx * 0.080, -0.010, Z0 + 0.515), (sx * 0.092, -0.002, Z0 + 0.562)]
    f.tube(pts, [0.046, 0.032, 0.004], 8, S, squash=0.42, ref=(1, 0, 0))
    pin = [(sx * 0.066, -0.043, Z0 + 0.468), (sx * 0.078, -0.036, Z0 + 0.515), (sx * 0.086, -0.032, Z0 + 0.540)]
    f.tube(pin, [0.026, 0.016, 0.003], 6, SD, squash=0.30, ref=(1, 0, 0))
# yeux en amande, obliques
for sx in (-1, 1):
    f.blob((sx * 0.050, -0.140, Z0 + 0.445), (0.025, 0.008, 0.009), SD, subdiv=1, noise=0.0,
           quat=Quaternion((0, 1, 0), sx * 0.42))
# queue enroulee autour du flanc droit, posee sur le socle
tail = catmull([(0.04, 0.12, Z0 + 0.075), (0.14, 0.16, Z0 + 0.085), (0.23, 0.12, Z0 + 0.10), (0.27, 0.02, Z0 + 0.12),
                (0.25, -0.08, Z0 + 0.15), (0.20, -0.14, Z0 + 0.20), (0.17, -0.14, Z0 + 0.28)], 5)
radii = []
nt = len(tail)
for i in range(nt):
    t = i / (nt - 1)
    radii.append(0.050 + 0.052 * math.sin(math.pi * min(t * 1.1, 1.0)) ** 0.9 - (0.050 * max(0, t - 0.75) / 0.25))
f.tube(tail, radii, 10, S, squash=0.92)
body = f.build("fox_body")

# ---------------------------------------------------------------- bavoir rouge (collerette + pan sur la poitrine)
r = Mesh()
r.lathe([(0.126, Z0 + 0.31), (0.150, Z0 + 0.322), (0.152, Z0 + 0.352), (0.128, Z0 + 0.378)], N, "lacquer_red",
        scale=(1.0, 0.88))
levels = [(Z0 + 0.325, 52), (Z0 + 0.28, 46), (Z0 + 0.23, 36), (Z0 + 0.19, 22), (Z0 + 0.165, 8)]
K = 7
panel = []
for z, th in levels:
    rb = lerp_poly(bprof, z)
    pts = []
    for k in range(K):
        a = math.radians(-90 - th + 2 * th * k / (K - 1))
        pts.append((math.cos(a) * (rb + 0.016), math.sin(a) * (rb + 0.016) * 0.88, z))
    for k in reversed(range(K)):
        a = math.radians(-90 - th + 2 * th * k / (K - 1))
        pts.append((math.cos(a) * (rb - 0.004), math.sin(a) * (rb - 0.004) * 0.88, z))
    panel.append(pts)
r.loft(panel, "lacquer_red", cap0=True, cap1=True)
cloth = r.build("red_cloth")

# ---------------------------------------------------------------- mousse
m = Mesh()
moss_blobs(m, [(-0.27, -0.19, 0.125, 0.09, 0.07, 0.04, 0.4), (0.30, -0.15, 0.125, 0.07, 0.08, 0.035, -0.3),
               (-0.12, 0.20, 0.125, 0.10, 0.06, 0.035, 0.1), (0.36, 0.12, 0.04, 0.05, 0.09, 0.05, 0.0),
               (-0.30, 0.10, 0.06, 0.05, 0.10, 0.05, 0.0), (0.0, -0.28, 0.01, 0.12, 0.06, 0.05, 0.1),
               (-0.18, -0.08, Z0 - 0.005, 0.07, 0.07, 0.03, 0.8), (0.20, 0.18, Z0 + 0.14, 0.05, 0.05, 0.025, 0.2),
               (-0.10, 0.12, Z0 + 0.20, 0.06, 0.04, 0.025, 0.4)], 21)
moss = m.build("moss_patches")

parts = [lo, hi, body, cloth, moss]
tri_report(parts)
fox = join(parts, "fox_statue")
apply_rot(fox, (0.6, -0.8, 3.0))
collision_box("fox_statue", (0.84, 0.56, 0.8), (0, 0, 0.4))

tfinish("fox_statue", expected_dims=(0.76, 0.54, 0.80), tri_limit=(300, 3500), yaw=28, pitch=14, margin=1.1,
        angles={"fox_statue": math.radians(45)},
        extra_views=[("_b", dict(yaw=-50, pitch=12, margin=1.1)), ("_c", dict(yaw=0, pitch=8, margin=1.1))])
