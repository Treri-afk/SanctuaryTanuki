"""Touffe de bambous (bamboo_clump, 5 m). Objets : stalks, leaves, bamboo_clump-col (boite basse au pied)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *

reset_scene()
rnd = random.Random(12)
sb = Builder()
lb = Builder()

N = 8
tops = []
for i in range(N):
    a = 2 * math.pi * i / N + rnd.uniform(-0.3, 0.3)
    r0 = rnd.uniform(0.12, 0.38)                  # position au sol
    H = [5.0, 4.5, 4.8, 4.2, 4.9, 4.4, 4.7, 4.0][i]
    lean = rnd.uniform(0.35, 0.8)                 # inclinaison vers l'exterieur a la tete
    curl = rnd.uniform(-0.15, 0.15)               # courbure laterale
    rad0 = rnd.uniform(0.042, 0.055)
    ca, sa = math.cos(a), math.sin(a)
    nodes = []
    nn = 9
    for k in range(nn + 1):
        t = k / nn
        z = H * t
        out = lean * t ** 2.2 * 1.0                # courbe vers l'exterieur surtout en haut
        side = curl * t ** 1.5 * 1.0
        x = r0 * ca + out * ca - side * sa
        y = r0 * sa + out * sa + side * ca
        nodes.append((x, y, z))
    rad = lambda t: rad0 * (1.0 - 0.55 * t)
    pts = [nodes[0]] + nodes[1:]
    sb.tube(pts, [rad(k / nn) for k in range(nn + 1)], sides=5, m="bamboo_green")
    # noeuds : petits anneaux un peu plus larges
    for k in range(1, nn + 1):
        p = Vector(nodes[k])
        prev = Vector(nodes[k - 1])
        d = (p - prev).normalized()
        c = p - d * 0.02
        e = p + d * 0.02
        sb.tube([c, e], [rad(k / nn) * 1.45, rad(k / nn) * 1.45], sides=5, m="bamboo_node", caps=False)
    # base : noeud epais proche du sol
    sb.tube([(nodes[0][0], nodes[0][1], 0.0), (nodes[0][0], nodes[0][1], 0.05)], [rad0 * 1.5, rad0 * 1.4], sides=5, m="bamboo_node")
    tops.append((nodes, rad0, a, H))

    # feuillage : touffes de lames tombantes sur le haut de la tige
    tufts = [(1.0, 3, 0.34), (0.84, 2, 0.30), (0.70, 2, 0.26)] if i % 2 == 0 else [(1.0, 3, 0.34), (0.86, 3, 0.30)]
    for k, (tt, nb, sz) in enumerate(tufts):
        idx = min(nn, int(round(tt * nn)))
        c = Vector(nodes[idx])
        base = a + k * 2.1 + rnd.uniform(0, 1.0)
        for s_ in range(nb):
            b = base + s_ * 2 * math.pi / nb + rnd.uniform(-0.35, 0.35)
            pitch = math.radians(rnd.uniform(18, 42))
            d = Vector((math.cos(b) * math.cos(pitch), math.sin(b) * math.cos(pitch), -math.sin(pitch)))
            blob_rot(lb, c + d * sz * 0.95 + Vector((0, 0, 0.03)), (sz, sz * 0.2, sz * 0.07),
                     "bamboo_leaf" if (i + k + s_) % 3 else "bamboo_green", rot=(0, pitch, b), subdiv=1,
                     noise=0.05, seed=i * 5 + k * 2 + s_, bottom=0.8)

ground_clamp(sb)
stalks = sb.build("stalks")
leaves = lb.build("leaves")
collision_box("bamboo_clump", (1.0, 1.0, 0.5), loc=(0.0, 0.0, 0.25))
finish("bamboo_clump", expected_dims=(2.5, 2.5, 5.0), tri_limit=(100, 3000),
       angles={"stalks": math.radians(50), "leaves": math.radians(180)}, margin=1.05,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.05))])
