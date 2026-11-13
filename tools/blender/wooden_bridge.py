"""Petit pont de bois voute (3,2 m x 1,3 m) : longerons arques, tablier de planches, garde-corps bas,
poteaux d'extremite laques rouges uses, culees de pierre moussues. Axe du pont = X. Origine au sol, centre.
Lancer : blender --background --python tools/blender/wooden_bridge.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1
rng = random.Random(8)

XD = 1.30                   # demi-longueur du tablier
Z_END, Z_MID = 0.26, 0.35   # dessus du tablier : aux bouts / au centre
RISE = Z_MID - Z_END
TD, TS = 0.055, 0.12        # epaisseur des planches / des longerons
YP = 0.56                   # demi-largeur des planches
YS = 0.50                   # axe des longerons
YR = 0.60                   # axe des poteaux de garde-corps


def top(x):
    return Z_END + RISE * (1 - (x / XD) ** 2)


def slope(x):
    return -2 * RISE * x / XD ** 2


def sweep_x(name, profile, xs, zlift, material, bevel=0.012):
    n = len(profile)
    verts, faces = [], []
    for x in xs:
        for (y, z) in profile:
            verts.append((x, y, z + zlift(x)))
    for i in range(len(xs) - 1):
        for j in range(n):
            a = i * n + j
            b = i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range((len(xs) - 1) * n, len(xs) * n)))
    return mesh_from_data(name, verts, faces, material, (0, 0, 0), bevel)


PARTS = []
add = PARTS.append

# ------------------------------------------------------------------ longerons arques (bois sombre)
xs = [-1.40 + 2.80 * i / 8 for i in range(9)]
for sy in (-1, 1):
    y = sy * YS
    prof = [(y - 0.06, -TD - TS), (y + 0.06, -TD - TS), (y + 0.06, -TD), (y - 0.06, -TD)]
    add(sweep_x(f"stringer_{sy}", prof, xs, top, "wood_dark", bevel=0.015))
# entretoises sous le tablier
for k, x in enumerate((-0.85, 0.0, 0.85)):
    add(bx(f"cross_{k}", (0.10, 2 * YS - 0.1, 0.09), (x, 0, top(x) - TD - 0.075), "wood_dark", bevel=0.012))

# ------------------------------------------------------------------ planches du tablier (legerement irregulieres)
NPL = 15
pitch = 2 * XD / NPL
for i in range(NPL):
    x = -XD + pitch * (i + 0.5)
    r = rng.random()
    m = "wood_faded" if r < 0.55 else ("wood_light" if r < 0.78 else "wood_dark")
    ang = -math.atan(slope(x)) + rng.uniform(-0.012, 0.012)
    ln = 2 * YP + rng.uniform(-0.025, 0.025)
    add(bx(f"plank_{i}", (pitch - 0.018, ln, TD), (x, rng.uniform(-0.012, 0.012), top(x) - TD / 2 + rng.uniform(-0.004, 0.003)),
           m, rot=(0, ang, 0), bevel=0.012))

# ------------------------------------------------------------------ garde-corps
posts_x = (-1.28, -0.64, 0.0, 0.64, 1.28)
rail_xs = [-1.28 + 2.56 * i / 6 for i in range(7)]
for sy in (-1, 1):
    y = sy * YR
    # lisse haute et lisse basse (suivent l'arc)
    prof = [(y - 0.04, 0.43), (y + 0.04, 0.43), (y + 0.04, 0.51), (y - 0.04, 0.51)]
    add(sweep_x(f"rail_top_{sy}", prof, rail_xs, top, "wood_faded", bevel=0.014))
    prof2 = [(y - 0.03, 0.17), (y + 0.03, 0.17), (y + 0.03, 0.23), (y - 0.03, 0.23)]
    add(sweep_x(f"rail_low_{sy}", prof2, rail_xs, top, "wood_dark", bevel=0.01))
    for k, x in enumerate(posts_x):
        end = k in (0, len(posts_x) - 1)
        if end:
            # poteau d'extremite laque rouge use : pied decolore, corps rouge, chapeau de bois nu
            add(bx(f"endpost_foot_{sy}_{k}", (0.135, 0.135, 0.13), (x, y, top(x) + 0.045), "wood_faded", bevel=0.02))
            add(bx(f"endpost_{sy}_{k}", (0.13, 0.13, 0.46), (x, y, top(x) + 0.34), "lacquer_red", bevel=0.025))
            add(bx(f"endpost_cap_{sy}_{k}", (0.17, 0.17, 0.05), (x, y, top(x) + 0.595), "wood_faded", bevel=0.02))
        else:
            add(bx(f"post_{sy}_{k}", (0.09, 0.09, 0.5), (x, y, top(x) + 0.22), "wood_faded", bevel=0.02))

# ------------------------------------------------------------------ culees de pierre
for sx in (-1, 1):
    outline = [(1.10 * sx, 0.0), (1.62 * sx, 0.0), (1.62 * sx, 0.08), (1.52 * sx, 0.17), (1.22 * sx, 0.20), (1.10 * sx, 0.20)]
    M = Mesh()
    prism_xz(M, outline, -0.65, 0.65, "stone")
    ab = M.build(f"abutment_{sx}", bevel=0.03)
    jitter(ab, 0.008, 40 + sx)
    add(ab)
    # pierres de parement face au ruisseau + gros blocs de coin
    for k, (yy, w, h, m) in enumerate([(-0.42, 0.40, 0.17, "stone_dark"), (0.0, 0.42, 0.11, "stone"), (0.40, 0.40, 0.15, "stone")]):
        o = bx(f"facing_{sx}_{k}", (0.24, w, h), (sx * 1.08, yy, h / 2), m, bevel=0.045)
        jitter(o, 0.008, 70 + k + sx)
        add(o)
    for k, yy in enumerate((-0.52, 0.52)):
        o = bx(f"corner_stone_{sx}_{k}", (0.30, 0.22, 0.30), (sx * 1.46, yy, 0.15 + 0.03 * k), "stone_dark" if k else "stone", bevel=0.05)
        jitter(o, 0.01, 90 + k + sx)
        add(o)
    # mousse
    add(moss(f"moss_ab_{sx}_a", (sx * 1.40, -0.2, 0.2), 0.22, 0.14, 0.04, seg=7, rings=3))
    add(moss(f"moss_ab_{sx}_b", (sx * 1.50, 0.30, 0.09), 0.08, 0.18, 0.05, seg=7, rings=3))
    add(moss(f"moss_face_{sx}", (sx * 1.0, -0.45, 0.04), 0.14, 0.25, 0.05, seg=7, rings=3))
    add(moss(f"moss_corner_{sx}", (sx * 1.46, 0.52, 0.32), 0.12, 0.09, 0.03, seg=7, rings=3))
add(moss("moss_deck_a", (0.42, -0.5, top(0.42) + 0.0), 0.15, 0.09, 0.012, rot=(0, -math.atan(slope(0.42)), 0), seg=7, rings=3))
add(moss("moss_deck_b", (-0.78, 0.52, top(-0.78) + 0.0), 0.13, 0.08, 0.012, rot=(0, -math.atan(slope(-0.78)), 0), seg=7, rings=3))

bridge = merge(PARTS, "bridge", origin=(0, 0, 0))

# ------------------------------------------------------------------ collisions
hull = [(-1.45, 0.0), (1.45, 0.0), (1.45, 0.20)] + [(x, top(x)) for x in (1.3, 1.0, 0.5, 0.0, -0.5, -1.0, -1.3)] + [(-1.45, 0.20)]
H = Mesh()
prism_xz(H, hull, -0.56, 0.56, "wood_light")
dk = H.build("bridge_deck")
dk.name = "bridge_deck-convcol"
dk.data.name = "bridge_deck-convcol"
dk.display_type = "WIRE"
for sy in (-1, 1):
    collision_box(f"bridge_rail_{sy}", (2.7, 0.12, 0.72), (0, sy * YR, 0.46))
for sx in (-1, 1):
    collision_box(f"bridge_abutment_{sx}", (0.55, 1.30, 0.2), (sx * 1.35, 0, 0.10))

pfinish("wooden_bridge", expected_dims=(3.2, 1.3, 0.89), tri_limit=(800, 3500),
        angles={"bridge": math.radians(50)}, yaw=32, pitch=22, margin=1.1,
        extra_views=[("_b", dict(yaw=90, pitch=10, margin=1.0))])
