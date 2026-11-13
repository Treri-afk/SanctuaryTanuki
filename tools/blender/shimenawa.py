"""Shimenawa : corde sacree de paille torsadee de 3 m, 5 shide (papier en zigzag), 2 glands de paille.
Origine : milieu de la corde, dessous de la corde a z=0 (les shide pendent sous z=0). Avant = -Y. Pas de collision."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
rnd = random.Random(6)
LEN = 3.0
SAG = 0.30


def rr(x):                      # epaisseur : plus gros a gauche (-X), s'amincit vers la droite
    t = (x + LEN / 2) / LEN
    return 0.078 - 0.034 * t ** 1.2 + 0.004 * math.sin(t * 17)


def zc(x):                      # axe de la corde : point bas a x=0, dessous de la corde a z=0
    return rr(0) + SAG * (x / (LEN / 2)) ** 2 + 0.0


m = Mesh()
NRING = 40
pts = [(-LEN / 2 + LEN * i / (NRING - 1), 0.0, zc(-LEN / 2 + LEN * i / (NRING - 1))) for i in range(NRING)]
TW = 13.0       # rad / m : torsion (pas ~0.48 m)


def sec(i, a):
    x = pts[i][0]
    r = rr(x) * (1 + 0.26 * math.cos(3 * a + TW * x))
    return (r * math.cos(a), r * math.sin(a))
m.sweep(pts, sec, 12, "straw", caps=True, ref=(0, 1, 0))

# ligatures de corde (rope) la ou pendent les shide
SHX = [-1.1, -0.55, 0.0, 0.55, 1.1]
for xs in SHX:
    r0 = rr(xs) * 1.12
    c = [(xs + math.cos(2 * math.pi * k / 10) * 0.0, 0, 0) for k in range(1)]
    ring = []
    for k in range(11):
        a = 2 * math.pi * k / 10
        ring.append((xs + math.sin(a) * 0.016, math.cos(a) * r0, zc(xs) + math.sin(a) * 0.0 + (math.sin(a) * 0)))
    # boucle autour de la corde : cercle dans le plan YZ
    loop = [(xs, math.cos(2 * math.pi * k / 10) * r0, zc(xs) + math.sin(2 * math.pi * k / 10) * r0) for k in range(11)]
    m.tube(loop, [0.011] * 11, 5, "rope", caps=False)

# shide : double lame de papier pliee en zigzag
def shide(xs, phase, wid=0.09, panel=0.095, panels=4, amp=0.032, dx=0.0):
    top = zc(xs) - rr(xs) * 0.6
    ys = []
    pts_zz = []
    for k in range(panels + 1):
        y = -amp * (1 if (k + phase) % 2 else -1) * (0.55 if k == 0 else 1.0)
        z = top - panel * k * (1 + 0.04 * (k % 2))
        pts_zz.append((y, z))
    rings = []
    for (y, z) in pts_zz:
        rings.append([(xs + dx - wid / 2, y, z), (xs + dx + wid / 2, y, z),
                      (xs + dx + wid / 2, y + 0.0035, z), (xs + dx - wid / 2, y + 0.0035, z)])
    m.loft(rings, "paper", cap0=True, cap1=True)

for k, xs in enumerate(SHX):
    shide(xs, k % 2, dx=-0.05, panels=4 if k % 2 == 0 else 3)
    shide(xs, (k + 1) % 2, dx=0.05, panels=3 if k % 2 == 0 else 4)

# glands de paille aux deux extremites
def tassel(xe, sign):
    z0 = zc(xe) - 0.03
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2)
        d = 0.024 if k < 8 else 0.0
        L = rnd.uniform(0.28, 0.36)
        flare = rnd.uniform(0.025, 0.05)
        p = []
        for t in (0.0, 0.33, 0.66, 1.0):
            p.append((xe + math.cos(a) * (d + flare * t ** 1.5) - sign * 0.02 * t * 0, math.sin(a) * (d + flare * t ** 1.5), z0 - L * t))
        m.tube(p, [0.022, 0.02, 0.015, 0.002], 5, "straw", caps=False)
    # attache
    loop = [(xe, math.cos(2 * math.pi * k / 8) * 0.03, z0 - 0.07 + math.sin(2 * math.pi * k / 8) * 0.03) for k in range(9)]
    loop = [(xe + math.sin(2 * math.pi * k / 8) * 0.0, math.cos(2 * math.pi * k / 8) * 0.032, z0 - 0.07) for k in range(9)]
    m.tube(loop, [0.011] * 9, 5, "rope", caps=False)
tassel(-LEN / 2, -1)
tassel(LEN / 2, 1)

body = m.build("shimenawa")
empty("anchor_left", (-LEN / 2, 0, zc(-LEN / 2)), size=0.08)
empty("anchor_right", (LEN / 2, 0, zc(LEN / 2)), size=0.08)
pfinish("shimenawa", expected_dims=(3.1, 0.2, 0.9), tri_limit=(100, 2500), angles={"shimenawa": math.radians(55)},
        yaw=20, pitch=10, margin=1.0, lift_preview=0.4)
