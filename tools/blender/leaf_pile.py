"""Tas de feuilles d'automne balayees : ~0.9 m x 0.35 m. Origine au sol centree, pas de collision."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
rnd = random.Random(7)
RX, RY, H = 0.37, 0.32, 0.30


def height(x, y):
    q = (x / RX) ** 2 + (y / RY) ** 2
    base = max(0.0, 1.0 - q) ** 0.85
    bump = 1.0 + 0.18 * noise3(x * 5, y * 5, 0, 2.0)
    # deuxieme bosse decalee : tas asymetrique
    q2 = ((x + 0.18) / 0.26) ** 2 + ((y - 0.10) / 0.22) ** 2
    return H * base * bump * 0.85 + 0.05 * max(0.0, 1 - q2) ** 1.2


def pick_color(x, y):
    n = noise3(x * 4.0, y * 4.0, 1.0, 5.0) + rnd.uniform(-0.45, 0.45)
    if n < -0.05:
        return "foliage_red"
    if n < 0.42:
        return "foliage_orange"
    return "foliage_light"


# --- masse du tas : surface lisse de revolution (couleurs par plaques)
mound = Mesh()
prof_f = [0.0, 0.22, 0.45, 0.66, 0.84, 0.97]
N = 18
rings = []
for i, f in enumerate(prof_f[::-1][::-1]):
    ring = []
    for j in range(N):
        a = 2 * math.pi * j / N
        k = 1.0 + 0.06 * noise3(math.cos(a) * 2, math.sin(a) * 2, f, 9.0)
        x, y = math.cos(a) * RX * f * k, math.sin(a) * RY * f * k
        ring.append((x, y, max(height(x, y) * 0.93, 0.0) + (0.0 if f < 0.95 else 0.012)))
    rings.append(ring)
rings.reverse()      # de l'exterieur vers le centre
cols = {}
def mcol(i, j):
    x, y, _ = rings[i][j]
    return pick_color(x * 0.9, y * 0.9) if False else (
        "foliage_red" if noise3(x * 4, y * 4, 0, 5.0) < -0.2 else ("foliage_light" if noise3(x * 4, y * 4, 0, 5.0) > 0.3 else "foliage_orange"))
mound.loft(rings, mcol, cap0=True, cap1=True)

# --- feuilles
leaves = Mesh()
def put(x, y, flat=False):
    z = height(x, y)
    e = 0.01
    gx = (height(x + e, y) - height(x - e, y)) / (2 * e)
    gy = (height(x, y + e) - height(x, y - e)) / (2 * e)
    n = Vector((-gx, -gy, 1.0)).normalized()
    if flat:
        n = Vector((0, 0, 1))
    else:
        n = (n + Vector((rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45), rnd.uniform(0, 0.3)))).normalized()
    kind = "star" if rnd.random() < 0.22 else "lens"
    L = rnd.uniform(0.14, 0.19)
    z = max(z + 0.006, 0.5 * L * math.sqrt(max(0.0, 1 - n.z * n.z)) * 0.9 + 0.012)
    add_leaf(leaves, (x, y, z), n, rnd.uniform(0, 6.28), L,
             L * (0.62 if kind == "lens" else 0.95), pick_color(x, y), kind=kind, t=0.008, curl=0.014)

count = 0
while count < 125:
    a = rnd.uniform(0, 2 * math.pi)
    r = math.sqrt(rnd.random()) * 1.0
    x, y = math.cos(a) * RX * r, math.sin(a) * RY * r
    if height(x, y) < 0.015 and r < 0.8:
        continue
    put(x, y)
    count += 1
for k in range(10):          # feuilles epargnees autour du tas
    a = rnd.uniform(0, 2 * math.pi)
    r = rnd.uniform(1.0, 1.18)
    put(math.cos(a) * RX * r, math.sin(a) * RY * r, flat=True)

mound.build("leaf_mound")
leaves.build("leaf_pieces")
pfinish("leaf_pile", expected_dims=(0.9, 0.9, 0.35), tri_limit=(100, 3000),
        angles={"leaf_mound": math.radians(60), "leaf_pieces": math.radians(60)}, yaw=25, pitch=32, margin=1.0)
