"""Souche mousseuse (stump_mossy, 0,7 m). Objets : stump (ecorce + coupe), moss, stump-col."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *

PALETTE["wood_cut"] = "#B88F5E"      # coupe fraiche de la souche
PALETTE["wood_cut_dark"] = "#9A7548"
reset_scene()

N = 18
levels = [(0.0, 0.50), (0.10, 0.42), (0.28, 0.36), (0.48, 0.34)]    # (z, rayon)


def lob(a, z):
    flare = max(0.0, 1.0 - z / 0.35)                      # contreforts forts en bas, s'attenuent vers le haut
    return 1.0 + 0.22 * flare * math.sin(5 * a + 0.6) + 0.06 * math.sin(3 * a + 1.0) + 0.04 * math.sin(7 * a)


def ztop(a):                                              # sommet brise : haut d'un cote, bas de l'autre
    return 0.53 + 0.12 * math.cos(a - 2.3) + 0.04 * math.sin(3 * a + 0.5)


verts, faces_bark, faces_cut, faces_cut2 = [], [], [], []
rings = []
for (z, r) in levels:
    ring = []
    for j in range(N):
        a = 2 * math.pi * j / N
        rr = r * lob(a, z)
        verts.append((rr * math.cos(a), rr * math.sin(a), z))
        ring.append(len(verts) - 1)
    rings.append(ring)
# anneau sommet (bord irregulier)
ring = []
for j in range(N):
    a = 2 * math.pi * j / N
    rr = 0.34 * lob(a, 0.5)
    verts.append((rr * math.cos(a), rr * math.sin(a), ztop(a)))
    ring.append(len(verts) - 1)
rings.append(ring)
for i in range(len(rings) - 1):
    for j in range(N):
        j2 = (j + 1) % N
        faces_bark.append((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
# coupe : bande claire + disque central plus fonce, legerement creux
inner = []
for j in range(N):
    a = 2 * math.pi * j / N
    rr = 0.27
    verts.append((rr * math.cos(a), rr * math.sin(a), ztop(a) - 0.035))
    inner.append(len(verts) - 1)
verts.append((0.0, 0.0, 0.53 - 0.09))
cen = len(verts) - 1
for j in range(N):
    j2 = (j + 1) % N
    faces_cut.append((rings[-1][j], rings[-1][j2], inner[j2], inner[j]))
    faces_cut2.append((inner[j], inner[j2], cen))
verts.append((0.0, 0.0, 0.0))
bot = len(verts) - 1
for j in range(N):
    faces_bark.append((rings[0][(j + 1) % N], rings[0][j], bot))

sb = Builder()
for f, m in ((faces_bark, "bark_cedar"), (faces_cut, "wood_cut"), (faces_cut2, "wood_cut_dark")):
    sb.add(verts, f, m)          # sommets dupliques par groupe : clean() les fusionne
roots(sb, 5, 0.42, 0.0, "bark_cedar", seed=3, length=0.25, rr=0.15, sides=6, taper=(1.0, 0.75, 0.45))
ground_clamp(sb)
sb.build("stump")

# ---------------------------------------------------------------- mousse (objet separe)
mb = Builder()
spots = [   # angle, z, echelle (radial, tangent, vertical), graine
    (-0.9, 0.07, (0.15, 0.34, 0.16), 1), (0.5, 0.08, (0.14, 0.30, 0.15), 2), (2.0, 0.09, (0.15, 0.32, 0.15), 3),
    (3.6, 0.07, (0.15, 0.34, 0.16), 4), (5.1, 0.09, (0.13, 0.28, 0.14), 5),
    (-1.0, 0.27, (0.11, 0.26, 0.19), 6), (0.1, 0.36, (0.10, 0.22, 0.17), 7), (3.9, 0.30, (0.10, 0.25, 0.18), 8),
    (2.6, 0.30, (0.10, 0.28, 0.20), 9),
]
for k, (a, z, sc, sd) in enumerate(spots):
    r = (0.44 if z < 0.15 else 0.36) * lob(a, z) * 0.9
    blob_rot(mb, (r * math.cos(a), r * math.sin(a), z), sc, "moss", rot=(0, 0, a), subdiv=2, noise=0.1, seed=sd, bottom=0.6)
# coussin de mousse sur le bord haut (cote le plus haut, a l'arriere)
for k, a in enumerate([2.0, 2.6, 3.2]):
    r = 0.27
    blob_rot(mb, (r * math.cos(a), r * math.sin(a), ztop(a) - 0.02), (0.18, 0.20, 0.09), "moss", rot=(0, 0, a),
             subdiv=2, noise=0.1, seed=20 + k, bottom=0.5)
ground_clamp(mb)
mb.build("moss")

cylinder("stump-col", 0.4, 0.68, loc=(0, 0, 0.34), material=None, verts=10, bevel=0).display_type = "WIRE"
finish("stump_mossy", expected_dims=(1.1, 1.1, 0.72), tri_limit=(100, 3000),
       angles={"stump": math.radians(55), "moss": math.radians(180)}, margin=1.1, pitch=30,
       extra_views=[("_back", dict(yaw=-130, pitch=25, margin=1.1))])
