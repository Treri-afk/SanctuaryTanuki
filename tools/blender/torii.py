"""Torii vermillon 3,5 m. Lancer : blender --background --python tools/blender/torii.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

reset_scene()


def sweep_x(name, profile, xs, zlift, material, loc=(0, 0, 0), bevel=BEVEL_WIDTH):
    """Extrude un profil (y, z) le long de X ; zlift(x) releve la section (kasagi courbe)."""
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
    return mesh_from_data(name, verts, faces, material, loc, bevel)


def lift(x):
    return 0.24 * (abs(x) / 2.05) ** 2.4


XS_ALL = [-2.05 + i * (4.1 / 20) for i in range(21)]
ROOF_PROFILE = [(-0.30, -0.15), (0.30, -0.15), (0.36, 0.02), (0.0, 0.19), (-0.36, 0.02)]
CAP_PROFILE = [(y * 1.07, z * 1.1) for (y, z) in ROOF_PROFILE]

Z0 = 3.08
parts = []
# kasagi : corps rouge + bouts noirs
parts.append(sweep_x("kasagi", ROOF_PROFILE, XS_ALL, lift, "lacquer_red", loc=(0, 0, Z0)))
for s in (-1, 1):
    xs = [s * (1.62 + i * (0.43 / 5)) for i in range(6)]
    if s < 0:
        xs = xs[::-1]
    # bout noir : section un peu plus grosse, orienté pour garder les normales
    p = CAP_PROFILE if s > 0 else list(reversed(CAP_PROFILE))
    parts.append(sweep_x(f"kasagi_tip_{'r' if s>0 else 'l'}", p, sorted(xs), lift, "lacquer_black", loc=(0, 0, Z0)))

# shimaki (sous le kasagi), noir fin dessous
parts.append(box("shimaki", (3.7, 0.38, 0.15), (0, 0, 2.90), "lacquer_red"))
parts.append(box("shimaki_edge", (3.76, 0.30, 0.05), (0, 0, 2.84), "lacquer_black"))

# nuki : traverse qui dépasse des piliers
parts.append(box("nuki", (3.5, 0.2, 0.26), (0, 0, 2.42), "lacquer_red"))
for s in (-1, 1):
    # cales (kusabi) de chaque côté de pilier
    parts.append(box(f"kusabi_{s}", (0.10, 0.28, 0.40), (s * 1.62, 0, 2.42), "lacquer_black", bevel=0.03))

# gakuzuka : plaque centrale
parts.append(box("plaque_frame", (0.62, 0.12, 0.42), (0, 0, 2.64), "wood_dark", bevel=0.03))
parts.append(box("plaque_face", (0.46, 0.05, 0.30), (0, -0.065, 2.64), "metal_gold", bevel=0.015))
parts.append(box("plaque_face_back", (0.46, 0.05, 0.30), (0, 0.065, 2.64), "metal_gold", bevel=0.015))

# piliers évasés, légèrement inclinés vers l'intérieur
for s in (-1, 1):
    lean = -s * 0.035
    h = 2.62
    p = cylinder(f"pillar_{s}", 0.28, h, (s * 1.2 + (-s * 0.045), 0, 0.32 + h / 2), "lacquer_red",
                 rot=(0, lean, 0), verts=14, bevel=0.03, radius2=0.205)
    parts.append(p)
    # collier noir au pied (kamabara)
    parts.append(cylinder(f"pillar_foot_{s}", 0.295, 0.30, (s * 1.2, 0, 0.47), "lacquer_black", verts=14,
                          bevel=0.03, radius2=0.285))
    # base de pierre
    parts.append(cylinder(f"base_{s}", 0.40, 0.32, (s * 1.2, 0, 0.16), "stone", verts=16, bevel=0.04, radius2=0.36))
    parts.append(cylinder(f"base_top_{s}", 0.30, 0.06, (s * 1.2, 0, 0.33), "stone_dark", verts=16, bevel=0.02))
    # mousse
    for k, (a, r) in enumerate([(-30, 0.13), (100, 0.1), (200, 0.12), (300, 0.08)]):
        ang = math.radians(a)
        parts.append(sphere(f"moss_{s}_{k}", r, (s * 1.2 + 0.34 * math.cos(ang), 0.34 * math.sin(ang), 0.04),
                            "moss", scale=(1.1, 1, 0.45), seg=8, rings=4))
    # coulure/décoloration : bande de bois décoloré au-dessus du collier
    parts.append(cylinder(f"pillar_faded_{s}", 0.278, 0.22, (s * 1.2 + (-s * 0.0085), 0, 0.72), "wood_faded", verts=14,
                          bevel=0.02, radius2=0.272, rot=(0, lean, 0)))

# collisions : piliers seulement
for s in (-1, 1):
    collision_box(f"pillar_{s}", (0.6, 0.6, 3.0), (s * 1.2, 0, 1.5))

finish_model("torii", expected_dims=(4.1, 0.75, 3.5), yaw=30, pitch=14)
