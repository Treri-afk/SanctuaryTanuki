"""Marteau de charpentier japonais (genno) : tete d'acier forge a deux faces (une plate, une legerement
bombee), manche de chene ovale qui s'evase vers le bout, deux coins d'acier dans l'oeil.
Tenu en main : manche vertical, origine au bout du manche, tete en haut. Pas de collision.
Lancer : blender --background --python tools/blender/hammer.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1

Z_HEAD = 0.3400          # axe de la tete
HALF = 0.0510            # demi-longueur de la tete
Z_TOP = 0.3620           # haut du manche, juste au-dessus de la tete

# ------------------------------------------------------------------ manche (chene, section ovale, axe le long de X)
H = Mesh()


def curve(t):
    """Le manche n'est pas droit : tres leger galbe vers l'arriere."""
    return (0.0, -0.0032 * math.sin(math.pi * t) + 0.0012 * t)


# (t, demi-largeur X, demi-largeur Y) : fin sous l'oeil, large et evase au bout
radii = [
    (0.000, 0.0104, 0.0068),   # tout le bout, arrondi
    (0.016, 0.0168, 0.0110),
    (0.050, 0.0183, 0.0119),   # renflement du talon (la main bute dessus)
    (0.120, 0.0158, 0.0103),
    (0.300, 0.0137, 0.0090),
    (0.520, 0.0126, 0.0083),   # creux de la prise
    (0.720, 0.0125, 0.0082),
    (0.870, 0.0132, 0.0087),
    (0.942, 0.0141, 0.0093),   # epaulement sous l'oeil
    (0.982, 0.0134, 0.0088),
    (1.000, 0.0126, 0.0083),
]
# les changements de teinte tombent sur les ruptures de galbe : on lit un bois use, pas une bague peinte
mats = [(0.0, "oak_dark"), (0.016, "oak"), (0.120, "oak_worn"), (0.870, "oak"), (0.982, "oak_dark")]
wooden_handle(H, 0.0, Z_TOP, radii, mats, sides=12, expo=2.5, curve=curve)
handle = H.build("handle")

# ------------------------------------------------------------------ tete (barre forgee octogonale le long de X)
T = Mesh()
# (x, demi-hauteur Z, demi-profondeur Y) ; l'oeil est renfle, les faces se retrecissent
prof = [
    (-HALF,          0.0122, 0.0112),   # face plate : petit chanfrein
    (-HALF + 0.0040, 0.0144, 0.0133),
    (-HALF + 0.015,  0.0150, 0.0138),
    (-0.018,         0.0166, 0.0152),   # renflement de l'oeil
    (0.018,          0.0166, 0.0152),
    (0.023,          0.0162, 0.0148),
    (HALF - 0.017,   0.0149, 0.0137),
    (HALF - 0.005,   0.0140, 0.0129),   # amorce de la face bombee
    (HALF - 0.0014,  0.0124, 0.0114),
    (HALF,           0.0088, 0.0081),
]
rings = [ring((x, 0, Z_HEAD), (0, 1, 0), (0, 0, 1), ry, rz, 8, 3.4) for x, rz, ry in prof]


def head_mat(i, j):
    # les deux faces sont polies par l'usage, le corps reste forge et sombre
    if i <= 0 or i >= len(prof) - 3:
        return "steel"
    if i == 1 or i == len(prof) - 4:
        return "steel_dark"
    return "forge"


T.loft(rings, head_mat, True, True)
head = T.build("head", bevel=0.0028)

# ------------------------------------------------------------------ coins d'acier dans l'oeil + bois de fil
W = Mesh()
FACES = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 3, 7, 4), (1, 5, 6, 2), (0, 4, 5, 1), (3, 2, 6, 7)]
z_eye = Z_HEAD + 0.0120
for sx in (-0.0056, 0.0056):
    verts = [
        (sx - 0.0021, -0.0074, z_eye), (sx + 0.0021, -0.0074, z_eye),
        (sx + 0.0021, 0.0074, z_eye), (sx - 0.0021, 0.0074, z_eye),
        (sx - 0.0017, -0.0068, Z_TOP + 0.0004), (sx + 0.0017, -0.0068, Z_TOP + 0.0004),
        (sx + 0.0017, 0.0068, Z_TOP + 0.0004), (sx - 0.0017, 0.0068, Z_TOP + 0.0004),
    ]
    W.add(verts, FACES, "steel")
wedges = W.build("wedges")

collision = None

pfinish("hammer", expected_dims=(0.102, 0.034, 0.362), tri_limit=(250, 1800),
        angles={"handle": math.radians(50), "head": math.radians(18), "wedges": math.radians(14)},
        yaw=28, pitch=14, margin=1.0,
        extra_views=[("_b", dict(yaw=-62, pitch=22, margin=0.85))])
