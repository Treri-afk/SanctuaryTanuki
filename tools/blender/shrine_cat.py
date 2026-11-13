"""Chat du sanctuaire assis (0,38 m), stylise : corps en poire, grosse tete ronde, grandes oreilles dressees, queue enroulee
autour des pattes, pelage blanc a taches orange, collier rouge a grelot. Pas de bevel (formes douces).
Avant = -Y ; la tete est tournee d'un quart vers +X (vue 3/4). Origine au sol, centree.
Lancer : blender --background --python tools/blender/shrine_cat.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *
from mathutils import Quaternion

reset_scene()
M = Mesh()


def xf(v0, matrix):
    """Applique une matrice 4x4 aux sommets v0.. du mesh M."""
    for i in range(v0, len(M.v)):
        M.v[i] = tuple(matrix @ Vector(M.v[i]))


def about(pivot, rot):
    p = Vector(pivot)
    return Matrix.Translation(p) @ rot.to_4x4() @ Matrix.Translation(-p)


def dist(a, b, sc=(1, 1, 1)):
    return math.sqrt(sum(((a[i] - b[i]) / sc[i]) ** 2 for i in range(3)))


def ell(c, sc, m, N=16, R=9):
    """Ellipsoide de revolution (lathe) : bien plus propre qu'une icosphere pour la silhouette."""
    prof = [(math.sin(math.pi * i / R), c[2] - math.cos(math.pi * i / R) * sc[2]) for i in range(R + 1)]
    M.lathe(prof, N, m, center=(c[0], c[1]), scale=(sc[0], sc[1]))


W, O, D = "cat_white", "cat_orange", "cat_dark"

# ------------------------------------------------------------------ corps (poire) + hanches + pattes
f0 = len(M.f)
body_prof = [(0.090, 0.0), (0.106, 0.03), (0.112, 0.085), (0.102, 0.148), (0.082, 0.20), (0.062, 0.24), (0.050, 0.262)]
M.lathe(body_prof, 20, W, center=(0.0, 0.016), scale=(1.0, 1.07))
ell((0.086, 0.03, 0.077), (0.060, 0.094, 0.077), W, 14, 8)       # hanche cote +X
ell((-0.086, 0.03, 0.077), (0.060, 0.094, 0.077), W, 14, 8)      # hanche cote -X
for sx in (-1, 1):
    ell((sx * 0.041, -0.074, 0.098), (0.031, 0.033, 0.095), W, 10, 7)   # patte avant
    ell((sx * 0.043, -0.097, 0.022), (0.034, 0.047, 0.024), W, 10, 6)   # pied avant
    ell((sx * 0.076, -0.06, 0.022), (0.036, 0.052, 0.024), W, 10, 6)    # pied arriere

# taches orange : large tache cote +X (visible en vue 3/4), tache sur la hanche, petite tache cote -X
recolor(M, f0, lambda c: O if (dist(c, (0.074, 0.035, 0.17), (1.0, 1.0, 1.15)) < 0.075
                               or dist(c, (0.10, 0.03, 0.095)) < 0.05
                               or dist(c, (-0.09, 0.045, 0.12)) < 0.045) else None)

# ------------------------------------------------------------------ tete (groupe oriente d'un quart vers +X)
HC = (0.0, -0.040, 0.272)
h0 = len(M.v)
hf0 = len(M.f)
ell(HC, (0.090, 0.073, 0.068), W, 18, 10)                                            # crane + joues
ell((HC[0], HC[1] - 0.052, HC[2] - 0.026), (0.034, 0.024, 0.022), W, 10, 6)          # petit museau
# oreilles : cones evases, droits, un peu ecartes
for sx, m_out in ((1, O), (-1, W)):
    tf = Matrix.Translation((HC[0] + sx * 0.052, HC[1] + 0.006, HC[2] + 0.046)) @ Matrix.Rotation(-sx * 0.30, 4, "Y") \
        @ Matrix.Rotation(-0.08, 4, "X")
    v0 = len(M.v)
    M.lathe([(0.034, 0.0), (0.029, 0.026), (0.0, 0.066)], 6, m_out, center=(0, 0), scale=(1.0, 0.5))
    xf(v0, tf)
    v1 = len(M.v)
    M.lathe([(0.020, 0.004), (0.016, 0.018), (0.0, 0.050)], 6, W if sx == 1 else O, center=(0, -0.012), scale=(1.0, 0.4))
    xf(v1, tf)
# yeux (ovales, ecartes), nez, moustaches
for sx in (-1, 1):
    ell((HC[0] + sx * 0.037, HC[1] - 0.063, HC[2] + 0.004), (0.0095, 0.006, 0.0135), D, 8, 6)
ell((HC[0], HC[1] - 0.074, HC[2] - 0.011), (0.0095, 0.007, 0.0075), D, 8, 5)
for sx in (-1, 1):
    for k, dz in enumerate((0.0, -0.011)):
        M.tube([(HC[0] + sx * 0.040, HC[1] - 0.068, HC[2] - 0.016 + dz),
                (HC[0] + sx * 0.078, HC[1] - 0.075, HC[2] - 0.012 + dz * 1.6 + 0.004)], [0.0016, 0.0009], 3, D, caps=True)
# tache orange : calotte cote +X (oreille orange comprise)
recolor(M, hf0, lambda c: O if (dist(c, (HC[0] + 0.046, HC[1] + 0.005, HC[2] + 0.052)) < 0.058
                                and c[2] > HC[2] - 0.004 and c[1] > HC[1] - 0.05) else None)
# tete tournee d'un quart vers +X
xf(h0, about((HC[0], HC[1] + 0.02, HC[2]), Quaternion((0, 0, 1), 0.34).to_matrix()))

# ------------------------------------------------------------------ collier rouge + grelot
ring = []
for i in range(17):
    a = 2 * math.pi * i / 16
    ring.append((0.082 * math.cos(a), 0.016 + 0.088 * math.sin(a), 0.212 + 0.010 * math.sin(a)))
M.tube(ring, [0.0085] * len(ring), 6, "lacquer_red", caps=False)
ell((0.0, -0.092, 0.196), (0.0135, 0.0125, 0.0135), "metal_gold", 8, 5)

# ------------------------------------------------------------------ queue : enroulee autour des pattes, cote +X
tail = [(0.0, 0.108, 0.030), (0.074, 0.112, 0.031), (0.130, 0.074, 0.032), (0.147, -0.002, 0.033),
        (0.130, -0.066, 0.034), (0.100, -0.100, 0.040), (0.074, -0.114, 0.056), (0.066, -0.118, 0.072)]
tr = [0.031, 0.030, 0.0285, 0.0265, 0.0245, 0.0225, 0.0185, 0.0085]
M.tube(tail, tr, 8, lambda i, j: W if i >= 5 else O, caps=True)
M.fm[-1] = M._mi(W)          # le bout de la queue est blanc (y compris le capuchon)

cat = M.build("cat")

collision_box("shrine_cat", (0.25, 0.26, 0.36), (0.0, 0.0, 0.18))

pfinish("shrine_cat", expected_dims=(0.30, 0.30, 0.38), tri_limit=(300, 2500),
        angles={"cat": math.radians(80)}, yaw=28, pitch=14, margin=1.0,
        extra_views=[("_b", dict(yaw=-35, pitch=14, margin=1.0))])
