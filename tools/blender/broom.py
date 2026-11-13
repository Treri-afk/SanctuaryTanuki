"""Balai de jardin (takeboki) : manche de bambou, ligatures de corde, touffe en eventail. 1,4 m. Origine : bas de la touffe."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from veg_utils import *

reset_scene()
rng = random.Random(11)

Z_TOP_BUNDLE = 0.65     # haut des meches (cache sous la ligature)
Z_BIND2 = 0.42          # seconde ligature : sous elle, la touffe s'evase
ELL_X, ELL_Y = 0.36, 0.17


def handle_c(z):
    """Axe du manche : legerement irregulier."""
    return Vector((0.011 * math.sin((z - 0.5) * 3.3) + 0.004, 0.007 * math.sin((z - 0.5) * 5.1 + 1.0), z))


def handle_r(z):
    return lerp(0.0225, 0.0170, (z - 0.48) / 0.92) + 0.0008 * math.sin(z * 17.0)


# ---------------------------------------------------------------- manche
hb = Builder()
zs = [0.48 + i * 0.07 for i in range(13)] + [1.385, 1.397]
pts = [handle_c(z) for z in zs]
rad = [handle_r(z) for z in zs]
rad[-2] *= 0.93
rad[-1] *= 0.55
hb.tube(pts, rad, sides=8, m="bamboo")
# noeuds du bambou (bagues legerement plus larges)
for zn in (0.83, 1.04, 1.25):
    r = handle_r(zn) + 0.0032
    zz = [zn - 0.011, zn - 0.006, zn + 0.006, zn + 0.011]
    hb.tube([handle_c(z) for z in zz], [r * 0.93, r, r, r * 0.93], sides=6, m="wood_faded")
# bas du manche (partie enfoncee dans la touffe, bois plus fonce)
hb.tube([handle_c(z) for z in (0.48, 0.55, 0.62, 0.70)], [0.0225, 0.0228, 0.0232, 0.0228], sides=8, m="wood_light")
handle = hb.build("handle")

# ---------------------------------------------------------------- touffe
bb = Builder()


def tip_radius(phi, scale):
    ca, sa = math.cos(phi), math.sin(phi)
    return scale / math.sqrt((ca / ELL_X) ** 2 + (sa / ELL_Y) ** 2)


def radial(z, tip_r):
    if z >= Z_BIND2:
        return 0.040 + 0.020 * (Z_TOP_BUNDLE - z) / (Z_TOP_BUNDLE - Z_BIND2)
    u = (Z_BIND2 - z) / Z_BIND2
    return 0.060 + (tip_r - 0.060) * (u ** 1.15)


def strand_pts(phi, tip_r, z_top, z_end, zlist, lean):
    pts = []
    for z in zlist:
        zz = max(z, z_end) if z > z_end else z_end
        u = (z_top - zz) / (z_top - z_end)
        r = radial(zz, tip_r)
        # courbure : les pointes se recourbent un peu vers l'avant-droite (usure)
        x = r * math.cos(phi) + lean * (u ** 2.5)
        y = r * math.sin(phi) - 0.04 * lean * (u ** 2.5)
        pts.append(Vector((x, y, zz)))
    return pts


def pick_mat():
    p = rng.random()
    return "straw" if p < 0.45 else ("bamboo" if p < 0.8 else "wood_faded")


bundles = []
n_out = 16
for k in range(n_out):
    phi = 2 * math.pi * k / n_out + rng.uniform(-0.10, 0.10)
    sc = rng.uniform(0.86, 1.1) * (1 + 0.09 * math.cos(phi - 0.5))
    z_end = rng.uniform(0.012, 0.05)
    bundles.append((phi, tip_radius(phi, sc), z_end, 1.0, pick_mat()))
for k in range(6):
    phi = 2 * math.pi * k / 6 + 0.4 + rng.uniform(-0.15, 0.15)
    bundles.append((phi, tip_radius(phi, 0.55), rng.uniform(0.05, 0.10), 0.85, pick_mat()))

for phi, tr, z_end, rs, m in bundles:
    zl = [Z_TOP_BUNDLE, Z_BIND2, lerp(Z_BIND2, z_end, 0.45), lerp(Z_BIND2, z_end, 0.8), z_end]
    lean = rng.uniform(0.01, 0.045)
    p = strand_pts(phi, tr, Z_TOP_BUNDLE, z_end, zl, lean)
    radii = [0.027, 0.026, 0.0215, 0.0165, 0.011]
    bb.tube(p, [r * rs for r in radii], sides=5, m=m, caps=True)

# brins fins qui s'echappent des meches (aspect hirsute, un peu casse)
for k in range(20):
    phi = rng.uniform(0, 2 * math.pi)
    tr = tip_radius(phi, rng.uniform(0.95, 1.30))
    z_end = rng.uniform(0.012, 0.11)
    zl = [0.52, Z_BIND2, lerp(Z_BIND2, z_end, 0.5), z_end]
    lean = rng.uniform(0.0, 0.06)
    p = strand_pts(phi, tr, 0.52, z_end, zl, lean)
    bb.tube(p, [0.0085, 0.0085, 0.0062, 0.0035], sides=3, m=rng.choice(["straw", "bamboo", "straw"]))
bristles = bb.build("bristles")

# ---------------------------------------------------------------- ligatures en corde
rb = Builder()


def coil(z0, z1, R, turns, ppt=7, r_rope=0.0085, wob=0.004):
    n = int(turns * ppt)
    pts, rr = [], []
    for k in range(n + 1):
        a = 2 * math.pi * turns * k / n + 0.7
        z = lerp(z0, z1, k / n) + 0.003 * math.sin(a * 2.0)
        R2 = R + wob * math.sin(a * 1.3 + 2.0)
        c = Vector((R2 * math.cos(a) * 1.12, R2 * math.sin(a) * 0.95, z))
        pts.append(c)
        rr.append(r_rope)
    return pts, rr


# ligature haute (serree, 5 tours)
p1, r1 = coil(0.50, 0.675, 0.077, 3.2, ppt=11)
rb.tube(p1, r1, sides=6, m="rope")
# queue pendante + noeud
tail0 = p1[-1]
rb.tube([tail0, tail0 + Vector((0.035, -0.02, -0.03)), tail0 + Vector((0.055, -0.03, -0.085)),
         tail0 + Vector((0.05, -0.04, -0.14))], [0.0085, 0.0085, 0.007, 0.005], sides=5, m="rope")
# ligature basse (4 tours) : la touffe s'evase dessous
p2, r2 = coil(0.385, 0.455, 0.098, 2.8, ppt=11, r_rope=0.0095)
rb.tube(p2, r2, sides=6, m="rope")
t2 = p2[-1]
rb.tube([t2, t2 + Vector((-0.03, -0.03, -0.02)), t2 + Vector((-0.045, -0.05, -0.07)),
         t2 + Vector((-0.04, -0.06, -0.12))], [0.0095, 0.009, 0.0075, 0.005], sides=5, m="rope")
rope = rb.build("rope")

# collisions simples (version posee)
collision_box("broom_handle", (0.07, 0.07, 1.40), loc=(0.0, 0.0, 0.70))
collision_box("broom_tuft", (0.46, 0.26, 0.45), loc=(0.0, 0.0, 0.225))

finish("broom", expected_dims=(0.65, 0.40, 1.40), tri_limit=(500, 3000),
       margin=1.0, angles={"bristles": math.radians(75), "handle": math.radians(60), "rope": math.radians(75)},
       extra_views=[("_b", dict(yaw=-50, pitch=10, margin=0.85))])
