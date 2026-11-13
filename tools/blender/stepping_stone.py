"""Pierre plate de gue (0,55 x 0,45 x 0,25 m) : bords arrondis, dessus legerement penche, mousse sur un cote.
Origine au sol, centree. Collision boite.
Lancer : blender --background --python tools/blender/stepping_stone.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *

reset_scene()
rng = random.Random(33)
M = Mesh()

RX, RY = 0.262, 0.215
N = 13
# (hauteur, echelle du contour) : pied enterre -> flanc -> epaule arrondie -> dessus plat
sections = [(0.0, 0.90), (0.045, 1.0), (0.17, 0.985), (0.223, 0.93), (0.2495, 0.80)]
amp = [0.05, 0.07, 0.07, 0.05, 0.04]
phase = [rng.uniform(0, 6.28) for _ in range(N)]
base_wob = [rng.uniform(-1, 1) for _ in range(N)]
rings = []
for si, (z, k) in enumerate(sections):
    ring = []
    for j in range(N):
        a = 2 * math.pi * (j + 0.35 * math.sin(phase[j])) / N
        ca, sa = math.cos(a), math.sin(a)
        e = 2.7
        s = (abs(ca) ** e + abs(sa) ** e) ** (-1.0 / e)
        rr = k * (1.0 + amp[si] * base_wob[j] + 0.04 * math.sin(2 * a + 0.8))
        zz = z + (0.014 * math.cos(a - 0.6) * (z / 0.25) if si > 3 else 0.0)
        ring.append((RX * ca * s * rr, RY * sa * s * rr, zz))
    rings.append(ring)
f0 = len(M.f)
M.loft(rings, "stone", cap0=True, cap1=True)


def pred(c):
    x, y, z = c
    if z > 0.2 and ((x * 0.8 - y * 0.6 < -0.1) or (y < -0.1 and x < 0.05)):                 # dessus, cote -X / +Y
        return "moss"
    if z < 0.03:
        return "stone_dark"
    return None


recolor(M, f0, pred)
M.blob((-0.12, -0.105, 0.236), (0.09, 0.06, 0.026), "moss", subdiv=1, noise=0.12, seed=3)
M.blob((0.06, 0.165, 0.222), (0.075, 0.045, 0.025), "moss", subdiv=1, noise=0.12, seed=5)
M.blob((-0.05, -0.2, 0.045), (0.09, 0.05, 0.04), "moss", subdiv=1, noise=0.12, seed=7)
M.blob((0.2, -0.12, 0.04), (0.05, 0.06, 0.035), "moss", subdiv=1, noise=0.12, seed=9)
stone = M.build("stepping_stone")

collision_box("stepping_stone", (0.55, 0.45, 0.25), (0, 0, 0.125))

pfinish("stepping_stone", expected_dims=(0.55, 0.45, 0.25), tri_limit=(100, 800),
        angles={"stepping_stone": math.radians(40)}, yaw=30, pitch=28, margin=1.0,
        extra_views=[("_b", dict(yaw=-140, pitch=20, margin=1.0))])
