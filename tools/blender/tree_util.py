"""Arbres refaits au propre (erables, cedres, pin).

Principe (rendu « Ghibli » du shader toon) :
- feuillage = des MASSES (ellipsoides lisses, couleur sombre : l'ombre entre les feuilles) recouvertes de TOUFFES
  (cartes pliees en V, 2 triangles) qui donnent une silhouette decoupee et la matiere de pres ;
- les normales du feuillage sont celles de l'ENVELOPPE de la couronne (melangees un peu a celles de chaque masse) :
  le cel shading eclaire l'arbre comme un seul volume, avec un terminateur qui ondule le long des masses, au lieu
  d'un patchwork de boules eclairees chacune pour soi ;
- branches visibles dans les trouees, qui montent jusque dans chaque masse ;
- couleurs portees par les sommets (attribut « Col », multiplie par un materiau blanc dans le jeu) : un seul
  materiau par objet (tronc, feuillage) au lieu d'un par teinte, donc moins d'appels de dessin dans la foret.
  Les teintes suivent des champs doux (hauteur, lumiere, bruit lent), jamais du hasard par face.
Objets exportes : trunk, foliage, trunk-col (collision du tronc seul).
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *          # common.* (reset_scene, mat, cylinder, report...), noise3
import common
import bmesh
from mathutils import Vector, Quaternion, Matrix

V = Vector
UP = V((0, 0, 1))


def lin(h):
    return tuple(common.hex_to_linear(h)[:3])


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t


def mixc(a, b, t):
    return tuple(mix(x, y, t) for x, y in zip(a, b))


# ------------------------------------------------------------------ maillage a couleurs de sommets
class TM:
    """Maillage : sommets, faces, couleur par face (lineaire), ombrage et normale imposee par sommet."""

    def __init__(self):
        self.v, self.f, self.fc = [], [], []
        self.vn, self.vs = [], []

    def add(self, verts, faces, color, normals=None, shade=None):
        o = len(self.v)
        self.v += [V(p) for p in verts]
        self.vn += list(normals) if normals is not None else [None] * len(verts)
        self.vs += list(shade) if shade is not None else [1.0] * len(verts)
        for k, fc in enumerate(faces):
            self.f.append(tuple(i + o for i in fc))
            self.fc.append(color(k) if callable(color) else color)
        return o

    # ---- tube (branche, tronc) : anneaux par transport parallele
    def tube(self, pts, radii, sides, color, cap_end=True, noise=0.0, seed=0.0):
        pts = [V(p) for p in pts]
        n = len(pts)
        tans = []
        for i in range(n):
            a = pts[max(i - 1, 0)]
            b = pts[min(i + 1, n - 1)]
            tans.append((b - a).normalized())
        ref = V((1, 0, 0)) if abs(tans[0].x) < 0.9 else V((0, 1, 0))
        nrm = (ref - tans[0] * ref.dot(tans[0])).normalized()
        verts, faces = [], []
        for i in range(n):
            t = tans[i]
            nrm = (nrm - t * nrm.dot(t)).normalized()
            b = t.cross(nrm)
            for j in range(sides):
                a = 2 * math.pi * j / sides
                r = radii[i]
                if noise:
                    p0 = pts[i]
                    r *= 1.0 + noise * noise3(p0.x * 2.1 + math.cos(a), p0.y * 2.1 + math.sin(a), p0.z * 1.3, seed)
                verts.append(pts[i] + nrm * (r * math.cos(a)) + b * (r * math.sin(a)))
        cols = []
        for i in range(n - 1):
            for j in range(sides):
                j2 = (j + 1) % sides
                faces.append((i * sides + j, i * sides + j2, (i + 1) * sides + j2, (i + 1) * sides + j))
                cols.append(color(i, j, verts[i * sides + j]) if callable(color) else color)
        if cap_end:
            faces.append(tuple(range((n - 1) * sides, n * sides)))
            cols.append(cols[-1])
        return self.add(verts, faces, lambda k: cols[k])

    # ---- ellipsoide (masse de feuillage)
    def ico(self, center, radii, color, quat=None, subdiv=2, noise=0.06, seed=0.0, bottom=1.0, normal_fn=None,
            shade_fn=None):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        c = V(center)
        verts, loc_n = [], []
        for v in bm.verts:
            x, y, z = v.co
            k = 1.0 + noise * noise3(x * 1.7, y * 1.7, z * 1.7, seed)
            z2 = z * (bottom if z < 0 else 1.0)
            p = V((x * k * radii[0], y * k * radii[1], z2 * k * radii[2]))
            g = V((x / radii[0], y / radii[1], z2 / radii[2])).normalized()   # normale de l'ellipsoide
            if quat is not None:
                p = quat @ p
                g = quat @ g
            verts.append(c + p)
            loc_n.append(g)
        faces = [tuple(v.index for v in f.verts) for f in bm.faces]
        bm.free()
        normals = [normal_fn(p, g) for p, g in zip(verts, loc_n)] if normal_fn else None
        shade = [shade_fn(p) for p in verts] if shade_fn else None
        return self.add(verts, faces, color, normals, shade)

    # ---- touffe : carte pliee en V le long de la nervure (4 sommets, 2 triangles)
    def card(self, base, n_surf, direction, length, width, color, lift, normal=None, shade=1.0, fold=0.2):
        n = V(n_surf).normalized()
        d = V(direction)
        d = (d - n * d.dot(n))
        if d.length < 1e-6:
            d = n.orthogonal()
        d.normalize()
        d = (d * math.cos(lift) + n * math.sin(lift)).normalized()
        side = n.cross(d).normalized()
        up = d.cross(side).normalized()
        if up.dot(n) < 0:
            up = -up
        base = V(base)
        tip = base + d * length
        mid = base + d * (length * 0.45)
        l = mid + side * (width * 0.5) - up * (width * fold)
        r = mid - side * (width * 0.5) - up * (width * fold)
        nn = [normal] * 4 if normal is not None else None
        # face avant tournee vers l'exterieur (up)
        return self.add([base, r, tip, l], [(0, 1, 2), (0, 2, 3)], color, nn, [shade * 0.9, shade, shade, shade])

    # ---- objet Blender
    def build(self, name, custom_normals=False):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        me.update()
        me.materials.append(vcol_material())
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        bpy.context.view_layer.objects.active = o
        if not custom_normals:
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
        else:
            # faces orientees comme la normale imposee (les cartes et masses doivent faire face a l'exterieur)
            for p in me.polygons:
                ns = [self.vn[i] for i in p.vertices if self.vn[i] is not None]
                if ns:
                    avg = sum(ns, V((0, 0, 0)))
                    if p.normal.dot(avg) < 0:
                        p.flip()
            me.update()
        o["_tm"] = True
        TM_REG[name] = self
        return o


TM_REG = {}


def vcol_material():
    """Materiau blanc qui affiche l'attribut « Col » (preview) ; dans le jeu, Toon multiplie Col par le blanc."""
    m = bpy.data.materials.get("tree_vcol")
    if m:
        return m
    m = bpy.data.materials.new("tree_vcol")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    m.diffuse_color = (1, 1, 1, 1)
    return m


def _write_colors(o, tm, ao=None):
    """Col = couleur de la face x ombrage du sommet (x occlusion par coin si `ao`)."""
    me = o.data
    attr = me.color_attributes.get("Col")
    if attr is None:
        attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    flat = []
    for p in me.polygons:
        c = tm.fc[p.index]
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            s = tm.vs[vi]
            if ao is not None:
                s *= ao[li]
            flat += [c[0] * s, c[1] * s, c[2] * s, 1.0]
    attr.data.foreach_set("color", flat)
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
    except Exception:
        pass


def finish_tree(name, expected_dims=None, tri_limit=(300, 4000), views=(), trunk_angle=55, **preview_kw):
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.type != "MESH" or o.name.endswith("-col"):
            continue
        tm = TM_REG.get(o.name)
        if tm is None:
            continue
        me = o.data
        if any(n is not None for n in tm.vn):
            me.shade_smooth()
            ns = [(n.normalized() if n is not None else V((0, 0, 1))) for n in tm.vn]
            me.normals_split_custom_set_from_vertices([tuple(n) for n in ns])
            _write_colors(o, tm)
        else:
            shade(o, math.radians(trunk_angle))
            common.apply_vertex_tint([o])
            col = me.color_attributes.get("Col")
            ao = [d.color[0] for d in col.data]
            _write_colors(o, tm, ao)
    apply_all_transforms()
    info = report(name, expected_dims, tri_limit=tri_limit)
    info["tris_per_object"] = {o.name: tri_count(o) for o in sc.objects if o.type == "MESH"}
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    info["glb"] = _export(name)
    info["preview"] = render_preview(name, **preview_kw)
    for suffix, kw in views:
        render_preview(name + suffix, **kw)
    with open(os.path.join(PREVIEW_DIR, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("MODEL_REPORT " + json.dumps(info))
    return info


def _export(name):
    os.makedirs(MODELS_DIR, exist_ok=True)
    path = os.path.join(MODELS_DIR, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    renamed = []
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "EMPTY"}:
            o.select_set(True)
        if o.type == "MESH" and o.name.endswith("-col"):
            renamed.append((o, o.name))
            o.name = o.name.rsplit("-", 1)[0] + "-convcolonly"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_cameras=False, export_lights=False, export_extras=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_active_vertex_color_when_no_material=True)
    for o, n in renamed:
        o.name = n
    return path


def trunk_collision(radius, height, at=(0, 0)):
    o = cylinder("trunk-col", radius, height, loc=(at[0], at[1], height / 2), material=None, verts=10, bevel=0)
    o.display_type = "WIRE"
    return o


# ------------------------------------------------------------------ outils de forme
def fib_sphere(n, seed=0.0):
    """n directions reparties regulierement sur la sphere (spirale de Fibonacci), tournees de `seed`."""
    out = []
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        a = i * 2.39996323 + seed
        out.append(V((r * math.cos(a), r * math.sin(a), z)))
    return out


def ellipsoid_normal(p, c, r):
    d = V(p) - V(c)
    return V((d.x / (r[0] * r[0]), d.y / (r[1] * r[1]), d.z / (r[2] * r[2]))).normalized()


def inside_ellipsoid(p, c, r, quat=None, k=1.0):
    d = V(p) - V(c)
    if quat is not None:
        d = quat.inverted() @ d
    return (d.x / r[0]) ** 2 + (d.y / r[1]) ** 2 + (d.z / r[2]) ** 2 < k * k


def bezier(a, b, c, n):
    a, b, c = V(a), V(b), V(c)
    return [a * (1 - t) ** 2 + b * 2 * t * (1 - t) + c * t * t for t in (i / (n - 1) for i in range(n))]


def bark_color(base, dark, moss=None, moss_h=0.7, seed=0.0, moss_r=0.75):
    """Couleur d'ecorce : plus sombre au pied, eclaircie vers le haut. Rien par face au hasard : sur un tronc
    a gros pans, des taches de couleur par face se liraient comme des triangles peints (moss et seed : ignores)."""
    b, d = lin(base), lin(dark)

    def f(i, j, p):
        return mixc(d, b, smooth((p.z - 0.05) / 1.4))
    return f


# ------------------------------------------------------------------ feuillu (erables)
class Broadleaf:
    """Feuillu a couronne en masses. Parametres :
    trunk : [(x, y, z)...] axe du tronc jusqu'a la fourche ; trunk_r : rayon a la base (hors evasement)
    crown_c, crown_r : enveloppe de la couronne ; clumps : [(centre, rayons)] (sinon generees)
    tones : familles de teintes [(profonde, moyenne, claire)] ; card : (longueur, largeur) des touffes."""

    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.seed = seed
        self.T = TM()      # tronc et branches
        self.F = TM()      # feuillage

    def env_normal(self, p):
        return ellipsoid_normal(p, self.crown_c, self.crown_r)

    def foliage_normal(self, p, g, w_env=0.7):
        n = self.env_normal(p) * w_env + V(g) * (1 - w_env)
        return n.normalized()

    def gen_clumps(self, n, shell=(0.45, 0.72), size=(0.9, 1.3), min_z=-0.3, squash=0.8, center=0.42, spacing=0.55):
        """Masses reparties sur l'enveloppe, a des profondeurs variees (silhouette en cumulus, pas un dome lisse).
        Dessous ouvert : on voit les branches par en dessous."""
        rng = self.rng
        c, r = V(self.crown_c), self.crown_r
        out = []
        cands = fib_sphere(n * 8, seed=self.seed * 1.7)
        rng.shuffle(cands)
        for d in cands:
            if d.z < min_z:
                continue
            k = rng.uniform(*shell)
            s = rng.uniform(*size)
            p = V((c.x + d.x * r[0] * k, c.y + d.y * r[1] * k, c.z + d.z * r[2] * k))
            if any((p - q).length < spacing * (s + rr[0]) for q, rr in out):
                continue
            out.append((p, (s, s * rng.uniform(0.9, 1.05), s * squash)))
            if len(out) >= n:
                break
        if center:
            out.append((V((c.x, c.y, c.z + r[2] * 0.15)), (r[0] * center, r[1] * center, r[2] * center)))
        self.clumps = out
        return out

    def build_trunk(self, trunk, trunk_r, bark, roots=5, root_len=1.0, flare=0.6, sides=10):
        T = self.T
        pts = bezier(*trunk, 9) if len(trunk) == 3 else [V(p) for p in trunk]
        top = pts[-1].z
        radii = []
        for p in pts:
            t = p.z / top
            radii.append(trunk_r * (1.0 - 0.45 * t) * (1.0 + flare * math.exp(-p.z / 0.35)))
        T.tube(pts, radii, sides, bark, noise=0.06, seed=self.seed)
        self.trunk_pts, self.trunk_radii = pts, radii
        # racines apparentes
        for k in range(roots):
            a = 2 * math.pi * k / roots + self.rng.uniform(-0.3, 0.3)
            L = root_len * self.rng.uniform(0.75, 1.2)
            ca, sa = math.cos(a), math.sin(a)
            r0 = trunk_r * (1 + flare) * 0.7
            rp = [(r0 * 0.5 * ca, r0 * 0.5 * sa, 0.55), (r0 * 1.1 * ca, r0 * 1.1 * sa, 0.2),
                  ((r0 + 0.5 * L) * ca, (r0 + 0.5 * L) * sa, 0.07), ((r0 + L) * ca, (r0 + L) * sa, 0.02)]
            T.tube(rp, [trunk_r * 0.48, trunk_r * 0.4, trunk_r * 0.27, trunk_r * 0.17], 6, bark)

    def build_branches(self, bark, limbs=4, r_limb=0.16, r_twig=0.06, sides=7, spread=0.8, rise=0.45, twig_sides=5):
        """Charpentieres qui s'ecartent de la fourche vers chaque groupe de masses, puis rameaux vers chaque masse."""
        T, rng = self.T, self.rng
        fork = self.trunk_pts[-1]
        c = V(self.crown_c)
        groups = [[] for _ in range(limbs)]
        off = rng.uniform(0, 2 * math.pi)
        for p, r in self.clumps:
            a = (math.atan2(p.y - c.y, p.x - c.x) + off) % (2 * math.pi)
            groups[int(a / (2 * math.pi) * limbs) % limbs].append((p, r))
        for g in groups:
            if not g:
                continue
            avg = sum((p for p, _ in g), V((0, 0, 0))) / len(g)
            lp = V((mix(fork.x, avg.x, spread), mix(fork.y, avg.y, spread), mix(fork.z, avg.z, rise)))
            out = (lp - fork)
            out.z = 0
            ctrl = fork + out * 0.25 + V((0, 0, (lp.z - fork.z) * 0.75))
            pts = bezier(fork - V((0, 0, 0.35)), ctrl, lp, 6)
            T.tube(pts, [r_limb * 1.2, r_limb * 1.05, r_limb * 0.9, r_limb * 0.8, r_limb * 0.7, r_limb * 0.6], sides,
                   bark, noise=0.05, seed=self.seed)
            ldir = (pts[-1] - pts[-2]).normalized()
            for p, r in g:
                end = V(p) - V((0, 0, r[2] * 0.2))
                mid = lp + ldir * ((end - lp).length * 0.45) + V((0, 0, 0.1))
                if twig_sides >= 5:
                    T.tube(bezier(lp - ldir * 0.1, mid, end, 5),
                           [r_limb * 0.62, r_limb * 0.45, r_twig * 1.3, r_twig, r_twig * 0.55], twig_sides, bark)
                else:
                    T.tube(bezier(lp - ldir * 0.1, mid, end, 4), [r_limb * 0.6, r_twig * 1.3, r_twig, r_twig * 0.55],
                           twig_sides, bark)

    def build_foliage(self, tones, card=(0.4, 0.3), density=2.0, lift=(0.15, 0.45), core=0.78,
                      w_env=0.72, subdiv=1, droop=1.1, light=0.6):
        """Masses + touffes couchees en ecailles (pointe vers le bas, comme un feuillage qui retombe).
        tones : familles (profonde, moyenne, claire), melangees par un champ lent sur la couronne."""
        F, rng = self.F, self.rng
        c, r = V(self.crown_c), self.crown_r
        zmin, zmax = c.z - r[2], c.z + r[2]
        ph = [rng.uniform(0, 6.28) for _ in range(4)]
        tl = [tuple(lin(h) for h in fam) for fam in tones]

        def family(p):
            v = 0.5 + 0.35 * math.sin(p.x * 0.6 + ph[0]) * math.cos(p.y * 0.55 + ph[1]) + 0.2 * math.sin(p.z * 0.8 + ph[2])
            v = max(0.0, min(0.999, v)) * (len(tl) - 1)
            i = int(v)
            j = min(i + 1, len(tl) - 1)
            t = smooth(v - i)
            return tuple(mixc(tl[i][k], tl[j][k], t) for k in range(3))

        def hshade(p):
            return 0.8 + 0.2 * smooth((p.z - zmin) / (zmax - zmin))

        for ci, (p, rr) in enumerate(self.clumps):
            fam = family(p)
            F.ico(p, rr, mixc(fam[0], fam[1], 0.35), subdiv=subdiv, noise=0.07, seed=ci * 1.3 + self.seed,
                  normal_fn=lambda q, g: self.foliage_normal(q, g, w_env), shade_fn=lambda q: hshade(q) * core,
                  bottom=0.8)
        for ci, (p, rr) in enumerate(self.clumps):
            area = 4 * math.pi * ((rr[0] * rr[1] + rr[0] * rr[2] + rr[1] * rr[2]) / 3)
            n = int(area / (card[0] * card[1]) * density)
            for d in fib_sphere(n, seed=ci * 0.7 + self.seed):
                q = V(p) + V((d.x * rr[0], d.y * rr[1], d.z * rr[2] * (0.8 if d.z < 0 else 1.0)))
                g = V((d.x / rr[0], d.y / rr[1], d.z / rr[2])).normalized()
                en = self.env_normal(q)
                if g.dot(en) < -0.2:
                    continue                      # tourne vers l'interieur de la couronne
                if any(cj != ci and inside_ellipsoid(q, p2, r2, k=0.95) for cj, (p2, r2) in enumerate(self.clumps)):
                    continue
                fam = family(q)
                # claire en haut cote ciel ; le bruit est lent : on lit des plaques, pas des confettis
                lv = 0.6 * smooth((q.z - zmin) / (zmax - zmin)) + 0.35 * max(0.0, en.z) \
                    + 0.18 * noise3(q.x * 0.8, q.y * 0.8, q.z * 0.8, self.seed + 5)
                t = smooth((lv - light + 0.12) / 0.24)
                col = mixc(fam[1], fam[2], t) if lv > 0.25 else mixc(fam[0], fam[1], 0.6)
                tdir = V((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), -droop))
                L = card[0] * rng.uniform(0.85, 1.2)
                W = card[1] * rng.uniform(0.85, 1.15)
                F.card(q - g * 0.04, g, tdir, L, W, col, rng.uniform(*lift),
                       normal=self.foliage_normal(q, g, w_env), shade=hshade(q))

    def build(self):
        self.T.v[:] = [V((p.x, p.y, max(0.0, p.z))) for p in self.T.v]     # racines posees au sol
        self.T.build("trunk")
        self.F.build("foliage", custom_normals=True)


# ------------------------------------------------------------------ conifere (cedre du Japon, sugi)
class Conifer:
    """Cedre : tronc droit, masses de rameaux etagees en spirale le long du tronc, en cone etroit un peu bombe,
    pointe en fleche. Les normales suivent le cone (lumiere d'un seul volume), les touffes sont des rameaux
    d'aiguilles etroits qui retombent."""

    def __init__(self, seed, H, z0, R, trunk_r, bark, lean=(0.0, 0.0)):
        self.rng = random.Random(seed)
        self.seed, self.H, self.z0, self.R, self.trunk_r = seed, H, z0, R, trunk_r
        self.lean = V((lean[0], lean[1], 0))
        self.bark = bark
        self.T, self.F = TM(), TM()
        self.clumps = []          # (centre, rayons, quat)

    def axis(self, z):
        """Point de l'axe du tronc a la hauteur z (leger penchant + ondulation)."""
        s = self.seed
        return V((self.lean.x * z + 0.08 * math.sin(z * 0.45 + s), self.lean.y * z + 0.08 * math.cos(z * 0.38 + s), z))

    def radius_at(self, z, shape=0.85):
        t = max(0.0, min(1.0, (z - self.z0) / (self.H - self.z0)))
        return self.R * (1 - t) ** shape * (0.55 + 0.45 * smooth(t * 6))

    def env_normal(self, p):
        a = self.axis(p.z)
        d = V((p.x - a.x, p.y - a.y, 0))
        if d.length < 1e-4:
            return UP.copy()
        d.normalize()
        slope = self.R / (self.H - self.z0)
        return (d + UP * (slope * 1.2 + 0.15)).normalized()

    def foliage_normal(self, p, g, w_env=0.68):
        return (self.env_normal(p) * w_env + V(g) * (1 - w_env)).normalized()

    def build_trunk(self, roots=5, sides=9, flare=0.6):
        zs = [0, 0.25, 0.6, 1.2, 2.2] + [2.2 + (self.H - 2.2) * k / 7 for k in range(1, 8)]
        pts = [self.axis(z) for z in zs]
        radii = [self.trunk_r * max(0.06, 1 - z / (self.H * 1.02)) ** 0.9 * (1 + flare * math.exp(-z / 0.4)) for z in zs]
        self.T.tube(pts, radii, sides, self.bark, noise=0.05, seed=self.seed)
        rng = self.rng
        for k in range(roots):
            a = 2 * math.pi * k / roots + rng.uniform(-0.3, 0.3)
            L = rng.uniform(0.55, 0.85)
            ca, sa = math.cos(a), math.sin(a)
            r0 = self.trunk_r * (1 + flare) * 0.7
            rp = [(r0 * 0.5 * ca, r0 * 0.5 * sa, 0.5), (r0 * 1.1 * ca, r0 * 1.1 * sa, 0.17),
                  ((r0 + 0.5 * L) * ca, (r0 + 0.5 * L) * sa, 0.06), ((r0 + L) * ca, (r0 + L) * sa, 0.02)]
            self.T.tube(rp, [self.trunk_r * 0.45, self.trunk_r * 0.36, self.trunk_r * 0.24, self.trunk_r * 0.15], 6,
                        self.bark)

    def gen_clumps(self, n, size=(0.55, 0.45), skip=None, droop=0.25):
        """n masses en spirale (angle d'or) de z0 au sommet ; la taille suit le rayon du cone.
        skip(z, angle) -> True pour laisser un trou (etage casse)."""
        rng = self.rng
        a = rng.uniform(0, 6.28)
        for i in range(n):
            t = (i + 0.5) / n
            z = self.z0 + (self.H - self.z0 - 0.9) * (t ** 0.92)
            a += 2.39996 + rng.uniform(-0.25, 0.25)
            if skip and skip(z, a % (2 * math.pi)):
                continue
            rr = self.radius_at(z)
            ax = self.axis(z)
            d = V((math.cos(a), math.sin(a), 0))
            k = rng.uniform(0.5, 0.72)
            c = ax + d * (rr * k) + V((0, 0, rng.uniform(-0.1, 0.1)))
            s = size[0] * rr + size[1]
            radii = (s * 1.25, s * 0.95, s * 0.62)
            q = Quaternion(UP, a) @ Quaternion(V((0, 1, 0)), droop)    # bout de la masse qui retombe
            self.clumps.append((c, radii, q, a))
        # fleche : petites masses empilees sur l'axe
        for j, (zz, s) in enumerate([(self.H - 1.6, 0.62), (self.H - 0.95, 0.45), (self.H - 0.45, 0.28)]):
            self.clumps.append((self.axis(zz), (s, s, s * 1.5), Quaternion(), 0.0))

    def build_branches(self, sides=3, dead=(), upto=0.6):
        """Une branche du tronc vers chaque masse du bas de la couronne (visible dans les trouees ; plus haut,
        elles seraient cachees) + chicots morts sous la couronne."""
        for c, r, q, a in self.clumps:
            if not a or c.z > self.z0 + upto * (self.H - self.z0):
                continue
            ax = self.axis(c.z - 0.25)
            d = (c - ax)
            end = ax + d * 0.85
            self.T.tube([ax, ax + d * 0.45 + V((0, 0, 0.05)), end], [self.trunk_r * 0.22, self.trunk_r * 0.13,
                        self.trunk_r * 0.06], sides, self.bark)
        for z, a, L in dead:
            ax = self.axis(z)
            d = V((math.cos(a), math.sin(a), 0.12))
            self.T.tube([ax, ax + d * L * 0.6, ax + d * L + V((0, 0, -0.1 * L))], [0.06, 0.04, 0.02], 4, self.bark)

    def build_foliage(self, tones, card=(0.6, 0.2), density=1.4, lift=(0.08, 0.3), core=0.8, w_env=0.68,
                      dry=None, subdiv=1):
        """dry(z, a) -> True : masse roussie (rameaux secs de l'etage casse)."""
        F, rng = self.F, self.rng
        tl = [tuple(lin(h) for h in fam) for fam in tones]
        ph = rng.uniform(0, 6.28)
        H = self.H

        def fam_at(p):
            v = 0.5 + 0.4 * math.sin(p.z * 0.5 + ph) * math.cos(math.atan2(p.y, p.x) * 1.0 + ph)
            v = max(0.0, min(0.999, v)) * (len(tl) - 1)
            i = int(v)
            j = min(i + 1, len(tl) - 1)
            return tuple(mixc(tl[i][k], tl[j][k], smooth(v - i)) for k in range(3))

        def hshade(p):
            return 0.78 + 0.22 * smooth((p.z - self.z0) / (H - self.z0))

        for ci, (c, rr, q, a) in enumerate(self.clumps):
            fam = DRY if dry and a and dry(c.z, a % (2 * math.pi)) else fam_at(c)
            F.ico(c, rr, mixc(fam[0], fam[1], 0.3), quat=q, subdiv=subdiv, noise=0.08, seed=ci * 1.1 + self.seed,
                  normal_fn=lambda p, g: self.foliage_normal(p, g, w_env), shade_fn=lambda p: hshade(p) * core,
                  bottom=0.7)
        qinv = [q.inverted() for (_, _, q, _) in self.clumps]
        for ci, (c, rr, q, a) in enumerate(self.clumps):
            fam = DRY if dry and a and dry(c.z, a % (2 * math.pi)) else None
            area = 4 * math.pi * ((rr[0] * rr[1] + rr[0] * rr[2] + rr[1] * rr[2]) / 3)
            n = int(area / (card[0] * card[1]) * density * 0.5)
            for d in fib_sphere(n, seed=ci * 0.9 + self.seed):
                loc = V((d.x * rr[0], d.y * rr[1], d.z * rr[2] * (0.7 if d.z < 0 else 1.0)))
                p = c + q @ loc
                g = (q @ V((d.x / rr[0], d.y / rr[1], d.z / rr[2]))).normalized()
                en = self.env_normal(p)
                if g.dot(en) < -0.15:
                    continue
                hid = False
                for cj, (c2, r2, q2, _) in enumerate(self.clumps):
                    if cj != ci:
                        dd = qinv[cj] @ (p - c2)
                        if (dd.x / r2[0]) ** 2 + (dd.y / r2[1]) ** 2 + (dd.z / r2[2]) ** 2 < 0.88:
                            hid = True
                            break
                if hid:
                    continue
                f = fam or fam_at(p)
                lv = 0.5 * smooth((p.z - self.z0) / (H - self.z0)) + 0.4 * max(0.0, g.z) \
                    + 0.2 * noise3(p.x * 0.7, p.y * 0.7, p.z * 0.5, self.seed + 2)
                col = mixc(f[1], f[2], smooth((lv - 0.55) / 0.3)) if lv > 0.2 else mixc(f[0], f[1], 0.55)
                out = V((p.x - self.axis(p.z).x, p.y - self.axis(p.z).y, 0))
                tdir = out.normalized() * 0.9 + V((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), -0.9))
                F.card(p - g * 0.04, g, tdir, card[0] * rng.uniform(0.85, 1.2), card[1] * rng.uniform(0.85, 1.2), col,
                       rng.uniform(*lift), normal=self.foliage_normal(p, g, w_env), shade=hshade(p), fold=0.35)

    def build(self):
        self.T.v[:] = [V((p.x, p.y, max(0.0, p.z))) for p in self.T.v]
        self.T.build("trunk")
        self.F.build("foliage", custom_normals=True)


DRY = tuple(lin(h) for h in ("#5E4026", "#8A5D33", "#A97A42"))


# ------------------------------------------------------------------ pin (kuromatsu) : nuages plats
class Pine:
    """Pin japonais : tronc tordu, branches presque horizontales qui portent des plateaux d'aiguilles.
    Chaque plateau est son propre volume (normales du plateau : dessus clair, dessous sombre) ; des aiguilles
    rayonnent sur son pourtour et se couchent sur le dessus."""

    def __init__(self, seed, bark):
        self.rng = random.Random(seed)
        self.seed, self.bark = seed, bark
        self.T, self.F = TM(), TM()
        self.pads = []

    def trunk(self, pts, radii, sides=9, roots=4):
        self.trunk_pts = [V(p) for p in pts]
        self.T.tube(self.trunk_pts, radii, sides, self.bark, noise=0.07, seed=self.seed)
        rng = self.rng
        r0 = radii[0]
        for k in range(roots):
            a = 2 * math.pi * k / roots + rng.uniform(-0.3, 0.3)
            L = rng.uniform(0.5, 0.8)
            ca, sa = math.cos(a), math.sin(a)
            rp = [(r0 * 0.4 * ca, r0 * 0.4 * sa, 0.45), (r0 * 0.95 * ca, r0 * 0.95 * sa, 0.15),
                  ((r0 + 0.5 * L) * ca, (r0 + 0.5 * L) * sa, 0.05), ((r0 + L) * ca, (r0 + L) * sa, 0.02)]
            self.T.tube(rp, [r0 * 0.5, r0 * 0.38, r0 * 0.24, r0 * 0.15], 6, self.bark)

    def branch(self, start, end, r0, r1, bend=0.4):
        s, e = V(start), V(end)
        mid = s + (e - s) * 0.5 + V((0, 0, bend))
        self.T.tube(bezier(s, mid, e, 5), [r0, mix(r0, r1, 0.3), mix(r0, r1, 0.6), mix(r0, r1, 0.85), r1], 6, self.bark)

    def pad(self, c, R, h, yaw=0.0, sat=2):
        """Plateau principal + lobes de bord (bord festonne)."""
        c = V(c)
        q = Quaternion(UP, yaw)
        self.pads.append((c, (R, R * 0.82, h), q))
        rng = self.rng
        for k in range(sat):
            a = yaw + rng.uniform(0, 6.28)
            off = V((math.cos(a) * R * 0.68, math.sin(a) * R * 0.6, rng.uniform(-0.2, 0.15) * h))
            self.pads.append((c + off, (R * 0.52, R * 0.46, h * 0.82), Quaternion(UP, a)))
        # dome sur le dessus : le plateau est un nuage, pas une assiette
        self.pads.append((c + V((rng.uniform(-0.2, 0.2) * R, rng.uniform(-0.2, 0.2) * R, h * 0.45)),
                          (R * 0.6, R * 0.52, h * 0.75), Quaternion(UP, yaw + 1.0)))

    def build_foliage(self, tones, card=(0.4, 0.15), density=1.6, core=0.78, subdiv=1):
        F, rng = self.F, self.rng
        deep, mid, light = (lin(h) for h in tones)
        zs = [c.z for c, _, _ in self.pads]
        zmin, zmax = min(zs) - 0.5, max(zs) + 0.5
        # normales : celles du plateau-mere (grand ellipsoide aplati englobant le plateau et ses lobes)
        groups = []
        for c, r, q in self.pads:
            groups.append((c, (r[0] * 1.25, r[1] * 1.25, r[2] * 1.6)))

        def owner(p):
            best, bd = 0, 1e9
            for i, (c, r) in enumerate(groups):
                d = ((p.x - c.x) / r[0]) ** 2 + ((p.y - c.y) / r[1]) ** 2 + ((p.z - c.z) / r[2]) ** 2
                if d < bd:
                    best, bd = i, d
            return groups[best]

        def nrm(p, g):
            c, r = owner(p)
            e = ellipsoid_normal(p, c, r)
            e = (e + UP * 0.25).normalized()
            return (e * 0.75 + V(g) * 0.25).normalized()

        def hshade(p):
            return 0.82 + 0.18 * smooth((p.z - zmin) / (zmax - zmin))

        for i, (c, rr, q) in enumerate(self.pads):
            F.ico(c, rr, mixc(deep, mid, 0.25), quat=q, subdiv=subdiv, noise=0.1, seed=i * 1.9 + self.seed,
                  normal_fn=nrm, shade_fn=lambda p: hshade(p) * core, bottom=0.55)
        qinv = [q.inverted() for (_, _, q) in self.pads]
        for i, (c, rr, q) in enumerate(self.pads):
            area = 4 * math.pi * ((rr[0] * rr[1] + rr[0] * rr[2] + rr[1] * rr[2]) / 3)
            n = int(area / (card[0] * card[1]) * density * 0.5)
            for d in fib_sphere(n, seed=i * 1.3 + self.seed):
                if d.z < -0.55:
                    continue
                loc = V((d.x * rr[0], d.y * rr[1], d.z * rr[2] * (0.55 if d.z < 0 else 1.0)))
                p = c + q @ loc
                g = (q @ V((d.x / rr[0], d.y / rr[1], d.z / rr[2]))).normalized()
                hid = False
                for j, (c2, r2, q2) in enumerate(self.pads):
                    if j != i:
                        dd = qinv[j] @ (p - c2)
                        if (dd.x / r2[0]) ** 2 + (dd.y / r2[1]) ** 2 + (dd.z / r2[2]) ** 2 < 0.88:
                            hid = True
                            break
                if hid:
                    continue
                lv = 0.75 * max(0.0, g.z) + 0.25 * noise3(p.x, p.y, p.z, self.seed)
                col = mixc(mid, light, smooth((lv - 0.45) / 0.25)) if lv > 0.15 else mixc(deep, mid, 0.5)
                # aiguilles : rayonnent vers l'exterieur du plateau, a peine relevees
                out = V((loc.x, loc.y, 0))
                out = (q @ out).normalized() if out.length > 1e-4 else V((1, 0, 0))
                tdir = out + V((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), -0.35))
                F.card(p - g * 0.03, g, tdir, card[0] * rng.uniform(0.85, 1.2), card[1] * rng.uniform(0.85, 1.2), col,
                       rng.uniform(0.02, 0.2), normal=nrm(p, g), shade=hshade(p), fold=0.35)

    def build(self):
        self.T.v[:] = [V((p.x, p.y, max(0.0, p.z))) for p in self.T.v]
        self.T.build("trunk")
        self.F.build("foliage", custom_normals=True)
