"""Helpers locaux de l'agent 'sentiers' (hokora, fox_statue, torii_small, stone_marker, bench, paper_lantern, ema_loose).
N'altere pas common.py. Importer avec : from trail_util import *
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *          # common.*, pierre_util.*, Mesh, noise3, lerp ...
import common
from mathutils import Vector, Quaternion, Matrix, Euler


# ----------------------------------------------------------------- formes dans un Mesh multi-materiaux
def add_box(m, center, size, mat_name, rot=(0, 0, 0)):
    """Boite non biseautee (12 tris) ajoutee a un Mesh. rot = Euler (rad) autour du centre."""
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    e = Euler(rot, "XYZ")
    c = Vector(center)
    rm = e.to_matrix()
    verts = [tuple(c + rm @ Vector(p)) for p in pts]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    m.add(verts, faces, mat_name)


def rect_ring(cx, cy, z, w, d):
    return [(cx - w / 2, cy - d / 2, z), (cx + w / 2, cy - d / 2, z), (cx + w / 2, cy + d / 2, z), (cx - w / 2, cy + d / 2, z)]


def frustum(m, c0, s0, c1, s1, mat_name):
    """Prisme/tronc rectangulaire de c0=(x,y,z0) taille s0=(w,d) a c1=(x,y,z1) taille s1 (jambes evasees, etc.)."""
    r0 = rect_ring(c0[0], c0[1], c0[2], s0[0], s0[1])
    r1 = rect_ring(c1[0], c1[1], c1[2], s1[0], s1[1])
    m.loft([r0, r1], mat_name)


def rect_loft(m, rings, mat_name):
    """rings = [(cx, cy, z, w, d), ...] -> loft ferme de sections rectangulaires."""
    m.loft([rect_ring(*r) for r in rings], mat_name)


def prism_y(m, outline_xz, y0, y1, mat_name):
    """Prisme de contour (x, z) extrude entre y0 et y1 (plaquettes, panneaux)."""
    n = len(outline_xz)
    verts = [(x, y0, z) for x, z in outline_xz] + [(x, y1, z) for x, z in outline_xz]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    m.add(verts, faces, mat_name)


def torus(m, center, R, r, mat_name, axis="y", nmaj=14, nmin=6):
    """Anneau (tore). axis='y' : anneau dans le plan XZ (anneau de suspension vertical vu de face)."""
    cx, cy, cz = center
    verts, faces = [], []
    for i in range(nmaj):
        a = 2 * math.pi * i / nmaj
        for j in range(nmin):
            b = 2 * math.pi * j / nmin
            rr = R + r * math.cos(b)
            if axis == "y":
                verts.append((cx + rr * math.cos(a), cy + r * math.sin(b), cz + rr * math.sin(a)))
            else:
                verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz + r * math.sin(b)))
    for i in range(nmaj):
        for j in range(nmin):
            i2, j2 = (i + 1) % nmaj, (j + 1) % nmin
            faces.append((i * nmin + j, i2 * nmin + j, i2 * nmin + j2, i * nmin + j2))
    m.add(verts, faces, mat_name)


def loop_tube_yz(m, center_yz, ry, rz, r, mat_name, nseg=16, nsides=5, bottom_at_center=False):
    """Boucle de ficelle fermee dans le plan YZ (x = 0) : ellipse de rayons ry/rz, section circulaire r.
    Le point le plus bas de l'ellipse est a (y, z) = center_yz - (0, rz) (la ficelle y passe selon Y)."""
    cy, cz = center_yz
    pts = []
    for i in range(nseg):
        t = 2 * math.pi * i / nseg
        pts.append((cy + ry * math.sin(t), cz - rz * math.cos(t)))
    verts, faces = [], []
    for i, (y, z) in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % nseg]
        ty, tz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(ty, tz)
        ty, tz = ty / L, tz / L
        ny, nz = -tz, ty
        for j in range(nsides):
            ph = 2 * math.pi * j / nsides
            verts.append((r * math.cos(ph), y + r * math.sin(ph) * ny, z + r * math.sin(ph) * nz))
    for i in range(nseg):
        for j in range(nsides):
            i2, j2 = (i + 1) % nseg, (j + 1) % nsides
            faces.append((i * nsides + j, i2 * nsides + j, i2 * nsides + j2, i * nsides + j2))
    m.add(verts, faces, mat_name)


def catmull(pts, per=4):
    """Interpolation Catmull-Rom d'une polyligne 3D (pour queue, cordes)."""
    P = [Vector(p) for p in pts]
    out = []
    Q = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    for i in range(1, len(Q) - 2):
        p0, p1, p2, p3 = Q[i - 1], Q[i], Q[i + 1], Q[i + 2]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t ** 3
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return [tuple(p) for p in out]


def lerp_poly(profile, z):
    """Interpole un profil [(r, z), ...] croissant en z."""
    if z <= profile[0][1]:
        return profile[0][0]
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z0 <= z <= z1:
            return lerp(r0, r1, (z - z0) / (z1 - z0))
    return profile[-1][0]


def apply_rot(obj, rot_deg, pivot=(0, 0, 0)):
    """Fait pivoter un objet autour d'un pivot (degres XYZ) et applique la transformation."""
    px, py, pz = pivot
    e = Euler([math.radians(a) for a in rot_deg], "XYZ")
    mt = Matrix.Translation(pivot) @ e.to_matrix().to_4x4() @ Matrix.Translation((-px, -py, -pz))
    obj.matrix_world = mt @ obj.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def tri_report(parts):
    """Affiche les triangles par piece (avant join) pour eviter de depasser le budget."""
    tot = 0
    for p in parts:
        n = tri_count(p)
        tot += n
        print(f"  TRIS {p.name:16s} {n}")
    print(f"  TRIS total {tot}")


# ----------------------------------------------------------------- mousse
def moss_blobs(mesh, specs, seed0=1):
    """specs = [(x, y, z, rx, ry, rz, yaw)] : patchs de mousse (blobs aplatis, moitie basse enterree)."""
    for i, (x, y, z, rx, ry, rz, yaw) in enumerate(specs):
        mesh.blob((x, y, z), (rx, ry, rz), "moss", subdiv=2, noise=0.13, seed=seed0 + i * 3 + 1, bottom=0.45,
                  quat=Quaternion((0, 0, 1), yaw))


# ----------------------------------------------------------------- fin de modele
def tfinish(name, expected_dims=None, tri_limit=(300, 3500), angles=None, default_angle=math.radians(50),
            origin="ground", extra_views=(), lift_preview=0.0, **preview_kw):
    """Comme props_util.pfinish ; origin='top' pour un objet suspendu (origine en haut, modele vers -Z)."""
    angles = angles or {}
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            clean(o)
            shade(o, angles.get(o.name, default_angle))
    apply_all_transforms()
    info = report(name, expected_dims, tri_limit=tri_limit)
    vis = visual_objects()
    mn, mx = world_bounds(vis)
    info["max_z"] = round(mx.z, 3)
    if origin == "top":
        info["warnings"] = [w for w in info["warnings"] if not w.startswith("origine pas au sol")]
        if abs(mx.z) > 0.02:
            info["warnings"].append(f"origine pas au point d'accroche haut (max z = {mx.z:.3f})")
    info["objects"] = sorted(o.name for o in bpy.context.scene.objects if o.type == "MESH")
    info["empties"] = sorted(o.name for o in bpy.context.scene.objects if o.type == "EMPTY")
    info["tris_per_object"] = {o.name: tri_count(o) for o in bpy.context.scene.objects if o.type == "MESH"}
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    info["glb"] = export_glb(name)
    if lift_preview:
        for o in bpy.context.scene.objects:
            if o.type in {"MESH", "EMPTY"}:
                o.location.z += lift_preview
        bpy.context.view_layer.update()
    info["preview"] = render_preview(name, **preview_kw)
    for suffix, kw in extra_views:
        render_preview(name + suffix, **kw)
    with open(os.path.join(PREVIEW_DIR, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("MODEL_REPORT " + json.dumps(info))
    return info
