"""Rateau de jardin zen en bois : manche de 1,4 m, tete de 0,6 m a dents, deux jambes de force, ligature de corde.
Tenu en main : manche vertical, origine au bas des dents. Pas de collision.
Lancer : blender --background --python tools/blender/rake.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1
rng = random.Random(6)
PARTS = []
add = PARTS.append

# ------------------------------------------------------------------ manche (bois clair use, legerement irregulier)
H = Mesh()


def hc(z):
    return Vector((0.006 * math.sin(z * 3.1), 0.004 * math.sin(z * 5.3 + 1.0), z))


zs = [0.12 + i * 0.11 for i in range(12)] + [1.40]
rad = [0.0215 - 0.0055 * (z - 0.12) / 1.28 + 0.0007 * math.sin(z * 19) for z in zs]
rad[-1] *= 0.8
H.tube([hc(z) for z in zs], rad, 8, "wood_light", caps=True)
# usure : zone de prise plus sombre au milieu du manche
H.tube([hc(z) for z in (0.62, 0.72, 0.82, 0.92, 1.02)], [0.0198, 0.0201, 0.0203, 0.0200, 0.0197], 8, "wood_faded", caps=True)
# pommeau
H.blob((0.0, 0.0, 1.405), (0.0215, 0.0215, 0.016), "wood_faded", subdiv=1, noise=0.0)
handle = H.build("handle")

# ------------------------------------------------------------------ tete, jambes de force, dents
add(bx("head_bar", (0.60, 0.085, 0.05), (0, 0, 0.115), "wood_faded", bevel=0.012))
add(bx("head_block", (0.12, 0.085, 0.07), (0, 0, 0.145), "wood_dark", bevel=0.015))
for sx in (-1, 1):
    add(bx(f"head_end_{sx}", (0.035, 0.09, 0.065), (sx * 0.2925, 0, 0.115), "wood_dark", bevel=0.012))
    add(bx(f"brace_{sx}", (0.034, 0.03, 0.40), (sx * 0.105, 0, 0.285), "wood_faded", rot=(0, -sx * 0.55, 0), bevel=0.008))
add(cyl("binding", 0.0285, 0.065, (0, 0, 0.41), "rope", verts=10, bevel=0.005))
add(cyl("binding_low", 0.0285, 0.04, (0, 0, 0.185), "rope", verts=10, bevel=0.004))

T = Mesh()
n_t = 12
for i in range(n_t):
    x = -0.275 + 0.55 * i / (n_t - 1)
    h = 0.095 - (0.03 if i in (3, 8) else 0.0) - rng.uniform(0, 0.006)
    z0 = 0.0
    m = "wood_light" if i % 4 else "wood_faded"
    T.tube([(x, 0, z0), (x, 0, z0 + h * 0.5), (x, 0, 0.095)], [0.0075, 0.0105, 0.0125], 6, m, caps=True)
teeth = T.build("teeth")

collision = None

pfinish("rake", expected_dims=(0.6, 0.1, 1.4), tri_limit=(150, 1500),
        angles={"handle": math.radians(60), "teeth": math.radians(60)}, yaw=25, pitch=12, margin=1.0,
        extra_views=[("_b", dict(yaw=-50, pitch=10, margin=0.9))])
