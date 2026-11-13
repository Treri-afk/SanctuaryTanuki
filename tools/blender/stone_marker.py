"""Steele de pierre (sekihi) : 0,5 x 0,25 x 1,6 m, sur un socle, panneau d'inscription en creux, mousse, penchee.
Lancer : blender --background --python tools/blender/stone_marker.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

reset_scene()
S, SD = "stone", "stone_dark"

# ---------------------------------------------------------------- socle : 2 pierres superposees, un peu de travers
lo = box("base_low", (0.50, 0.25, 0.115), (0, 0, 0.0575), SD, bevel=0.03)
hi = box("base_high", (0.42, 0.20, 0.09), (0, 0, 0.16), S, bevel=0.025)
jitter(lo, 0.005, 3)
jitter(hi, 0.005, 6)
lo.rotation_euler = (math.radians(0.5), 0, math.radians(-1.5))
hi.rotation_euler = (0, 0, math.radians(1.8))

# ---------------------------------------------------------------- steele : dalle a sommet arrondi (loft), panneau en creux
ZB, ZT = 0.19, 1.60
rings = [(0, 0, ZB, 0.34, 0.15), (0, 0, 0.9, 0.335, 0.15), (0, 0, 1.46, 0.318, 0.15),
         (0, 0, 1.51, 0.308, 0.147), (0, 0, 1.55, 0.280, 0.138), (0, 0, 1.58, 0.225, 0.118), (0, 0, ZT, 0.13, 0.075)]
st = Mesh()
rect_loft(st, rings, S)
stele = st.build("stele")
cut = box("cut", (0.20, 0.044, 0.76), (0, -0.0705, 0.93), S, bevel=0)   # fond du creux a y = -0.0485 (creux de 2,6 cm)
bool_cut(stele, cut)
common._finalize_obj(stele, None, 0.014, "stele")

# fond sombre du creux + quelques "caracteres" clairs en relief leger
ins = Mesh()
add_box(ins, (0, -0.0505, 0.93), (0.192, 0.004, 0.752), SD)
GY = -0.0538
rg = random.Random(5)


def glyph(m, cx, cz, h, kind):
    """Pseudo-caractere : quelques traits clairs en relief leger (suggere une inscription)."""
    w = 0.10 * h
    def bar(x, z, sx, sz, ry=0.0):
        add_box(m, (cx + x * h, GY, cz + z * h), (sx * h, 0.004, sz * h), S, rot=(0, ry, 0))
    if kind == 0:
        bar(0, 0.38, 0.8, 0.11)
        bar(0, 0.0, 0.11, 0.95)
        bar(0, -0.05, 0.56, 0.10)
        bar(-0.22, -0.32, 0.11, 0.42, 0.55)
        bar(0.22, -0.32, 0.11, 0.42, -0.55)
    elif kind == 1:
        bar(0, 0.40, 0.7, 0.10)
        bar(-0.2, 0.05, 0.11, 0.8)
        bar(0.2, 0.05, 0.11, 0.8)
        bar(0, 0.05, 0.5, 0.10)
        bar(0, -0.30, 0.5, 0.10)
        bar(0, -0.46, 0.8, 0.10)
    elif kind == 2:
        bar(0, 0.42, 0.9, 0.10)
        bar(0.0, 0.0, 0.11, 0.9)
        bar(-0.28, -0.12, 0.10, 0.5, 0.45)
        bar(0.28, -0.1, 0.10, 0.5, -0.5)
    else:
        bar(0, 0.0, 0.8, 0.11)
        bar(-0.3, 0.0, 0.11, 0.9)
        bar(0.3, 0.0, 0.11, 0.9)
        bar(0, 0.35, 0.8, 0.10)
        bar(0, -0.35, 0.8, 0.10)


for k, z in enumerate((1.19, 1.05, 0.91, 0.77, 0.63)):
    glyph(ins, -0.035 + rg.uniform(-0.004, 0.004), z, 0.105, (k * 3 + 1) % 4)
for k, z in enumerate((1.22, 1.14, 1.06)):
    glyph(ins, 0.062, z, 0.062, (k * 2) % 4)
add_box(ins, (0.062, GY, 0.74), (0.04, 0.004, 0.04), "lacquer_red")     # petit sceau rouge
inlay = ins.build("inscription")
# moisissure/mousse sur la steele : pied + trainee sur le cote gauche
sm = Mesh()
for i, (x, y, z, rx, ry, rz, yaw) in enumerate([(-0.02, -0.075, 0.22, 0.11, 0.022, 0.055, 0.0),
                                                (-0.168, -0.02, 0.32, 0.016, 0.06, 0.12, 0.0),
                                                (0.10, 0.074, 0.23, 0.09, 0.02, 0.05, 0.0),
                                                (0.10, -0.075, 0.20, 0.05, 0.02, 0.035, 0.0)]):
    sm.blob((x, y, z), (rx, ry, rz), "moss", subdiv=2, noise=0.15, seed=40 + i, bottom=0.6)
smoss = sm.build("stele_moss")
st_all = join([stele, inlay, smoss], "stele_group")
apply_rot(st_all, (-1.0, 2.6, 0.0), pivot=(0, 0, ZB))

# ---------------------------------------------------------------- mousse au sol / socle
m = Mesh()
moss_blobs(m, [(-0.18, -0.10, 0.115, 0.06, 0.04, 0.025, 0.2), (0.19, -0.08, 0.115, 0.05, 0.05, 0.025, 0.0),
               (0.255, 0.02, 0.04, 0.03, 0.07, 0.04, 0.0), (-0.12, 0.105, 0.02, 0.08, 0.035, 0.035, 0.1),
               (0.10, -0.115, 0.01, 0.08, 0.03, 0.035, 0.0), (0.14, 0.05, 0.205, 0.05, 0.04, 0.02, 0.3),
               (-0.15, -0.04, 0.205, 0.04, 0.035, 0.02, 0.5)], 51)
mosses = m.build("moss_patches")

parts = [lo, hi, st_all, mosses]
tri_report(parts)
mk = join(parts, "stone_marker")
collision_box("stone_marker", (0.5, 0.25, 1.6), (0, 0, 0.8))

tfinish("stone_marker", expected_dims=(0.5, 0.25, 1.6), tri_limit=(300, 3500), yaw=-28, pitch=10, margin=1.05,
        angles={"stone_marker": math.radians(45)},
        extra_views=[("_b", dict(yaw=20, pitch=8, margin=1.05)), ("_c", dict(yaw=120, pitch=8, margin=1.05))])
