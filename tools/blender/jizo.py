"""Statue de jizo en pierre (0.9 m) : socle, corps rond, bavoir et bonnet rouges, mousse. Avant = -Y."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
rnd = random.Random(8)
S, SD = "stone", "stone_dark"
ZS = 0.27                       # hauteur du socle

# ---------------------------------------------------------------- socle (2 etages, legerement de travers)
base_lo = box("base_low", (0.56, 0.44, 0.13), (0, 0, 0.065), SD, bevel=0.035)
base_hi = box("base_high", (0.42, 0.34, 0.15), (0, 0, 0.13 + 0.075 - 0.01), S, bevel=0.03)
for o, sd in ((base_lo, 3), (base_hi, 5)):
    jitter(o, 0.006, sd)
base_hi.rotation_euler = (0, 0, math.radians(4))
base_lo.rotation_euler = (math.radians(0.8), 0, math.radians(-3))

# ---------------------------------------------------------------- corps de pierre (revolution)
b = Mesh()
bprof = [(r * 1.1, z) for r, z in [(0.17, ZS - 0.01), (0.178, ZS + 0.03), (0.17, ZS + 0.12), (0.152, ZS + 0.22), (0.14, ZS + 0.30),
         (0.12, ZS + 0.335), (0.088, ZS + 0.35)]]
N = 20
def body_col(i, j):
    a = 2 * math.pi * j / N
    if i <= 1 and noise3(math.cos(a) * 3, math.sin(a) * 3, 0, 7.0) > 0.0:
        return "moss"
    return S
rings = b.lathe([(r, z) for r, z in bprof], N, body_col, scale=(1.0, 0.86))

# tete ronde
ZC, RH = 0.72, 0.148
hprof = []
for k in range(0, 11):
    phi = math.radians(-90 + 18 * k)
    hprof.append((max(RH * math.cos(phi), 0.0), ZC + RH * math.sin(phi) * 0.98))
b.lathe(hprof, N, S, scale=(1.0, 0.93))
# oreilles
for sx in (-1, 1):
    b.blob((sx * 0.146, 0.0, ZC - 0.02), (0.026, 0.024, 0.055), S, subdiv=1, noise=0.0)
# bras / sleeves + mains jointes
for sx in (-1, 1):
    b.blob((sx * 0.135, -0.02, ZS + 0.17), (0.07, 0.085, 0.12), S, subdiv=1, noise=0.04, seed=sx)
b.blob((0, -0.125, ZS + 0.225), (0.085, 0.045, 0.055), S, subdiv=2, noise=0.04, seed=2)
# visage : yeux fermes souriants, bouche
def head_y(z):
    dz = z - ZC
    rr = RH * math.sqrt(max(0.0, 1 - (dz / (RH * 0.98)) ** 2))
    return -rr * 0.93
for sx in (-1, 1):
    zz = ZC - 0.045
    b.blob((sx * 0.052, head_y(zz) + 0.003, zz), (0.026, 0.008, 0.01), SD, subdiv=1, noise=0.0,
           quat=Quaternion((0, 1, 0), sx * 0.18))
zz = ZC - 0.1
b.blob((0, head_y(zz) + 0.003, zz), (0.017, 0.007, 0.007), SD, subdiv=1, noise=0.0)
body = b.build("statue_body")

# ---------------------------------------------------------------- vetements rouges (bavoir + bonnet)
r = Mesh()
# bonnet : calotte legerement plus grande que la tete
cap = []
for k in range(0, 9):
    phi = math.radians(10 + 80 * k / 8)
    rr = RH + 0.014
    cap.append((rr * math.cos(phi) if k < 8 else 0.0, ZC + rr * math.sin(phi) * 0.98 + (0.03 if k == 8 else 0.0)))
cap.insert(0, (RH + 0.018, ZC + 0.03))
cap.insert(0, (RH + 0.012, ZC + 0.018))
r.lathe(cap, N, "lacquer_red", scale=(1.0, 0.93))
# bavoir : collerette evasee autour du cou
r.lathe([(0.125, ZS + 0.318), (0.142, ZS + 0.335), (0.13, ZS + 0.362), (0.108, ZS + 0.372)], N, "lacquer_red", scale=(1.0, 0.86))
# bavoir : pan pendant sur la poitrine
levels = [(ZS + 0.335, 62), (ZS + 0.29, 52), (ZS + 0.24, 44), (ZS + 0.19, 38)]
rr_body = lambda z: None
def body_r(z):
    # interpolation du profil du corps (rayon x)
    for (r0, z0), (r1, z1) in zip(bprof, bprof[1:]):
        if z0 <= z <= z1:
            return lerp(r0, r1, (z - z0) / (z1 - z0))
    return bprof[-1][0]
panel_rings = []
K = 7
for z, th in levels:
    rb = body_r(z)
    pts = []
    for k in range(K):
        a = math.radians(-90 - th + 2 * th * k / (K - 1))
        pts.append((math.cos(a) * (rb + 0.016), math.sin(a) * (rb + 0.016) * 0.86, z))
    for k in reversed(range(K)):
        a = math.radians(-90 - th + 2 * th * k / (K - 1))
        pts.append((math.cos(a) * (rb - 0.004), math.sin(a) * (rb - 0.004) * 0.86, z))
    panel_rings.append(pts)
# pointe du bavoir en bas
r.loft(panel_rings, "lacquer_red", cap0=True, cap1=True)
red = r.build("red_cloth")

# ---------------------------------------------------------------- mousse (volumes)
m = Mesh()
def mb(x, y, z, rx, ry, rz, seed, yaw=0.0):
    m.blob((x, y, z), (rx, ry, rz), "moss", subdiv=2, noise=0.12, seed=seed, bottom=0.5, quat=Quaternion((0, 0, 1), yaw))
mb(-0.22, -0.16, 0.13, 0.09, 0.07, 0.035, 1, 0.5)      # sur le socle bas
mb(0.21, 0.13, 0.13, 0.08, 0.06, 0.03, 2, -0.3)
mb(0.20, -0.17, 0.13, 0.07, 0.055, 0.03, 3)
mb(0.30, 0.0, 0.04, 0.045, 0.09, 0.05, 4)               # contre le flanc, au sol
mb(-0.1, 0.235, 0.04, 0.09, 0.045, 0.05, 5, 0.1)
mb(0.14, 0.11, ZS, 0.07, 0.05, 0.028, 6, 0.8)           # sur le socle haut
mb(-0.15, -0.1, ZS, 0.06, 0.05, 0.026, 7)
mb(0.0, 0.12, ZS + 0.345, 0.07, 0.04, 0.03, 8)          # epaule arriere
moss = m.build("moss_patches")

# empilement : mousse ajustee en hauteur (blobs poses au sol/socle)
all_parts = [base_lo, base_hi, body, red, moss]
jz = join(all_parts, "jizo")
jz.rotation_euler = (math.radians(0.6), math.radians(-1.0), math.radians(5))
bpy.ops.object.transform_apply(rotation=True)
collision_box("jizo", (0.54, 0.44, 0.9), (0, 0, 0.45))
pfinish("jizo", expected_dims=(0.56, 0.44, 0.90), tri_limit=(100, 3000), angles={"jizo": math.radians(45)}, yaw=22, pitch=13, margin=1.1)
