"""Saisen-bako (tronc a offrandes) + cloche suzu sous un petit auvent.
Objets separes : `rope` (corde, sans collision), `bell` (cloche, metal), empty `rope_anchor` (bas de la corde).
Lancer : blender --background --python tools/blender/offering_box.py     Avant = -Y."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import common

reset_scene()
common.BEVEL_SEGMENTS = 2


def sweep_x(name, profile, xs, zlift, material, bevel=BEVEL_WIDTH):
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


def set_origin(obj, point):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.context.scene.cursor.location = point
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


BY = 0.32       # centre du tronc en Y
RY = -0.22      # position Y de la corde
parts = []
M = parts.append

# ---------------------------------------------------------------- portique : poteaux, poutre, auvent
YR = 0.72
E, H = 2.85, 0.35


def roof_top(y):
    u = 1 - min(abs(y), YR) / YR
    return E + H * u ** 1.5 + 0.06 * (1 - u) ** 4


def prof(ymax, dz_top, dz_bot, n=11):
    ys = [-ymax + 2 * ymax * i / (n - 1) for i in range(n)]
    return [(y, roof_top(y) + dz_bot) for y in ys] + [(y, roof_top(y) + dz_top) for y in reversed(ys)]


nl = lambda x: 0.0
for sx in (-1, 1):
    M(box(f"post_{sx}", (0.2, 0.2, 2.78), (sx * 0.95, 0, 1.39 + 0.0), "wood_dark", bevel=0.04))
    M(box(f"post_stone_{sx}", (0.36, 0.36, 0.18), (sx * 0.95, 0, 0.09), "stone", bevel=0.04))
    M(box(f"post_stone_top_{sx}", (0.3, 0.3, 0.04), (sx * 0.95, 0, 0.2), "stone_dark", bevel=0.01))
    M(sphere(f"moss_post_{sx}", 0.14, (sx * 0.95 + 0.14, -0.14, 0.06), "moss", scale=(1.3, 1, 0.4), seg=6, rings=3))
M(box("beam", (2.3, 0.24, 0.24), (0, 0, 2.86), "wood_dark", bevel=0.04))
M(box("rope_mount", (0.16, 0.24, 0.1), (0, RY + 0.06, 2.74), "lacquer_black", bevel=0.02))
M(box("bell_hanger", (0.05, 0.05, 0.12), (0, 0, 2.70), "metal", bevel=0.01))
for sx in (-1, 1):    # petites consoles
    M(box(f"bracket_{sx}", (0.14, 0.44, 0.12), (sx * 0.95, 0, 2.76), "wood_dark", bevel=0.03))
M(sweep_x("roof_base", prof(YR - 0.06, -0.10, -0.31), [-1.28, 1.28], nl, "wood_dark", bevel=0.025))
M(sweep_x("roof_tiles", prof(YR, 0.0, -0.10), [-1.36, 1.36], nl, "stone_dark", bevel=0.025))
rp = [(-0.18, -0.07), (0.18, -0.07), (0.15, 0.04), (0.0, 0.1), (-0.15, 0.04)]
M(sweep_x("ridge", [(y, z + roof_top(0) + 0.0) for (y, z) in rp], [-1.3 + i * 2.6 / 6 for i in range(7)],
          lambda x: 0.05 * (abs(x) / 1.3) ** 2.5, "stone", bevel=0.02))
M(sphere("moss_roof", 0.16, (-0.6, -0.5, roof_top(-0.5) - 0.02), "moss", scale=(1.5, 1, 0.2), seg=6, rings=3))

# ---------------------------------------------------------------- tronc saisen-bako
M(box("box_plinth", (1.1, 0.7, 0.1), (0, BY, 0.05), "wood_faded", bevel=0.03))
M(box("box_body", (1.0, 0.6, 0.68), (0, BY, 0.44), "wood_dark", bevel=0.04))
M(box("box_top_plate", (0.9, 0.5, 0.02), (0, BY, 0.78), "lacquer_black", bevel=0))
for sy in (-1, 1):
    M(box(f"box_frame_fb_{sy}", (1.04, 0.09, 0.10), (0, BY + sy * 0.255, 0.82), "wood_light", bevel=0.02))
for sx in (-1, 1):
    M(box(f"box_frame_side_{sx}", (0.09, 0.45, 0.10), (sx * 0.475, BY, 0.82), "wood_light", bevel=0.02))
for i in range(7):   # grille en lattes
    M(box(f"box_slat_{i}", (0.07, 0.44, 0.05), (-0.36 + i * 0.12, BY, 0.835), "wood_light", bevel=0))
for i, bx in enumerate((-0.3, 0.0, 0.3)):     # lattes verticales de face
    M(box(f"box_batten_{i}", (0.08, 0.04, 0.55), (bx, BY - 0.31, 0.44), "wood_light", bevel=0.01))
M(box("box_band", (1.04, 0.05, 0.08), (0, BY - 0.30, 0.72), "wood_faded", bevel=0.01))
M(sphere("moss_box", 0.13, (0.4, BY - 0.38, 0.06), "moss", scale=(1.3, 1, 0.4), seg=6, rings=3))

# ---------------------------------------------------------------- cloche (objet separe `bell`)
BZ = 2.45
b = []
b.append(sphere("bell_body", 0.16, (0, 0, BZ), "metal_gold", scale=(1, 1, 0.95), seg=14, rings=8))
b.append(cylinder("bell_ring", 0.045, 0.05, (0, 0, BZ + 0.17), "metal_gold", verts=10, bevel=0.01))
b.append(cylinder("bell_collar", 0.07, 0.03, (0, 0, BZ + 0.13), "metal_gold", verts=10, bevel=0.008))
b.append(sphere("bell_slit", 0.12, (0, -0.13, BZ - 0.09), "lacquer_black", scale=(0.85, 0.12, 0.09), seg=8, rings=4))
bell = join(b, "bell")
set_origin(bell, (0, 0, BZ + 0.2))

# ---------------------------------------------------------------- corde (objet separe `rope`)
r = []
z_top, z_cord_end, z_bot = 2.74, 1.22, 0.98
nseg = 8
seg = (z_top - z_cord_end) / nseg
for i in range(nseg):
    z = z_top - seg * (i + 0.5)
    r.append(cylinder(f"rope_seg_{i}", 0.034, seg + 0.004, (0, RY, z), "lacquer_red" if i % 2 else "rope",
                      verts=8, bevel=0))
for i in range(0, nseg + 1, 2):
    pass
r.append(sphere("rope_knot", 0.055, (0, RY, z_cord_end - 0.03), "rope", scale=(1, 1, 1.1), seg=8, rings=4))
r.append(cylinder("rope_tassel", 0.065, 0.24, (0, RY, (z_cord_end + z_bot) / 2 - 0.05), "straw", verts=8, bevel=0,
                  radius2=0.04))
r.append(cylinder("rope_tassel_end", 0.04, 0.06, (0, RY, z_bot + 0.03), "straw", verts=8, bevel=0, radius2=0.06))
rope = join(r, "rope")
set_origin(rope, (0, RY, z_top))
empty("rope_anchor", (0, RY, z_bot), size=0.08)

# ---------------------------------------------------------------- collisions (pas de collision sur la corde)
collision_box("offering_box", (1.1, 0.7, 0.9), (0, BY, 0.45))
for sx in (-1, 1):
    collision_box(f"offering_post_{sx}", (0.36, 0.36, 2.8), (sx * 0.95, 0, 1.4))

finish_model("offering_box", expected_dims=(2.7, 1.45, 3.3), yaw=28, pitch=12)
