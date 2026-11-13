import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pierre_util import *
reset_scene()
S, SD = "stone", "stone_dark"
parts = []
# base (kiso) large, evasee
parts.append(cylinder("kiso", 0.38, 0.14, (0, 0, 0.07), S, verts=8, radius2=0.33, bevel=0.04))
parts.append(cylinder("kiso_top", 0.30, 0.06, (0, 0, 0.17), SD, verts=8, radius2=0.26, bevel=0.02))
# fut trapu, leger renflement
parts.append(cylinder("sao", 0.17, 0.62, (0, 0, 0.48), S, verts=8, radius2=0.19, bevel=0.035))
parts.append(sphere("sao_bulge", 0.23, (0, 0, 0.58), S, scale=(1, 1, 0.45), seg=8, rings=6))
parts.append(cylinder("chudai", 0.24, 0.12, (0, 0, 0.80), S, verts=8, radius2=0.35, bevel=0.035))
parts.append(cylinder("chudai_top", 0.35, 0.04, (0, 0, 0.88), SD, verts=8, bevel=0.02))
fire = cylinder("hibukuro", 0.26, 0.34, (0, 0, 1.07), S, verts=8, bevel=0.03)
for ang in (0, 90):
    c = box("cut", (0.22, 0.7, 0.22), (0, 0, 1.08), "stone", rot=(0, 0, math.radians(ang)), bevel=0)
    bool_cut(fire, c)
fire.name = "hibukuro"
parts.append(fire)
parts.append(cylinder("kasa_under", 0.28, 0.05, (0, 0, 1.265), SD, verts=8, bevel=0.02))
parts.append(cylinder("kasa", 0.52, 0.24, (0, 0, 1.39), S, verts=8, radius2=0.28, bevel=0.05))
parts.append(cylinder("kasa_top", 0.30, 0.10, (0, 0, 1.56), S, verts=8, radius2=0.18, bevel=0.03))
parts.append(cylinder("hoju_base", 0.1, 0.05, (0, 0, 1.63), SD, verts=8, bevel=0.015))
parts.append(sphere("hoju", 0.11, (0, 0, 1.72), S, scale=(1, 1, 1.25), seg=10, rings=8))
parts += moss_ring("mb", 0, 0, 0.33, 0.12, 7, 0.1, seed=4, flat=0.7)
parts += moss_ring("ms", 0, 0, 0.17, 0.15, 4, 0.07, seed=9, flat=0.8)
parts += moss_ring("mc", 0, 0, 0.30, 0.89, 3, 0.07, seed=21, flat=0.7, start=1.0, span=1.5)
for i, p in enumerate(parts):
    if p.name.startswith(("kiso", "chudai", "kasa")) and not p.name.startswith("kasa_tip"):
        jitter(p, 0.006, i)
parts[0].rotation_euler = (math.radians(0.8), math.radians(-0.6), 0.1)
body = join(parts, "stone_lantern")
body.rotation_euler = (math.radians(1.0), math.radians(-0.8), math.radians(8))
bpy.ops.object.transform_apply(rotation=True)
empty("flame_anchor", (0, 0, 1.05), size=0.08)
collision_box("stone_lantern", (0.7, 0.7, 1.0), (0, 0, 0.5))
# collision haute fine : deuxieme boite pour toit n'est pas necessaire
finish_model("stone_lantern", expected_dims=(1.05, 1.05, 1.8), tri_limit=(500, 5000))
