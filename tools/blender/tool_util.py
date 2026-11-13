"""Helpers des outils de main (marteau, cisaille, serpe) et des carpes.

Ces modeles sont vus de tres pres en vue subjective : on soigne les sections (manches ovales,
lames a biseau) plutot que le nombre de pieces. N'altere pas common.py.
Importer avec : from tool_util import *
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *          # common.* + Mesh, pfinish, bx, cyl, merge, recolor ...
import common
from mathutils import Vector, Matrix

PALETTE.update({
    "steel":        "#9AA2A8",   # acier poli (plat de lame, face de frappe)
    "steel_edge":   "#C3CBD0",   # fil de la lame, tres clair
    "steel_dark":   "#5C6268",   # acier dans l'ombre, dos de lame
    "forge":        "#41464C",   # acier forge brut, bleute
    "patina":       "#6E6356",   # patine / amorce de rouille sur le dos
    "oak":          "#B08A58",   # manche en chene blanc
    "oak_worn":     "#A47F4E",   # zone de prise, polie par la main
    "oak_dark":     "#6E5335",   # bout de manche, bois de fil
    "brass":        "#A8853C",   # virole
    "koi_white":    "#F2EEE6",
    "koi_red":      "#CE4428",
    "koi_black":    "#272530",
    "koi_gold":     "#DFAE41",
    "koi_blue":     "#7F95AE",
    "koi_orange":   "#DD7B37",
    "koi_fin":      "#E0D6C8",
    "koi_eye":      "#2A2630",
})


# ------------------------------------------------------------------ sections
def ring(c, u, v, ru, rv, n=12, expo=2.0, phase=0.0):
    """Anneau ferme de n points autour de c, dans le plan (u, v).
    expo = 2 : ellipse ; expo > 2 : section rectangulaire a coins arrondis (manche, barre forgee)."""
    c, u, v = Vector(c), Vector(u), Vector(v)
    pts = []
    for j in range(n):
        a = phase + 2.0 * math.pi * j / n
        ca, sa = math.cos(a), math.sin(a)
        k = (abs(ca) ** expo + abs(sa) ** expo) ** (-1.0 / expo)
        pts.append(c + u * (ru * ca * k) + v * (rv * sa * k))
    return pts


def blade_section(width, half_thick, bevel=0.30, back=0.0):
    """Section de lame (u = du dos vers le fil, v = epaisseur), en 8 points fermes.
    Le dos est plein, le fil s'amincit : c'est ce profil qui fait lire « lame » et non « plaque ».
    bevel : part de la largeur occupee par le biseau. back : arrondi du dos (0 = plat)."""
    w, t = width, half_thick
    b = 1.0 - bevel
    return [
        (-back * w, 0.0),            # dos
        (0.08 * w, t * 0.96),
        (b * 0.55 * w, t * 0.92),
        (b * w, t * 0.74),           # depart du biseau
        (w, 0.0),                    # fil
        (b * w, -t * 0.74),
        (b * 0.55 * w, -t * 0.92),
        (0.08 * w, -t * 0.96),
    ]


def frames(path, up=(0, 0, 1)):
    """Repere (tangente, u, v) le long d'une polyligne, sans vrille (transport parallele)."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    tans = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        tans.append(t.normalized())
    ref = Vector(up)
    if abs(tans[0].dot(ref)) > 0.95:
        ref = Vector((1, 0, 0))
    v = (ref - tans[0] * ref.dot(tans[0])).normalized()
    out = []
    for i in range(n):
        t = tans[i]
        v = (v - t * v.dot(t)).normalized()
        u = v.cross(t)
        out.append((pts[i], u, v))
    return out


def sweep_profile(M, path, sec, m, up=(0, 0, 1), cap0=True, cap1=True, flip_u=False):
    """Balaye une section 2D le long d'une polyligne. sec(i) -> [(u, v), ...] (meme longueur partout).
    m : nom de materiau ou callable(i, j)."""
    rings = []
    for i, (p, u, v) in enumerate(frames(path, up)):
        if flip_u:
            u = -u
        rings.append([p + u * su + v * sv for su, sv in sec(i)])
    M.loft(rings, m, cap0, cap1)
    return rings


def lerp_list(a, b, t):
    return [x + (y - x) * t for x, y in zip(a, b)]


# ------------------------------------------------------------------ manche
def wooden_handle(M, z0, z1, radii, mats, sides=12, expo=2.3, curve=None, phase=0.0):
    """Manche ovale le long de Z, entre z0 et z1. radii : [(t, rx, ry), ...] avec t de 0 (bas) a 1 (haut).
    mats : [(t, nom)] triee ; le materiau d'un anneau est celui du dernier t <= celui de l'anneau.
    curve(t) -> (dx, dy) decale l'axe (manche jamais parfaitement droit)."""
    ts = [r[0] for r in radii]
    rings, ring_mat = [], []
    for t, rx, ry in radii:
        z = z0 + (z1 - z0) * t
        dx, dy = curve(t) if curve else (0.0, 0.0)
        rings.append(ring((dx, dy, z), (1, 0, 0), (0, 1, 0), rx, ry, sides, expo, phase))
        cur = mats[0][1]
        for mt, mn in mats:
            if t >= mt - 1e-6:
                cur = mn
        ring_mat.append(cur)
    M.loft(rings, lambda i, j: ring_mat[i], True, True)
    return rings, ts


def absorb(M, other, offset=(0, 0, 0)):
    """Ajoute le contenu d'un autre Mesh (avec ses materiaux) dans M, decale de offset."""
    ox, oy, oz = offset
    base = len(M.v)
    M.v += [(x + ox, y + oy, z + oz) for x, y, z in other.v]
    for fc, mi in zip(other.f, other.fm):
        M.f.append(tuple(i + base for i in fc))
        M.fm.append(M._mi(other.mats[mi]))
