"""Outils partages des batiments du sanctuaire (haiden, tronc a offrandes...) : palette etendue (cuivre, enduit,
tissus), maillages multi-materiaux, toits epais en champ de hauteur, poutres balayees le long d'une polyligne,
tubes (cordes), prismes, chapeaux dores (giboshi), papiers en zigzag (shide).
Importer avec : from shrine_util import *"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import common
import bmesh
from mathutils import Vector

PALETTE.update({
    "copper":        "#5E8C7A",   # toiture de cuivre patine (vert-de-gris)
    "copper_dark":   "#46695E",   # faitage, aretiers
    "roof_edge":     "#7C6650",   # tranche du toit : couches d'ecorce de cypres
    "soffit":        "#6A4A32",   # sous-face du toit
    "plaster":       "#CBBDA3",   # frise enduite (sous le seuil de lueur du shader)
    "tatami":        "#BFA866",
    "cloth_purple":  "#6E4C8C",
    "cloth_white":   "#D6CEBE",
    "sakaki":        "#3D5A35",
})

# =========================================================== helpers
def make_mesh(name, verts, faces, mats, bevel=0.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    names = []
    idx = []
    for m in mats:
        if m not in names:
            names.append(m)
        idx.append(names.index(m))
    for n in names:
        me.materials.append(mat(n))
    for p, i in zip(me.polygons, idx):
        p.material_index = i
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if bevel:
        bevel_obj(o, bevel)
    return o


def bevel_obj(o, w, seg=1):
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = seg
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(30)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier="bevel")


def bx(name, size, loc, m="wood_dark", bevel=0.02, seg=1, rot=(0, 0, 0)):
    old = common.BEVEL_SEGMENTS
    common.BEVEL_SEGMENTS = seg
    o = box(name, size, loc, m, rot, bevel)
    common.BEVEL_SEGMENTS = old
    return o


def bx_span(name, x0, x1, y0, y1, z0, z1, m="wood_dark", bevel=0.02, seg=1):
    return bx(name, (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)),
              ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), m, bevel, seg)


def cyl(name, r, z0, z1, x, y, m="lacquer_red", verts=16, bevel=0.02, r2=None):
    old = common.BEVEL_SEGMENTS
    common.BEVEL_SEGMENTS = 1
    o = cylinder(name, r, z1 - z0, (x, y, (z0 + z1) / 2), m, verts=verts, bevel=bevel, radius2=r2)
    common.BEVEL_SEGMENTS = old
    return o


def heightfield(name, xs, ys, top, thick, mtop, medge, mbot, diag=None):
    """Toit epais : surface top(x, y), dessous top - thick, tranche sur le pourtour."""
    nx, ny = len(xs), len(ys)
    V, F, M = [], [], []
    for y in ys:
        for x in xs:
            V.append((x, y, top(x, y)))
    off = len(V)
    for y in ys:
        for x in xs:
            V.append((x, y, top(x, y) - thick(x, y)))

    def ix(i, j):
        return j * nx + i

    for j in range(ny - 1):
        for i in range(nx - 1):
            a, b, c, d = ix(i, j), ix(i + 1, j), ix(i + 1, j + 1), ix(i, j + 1)
            alt = diag((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2) if diag else False
            tris = [(a, b, d), (b, c, d)] if alt else [(a, b, c), (a, c, d)]
            for t in tris:
                F.append(t)
                M.append(mtop)
                F.append(tuple(v + off for v in reversed(t)))
                M.append(mbot)
    ring = ([(i, 0) for i in range(nx)] + [(nx - 1, j) for j in range(1, ny)]
            + [(i, ny - 1) for i in range(nx - 2, -1, -1)] + [(0, j) for j in range(ny - 2, 0, -1)])
    for k in range(len(ring)):
        i0, j0 = ring[k]
        i1, j1 = ring[(k + 1) % len(ring)]
        F.append((ix(i0, j0), ix(i1, j1), ix(i1, j1) + off, ix(i0, j0) + off))
        M.append(medge)
    return make_mesh(name, V, F, M)


def frame_at(pts, k, up):
    if k == 0:
        t = Vector(pts[1]) - Vector(pts[0])
    elif k == len(pts) - 1:
        t = Vector(pts[-1]) - Vector(pts[-2])
    else:
        t = Vector(pts[k + 1]) - Vector(pts[k - 1])
    t.normalize()
    s = t.cross(Vector(up))
    if s.length < 1e-6:
        s = t.cross(Vector((1, 0, 0)))
    s.normalize()
    u = s.cross(t).normalized()
    return t, s, u


def sweep(name, pts, w, h, m, up=(0, 0, 1), bevel=0.0, dz_top=False):
    """Poutre de section w x h le long d'une polyligne (h selon la verticale locale).
    dz_top : la polyligne est le dessus de la poutre (sinon son axe)."""
    V, F = [], []
    for k, p in enumerate(pts):
        t, s, u = frame_at(pts, k, up)
        P = Vector(p) - (u * (h / 2) if dz_top else Vector((0, 0, 0)))
        for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            V.append(tuple(P + s * (a * w / 2) + u * (b * h / 2)))
    n = len(pts)
    for k in range(n - 1):
        for q in range(4):
            a = k * 4 + q
            b = k * 4 + (q + 1) % 4
            F.append((a, b, b + 4, a + 4))
    F.append((3, 2, 1, 0))
    F.append(tuple(range((n - 1) * 4, n * 4)))
    return make_mesh(name, V, F, [m] * len(F), bevel)


def tube(name, pts, radii, m, nseg=8):
    V, F = [], []
    for k, p in enumerate(pts):
        t, s, u = frame_at(pts, k, (0, 0, 1))
        for q in range(nseg):
            a = 2 * math.pi * q / nseg
            V.append(tuple(Vector(p) + (s * math.cos(a) + u * math.sin(a)) * radii[k]))
    n = len(pts)
    for k in range(n - 1):
        for q in range(nseg):
            a = k * nseg + q
            b = k * nseg + (q + 1) % nseg
            F.append((a, b, b + nseg, a + nseg))
    F.append(tuple(range(nseg))[::-1])
    F.append(tuple(range((n - 1) * nseg, n * nseg)))
    return make_mesh(name, V, F, [m] * len(F))


def prism_x(name, outline, x0, x1, m, bevel=0.0):
    """Prisme : contour (y, z) extrude entre x0 et x1."""
    n = len(outline)
    V = [(x0, y, z) for y, z in outline] + [(x1, y, z) for y, z in outline]
    F = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    F += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return make_mesh(name, V, F, [m] * len(F), bevel)


def prism_y(name, outline, y0, y1, m, bevel=0.0):
    """Prisme : contour (x, z) extrude entre y0 et y1."""
    n = len(outline)
    V = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
    F = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    F += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return make_mesh(name, V, F, [m] * len(F), bevel)


def col_prism_x(name, outline, x0, x1):
    o = prism_x(name + "-convcol", outline, x0, x1, "stone")
    o.data.materials.clear()
    o.display_type = "WIRE"
    return o


def giboshi(name, x, y, z, r=0.085):
    """Chapeau dore en bulbe sur un poteau de rambarde."""
    sphere(name + "_bulb", r, (x, y, z + r * 0.8), "metal_gold", scale=(1, 1, 0.9), seg=10, rings=6)
    cyl(name + "_tip", r * 0.45, z + r * 1.4, z + r * 2.4, x, y, "metal_gold", verts=8, bevel=0, r2=0.005)
    cyl(name + "_neck", r * 0.75, z - 0.02, z + 0.05, x, y, "metal_gold", verts=10, bevel=0)



def shide(name, x, y, ztop, scale=1.0, axis="x"):
    """Papier en zigzag (4 segments) qui pend sous ztop."""
    segs = [(0.0, 0.0), (0.06, -0.09), (-0.02, -0.17), (0.07, -0.26), (0.0, -0.36)]
    for i in range(len(segs) - 1):
        (a0, z0), (a1, z1) = segs[i], segs[i + 1]
        w = 0.07 * scale
        cx = x + (a0 + a1) / 2 * scale if axis == "x" else x
        cy = y if axis == "x" else y + (a0 + a1) / 2 * scale
        bx(f"{name}_{i}", (w, 0.01, abs(z1 - z0) * scale + 0.02) if axis == "x" else (0.01, w, abs(z1 - z0) * scale + 0.02),
           (cx, cy, ztop + (z0 + z1) / 2 * scale), "paper", bevel=0)


