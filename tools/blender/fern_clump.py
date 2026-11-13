"""Touffe de fougeres / herbes hautes : 0.6 m, lames evasees en 2 verts. Pas de collision."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
rnd = random.Random(12)
m = Mesh()
NB = 14
for k in range(NB):
    az = 2 * math.pi * k / NB + rnd.uniform(-0.25, 0.25)
    inner = k % 3 == 0
    H = rnd.uniform(0.50, 0.62) if inner else rnd.uniform(0.62, 0.78)
    out = rnd.uniform(0.14, 0.24) if inner else rnd.uniform(0.26, 0.38)   # portee horizontale
    base_r = rnd.uniform(0.015, 0.04)
    wmax = rnd.uniform(0.05, 0.07)
    col = "fern_dark" if (inner or rnd.random() < 0.3) else "fern_green"
    dx, dy = math.cos(az), math.sin(az)
    pts = []
    P = 6
    for i in range(P):
        t = i / (P - 1)
        d = base_r + out * (t ** 1.7)
        z = H * (1 - (1 - t) ** 0 * 0) * math.sin(min(t * 1.25, 1.0) * math.pi / 2) ** 1.0 - 0.0
        z = H * (t ** 0.8) * (1.0 - 0.22 * t * (out / 0.3))     # monte puis retombe
        pts.append((dx * d, dy * d, z))
    def sec(i, a, wmax=wmax, P=P):
        t = i / (P - 1)
        w = wmax * math.sin(math.pi * min(t * 1.0 + 0.12, 1.0)) ** 0.8 * (1 - 0.15 * t) if t < 1 else 0.0
        w = max(w, 0.004) if t < 1 else 0.0
        th = 0.004 if t < 1 else 0.0
        return (w * math.cos(a), th * math.sin(a) * 1.0)
    m.sweep(pts, sec, 4, col, caps=False, ref=(-dy, dx, 0))
m.build("fern_blades")
pfinish("fern_clump", expected_dims=(0.7, 0.7, 0.6), tri_limit=(20, 600), angles={"fern_blades": math.radians(60)},
        yaw=30, pitch=25, margin=1.05)
