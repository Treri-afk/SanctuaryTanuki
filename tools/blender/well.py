import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pierre_util import *
reset_scene()
parts = []
parts.append(cylinder("curb_low", 0.50, 0.58, (0, 0, 0.29), "stone", verts=14, radius2=0.46, bevel=0.04, rot=(0, 0, 0.2)))
# fut leger evase vers le bas
cap = cylinder("curb_cap", 0.52, 0.28, (0, 0, 0.76), "stone", verts=14, bevel=0.05)
hole = cylinder("hole", 0.34, 0.5, (0, 0, 0.8), "stone", verts=14, bevel=0)
bool_cut(cap, hole)
cap.name = "curb_cap"
parts.append(cap)
# bandeau stone_dark a la jonction
parts.append(cylinder("curb_band", 0.49, 0.05, (0, 0, 0.6), "stone_dark", verts=14, bevel=0.015))
parts.append(cylinder("shaft_dark", 0.4, 0.04, (0, 0, 0.56), "stone_dark", verts=14, bevel=0.005))
# poteaux et traverse
for sx in (-1, 1):
    parts.append(box(f"post{sx}", (0.11, 0.11, 1.5), (sx * 0.6, 0.0, 0.75), "wood_dark", bevel=0.02))
    parts.append(box(f"foot{sx}", (0.2, 0.2, 0.08), (sx * 0.6, 0.0, 0.04), "stone_dark", bevel=0.03))
    parts.append(box(f"brace{sx}", (0.07, 0.07, 0.45), (sx * 0.5, 0, 1.28), "wood_faded", rot=(0, -sx * math.radians(35), 0), bevel=0.015))
parts.append(box("beam", (1.44, 0.14, 0.12), (0, 0, 1.52), "wood_dark", bevel=0.025))
parts.append(box("roof_beam", (1.5, 0.3, 0.07), (0, 0, 1.61), "wood_faded", bevel=0.02))
# poulie, corde, seau
parts.append(cylinder("pulley", 0.09, 0.05, (0, 0, 1.36), "wood_light", rot=(0, math.radians(90), 0), verts=12, bevel=0.01))
parts.append(box("pulley_hang", (0.04, 0.04, 0.1), (0, 0, 1.45), "metal", bevel=0.01))
parts.append(cylinder("rope", 0.012, 0.75, (0, 0, 0.93), "rope", bevel=0, verts=6))
parts.append(cylinder("bucket", 0.1, 0.16, (0, 0, 0.46), "wood_light", verts=10, radius2=0.08, bevel=0.01))
# mousse
parts += moss_ring("mb", 0, 0, 0.47, 0.07, 9, 0.1, seed=5, flat=0.7)
parts += moss_patch("mc0", (0.2, -0.46, 0.88), 0.06, 0.6, 21, 2)
parts += moss_patch("mc1", (-0.4, -0.3, 0.9), 0.05, 0.6, 22, 2)
for i, p in enumerate(parts):
    if p.name.startswith("curb"):
        jitter(p, 0.007, i)
body = join(parts, "well")
body.rotation_euler.z = math.radians(5)
bpy.ops.object.transform_apply(rotation=True)
collision_box("well", (1.04, 1.04, 0.9), (0, 0, 0.45))
finish_model("well", expected_dims=(1.5, 1.1, 1.65), tri_limit=(500, 5000))
