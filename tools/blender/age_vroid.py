## Vieillit un modèle VRoid : rides peintes sur la texture du visage, paupières tombantes, peau ternie,
## sourcils gris. Le dos voûté se règle dans le jeu ("stoop" dans scripts/placeholder_visitor.gd).
## Usage :
##   /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/age_vroid.py -- \
##       "$PWD/assets/characters/fumiko/original/fumiko_base.vrm" "$PWD/assets/characters/fumiko/fumiko.vrm" [dossier_apercu]
## Les coordonnées des rides sont celles de la texture du visage VRoid (1024 px), communes à tous les modèles VRoid.
## AGE_DEBUG=1 dessine une grille sur la texture pour repérer où elle tombe sur le visage.
## Nécessite l'extension Blender « VRM format ».
import bpy, sys, os, math
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
PREVIEW = a[2] if len(a) > 2 else ""

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
bpy.ops.import_scene.vrm(filepath=SRC)

# ---------------------------------------------------------------- texture du visage
def face_image():
    m = bpy.data.materials["N00_000_00_Face_00_SKIN (Instance)"]
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and n.image.size[0] == n.image.size[1] and n.image.name != "N00_000_00_Face_00_out":
            return n.image
    raise RuntimeError("texture du visage introuvable")

def body_image():
    m = bpy.data.materials["N00_000_00_Body_00_SKIN (Instance)"]
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and n.image.size[0] >= 1024:
            return n.image
    return None

def load(img):
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return px[::-1].copy()   # ligne 0 = haut de l'image (comme dans un PNG)

def store(img, arr):
    img.pixels[:] = arr[::-1].reshape(-1).tolist()
    img.update()
    img.pack()   # sinon l'export VRM peut reprendre l'image d'origine encore empaquetée

def blur(arr, r):
    # flou boîte séparable (r en pixels), répété 2 fois ≈ gaussien
    out = arr
    for _ in range(2):
        k = 2 * r + 1
        pad = np.pad(out, ((r, r), (0, 0), (0, 0)), mode="edge")
        c = np.cumsum(pad, axis=0)
        c = np.concatenate([np.zeros_like(c[:1]), c], axis=0)
        out = (c[k:] - c[:-k]) / k
        pad = np.pad(out, ((0, 0), (r, r), (0, 0)), mode="edge")
        c = np.cumsum(pad, axis=1)
        c = np.concatenate([np.zeros_like(c[:, :1]), c], axis=1)
        out = (c[:, k:] - c[:, :-k]) / k
    return out

def bezier(pts, n=60):
    # courbe passant près des points (Catmull-Rom)
    pts = [np.array(p, dtype=np.float32) for p in pts]
    pts = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-2])
    return out

def stroke(mask, pts, width, strength, taper=True):
    # trace une ligne douce ; s'amincit et s'efface aux deux bouts
    curve = bezier(pts)
    h, w = mask.shape
    n = len(curve)
    for i, p in enumerate(curve):
        f = i / max(1, n - 1)
        k = math.sin(math.pi * f) ** 0.7 if taper else 1.0
        sig = max(0.6, width * (0.45 + 0.55 * k))
        r = int(sig * 3) + 1
        x0, y0 = int(p[0]), int(p[1])
        ys, xs = np.mgrid[max(0, y0 - r):min(h, y0 + r + 1), max(0, x0 - r):min(w, x0 + r + 1)]
        d2 = (xs - p[0]) ** 2 + (ys - p[1]) ** 2
        v = strength * k * np.exp(-d2 / (2 * sig * sig))
        sl = mask[max(0, y0 - r):min(h, y0 + r + 1), max(0, x0 - r):min(w, x0 + r + 1)]
        np.maximum(sl, v, out=sl)

def mirror(pts, cx):
    return [(2 * cx - x, y) for x, y in pts]

img = face_image()
S = img.size[0] / 1024.0   # coordonnées écrites pour une texture 1024
face = load(img)
rgb = face[:, :, :3]
CX = 512.5

def P(pts):
    return [(x * S, y * S) for x, y in pts]

# 1) peau un peu ternie et moins rose
grey = rgb.mean(axis=2, keepdims=True)
warm = np.array([1.0, 0.95, 0.90], dtype=np.float32)
rgb[:] = rgb * 0.82 + grey * warm * 0.18
rgb *= 0.985

# 2) joues : on adoucit les hachures de blush (flou local) et on retire une partie du rose
blurred = blur(rgb, int(10 * S))
ref = rgb[int(470 * S), int(512 * S)].copy()   # peau du milieu du visage, sans blush
hh, ww = rgb.shape[:2]
yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32)
for cx in (330.0, 695.0):
    e = ((xx - cx * S) / (110 * S)) ** 2 + ((yy - 635 * S) / (50 * S)) ** 2
    m = np.clip(1.2 - e, 0, 1)[..., None]
    rgb[:] = rgb * (1 - m) + blurred * m
    rgb[:] = rgb * (1 - m * 0.5) + ref * (m * 0.5)

# 3) rides (masque) puis couleur
lines = np.zeros((hh, ww), dtype=np.float32)
soft = np.zeros((hh, ww), dtype=np.float32)
L = []
# sillons nez-bouche : partent à côté de l'aile du nez, descendent en biais au-delà des coins de la bouche
L.append(([(462, 684), (447, 716), (434, 752), (427, 792)], 1.7, 0.42))
# plis d'amertume, très légers
L.append(([(428, 808), (424, 832)], 1.2, 0.16))
# pattes d'oie
L.append(([(286, 548), (262, 540), (240, 534)], 1.4, 0.45))
L.append(([(288, 562), (264, 566), (242, 572)], 1.4, 0.45))
L.append(([(294, 576), (276, 590), (260, 602)], 1.3, 0.38))
# poches sous les yeux
L.append(([(312, 596), (338, 610), (368, 612), (396, 600)], 1.4, 0.32))
L.append(([(322, 620), (350, 630), (380, 628)], 1.1, 0.18))
LINE_W, LINE_K = 1.8, 1.0   # épaisseur et intensité : le visage fait ~120 px de haut à l'écran
for pts, wd, st in L:
    stroke(lines, P(pts), wd * LINE_W * S, min(0.8, st * LINE_K))
    stroke(lines, P(mirror(pts, CX)), wd * LINE_W * S, min(0.8, st * LINE_K))
# front (souvent sous la frange, mais visible quand les cheveux bougent)
for y, st in ((318, 0.25), (346, 0.22)):
    stroke(lines, P([(410, y + 6), (460, y), (512, y - 2), (565, y), (615, y + 6)]), 1.4 * S, st)
# ombre douce qui creuse les sillons et les poches
for pts, wd, st in L[:1] + L[5:6]:
    stroke(soft, P(pts), 12 * S, 0.28)
    stroke(soft, P(mirror(pts, CX)), 12 * S, 0.28)

line_col = np.array([0.66, 0.49, 0.44], dtype=np.float32)
shade_col = rgb * np.array([0.90, 0.84, 0.82], dtype=np.float32)
rgb[:] = rgb * (1 - soft[..., None]) + shade_col * soft[..., None]
rgb[:] = rgb * (1 - lines[..., None]) + line_col * lines[..., None]

# 4) quelques taches de vieillesse, très pâles
rng = np.random.default_rng(7)
spots = np.zeros((hh, ww), dtype=np.float32)
for cx, cy in ((262, 690), (230, 520), (300, 720), (760, 700), (790, 515), (725, 735), (600, 300)):
    for _ in range(2):
        x = (cx + rng.uniform(-18, 18)) * S
        y = (cy + rng.uniform(-14, 14)) * S
        stroke(spots, [(x, y), (x + 0.5, y)], rng.uniform(2.5, 4.0) * S, rng.uniform(0.10, 0.18), taper=False)
spot_col = np.array([0.72, 0.55, 0.45], dtype=np.float32)
rgb[:] = rgb * (1 - spots[..., None]) + spot_col * spots[..., None]

if os.environ.get("AGE_DEBUG"):
    for gx in range(0, 1024, 64):
        rgb[:, int(gx * S):int(gx * S) + 3] = (1, 0, 0) if gx % 256 == 0 else (0, 0.6, 0)
    for gy in range(0, 1024, 64):
        rgb[int(gy * S):int(gy * S) + 3, :] = (1, 0, 0) if gy % 256 == 0 else (0, 0, 1)
face[:, :, :3] = np.clip(rgb, 0, 1)
store(img, face)
if PREVIEW:
    prev = img.copy()
    prev.filepath_raw = os.path.join(PREVIEW, "face_aged.png")
    prev.file_format = "PNG"
    prev.save()

# peau du corps (cou, mains) ternie de la même façon
bimg = body_image()
if bimg:
    b = load(bimg)
    brgb = b[:, :, :3]
    bg = brgb.mean(axis=2, keepdims=True)
    skin = (brgb[:, :, 0] > brgb[:, :, 2] + 0.05)[..., None]   # ne touche que les pixels couleur peau
    brgb[:] = np.where(skin, (brgb * 0.82 + bg * warm * 0.18) * 0.985, brgb)
    store(bimg, b)

# sourcils gris (comme les cheveux)
for m in bpy.data.materials:
    if m.name.startswith("N00_000_00_FaceBrow_00_FACE"):
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 8:
                br = load(n.image)
                g = br[:, :, :3].mean(axis=2, keepdims=True)
                br[:, :, :3] = np.clip(g * 0.6 + 0.42, 0, 1) * np.array([0.98, 0.97, 0.96])
                store(n.image, br)
                break

# ---------------------------------------------------------------- paupières tombantes
# On intègre une fraction de « yeux mi-clos » dans la forme de base. Les formes qui ferment l'œil
# gardent leur position absolue (l'œil se ferme toujours pareil) ; les autres suivent.
EYELID = 0.30
face_obj = bpy.data.objects["Face"]
keys = face_obj.data.shape_keys.key_blocks
basis = keys["Basis"]
n = len(basis.data)
def co(k):
    arr = np.empty(n * 3, dtype=np.float32)
    k.data.foreach_get("co", arr)
    return arr
b0 = co(basis)
close = co(keys["Fcl_EYE_Close"])
delta = (close - b0) * EYELID
CLOSING = {"Fcl_EYE_Close", "Fcl_EYE_Close_R", "Fcl_EYE_Close_L", "Fcl_EYE_Joy", "Fcl_EYE_Joy_R", "Fcl_EYE_Joy_L",
           "Fcl_ALL_Joy", "Fcl_ALL_Fun"}
for k in keys:
    if k.name in CLOSING:
        continue
    c = co(k)
    k.data.foreach_set("co", c + delta)
face_obj.data.vertices.foreach_set("co", co(basis))
face_obj.data.update()

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action="DESELECT")
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
bpy.context.view_layer.objects.active = arm
res = bpy.ops.export_scene.vrm(filepath=DST, armature_object_name=arm.name)
print("AGE export", res, DST)
