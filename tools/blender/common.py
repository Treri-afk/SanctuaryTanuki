"""Module commun des scripts Blender de Gardien de sanctuaire.

Usage dans un script de modele (depuis la racine du projet) :

    import sys, os
    sys.path.insert(0, os.path.dirname(__file__))
    from common import *
    reset_scene()
    ... construire ...
    finish_model("torii", expected_dims=(3.5, 4.0, 3.5))   # exporte glb, blend, preview, stats

Lancement :
    blender --background --python tools/blender/<script>.py

Conventions : 1 unite = 1 m, origine au sol centree, avant = -Y Blender, snake_case anglais.
Un seul materiau = une couleur unie (pas de texture).
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS_DIR = os.path.join(ROOT, "assets", "models")
BLEND_DIR = os.path.join(ROOT, "assets", "blender")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")

PALETTE = {
    "lacquer_red":   "#C8442B",
    "wood_dark":     "#5A3A26",
    "wood_light":    "#A87B4F",
    "wood_faded":    "#8C7155",   # bois decolore par le temps
    "stone":         "#8E8A80",
    "stone_dark":    "#6F6B63",
    "moss":          "#6F8A3E",
    "paper":         "#EFE6D2",
    "lacquer_black": "#1E1E22",
    "metal":         "#6B6F73",
    "metal_gold":    "#B8933A",
    "foliage_orange": "#D9822B",
    "foliage_red":   "#B8452A",
    "bamboo":        "#B9A25A",
    "water":         "#5F8FA8",
    "straw":         "#C9AE6A",
    "rope":          "#CFC0A0",
}

BEVEL_WIDTH = 0.025     # bevel standard (m). Harmoniser entre agents : ne pas changer.
BEVEL_SEGMENTS = 2
SMOOTH_ANGLE = math.radians(40)


def hex_to_linear(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]
    return (*lin, 1.0)


_mat_cache = {}


def mat(name):
    """Materiau uni nomme par usage (cle de PALETTE)."""
    if name in _mat_cache and _mat_cache[name].name in bpy.data.materials:
        return _mat_cache[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    col = hex_to_linear(PALETTE[name])
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.9
    m.diffuse_color = col
    _mat_cache[name] = m
    return m


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mat_cache.clear()
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0


# ---------------------------------------------------------------- primitives
def _finalize_obj(obj, material, bevel, name, smooth=True):
    obj.name = name
    obj.data.name = name
    if material is not None:
        obj.data.materials.clear()
        obj.data.materials.append(mat(material) if isinstance(material, str) else material)
    if bevel:
        bpy.context.view_layer.objects.active = obj
        m = obj.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = BEVEL_SEGMENTS
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(30)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier="bevel")
    return obj


def box(name, size, loc=(0, 0, 0), material="wood_dark", rot=(0, 0, 0), bevel=BEVEL_WIDTH):
    """Boite de dimensions size=(x,y,z), centree sur loc."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finalize_obj(o, material, bevel, name)


def cylinder(name, radius, depth, loc=(0, 0, 0), material="wood_dark", rot=(0, 0, 0),
             verts=16, bevel=BEVEL_WIDTH, radius2=None):
    """Cylindre (ou cone tronque si radius2). Axe Z par defaut, centre sur loc."""
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth,
                                        location=loc, rotation=rot)
    return _finalize_obj(bpy.context.object, material, bevel, name)


def sphere(name, radius, loc=(0, 0, 0), material="stone", scale=(1, 1, 1), seg=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=radius, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finalize_obj(o, material, 0, name)


def mesh_from_data(name, verts, faces, material="wood_dark", loc=(0, 0, 0), bevel=BEVEL_WIDTH):
    """Mesh a partir de sommets/faces (pour toits courbes, etc.)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    bpy.context.view_layer.objects.active = o
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return _finalize_obj(o, material, bevel, name)


def empty(name, loc=(0, 0, 0), kind="PLAIN_AXES", size=0.1, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    e.location = loc
    bpy.context.collection.objects.link(e)
    if parent:
        e.parent = parent
    return e


def collision_box(name, size, loc=(0, 0, 0)):
    """Collision simplifiee : boite nommee '<name>-col' (importee par Godot en StaticBody3D + shape)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.name = name + "-col"
    o.data.name = name + "-col"
    o.display_type = "WIRE"
    return o


def collision_from(obj, name):
    """Copie d'un mesh (convexe attendu) en '<name>-convcol' pour une collision convexe."""
    c = obj.copy()
    c.data = obj.data.copy()
    c.modifiers.clear()
    c.name = name + "-convcol"
    c.data.name = name + "-convcol"
    c.display_type = "WIRE"
    bpy.context.collection.objects.link(c)
    return c


def join(objs, name, material=None):
    """Fusionne des objets en un seul (garde les materiaux de chaque piece)."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    return o


def shade(obj, angle=SMOOTH_ANGLE):
    """Shade Smooth + 'Smooth by Angle' (equivalent Auto Smooth, Blender >= 4.1)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=angle)
    except Exception:
        bpy.ops.object.shade_auto_smooth(angle=angle)


def clean(obj):
    """Fusionne les doublons, supprime faces dupliquees/degenerees."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


# ---------------------------------------------------------------- verification
def tri_count(obj):
    me = obj.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def visual_objects():
    return [o for o in bpy.context.scene.objects
            if o.type == "MESH" and not (o.name.endswith("-col") or o.name.endswith("-convcol")
                                         or o.name.endswith("-colonly"))]


def world_bounds(objs):
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn[i], w[i]) for i in range(3)))
            mx = Vector((max(mx[i], w[i]) for i in range(3)))
    return mn, mx


def apply_all_transforms():
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def report(name, expected_dims=None, tol=0.25, tri_limit=(500, 5000)):
    """Retourne un dict de stats et affiche les avertissements."""
    vis = visual_objects()
    tris = sum(tri_count(o) for o in vis)
    mn, mx = world_bounds(vis)
    dims = mx - mn
    info = {
        "name": name, "triangles": tris,
        "dims_xyz_m": [round(dims.x, 3), round(dims.y, 3), round(dims.z, 3)],
        "min_z": round(mn.z, 3),
        "center_xy": [round((mn.x + mx.x) / 2, 3), round((mn.y + mx.y) / 2, 3)],
        "collisions": sorted(o.name for o in bpy.context.scene.objects if "col" in o.name.split("-")[-1]),
        "materials": sorted({m.name for m in bpy.data.materials if m.users}),
        "warnings": [],
    }
    if not (tri_limit[0] <= tris <= tri_limit[1]):
        info["warnings"].append(f"triangles {tris} hors budget {tri_limit}")
    if abs(mn.z) > 0.02:
        info["warnings"].append(f"origine pas au sol (min z = {mn.z:.3f})")
    if expected_dims:
        for i, (got, exp) in enumerate(zip(dims, expected_dims)):
            if exp and abs(got - exp) / exp > tol:
                info["warnings"].append(f"axe {'XYZ'[i]} : {got:.2f} m au lieu de ~{exp} m")
    return info


# ---------------------------------------------------------------- previsualisation
def render_preview(name, size=900, yaw=35.0, pitch=22.0, margin=1.25, target_obj_names=None):
    """Rend assets/previews/<name>.png : vue 3/4, fond neutre, eclairage simple.
    La camera cadre automatiquement l'objet ; avant de l'objet (-Y) vu depuis le coin avant-droit."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    sc = bpy.context.scene
    vis = visual_objects()
    mn, mx = world_bounds(vis)
    ctr = (mn + mx) / 2
    radius = max((mx - mn).length / 2, 0.05)

    # fond + eclairage
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.62, 0.64, 0.68, 1)
    bg.inputs["Strength"].default_value = 0.6
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.5
    so = bpy.data.objects.new("sun", sun)
    bpy.context.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    fill = bpy.data.lights.new("fill", "SUN")
    fill.energy = 0.6
    fo = bpy.data.objects.new("fill", fill)
    bpy.context.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(70), 0, math.radians(140))

    # sol de reference discret
    bpy.ops.mesh.primitive_plane_add(size=max(6 * radius, 2), location=(ctr.x, ctr.y, 0))
    ground = bpy.context.object
    ground.name = "preview_ground"
    gm = bpy.data.materials.new("preview_ground")
    gm.diffuse_color = (0.45, 0.46, 0.45, 1)
    ground.data.materials.append(gm)

    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(co)
    sc.camera = co
    dist = radius * margin / math.sin(cam.angle / 2)
    yawr, pitr = math.radians(yaw), math.radians(pitch)
    # avant = -Y ; camera devant (-Y) et legerement a droite (+X)
    co.location = (ctr.x + dist * math.sin(yawr) * math.cos(pitr),
                   ctr.y - dist * math.cos(yawr) * math.cos(pitr),
                   ctr.z + dist * math.sin(pitr))
    direction = ctr - co.location
    co.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    for o in bpy.context.scene.objects:   # les collisions ne doivent pas apparaitre
        if o.type == "MESH" and o not in visual_objects() and o is not ground:
            o.hide_render = True
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.film_transparent = False
    sc.render.filepath = os.path.join(PREVIEW_DIR, name + ".png")
    sc.render.image_settings.file_format = "PNG"
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    if sc.render.engine == "BLENDER_WORKBENCH":
        sc.display.shading.light = "STUDIO"
        sc.display.shading.color_type = "MATERIAL"
    bpy.ops.render.render(write_still=True)
    # nettoyage pour ne pas polluer l'export / le .blend
    for o in (so, fo, co, ground):
        bpy.data.objects.remove(o, do_unlink=True)
    return sc.render.filepath


# ---------------------------------------------------------------- export
# ---------------------------------------------------------------- teinte de sommet
# Chaque modele exporte porte un attribut de couleur "Col" (gris, 1.0 = neutre) que le shader toon du jeu
# multiplie a la couleur du materiau : creux assombris (occlusion ambiante) et pied des objets plus sombre.
# C'est applique automatiquement par export_glb. Reglages par script : common.TINT = False pour desactiver,
# ou modifier common.TINT_AO / TINT_AO_DIST / TINT_GROUND / TINT_GROUND_H avant l'export.
TINT = True
TINT_AO = 0.45         # assombrissement maximal dans les creux
TINT_AO_DIST = 0.7     # portee des rayons d'occlusion (m)
TINT_GROUND = 0.14     # assombrissement au ras du sol
TINT_GROUND_H = 0.5    # hauteur (m) ou l'assombrissement du sol disparait


def apply_vertex_tint(objs=None):
    """Calcule l'attribut de couleur "Col" (occlusion ambiante par lancer de rayons + fondu au sol)."""
    from mathutils.bvhtree import BVHTree
    objs = [o for o in (objs or visual_objects()) if o.type == "MESH" and len(o.data.polygons)]
    if not objs:
        return
    verts, polys = [], []
    for o in objs:
        off = len(verts)
        mw = o.matrix_world
        verts.extend([mw @ v.co for v in o.data.vertices])
        polys.extend([[off + i for i in p.vertices] for p in o.data.polygons])
    bvh = BVHTree.FromPolygons(verts, polys)
    # 16 directions reparties sur l'hemisphere (spirale de Fibonacci), en repere tangent (x, y, z = normale)
    dirs = []
    n_dirs = 16
    for i in range(n_dirs):
        z = 0.15 + 0.85 * (i + 0.5) / n_dirs
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = i * 2.39996323
        dirs.append((r * math.cos(a), r * math.sin(a), z))
    for o in objs:
        me = o.data
        mw = o.matrix_world
        nm = mw.to_3x3().inverted_safe().transposed()
        attr = me.color_attributes.get("Col")
        if attr is not None:
            me.color_attributes.remove(attr)
        attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        cache = {}
        normals = me.corner_normals
        for li, loop in enumerate(me.loops):
            vi = loop.vertex_index
            n = (nm @ Vector(normals[li].vector)).normalized()
            key = (vi, round(n.x, 1), round(n.y, 1), round(n.z, 1))
            val = cache.get(key)
            if val is None:
                p = mw @ me.vertices[vi].co
                t = n.cross(Vector((0.0, 0.0, 1.0)) if abs(n.z) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
                b = n.cross(t)
                origin = p + n * 0.015
                occ = 0.0
                for dx, dy, dz in dirs:
                    w = t * dx + b * dy + n * dz
                    hit = bvh.ray_cast(origin, w, TINT_AO_DIST)
                    if hit[0] is not None:
                        occ += 1.0 - hit[3] / TINT_AO_DIST
                ao = min(1.0, occ / n_dirs * 1.7)
                val = 1.0 - TINT_AO * ao
                if 0.0 <= p.z < TINT_GROUND_H or -0.05 < p.z < 0.0:
                    val *= 1.0 - TINT_GROUND * (1.0 - max(p.z, 0.0) / TINT_GROUND_H)
                cache[key] = val
            attr.data[li].color = (val, val, val, 1.0)
        me.color_attributes.active_color = attr
        try:
            me.color_attributes.render_color_index = me.color_attributes.find("Col")
        except Exception:
            pass


def export_glb(name, selection=None):
    os.makedirs(MODELS_DIR, exist_ok=True)
    path = os.path.join(MODELS_DIR, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "EMPTY"} and (selection is None or o in selection):
            o.select_set(True)
    # Godot : le suffixe "-col" garde le mesh visible ; "-convcolonly" ne garde que la collision convexe.
    renamed = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and (o.name.endswith("-col") or o.name.endswith("-convcol")):
            renamed.append((o, o.name))
            o.name = o.name.rsplit("-", 1)[0] + "-convcolonly"
    kw = {}
    if TINT:
        apply_vertex_tint()
        kw = dict(export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                  export_active_vertex_color_when_no_material=True)
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_yup=True, export_apply=True, export_cameras=False,
                                  export_lights=False, export_extras=False, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_yup=True, export_apply=True, export_cameras=False,
                                  export_lights=False, export_extras=False)
    for o, n in renamed:
        o.name = n
    return path


def finish_model(name, expected_dims=None, tri_limit=(500, 5000), preview=True, **preview_kw):
    """A appeler en fin de script : nettoie, lisse, rapporte, sauvegarde .blend, exporte .glb, rend la preview."""
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and not o.name.endswith("preview_ground"):
            clean(o)
            shade(o)
    apply_all_transforms()
    info = report(name, expected_dims, tri_limit=tri_limit)
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    info["glb"] = export_glb(name)
    if preview:
        info["preview"] = render_preview(name, **preview_kw)
    stats_dir = os.path.join(ROOT, "assets", "previews")
    os.makedirs(stats_dir, exist_ok=True)
    with open(os.path.join(stats_dir, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("MODEL_REPORT " + json.dumps(info))
    return info
