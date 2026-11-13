"""Hokora : petit sanctuaire de bord de chemin (1,2 x 0,9 x 1,6 m). Avant = -Y.
Socle de pierre moussu, corps de bois a portes closes (washi), toit a double pente epais, details laques rouges.
Lancer : blender --background --python tools/blender/hokora.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

reset_scene()
S, SD = "stone", "stone_dark"
parts = []

# ---------------------------------------------------------------- socle de pierre (2 etages + marche), de travers
lo = box("base_low", (1.02, 0.74, 0.15), (0, 0, 0.075), SD, bevel=0.035)
hi = box("base_high", (0.92, 0.64, 0.14), (0, 0, 0.21), S, bevel=0.03)
step = box("step", (0.50, 0.09, 0.09), (0.0, -0.385, 0.045), S, bevel=0.025)
for o, sd in ((lo, 3), (hi, 5), (step, 7)):
    jitter(o, 0.006, sd)
hi.rotation_euler = (0, 0, math.radians(2.2))
lo.rotation_euler = (math.radians(0.6), 0, math.radians(-1.5))
step.rotation_euler = (0, 0, math.radians(2.0))
parts += [lo, hi, step]

# ---------------------------------------------------------------- corps de bois
PX, PY = 0.36, 0.22
for sx in (-1, 1):
    for sy in (-1, 1):
        mt = "wood_faded" if (sy > 0 and sx > 0) else "wood_dark"
        parts.append(box("post", (0.08, 0.08, 0.74), (sx * PX, sy * PY, 0.65), mt, bevel=0.015))
# parois (non biseautees, en retrait des poteaux) : planches verticales au dos, traverses sur les cotes
w = Mesh()
bx = [-0.27, -0.09, 0.09, 0.27]
for i, x in enumerate(bx):
    add_box(w, (x, PY, 0.65), (0.178, 0.03, 0.72), "wood_faded" if i != 2 else "wood_dark")
for sx in (-1, 1):
    mt = "wood_dark" if sx < 0 else "wood_faded"
    add_box(w, (sx * PX, 0, 0.65), (0.03, 0.36, 0.72), mt)
    for z in (0.46, 0.78):
        add_box(w, (sx * (PX + 0.012), 0, z), (0.03, 0.40, 0.045), "wood_dark")
add_box(w, (0, -0.205, 0.345), (0.64, 0.03, 0.13), "wood_faded")
parts.append(w.build("walls"))
# ceinture laquee rouge (kamoi) qui deborde des poteaux + corniche sombre au-dessus
parts.append(box("belt_red", (0.86, 0.58, 0.09), (0, 0, 0.93), "lacquer_red", bevel=0.02))
parts.append(box("cornice", (0.78, 0.52, 0.05), (0, 0, 0.9975), "wood_dark", bevel=0.012))

# ---------------------------------------------------------------- portes closes (washi) : 2 vantaux coulissants
d = Mesh()


def door(m, cx, y, w, h, z0):
    t, f = 0.030, 0.030
    zc = z0 + h / 2
    add_box(m, (cx, y, z0 + f / 2), (w, t, f), "wood_dark")
    add_box(m, (cx, y, z0 + h - f / 2), (w, t, f), "wood_dark")
    add_box(m, (cx - w / 2 + f / 2, y, zc), (f, t, h - 2 * f), "wood_dark")
    add_box(m, (cx + w / 2 - f / 2, y, zc), (f, t, h - 2 * f), "wood_dark")
    add_box(m, (cx, y + 0.003, zc), (w - 2 * f + 0.004, 0.010, h - 2 * f + 0.004), "paper")
    add_box(m, (cx, y - 0.003, zc), (0.012, 0.012, h - 2 * f), "wood_light")
    for k in (1, 2):
        add_box(m, (cx, y - 0.003, z0 + f + (h - 2 * f) * k / 3), (w - 2 * f, 0.012, 0.012), "wood_light")


DW, DH, DZ = 0.335, 0.455, 0.43
door(d, -0.162, -0.172, DW, DH, DZ)
door(d, 0.162, -0.202, DW, DH, DZ)
# poignees laquees
add_box(d, (-0.007, -0.222, DZ + DH / 2), (0.014, 0.014, 0.08), "lacquer_red")
add_box(d, (0.017, -0.232, DZ + DH / 2), (0.014, 0.014, 0.08), "lacquer_red")
add_box(d, (0, -0.185, 0.425), (0.66, 0.05, 0.02), "wood_dark")      # rail bas (shikii)
parts.append(d.build("doors"))

# ---------------------------------------------------------------- toit a double pente, epais, concave, avec rebords releves
RY, RX = 0.42, 0.58


def zt(t):          # hauteur de la face superieure : t = 0 a l'egout, 1 au faitage
    return 1.10 + 0.40 * t ** 1.5 + 0.03 * (1 - t) ** 8


TS = [0, 0.1, 0.22, 0.36, 0.52, 0.68, 0.84, 1.0]
left = [(-RY * (1 - t), zt(t)) for t in TS]
right = [(RY * (1 - t), zt(t)) for t in TS[:-1]][::-1]
prof = [(-RY, 1.0)] + left + right + [(RY, 1.0), (0.30, 1.035), (-0.30, 1.035)]
ring = lambda x: [(x, y, z) for y, z in prof]
roof = Mesh()
roof.loft([ring(-RX), ring(RX)], "wood_dark")
roof_o = roof.build("roof", bevel=0.02)
parts.append(roof_o)
roof_top = lambda s, t: (s * RY * (1 - t), zt(t))

# planches de couverture : baguettes fines suivant la pente, sans biseau (maillage a part)
bt = Mesh()


def batten(m, x, s, mat_name, w=0.03, h=0.014):
    pts = [roof_top(s, t) for t in (0.05, 0.3, 0.55, 0.78, 0.97)]
    rings = []
    for i, (y, z) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(ty, tz)
        ny, nz = -tz / L, ty / L
        if nz < 0:
            ny, nz = -ny, -nz
        rings.append([(x - w / 2, y - 0.006 * ny, z - 0.006 * nz), (x + w / 2, y - 0.006 * ny, z - 0.006 * nz),
                      (x + w / 2, y + h * ny, z + h * nz), (x - w / 2, y + h * ny, z + h * nz)])
    m.loft(rings, mat_name)


for s in (-1, 1):
    for k in range(8):
        x = -0.49 + 0.14 * k
        batten(bt, x, s, "wood_faded")
parts.append(bt.build("roof_battens"))
# faite : poutre + embouts noirs
parts.append(box("ridge_cap", (1.14, 0.17, 0.11), (0, 0, 1.52), "wood_dark", bevel=0.02))
for sx in (-1, 1):
    parts.append(box("ridge_end", (0.08, 0.21, 0.16), (sx * 0.575, 0, 1.525), "lacquer_black", bevel=0.025))

# ---------------------------------------------------------------- mousse
m = Mesh()
moss_blobs(m, [(-0.40, -0.28, 0.15, 0.09, 0.06, 0.04, 0.3), (0.45, -0.14, 0.15, 0.07, 0.10, 0.04, -0.2),
               (0.22, 0.31, 0.15, 0.10, 0.06, 0.035, 0.1), (-0.49, 0.10, 0.04, 0.05, 0.12, 0.05, 0.0),
               (0.12, -0.44, 0.01, 0.12, 0.06, 0.05, 0.1), (-0.17, -0.385, 0.09, 0.08, 0.05, 0.03, 0.2),
               (-0.35, 0.0, 0.28, 0.08, 0.06, 0.03, 0.4)], 11)
# mousse sur le toit : petits amas irreguliers inclines sur la pente
def roof_moss(m, x, t, s, r, seed):
    """Amas de mousse irregulier pose sur la pente (blobs inclines suivant la normale du toit)."""
    rnd = random.Random(seed)
    for k in range(4):
        tt = min(max(t + rnd.uniform(-0.07, 0.07), 0.05), 0.95)
        y, z = roof_top(s, tt)
        dt = 0.02
        y2, z2 = roof_top(s, tt + dt)
        a = math.atan2(z2 - z, abs(y2 - y)) * (-s)
        m.blob((x + rnd.uniform(-r, r) * 1.2, y, z + 0.004),
               (r * rnd.uniform(0.7, 1.1), r * rnd.uniform(0.5, 0.8), 0.02), "moss", subdiv=1, noise=0.15,
               seed=seed + k, bottom=0.4, quat=Quaternion((1, 0, 0), a) @ Quaternion((0, 0, 1), rnd.uniform(-0.4, 0.4)))


roof_moss(m, -0.36, 0.30, -1, 0.08, 3)
roof_moss(m, 0.33, 0.14, -1, 0.07, 8)
roof_moss(m, 0.10, 0.45, 1, 0.08, 5)
parts.append(m.build("moss_patches"))

tri_report(parts)
hok = join(parts, "hokora")
apply_rot(hok, (0.5, -0.7, 2.0))
collision_box("hokora", (1.1, 0.8, 1.6), (0, 0, 0.8))

tfinish("hokora", expected_dims=(1.2, 0.9, 1.6), tri_limit=(300, 3500), yaw=32, pitch=15, margin=1.12,
        angles={"hokora": math.radians(45)},
        extra_views=[("_b", dict(yaw=-145, pitch=14, margin=1.12))])
