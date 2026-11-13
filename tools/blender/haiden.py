"""Haiden : pavillon de priere avec engawa, socle de pierre, toit a double pente courbe.
Lancer : blender --background --python tools/blender/haiden.py
Avant = -Y. Faitage le long de X."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import common

reset_scene()


def sweep_x(name, profile, xs, zlift, material, bevel=BEVEL_WIDTH):
    """Extrude un profil (y, z) le long de X ; zlift(x) releve la section."""
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


# ----------------------------------------------------------- geometrie du toit
YR = 1.85           # demi-profondeur du toit (debord compris)
E, H = 2.70, 1.02   # hauteur du bord / amplitude jusqu'au faitage (dessus des tuiles)


def roof_top(y):
    u = 1 - min(abs(y), YR) / YR
    return E + H * u ** 1.5 + 0.12 * (1 - u) ** 4      # concave + relevé au bout (hanegaeri)


def samples(ymax, n=15):
    return [-ymax + 2 * ymax * i / (n - 1) for i in range(n)]


def roof_profile(ymax, dz_top, dz_bot):
    ys = samples(ymax)
    return [(y, roof_top(y) + dz_bot) for y in ys] + [(y, roof_top(y) + dz_top) for y in reversed(ys)]


no_lift = lambda x: 0.0
ZB = roof_top(1.0) - 0.34 - 0.02 + 0.0    # sommet du corps (jusque sous le toit)
ZB = 2.62

parts = []
M = lambda p: parts.append(p)
common.BEVEL_SEGMENTS = 2   # grosses pieces : bevel 2 segments

# ----------------------------------------------------------- socle, sol, marches
M(box("podium", (3.8, 2.3, 0.4), (0, -0.05, 0.2), "stone", bevel=0.04))
common.BEVEL_SEGMENTS = 1
M(box("podium_skirt", (3.9, 2.4, 0.12), (0, -0.05, 0.06), "stone_dark", bevel=0.03))
M(box("deck_base", (3.7, 2.3, 0.14), (0, -0.1, 0.47), "wood_dark"))
# lames de la veranda (praticable)
for i in range(5):
    y = -1.18 + i * 0.145
    M(box(f"plank_{i}", (3.68, 0.14, 0.12), (0, y, 0.54), "wood_light" if i % 2 == 0 else "wood_faded", bevel=0.015))
M(box("deck_rear", (3.68, 1.7, 0.12), (0, 0.22, 0.54), "wood_faded", bevel=0.015))
common.BEVEL_SEGMENTS = 2
M(box("step_b", (1.5, 0.36, 0.4), (0, -1.38, 0.2), "stone", bevel=0.04))
M(box("step_a", (1.65, 0.36, 0.2), (0, -1.73, 0.1), "stone", bevel=0.04))

common.BEVEL_SEGMENTS = 1   # petites pieces : chanfrein 1 segment (budget)
# ----------------------------------------------------------- corps ferme
common.BEVEL_SEGMENTS = 2
M(box("body", (3.0, 1.5, ZB - 0.6), (0, 0.25, 0.6 + (ZB - 0.6) / 2), "wood_faded", bevel=0.03))
common.BEVEL_SEGMENTS = 1
for sx in (-1, 1):
    for yy in (-0.5, 1.0):
        M(box(f"wall_post_{sx}_{yy}", (0.2, 0.2, ZB - 0.6), (sx * 1.5, yy, 0.6 + (ZB - 0.6) / 2), "wood_dark", bevel=0.04))
M(box("sill_front", (3.1, 0.1, 0.14), (0, -0.52, 0.68), "wood_dark", bevel=0))
M(box("beam_front", (3.1, 0.12, 0.16), (0, -0.52, 2.45), "wood_dark", bevel=0.02))
for sx in (-1, 1):
    M(box(f"beam_side_{sx}", (0.12, 1.6, 0.16), (sx * 1.52, 0.25, 2.45), "wood_dark", bevel=0.02))
    M(box(f"sill_side_{sx}", (0.1, 1.6, 0.14), (sx * 1.52, 0.25, 0.68), "wood_dark", bevel=0.02))
M(box("beam_back", (3.1, 0.12, 0.16), (0, 1.02, 2.45), "wood_dark", bevel=0.02))
# planches verticales sur les murs lateraux et arriere
for sx in (-1, 1):
    for k in range(3):
        M(box(f"batten_{sx}_{k}", (0.05, 0.08, 1.5), (sx * 1.53, -0.05 + k * 0.5, 1.55), "wood_dark", bevel=0))
for k in range(5):
    M(box(f"batten_back_{k}", (0.08, 0.05, 1.5), (-1.1 + k * 0.55, 1.03, 1.55), "wood_dark", bevel=0))

# portes coulissantes en bois et papier (washi)
M(box("door_frame", (2.0, 0.08, 1.62), (0, -0.53, 1.47), "wood_dark", bevel=0.02))
M(box("door_lintel", (2.4, 0.14, 0.16), (0, -0.55, 2.25), "wood_dark", bevel=0.02))
for sx in (-1, 1):
    cx = sx * 0.47
    M(box(f"door_paper_{sx}", (0.9, 0.03, 1.46), (cx, -0.58, 1.47), "paper", bevel=0))
    M(box(f"door_stile_a_{sx}", (0.06, 0.05, 1.5), (cx - 0.45, -0.60, 1.47), "wood_light", bevel=0))
    M(box(f"door_stile_b_{sx}", (0.06, 0.05, 1.5), (cx + 0.45, -0.60, 1.47), "wood_light", bevel=0))
    for zz in (0.74, 2.20):
        M(box(f"door_rail_{sx}_{zz}", (0.9, 0.05, 0.07), (cx, -0.60, zz), "wood_light", bevel=0))
    for vx in (-0.22, 0.0, 0.22):
        M(box(f"door_bar_v_{sx}_{vx}", (0.025, 0.02, 1.4), (cx + vx, -0.61, 1.47), "wood_light", bevel=0))
    for zz in (1.1, 1.47, 1.84):
        M(box(f"door_bar_h_{sx}_{zz}", (0.86, 0.02, 0.025), (cx, -0.61, zz), "wood_light", bevel=0))
# petites fenetres de papier de chaque cote
for sx in (-1, 1):
    M(box(f"win_frame_{sx}", (0.5, 0.06, 0.78), (sx * 1.25, -0.53, 1.55), "wood_dark", bevel=0.02))
    M(box(f"win_paper_{sx}", (0.38, 0.03, 0.66), (sx * 1.25, -0.57, 1.55), "paper", bevel=0))
    M(box(f"win_bar_{sx}", (0.025, 0.02, 0.66), (sx * 1.25, -0.585, 1.55), "wood_dark", bevel=0))

# ----------------------------------------------------------- veranda : piliers, poutre, rambarde
common.BEVEL_SEGMENTS = 1
PX = (-1.65, -0.9, 0.9, 1.65)
for i, x in enumerate(PX):
    common.BEVEL_SEGMENTS = 2
    M(box(f"post_{i}", (0.26, 0.26, 1.92), (x, -1.05, 0.6 + 0.96), "wood_dark", bevel=0.045))
    common.BEVEL_SEGMENTS = 1
    M(box(f"post_stone_{i}", (0.38, 0.38, 0.09), (x, -1.05, 0.645), "stone", bevel=0.03))
    M(box(f"post_cap_{i}", (0.42, 0.42, 0.12), (x, -1.05, 2.58), "wood_dark", bevel=0.03))
common.BEVEL_SEGMENTS = 1
M(box("beam_veranda", (3.95, 0.24, 0.24), (0, -1.05, 2.45), "wood_dark", bevel=0.04))
for sx in (-1, 1):
    # poutres reliant la veranda au corps
    M(box(f"tie_{sx}", (0.2, 0.6, 0.2), (sx * 1.65, -0.78, 2.45), "wood_dark", bevel=0.03))
    M(box(f"tie_mid_{sx}", (0.2, 0.6, 0.2), (sx * 0.9, -0.78, 2.45), "wood_dark", bevel=0.03))
# rambardes laquees rouges
for sx in (-1, 1):
    cx = sx * 1.38
    M(box(f"rail_top_{sx}", (1.0, 0.1, 0.1), (cx, -1.2, 1.3), "lacquer_red", bevel=0.03))
    M(box(f"rail_low_{sx}", (1.0, 0.08, 0.08), (cx, -1.2, 0.92), "lacquer_red", bevel=0.025))
    for bx in (0.0, 0.33, -0.33):
        M(box(f"rail_bal_{sx}_{bx}", (0.07, 0.07, 0.7), (cx + bx, -1.2, 0.96), "lacquer_red", bevel=0.02))
    M(box(f"newel_{sx}_a", (0.13, 0.13, 0.85), (sx * 0.88, -1.2, 1.02), "lacquer_red", bevel=0.035))
    M(box(f"newel_{sx}_b", (0.13, 0.13, 0.85), (sx * 1.86, -1.2, 1.02), "lacquer_red", bevel=0.035))
    M(box(f"rail_side_top_{sx}", (0.1, 0.72, 0.1), (sx * 1.86, -0.85, 1.3), "lacquer_red", bevel=0.03))
    M(box(f"rail_side_low_{sx}", (0.08, 0.72, 0.08), (sx * 1.86, -0.85, 0.92), "lacquer_red", bevel=0.025))
    M(box(f"newel_{sx}_c", (0.13, 0.13, 0.85), (sx * 1.86, -0.5, 1.02), "lacquer_red", bevel=0.035))

# ----------------------------------------------------------- toit
# remplissage du pignon / dessous du toit (entre corps et toit)
ys = [-0.5 + 1.5 * i / 8 for i in range(9)]
fill = [(y, ZB - 0.03) for y in ys] + [(y, roof_top(y) - 0.34 + 0.03) for y in reversed(ys)]
common.BEVEL_SEGMENTS = 1
M(sweep_x("gable_fill", fill, [-1.48, 1.48], no_lift, "wood_faded", bevel=0.02))
M(sweep_x("roof_base", roof_profile(YR - 0.08, -0.10, -0.34), [-2.12, 2.12], no_lift, "wood_dark", bevel=0.03))
M(sweep_x("roof_tiles", roof_profile(YR, 0.0, -0.12), [-2.2, 2.2], no_lift, "stone_dark", bevel=0.03))
common.BEVEL_SEGMENTS = 1
# faitage courbe
ridge_lift = lambda x: 0.08 * (abs(x) / 2.1) ** 2.5
ridge_prof = [(-0.24, -0.1), (0.24, -0.1), (0.22, 0.05), (0.11, 0.17), (-0.11, 0.17), (-0.22, 0.05)]
ridge_prof = [(y, z + roof_top(0) + 0.05) for (y, z) in ridge_prof]
M(sweep_x("ridge", ridge_prof, [-2.1 + i * 4.2 / 7 for i in range(8)], ridge_lift, "stone", bevel=0.03))
for sx in (-1, 1):   # onigawara : bouts noirs releves
    M(box(f"ridge_end_{sx}", (0.26, 0.42, 0.40), (sx * 2.06, 0, roof_top(0) + 0.20), "lacquer_black", bevel=0.05))
# ----------------------------------------------------------- usure : mousse
rng = [(-1.75, -1.2), (1.4, -1.22), (-1.9, 0.3), (1.9, -0.6), (0.9, 1.1), (-1.0, 1.12), (1.9, 0.7)]
for k, (x, y) in enumerate(rng):
    M(sphere(f"moss_base_{k}", 0.16, (x, y, 0.06), "moss", scale=(1.3, 1.0, 0.4), seg=6, rings=3))
M(sphere("moss_step_a", 0.12, (-0.7, -1.88, 0.2), "moss", scale=(1.4, 1.0, 0.4), seg=6, rings=3))
for k, (x, y) in enumerate([(-1.5, -1.45), (1.2, 1.2)]):
    M(sphere(f"moss_roof_{k}", 0.16, (x, y, roof_top(y) - 0.02), "moss", scale=(1.5, 1.0, 0.2), seg=6, rings=3))

# ----------------------------------------------------------- collisions
collision_box("haiden_floor", (3.8, 2.3, 0.6), (0, -0.05, 0.3))
collision_box("haiden_step_b", (1.5, 0.36, 0.4), (0, -1.38, 0.2))
collision_box("haiden_step_a", (1.65, 0.36, 0.2), (0, -1.73, 0.1))
collision_box("haiden_body", (3.0, 1.5, 2.0), (0, 0.25, 1.6))
for i, x in enumerate(PX):
    collision_box(f"haiden_post_{i}", (0.3, 0.3, 1.9), (x, -1.05, 1.55))
for sx in (-1, 1):
    collision_box(f"haiden_rail_{sx}", (1.2, 0.15, 0.8), (sx * 1.38, -1.2, 1.0))
    collision_box(f"haiden_rail_side_{sx}", (0.15, 0.9, 0.8), (sx * 1.86, -0.8, 1.0))

finish_model("haiden", expected_dims=(4.4, 3.8, 4.0), yaw=32, pitch=16)
