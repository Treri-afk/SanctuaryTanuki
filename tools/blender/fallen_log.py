"""Tronc couche mousseux : 2.5 m x 0.5 m de diametre, axe X, avant -Y. Collision boite."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
rnd = random.Random(21)
L = 2.5
NA = 20        # sections autour
NX = 14        # anneaux le long du tronc


def radius(x):
    t = (x + L / 2) / L
    flare = 0.03 * max(0.0, 1 - t * 7)                       # empattement racinaire a un bout
    return 0.245 + flare + 0.012 * math.sin(t * 9 + 1) - 0.012 * t


def centre(x):
    t = (x + L / 2) / L
    return (0.04 * math.sin(t * 3.2), radius(x) + 0.03 * math.sin(t * 5) * 0)


m = Mesh()
rings = []
for i in range(NX):
    x = -L / 2 + L * i / (NX - 1)
    cy, cz = centre(x)
    r0 = radius(x)
    ring = []
    for j in range(NA):
        a = 2 * math.pi * j / NA
        # ecorce : fissures longitudinales + bosses
        bark = 1 + 0.09 * math.sin(a * 4 + x * 0.5) + 0.03 * noise3(x * 2.0, math.cos(a), math.sin(a), 3.0)
        rr = r0 * bark
        if i in (0, NX - 1):
            rr *= 0.98
        # extremite brisee : bout deviant (irregulier)
        xx = x
        if i == NX - 1:
            xx += 0.05 * math.sin(a * 2 + 1) + 0.04 * noise3(a, 0, 1, 9.0)
        ring.append((xx, cy + rr * math.cos(a) * 0.98, cz + rr * math.sin(a)))
    rings.append(ring)

def col(i, j):
    a = 2 * math.pi * j / NA
    x = -L / 2 + L * i / (NX - 1)
    h = math.sin(a)
    n = noise3(x * 1.1, a * 0.9, 1.0, 11.0)
    if h > 0.5 and n > -0.5:
        return "moss"
    if h > 0.2 and n > 0.45:
        return "moss"
    if i == NX - 2 or i == 0:
        return "wood_faded"
    if noise3(x * 0.9, a * 1.3, 4.0, 5.0) > 0.42:
        return "wood_faded"
    return "wood_dark"
m.loft(rings, col, cap0=False, cap1=False)
# disques de bout (bois clair, anneaux de croissance par disque plus petit un peu en retrait)
for idx, sgn in ((0, -1), (NX - 1, 1)):
    ring = rings[idx]
    cx = sum(p[0] for p in ring) / NA
    cy_ = sum(p[1] for p in ring) / NA
    cz_ = sum(p[2] for p in ring) / NA
    outer = [(p[0], p[1], p[2]) for p in ring]
    shrunk1 = [(cx - sgn * 0.012, cy_ + (p[1] - cy_) * 0.86, cz_ + (p[2] - cz_) * 0.86) for p in ring]
    shrunk2 = [(cx - sgn * 0.02, cy_ + (p[1] - cy_) * 0.5, cz_ + (p[2] - cz_) * 0.5) for p in ring]
    rr = [outer, shrunk1, shrunk2]
    # petit coeur : on boucle 3 anneaux
    m.loft(rr if sgn < 0 else rr, "wood_light" if True else "wood_faded", cap0=False, cap1=True)
# souches de branches
for (xb, ang, ln) in ((-0.55, 150, 0.15), (0.4, 35, 0.12), (0.9, 100, 0.09)):
    cy, cz = centre(xb)
    a = math.radians(ang)
    r = radius(xb)
    p0 = (xb, cy + math.cos(a) * r * 0.8, cz + math.sin(a) * r * 0.8)
    p1 = (xb + 0.05, cy + math.cos(a) * (r + ln * 0.5), cz + math.sin(a) * (r + ln * 0.5))
    p2 = (xb + 0.08, cy + math.cos(a) * (r + ln), cz + math.sin(a) * (r + ln))
    m.tube([p0, p1, p2], [0.05, 0.042, 0.036], 7, "wood_dark", caps=False)
    m.tube([p2, (p2[0] + 0.005, p2[1] + math.cos(a) * 0.01, p2[2] + math.sin(a) * 0.01)], [0.036, 0.03], 7, "wood_light", caps=True)
# mousse : volumes sur le dessus
for k in range(5):
    x = rnd.uniform(-1.0, 1.0)
    cy, cz = centre(x)
    r = radius(x)
    m.blob((x, cy + rnd.uniform(-0.08, 0.08), cz + r * 0.92), (rnd.uniform(0.12, 0.2), rnd.uniform(0.08, 0.12), 0.045),
           "moss", subdiv=2, noise=0.14, seed=k * 2.1, bottom=0.6)
for k in range(4):
    x = rnd.uniform(-1.1, 1.1)
    cy, cz = centre(x)
    r = radius(x)
    m.blob((x, cy - r * 0.85 * (1 if k % 2 else -1), 0.05), (0.15, 0.08, 0.06), "moss", subdiv=1, noise=0.1, seed=k, bottom=0.6)
log = m.build("fallen_log")
bpy.ops.object.select_all(action="DESELECT")
# pose au sol
mn, mx = world_bounds([log])
log.rotation_euler = (0, math.radians(0.4), math.radians(-6))
bpy.ops.object.select_all(action="DESELECT"); log.select_set(True); bpy.context.view_layer.objects.active = log
bpy.ops.object.transform_apply(location=True, rotation=True)
mn, mx = world_bounds([log])
log.location.z -= mn.z
log.location.x -= (mn.x + mx.x) / 2
log.location.y -= (mn.y + mx.y) / 2
bpy.ops.object.transform_apply(location=True)
collision_box("fallen_log", (2.5, 0.5, 0.5), (0, 0, 0.25))
pfinish("fallen_log", expected_dims=(2.5, 0.55, 0.55), tri_limit=(100, 3000), angles={"fallen_log": math.radians(30)},
        yaw=40, pitch=22, margin=1.05)
