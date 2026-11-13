"""Panier d'osier / bambou tresse pour les feuilles : 0.6 m de diametre (anses comprises), 0.5 m de haut."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
rnd = random.Random(4)
H = 0.455
R = 14          # rangees de tressage
M = 24          # colonnes
RB, RT = 0.19, 0.25


def rad(z):
    t = z / H
    return lerp(RB, RT, t ** 0.9) + 0.016 * math.sin(math.pi * min(t, 1.0) ** 0.8)


zs = [0.025 + (H - 0.025) * i / (R - 1) for i in range(R)]
rim_top = RT + 0.0
rim = [(rad(H) + 0.012, H + 0.004), (rad(H) + 0.016, H + 0.022), (rad(H) + 0.006, H + 0.04),
       (rad(H) - 0.018, H + 0.044), (rad(H) - 0.034, H + 0.03), (rad(H) - 0.032, H + 0.012)]
inner = [(rad(z) - 0.03, z) for z in (zs[-3], zs[-6], zs[-10])]
floor = [(0.16, 0.055), (0.07, 0.05), (0.0, 0.05)]
profile = [(0.17, 0.0)] + [(rad(z), z) for z in zs] + rim + inner + floor
n_out = len(zs) + 1           # lignes de la face exterieure (profil 0..n_out)
n_rim = len(rim)

wb = Mesh()
def col(i, j):
    if i == 0:
        return "wood_light"                      # dessous du fond
    if i < n_out:
        return "straw" if (i + j) % 2 else "bamboo"
    if i < n_out + n_rim:
        return "wood_light"                      # bourrelet du bord
    return "wood_faded"                          # interieur

N = M
rings = []
for i, (r, z) in enumerate(profile):
    ring = []
    for j in range(N):
        a = 2 * math.pi * j / N + (math.pi / N if (i % 2) else 0)
        rr = r
        if 1 <= i < n_out:       # relief de tressage : brins alternes
            rr += 0.0075 * (1 if (i + j) % 2 else -0.3)
        rr *= 1 + 0.012 * noise3(math.cos(a) * 2, math.sin(a) * 2, z * 3, 4.0)
        ring.append((rr * math.cos(a), rr * math.sin(a), z))
    rings.append(ring)
wb.loft(rings, col, cap0=True, cap1=False)

# base : couronne de renfort en bois clair
base_ring = []
for k in range(N):
    pass
ring_pts = [(math.cos(2 * math.pi * k / (N)) * (RB + 0.012), math.sin(2 * math.pi * k / (N)) * (RB + 0.012), 0.022)
            for k in range(N)]
ring_pts.append(ring_pts[0])
tmp = Mesh()
tmp.tube(ring_pts, [0.02] * len(ring_pts), 5, "wood_light", caps=False)
# bandes de renfort plaquees contre le tressage
for zb in (0.13, 0.30):
    rp = [(math.cos(2 * math.pi * k / N) * (rad(zb) + 0.009), math.sin(2 * math.pi * k / N) * (rad(zb) + 0.009), zb)
          for k in range(N)]
    rp.append(rp[0])
    tmp.tube(rp, [0.011] * len(rp), 5, "wood_light", caps=False)
# anses : deux boucles opposees (axe X)
def handle(sign):
    pts = []
    x0 = rad(0.38) - 0.01
    for k in range(11):
        t = math.pi * k / 10
        y = -0.095 * math.cos(t)
        x = sign * (x0 + 0.06 * math.sin(t) ** 0.7)
        z = 0.37 + 0.09 * math.sin(t) ** 0.9 + 0.01 * (1 - math.sin(t))
        pts.append((x, y, z))
    return pts
for s in (1, -1):
    pts = handle(s)
    radii = [0.023 if 0 < k < 10 else 0.024 for k in range(11)]
    tmp.tube(pts, radii, 7, "bamboo", caps=True)
    # ligatures de l'anse
    for yy, p in ((pts[0], 1), (pts[-1], 1)):
        tmp.blob((yy[0] - s * 0.012, yy[1], yy[2]), (0.032, 0.03, 0.04), "wood_light", subdiv=1, noise=0.05)

body = wb.build("basket_weave")
extra = tmp.build("basket_trim")
body = join([body, extra], "basket")
collision_box("basket", (0.54, 0.54, 0.48), (0, 0, 0.24))
pfinish("basket", expected_dims=(0.62, 0.55, 0.50), tri_limit=(100, 3000), angles={"basket": math.radians(55)})
