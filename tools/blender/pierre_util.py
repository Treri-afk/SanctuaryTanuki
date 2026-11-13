import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *


def jitter(obj, amt=0.008, seed=1, zfix=True):
    """Deplace legerement les sommets (asymetrie, pierre irreguliere)."""
    rnd = random.Random(seed)
    me = obj.data
    cache = {}
    for v in me.vertices:
        k = (round(v.co.x, 3), round(v.co.y, 3), round(v.co.z, 3))
        if k not in cache:
            cache[k] = Vector((rnd.uniform(-amt, amt), rnd.uniform(-amt, amt), rnd.uniform(-amt, amt) * 0.6))
        v.co += cache[k]
    me.update()
    return obj


def moss_patch(name, loc, r=0.08, flat=0.45, seed=1, n=1):
    """Petit volume de mousse irregulier (spheres aplaties jointes)."""
    rnd = random.Random(seed)
    parts = []
    for i in range(n):
        o = sphere(f"{name}_{i}", r * rnd.uniform(0.7, 1.1),
                   loc=(loc[0] + rnd.uniform(-r, r) * (i > 0), loc[1] + rnd.uniform(-r, r) * (i > 0), loc[2]),
                   material="moss", scale=(rnd.uniform(1, 1.4), rnd.uniform(1, 1.4), flat), seg=10, rings=6)
        parts.append(o)
    return parts


def moss_ring(name, cx, cy, radius, z, count, r=0.07, seed=3, flat=0.5, start=0, span=2 * math.pi):
    rnd = random.Random(seed)
    parts = []
    for i in range(count):
        a = start + span * i / count + rnd.uniform(-0.2, 0.2)
        rr = radius + rnd.uniform(-0.02, 0.03)
        parts += moss_patch(f"{name}{i}", (cx + rr * math.cos(a), cy + rr * math.sin(a), z + rnd.uniform(0, 0.02)),
                            r * rnd.uniform(0.6, 1.2), flat, seed + i)
    return parts


def bool_cut(obj, cutter, remove=True):
    m = obj.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    m.object = cutter
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="cut")
    if remove:
        bpy.data.objects.remove(cutter, do_unlink=True)
    return obj


def merge_all(skip=(), name="body"):
    """Joint tous les meshes visuels sauf ceux de skip (noms) et collisions."""
    objs = [o for o in visual_objects() if o.name not in skip]
    return join(objs, name)
