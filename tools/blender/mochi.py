"""Mochi, le chat de Hina (blanc à taches rousses), à partir de « Toon Cat FREE » d'Omabuarts Studio
(Sketchfab, CC-BY-4.0 : https://sketchfab.com/3d-models/toon-cat-free-b2bd1ee7858444bda366110a2d960386).

Le modèle d'origine (assets/animals/chat/toon_cat_free.glb) est brun et n'a qu'une marche. Ce script :
- repeint le pelage en couleurs de sommet : blanc, taches rousses (calotte et oreille gauche, selle sur le dos,
  queue rousse au bout) ; les yeux, le nez et l'intérieur des oreilles gardent leurs couleurs ;
- garde la marche (« walk ») et ajoute, à partir de la posture moyenne de la marche :
    idle     debout : respiration, queue qui ondule, regard à gauche puis à droite, clignement, oreille qui frémit ;
    sit      assis sur son derrière, queue enroulée sur les pattes avant, clignement lent ;
    sleep    couché en boule au soleil, yeux fermés, respiration lente ;
    content  caressé, assis : yeux mi-clos, tête qui se tend et se frotte, bout de la queue qui frémit ;
- exporte assets/animals/chat/mochi.glb (le jeu le met à l'échelle : scripts/cat.gd).
Lancer : blender --background --python tools/blender/mochi.py [-- dossier_apercus]"""
import bpy, sys, os, math, random
from mathutils import Vector, Matrix, Quaternion

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "animals", "chat", "toon_cat_free.glb")
OUT = os.path.join(ROOT, "assets", "animals", "chat", "mochi.glb")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = args[0] if args else ""
FPS = 24

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
sc.render.fps = FPS
if bpy.data.objects.get("Icosphere"):
    bpy.data.objects.remove(bpy.data.objects["Icosphere"])     # sphère orpheline livrée avec le fichier
arm = [o for o in sc.objects if o.type == "ARMATURE"][0]
mesh = [o for o in sc.objects if o.type == "MESH"][0]
P = arm.pose.bones
walk = arm.animation_data.action
walk.name = "walk"
walk.use_fake_user = True
for pb in P:
    pb.rotation_mode = "QUATERNION"

# repère du monde dans l'espace de l'armature : haut Z, avant -Y, gauche +X
AM = arm.matrix_world
A3 = AM.to_3x3().normalized().inverted()
SW = AM.to_scale()[0]


def ax(v):
    return (A3 @ Vector(v)).normalized()


UP, FWD, LEFT = ax((0, 0, 1)), ax((0, -1, 0)), ax((1, 0, 0))


def update():
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- posture de base : moyenne de la marche
acc = {pb.name: [Vector(), Vector((0, 0, 0, 0)), Vector(), None] for pb in P}
for f in range(0, 20):
    sc.frame_set(f)
    for pb in P:
        a = acc[pb.name]
        q = pb.rotation_quaternion.copy()
        if a[3] is None:
            a[3] = q.copy()
        if q.dot(a[3]) < 0:
            q.negate()
        a[0] += pb.location
        a[1] += Vector(q)
        a[2] += pb.scale
BASE = {n: (l / 20, Quaternion(q / 20).normalized(), s / 20) for n, (l, q, s, _) in acc.items()}
arm.animation_data.action = None


def reset():
    for pb in P:
        l, q, s = BASE[pb.name]
        pb.location, pb.rotation_quaternion, pb.scale = l, q, s
    update()


def mesh_min_z():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    mw = ev.matrix_world
    return min((mw @ v.co).z for v in ev.data.vertices)


def mesh_bounds():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    mw = ev.matrix_world
    pts = [mw @ v.co for v in ev.data.vertices]
    return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])


reset()
GROUND = mesh_min_z()
BMIN, BMAX = mesh_bounds()
H = BMAX.z - BMIN.z               # hauteur du chat debout (unités de la scène)
print("MOCHI base : hauteur %.1f, sol %.1f" % (H, GROUND))


# ---------------------------------------------------------------- outils de pose (espace monde)
def rot(name, axis, deg):
    """Tourne un os autour d'un axe du monde, pivot à sa tête ; ses enfants suivent."""
    pb = P[name]
    update()
    M = pb.matrix.copy()
    h = M.translation.copy()
    R = Matrix.Rotation(math.radians(deg), 4, axis)
    pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M


def pitch(name, deg):
    """+ = l'extrémité de l'os monte vers l'avant (le nez se lève)."""
    rot(name, -LEFT, deg)


def yaw(name, deg):
    """+ = vers la gauche du chat."""
    rot(name, UP, deg)


def roll(name, deg):
    rot(name, FWD, deg)


def move(name, world_vec):
    pb = P[name]
    update()
    M = pb.matrix.copy()
    pb.matrix = Matrix.Translation(A3 @ Vector(world_vec) / SW) @ M


def squash(name, s, axis=None):
    """Écrase un os le long d'un axe du monde (paupières : on aplatit l'œil)."""
    pb = P[name]
    update()
    M = pb.matrix.copy()
    h = M.translation.copy()
    u = (axis or UP).normalized()
    S = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            S[i][j] += (s - 1.0) * u[i] * u[j]
    pb.matrix = Matrix.Translation(h) @ S @ Matrix.Translation(-h) @ M


def to_ground(extra=0.0):
    """Pose le point le plus bas du chat sur le sol (en déplaçant tout le corps)."""
    update()
    dz = GROUND - mesh_min_z() + extra
    move("root_01", (0, 0, dz))


def blink(t, at, dur=0.16, close=0.12):
    """Facteur d'ouverture des yeux (1 = ouverts) pour un clignement à l'instant `at`."""
    d = abs(t - at) / (dur / 2)
    return 1.0 if d >= 1 else close + (1 - close) * d * d


def eyes(open_k):
    """Ferme les yeux en aplatissant chaque œil le long de son axe propre le plus vertical (une échelle sur un axe
    de l'os : elle survit à l'export, contrairement à un écrasement en biais)."""
    if open_k >= 0.999:
        return
    update()
    for n in ("eye.L_022", "eye.R_023"):
        pb = P[n]
        m3 = pb.matrix.to_3x3()
        i = max(range(3), key=lambda k: abs(m3.col[k].normalized().dot(UP)))
        sc_ = pb.scale.copy()
        sc_[i] *= open_k
        pb.scale = sc_


TAIL = ["tail_07", "tail.01_08", "tail.02_09", "tail.03_010", "tail.end_011"]
HIND = {"L": ["thigh.B.L_03", "leg.upper.B.L_04", "leg.lower.B.L_05", "foot.B.L_06"],
        "R": ["thigh.B.R_026", "leg.upper.B.R_027", "leg.lower.B.R_028", "foot.B.R_029"]}
FRONT = {"L": ["leg.upper.F.L_014", "leg.lower.FL_015", "foot.F.L_016"],
         "R": ["leg.upper.F.R_024", "leg.lower.F.R_00", "foot.F.R_025"]}


# ---------------------------------------------------------------- poses (t en secondes)
def pose_idle(t, T):
    w = 2 * math.pi / T
    pitch("spine.01_012", 1.2 * math.sin(w * 2 * t))                 # respiration
    look = math.sin(w * t) * 16 * min(1.0, abs(math.sin(w * t)) * 1.6)
    yaw("neck_017", look * 0.4)
    yaw("head_018", look * 0.6)
    pitch("head_018", 4 * math.sin(w * t * 2 + 1.0))
    for i, b in enumerate(TAIL):
        yaw(b, (6 + 4 * i) * math.sin(w * t - i * 0.7))
    if 2.4 < t < 2.75:                                               # oreille qui frémit
        rot("ear.L_019", FWD, -25 * math.sin((t - 2.4) / 0.35 * math.pi))
    eyes(min(blink(t, 1.1), blink(t, 3.3)))


def pose_sit(t, T, blinks=True):
    """Angles calculés depuis la posture moyenne : cuisse en avant le long du sol, jarret en arrière, métatarse à plat
    vers l'avant ; pattes avant d'aplomb sous le poitrail."""
    w = 2 * math.pi / T
    pitch("torso_02", 45)                         # le corps se redresse autour du bassin
    pitch("spine.01_012", 4)
    pitch("neck_017", -26)
    pitch("head_018", -16 + 1.5 * math.sin(w * t))
    for s in "LR":
        th, up, lo, ft = HIND[s]
        pitch(th, 29)
        pitch(up, -87)
        pitch(lo, 104)
        pitch(ft, -59)
        fu, fl, ff = FRONT[s]
        pitch(fu, -22)
        pitch(fl, -63)
        pitch(ff, 73)
    pitch(TAIL[0], 22)                            # la queue descend au sol puis s'enroule devant les pattes
    for i, b in enumerate(TAIL[1:]):
        pitch(b, -5)
        yaw(b, 38 + 3 * math.sin(w * t * 2 - i))
    pitch("spine.02_013", 0.8 * math.sin(w * 2 * t))
    to_ground()
    if blinks:
        eyes(min(blink(t, 1.6, 0.5, 0.25), blink(t, 3.4)))


def pose_sleep(t, T):
    """Couché en pain (« loaf ») : pattes avant repliées sous le poitrail, cuisses le long du corps, tête basse."""
    w = 2 * math.pi / T
    for s in "LR":
        th, up, lo, ft = HIND[s]
        pitch(th, 44)
        pitch(up, -67)
        pitch(lo, 114)
        pitch(ft, -36)
        fu, fl, ff = FRONT[s]
        pitch(fu, -17)
        pitch(fl, -113)
        pitch(ff, -60)
    pitch("neck_017", -34)
    pitch("head_018", 8)
    yaw("neck_017", 18)
    roll("head_018", 10)
    for i, b in enumerate(TAIL):                 # la queue fait le tour du corps, posée au sol
        pitch(b, 62 if i == 0 else 4)
        yaw(b, 0 if i == 0 else 36)
    breath = math.sin(w * t)
    pitch("spine.01_012", 1.6 * breath)
    squash("torso_02", 1.0 + 0.025 * breath, LEFT)
    # le ventre repose au sol : les pattes repliées disparaissent dessous
    update()
    hip = (AM @ P["torso_02"].head).z
    move("root_01", (0, 0, GROUND + 0.24 * H - hip))
    eyes(0.1)


def pose_content(t, T):
    """Caressé, assis : la tête se tend et se frotte (roulis), yeux mi-clos, oreilles un peu couchées."""
    w = 2 * math.pi / T
    pose_sit(t, T, blinks=False)
    pitch("neck_017", 8)
    pitch("head_018", 16 + 4 * math.sin(w * t))
    roll("head_018", 10 * math.sin(w * t * 0.5))
    yaw(TAIL[-1], 12 * math.sin(w * t * 3))
    rot("ear.L_019", FWD, -12)
    rot("ear.R_020", FWD, 12)
    eyes(0.3 + 0.08 * math.sin(w * t))


ANIMS = [("idle", pose_idle, 4.0), ("sit", pose_sit, 4.0), ("sleep", pose_sleep, 5.0), ("content", pose_content, 2.0)]


def bake(name, fn, T, step=2):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    n = int(T * FPS)
    for f in list(range(0, n, step)) + [n]:
        reset()
        fn((f % n) / FPS, T)
        update()
        for pb in P:
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("scale", frame=f)
    arm.animation_data.action = None
    return act


# ---------------------------------------------------------------- pelage : blanc à taches rousses
def repaint():
    me = mesh.data
    img = None
    for m in me.materials:
        for nd in m.node_tree.nodes:
            if nd.type == "TEX_IMAGE" and nd.image:
                img = nd.image
    W, Hh = img.size
    px = list(img.pixels[:])

    def sample(u, v):
        x = min(W - 1, max(0, int(u * W)))
        y = min(Hh - 1, max(0, int(v * Hh)))
        i = (y * W + x) * 4
        return px[i], px[i + 1], px[i + 2]

    reset()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    mw = ev.matrix_world
    pos = [mw @ v.co for v in ev.data.vertices]
    mn, mx = mesh_bounds()
    L = mx.y - mn.y
    uv = me.uv_layers.active.data
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    WHITE = (0.94, 0.92, 0.88)
    CREAM = (0.90, 0.86, 0.80)
    RUSSET = (0.80, 0.42, 0.20)
    RUSSET_D = (0.64, 0.31, 0.15)

    def lin(c):
        return tuple(x ** 2.2 for x in c)

    def patch(p):
        """0 = blanc, 1 = roux : calotte + oreille gauche, selle, bout de la queue."""
        u = (p.y - mn.y) / L                    # 0 = nez (avant -Y), 1 = bout de la queue
        h = (p.z - mn.z) / H
        x = p.x
        wob = 0.03 * math.sin(p.x * 0.05 + p.y * 0.03) + 0.02 * math.sin(p.z * 0.07 - p.y * 0.05)
        k = 0.0
        # calotte : dessus de la tête, débordant sur l'œil gauche et l'oreille gauche
        if u < 0.34 and (h > 0.86 + wob or (x > 12 + 20 * wob and h > 0.66 and u > 0.06)):
            k = 1.0
        # selle sur le dos (milieu du corps), plus large d'un côté
        d = ((u - 0.52 - wob) / 0.16) ** 2 + ((h - 0.62) / 0.2) ** 2 + (max(0.0, -x - 10) / 60.0) ** 2
        if d < 1.0 and h > 0.42:
            k = 1.0
        # queue : rousse sur sa moitié de bout
        if u > 0.74 + wob:
            k = 1.0
        return k

    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            r, g, b = sample(uv[li].uv.x, uv[li].uv.y)
            mxc, mnc = max(r, g, b), min(r, g, b)
            sat = (mxc - mnc) / mxc if mxc > 1e-4 else 0.0
            hue_ok = r >= g >= b * 0.9
            fur = hue_ok and sat > 0.35 and 0.12 < mxc < 0.95 and not (r > 0.6 and g < r * 0.55 and b > g)
            if fur:
                k = patch(pos[vi])
                shade = min(1.0, mxc / 0.55)               # garde le dégradé (ventre plus clair, dos plus sombre)
                base = RUSSET if k > 0.5 else WHITE
                dark = RUSSET_D if k > 0.5 else CREAM
                c = lin(tuple(dark[i] + (base[i] - dark[i]) * shade for i in range(3)))
            else:
                c = lin((r, g, b))           # pixels de l'image en sRGB ; l'attribut attend du linéaire
            col.data[li].color = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = col
    # le matériau affiche les couleurs de sommet (aperçus) ; le jeu les lit directement (Toon, use_vertex_color)
    m = me.materials[0]
    nt = m.node_tree
    bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])


if os.environ.get("MOCHI_DEBUG"):           # positions des articulations (mise au point des poses)
    def joints(tag):
        update()
        for n in ["torso_02", "spine.02_013", "leg.upper.F.L_014", "leg.lower.FL_015", "foot.F.L_016", "thigh.B.L_03",
                  "leg.upper.B.L_04", "leg.lower.B.L_05", "foot.B.L_06", "head_018"]:
            pb = P[n]
            h = AM @ pb.head
            t = AM @ pb.tail
            print("J %-6s %-18s head y=%7.1f z=%7.1f  tail y=%7.1f z=%7.1f" % (tag, n, h.y, h.z, t.y, t.z))
    reset()
    joints("base")
    reset()
    pitch("leg.upper.F.L_014", 60)
    joints("F+60")
    reset()
    pose_sleep(0, 5.0)
    joints("sleep")
    sys.exit(0)
def rebake_walk():
    """La marche d'origine s'exporte dans un autre repère (le corps part à des mètres) : on la ré-échantillonne
    image par image dans une action neuve, comme les autres."""
    frames = []
    arm.animation_data.action = walk
    for f in range(0, 21):
        sc.frame_set(f)
        frames.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in P})
    arm.animation_data.action = None
    walk.name = "walk_source"
    walk.use_fake_user = False
    act = bpy.data.actions.new("walk")
    act.use_fake_user = True
    arm.animation_data.action = act
    for f, fr in enumerate(frames):
        for pb in P:
            pb.location, pb.rotation_quaternion, pb.scale = fr[pb.name]
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("scale", frame=f)
    arm.animation_data.action = None
    bpy.data.actions.remove(walk)
    return act


repaint()
walk = rebake_walk()
made = [bake(n, fn, T) for (n, fn, T) in ANIMS]
print("MOCHI animations :", ["walk"] + [a.name for a in made])

# ---------------------------------------------------------------- aperçus
if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = H * 2.0
    cam.data.clip_end = 100000
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "VERTEX"
    sc.display.shading.light = "STUDIO"
    sc.render.resolution_x = sc.render.resolution_y = 300
    c = (BMIN + BMAX) / 2
    D = H * 6
    views = {"side": ((c.x + D, c.y, c.z), (math.pi / 2, 0, math.pi / 2)),
             "front": ((c.x, c.y - D, c.z), (math.pi / 2, 0, 0)),
             "top3q": ((c.x + D * 0.6, c.y - D * 0.6, c.z + D * 0.5), (math.radians(60), 0, math.radians(45)))}
    for act in [walk] + made:
        arm.animation_data.action = act
        fr = act.frame_range
        sc.frame_set(int(fr[0] + (fr[1] - fr[0]) * 0.3))
        for vn, (loc, r) in views.items():
            cam.location, cam.rotation_euler = loc, r
            sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (act.name, vn))
            bpy.ops.render.render(write_still=True)
    arm.animation_data.action = None

# ---------------------------------------------------------------- export
arm.animation_data.action = None
reset()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="ACTIONS", export_force_sampling=True,
                          export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_yup=True)
print("MOCHI export", OUT)
