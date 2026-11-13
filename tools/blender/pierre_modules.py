import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pierre_util import *
LIM = (50, 5000)


def slab(variant):
    reset_scene()
    parts = []
    if variant == "a":
        parts.append(box("slab", (0.94, 0.9, 0.09), (0, 0, 0.045), "stone", bevel=0.03))
        parts[0].rotation_euler.z = math.radians(2)
        parts += moss_patch("m0", (0.38, 0.36, 0.06), 0.06, 0.6, 1, 2)
        parts += moss_patch("m1", (-0.4, -0.2, 0.06), 0.05, 0.6, 2, 2)
    elif variant == "b":
        parts.append(box("slab", (0.46, 0.92, 0.1), (-0.25, 0, 0.05), "stone", bevel=0.03))
        parts.append(box("slab2", (0.44, 0.84, 0.08), (0.25, 0.02, 0.04), "stone_dark", bevel=0.03))
        parts[1].rotation_euler.z = math.radians(-3)
        parts += moss_patch("m0", (0.0, -0.3, 0.06), 0.06, 0.6, 3, 3)
        parts += moss_patch("m1", (0.02, 0.35, 0.06), 0.05, 0.6, 4, 2)
    else:
        s = box("slab", (0.96, 0.92, 0.11), (0, 0, 0.055), "stone", bevel=0.035)
        c = box("cut", (0.3, 0.3, 0.3), (0.56, -0.5, 0.05), "stone", rot=(0, 0, math.radians(45)), bevel=0)
        bool_cut(s, c)
        s.name = "slab"
        parts.append(s)
        parts += moss_patch("m0", (-0.4, 0.38, 0.07), 0.06, 0.6, 5, 3)
        parts += moss_patch("m1", (0.4, 0.38, 0.07), 0.04, 0.6, 6, 2)
    for i, p in enumerate(parts):
        if p.name.startswith("slab"):
            jitter(p, 0.012, i + ord(variant))
    body = join(parts, f"path_slab_{variant}")
    collision_box(f"path_slab_{variant}", (0.96, 0.94, 0.08), (0, 0, 0.04))
    finish_model(f"path_slab_{variant}", expected_dims=(1.0, 1.0, 0.1), tri_limit=LIM)


def step():
    reset_scene()
    parts = [box("step", (1.96, 0.5, 0.18), (0, 0, 0.09), "stone", bevel=0.045)]
    parts.append(box("step_wear", (1.0, 0.24, 0.015), (0.1, -0.02, 0.18), "stone_dark", bevel=0.007))
    parts += moss_patch("m0", (-0.8, 0.12, 0.17), 0.08, 0.5, 7, 3)
    parts += moss_patch("m1", (0.75, 0.12, 0.17), 0.06, 0.5, 8, 2)
    parts += moss_patch("m2", (-0.2, -0.15, 0.05), 0.05, 0.8, 9, 2)
    jitter(parts[0], 0.012, 3)
    body = join(parts, "stone_step")
    collision_box("stone_step", (1.96, 0.5, 0.18), (0, 0, 0.09))
    finish_model("stone_step", expected_dims=(2.0, 0.5, 0.18), tri_limit=LIM)


def wall():
    reset_scene()
    parts = [box("socle", (2.0, 0.3, 0.36), (0, 0, 0.18), "stone", bevel=0.045)]
    parts.append(box("socle_cap", (1.9, 0.26, 0.06), (0, 0, 0.39), "stone_dark", bevel=0.02))
    for sx in (-1, 1):
        parts.append(box(f"post{sx}", (0.14, 0.14, 0.84), (sx * 0.92, 0, 0.42), "wood_dark", bevel=0.025))
        parts.append(box(f"post_cap{sx}", (0.17, 0.17, 0.05), (sx * 0.92, 0, 0.85), "wood_faded", bevel=0.02))
    parts.append(box("post_mid", (0.12, 0.12, 0.6), (0, 0, 0.66), "wood_dark", bevel=0.02))
    parts.append(box("rail_top", (1.84, 0.1, 0.1), (0, 0, 0.78), "wood_faded", bevel=0.02))
    parts.append(box("rail_mid", (1.84, 0.08, 0.08), (0, 0, 0.6), "wood_faded", bevel=0.02))
    parts += moss_patch("m0", (-0.7, -0.1, 0.06), 0.08, 0.7, 11, 3)
    parts += moss_patch("m1", (0.5, -0.1, 0.05), 0.07, 0.7, 12, 3)
    parts += moss_patch("m2", (0.75, 0.0, 0.38), 0.05, 0.5, 13, 2)
    jitter(parts[0], 0.01, 2)
    body = join(parts, "low_wall")
    collision_box("low_wall", (2.0, 0.3, 0.85), (0, 0, 0.425))
    finish_model("low_wall", expected_dims=(2.0, 0.3, 0.9), tri_limit=LIM)


which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["a", "b", "c", "step", "wall"]
for w in which:
    if w in "abc" and len(w) == 1:
        slab(w)
    elif w == "step":
        step()
    else:
        wall()
