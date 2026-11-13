"""Helpers locaux (agent vegetation / props) : tubes lofts, blobs, finish avec angle de lissage par objet.
N'altere pas common.py."""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import common
from mathutils import Vector


class Builder:
    """Accumule plusieurs formes (tubes, blobs, prismes) dans un seul mesh multi-materiaux."""

    def __init__(self):
        self.v, self.f, self.fm, self.mats = [], [], [], []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add(self, verts, faces, m):
        o = len(self.v)
        self.v += [tuple(x) for x in verts]
        mi = self._mi(m)
        for fc in faces:
            self.f.append(tuple(i + o for i in fc))
            self.fm.append(mi)

    def tube(self, pts, radii, sides=8, m="wood_dark", closed=False, caps=True, squash=1.0, ref=(0, 0, 1)):
        pts = [Vector(p) for p in pts]
        n = len(pts)
        tans = []
        for i in range(n):
            if closed:
                t = pts[(i + 1) % n] - pts[(i - 1) % n]
            elif i == 0:
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
        verts, faces = [], []
        for i in range(n):
            t = tans[i]
            nrm = (nrm - t * nrm.dot(t))
            nrm = nrm.normalized()
            b = t.cross(nrm)
            for j in range(sides):
                a = 2 * math.pi * j / sides
                verts.append(pts[i] + radii[i] * (math.cos(a) * nrm + squash * math.sin(a) * b))
        segs = n if closed else n - 1
        for i in range(segs):
            i2 = (i + 1) % n
            for j in range(sides):
                j2 = (j + 1) % sides
                faces.append((i * sides + j, i * sides + j2, i2 * sides + j2, i2 * sides + j))
        if caps and not closed:
            c0 = len(verts)
            verts.append(pts[0])
            for j in range(sides):
                faces.append((c0, (j + 1) % sides, j))
            c1 = len(verts)
            verts.append(pts[-1])
            base = (n - 1) * sides
            for j in range(sides):
                faces.append((c1, base + j, base + (j + 1) % sides))
        self.add(verts, faces, m)

    def blob(self, center, scale, m, subdiv=2, noise=0.08, seed=0, bottom=0.6):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        cx, cy, cz = center
        for v in bm.verts:
            x, y, z = v.co
            k = 1.0 + noise * (math.sin(3.1 * x + seed) * math.cos(2.7 * y + seed * 1.7)
                               + 0.7 * math.sin(3.6 * z + seed * 0.6) + 0.5 * math.sin(2.3 * (x + y) + seed))
            z2 = z * (bottom if z < 0 else 1.0)
            v.co = (cx + x * k * scale[0], cy + y * k * scale[1], cz + z2 * k * scale[2])
        bm.verts.ensure_lookup_table()
        verts = [tuple(v.co) for v in bm.verts]
        faces = [tuple(v.index for v in f.verts) for f in bm.faces]
        bm.free()
        self.add(verts, faces, m)

    def poly_prism(self, outline, thickness, m, axis="y", y0=0.0):
        """Prisme extrude depuis un contour 2D (x,z) (axis y) : plaque."""
        n = len(outline)
        verts = [(x, y0 - thickness / 2, z) for x, z in outline] + [(x, y0 + thickness / 2, z) for x, z in outline]
        faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
        self.add(verts, faces, m)

    def build(self, name, bevel=0.0, loc=(0, 0, 0)):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], self.f)
        me.update()
        for m in self.mats:
            me.materials.append(mat(m))
        for p, mi in zip(me.polygons, self.fm):
            p.material_index = mi
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        o.location = loc
        bpy.context.view_layer.objects.active = o
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        if bevel:
            common._finalize_obj(o, None, bevel, name)
        return o


def lerp(a, b, t):
    return a + (b - a) * t


def finish(name, expected_dims=None, tri_limit=(500, 5000), angles=None, default_angle=math.radians(50),
           extra_views=(), **preview_kw):
    """Comme common.finish_model mais angle de lissage par objet (angles = {nom: radians}) et vues supplementaires."""
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
    info["preview"] = render_preview(name, **preview_kw)
    for suffix, kw in extra_views:
        render_preview(name + suffix, **kw)
    with open(os.path.join(PREVIEW_DIR, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("MODEL_REPORT " + json.dumps(info))
    return info
