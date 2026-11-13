"""Banc de bois de sentier : 1,6 m de large, assise a 0,45 m, dossier bas, planches usees, pieds trapus sur pierres plates.
Avant = -Y. Lancer : blender --background --python tools/blender/bench.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

reset_scene()
rnd = random.Random(12)
parts = []
SEAT_Z0, SEAT_Z1 = 0.405, 0.455      # epaisseur de l'assise
LX = 0.66                            # position X des pieds
YF, YB = -0.13, 0.13               # pieds avant / arriere

# ---------------------------------------------------------------- pierres d'assise sous les pieds
for sx in (-1, 1):
    for sy, yy in ((-1, YF), (1, YB)):
        st = box("footing", (0.18, 0.18, 0.045), (sx * (LX + 0.01), yy, 0.0225), "stone", bevel=0.018)
        jitter(st, 0.005, int(sx * 7 + sy * 3 + 20))
        st.rotation_euler = (0, 0, math.radians(rnd.uniform(-8, 8)))
        parts.append(st)

# ---------------------------------------------------------------- structure : pieds trapus legerement evases, tabliers, traverse, montants de dossier
fr = Mesh()
for sx in (-1, 1):
    for sy, yy in ((-1, YF), (1, YB)):
        mt = "wood_dark"
        frustum(fr, (sx * (LX + 0.025), yy + sy * 0.018, 0.04), (0.105, 0.105),
                (sx * (LX - 0.005), yy - sy * 0.004, SEAT_Z0 + 0.002), (0.125, 0.125), mt)
    # tablier sous l'assise (relie pieds avant/arriere)
    add_box(fr, (sx * (LX - 0.005), 0.0, SEAT_Z0 - 0.04), (0.085, 0.32, 0.08), "wood_dark")
    # montant de dossier : prolonge le pied arriere, penche vers l'arriere
    frustum(fr, (sx * (LX - 0.005), YB - 0.004, SEAT_Z1 - 0.01), (0.085, 0.07),
            (sx * (LX - 0.005), YB + 0.045, 0.75), (0.075, 0.062), "wood_dark")
# traverse basse entre les deux pieds arriere
add_box(fr, (0, YB + 0.003, 0.17), (1.28, 0.05, 0.065), "wood_dark")
parts.append(fr.build("frame", bevel=0.014))

# ---------------------------------------------------------------- assise : 3 planches un peu inegales
pl = Mesh()
plank_y = [-0.141, -0.004, 0.133]
plank_m = ["wood_light", "wood_faded", "wood_light"]
for i, y in enumerate(plank_y):
    L = [1.60, 1.575, 1.60][i]
    dz = [0.0, 0.004, -0.002][i]
    add_box(pl, (0.0 + (0.004 if i == 1 else 0.0), y, (SEAT_Z0 + SEAT_Z1) / 2 + dz), (L, 0.132, SEAT_Z1 - SEAT_Z0),
            plank_m[i], rot=(0, 0, math.radians([0.25, -0.2, 0.15][i])))
# dossier : 2 lattes sur la face avant des montants
for z, mt in ((0.575, "wood_faded"), (0.68, "wood_light")):
    yb = YB + 0.045 * (z - SEAT_Z1) / (0.75 - SEAT_Z1) - 0.045
    add_box(pl, (0.0, yb, z), (1.50, 0.03, 0.09), mt, rot=(math.radians(-8), 0, 0))
parts.append(pl.build("planks", bevel=0.011))

# ---------------------------------------------------------------- mousse
m = Mesh()
moss_blobs(m, [(-LX - 0.07, YF - 0.04, 0.04, 0.06, 0.04, 0.04, 0.3), (LX + 0.09, YB + 0.03, 0.04, 0.05, 0.06, 0.04, 0.0),
               (-LX, YB + 0.08, 0.03, 0.07, 0.035, 0.035, 0.1), (LX + 0.01, YF, 0.047, 0.05, 0.05, 0.02, 0.2),
               (-0.55, 0.12, SEAT_Z1, 0.07, 0.035, 0.018, 0.2)], 61)
parts.append(m.build("moss_patches"))

tri_report(parts)
bn = join(parts, "bench")
apply_rot(bn, (0, 0.4, 2.0))
collision_box("bench", (1.6, 0.46, 0.75), (0, 0, 0.375))

tfinish("bench", expected_dims=(1.6, 0.47, 0.75), tri_limit=(300, 3500), yaw=30, pitch=18, margin=1.08,
        angles={"bench": math.radians(45)},
        extra_views=[("_b", dict(yaw=-140, pitch=16, margin=1.08))])
