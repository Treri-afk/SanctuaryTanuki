import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pierre_util import *
reset_scene()
parts = []
# socle evase
parts.append(box("plinth", (0.96, 0.46, 0.22), (0, 0, 0.11), "stone_dark", bevel=0.04))
parts.append(box("plinth_top", (1.02, 0.5, 0.08), (0, 0, 0.26), "stone", bevel=0.03))
# bassin : bloc creuse
bas = box("basin", (1.14, 0.52, 0.34), (0, 0, 0.47), "stone", bevel=0.045)
hole = box("hole", (0.96, 0.34, 0.3), (0, 0, 0.66), "stone", bevel=0)
bool_cut(bas, hole)
bas.name = "basin"
parts.append(bas)
# interieur plus sombre (fond)
parts.append(box("basin_floor", (0.96, 0.34, 0.02), (0, 0, 0.525), "stone_dark", bevel=0.005))
# poteau de bois et bambou d'alimentation
parts.append(box("post", (0.09, 0.09, 0.56), (-0.36, 0.25, 0.52), "wood_dark", bevel=0.02))
parts.append(cylinder("post_cap", 0.065, 0.04, (-0.36, 0.25, 0.82), "wood_dark", bevel=0.01, radius2=0.05))
parts.append(cylinder("spout", 0.032, 0.36, (-0.36, 0.09, 0.745), "bamboo", rot=(math.radians(100), 0, 0), bevel=0.008, verts=10))
parts.append(cylinder("spout_node", 0.038, 0.025, (-0.36, -0.03, 0.742), "bamboo", rot=(math.radians(100), 0, 0), bevel=0.005, verts=10))
parts.append(box("tie", (0.1, 0.03, 0.04), (-0.36, 0.2, 0.745), "rope", bevel=0.008))
# mousse
parts += moss_patch("mb0", (0.45, -0.25, 0.13), 0.09, 0.8, 3, 3)
parts += moss_patch("mb1", (-0.3, -0.24, 0.13), 0.08, 0.8, 8, 2)
parts += moss_patch("mb2", (0.5, 0.2, 0.31), 0.06, 0.8, 12, 2)
parts += moss_patch("mb3", (0.05, -0.26, 0.31), 0.05, 0.7, 15, 2)
for i, p in enumerate(parts):
    if p.name in ("plinth", "plinth_top", "basin"):
        jitter(p, 0.007, i)
parts[0].rotation_euler.z = 0.03
body = join(parts, "water_basin")
body.rotation_euler.z = math.radians(2)
bpy.ops.object.transform_apply(rotation=True)
# eau
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0.60))
w = bpy.context.object
w.scale = (0.94, 0.32, 1)
bpy.ops.object.transform_apply(scale=True)
w.name = "water_surface"; w.data.name = "water_surface"
w.data.materials.append(mat("water"))
# louche
lad = []
lad.append(cylinder("l_handle", 0.014, 0.42, (0.3, -0.2, 0.664), "bamboo", rot=(0, math.radians(90), math.radians(6)), bevel=0.004, verts=8))
lad.append(cylinder("l_cup", 0.055, 0.08, (0.53, -0.19, 0.69), "bamboo", bevel=0.008, verts=10))
ladle = join(lad, "ladle")
collision_box("water_basin", (1.14, 0.52, 0.64), (0, 0, 0.32))
finish_model("water_basin", expected_dims=(1.2, 0.6, 0.8), tri_limit=(500, 5000))
