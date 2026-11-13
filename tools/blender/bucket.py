"""Seau de bois a cerclages (tarugo), anse de corde. ~30 cm de diametre, 28 cm de haut. Origine au sol, centree."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from veg_utils import *

reset_scene()
rng = random.Random(5)

H = 0.28
N = 16
DELTA = 2 * math.pi / N
THICK = 0.017


def Ro(z):
    """Rayon exterieur (leger evasement vers le haut + petit ventre)."""
    return lerp(0.128, 0.150, z / H) + 0.003 * math.sin(math.pi * z / H)


def stave(b, theta, z_top, m, ear=False):
    c = 0.0045
    zs = [0.0, 0.14, H]
    taper_top = 0.0
    if ear:
        zs += [z_top - 0.012, z_top]
    sections = []
    for zi, z in enumerate(zs):
        ro = Ro(z)
        ri = ro - THICK
        wo = ro * math.tan(DELTA / 2) * 0.975
        wi = wo * ri / ro
        if ear and z > H:
            k = 1.0 if z < z_top - 0.01 else 0.62      # oreille arrondie
            wo, wi = wo * k, wi * k
            ro -= (0.0 if k == 1 else 0.003)
        pts = [(-wi, ri), (-wo, ro - c), (-wo + c, ro), (wo - c, ro), (wo, ro - c), (wi, ri)]
        sections.append((z, pts))
    verts, faces = [], []
    ct, st = math.cos(theta), math.sin(theta)
    for z, pts in sections:
        for u, r in pts:
            # r = distance radiale (avant = -Y gere par theta), u = tangent
            verts.append((r * ct - u * st, r * st + u * ct, z))
    n = 6
    for i in range(len(sections) - 1):
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    for i in (0, len(sections) - 1):
        faces.append(tuple(range(i * n, i * n + n)))
    b.add(verts, faces, m)


body = Builder()
ear_idx = (0, 8)   # staves opposees (axe X) qui depassent
for k in range(N):
    theta = k * DELTA + (math.pi / 2 if False else 0)
    ear = k in ear_idx
    p = rng.random()
    if ear:
        p = 0.1
    m = "wood_light" if p < 0.62 else ("wood_faded" if p < 0.92 else "wood_dark")
    stave(body, theta + rng.uniform(-0.01, 0.01), H + (0.055 if ear else 0.0) - (0.0 if ear else rng.uniform(0, 0.004)), m, ear)


def revolve(b, prof, m, seg=24):
    n = len(prof)
    verts = []
    for s in range(seg):
        a = 2 * math.pi * s / seg
        for r, z in prof:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    faces = []
    for s in range(seg):
        s2 = (s + 1) % seg
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((s * n + j, s * n + j2, s2 * n + j2, s2 * n + j))
    b.add(verts, faces, m)


# fond (planche circulaire legerement en retrait)
revolve(body, [(0.0001, 0.012), (0.118, 0.012), (0.126, 0.02), (0.126, 0.04), (0.118, 0.045), (0.0001, 0.045)], "wood_faded", 16)


def hoop(z0, z1, m, ex=0.011):
    c = 0.004
    zm = (z0 + z1) / 2
    prof = [(Ro(z0) - 0.004, z0), (Ro(z0) + ex - c, z0), (Ro(z0) + ex, z0 + c),
            (Ro(z1) + ex, z1 - c), (Ro(z1) + ex - c, z1), (Ro(z1) - 0.004, z1)]
    revolve(body, prof, m, 28)


hoop(0.035, 0.075, "metal", 0.0095)
hoop(0.195, 0.235, "bamboo", 0.011)
# anse de corde qui passe par les oreilles
ez = H + 0.03
arc = []
for i in range(19):
    a = math.pi * i / 18
    arc.append((Ro(ez) * -math.cos(a) * 1.0 + (0.0), 0.0, ez + 0.10 * math.sin(a) ** 0.9 + (0.0)))
# les extremites traversent les oreilles (axe X)
arc[0] = (-Ro(ez) + 0.004, 0.0, ez)
arc[-1] = (Ro(ez) - 0.004, 0.0, ez)
for i, (x, y, z) in enumerate(arc):
    arc[i] = (x * (1.0 + 0.1 * math.sin(math.pi * i / 18)), y, z)
body.tube(arc, [0.0075] * len(arc), sides=6, m="rope")
# noeuds exterieurs
for sx in (-1, 1):
    body.blob((sx * (Ro(ez) + 0.004), 0.0, ez), (0.011, 0.011, 0.011), "rope", subdiv=1, noise=0.1, seed=sx + 3)

bucket = body.build("bucket")
collision_box("bucket", (0.31, 0.31, 0.28), loc=(0, 0, 0.14))

finish("bucket", expected_dims=(0.32, 0.32, 0.40), tri_limit=(500, 3000),
       angles={"bucket": math.radians(35)}, margin=1.0,
       extra_views=[("_b", dict(yaw=-120, pitch=45, margin=1.0))])
