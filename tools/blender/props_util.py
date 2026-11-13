"""Helpers locaux de l'agent 'props de decor' (rochers, feuilles, panier, jizo, fougeres, tronc...).
N'altere pas common.py. Importer avec : from props_util import *
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pierre_util import *          # common.* + jitter, moss_patch, bool_cut ...
import common
from mathutils import Vector, Quaternion, Matrix

PALETTE.update({
    "fern_green": "#5E7B3A",
    "fern_dark": "#44602E",
    "foliage_light": "#E8AA3E",
})


def lerp(a, b, t):
    return a + (b - a) * t


def noise3(x, y, z, seed=0.0):
    """Pseudo-bruit lisse ~[-1, 1]."""
    return (math.sin(x * 3.1 + seed) * math.cos(y * 2.7 + seed * 1.7)
            + 0.7 * math.sin(z * 3.6 + seed * 0.6) + 0.5 * math.sin(2.3 * (x + y) + seed)) / 2.2


class Mesh:
    """Accumule plusieurs formes dans un mesh multi-materiaux (une couleur unie par materiau)."""

    def __init__(self):
        self.v, self.f, self.fm, self.mats = [], [], [], []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add(self, verts, faces, m):
        o = len(self.v)
        self.v += [tuple(x) for x in verts]
        for fc in faces:
            self.f.append(tuple(i + o for i in fc))
            self.fm.append(self._mi(m))

    # ---- surfaces de revolution / lofts
    def loft(self, rings, m, cap0=True, cap1=True):
        """Surface fermee autour de chaque anneau ; m : nom ou callable(i, j) -> nom."""
        n = len(rings[0])
        o = len(self.v)
        self.v += [tuple(p) for r in rings for p in r]
        for i in range(len(rings) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                self.f.append((o + i * n + j, o + i * n + j2, o + (i + 1) * n + j2, o + (i + 1) * n + j))
                self.fm.append(self._mi(m(i, j) if callable(m) else m))
        mm = m(0, 0) if callable(m) else m
        if cap0:
            self.f.append(tuple(range(o, o + n)))
            self.fm.append(self._mi(mm))
        if cap1:
            b = o + (len(rings) - 1) * n
            self.f.append(tuple(range(b, b + n))[::-1])
            self.fm.append(self._mi(mm))

    def lathe(self, profile, N, m, center=(0, 0), scale=(1, 1), phase=0.0, cap0=True, cap1=True, noise=None):
        """profile = [(r, z), ...] du bas vers le haut. m : nom ou callable(i, j)."""
        rings = []
        for i, (r, z) in enumerate(profile):
            ring = []
            for j in range(N):
                a = phase + 2 * math.pi * j / N
                rr = r
                if noise:
                    rr = r * (1 + noise(i, j, a, z))
                ring.append((center[0] + rr * scale[0] * math.cos(a),
                             center[1] + rr * scale[1] * math.sin(a), z))
            rings.append(ring)
        self.loft(rings, m, cap0 and profile[0][0] > 1e-6, cap1 and profile[-1][0] > 1e-6)
        return rings

    def sweep(self, pts, sec, sides, m, caps=True, ref=(0, 0, 1)):
        """Tube le long d'une polyligne ; sec(i, angle) -> (u, v) decalage dans le repere local."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        tans = []
        for i in range(n):
            if i == 0:
                t = pts[1] - pts[0]
            elif i == n - 1:
                t = pts[-1] - pts[-2]
            else:
                t = pts[i + 1] - pts[i - 1]
            tans.append(t.normalized())
        r = Vector(ref)
        if abs(tans[0].dot(r)) > 0.95:
            r = Vector((1, 0, 0))
        nrm = (r - tans[0] * r.dot(tans[0])).normalized()
        rings = []
        for i in range(n):
            t = tans[i]
            nrm = (nrm - t * nrm.dot(t)).normalized()
            b = t.cross(nrm)
            ring = []
            for j in range(sides):
                u, v = sec(i, 2 * math.pi * j / sides)
                ring.append(pts[i] + u * nrm + v * b)
            rings.append(ring)
        self.loft(rings, m, caps, caps)
        return rings

    def tube(self, pts, radii, sides, m, caps=True, squash=1.0, ref=(0, 0, 1)):
        return self.sweep(pts, lambda i, a: (radii[i] * math.cos(a), radii[i] * squash * math.sin(a)),
                          sides, m, caps, ref)

    def blob(self, center, scale, m, quat=None, subdiv=1, noise=0.08, seed=0, bottom=1.0, ground=False):
        """Ellipsoide bruite (icosphere). bottom<1 aplatit la moitie basse ; ground=True pose le blob sur z=center.z
        (le bas du blob est a center.z - 0)."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        cx, cy, cz = center
        verts = []
        for v in bm.verts:
            x, y, z = v.co
            k = 1.0 + noise * (math.sin(3.1 * x + seed) * math.cos(2.7 * y + seed * 1.7)
                               + 0.7 * math.sin(3.6 * z + seed * 0.6) + 0.5 * math.sin(2.3 * (x + y) + seed))
            z2 = z * (bottom if z < 0 else 1.0)
            p = Vector((x * k * scale[0], y * k * scale[1], z2 * k * scale[2]))
            if quat is not None:
                p = quat @ p
            verts.append((cx + p.x, cy + p.y, cz + p.z))
        bm.verts.ensure_lookup_table()
        faces = [tuple(v.index for v in f.verts) for f in bm.faces]
        bm.free()
        self.add(verts, faces, m)

    def build(self, name, bevel=0.0, loc=(0, 0, 0), recalc=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], self.f)
        me.update()
        used = sorted(set(self.fm))
        remap = {}
        for k, mi in enumerate(used):
            me.materials.append(mat(self.mats[mi]))
            remap[mi] = k
        for p, mi in zip(me.polygons, self.fm):
            p.material_index = remap[mi]
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        o.location = loc
        bpy.context.view_layer.objects.active = o
        if recalc:
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
        if bevel:
            common._finalize_obj(o, None, bevel, name)
        return o


def align_quat(normal, yaw=0.0):
    q = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized())
    return q @ Quaternion((0, 0, 1), yaw)


# ----------------------------------------------------------------- feuilles
def leaf_outline(kind):
    """Contour (x, y) normalise : x de -0.5 (base) a +0.5 (pointe), y demi-largeur +-0.5."""
    if kind == "lens":
        return [(-0.5, 0.0), (-0.2, 0.46), (0.18, 0.42), (0.5, 0.0), (0.18, -0.42), (-0.2, -0.46)]
    if kind == "star":      # feuille d'erable simplifiee a 5 lobes
        pts = []
        for k in range(5):
            a = math.radians(90 + 72 * k)
            pts.append((0.5 * math.cos(a) * (0.95 if k else 1.0), 0.5 * math.sin(a)))
            a2 = a + math.radians(36)
            pts.append((0.21 * math.cos(a2), 0.21 * math.sin(a2)))
        return pts
    raise ValueError(kind)


def add_leaf(mesh, pos, normal, yaw, L, W, m, kind="lens", t=0.004, curl=0.0):
    """Feuille = bipyramide plate fermee (12 ou 20 triangles). Pose en pos, orientee sur la normale."""
    q = align_quat(normal, yaw)
    outline = leaf_outline(kind)
    n = len(outline)
    verts = []
    for (x, y) in outline:
        r2 = (x * x + y * y) * 4
        verts.append(q @ Vector((x * L, y * W, curl * r2)))
    verts.append(q @ Vector((0.0, 0.0, t)))
    verts.append(q @ Vector((0.0, 0.0, -t * 0.6)))
    verts = [tuple(Vector(pos) + v) for v in verts]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((n, i, j))
        faces.append((n + 1, j, i))
    mesh.add(verts, faces, m)


def pfinish(name, expected_dims=None, tri_limit=(100, 3000), angles=None, default_angle=math.radians(50),
            extra_views=(), lift_preview=0.0, **preview_kw):
    """Comme common.finish_model mais angle de lissage par objet, vues supplementaires et detail par objet."""
    angles = angles or {}
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            clean(o)
            shade(o, angles.get(o.name, default_angle))
    apply_all_transforms()
    info = report(name, expected_dims, tri_limit=tri_limit)
    info["objects"] = sorted(o.name for o in bpy.context.scene.objects if o.type == "MESH")
    info["empties"] = sorted(o.name for o in bpy.context.scene.objects if o.type == "EMPTY")
    info["tris_per_object"] = {o.name: tri_count(o) for o in bpy.context.scene.objects if o.type == "MESH"}
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    info["glb"] = export_glb(name)
    if lift_preview:        # preview seulement : releve le modele pour qu'il ne passe pas sous le sol de reference
        for o in bpy.context.scene.objects:
            if o.type in {"MESH", "EMPTY"}:
                o.location.z += lift_preview
    info["preview"] = render_preview(name, **preview_kw)
    for suffix, kw in extra_views:
        render_preview(name + suffix, **kw)
    with open(os.path.join(PREVIEW_DIR, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("MODEL_REPORT " + json.dumps(info))
    return info
