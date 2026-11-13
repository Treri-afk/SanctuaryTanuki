"""Serpe japonaise (kama) : lame legerement courbe, noircie a la forge avec un biseau poli le long du fil,
col forge qui sort d'une virole de fer, manche de chene ovale qui s'evase au bout.
La lame part vers -X, dans le plan XZ, fil en bas (on coupe en tirant).
Tenue en main : manche vertical, origine au bout du manche. Pas de collision.
Lancer : blender --background --python tools/blender/sickle.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1

Z_HANDLE = 0.276      # haut du bois
Z_FERRULE = 0.298     # haut de la virole

# ------------------------------------------------------------------ manche
H = Mesh()
radii = [
    (0.000, 0.0112, 0.0094),
    (0.020, 0.0152, 0.0128),
    (0.065, 0.0160, 0.0135),   # talon
    (0.180, 0.0149, 0.0126),
    (0.450, 0.0140, 0.0118),
    (0.750, 0.0137, 0.0116),
    (0.940, 0.0136, 0.0115),
    (1.000, 0.0131, 0.0111),
]
mats = [(0.0, "oak_dark"), (0.020, "oak"), (0.180, "oak_worn"), (0.750, "oak")]
wooden_handle(H, 0.0, Z_HANDLE + 0.004, radii, mats, sides=12, expo=2.3,
              curve=lambda t: (0.0025 * math.sin(math.pi * t), 0.0))

# virole de fer, legerement bombee
fz = [Z_HANDLE - 0.008, Z_HANDLE - 0.005, Z_HANDLE + 0.006, Z_FERRULE - 0.004, Z_FERRULE]
fr = [0.0138, 0.0150, 0.0154, 0.0148, 0.0128]
H.loft([ring((0.0, 0.0, z), (1, 0, 0), (0, 1, 0), r, r * 0.85, 12, 2.2) for z, r in zip(fz, fr)],
       lambda i, j: "steel_dark" if i in (0, 3) else "forge", True, True)
handle = H.build("handle")

# ------------------------------------------------------------------ col forge : sort de la virole et se couche vers -X
N = Mesh()
neck = [(0.0, 0.0, Z_FERRULE - 0.004), (-0.0015, 0.0, Z_FERRULE + 0.010),
        (-0.007, 0.0, Z_FERRULE + 0.024), (-0.016, 0.0, Z_FERRULE + 0.031)]
nr = [(0.0058, 0.0046), (0.0052, 0.0040), (0.0047, 0.0033), (0.0044, 0.0028)]
sweep_profile(N, neck, lambda i: [(nr[i][0] * math.cos(a) * 1.0, nr[i][1] * math.sin(a))
                                  for a in [2 * math.pi * k / 8 for k in range(8)]],
              "forge", up=(0, 1, 0))

# ------------------------------------------------------------------ lame
n = 13
x0, length = -0.012, 0.205
path = []
for i in range(n):
    t = i / (n - 1)
    x = x0 - length * t
    z = Z_FERRULE + 0.034 + 0.010 * math.sin(math.pi * min(t * 1.25, 1.0)) - 0.034 * t ** 2.3
    path.append((x, 0.0, z))
widths = [0.022, 0.029, 0.033, 0.034, 0.0335, 0.032, 0.0295, 0.026, 0.0215, 0.016, 0.0105, 0.0055, 0.0012]
thick = [0.0034, 0.0033, 0.0031, 0.0029, 0.0027, 0.0025, 0.0023, 0.0021, 0.0019, 0.0017, 0.0015, 0.0012, 0.0008]


def blade_mat(i, j):
    if j in (3, 4):
        return "steel_edge"     # biseau poli : la ligne claire qui court le long du fil
    if j in (0, 7):
        return "patina"         # dos, un peu rouille
    return "forge"              # plats noircis a la forge


sweep_profile(N, path, lambda i: blade_section(widths[i], thick[i], bevel=0.40, back=0.04),
              blade_mat, up=(0, 1, 0), flip_u=True)
blade = N.build("blade")

collision = None

pfinish("sickle", expected_dims=(0.235, 0.032, 0.345), tri_limit=(250, 2000),
        angles={"handle": math.radians(50), "blade": math.radians(28)},
        yaw=12, pitch=12, margin=1.05,
        extra_views=[("_b", dict(yaw=-55, pitch=30, margin=0.95)), ("_top", dict(yaw=20, pitch=10, margin=0.6))])
