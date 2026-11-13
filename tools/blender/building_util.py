"""Outils des batiments secondaires (bureau du sanctuaire, salon de the, pavillon des ablutions).
Meme langage que le haiden : toits epais a coins releves, bois sombre, enduit clair, une couleur par materiau.
S'appuie sur shrine_util (make_mesh, bx, bx_span, cyl, sweep, prism_*) sans le modifier.
Importer avec : from building_util import *"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrine_util import *
from mathutils import Vector

PALETTE.update({
    "plaster_white": "#E3DAC6",   # enduit des murs (un peu chaud, pas blanc pur)
    "kawara":        "#6C7075",   # tuiles grises
    "kawara_dark":   "#53575C",   # rangs de tuiles rondes (marugawara)
    "kawara_ridge":  "#45484C",
    "thatch":        "#A58E55",
    "thatch_dark":   "#8A7444",
    "thatch_light":  "#B9A167",
    "shoji_paper":   "#EFE6D2",
    "interior":      "#3A2C24",   # interieur dans l'ombre
    "noren":         "#2F3E5C",   # rideau indigo
    "noren_mon":     "#E8E0CC",
    "bamboo_green":  "#7C9A4A",
    "wood_mid":      "#7A5536",
})


def f_slope(d, R, E, H):
    """Profil de toit : hauteur au-dessus de l'egout E, en fonction de la distance d a l'egout (0..R)."""
    t = max(0.0, min(d / R, 1.0))
    return E + H * (0.42 * t + 0.58 * t * t)


def grid(a, b, step, extra=()):
    """Abscisses de a a b au pas step, plus des abscisses imposees (lignes de tuiles...)."""
    n = max(2, int(math.ceil((b - a) / step)) + 1)
    vals = {round(a + (b - a) * i / (n - 1), 5) for i in range(n)}
    for e in extra:
        if a < e < b:
            vals.add(round(e, 5))
    return sorted(vals)


def heightfield_fn(name, xs, ys, top, thick, mtop, medge, mbot):
    """Comme shrine_util.heightfield, mais mtop(x, y, haut) -> materiau de chaque cellule (tuiles en rangs...)."""
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
            cx, cy = (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2
            m = mtop(cx, cy)
            # diagonale qui suit l'aretier : pas de facettes en dents de scie sur les croupes
            alt = (cx * cy) > 0
            tris = [(a, b, d), (b, c, d)] if alt else [(a, b, c), (a, c, d)]
            for t in tris:
                F.append(t)
                M.append(m)
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


# ================================================================ toit en croupe (yosemune) a tuiles
class HipRoof:
    """Toit a quatre pentes : egouts a RX (x) et RY (y), hauteur d'egout E, montee H jusqu'au faitage.
    Le faitage court le long de X sur 2 (RX - RY). Coins legerement releves (lift)."""

    def __init__(self, RX, RY, E, H, T=0.30, lift=0.28, cx=0.0, cy=0.0):
        self.RX, self.RY, self.E, self.H, self.T, self.lift = RX, RY, E, H, T, lift
        self.cx, self.cy = cx, cy

    def top(self, x, y):
        x, y = x - self.cx, y - self.cy
        dy = self.RY - abs(y)
        dx = self.RX - abs(x)
        z = min(f_slope(dy, self.RY, self.E, self.H), f_slope(dx, self.RY, self.E, self.H))
        return z + self.lift * (min(abs(x) / self.RX, 1.0) ** 4) * (min(abs(y) / self.RY, 1.0) ** 4)

    def side(self, x, y):
        """'y' sur les longs pans (avant/arriere), 'x' sur les croupes."""
        x, y = x - self.cx, y - self.cy
        return "y" if (self.RY - abs(y)) <= (self.RX - abs(x)) else "x"

    def build(self, name, mats=("kawara", "kawara_dark", "roof_edge", "soffit"), rib=0.30, rib_w=0.09):
        m_tile, m_rib, m_edge, m_bot = mats
        RX, RY, cx, cy = self.RX, self.RY, self.cx, self.cy
        ex_x = [cx + k * rib + o for k in range(-40, 41) for o in (0.0, rib_w)]
        ex_y = [cy + k * rib + o for k in range(-40, 41) for o in (0.0, rib_w)]
        xs = grid(cx - RX, cx + RX, 0.30, ex_x + [cx - (RX - RY), cx + (RX - RY)])
        ys = grid(cy - RY, cy + RY, 0.30, ex_y + [cy])

        def mtop(x, y):
            s = self.side(x, y)
            u = (x - cx) if s == "y" else (y - cy)
            return m_rib if (u % rib) < rib_w else m_tile

        return heightfield_fn(name, xs, ys, self.top, lambda x, y: self.T, mtop, m_edge, m_bot)

    def ridges(self, name, m="kawara_ridge", w=0.26, h=0.30, oni=True):
        """Faitage et aretiers (tuiles de couronnement), avec les blocs d'about (onigawara)."""
        RX, RY, cx, cy = self.RX, self.RY, self.cx, self.cy
        L = RX - RY
        zr = self.top(cx, cy)
        sweep(name + "_ridge", [(cx - L - 0.05, cy, zr + h * 0.35), (cx + L + 0.05, cy, zr + h * 0.35)], w, h, m, bevel=0.03)
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts = []
                for k in range(9):
                    t = k / 8
                    x = cx + sx * (L + (RX - L) * t * 0.97)
                    y = cy + sy * (RY * t * 0.97)
                    pts.append((x, y, self.top(x, y) + h * 0.3))
                sweep(f"{name}_hip_{sx}_{sy}", pts, w * 0.8, h * 0.8, m, bevel=0.02)
            if oni:
                bx(f"{name}_oni_{sx}", (0.14, w * 1.5, h * 1.25), (cx + sx * (L + 0.06), cy, zr + h * 0.55), m, bevel=0.03)

    def rafters(self, name, inset, z_under, pitch=0.32, m="wood_dark", s=0.07):
        """Chevrons apparents sous l'avant-toit, du mur jusqu'a l'egout, sur les quatre cotes."""
        RX, RY, cx, cy = self.RX, self.RY, self.cx, self.cy
        k = 0
        bx_w, by_w = inset
        for sy in (-1, 1):
            x = -RX + 0.35
            while x < RX - 0.35:
                y0, y1 = sy * by_w, sy * (RY - 0.12)
                p0 = (cx + x, cy + y0, z_under(cx + x, cy + y0))
                p1 = (cx + x, cy + y1, self.top(cx + x, cy + y1) - self.T - s * 0.5)
                sweep(f"{name}_{k}", [p0, p1], s, s, m)
                k += 1
                x += pitch
        for sx in (-1, 1):
            y = -RY + 0.35
            while y < RY - 0.35:
                x0, x1 = sx * bx_w, sx * (RX - 0.12)
                p0 = (cx + x0, cy + y, z_under(cx + x0, cy + y))
                p1 = (cx + x1, cy + y, self.top(cx + x1, cy + y) - self.T - s * 0.5)
                sweep(f"{name}_{k}", [p0, p1], s, s, m)
                k += 1
                y += pitch


# ================================================================ toit de chaume (kayabuki)
class ThatchRoof(HipRoof):
    """Toit de chaume : epais, bords arrondis, surface legerement bosselee, faitage couvert de bambou."""

    def __init__(self, RX, RY, E, H, T=0.55, seed=3, **kw):
        super().__init__(RX, RY, E, H, T=T, lift=0.0, **kw)
        self.r = random.Random(seed)
        self.ph = [self.r.uniform(0, 6.28) for _ in range(4)]

    def top(self, x, y):
        z = super().top(x, y)
        ph = self.ph
        # bosses tres douces, nulles pres des aretiers (sinon les aretes deviennent des dents de scie)
        x0, y0 = x - self.cx, y - self.cy
        hip = abs((self.RY - abs(y0)) - (self.RX - abs(x0)))
        k = min(1.0, hip / 0.6)
        return z + k * (0.018 * math.sin(x * 2.3 + ph[0]) * math.cos(y * 1.9 + ph[1]) + 0.008 * math.sin(x * 5.1 + y * 3.7 + ph[2]))

    def build(self, name, mats=("thatch", "thatch_dark", "thatch_dark", "soffit"), rib=0.55, rib_w=0.2):
        # bandes de chaume tasse le long des egouts (couches visibles), pas de rangs de tuiles
        RX, RY, cx, cy = self.RX, self.RY, self.cx, self.cy
        m_a, m_b, m_edge, m_bot = mats
        xs = grid(cx - RX, cx + RX, 0.18, [cx - (RX - RY), cx + (RX - RY), cx - RX + 0.36, cx + RX - 0.36])
        ys = grid(cy - RY, cy + RY, 0.18, [cy, cy - RY + 0.36, cy + RY - 0.36])

        def mtop(x, y):
            s = self.side(x, y)
            d = (self.RY - abs(y - cy)) if s == "y" else (self.RX - abs(x - cx))
            # une seule couche visible : le rang d'egout, tasse et plus clair, au-dessus de la tranche
            return m_b if d < 0.36 else m_a

        thick = lambda x, y: self.T * (0.55 + 0.45 * min(1.0, (min(self.RY - abs(y - cy), self.RX - abs(x - cx))) / 0.6))
        return heightfield_fn(name, xs, ys, self.top, thick, mtop, m_edge, m_bot)

    def ridge_cap(self, name):
        """Faitage : boudin de chaume serre, enfonce dans le toit, coiffe d'une planche et de deux paires de
        traverses croisees (karasu-odori) aux extremites."""
        L = self.RX - self.RY
        zr = HipRoof.top(self, self.cx, self.cy)
        tube(name + "_roll", [(self.cx - L - 0.35, self.cy, zr - 0.06), (self.cx + L + 0.35, self.cy, zr - 0.06)],
             [0.24, 0.24], "thatch_dark", nseg=10)
        sweep(name + "_cap", [(self.cx - L - 0.42, self.cy, zr + 0.2), (self.cx + L + 0.42, self.cy, zr + 0.2)],
              0.30, 0.07, "wood_dark", bevel=0.015)
        for x in (self.cx - L - 0.25, self.cx + L + 0.25):
            for s in (-1, 1):
                sweep(f"{name}_x{x:.2f}_{s}", [(x, self.cy - 0.32 * s, zr - 0.02), (x, self.cy + 0.12 * s, zr + 0.42)],
                      0.05, 0.05, "wood_dark")


# ================================================================ toit a deux pans (kirizuma), en cuivre
class GableRoof:
    """Toit a deux pans : faitage le long de X, egouts a +-RY, pignons a +-RX avec planches de rive (hafu)."""

    def __init__(self, RX, RY, E, H, T=0.22, lift=0.18):
        self.RX, self.RY, self.E, self.H, self.T, self.lift = RX, RY, E, H, T, lift

    def top(self, x, y):
        z = f_slope(self.RY - abs(y), self.RY, self.E, self.H)
        return z + self.lift * (abs(x) / self.RX) ** 4 * (abs(y) / self.RY) ** 2

    def build(self, name, mats=("copper", "copper_dark", "roof_edge", "soffit"), rib=0.32, rib_w=0.06):
        m_a, m_b, m_edge, m_bot = mats
        xs = grid(-self.RX, self.RX, 0.2, [k * rib + o for k in range(-30, 31) for o in (0.0, rib_w)])
        ys = grid(-self.RY, self.RY, 0.2, [0.0])
        mtop = lambda x, y: m_b if (x % rib) < rib_w else m_a
        return heightfield_fn(name, xs, ys, self.top, lambda x, y: self.T, mtop, m_edge, m_bot)

    def ridge(self, name, m="copper_dark"):
        zr = self.top(0, 0)
        sweep(name + "_ridge", [(-self.RX - 0.12, 0, zr + 0.06), (self.RX + 0.12, 0, zr + 0.06)], 0.20, 0.16, m, bevel=0.02)

    def bargeboards(self, name, m="wood_dark", w=0.07, h=0.24, gegyo=True):
        """Planches de rive le long des pignons, et le pendentif du pignon (gegyo)."""
        for sx in (-1, 1):
            x = sx * (self.RX + 0.02)
            for sy in (-1, 1):
                pts = []
                for k in range(9):
                    y = sy * self.RY * k / 8
                    pts.append((x, y, self.top(x, y) - self.T * 0.5 - 0.02))
                sweep(f"{name}_{sx}_{sy}", pts, w, h, m, bevel=0.012)
            if gegyo:
                z = self.top(x, 0) - self.T - 0.05
                prism_x(f"{name}_gegyo_{sx}", [(-0.16, 0.0), (0.16, 0.0), (0.09, -0.22), (0.0, -0.30), (-0.09, -0.22)],
                        x - 0.03, x + 0.03, "metal_gold")
                prism_x(f"{name}_gegyo_b{sx}", [(-0.12, -0.02), (0.12, -0.02), (0.0, -0.20)], x - 0.045, x + 0.045, m)
                # (le cache dore depasse de la planche sombre)
                for o in bpy.context.scene.objects:
                    if o.name == f"{name}_gegyo_{sx}":
                        o.location.z = z
                    if o.name == f"{name}_gegyo_b{sx}":
                        o.location.z = z + 0.01


# ================================================================ murs
def plaster_wall(name, a0, a1, fixed, z0, z1, axis="x", m="plaster_white", t=0.10):
    """Pan d'enduit entre deux poteaux. axis='x' : mur le long de X a y=fixed."""
    if axis == "x":
        return bx_span(name, a0, a1, fixed - t / 2, fixed + t / 2, z0, z1, m, bevel=0.0)
    return bx_span(name, fixed - t / 2, fixed + t / 2, a0, a1, z0, z1, m, bevel=0.0)


def plank_wall(name, a0, a1, fixed, z0, z1, axis="x", w=0.24, t=0.06, mats=("wood_faded", "wood_mid")):
    """Bardage de planches verticales (koshi-ita), deux teintes alternees."""
    n = max(1, int(round((a1 - a0) / w)))
    step = (a1 - a0) / n
    for i in range(n):
        b0, b1 = a0 + i * step + 0.006, a0 + (i + 1) * step - 0.006
        m = mats[i % 2]
        if axis == "x":
            bx_span(f"{name}_{i}", b0, b1, fixed - t / 2, fixed + t / 2, z0, z1, m, bevel=0.008)
        else:
            bx_span(f"{name}_{i}", fixed - t / 2, fixed + t / 2, b0, b1, z0, z1, m, bevel=0.008)


def shoji(name, a0, a1, fixed, z0, z1, axis="x", cols=3, rows=4, frame="wood_light", paper="shoji_paper", t=0.05):
    """Panneau de shoji : cadre, papier, petits bois."""
    def B(n, p0, p1, q0, q1, r0, r1, m, bev=0.006):
        if axis == "x":
            bx_span(n, p0, p1, fixed + q0, fixed + q1, r0, r1, m, bevel=bev)
        else:
            bx_span(n, fixed + q0, fixed + q1, p0, p1, r0, r1, m, bevel=bev)
    fw = 0.045
    B(name + "_paper", a0 + fw, a1 - fw, -0.008, 0.008, z0 + fw, z1 - fw, paper, 0)
    B(name + "_fl", a0, a0 + fw, -t / 2, t / 2, z0, z1, frame)
    B(name + "_fr", a1 - fw, a1, -t / 2, t / 2, z0, z1, frame)
    B(name + "_fb", a0, a1, -t / 2, t / 2, z0, z0 + fw * 1.6, frame)
    B(name + "_ft", a0, a1, -t / 2, t / 2, z1 - fw, z1, frame)
    for c in range(1, cols):
        a = a0 + (a1 - a0) * c / cols
        B(f"{name}_c{c}", a - 0.012, a + 0.012, -0.018, 0.018, z0 + fw, z1 - fw, frame, 0)
    for r in range(1, rows):
        z = z0 + (z1 - z0) * r / rows
        B(f"{name}_r{r}", a0 + fw, a1 - fw, -0.018, 0.018, z - 0.012, z + 0.012, frame, 0)


def lattice_window(name, a0, a1, fixed, z0, z1, axis="x", bars=7, m="wood_dark"):
    """Fenetre a barreaux verticaux (renji-mado) devant un fond sombre."""
    def B(n, p0, p1, q0, q1, r0, r1, mm, bev=0.006):
        if axis == "x":
            bx_span(n, p0, p1, fixed + q0, fixed + q1, r0, r1, mm, bevel=bev)
        else:
            bx_span(n, fixed + q0, fixed + q1, p0, p1, r0, r1, mm, bevel=bev)
    B(name + "_back", a0, a1, 0.03, 0.05, z0, z1, "interior", 0)
    fw = 0.06
    B(name + "_fb", a0 - fw, a1 + fw, -0.05, 0.05, z0 - fw, z0, m)
    B(name + "_ft", a0 - fw, a1 + fw, -0.05, 0.05, z1, z1 + fw, m)
    B(name + "_fl", a0 - fw, a0, -0.05, 0.05, z0, z1, m)
    B(name + "_fr", a1, a1 + fw, -0.05, 0.05, z0, z1, m)
    for i in range(1, bars + 1):
        a = a0 + (a1 - a0) * i / (bars + 1)
        B(f"{name}_b{i}", a - 0.018, a + 0.018, -0.03, 0.03, z0, z1, m)


def post(name, x, y, z0, z1, w=0.17, m="wood_dark"):
    return bx(name, (w, w, z1 - z0), (x, y, (z0 + z1) / 2), m, bevel=0.02)


def stone_plinth(name, x0, x1, y0, y1, h, cap=0.06):
    """Soubassement de pierre : bloc, chaperon plus sombre, quelques joints en saillie, mousse au pied."""
    bx_span(name, x0, x1, y0, y1, 0.0, h - cap, "stone", bevel=0.04, seg=2)
    bx_span(name + "_cap", x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, h - cap, h, "stone_dark", bevel=0.02)
    r = random.Random(len(name))
    for k in range(int((x1 - x0) / 1.4)):
        x = x0 + 0.7 + k * 1.4 + r.uniform(-0.2, 0.2)
        bx(f"{name}_jf{k}", (0.03, 0.03, (h - cap) * 0.9), (x, y0 - 0.005, (h - cap) / 2), "stone_dark", bevel=0)
    for k in range(4):
        x = r.uniform(x0 + 0.3, x1 - 0.3)
        sphere(f"{name}_moss{k}", 1.0, (x, y0 - 0.03, 0.02), "moss", scale=(r.uniform(0.12, 0.22), 0.07, 0.04), seg=8, rings=4)


def merge_visuals(name):
    """Fusionne toutes les pieces visibles en un seul objet (une surface par materiau) : quelques appels de
    dessin au lieu de plusieurs centaines dans Godot. Les collisions (-col) et les reperes restent a part."""
    objs = [o for o in bpy.context.scene.objects
            if o.type == "MESH" and not (o.name.endswith("-col") or o.name.endswith("-convcol"))]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    return o


def ink_glyph(name, cx, y, cz, size, seed, m="lacquer_black", depth=0.012):
    """Caractere a l'encre stylise sur une enseigne (plan XZ, face -Y) : 4 a 6 traits de pinceau de longueurs
    et d'inclinaisons variees (horizontaux, verticaux, obliques, points), comme un kanji vu de loin."""
    r = random.Random(seed)
    s = size
    strokes = [("h", r.uniform(-0.25, 0.25), r.uniform(0.25, 0.42), r.uniform(0.55, 0.95)),
               ("v", r.uniform(-0.15, 0.15), r.uniform(-0.05, 0.05), r.uniform(0.75, 1.0))]
    for _ in range(r.randint(2, 4)):
        kind = r.choice(("h", "h", "d", "d", "p", "v"))
        strokes.append((kind, r.uniform(-0.3, 0.3), r.uniform(-0.35, 0.35), r.uniform(0.3, 0.7)))
    for i, (kind, dx, dz, ln) in enumerate(strokes):
        x, z = cx + dx * s, cz + dz * s
        if kind == "h":
            bx(f"{name}_{i}", (ln * s, depth, 0.11 * s), (x, y, z), m, bevel=0, rot=(0, r.uniform(-0.12, 0.05), 0))
        elif kind == "v":
            bx(f"{name}_{i}", (0.12 * s, depth, ln * s), (x, y, z), m, bevel=0, rot=(0, r.uniform(-0.06, 0.06), 0))
        elif kind == "d":
            bx(f"{name}_{i}", (0.11 * s, depth, ln * s * 0.8), (x, y, z), m, bevel=0, rot=(0, r.choice((-1, 1)) * r.uniform(0.5, 0.8), 0))
        else:
            bx(f"{name}_{i}", (0.14 * s, depth, 0.14 * s), (x, y, z), m, bevel=0, rot=(0, 0.6, 0))
