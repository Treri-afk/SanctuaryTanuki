"""Generateur de rochers de montagne : enveloppe convexe facettee + biseau + mousse (faces + volumes)."""
from props_util import *


def fib_dirs(n, rnd):
    dirs = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        a = ga * i + rnd.uniform(-0.25, 0.25)
        d = Vector((r * math.cos(a), r * math.sin(a), z + rnd.uniform(-0.08, 0.08)))
        dirs.append(d.normalized())
    return dirs


def rock_points(rnd, center, radii, h, n, lean=0.0, rough=0.16, flat_top=1.0, seed=0.0):
    """Points sur un ellipsoide irregulier, coupes a z=0 (base plate)."""
    pts = []
    for d in fib_dirs(n, rnd):
        k = 1.0 + 0.22 * noise3(d.x * 2.0, d.y * 2.0, d.z * 2.0, seed) + rnd.uniform(-rough, rough) * 0.35
        p = Vector((center[0] + radii[0] * d.x * k, center[1] + radii[1] * d.y * k,
                    center[2] + radii[2] * d.z * k))
        p.z = min(max(p.z, 0.0), h * flat_top)
        p.x += lean * p.z
        pts.append(p)
    return pts


def hull_object(name, pts):
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    kill = list({g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def color_rock(obj, h, seed, moss_top=-0.15, dark_amt=0.4):
    """Materiaux par face : mousse sur le dessus, pierre sombre en bas / par plaques, pierre chaude ailleurs."""
    me = obj.data
    for m in ("stone", "stone_dark", "moss"):
        me.materials.append(mat(m))
    idx = {"stone": 0, "stone_dark": 1, "moss": 2}
    for p in me.polygons:
        c, n = p.center, p.normal
        nz = noise3(c.x * 3.0, c.y * 3.0, c.z * 2.0, seed)
        m = "stone"
        if n.z > 0.6 and nz > moss_top:
            m = "moss"
        elif c.z < h * 0.18 and n.z < 0.5 and nz > 0.15:
            m = "moss"
        elif c.z < h * 0.30 and n.z < 0.45:
            m = "stone_dark"
        elif noise3(c.x * 2.0 + 5, c.y * 2.0, c.z * 3.0, seed + 3) > (1.0 - dark_amt * 2):
            m = "stone_dark"
        p.material_index = idx[m]


def moss_layer(obj, h, seed, thick=0.03):
    """Extrude en bloc les faces 'moss' (couche de mousse epaisse a bord irregulier)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    mi = 2
    faces = [f for f in bm.faces if f.material_index == mi]
    if not faces:
        bm.free()
        return
    res = bmesh.ops.extrude_face_region(bm, geom=faces)
    bmesh.ops.delete(bm, geom=faces, context="FACES_ONLY")
    new_v = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    new_f = [e for e in res["geom"] if isinstance(e, bmesh.types.BMFace)]
    bm.normal_update()
    for v in new_v:
        k = thick * (0.7 + 0.6 * (0.5 + 0.5 * noise3(v.co.x * 5, v.co.y * 5, v.co.z * 5, seed)))
        v.co += v.normal * k
    for f in new_f:
        f.material_index = mi
        f.smooth = True
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()


def surface_point(obj, x, y, z0):
    hit, loc, nrm, _ = obj.ray_cast(Vector((x, y, z0)), Vector((0, 0, -1)))
    return (loc, nrm) if hit else (None, None)


def side_point(obj, ang, z, dist):
    o = Vector((math.cos(ang) * dist, math.sin(ang) * dist, z))
    hit, loc, nrm, _ = obj.ray_cast(o, Vector((-math.cos(ang), -math.sin(ang), 0)))
    return (loc, nrm) if hit else (None, None)


def make_rock(name, width, depth, height, seed, n_main=16, extras=(), lean=0.05, bevel=0.04,
              top_moss=6, base_moss=7, blob_r=0.11, rough=0.16, moss_top=-0.15, moss_thick=0.0):
    """extras : liste de (dx, dy, w, d, h) pour des blocs secondaires accoles (silhouette non symetrique)."""
    reset_scene()
    rnd = random.Random(seed)
    main_pts = rock_points(rnd, (0, 0, height * 0.42), (width * 0.54, depth * 0.54, height * 0.62), height,
                           n_main, lean * width, rough, seed=seed)
    all_pts = list(main_pts)
    hulls = [hull_object(name + "_main", main_pts)]
    for k, (dx, dy, w, d, hh) in enumerate(extras):
        pts = rock_points(rnd, (dx, dy, hh * 0.45), (w * 0.54, d * 0.54, hh * 0.62), hh, 16, lean * w * 0.8,
                          rough, seed=seed + 5 + k)
        all_pts += pts
        hulls.append(hull_object(f"{name}_lump{k}", pts))
    # collision convexe = enveloppe de tous les points
    col = hull_object(name + "_colsrc", all_pts)
    colobj = common.collision_from(col, name)
    bpy.data.objects.remove(col, do_unlink=True)
    colobj.name = name + "-convcol"
    parts = []
    for i, ho in enumerate(hulls):
        bpy.context.view_layer.objects.active = ho
        b = bevel * (1.0 if i == 0 else 0.8)
        bev = ho.modifiers.new("bevel", "BEVEL")
        bev.width = b
        bev.segments = 1
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(12)
        bpy.ops.object.select_all(action="DESELECT")
        ho.select_set(True)
        bpy.ops.object.modifier_apply(modifier="bevel")
        color_rock(ho, height if i == 0 else height * 0.7, seed + i * 7, moss_top)
        if moss_thick > 0:
            moss_layer(ho, height, seed + i, thick=moss_thick)
        parts.append(ho)
    # volumes de mousse poses a la surface (ray cast sur le bloc principal)
    moss = Mesh()
    main = hulls[0]
    attempts = 0
    placed = 0
    while placed < top_moss and attempts < 80:
        attempts += 1
        x = rnd.uniform(-width * 0.30, width * 0.30)
        y = rnd.uniform(-depth * 0.30, depth * 0.30)
        loc, nrm = surface_point(main, x, y, height * 2)
        if loc is None or nrm.z < 0.62:
            continue
        r = blob_r * rnd.uniform(0.7, 1.25)
        moss.blob(loc - nrm * (r * 0.30), (r * rnd.uniform(1.1, 1.6), r * rnd.uniform(1.1, 1.5), r * 0.62),
                  "moss", quat=align_quat(nrm, rnd.uniform(0, 6.28)), noise=0.12, seed=seed + placed, subdiv=2)
        placed += 1
    placed = 0
    attempts = 0
    while placed < base_moss and attempts < 120:
        attempts += 1
        ang = rnd.uniform(0, 2 * math.pi)
        z = rnd.uniform(0.03, height * 0.22)
        loc, nrm = side_point(main, ang, z, max(width, depth))
        if loc is None:
            continue
        r = blob_r * rnd.uniform(0.55, 0.95)
        nrm = Vector((nrm.x, nrm.y, max(nrm.z, 0.0) + 0.5)).normalized()
        moss.blob(Vector((loc.x, loc.y, max(loc.z, r * 0.36))) + Vector((nrm.x, nrm.y, 0)) * (-r * 0.45),
                  (r * 1.2, r * 1.5, r * 0.62), "moss", quat=Quaternion((0, 0, 1), ang), noise=0.12,
                  seed=seed + 50 + placed, bottom=0.5, subdiv=2)
        placed += 1
    mo = moss.build(name + "_moss")
    body = join(parts + [mo], name) if False else join(parts, name)
    fit_to_width(width)
    return body


def fit_to_width(width):
    """Echelle uniforme pour que la largeur X visuelle vaille `width`, recentre en XY, pose au sol."""
    vis = visual_objects()
    mn, mx = world_bounds(vis)
    f = width / (mx.x - mn.x)
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.scale = (f, f, f)
            o.location = (-cx * f, -cy * f, 0)
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
