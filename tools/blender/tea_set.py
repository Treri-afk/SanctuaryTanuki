"""Service a the : plateau de bois, theiere en fonte (tetsubin) avec anse arquee, deux tasses de ceramique claire.
0,35 x 0,25 x 0,15 m. Origine : dessous du plateau, centree. Pas de collision.
Lancer : blender --background --python tools/blender/tea_set.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1
PARTS = []
add = PARTS.append

# ------------------------------------------------------------------ plateau
add(bx("tray_base", (0.35, 0.25, 0.018), (0, 0, 0.009), "wood_faded", bevel=0.006))
for sy in (-1, 1):
    add(bx(f"tray_rim_fb_{sy}", (0.35, 0.018, 0.026), (0, sy * 0.116, 0.018 + 0.011), "wood_dark", bevel=0.006))
for sx in (-1, 1):
    add(bx(f"tray_rim_side_{sx}", (0.018, 0.214, 0.026), (sx * 0.166, 0, 0.018 + 0.011), "wood_dark", bevel=0.006))
for sx in (-1, 1):
    add(bx(f"tray_foot_{sx}", (0.03, 0.2, 0.004), (sx * 0.12, 0, 0.002), "wood_dark", bevel=0.001))

Z0 = 0.018          # dessus du fond du plateau
M = Mesh()

# ------------------------------------------------------------------ theiere en fonte (tetsubin)
PX, PY = -0.075, 0.005
pot_prof = [(0.040, 0.0), (0.050, 0.007), (0.060, 0.028), (0.061, 0.052), (0.050, 0.074), (0.036, 0.086), (0.031, 0.092)]
M.lathe([(r, z + Z0) for (r, z) in pot_prof], 14, "iron", center=(PX, PY))
# couvercle (metal) : disque bombe + bouton
M.lathe([(0.034, 0.092 + Z0), (0.032, 0.097 + Z0), (0.024, 0.104 + Z0), (0.011, 0.109 + Z0), (0.0, 0.110 + Z0)], 14,
        "metal", center=(PX, PY))
M.lathe([(0.0095, 0.109 + Z0), (0.0105, 0.114 + Z0), (0.0075, 0.119 + Z0), (0.0, 0.1205 + Z0)], 10, "iron", center=(PX, PY))
# bec verseur (vers +X)
M.tube([(PX + 0.048, PY, Z0 + 0.034), (PX + 0.078, PY, Z0 + 0.046), (PX + 0.098, PY, Z0 + 0.066), (PX + 0.106, PY, Z0 + 0.082)],
       [0.0165, 0.0125, 0.0092, 0.0078], 8, "iron", caps=True)
# anse arquee (arc au-dessus du couvercle) + pattes
arc = []
for i in range(11):
    a = math.pi * i / 10
    arc.append((PX - 0.002, PY - 0.060 * math.cos(a), Z0 + 0.066 + 0.062 * math.sin(a) ** 0.85))
M.tube(arc, [0.0052] * len(arc), 6, "iron", caps=True)
for sy in (-1, 1):
    M.blob((PX, PY + sy * 0.061, Z0 + 0.066), (0.010, 0.008, 0.012), "iron", subdiv=1, noise=0.0)
# bande rouillee a l'epaule
M.lathe([(0.0505, Z0 + 0.0715), (0.0485, Z0 + 0.078), (0.0425, Z0 + 0.0825), (0.0405, Z0 + 0.0845)], 14, "rust", center=(PX, PY))


# ------------------------------------------------------------------ tasses (yunomi)
def cup(cx, cy, m, foot_m):
    prof = [(0.0, 0.0), (0.020, 0.0), (0.028, 0.006), (0.034, 0.021), (0.0365, 0.045), (0.0335, 0.0475), (0.0305, 0.045),
            (0.0285, 0.014), (0.0, 0.0105)]
    z = Z0
    M.lathe([(r, zz + z) for (r, zz) in prof], 14, m, center=(cx, cy))
    # petit pied
    M.lathe([(0.017, z + 0.0), (0.0215, z + 0.0), (0.0215, z + 0.004), (0.017, z + 0.004)], 14, foot_m, center=(cx, cy))
    # the vert
    ring = [(cx + 0.0285 * math.cos(2 * math.pi * k / 14), cy + 0.0285 * math.sin(2 * math.pi * k / 14), z + 0.036) for k in range(14)]
    M.add(ring, [tuple(range(14))], "tea")


cup(0.092, 0.052, "paper", "stone")
cup(0.115, -0.050, "stone", "paper")

pot = M.build("teaware")
tray = merge(PARTS, "tray", origin=(0, 0, 0))

pfinish("tea_set", expected_dims=(0.35, 0.25, 0.15), tri_limit=(200, 1800),
        angles={"teaware": math.radians(60), "tray": math.radians(50)}, yaw=32, pitch=26, margin=0.95,
        extra_views=[("_b", dict(yaw=-40, pitch=35, margin=0.95))])
