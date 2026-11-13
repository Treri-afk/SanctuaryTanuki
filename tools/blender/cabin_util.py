"""Helpers locaux de l'agent 'cabane et vie du lieu' (hut, woodpile, wooden_bridge, tea_set, shrine_cat, rake,
stepping_stone). N'altere pas common.py : ajoute seulement des materiaux a common.PALETTE.
Importer avec : from cabin_util import *
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *          # common.* + Mesh, pfinish, jitter, moss_patch ...
import common
from mathutils import Vector, Matrix

PALETTE.update({
    "shingle":       "#7A6851",   # bardeaux de toit
    "shingle_light": "#8E7A5F",
    "shingle_dark":  "#5A4A3C",
    "thatch":        "#A58E55",   # faitage de chaume patine
    "iron":          "#2F3236",   # fonte / tole sombre
    "rust":          "#8B4A2B",
    "cat_white":     "#EFE6D2",
    "cat_orange":    "#D9822B",
    "cat_dark":      "#3A2E2A",
    "tea":           "#8E9446",
})


def bx(name, size, loc, material="wood_dark", rot=(0, 0, 0), bevel=0.02, seg=1):
    """Boite biseautee (1 segment par defaut pour le budget)."""
    old = common.BEVEL_SEGMENTS
    common.BEVEL_SEGMENTS = seg
    o = box(name, size, loc, material, rot, bevel)
    common.BEVEL_SEGMENTS = old
    return o


def cyl(name, r, depth, loc, material="wood_dark", rot=(0, 0, 0), verts=10, bevel=0.01, r2=None, seg=1):
    old = common.BEVEL_SEGMENTS
    common.BEVEL_SEGMENTS = seg
    o = cylinder(name, r, depth, loc, material, rot, verts, bevel, r2)
    common.BEVEL_SEGMENTS = old
    return o


def moss(name, loc, rx=0.12, ry=0.09, rz=0.03, rot=(0, 0, 0), seg=8, rings=4):
    """Petit volume de mousse aplati, eventuellement incline (rot = euler en radians)."""
    o = sphere(name, 1.0, loc, "moss", scale=(rx, ry, rz), seg=seg, rings=rings)
    o.rotation_euler = rot
    return o


def merge(objs, name, origin=(0, 0, 0)):
    """Fusionne des objets (apres application rot/echelle) et place l'origine du resultat en `origin` (monde)."""
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    delta = o.location - Vector(origin)
    if delta.length > 1e-9:
        o.data.transform(Matrix.Translation(delta))
        o.location = Vector(origin)
    return o


def recolor(M, f0, pred):
    """Change le materiau des faces f0.. de Mesh M selon pred(centroide) -> nom ou None."""
    for k in range(f0, len(M.f)):
        vs = [M.v[i] for i in M.f[k]]
        c = (sum(v[0] for v in vs) / len(vs), sum(v[1] for v in vs) / len(vs), sum(v[2] for v in vs) / len(vs))
        m = pred(c)
        if m:
            M.fm[k] = M._mi(m)


def prism_xz(M, outline, y0, y1, m):
    """Prisme extrude entre y0 et y1 depuis un contour convexe (x, z) ; faces recalculees a la fin."""
    n = len(outline)
    v = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
    f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, n + j, n + i))
    M.add(v, f, m)


def poly_ring(cx, cy, z, rx, ry, n, noise=0.0, rng=None, expo=2.0, rot=0.0):
    """Anneau de n points (super-ellipse) a la hauteur z."""
    ring = []
    for j in range(n):
        a = 2 * math.pi * j / n + rot
        ca, sa = math.cos(a), math.sin(a)
        k = (abs(ca) ** expo + abs(sa) ** expo) ** (-1.0 / expo)
        r = 1.0 + (rng.uniform(-noise, noise) if rng else 0.0)
        ring.append((cx + rx * ca * k * r, cy + ry * sa * k * r, z))
    return ring
