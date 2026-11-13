"""Presentoir a ema (1,5 m) : deux poteaux, toit a double pente avec auvent, deux barres de suspension.
6 plaquettes ema separees (ema_01..06) + 8 empties ema_slot_01..08 (origine de chaque ema = son point d'accroche)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from veg_utils import *

reset_scene()
rng = random.Random(21)
parts = []

PX = 0.55            # demi-ecartement des poteaux
BAR_Z = (1.42, 1.00)
POST_TOP = 1.84

# pierres d'assise
for sx in (-1, 1):
    parts.append(box(f"footing_{'l' if sx < 0 else 'r'}", (0.30, 0.30, 0.13), loc=(sx * PX, 0, 0.065), material="stone", bevel=0.025))
# poteaux (un peu decolore a gauche)
parts.append(box("post_l", (0.125, 0.125, POST_TOP - 0.12), loc=(-PX, 0, (POST_TOP + 0.12) / 2), material="wood_faded", bevel=0.02))
parts.append(box("post_r", (0.125, 0.125, POST_TOP - 0.12), loc=(PX, 0, (POST_TOP + 0.12) / 2), material="wood_dark", bevel=0.02))
# poutre haute (kamoi), lisse basse et traverse intermediaire
parts.append(box("beam_top", (1.40, 0.11, 0.12), loc=(0, 0, 1.76), material="wood_dark", bevel=0.02))
parts.append(box("sill_beam", (1.18, 0.09, 0.09), loc=(0, 0, 0.30), material="wood_dark", bevel=0.02))
parts.append(box("rail_low", (1.28, 0.06, 0.06), loc=(0, 0, 0.62), material="wood_light", bevel=0.012))
# barres de suspension (depassent un peu des poteaux)
for i, z in enumerate(BAR_Z):
    parts.append(box(f"bar_{i + 1}", (1.30, 0.05, 0.05), loc=(0, 0, z), material="wood_light", bevel=0.01))
# jambes de force (liaison poteau / poutre)
for sx in (-1, 1):
    for sy in (-1,):
        parts.append(box("brace", (0.07, 0.06, 0.34), loc=(sx * (PX - 0.16), 0, 1.60), material="wood_dark",
                         rot=(0, sx * math.radians(42), 0), bevel=0.012))
# montants courts sous le faite
for x in (-PX, 0.0, PX):
    parts.append(box("strut", (0.08, 0.08, 0.22), loc=(x, 0, 1.88), material="wood_dark", bevel=0.015))

# toit a double pente (profil Y/Z extrude en X), debord genereux
rx, ry = 0.74, 0.43
prof = [(-ry, 1.70), (-ry, 1.80), (0.0, 2.04), (ry, 1.80), (ry, 1.70), (0.0, 1.94)]
verts = [(-rx, y, z) for y, z in prof] + [(rx, y, z) for y, z in prof]
faces = [(0, 1, 2, 3, 4, 5), (11, 10, 9, 8, 7, 6)]
for i in range(6):
    j = (i + 1) % 6
    faces.append((i, j, 6 + j, 6 + i))
roof = mesh_from_data("roof", verts, faces, material="wood_dark", bevel=0.02)
parts.append(roof)
parts.append(box("ridge_cap", (1.50, 0.17, 0.07), loc=(0, 0, 2.06), material="wood_light", bevel=0.02))
# mousse sur le toit et sur une assise
mb = Builder()
mb.blob((0.30, -0.22, 1.92), (0.16, 0.09, 0.03), "moss", subdiv=2, noise=0.12, seed=2, bottom=0.5)
mb.blob((-0.35, 0.24, 1.94), (0.17, 0.10, 0.03), "moss", subdiv=2, noise=0.12, seed=5, bottom=0.5)
mb.blob((-PX + 0.08, -0.12, 0.135), (0.10, 0.08, 0.035), "moss", subdiv=2, noise=0.15, seed=9, bottom=0.4)
parts.append(mb.build("moss_patches"))

frame = join(parts, "frame")

# ---------------------------------------------------------------- ema
slot_xs = [-0.36, -0.12, 0.12, 0.36]
slots = []   # (x, z_apex)
for z in BAR_Z:
    for x in slot_xs:
        slots.append((x, z - 0.07))
PLATE_Y = -0.03
LOOP = [(0.0, 0.0), (-0.006, 0.04), (-0.006, 0.09), (0.005, 0.104), (0.03, 0.108), (0.056, 0.104), (0.066, 0.09),
        (0.066, 0.05), (0.056, 0.036), (0.03, 0.032), (0.004, 0.036), (0.0, 0.015)]
plate_outline = [(0.0, 0.0), (-0.06, -0.026), (-0.06, -0.09), (0.06, -0.09), (0.06, -0.026)]
slip_outline = [(-0.035, -0.04), (-0.035, -0.075), (0.035, -0.075), (0.035, -0.04)]
ema_mats = ["wood_light", "wood_faded", "wood_light", "wood_light", "wood_faded", "wood_light"]
tilts = [0.05, -0.06, 0.03, -0.04, 0.07, -0.03]
for i in range(8):
    x, zs_ = slots[i]
    empty(f"ema_slot_{i + 1:02d}", loc=(x, PLATE_Y, zs_), kind="ARROWS", size=0.04)
    if i >= 6:
        continue
    b = Builder()
    b.poly_prism(plate_outline, 0.009, ema_mats[i])
    if i in (1, 3, 4):
        b.poly_prism(slip_outline, 0.004, "paper", y0=-0.0065)
    # corde : boucle passant autour de la barre (la barre est a +0.03 en Y, +0.07 en Z)
    br = Builder()
    br.tube([(0.0, y, z) for y, z in LOOP], [0.0036] * len(LOOP), sides=4, m="rope", closed=True, ref=(1, 0, 0))
    o1 = b.build(f"ema_{i + 1:02d}", bevel=0.0012, loc=(x, PLATE_Y, zs_))
    o2 = br.build("cord", loc=(x, PLATE_Y, zs_))
    o = join([o1, o2], f"ema_{i + 1:02d}")
    o.rotation_euler = (0, tilts[i], 0)

# collisions (structure seulement)
collision_box("ema_rack_post_l", (0.16, 0.16, 1.85), loc=(-PX, 0, 0.925))
collision_box("ema_rack_post_r", (0.16, 0.16, 1.85), loc=(PX, 0, 0.925))
collision_box("ema_rack_roof", (1.5, 0.86, 0.38), loc=(0, 0, 1.87))
collision_box("ema_rack_bars", (1.1, 0.08, 0.85), loc=(0, 0, 1.2))

finish("ema_rack", expected_dims=(1.5, 0.86, 2.1), tri_limit=(500, 5000),
       angles={"frame": math.radians(40), "moss_patches": math.radians(180)}, margin=1.0,
       extra_views=[("_b", dict(yaw=-25, pitch=6, margin=1.0))])
