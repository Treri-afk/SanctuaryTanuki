"""Helpers des animaux (renard, tanuki), dans l'esprit du chat du sanctuaire (shrine_cat.py) :
volumes de revolution lisses plutot que des icospheres, aplats de couleur, taches definies par zones.
Importer avec : from creature_util import *
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *            # Mesh, pfinish, recolor, absorb, PALETTE ...
from mathutils import Vector, Matrix, Quaternion

PALETTE.update({
    "fox_fur":     "#CF6F2C",
    "fox_fur_dk":  "#A9532A",   # dos, un ton plus sombre
    "fox_cream":   "#F2E3C8",
    "fox_dark":    "#2E2420",   # chaussettes, dos des oreilles, truffe
    "fox_ear_in":  "#E8C59B",
    "tanuki_fur":  "#8C7862",
    "tanuki_back": "#6B5A4A",   # selle sombre des epaules
    "tanuki_lite": "#BBA586",   # joues, front
    "tanuki_belly": "#D3C2A2",
    "tanuki_dark": "#352C27",
    "tanuki_leaf": "#73993F",
    "eye_dark":    "#1F1A1E",
    "eye_shine":   "#F6F1E6",
})


def ell(M, c, sc, m, N=16, R=9):
    """Ellipsoide (lathe) centre en c, demi-axes sc."""
    prof = [(math.sin(math.pi * i / R), c[2] - math.cos(math.pi * i / R) * sc[2]) for i in range(R + 1)]
    M.lathe(prof, N, m, center=(c[0], c[1]), scale=(sc[0], sc[1]))


def xf(M, v0, matrix):
    """Applique une matrice 4x4 aux sommets v0.. du mesh."""
    for i in range(v0, len(M.v)):
        M.v[i] = tuple(matrix @ Vector(M.v[i]))


def about(pivot, rot3):
    p = Vector(pivot)
    return Matrix.Translation(p) @ rot3.to_4x4() @ Matrix.Translation(-p)


def dist(a, b, sc=(1, 1, 1)):
    return math.sqrt(sum(((a[i] - b[i]) / sc[i]) ** 2 for i in range(3)))


def cone(M, base, height, r, m, flat=0.5, tilt=(0.0, 0.0), sides=8, tip_round=0.0):
    """Cone (oreille) pose sur base, axe Z incline de tilt=(rx, ry) radians ; aplati en Y (flat)."""
    v0 = len(M.v)
    prof = [(r, 0.0), (r * 0.82, height * 0.45)]
    if tip_round:
        prof.append((r * tip_round, height * 0.9))
    prof.append((0.0, height))
    M.lathe(prof, sides, m, center=(0, 0), scale=(1.0, flat))
    tf = Matrix.Translation(base) @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X")
    xf(M, v0, tf)
