"""Bosquet de grands bambous (bamboo_tall, ~11 m) pour la bambouseraie de la mare : beaucoup de tiges droites et
serrees (comme a Arashiyama), le feuillage seulement dans le haut, qui se rejoint en voute au-dessus du sentier.
Objets : stalks, leaves, bamboo_tall-col (boite basse au pied).
Lancer : blender --background --python tools/blender/forest_bamboo_tall.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *

PALETTE.update({
    "bamboo_old":   "#8E9A52",    # vieilles tiges, plus jaunes
    "bamboo_dark":  "#5F7C3C",
})

reset_scene()
rnd = random.Random(31)
sb = Builder()
lb = Builder()

N = 11
for i in range(N):
    a = rnd.uniform(0, 2 * math.pi)
    r0 = 0.75 * math.sqrt(rnd.uniform(0.02, 1.0))     # pied des tiges dans un disque de 0,75 m
    H = rnd.uniform(8.6, 12.0)
    lean = rnd.uniform(0.2, 0.9)                      # la tete s'ecarte un peu, surtout en haut
    la = a + rnd.uniform(-0.6, 0.6)
    rad0 = rnd.uniform(0.055, 0.085)
    mat = "bamboo_old" if i % 4 == 0 else ("bamboo_dark" if i % 3 == 0 else "bamboo_green")
    ca, sa = math.cos(a), math.sin(a)
    nn = 12
    nodes = []
    for k in range(nn + 1):
        t = k / nn
        out = lean * t ** 2.4
        nodes.append((r0 * ca + out * math.cos(la), r0 * sa + out * math.sin(la), H * t))
    rad = lambda t: rad0 * (1.0 - 0.5 * t)
    sb.tube(nodes, [rad(k / nn) for k in range(nn + 1)], sides=5, m=mat)
    for k in range(2, nn, 2):                         # noeuds (un sur deux : assez a cette hauteur)
        p = Vector(nodes[k])
        d = (p - Vector(nodes[k - 1])).normalized()
        sb.tube([p - d * 0.025, p + d * 0.025], [rad(k / nn) * 1.35] * 2, sides=5, m="bamboo_node", caps=False)
    sb.tube([(nodes[0][0], nodes[0][1], 0.0), (nodes[0][0], nodes[0][1], 0.06)], [rad0 * 1.5, rad0 * 1.4], sides=5,
            m="bamboo_node")
    # feuillage : petits rameaux de lames dans le tiers haut, plus fournis vers la tete
    for k in range(int(nn * 0.68), nn + 1):
        t = k / nn
        c = Vector(nodes[k])
        nb = 2 if t < 0.9 else 3
        sz = 0.42 + 0.25 * t
        base = rnd.uniform(0, 2 * math.pi)
        for s_ in range(nb):
            b = base + s_ * 2 * math.pi / nb + rnd.uniform(-0.4, 0.4)
            pitch = math.radians(rnd.uniform(12, 38))
            d = Vector((math.cos(b) * math.cos(pitch), math.sin(b) * math.cos(pitch), -math.sin(pitch)))
            blob_rot(lb, c + d * sz * 0.95, (sz, sz * 0.2, sz * 0.07),
                     "bamboo_leaf" if (i + k + s_) % 3 else "bamboo_green", rot=(0, pitch, b), subdiv=1,
                     noise=0.06, seed=i * 31 + k * 3 + s_, bottom=0.8)

ground_clamp(sb)
stalks = sb.build("stalks")
leaves = lb.build("leaves")
collision_box("bamboo_tall", (1.3, 1.3, 0.5), loc=(0.0, 0.0, 0.25))
finish("bamboo_tall", expected_dims=(4.0, 4.0, 11.5), tri_limit=(500, 5000),
       angles={"stalks": math.radians(50), "leaves": math.radians(180)}, margin=1.05,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.05))])
