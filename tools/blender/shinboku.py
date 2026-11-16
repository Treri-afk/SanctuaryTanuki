"""Shinboku : le cedre sacre du sanctuaire, un geant d'environ 24 m au tronc de 2 m, ceint d'une grosse corde de
paille (shimenawa) d'ou pendent des shide (papiers en zigzag), dans un enclos de petites bornes de pierre reliees
par une corde. On le voit de partout dans l'enceinte.
Objets : trunk, foliage (comme les cedres), rope (corde, papiers, bornes), trunk-col.
Lancer : blender --background --python tools/blender/shinboku.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree_util import *

SUGI = [("#21382A", "#33523A", "#466B42"), ("#243B2C", "#36553B", "#4B6F43"), ("#203527", "#2E4B37", "#3F6243")]
BARK = bark_color("#6E4532", "#45291E", moss="#5F7A38", moss_h=1.6, moss_r=0.8, seed=9)
STRAW = lin("#C9AE6A")
STRAW_DARK = lin("#A88B4E")
PAPER = lin("#F4F1E8")
STONE = lin("#8F8B82")
STONE_DARK = lin("#6E6A62")
ROPE = lin("#B0945A")

reset_scene()
t = Conifer(seed=23, H=24.0, z0=6.5, R=4.4, trunk_r=1.0, bark=BARK)
t.build_trunk(roots=9, sides=12, flare=0.75)
t.gen_clumps(30, size=(0.6, 0.5))
t.build_branches(dead=[(3.6, 0.8, 0.9), (4.4, 3.0, 1.1), (5.2, 4.9, 0.8), (5.8, 2.0, 0.7)])
t.build_foliage(SUGI, density=1.1)
t.build()

# ---------------------------------------------------------------- corde sacree autour du tronc
rng = random.Random(4)
R = TM()
ZR = 2.4
r_tr = t.trunk_r * (1 - ZR / (t.H * 1.02)) ** 0.9 * (1 + 0.75 * math.exp(-ZR / 0.4))
RR = r_tr + 0.07
n = 48
ring = []
for k in range(n + 1):
    a = 2 * math.pi * k / n
    c = t.axis(ZR)
    ring.append((c.x + RR * math.cos(a), c.y + RR * math.sin(a), ZR + 0.03 * math.sin(a * 3)))
R.tube(ring, [0.11] * (n + 1), 10, lambda i, j, p: STRAW if (i // 3) % 2 == 0 else STRAW_DARK, cap_end=False)
# torsade : un second boudin plus fin enroule
tw = []
for k in range(n * 3 + 1):
    a = 2 * math.pi * k / (n * 3)
    c = t.axis(ZR)
    rr = RR + 0.08 * math.cos(a * 18)
    tw.append((c.x + rr * math.cos(a), c.y + rr * math.sin(a), ZR + 0.08 * math.sin(a * 18)))
R.tube(tw, [0.045] * len(tw), 6, STRAW_DARK, cap_end=False)


def box(T, c, s, color, yaw=0.0):
    cx, cy, cz = c
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    ca, sa = math.cos(yaw), math.sin(yaw)
    v = []
    for z in (-1, 1):
        for y in (-1, 1):
            for x in (-1, 1):
                lx, ly = x * hx, y * hy
                v.append((cx + lx * ca - ly * sa, cy + lx * sa + ly * ca, cz + z * hz))
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return T.add(v, f, color)


# shide : quatre lames de papier en zigzag qui pendent de la corde
for k in range(6):
    a = 2 * math.pi * (k + 0.5) / 6
    c = t.axis(ZR)
    px, py = c.x + (RR + 0.1) * math.cos(a), c.y + (RR + 0.1) * math.sin(a)
    z = ZR - 0.1
    for j in range(4):
        off = 0.05 * (1 if j % 2 else -1)
        box(R, (px + off * -math.sin(a), py + off * math.cos(a), z - 0.07), (0.13, 0.012, 0.13), PAPER, yaw=a + math.pi / 2)
        z -= 0.13
# enclos : bornes de pierre et corde lache
NP = 12
RP = 3.3
posts = []
for k in range(NP):
    a = 2 * math.pi * k / NP + 0.13
    p = (RP * math.cos(a), RP * math.sin(a))
    box(R, (p[0], p[1], 0.3), (0.2, 0.2, 0.62), STONE if k % 2 else STONE_DARK, yaw=a)
    box(R, (p[0], p[1], 0.64), (0.14, 0.14, 0.06), STONE_DARK, yaw=a)
    posts.append(p)
for k in range(NP):
    p0, p1 = posts[k], posts[(k + 1) % NP]
    pts = []
    for s in range(7):
        u = s / 6
        pts.append((p0[0] + (p1[0] - p0[0]) * u, p0[1] + (p1[1] - p0[1]) * u, 0.55 - 0.12 * math.sin(math.pi * u)))
    R.tube(pts, [0.025] * 7, 5, ROPE, cap_end=False)
R.build("rope")

trunk_collision(1.35, 5.0)
finish_tree("shinboku", expected_dims=(9.0, 9.0, 24.0), tri_limit=(500, 12000),
            views=[("_back", dict(yaw=-130, pitch=4, margin=1.05))], margin=1.05)
