"""Tas de buches empilees sous un petit auvent adosse (1,4 x 0,7 x 1,0 m). Les buches (axe Y) montrent leur bout rond
de face (-Y). Auvent en planchettes (bardeaux) incline vers l'avant, fond de planches au dos, poteaux et traverses.
Lancer : blender --background --python tools/blender/woodpile.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1
rng = random.Random(14)
PARTS = []
add = PARTS.append

Y_BACK = 0.265         # face avant du fond de planches
Z_BASE = 0.085         # dessus des traverses de pied
XL = 0.54              # demi-largeur utile du tas

# ------------------------------------------------------------------ buches (un seul mesh multi-materiaux)
L = Mesh()


def log(x, z, r, y_front, y_back, bark, end_m, ring_m):
    n = 9
    rot = rng.uniform(0, math.pi)
    rings = []
    for (y, k) in ((y_front, 1.0), (y_back, 0.97)):
        ring = []
        for j in range(n):
            a = rot + 2 * math.pi * j / n
            rr = r * k * (1.0 + rng.uniform(-0.035, 0.035))
            ring.append((x + rr * math.cos(a), y, z + rr * math.sin(a)))
        rings.append(ring)
    L.loft(rings, bark, cap0=False, cap1=False)
    # bout coupe : disque clair + cernes
    L.add(rings[0], [tuple(range(n))], end_m)
    inner = [(x + (px - x) * 0.52, y_front - 0.004, z + (pz - z) * 0.52) for (px, py, pz) in rings[0]]
    L.add(inner, [tuple(range(n))], ring_m)


rows = 6
for row in range(rows):
    z = Z_BASE + 0.072 + row * 0.119
    cnt = 8 if row % 2 == 0 else 7
    off = 0.0 if row % 2 == 0 else 0.0675
    for i in range(cnt):
        x = -XL + 0.0675 + off + i * 0.135 + rng.uniform(-0.005, 0.005)
        if abs(x) > XL + 0.01:
            continue
        r = rng.uniform(0.057, 0.067)
        yf = -0.27 + rng.uniform(-0.035, 0.015) + (0.012 if row % 3 == 1 else 0.0)
        p = rng.random()
        bark = "wood_dark" if p < 0.55 else ("wood_faded" if p < 0.88 else "stone_dark")
        if bark == "stone_dark":
            bark = "wood_faded"
        fresh = rng.random() < 0.62
        end_m, ring_m = ("wood_light", "wood_faded") if fresh else ("wood_faded", "wood_light")
        log(x, z + rng.uniform(-0.004, 0.006), r, yf, Y_BACK - 0.01, bark, end_m, ring_m)
# deux buches posees de travers sur le dessus (tas un peu en desordre)
logs = L.build("logs")

# ------------------------------------------------------------------ traverses de pied, poteaux, fond de planches
for sx in (-1, 1):
    add(bx(f"bearer_{sx}", (0.10, 0.60, Z_BASE), (sx * 0.47, 0.0, Z_BASE / 2), "wood_dark", bevel=0.018))
add(bx("bearer_back", (1.26, 0.10, Z_BASE), (0, 0.23, Z_BASE / 2), "wood_dark", bevel=0.018))
for sx in (-1, 1):
    for sy, zt in ((-1, 0.855), (1, 0.925)):
        y = sy * 0.31 if sy < 0 else 0.31
        add(bx(f"post_{sx}_{sy}", (0.095, 0.095, zt), (sx * 0.625, sy * 0.275, zt / 2), "wood_faded", bevel=0.02))
    add(bx(f"brace_{sx}", (0.07, 0.07, 0.34), (sx * 0.625, -0.275, 0.45), "wood_dark", rot=(0, 0, 0), bevel=0.015))
    add(bx(f"stone_foot_{sx}", (0.17, 0.17, 0.05), (sx * 0.625, -0.275, 0.025), "stone", bevel=0.025))
add(bx("beam_front", (1.40, 0.09, 0.09), (0, -0.275, 0.82), "wood_dark", bevel=0.02))
add(bx("beam_back", (1.40, 0.09, 0.09), (0, 0.275, 0.89), "wood_dark", bevel=0.02))
for sx in (-1, 1):
    add(bx(f"beam_side_{sx}", (0.09, 0.58, 0.08), (sx * 0.625, 0.0, 0.86), "wood_dark", rot=(math.atan(0.07 / 0.55), 0, 0), bevel=0.02))

# fond de planches verticales (Y_BACK .. +0.35)
B = Mesh()
n_pl = 7
pw = 1.40 / n_pl
for i in range(n_pl):
    xa = -0.70 + i * pw
    xb = xa + pw
    z1 = 0.93 + rng.uniform(-0.008, 0.01)
    z0 = 0.05 + rng.uniform(0, 0.03)
    g = 0.012
    prof = [(xa, 0.045), (xb, 0.045), (xb - g, 0.0), (xa + g, 0.0)]
    v = [(u, Y_BACK + d, z) for z in (z0, z1) for (u, d) in prof]
    f = [(3, 2, 1, 0), (4, 5, 6, 7)]
    for k in range(4):
        k2 = (k + 1) % 4
        f.append((k, k2, 4 + k2, 4 + k))
    r = rng.random()
    B.add(v, f, "wood_dark" if r < 0.5 else ("wood_faded" if r < 0.85 else "wood_light"))
wall = B.build("back_wall")
add(wall)

# ------------------------------------------------------------------ auvent : planchettes en gradins, incline vers l'avant
RY0, RY1 = -0.35, 0.35
RZ0, RZ1 = 0.862, 0.932          # dessous : avant / arriere
TH = 0.07


def rbot(y):
    return RZ0 + (y - RY0) / (RY1 - RY0) * (RZ1 - RZ0)


R = Mesh()
top = []
nc = 5
for k in range(nc):
    y0 = RY0 + (RY1 - RY0) * k / nc
    y1 = RY0 + (RY1 - RY0) * (k + 1) / nc
    top.append((y0, rbot(y0) + TH))
    top.append((y1 - 0.012, rbot(y1) + TH - 0.026))
prof = top + [(RY1, rbot(RY1)), (RY0, rbot(RY0))]
NP = len(prof)
xs = [-0.70 + 1.40 * i / 4 for i in range(5)]
verts = []
for x in xs:
    for j, (y, z) in enumerate(prof):
        jz = rng.uniform(-0.004, 0.004) if j < len(top) else 0.0
        verts.append((x, y, z + jz))
for i in range(len(xs) - 1):
    for j in range(NP):
        j2 = (j + 1) % NP
        a, b = i * NP + j, i * NP + j2
        if j < len(top) - 1:
            nose = abs(prof[j + 1][0] - prof[j][0]) < 0.03
            r = rng.random()
            m = "shingle_dark" if nose else ("shingle" if r < 0.6 else ("shingle_light" if r < 0.88 else "shingle_dark"))
        elif j == len(top) - 1 or j == NP - 2 + 1:
            m = "shingle_dark"
        else:
            m = "wood_dark"
        R.add([verts[a], verts[b], verts[b + NP], verts[a + NP]], [(0, 1, 2, 3)], m)
for i, rev in ((0, True), (len(xs) - 1, False)):
    idx = [i * NP + j for j in range(NP)]
    if rev:
        idx = idx[::-1]
    R.add([verts[k] for k in idx], [tuple(range(NP))], "wood_dark")
roof = R.build("roof")

# mousse sur l'auvent et au pied
a_roof = math.atan((RZ1 - RZ0) / (RY1 - RY0))
add(moss("moss_roof_a", (-0.30, 0.12, rbot(0.12) + TH - 0.02), 0.17, 0.11, 0.03, rot=(a_roof, 0, 0), seg=7, rings=3))
add(moss("moss_roof_b", (0.40, -0.18, rbot(-0.18) + TH - 0.02), 0.13, 0.08, 0.03, rot=(a_roof, 0, 0), seg=7, rings=3))
add(moss("moss_foot_a", (-0.60, -0.33, 0.05), 0.10, 0.08, 0.05, seg=7, rings=3))
add(moss("moss_foot_b", (0.50, -0.32, 0.04), 0.09, 0.07, 0.05, seg=7, rings=3))

pile = merge([logs, roof] + PARTS, "woodpile", origin=(0, 0, 0))

collision_box("woodpile", (1.40, 0.70, 0.97), (0, 0.0, 0.485))

pfinish("woodpile", expected_dims=(1.4, 0.7, 1.0), tri_limit=(300, 3000),
        angles={"woodpile": math.radians(50)}, yaw=28, pitch=14, margin=1.05,
        extra_views=[("_b", dict(yaw=-30, pitch=24, margin=1.05))])
