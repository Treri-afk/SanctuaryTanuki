"""Renard roux assis (nuits du sanctuaire), ~0,46 m aux pointes des oreilles.
Elance et droit : buste penche vers l'avant, plastron et joues creme, museau fin, grandes oreilles
triangulaires a pointe noire, pattes avant fines a chaussettes noires, grande queue touffue enroulee
devant les pattes, bout blanc. Meme langage que le chat (volumes lisses, aplats).
Avant = -Y (= +Z dans Godot, le jeu tourne la creature vers le joueur). Origine au sol, centree.
Objets : « fox » (corps) et « tail » (origine a la base de la queue, pour l'animer un jour).
Pas de collision : la creature ne doit pas bloquer le joueur.
Lancer : blender --background --python tools/blender/fox.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_util import *

reset_scene()
F, FD, C, D, EI = "fox_fur", "fox_fur_dk", "fox_cream", "fox_dark", "fox_ear_in"
M = Mesh()

# ------------------------------------------------------------------ buste : poire penchee vers l'avant
b0 = len(M.v)
f0 = len(M.f)
prof = [(0.0, 0.012), (0.048, 0.014), (0.066, 0.022), (0.078, 0.038), (0.084, 0.06), (0.085, 0.09),
        (0.082, 0.12), (0.076, 0.155), (0.068, 0.19), (0.060, 0.222), (0.053, 0.25), (0.047, 0.272),
        (0.042, 0.288), (0.030, 0.298), (0.0, 0.304)]
M.lathe(prof, 26, F, center=(0.0, 0.028), scale=(0.95, 1.10))
for i in range(b0, len(M.v)):
    x, y, z = M.v[i]
    M.v[i] = (x, y - 0.30 * max(0.0, z - 0.07), z)
# hanches
for sx in (-1, 1):
    ell(M, (sx * 0.060, 0.046, 0.074), (0.054, 0.098, 0.074), F, 14, 8)
# plastron creme : un volume pose sur le poitrail (bord net), incline comme le buste
v0 = len(M.v)
ell(M, (0.0, -0.066, 0.198), (0.041, 0.024, 0.098), C, 18, 10)
xf(M, v0, about((0.0, -0.066, 0.198), Matrix.Rotation(0.29, 3, "X")))

# ------------------------------------------------------------------ pattes : avant fines, chaussettes noires
l0 = len(M.f)
for sx in (-1, 1):
    ell(M, (sx * 0.029, -0.052, 0.102), (0.018, 0.020, 0.096), F, 10, 8)      # patte avant
    ell(M, (sx * 0.030, -0.070, 0.013), (0.019, 0.032, 0.014), F, 10, 6)      # pied avant
    ell(M, (sx * 0.070, -0.022, 0.013), (0.021, 0.040, 0.014), F, 10, 6)      # pied arriere
recolor(M, l0, lambda c: D if c[2] < 0.10 else None)

# ------------------------------------------------------------------ tete
HC = (0.0, -0.074, 0.334)
h0 = len(M.f)
ell(M, HC, (0.057, 0.055, 0.051), F, 20, 12)                                                  # crane
for sx in (-1, 1):
    # joues : touffes pointues couchees vers l'arriere et le bas (fourrure des joues du renard)
    v0 = len(M.v)
    cone(M, (sx * 0.040, HC[1] - 0.010, HC[2] - 0.026), 0.052, 0.022, C, flat=0.55, sides=8)
    xf(M, v0, about((sx * 0.040, HC[1] - 0.010, HC[2] - 0.026),
                    Matrix.Rotation(sx * 1.55, 3, "Y") @ Matrix.Rotation(0.55, 3, "X")))
ell(M, (0.0, HC[1] - 0.064, HC[2] - 0.020), (0.023, 0.052, 0.021), F, 12, 8)                  # museau
ell(M, (0.0, HC[1] - 0.056, HC[2] - 0.031), (0.020, 0.044, 0.013), C, 12, 6)                  # machoire
ell(M, (0.0, HC[1] - 0.115, HC[2] - 0.016), (0.0095, 0.008, 0.008), D, 8, 5)                  # truffe
# yeux en amande, legerement brides
for sx in (-1, 1):
    v0 = len(M.v)
    c = (sx * 0.026, HC[1] - 0.045, HC[2] + 0.006)
    ell(M, c, (0.0115, 0.0052, 0.0062), "eye_dark", 8, 5)
    xf(M, v0, about(c, Matrix.Rotation(-sx * 0.38, 3, "Y")))
# bas des joues et levres creme : le masque blanc du renard
recolor(M, h0, lambda c: C if (c[2] < HC[2] - 0.016 and c[1] < HC[1] + 0.02 and abs(c[0]) > 0.012) else None)
# oreilles : grands triangles, pointe noire, interieur clair
for sx in (-1, 1):
    base = (sx * 0.033, HC[1] + 0.008, HC[2] + 0.034)
    e0 = len(M.f)
    cone(M, base, 0.088, 0.031, F, flat=0.42, tilt=(-0.12, sx * 0.30), sides=8)
    recolor(M, e0, lambda c, bz=base[2]: D if c[2] > bz + 0.046 else None)
    cone(M, (base[0], base[1] - 0.009, base[2] + 0.004), 0.066, 0.020, EI, flat=0.32, tilt=(-0.12, sx * 0.30), sides=8)

M.build("fox")

# ------------------------------------------------------------------ queue : touffue, enroulee devant les pattes
PIV = Vector((0.0, 0.098, 0.060))
path = [(0.0, 0.100, 0.0), (0.070, 0.128, 0.0), (0.128, 0.082, 0.0), (0.150, 0.004, 0.0),
        (0.132, -0.072, 0.0), (0.096, -0.108, 0.0), (0.066, -0.118, 0.0)]
radii = [0.028, 0.048, 0.058, 0.058, 0.048, 0.032, 0.012]
pts = []
for (x, y, _), r in zip(path, radii):
    pts.append(Vector((x, y, r * 0.88 + 0.006)) - PIV)       # posee au sol, a peine ecrasee
pts[0] = Vector((0.0, 0.100, 0.060)) - PIV
T = Mesh()
T.tube(pts, radii, 10, lambda i, j: C if i >= 4 else F, caps=True)
T.fm[-1] = T._mi(C)          # le bout de la queue est blanc
T.build("tail", loc=tuple(PIV))

pfinish("fox", expected_dims=(0.30, 0.34, 0.46), tri_limit=(400, 4000),
        angles={"fox": math.radians(80), "tail": math.radians(80)},
        yaw=30, pitch=12, margin=1.0,
        extra_views=[("_b", dict(yaw=-40, pitch=10, margin=1.0)), ("_side", dict(yaw=90, pitch=4, margin=1.0))])
