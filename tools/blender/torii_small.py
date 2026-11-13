"""Petit torii de bord de chemin (2,4 m) : piliers evases, kasagi courbe a bouts noirs, nuki, bases de pierre moussues.
Lancer : blender --background --python tools/blender/torii_small.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

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


KX = 1.36                       # demi-longueur du kasagi
lift = lambda x: 0.14 * (abs(x) / KX) ** 2.4
XS = [-1.30 + i * (2.60 / 16) for i in range(17)]
PROF = [(-0.20, -0.095), (0.20, -0.095), (0.235, 0.0), (0.0, 0.12), (-0.235, 0.0)]
CAP = [(y * 1.08, z * 1.12) for (y, z) in PROF]
Z0 = 2.14
PXS = 0.80                       # demi-ecartement des piliers

parts = []
# kasagi : corps rouge + bouts noirs (plus gros), courbe relevee aux extremites
parts.append(sweep_x("kasagi", PROF, XS, lift, "lacquer_red", loc=(0, 0, Z0), bevel=0.02))
for s in (-1, 1):
    xs = sorted(s * (KX - 0.28 + i * (0.28 / 4)) for i in range(5))
    p = CAP if s > 0 else list(reversed(CAP))
    parts.append(sweep_x(f"kasagi_tip_{'r' if s > 0 else 'l'}", p, xs, lift, "lacquer_black", loc=(0, 0, Z0), bevel=0.02))
# nuki : traverse qui depasse des piliers + cales noires
parts.append(box("nuki", (2.0, 0.12, 0.16), (0, 0, 1.70), "lacquer_red", bevel=0.02))
for s in (-1, 1):
    parts.append(box(f"kusabi_{s}", (0.06, 0.17, 0.26), (s * 0.97, 0, 1.70), "lacquer_black", bevel=0.02))
# piliers evases (revolution), legerement inclines vers l'interieur : collier noir, bande decoloree, laque rouge
pm = Mesh()
PZ0, PZ1 = 0.17, 2.15
pr = lambda z: 0.165 - 0.045 * (z - PZ0) / (PZ1 - PZ0)
for s in (-1, 1):
    start = len(pm.v)
    zs = [PZ0, 0.32, 0.54, 1.4, PZ1]
    prof = [(pr(z) + (0.007 if z < 0.4 else (0.003 if z < 0.6 else 0.0)), z) for z in zs]
    mats = ["lacquer_black", "wood_faded", "lacquer_red", "lacquer_red"]
    pm.lathe(prof, 12, lambda i, j: mats[i], center=(s * PXS, 0))
    for k in range(start, len(pm.v)):
        x, y, z = pm.v[k]
        pm.v[k] = (x - s * 0.06 * (z - PZ0) / (PZ1 - PZ0), y, z)
parts.append(pm.build("pillars"))
# bases de pierre trapues (revolution a 9 pans), de travers
bm = Mesh()
for s in (-1, 1):
    bm.lathe([(0.25, 0.0), (0.255, 0.05), (0.225, 0.16), (0.19, 0.185), (0.0, 0.19)], 9, "stone", center=(s * PXS, 0),
             phase=0.2 * s)
bases = bm.build("bases", bevel=0.015)
jitter(bases, 0.007, 4)
parts.append(bases)
# mousse
m = Mesh()
moss_blobs(m, [(-1.0, -0.10, 0.03, 0.08, 0.06, 0.04, 0.3), (-0.78, 0.25, 0.03, 0.07, 0.08, 0.04, 0.0),
               (1.0, 0.08, 0.03, 0.07, 0.09, 0.04, 0.0), (0.78, -0.25, 0.03, 0.09, 0.06, 0.04, 0.2),
               (0.70, 0.17, 0.18, 0.06, 0.06, 0.03, 0.1)], 31)
parts.append(m.build("moss_patches"))

tri_report(parts)
t = join(parts, "torii_small")
apply_rot(t, (0, 0.3, 1.2))

# collisions : piliers seulement
for s in (-1, 1):
    collision_box(f"pillar_{s}", (0.46, 0.46, 2.2), (s * PXS, 0, 1.1))

tfinish("torii_small", expected_dims=(2.72, 0.5, 2.4), tri_limit=(300, 3500), yaw=28, pitch=12, margin=1.05,
        angles={"torii_small": math.radians(45)},
        extra_views=[("_b", dict(yaw=-30, pitch=8, margin=1.05))])
