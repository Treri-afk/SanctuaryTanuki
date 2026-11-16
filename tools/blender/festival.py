"""Decors de Tsukimi, la fete de la lune (fin de la demo) :
- festival_board : tableau de preparation (keijiban) a petit toit, feuilles epinglees (calendrier, liste) ;
- lantern_pole   : perche en bois a bras, socle de pierre ; la lanterne de papier (paper_lantern.glb) pend au repere « hook » ;
- nobori, nobori_red : banderoles verticales sur hampe, socle de pierre ; nobori_rolled : roulee, portee en main ;
- tsukimi_table  : table basse d'offrandes ; objets separes (dango, susuki, kaki, chataigne) que le jeu montre
  au fur et a mesure qu'on les depose.
Un seul materiau par objet : couleurs portees par les sommets (voir tree_util), creux assombris par occlusion.
L'avant est -Y dans Blender, soit +Z dans Godot.
Lancer : blender --background --python tools/blender/festival.py [-- festival_board lantern_pole ...]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from torii_util import *
from glyph_util import glyph_mesh

CEDAR = lin("#7A5238")
CEDAR_DARK = lin("#4E3526")
PLANK = lin("#A88460")
PLANK_DARK = lin("#8A6A4C")
SHINGLE = lin("#4A4040")
SHINGLE_RIDGE = lin("#2E2A2C")
WASHI = lin("#EFE6D2")
WASHI_OLD = lin("#E2D6BC")
INK = lin("#2A2024")
SEAL = lin("#C8442B")
BAMBOO = lin("#B9A25A")
BAMBOO_NODE = lin("#97843F")
ROPE = lin("#C9B07A")
INDIGO = lin("#2E3A5C")
INDIGO_DARK = lin("#232C47")
BANNER_RED = lin("#B8452A")
BANNER_RED_DARK = lin("#93361F")
CREAM = lin("#F1E8D2")
GOLD = lin("#D3A84E")
HINOKI = lin("#D9C3A0")
HINOKI_DARK = lin("#BFA47E")
DANGO = lin("#F4EFE4")
SUSUKI = lin("#D8CFB8")
SUSUKI_STEM = lin("#9A9060")
GLAZE = lin("#3C3A46")
KAKI = lin("#E07B2A")
KAKI_LEAF = lin("#4E6B35")
CHESTNUT = lin("#6E3F22")
CHESTNUT_PALE = lin("#B8936A")


def quad_box(T, pts, color):
    """Pave quelconque : 8 sommets [bas avant-gauche, bas avant-droit, bas arriere-droit, bas arriere-gauche, puis haut]."""
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return T.add(pts, f, color)


def bamboo(T, x, y, z0, z1, r, node_every=0.42, sides=8):
    """Chaume de bambou : tube droit avec des noeuds (bagues un peu plus larges et plus sombres)."""
    zs = [z0]
    z = z0 + node_every * 0.6
    while z < z1 - 0.05:
        zs += [z - 0.012, z, z + 0.012]
        z += node_every
    zs.append(z1)
    rr = []
    for k, zz in enumerate(zs):
        node = 0 < k < len(zs) - 1 and (k % 3 == 2)
        rr.append(r * (1.12 if node else 1.0) * (1 - 0.12 * (zz - z0) / max(z1 - z0, 0.01)))
    cols = {}
    for k in range(len(zs) - 1):
        cols[k] = BAMBOO_NODE if (k % 3 in (1, 2) and 0 < k) else BAMBOO
    T.tube([(x, y, zz) for zz in zs], rr, sides, lambda i, j, p: cols.get(i, BAMBOO))


def disc(T, c, r, color, n=24):
    """Disque face a l'avant (-Y), centre c, un peu bombe."""
    cx, cy, cz = c
    verts = [(cx, cy - 0.006, cz)] + [(cx + r * math.cos(2 * math.pi * k / n), cy, cz + r * math.sin(2 * math.pi * k / n))
                                      for k in range(n)]
    faces = [(0, 1 + (k + 1) % n, 1 + k) for k in range(n)]
    return T.add(verts, faces, color)


def capsule(T, c, half, th, color, n=8):
    """Bande horizontale aux bouts arrondis, face a l'avant (-Y)."""
    cx, cy, cz = c
    ring = []
    for k in range(n + 1):
        a = -math.pi / 2 + math.pi * k / n
        ring.append((cx + half + th * math.cos(a), cy, cz + th * math.sin(a)))
    for k in range(n + 1):
        a = math.pi / 2 + math.pi * k / n
        ring.append((cx - half + th * math.cos(a), cy, cz + th * math.sin(a)))
    verts = [(cx, cy - 0.003, cz)] + ring
    m = len(ring)
    faces = [(0, 1 + (k + 1) % m, 1 + k) for k in range(m)]
    return T.add(verts, faces, color)


def rope_ring(T, x, y, z, r, color=ROPE, sides=8):
    T.tube([(x, y, z - 0.012), (x, y, z), (x, y, z + 0.012)], [r * 1.02, r * 1.12, r * 1.02], sides, color)


# ------------------------------------------------------------------ tableau de preparation
COPPER = lin("#5F8F7C")          # toit de cuivre vert-de-gris (comme le pavillon principal)
COPPER_DARK = lin("#3F665A")
COPPER_EDGE = lin("#2F4A42")
HINOKI_PLANK = lin("#C9A77C")
HINOKI_PLANK2 = lin("#BC9A70")
LACQUER = lin("#26201E")
BRASS = lin("#C9A04A")
PAPER = lin("#F2EBDA")
PAPER_OLD = lin("#E8DCC2")
RED_INK = lin("#B8392A")


def _flat_ink(D, text, cx, y, cz, height, bold, color, vertical=True, space=0.92):
    """Calligraphie posee a plat sur une feuille (plan y), face a l'avant (-Y)."""
    gv, gf = glyph_mesh(text, height, bold, max_edge=1.0, vertical=vertical, space=space)
    D.add([(cx + x, y, cz + yy) for (x, yy) in gv], gf, color, normals=[V((0, -1, 0))] * len(gv))


def _flat_quad(D, x0, x1, z0, z1, y, color):
    D.add([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], [(0, 1, 2, 3)], color, normals=[V((0, -1, 0))] * 4)


def _flat_ring(D, cx, cz, r_in, r_out, y, color, n=28):
    verts, faces = [], []
    for rr in (r_in, r_out):
        for j in range(n):
            a = 2 * math.pi * j / n
            verts.append((cx + rr * math.cos(a), y, cz + rr * math.sin(a)))
    for j in range(n):
        j2 = (j + 1) % n
        faces.append((j, j2, n + j2, n + j))
    D.add(verts, faces, color, normals=[V((0, -1, 0))] * len(verts))


def _flat_disc(D, cx, cz, r, y, color, n=28):
    verts = [(cx, y, cz)] + [(cx + r * math.cos(2 * math.pi * j / n), y, cz + r * math.sin(2 * math.pi * j / n))
                             for j in range(n)]
    D.add(verts, [(0, 1 + j, 1 + (j + 1) % n) for j in range(n)], color, normals=[V((0, -1, 0))] * len(verts))


def _flat_capsule(D, cx, cz, half, th, y, color, n=10):
    """Bande horizontale aux bouts arrondis, peinte a plat (nuage)."""
    ring = []
    for k in range(n + 1):
        a = -math.pi / 2 + math.pi * k / n
        ring.append((cx + half + th * math.cos(a), y, cz + th * math.sin(a)))
    for k in range(n + 1):
        a = math.pi / 2 + math.pi * k / n
        ring.append((cx - half + th * math.cos(a), y, cz + th * math.sin(a)))
    verts = [(cx, y, cz)] + ring
    m = len(ring)
    D.add(verts, [(0, 1 + k, 1 + (k + 1) % m) for k in range(m)], color, normals=[V((0, -1, 0))] * len(verts))


def _curved_roof(T, xo, yd, z_ridge, z_eave, th, sori, lift_ends, color, edge):
    """Pan de toit a courbure japonaise : la pente se redresse vers l'egout (sori), l'egout remonte aux coins.
    Dalle fermee : dessus, dessous et chants. Renvoie la fonction surface(x, s, t) du dessus."""
    nx, nt = 16, 8

    def top(x, s, t):           # t = 0 au faitage -> 1 a l'egout ; s = cote (-1 avant, +1 arriere)
        k = abs(x) / xo
        z = z_ridge + (z_eave - z_ridge) * t - sori * t * (1 - t)        # creux : la pente s'adoucit vers l'egout
        z += lift_ends * (k ** 3) * t
        return V((x, s * yd * t, z))

    for s in (-1, 1):
        verts, faces, cols = [], [], []
        grid = [[top(-xo + 2 * xo * i / nx, s, j / nt) for i in range(nx + 1)] for j in range(nt + 1)]
        for j in range(nt + 1):
            for i in range(nx + 1):
                verts.append(grid[j][i] + V((0, 0, th)))
        off = len(verts)
        for j in range(nt + 1):
            for i in range(nx + 1):
                verts.append(grid[j][i])
        W = nx + 1
        for j in range(nt):
            for i in range(nx):
                a = j * W + i
                faces.append((a, a + 1, a + W + 1, a + W))
                cols.append(color)
                faces.append((off + a, off + a + W, off + a + W + 1, off + a + 1))
                cols.append(edge)
        # chants : egout, rives, faitage
        for j in range(nt):
            for i in (0, nx):
                a, b2 = j * W + i, (j + 1) * W + i
                faces.append((a, b2, off + b2, off + a))
                cols.append(edge)
        for i in range(nx):
            for j in (0, nt):
                a, b2 = j * W + i, j * W + i + 1
                faces.append((a, off + a, off + b2, b2))
                cols.append(edge)
        T.add(verts, faces, lambda k, cols=cols: cols[k])
    return top


class Sheet:
    """Feuille de papier epinglee sur le panneau : un peu de travers, qui gondole (coins du bas releves, leger
    bombe entre les epingles). Tout ce qui est peint dessus suit la meme surface."""

    def __init__(self, D, cx, cz, w, h, y0, angle=0.0, curl=0.02, color=None):
        self.D, self.cx, self.cz, self.w, self.h, self.y0 = D, cx, cz, w, h, y0
        self.ca, self.sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        self.curl = curl
        if color is not None:
            self._paper(color)

    def lift(self, lx, lz):
        """Ecart du papier par rapport au panneau (vers l'avant) en un point local."""
        u = lx / (self.w / 2)
        v = lz / (self.h / 2)
        bottom = max(0.0, -v - 0.35) / 0.65
        corner = bottom ** 2 * (0.35 + 0.65 * u * u)
        bulge = 0.004 * (1 - u * u) * (1 - abs(v)) + 0.003 * math.sin(u * 3.1) * (1 - v * v)
        return self.curl * corner + bulge

    def at(self, lx, lz, over=0.0):
        x = self.cx + lx * self.ca - lz * self.sa
        z = self.cz + lx * self.sa + lz * self.ca
        return (x, self.y0 - self.lift(lx, lz) - over, z)

    def _paper(self, color, nx=8, nz=12):
        verts = [self.at(-self.w / 2 + self.w * i / nx, -self.h / 2 + self.h * j / nz)
                 for j in range(nz + 1) for i in range(nx + 1)]
        W = nx + 1
        faces = [(j * W + i, j * W + i + 1, (j + 1) * W + i + 1, (j + 1) * W + i) for j in range(nz) for i in range(nx)]
        self.D.add(verts, faces, color, normals=[V((0, -1, 0))] * len(verts))

    def ink(self, text, lx, lz, height, bold, color, vertical=True, space=0.92, over=0.0012):
        gv, gf = glyph_mesh(text, height, bold, max_edge=0.04, vertical=vertical, space=space)
        self.D.add([self.at(lx + x, lz + y, over) for (x, y) in gv], gf, color, normals=[V((0, -1, 0))] * len(gv))

    def quad(self, x0, x1, z0, z1, color, over=0.001, n=4):
        verts = [self.at(x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * j / n, over) for j in range(n + 1) for i in range(n + 1)]
        W = n + 1
        faces = [(j * W + i, j * W + i + 1, (j + 1) * W + i + 1, (j + 1) * W + i) for j in range(n) for i in range(n)]
        self.D.add(verts, faces, color, normals=[V((0, -1, 0))] * len(verts))

    def disc(self, lx, lz, r_in, r_out, color, over=0.001, n=28, rings=2):
        verts = []
        for k in range(rings + 1):
            rr = r_in + (r_out - r_in) * k / rings
            for j in range(n):
                a = 2 * math.pi * j / n
                verts.append(self.at(lx + rr * math.cos(a), lz + rr * math.sin(a), over))
        faces = [(i * n + j, i * n + (j + 1) % n, (i + 1) * n + (j + 1) % n, (i + 1) * n + j)
                 for i in range(rings) for j in range(n)]
        self.D.add(verts, faces, color, normals=[V((0, -1, 0))] * len(verts))

    def pin(self, T, lx, lz, color):
        x, y, z = self.at(lx, lz, 0.004)
        T.ico((x, y - 0.004, z), (0.011, 0.008, 0.011), color, subdiv=1, noise=0.0)


def _susuki_bundle(T, base, n=7, seed=3):
    """Gerbe de susuki : tiges qui s'ouvrent en eventail, plumets argentes qui retombent."""
    rng = random.Random(seed)
    bx, by, bz = base
    for k in range(n):
        a = -0.9 + 1.8 * k / (n - 1) + rng.uniform(-0.12, 0.12)
        h = rng.uniform(0.55, 0.8)
        lean = rng.uniform(0.15, 0.3)
        pts = []
        for j in range(6):
            t = j / 5
            pts.append((bx + math.sin(a) * lean * t * t * 1.4, by + rng.uniform(-0.01, 0.01) - 0.04 * t * t,
                        bz + h * t - 0.06 * t ** 3))
        T.tube(pts, [0.006, 0.0055, 0.005, 0.0045, 0.004, 0.003], 4, SUSUKI_STEM)
        # plumet : epillets fins le long d'une tige qui s'incline et retombe d'un cote
        tip = V(pts[-1])
        side = 1 if math.sin(a) >= 0 else -1
        prev = tip
        for m in range(9):
            t = (m + 1) / 9
            q = tip + V((side * (0.02 * t + 0.07 * t * t), -0.012 * t, 0.05 * t - 0.17 * t * t))
            T.tube([prev, q], [0.003, 0.0025], 3, SUSUKI_STEM)
            for sgn in (-1, 1):
                d = (q - prev).normalized()
                off = V((d.z * sgn, 0.0, -d.x * sgn)) * 0.012
                T.ico(tuple(q + off * (1 - 0.5 * t)), (0.009, 0.007, 0.022 * (1 - 0.4 * t)), SUSUKI, subdiv=1,
                      noise=0.0)
            prev = q
        # feuille longue qui part du bas et retombe
        T.tube([(bx, by, bz + 0.02), (bx + math.sin(a + 0.5) * 0.12, by - 0.03, bz + 0.22),
                (bx + math.sin(a + 0.5) * 0.24, by - 0.05, bz + 0.26)], [0.005, 0.004, 0.0015], 3, SUSUKI_STEM)


KOHAKU_RED = lin("#C23A2C")
KOHAKU_WHITE = lin("#F3EEE4")


def _kara(x, H=0.22, wk=0.66):
    """Bosse du karahafu (pignon en arc ondule) le long de l'egout avant : ronde au sommet, creuse sur les flancs."""
    ax = abs(x)
    return H * 0.5 * (1 + math.cos(math.pi * ax / wk)) if ax < wk else 0.0


def _roof_kara(T, xo, yd, zr, ze, th, sori, lift_ends, color, edge, nx=28, nt=10):
    """Toit a deux pans courbes ; le pan avant porte un karahafu au milieu de l'egout. Renvoie surface(x, s, t)
    = dessous de la couverture (t = 0 faitage -> 1 egout, s = -1 avant / +1 arriere)."""
    def surf(x, s, t):
        k = abs(x) / xo
        z = zr + (ze - zr) * t - sori * t * (1 - t) + lift_ends * (k ** 3) * t
        if s < 0:
            z += _kara(x) * t ** 1.6
        return V((x, s * yd * t, z))

    for s in (-1, 1):
        verts, faces, cols = [], [], []
        grid = [[surf(-xo + 2 * xo * i / nx, s, j / nt) for i in range(nx + 1)] for j in range(nt + 1)]
        W = nx + 1
        for row in grid:
            verts += [p + V((0, 0, th)) for p in row]
        off = len(verts)
        for row in grid:
            verts += row
        for j in range(nt):
            for i in range(nx):
                a = j * W + i
                faces.append((a, a + 1, a + W + 1, a + W))
                cols.append(color)
                faces.append((off + a, off + a + W, off + a + W + 1, off + a + 1))
                cols.append(edge)
        for j in range(nt):
            for i in (0, nx):
                a, b2 = j * W + i, (j + 1) * W + i
                faces.append((a, b2, off + b2, off + a))
                cols.append(edge)
        for i in range(nx):
            for j in (0, nt):
                a, b2 = j * W + i, j * W + i + 1
                faces.append((a, off + a, off + b2, b2))
                cols.append(edge)
        T.add(verts, faces, lambda k, cols=cols: cols[k])
    return surf


def _kohaku_maku(D, x0, x1, z_top, z_bot, y, stripe=0.15, pleat=0.025):
    """Rideau de fete raye rouge et blanc (kohaku-maku), plisse ; deux faces (normales imposees)."""
    nx = int((x1 - x0) / 0.025)
    nz = 6
    xs = [x0 + (x1 - x0) * i / nx for i in range(nx + 1)]
    zs = [z_top + (z_bot - z_top) * j / nz for j in range(nz + 1)]

    def pos(x, z):
        f = (z_top - z) / (z_top - z_bot)
        return V((x, y + pleat * math.sin((x - x0) / stripe * math.pi) * (0.55 + 0.45 * f), z))

    def nrm(x, z):
        f = (z_top - z) / (z_top - z_bot)
        dydx = pleat * math.cos((x - x0) / stripe * math.pi) * math.pi / stripe * (0.55 + 0.45 * f)
        return V((dydx, -1.0, 0.0)).normalized()

    for side in (-1, 1):
        dy = 0.0 if side < 0 else 0.004
        verts = [pos(x, z) + V((0, dy, 0)) for z in zs for x in xs]
        ns = [nrm(x, z) * (1 if side < 0 else -1) for z in zs for x in xs]
        W = nx + 1
        faces, cols = [], []
        for j in range(nz):
            for i in range(nx):
                q = (j * W + i, j * W + i + 1, (j + 1) * W + i + 1, (j + 1) * W + i)
                faces.append(q if side < 0 else tuple(reversed(q)))
                xm = (xs[i] + xs[i + 1]) / 2
                cols.append(KOHAKU_RED if int((xm - x0) / stripe) % 2 == 0 else KOHAKU_WHITE)
        D.add(verts, faces, lambda k, cols=cols: cols[k], normals=ns)


def _shide(T, top, size=0.06, color=None):
    """Shide : bande de papier blanc pliee en zigzag, qui pend d'une corde."""
    color = color or KOHAKU_WHITE
    x, y, z = top
    pts = [(x, y, z), (x + size * 0.35, y, z - size * 0.5), (x - size * 0.1, y, z - size),
           (x + size * 0.25, y, z - size * 1.5), (x - size * 0.15, y, z - size * 2.0)]
    for k in range(len(pts) - 1):
        a, b2 = V(pts[k]), V(pts[k + 1])
        c = (a + b2) / 2
        d = b2 - a
        ang = math.atan2(d.x, -d.z)
        w, h = size * 0.38, d.length
        ca, sa = math.cos(ang), math.sin(ang)
        quad = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        vs = [(c.x + qx * ca - qz * sa, c.y + yy, c.z + qx * sa + qz * ca) for (qx, qz) in quad for yy in (-0.0015, 0.0015)]
        v8 = [vs[0], vs[2], vs[4], vs[6], vs[1], vs[3], vs[5], vs[7]]
        quad_box(T, [v8[0], v8[1], v8[5], v8[4], v8[3], v8[2], v8[6], v8[7]], color)


def festival_board():
    """Tableau d'affichage du sanctuaire (keijiban) habille pour Tsukimi.
    Silhouette : grand toit de cuivre vert-de-gris a deux pans courbes, karahafu (pignon en arc ondule) au milieu
    de l'avant, planche de rive courbe a medaillon de lune dore ; poteaux massifs sur socles de pierre.
    Fete : rideau raye rouge et blanc sous le panneau, corde tendue sous l'avant-toit avec des shide et quatre
    reperes « garland_0..3 » ou le jeu accroche des lanternes, gerbes de susuki aux deux poteaux.
    Panneau : feuilles qui gondolent (affiche « 月見祭 », liste « 準備 », avis « 迷い猫 »), plaque « 掲示板 »."""
    reset_scene()
    T = TM()
    D = TM()          # papier, rideau et peintures : normales imposees
    PX = 0.86
    P = 0.072
    TOP_BEAM = 2.1
    B0, B1 = 0.8, 1.9
    BW = 0.7
    # ---- socles et poteaux massifs
    for s in (-1, 1):
        x = s * PX
        box(T, (x, 0, 0.03), (0.34, 0.34, 0.1), STONE_DARK)
        T.add(*_frustum((x, 0), 0.15, 0.105, 0.08, 0.2), STONE)
        lathe(T, [(P * 1.08, 0.19), (P * 1.08, TOP_BEAM + 0.12), (0.0, TOP_BEAM + 0.12)], 8, (x, 0),
              lambda k: CEDAR, phase=math.pi / 8)
        box(T, (x, 0, 0.25), (2 * P * 1.08 + 0.014, 2 * P * 1.08 + 0.014, 0.06), IRON)
        box(T, (x, 0, TOP_BEAM - 0.1), (2 * P * 1.08 + 0.014, 2 * P * 1.08 + 0.014, 0.04), IRON)
    # ---- traverses
    box(T, (0, 0, TOP_BEAM), (2 * PX + 0.42, 0.13, 0.13), CEDAR_DARK)
    box(T, (0, 0, B0 - 0.13), (2 * PX + 0.3, 0.08, 0.08), CEDAR_DARK)
    for s in (-1, 1):
        box(T, (s * (PX + P + 0.035), -0.045, B0 - 0.13), (0.03, 0.014, 0.11), CEDAR)
        box(T, (s * (PX + 0.21 - 0.007), 0, TOP_BEAM), (0.014, 0.135, 0.135), BRASS)
        box(T, (s * (PX + 0.15 - 0.007), 0, B0 - 0.13), (0.014, 0.085, 0.085), BRASS)
    # ---- panneau en retrait dans un cadre profond
    PY = 0.02
    n_pl = 9
    for k in range(n_pl):
        x0 = -BW + 2 * BW * k / n_pl
        box(T, (x0 + BW / n_pl, PY + 0.0125, (B0 + B1) / 2), (2 * BW / n_pl - 0.006, 0.025, B1 - B0),
            HINOKI_PLANK if k % 2 else HINOKI_PLANK2)
    box(T, (0, PY + 0.03, (B0 + B1) / 2), (2 * BW, 0.01, B1 - B0), LACQUER)
    FD = 0.13
    for z in (B0 - 0.03, B1 + 0.03):
        box(T, (0, PY + 0.03 - FD / 2, z), (2 * BW + 0.14, FD, 0.07), LACQUER)
    for s in (-1, 1):
        box(T, (s * (BW + 0.035), PY + 0.03 - FD / 2, (B0 + B1) / 2), (0.07, FD, B1 - B0 + 0.13), LACQUER)
        box(T, (s * (BW + 0.07 + (PX - P - BW - 0.07) / 2), PY - 0.02, (B0 + B1) / 2),
            (PX - P - BW - 0.07 + 0.02, 0.05, 0.08), CEDAR_DARK)
    box(T, (0, PY + 0.03 - FD + 0.01, B1 + 0.075), (2 * BW + 0.2, 0.05, 0.025), CEDAR_DARK)
    # ---- plaque « 掲示板 » posee sur la traverse haute
    pz = TOP_BEAM + 0.02
    box(T, (0, -0.075, pz), (0.52, 0.024, 0.17), LACQUER)
    box(T, (0, -0.085, pz), (0.48, 0.012, 0.13), lin("#3A2E28"))
    _flat_ink(D, "掲示板", 0.0, -0.0915, pz - 0.002, 0.09, 0.03, BRASS, vertical=False)
    # ---- feuilles epinglees
    y0 = PY - 0.001
    A = Sheet(D, -0.3, 1.36, 0.5, 0.88, y0, angle=-1.2, curl=0.03, color=PAPER)
    m = 0.03
    for (d, w) in ((m, 0.008), (m + 0.016, 0.003)):
        hw, hh = A.w / 2 - d, A.h / 2 - d
        A.quad(-hw, hw, hh - w, hh, RED_INK)
        A.quad(-hw, hw, -hh, -hh + w, RED_INK)
        A.quad(-hw, -hw + w, -hh, hh, RED_INK)
        A.quad(hw - w, hw, -hh, hh, RED_INK)
    A.disc(0.09, 0.24, 0.0, 0.095, GOLD)
    A.disc(0.09, 0.24, 0.095, 0.101, lin("#B08A3A"), rings=1)
    A.ink("月見祭", -0.1, 0.02, 0.6, 0.026, INK)
    A.ink("十五夜", 0.1, -0.07, 0.24, 0.02, INK)
    A.quad(0.065, 0.135, -0.33, -0.26, RED_INK)
    A.ink("祭", 0.1, -0.295, 0.05, 0.03, PAPER, over=0.0018)
    for (lx, lz) in ((-0.23, 0.42), (0.23, 0.42)):
        A.pin(T, lx, lz, BRASS)
    L = Sheet(D, 0.34, 1.43, 0.4, 0.72, y0, angle=1.6, curl=0.025, color=PAPER_OLD)
    L.ink("準備", 0.0, 0.275, 0.062, 0.02, INK, vertical=False)
    L.quad(-0.16, 0.16, 0.22, 0.225, INK)
    for k, item in enumerate(("提灯", "幟", "供物")):
        cx = 0.11 - k * 0.11
        L.disc(cx, 0.15, 0.026, 0.033, RED_INK, rings=1)
        h = 0.082 * len(item) + 0.014 * (len(item) - 1)
        L.ink(item, cx, 0.09 - h / 2, h, 0.024, INK, space=1.0)
    L.ink("社務所", -0.13, -0.215, 0.12, 0.018, INK)
    L.quad(-0.155, -0.105, -0.335, -0.29, RED_INK)
    for (lx, lz) in ((-0.18, 0.34), (0.18, 0.34)):
        L.pin(T, lx, lz, BRASS)
    C = Sheet(D, 0.05, 0.99, 0.17, 0.2, y0, angle=-5.0, curl=0.012, color=lin("#F4EFE2"))
    C.ink("迷い猫", 0.035, 0.0, 0.14, 0.02, INK)
    C.ink("もち", -0.04, 0.015, 0.075, 0.02, RED_INK)
    C.pin(T, 0.0, 0.08, SEAL)
    # ---- tablette : pierre a encre et pinceau
    box(T, (0, -0.1, B0 - 0.045), (0.7, 0.17, 0.03), CEDAR)
    for s in (-1, 1):
        box(T, (s * 0.28, -0.06, B0 - 0.085), (0.03, 0.11, 0.05), CEDAR_DARK)
    box(T, (-0.16, -0.11, B0 - 0.022), (0.13, 0.08, 0.02), LACQUER)
    box(T, (-0.16, -0.11, B0 - 0.011), (0.1, 0.055, 0.004), lin("#3B3A40"))
    T.tube([(0.03, -0.115, B0 - 0.018), (0.22, -0.105, B0 - 0.018)], [0.0065, 0.0065], 6, BAMBOO)
    T.tube([(0.22, -0.105, B0 - 0.018), (0.25, -0.104, B0 - 0.018), (0.27, -0.104, B0 - 0.019)],
           [0.0075, 0.007, 0.002], 6, INK)
    # ---- rideau de fete sous le panneau, accroche a la traverse basse par une grosse corde blanche
    zt = B0 - 0.17
    _kohaku_maku(D, -PX + P + 0.005, PX - P - 0.005, zt, 0.16, -0.06)
    T.tube([(-PX + P, -0.085, zt + 0.01), (PX - P, -0.085, zt + 0.01)], [0.016, 0.016], 8, KOHAKU_WHITE)
    for k in range(7):                                  # noeuds de la corde
        x = -PX + P + 0.06 + (2 * (PX - P) - 0.12) * k / 6
        T.ico((x, -0.09, zt + 0.01), (0.024, 0.02, 0.022), KOHAKU_WHITE, subdiv=1, noise=0.0)
    # ---- gerbes de susuki liees aux deux poteaux
    for s in (-1, 1):
        vx = s * (PX + P + 0.05)
        T.tube([(vx, -0.02, 0.95), (vx, -0.02, 1.3)], [0.045, 0.043], 10, BAMBOO)
        T.tube([(vx, -0.02, 1.3), (vx, -0.02, 1.305)], [0.043, 0.035], 10, BAMBOO_NODE)
        for z in (1.04, 1.21):
            rope_ring(T, vx, -0.02, z, 0.05, ROPE)
            T.tube([(vx - s * 0.045, -0.02, z), (s * PX, -0.02, z)], [0.008, 0.008], 4, ROPE)
        _susuki_bundle(T, (vx, -0.02, 1.28), n=7, seed=3 if s > 0 else 8)
    # ---- toit : grand debord, karahafu a l'avant
    xo, yd = 1.3, 0.66
    zr, ze, th = 2.78, 2.3, 0.045
    roof = _roof_kara(T, xo, yd, zr, ze, th, 0.1, 0.1, COPPER, COPPER_EDGE)
    for s in (-1, 1):
        for k in range(15):                             # nervures
            x = -xo + 0.08 + (2 * xo - 0.16) * k / 14
            pts = [roof(x, s, t) + V((0, 0, th + 0.007)) for t in [i / 10 for i in range(11)]]
            T.tube(pts, [0.009] * len(pts), 4, COPPER_DARK)
        eave = [roof(-xo + 2 * xo * i / 28, s, 1.0) for i in range(29)]
        T.tube([p + V((0, 0, th * 0.5)) for p in eave], [0.03] * 29, 6, COPPER_DARK)          # bord roule
        T.tube([p + V((0, 0, -0.045)) for p in eave], [0.045] * 29, 4, CEDAR_DARK)           # planche d'egout
        for k in range(19):                             # chevrons sous l'avant-toit
            x = -xo + 0.1 + (2 * xo - 0.2) * k / 18
            pts = [roof(x, s, t) + V((0, 0, -0.025)) for t in (0.12, 0.4, 0.7, 0.96)]
            T.tube(pts, [0.02] * 4, 4, CEDAR)
    # karahafu : planche de rive courbe et epaisse sous la bosse, filet dore, medaillon de lune
    kx = [-0.8 + 1.6 * i / 32 for i in range(33)]
    hafu = [roof(x, -1, 1.0) + V((0, -0.01, -0.07)) for x in kx]
    T.tube(hafu, [0.06] * len(hafu), 6, CEDAR_DARK)
    T.tube([p + V((0, -0.045, 0.03)) for p in hafu], [0.012] * len(hafu), 5, BRASS)
    top = roof(0.0, -1, 1.0) + V((0, -0.07, -0.07))
    T.tube([top + V((0, 0.03, 0)), top + V((0, -0.03, 0))], [0.09, 0.09], 24, GOLD)          # medaillon de lune
    T.tube([top + V((0, 0.02, 0)), top + V((0, -0.025, 0))], [0.1, 0.1], 24, BRASS, cap_end=False)
    # faitage, abouts, planches de rive des pignons
    box(T, (0, 0, zr + th + 0.04), (2 * xo + 0.1, 0.15, 0.09), COPPER_DARK)
    for s in (-1, 1):
        box(T, (s * (xo + 0.06), 0, zr + th + 0.06), (0.11, 0.18, 0.16), COPPER_EDGE)
        x = s * (xo - 0.02)
        for side in (-1, 1):
            pts = [roof(x, side, t) + V((0, 0, -0.04)) for t in [i / 8 for i in range(9)]]
            T.tube(pts, [0.035] * len(pts), 4, CEDAR_DARK)
        T.ico((x + s * 0.035, 0, zr - 0.04), (0.03, 0.05, 0.05), BRASS, subdiv=1, noise=0.0)
    for s in (-1, 1):
        box(T, (s * PX, 0, (TOP_BEAM + zr) / 2 - 0.02), (0.1, 0.1, zr - TOP_BEAM - 0.06), CEDAR)
        zp = roof(0.0, s, 0.55).z - 0.025 - 0.02 - 0.035
        box(T, (0, s * yd * 0.55, zp), (2 * xo - 0.14, 0.07, 0.07), CEDAR_DARK)
    box(T, (0, 0, zr - 0.07), (2 * xo - 0.12, 0.08, 0.08), CEDAR_DARK)
    # ---- guirlande : corde tendue sous l'avant de l'avant-toit, shide, reperes des lanternes
    ends = [roof(sx * (xo - 0.12), -1, 0.85) + V((0, 0, -0.06)) for sx in (-1, 1)]
    def garland(t):
        p = ends[0] + (ends[1] - ends[0]) * t
        return p + V((0, 0, -0.16 * math.sin(math.pi * t)))
    gp = [garland(i / 30) for i in range(31)]
    T.tube(gp, [0.009] * len(gp), 5, ROPE)
    for e in ends:
        T.tube([e, e + V((0, 0, 0.07))], [0.006, 0.006], 4, IRON)
    lan_t = (0.11, 0.3, 0.7, 0.89)                    # rien au centre : la plaque reste visible
    for k, t in enumerate(lan_t):
        p = garland(t)
        T.tube([p, p + V((0, 0, -0.05))], [0.0045, 0.0045], 4, IRON)
        empty("garland_%d" % k, loc=tuple(p + V((0, 0, -0.05))))
    for t in (0.205, 0.4, 0.5, 0.6, 0.795):
        p = garland(t)
        _shide(T, (p.x, p.y - 0.01, p.z - 0.01), size=0.055)
    T.build("board")
    D.build("board_paint", custom_normals=True)
    collision_box("board", (2.0, 0.35, 2.2), (0, 0, 1.1))
    finish_tree("festival_board", expected_dims=(2.75, 1.4, 2.95), tri_limit=(400, 30000), trunk_angle=30, yaw=-22,
                pitch=6, margin=1.08, views=[("_close", dict(yaw=-8, pitch=2, margin=0.62))])


def _frustum(c, r0, r1, z0, z1):
    """Tronc de pyramide carre (socle de pierre taille) : base r0, haut r1 (demi-cotes)."""
    cx, cy = c
    v = [(cx - r0, cy - r0, z0), (cx + r0, cy - r0, z0), (cx + r0, cy + r0, z0), (cx - r0, cy + r0, z0),
         (cx - r1, cy - r1, z1), (cx + r1, cy - r1, z1), (cx + r1, cy + r1, z1), (cx - r1, cy + r1, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return v, f


# ------------------------------------------------------------------ perche a lanterne
STONE = lin("#8E8A80")
STONE_DARK = lin("#6E6A62")
IRON = lin("#2C2A2E")
POST = lin("#8A5E40")
POST_DARK = lin("#6A4630")

BOX_FACES = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]


def strut(T, a, b, half_u, half_v, plane_a, plane_b, color):
    """Piece de bois de section rectangulaire, de a vers b (dans le plan XZ), dont les deux bouts sont coupes
    pile sur un plan : plane_* = (normale, point). Les aretes touchent les faces des pieces voisines, sans jour."""
    a, b = V(a), V(b)
    d = (b - a).normalized()
    u = V((0, 1, 0)).cross(d).normalized()      # epaisseur, dans le plan XZ
    v = V((0, 1, 0))                             # largeur, selon Y
    verts = []
    for end, (n, p0) in ((0, plane_a), (1, plane_b)):
        n, p0 = V(n), V(p0)
        for sy in (-1, 1):
            for sx in (-1, 1):
                o = a + u * (sx * half_u) + v * (sy * half_v)
                t = (p0 - o).dot(n) / d.dot(n)   # intersection de l'arete avec le plan
                verts.append(o + d * t)
    return T.add(verts, BOX_FACES, color)


def lantern_pole():
    """Perche a lanterne en bois : poteau carre plante dans un socle de pierre, bras qui traverse le poteau
    (cheville au dos), contrefiche coupee d'equerre sur le poteau et sous le bras, petit chapeau, crochet en fer.
    La lanterne (paper_lantern.glb, mise a l'echelle par le jeu) pend sous le repere « hook »."""
    reset_scene()
    T = TM()
    H = 2.5            # sommet du poteau
    P = 0.045          # demi-section du poteau
    ARM = 2.28         # axe du bras
    A = 0.028          # demi-section du bras
    HOOK_X = 0.42
    # socle : pierre taillee a deux gradins, enterree de quelques centimetres
    box(T, (0, 0, 0.04), (0.30, 0.30, 0.16), STONE_DARK)
    box(T, (0, 0, 0.15), (0.22, 0.22, 0.08), STONE)
    # poteau, du coeur du socle jusqu'au chapeau
    box(T, (0, 0, (0.05 + H) / 2), (2 * P, 2 * P, H - 0.05), POST)
    # chapeau : plaque + petit toit a quatre pans qui recouvre le haut du poteau
    box(T, (0, 0, H + 0.01), (0.13, 0.13, 0.02), POST_DARK)
    c, r, top = H + 0.02, 0.075, H + 0.07
    T.add([(-r, -r, c), (r, -r, c), (r, r, c), (-r, r, c), (0, 0, top)],
          [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)], SHINGLE)
    # bras : traverse le poteau, depasse un peu au dos ; cheville verticale derriere le poteau
    x0, x1 = -0.11, HOOK_X + 0.06
    box(T, ((x0 + x1) / 2, 0, ARM), (x1 - x0, 2 * A, 2 * A), POST)
    T.tube([(-0.08, 0, ARM - A - 0.02), (-0.08, 0, ARM + A + 0.025)], [0.009, 0.009], 6, POST_DARK)
    # contrefiche : de la face avant du poteau au-dessous du bras, coupee sur ces deux faces
    zb = ARM - A
    strut(T, (P, 0, ARM - 0.42), (0.30, 0, zb), 0.02, 0.02,
          ((1, 0, 0), (P - 0.002, 0, 0)), ((0, 0, 1), (0, 0, zb + 0.002)), POST_DARK)
    # crochet en fer sous le bout du bras, puis cordelette jusqu'au repere
    T.tube([(HOOK_X, 0, zb + 0.005), (HOOK_X, 0, zb - 0.035)], [0.006, 0.006], 5, IRON)
    T.tube([(HOOK_X, 0, zb - 0.035), (HOOK_X + 0.018, 0, zb - 0.05), (HOOK_X, 0, zb - 0.065)],
           [0.005, 0.005, 0.005], 5, IRON)
    T.tube([(HOOK_X, 0, zb - 0.06), (HOOK_X, 0, zb - 0.13)], [0.004, 0.004], 4, ROPE)
    T.build("pole")
    empty("hook", loc=(HOOK_X, 0, zb - 0.13))
    collision_box("pole", (0.3, 0.3, H), (0, 0, H / 2))
    finish_tree("lantern_pole", expected_dims=(0.6, 0.3, 2.6), tri_limit=(60, 1500), trunk_angle=30, yaw=-25,
                pitch=8, margin=1.1)


# ------------------------------------------------------------------ banderoles nobori
NOBORI_POLE = lin("#3A2A22")
NOBORI_TOP = 3.32        # haut de l'etoffe
NOBORI_LEN = 2.5         # longueur de l'etoffe
NOBORI_W = 0.6           # largeur de l'etoffe
NOBORI_X0 = 0.065        # bord de l'etoffe cote hampe (la hampe est en x = 0)
HEADER = 0.34            # bandeau du haut (couleur foncee, lune)
HEM = 0.12               # ourlet du bas
CLOTH_TH = 0.0035        # epaisseur de l'etoffe (deux faces)


def _cloth_pos(u, v):
    """Point de l'etoffe : u = 0 cote hampe -> 1 bord libre ; v = 0 en haut -> 1 en bas.
    Ondulation douce qui grandit loin de la hampe et vers le bas (le tissu ne pend que par deux bords)."""
    x = NOBORI_X0 + u * NOBORI_W
    z = NOBORI_TOP - v * NOBORI_LEN
    y = 0.03 * math.sin(u * 2.4 + v * 4.2) * u * (0.4 + 0.6 * v) + 0.01 * math.sin(v * 7.0) * u
    return V((x, y, z))


def _cloth_normal(u, v):
    du = _cloth_pos(min(1, u + 0.01), v) - _cloth_pos(max(0, u - 0.01), v)
    dv = _cloth_pos(u, min(1, v + 0.01)) - _cloth_pos(u, max(0, v - 0.01))
    n = dv.cross(du).normalized()          # vers l'avant (-Y)
    return n if n.y < 0 else -n


def _on_cloth(s, t, side, lift):
    """Point du motif : s = metres depuis l'axe de l'etoffe (vers le bord libre vu de face), t = metres depuis le
    haut ; side = -1 face avant (-Y), +1 face arriere (motif retourne pour se lire de ce cote)."""
    u = 0.5 + (s if side < 0 else -s) / NOBORI_W
    v = t / NOBORI_LEN
    p, n = _cloth_pos(u, v), _cloth_normal(u, v)
    return p + n * lift if side < 0 else p + V((0, CLOTH_TH, 0)) - n * lift


def _side_normal(s, t, side):
    u = 0.5 + (s if side < 0 else -s) / NOBORI_W
    n = _cloth_normal(u, t / NOBORI_LEN)
    return n if side < 0 else -n


def _cloth_uv(s, t, side):
    """(u, v) de l'etoffe sous un point du motif : le shader s'en sert pour faire onduler le motif avec le tissu."""
    return (0.5 + (s if side < 0 else -s) / NOBORI_W, t / NOBORI_LEN)


def _decal_disc(T, t, r_in, r_out, color, side, n=32, rings=2):
    verts, faces, nrm = [], [], []
    for k in range(rings + 1):
        rr = r_in + (r_out - r_in) * k / rings
        for j in range(n):
            a = 2 * math.pi * j / n
            verts.append(_on_cloth(rr * math.cos(a), t - rr * math.sin(a), side, 0.004))
            nrm.append(_side_normal(rr * math.cos(a), t - rr * math.sin(a), side))
            T.uvs.append(_cloth_uv(rr * math.cos(a), t - rr * math.sin(a), side))
    for i in range(rings):
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    T.add(verts, faces, color, normals=nrm)


def _decal_text(T, text, t_center, height, bold, color, side):
    gv, gf = glyph_mesh(text, height, bold, max_edge=0.05)
    verts = [_on_cloth(x, t_center - y, side, 0.004) for (x, y) in gv]
    T.add(verts, gf, color, normals=[_side_normal(x, t_center - y, side) for (x, y) in gv])
    T.uvs += [_cloth_uv(x, t_center - y, side) for (x, y) in gv]


def nobori(name="nobori", face=INDIGO, dark=INDIGO_DARK, ink=CREAM, seed=1):
    """Banderole nobori : etoffe verticale tenue par une traverse en haut et par des boucles (chichi) le long de la
    hampe ; bandeau fonce avec la pleine lune, grande calligraphie « 月見祭 », ourlet. Motif sur les deux faces
    (chacune se lit dans le bon sens). Hampe laquee a bouton dore, plantee dans un socle de pierre perce."""
    reset_scene()
    T = TM()
    H = NOBORI_TOP + 0.2
    # hampe
    T.tube([(0, 0, 0.12), (0, 0, H)], [0.024, 0.021], 10, NOBORI_POLE)
    lathe(T, [(0.021, H - 0.005), (0.03, H + 0.012), (0.034, H + 0.035), (0.024, H + 0.06), (0.008, H + 0.085),
              (0.0, H + 0.09)], 12, (0, 0), lambda k: GOLD)
    # traverse du haut : prise dans l'ourlet de l'etoffe, ligaturee a la hampe
    zt = NOBORI_TOP + 0.012
    T.tube([(-0.03, 0, zt), (NOBORI_X0 + NOBORI_W + 0.035, 0, zt)], [0.012, 0.011], 8, NOBORI_POLE)
    rope_ring(T, 0, 0, zt, 0.03, ROPE)
    T.ico((NOBORI_X0 + NOBORI_W + 0.04, 0, zt), (0.016, 0.016, 0.016), GOLD, subdiv=1, noise=0.0)
    # etoffe (maillage a part, normales imposees : une etoffe ouverte n'a pas de « dehors » que Blender devine)
    C = TM()
    C.uvs = []
    us = [i / 12 for i in range(13)]
    vs = sorted(set([j / 30 for j in range(31)] + [HEADER / NOBORI_LEN, 1 - HEM / NOBORI_LEN]))
    nu = len(us)
    front = [_cloth_pos(u, v) for v in vs for u in us]
    back = [p + V((0, CLOTH_TH, 0)) for p in front]
    faces, cols = [], []
    for j in range(len(vs) - 1):
        vm = (vs[j] + vs[j + 1]) / 2 * NOBORI_LEN
        col = dark if (vm < HEADER or vm > NOBORI_LEN - HEM) else face
        for i in range(nu - 1):
            a = j * nu + i
            faces.append((a, a + 1, a + nu + 1, a + nu))
            cols.append(col)
    nf = len(faces)
    off = len(front)
    for k in range(nf):
        faces.append(tuple(reversed([i + off for i in faces[k]])))
        cols.append(cols[k])
    nf_front = [_cloth_normal(u, v) for v in vs for u in us]
    C.add(front + back, faces, lambda k: cols[k], normals=nf_front + [-n for n in nf_front])
    C.uvs += [(u, v) for v in vs for u in us] * 2
    # motifs, sur les deux faces
    for side in (-1, 1):
        _decal_disc(C, HEADER * 0.5, 0.0, 0.105, ink, side)                       # pleine lune
        _decal_text(C, "月見祭", HEADER + (NOBORI_LEN - HEADER - HEM) * 0.5, 1.5, 0.026, ink, side)
    # boucles (chichi) qui tiennent l'etoffe a la hampe
    for k in range(6):
        z = NOBORI_TOP - 0.12 - k * (NOBORI_LEN - 0.3) / 5
        pts = [(0.022 + 0.042 * math.cos(a) + 0.02, 0.03 * math.sin(a), z) for a in
               [2 * math.pi * j / 12 for j in range(13)]]
        T.tube(pts, [0.0075] * len(pts), 5, dark, cap_end=False)
    # socle : pierre taillee, percee pour la hampe
    lathe(T, [(0.17, 0.0), (0.18, 0.04), (0.165, 0.14), (0.12, 0.2), (0.04, 0.2), (0.04, 0.17), (0.0, 0.17)], 12,
          (0, 0), lambda k: STONE, phase=0.26, noise=0.02, seed=seed)
    T.build("banner")
    # « banner_cloth » : le jeu reconnait ce nom et fait onduler l'etoffe au vent (UV = position sur l'etoffe :
    # u = 0 a la hampe -> 1 au bord libre, v = 0 en haut -> 1 en bas)
    cl = C.build("banner_cloth", custom_normals=True)
    uvl = cl.data.uv_layers.new(name="UVMap")
    for loop in cl.data.loops:
        u, v = C.uvs[loop.vertex_index]
        uvl.data[loop.index].uv = (u, 1.0 - v)    # l'export glTF retourne V : le jeu recoit bien v = 0 en haut
    collision_box("banner", (0.36, 0.36, 1.2), (0, 0, 0.6))
    finish_tree(name, expected_dims=(0.75, 0.4, 3.6), tri_limit=(400, 9000), trunk_angle=35, yaw=-30, pitch=6,
                margin=1.08)


def nobori_rolled():
    """Banderole roulee autour de sa hampe, a porter (origine au milieu, s'etend selon +Z) : rouleau d'etoffe
    avec le bord en spirale, deux liens clairs, bouton dore."""
    reset_scene()
    T = TM()
    T.tube([(0, 0, -0.78), (0, 0, 0.8)], [0.022, 0.02], 8, NOBORI_POLE)
    lathe(T, [(0.019, 0.795), (0.027, 0.81), (0.03, 0.83), (0.021, 0.855), (0.007, 0.875), (0.0, 0.88)], 12, (0, 0),
          lambda k: GOLD)
    z0, z1, r = -0.36, 0.6, 0.052
    lathe(T, [(0.0, z0 - 0.004), (r - 0.012, z0 - 0.004), (r, z0 + 0.01), (r, z1 - 0.01), (r - 0.012, z1 + 0.004),
              (0.0, z1 + 0.004)], 16, (0, 0), lambda k: INDIGO)
    # bord de l'etoffe enroulee : une bande foncee en spirale, a peine en relief
    pts = []
    for k in range(61):
        t = k / 60
        a = t * 2 * math.pi * 3.2
        pts.append((math.cos(a) * (r + 0.002), math.sin(a) * (r + 0.002), z0 + 0.03 + t * (z1 - z0 - 0.06)))
    T.tube(pts, [0.004] * len(pts), 4, INDIGO_DARK, cap_end=False)
    for z in (-0.16, 0.4):
        rope_ring(T, 0, 0, z, r + 0.004, CREAM, sides=16)
    T.build("rolled")
    finish_tree("nobori_rolled", expected_dims=(0.13, 0.13, 1.7), tri_limit=(60, 2000), trunk_angle=35, yaw=20,
                pitch=10, margin=1.2)


# ------------------------------------------------------------------ table d'offrandes
MOSEN = lin("#B02E26")
MOSEN_DARK = lin("#8E231D")
HINOKI_LIGHT = lin("#E2CDA8")
KAKI_DARK = lin("#C9631C")
CALYX = lin("#5A5A2E")
CHESTNUT_DARK = lin("#4E2A16")
LEAF_GREEN = lin("#6E7B3A")
PORCELAIN = lin("#EEEAE0")
PORCELAIN_BLUE = lin("#3D5A8A")


def _mosen(D, x_half, y_half, top, drop, th=0.004):
    """Tapis de feutre rouge (hi-mosen) pose sur la table, qui retombe devant et derriere en plis souples."""
    # profil (y, z) : retombee avant, arrondi, dessus, arrondi, retombee arriere
    prof = []
    for k in range(6):
        t = k / 5
        prof.append((-y_half - 0.006, top - drop * (1 - t)))
    for k in range(1, 5):
        a = math.pi / 2 * k / 4
        prof.append((-y_half - 0.006 + 0.006 * (1 - math.cos(a)) * 0 + 0.0, top + 0.006 * math.sin(a)))
    for k in range(1, 12):
        prof.append((-y_half + 2 * y_half * k / 12, top + 0.006))
    for k in range(5):
        a = math.pi / 2 * k / 4
        prof.append((y_half + 0.006, top + 0.006 * math.cos(a)))
    for k in range(1, 6):
        t = k / 5
        prof.append((y_half + 0.006, top - drop * t))
    nx = 24
    for side in (-1, 1):
        verts, ns = [], []
        for i in range(nx + 1):
            x = -x_half + 2 * x_half * i / nx
            for (y, z) in prof:
                hang = max(0.0, (top - z) / drop) if z < top else 0.0
                fold = 0.008 * math.sin(x / x_half * math.pi * 3.0) * hang
                off = V((0, math.copysign(fold, y), 0)) if abs(y) > y_half else V((0, 0, 0))
                p = V((x, y, z)) + off
                if side > 0:                         # face interieure, un peu en retrait
                    p = p + (V((0, -math.copysign(th, y), 0)) if abs(y) > y_half else V((0, 0, -th)))
                verts.append(p)
                n = V((0, math.copysign(1.0, y), 0)) if abs(y) > y_half - 0.001 and z < top else V((0, 0, 1))
                ns.append(n if side < 0 else -n)
        m = len(prof)
        faces = []
        for i in range(nx):
            for j in range(m - 1):
                q = (i * m + j, (i + 1) * m + j, (i + 1) * m + j + 1, i * m + j + 1)
                faces.append(q if side < 0 else tuple(reversed(q)))
        D.add(verts, faces, MOSEN, normals=ns)
    return top + 0.006


def _sanbo(T, D, c, w=0.3, z0=0.0):
    """Sanbo : plateau a coins coupes et rebord, sur un pied carre perce de trois ouvertures (kurikata)."""
    cx, cy = c
    hb, hp = 0.1, 0.11                                   # hauteur du pied, demi-cote du pied
    box(T, (cx, cy, z0 + hb / 2), (2 * hp, 2 * hp, hb), HINOKI)
    # ouvertures : formes de joyau sombres, a peine en creux, sur l'avant et les cotes
    for (nx, ny) in ((0, -1), (-1, 0), (1, 0)):
        verts = []
        for k in range(16):
            a = 2 * math.pi * k / 16
            u = 0.062 * math.cos(a)
            v = 0.034 * math.sin(a) * (1.0 - 0.35 * math.cos(a) ** 2) + 0.004
            if nx == 0:
                verts.append((cx + u, cy + ny * (hp + 0.0008), z0 + hb * 0.5 + v))
            else:
                verts.append((cx + nx * (hp + 0.0008), cy + u, z0 + hb * 0.5 + v))
        nrm = V((nx, ny, 0))
        D.add([tuple(sum((V(p) for p in verts), V((0, 0, 0))) / len(verts))] + verts,
              [(0, 1 + (k + 1) % 16, 1 + k) if nx >= 0 and ny <= 0 and not (nx == 0 and ny == -1) else
               (0, 1 + k, 1 + (k + 1) % 16) for k in range(16)], LACQUER, normals=[nrm] * 17)
    # plateau octogonal (coins coupes), rebord
    zt = z0 + hb
    h = w / 2
    cut = 0.03
    oct_pts = [(h - cut, -h), (h, -h + cut), (h, h - cut), (h - cut, h), (-h + cut, h), (-h, h - cut), (-h, -h + cut),
               (-h + cut, -h)]
    def ring(scale, z):
        return [(cx + x * scale, cy + y * scale, z) for (x, y) in oct_pts]
    rings = [ring(1.0, zt), ring(1.0, zt + 0.035), ring(0.92, zt + 0.035), ring(0.92, zt + 0.012)]
    verts = [p for r in rings for p in r]
    faces = []
    for i in range(len(rings) - 1):
        for j in range(8):
            j2 = (j + 1) % 8
            faces.append((i * 8 + j, i * 8 + j2, (i + 1) * 8 + j2, (i + 1) * 8 + j))
    faces.append(tuple(range(7, -1, -1)))
    faces.append(tuple(range(24, 32)))
    T.add(verts, faces, HINOKI_LIGHT)
    # papier blanc plie pose dans le plateau (bord en dents de scie qui depasse un peu sur le devant)
    pz = zt + 0.0125
    pw = w * 0.42
    D.add([(cx - pw, cy - pw, pz), (cx + pw, cy - pw, pz), (cx + pw, cy + pw, pz), (cx - pw, cy + pw, pz)],
          [(0, 1, 2, 3)], WASHI, normals=[V((0, 0, 1))] * 4)
    return pz


def _sweep(T, pts, widths, ratio, color, up=(0, 0, 1), sides=8, cap=True):
    """Ruban epais : section en ellipse (largeur widths[i], epaisseur ratio * largeur) le long de pts.
    La largeur est orientee perpendiculairement a `up` (une feuille posee a plat, une meche qui pend)."""
    pts = [V(p) for p in pts]
    up = V(up)
    n = len(pts)
    verts = []
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(V((1, 0, 0)))
        side.normalize()
        nrm = side.cross(t).normalized()
        w = widths[i]
        for j in range(sides):
            a = 2 * math.pi * j / sides
            verts.append(pts[i] + side * (w * math.cos(a)) + nrm * (w * ratio * math.sin(a)))
    faces = []
    for i in range(n - 1):
        for j in range(sides):
            j2 = (j + 1) % sides
            faces.append((i * sides + j, i * sides + j2, (i + 1) * sides + j2, (i + 1) * sides + j))
    if cap:
        faces.append(tuple(range((n - 1) * sides, n * sides)))
        faces.append(tuple(reversed(range(0, sides))))
    cols = color if callable(color) else (lambda k: color)
    T.add(verts, faces, cols)


def _blob(T, c, radii, color_fn, nu=20, nv=12, shape=None):
    """Volume lisse en latitudes/longitudes : shape(u, v) -> facteur de rayon (u : tour, v : -1 bas -> 1 haut)."""
    cx, cy, cz = c
    verts = [(cx, cy, cz - radii[2] * (shape(0, -1) if shape else 1.0))]
    for j in range(1, nv):
        v = -1 + 2 * j / nv
        ph = math.asin(max(-1, min(1, v)))
        for i in range(nu):
            u = 2 * math.pi * i / nu
            k = shape(u, v) if shape else 1.0
            verts.append((cx + radii[0] * math.cos(ph) * math.cos(u) * k, cy + radii[1] * math.cos(ph) * math.sin(u) * k,
                          cz + radii[2] * math.sin(ph) * (k if v < 0 else 1.0)))
    top = len(verts)
    verts.append((cx, cy, cz + radii[2] * (shape(0, 1) if shape else 1.0)))
    faces, cols = [], []
    for i in range(nu):
        faces.append((0, 1 + (i + 1) % nu, 1 + i))
        cols.append(color_fn(-1.0))
    for j in range(nv - 2):
        for i in range(nu):
            i2 = (i + 1) % nu
            a0, b0 = 1 + j * nu, 1 + (j + 1) * nu
            faces.append((a0 + i, a0 + i2, b0 + i2, b0 + i))
            cols.append(color_fn(-1 + 2 * (j + 1.5) / nv))
    last = 1 + (nv - 2) * nu
    for i in range(nu):
        faces.append((last + i, last + (i + 1) % nu, top))
        cols.append(color_fn(1.0))
    T.add(verts, faces, lambda k: cols[k])


def _kaki(T, c, r=0.042, seed=0):
    """Kaki : fruit aplati et un peu carre (quatre lobes), haut creuse, calice de quatre sepales qui se relevent."""
    cx, cy, cz = c
    rot = seed * 0.9

    def shape(u, v):
        lobe = 1.0 + 0.06 * math.cos(4 * (u - rot))
        flat = 1.0 - 0.08 * max(0.0, v) ** 2
        return lobe * flat

    _blob(T, c, (r, r, r * 0.74), lambda v: KAKI_DARK if v > 0.75 else KAKI, nu=24, nv=12, shape=shape)
    zt = cz + r * 0.7
    for k in range(4):
        a = math.pi / 2 * k + rot + math.pi / 4
        d = V((math.cos(a), math.sin(a), 0))
        pts = [V((cx, cy, zt)) + d * (r * 0.5 * t) + V((0, 0, 0.012 * t * t + 0.002)) for t in (0.0, 0.35, 0.7, 1.0)]
        _sweep(T, pts, [r * 0.12, r * 0.26, r * 0.22, r * 0.05], 0.22, CALYX)
    _blob(T, (cx, cy, zt + 0.004), (r * 0.16, r * 0.16, r * 0.07), lambda v: CALYX, nu=10, nv=4)
    T.tube([(cx, cy, zt + 0.006), (cx + 0.002, cy, zt + 0.018)], [r * 0.07, r * 0.055], 6, CHESTNUT_DARK)


def _chestnut(T, c, yaw, s=1.0, seed=0):
    """Chataigne : ventre rond, une face plus plate, pointe effilee claire, large base mate plus claire."""
    cx, cy, cz = c
    ca, sa = math.cos(yaw), math.sin(yaw)

    def shape(u, v):
        point = 1.0 - 0.55 * max(0.0, (v - 0.2) / 0.8) ** 1.6
        flat = 1.0 - 0.18 * max(0.0, math.sin(u)) ** 2
        return point * flat

    verts_before = len(T.v)
    _blob(T, (0, 0, 0), (0.027 * s, 0.019 * s, 0.024 * s),
          lambda v: CHESTNUT_PALE if v < -0.55 else (CHESTNUT_DARK if v < -0.2 else CHESTNUT), nu=18, nv=10,
          shape=shape)
    for i in range(verts_before, len(T.v)):                 # oriente et place
        p = T.v[i]
        T.v[i] = V((cx + p.x * ca - p.y * sa, cy + p.x * sa + p.y * ca, cz + p.z))
    T.tube([(cx, cy, cz + 0.022 * s), (cx, cy, cz + 0.032 * s)], [0.004 * s, 0.0012 * s], 5, CHESTNUT_PALE)


def _susuki_stem(T, base, a, h, lean, seed):
    """Une tige de susuki : tige fine, longue feuille, plumet d'epillets qui retombe d'un cote."""
    rng = random.Random(seed)
    bx, by, bz = base
    pts = []
    for j in range(7):
        t = j / 6
        pts.append((bx + math.sin(a) * lean * t * t * 1.3, by - 0.03 * t * t, bz + h * t - 0.05 * t ** 3))
    T.tube(pts, [0.0055, 0.005, 0.0047, 0.0043, 0.004, 0.0035, 0.003], 4, SUSUKI_STEM)
    # plumet : meches soyeuses qui partent du sommet, s'ouvrent en eventail et retombent d'un cote
    tip = V(pts[-1])
    side = 1 if math.sin(a) >= 0 else -1
    silk = (lin("#D6C9A6"), lin("#C8B78F"), lin("#E0D5B8"))
    for g in range(13):
        ga = side * 0.45 + (g - 6) * 0.15 + rng.uniform(-0.07, 0.07)
        gy = rng.uniform(-0.35, 0.35)
        L = rng.uniform(0.09, 0.14)
        start = tip + V((0, 0, -0.006 * g))
        curve = [start + V((math.sin(ga) * L * t, gy * L * t, 0.03 * t - (0.07 + 0.05 * abs(math.sin(ga))) * t * t))
                 for t in [i / 6 for i in range(7)]]
        _sweep(T, curve, [0.002, 0.0045, 0.006, 0.006, 0.0055, 0.004, 0.0015], 0.6, silk[g % 3], up=(0, 1, 0),
               sides=5)
    la = a + rng.uniform(0.5, 0.9) * (1 if rng.random() < 0.5 else -1)
    T.tube([(bx, by, bz + 0.02), (bx + math.sin(la) * 0.14, by - 0.04, bz + 0.25),
            (bx + math.sin(la) * 0.3, by - 0.07, bz + 0.3), (bx + math.sin(la) * 0.38, by - 0.08, bz + 0.24)],
           [0.006, 0.005, 0.003, 0.0012], 3, SUSUKI_STEM)


def tsukimi_table():
    """Autel de Tsukimi : table basse d'hinoki couverte d'un tapis de feutre rouge (hi-mosen) qui retombe en plis ;
    sanbo (plateau d'offrande a coins coupes sur pied perce) portant une pyramide de 15 dango (9 + 4 + 2) ;
    vase a long col pour les susuki ; assiette laquee pour les kakis ; feuille de ho pour les chataignes ;
    paire de flacons de sake blancs et petit lapin de la lune (decor fixe).
    Offrandes en objets separes, montrees une par une par le jeu : dango, kaki_1..3, chataigne_1..3, susuki_1..3."""
    reset_scene()
    T = TM()
    D = TM()
    TW, TD, TH = 0.56, 0.3, 0.44
    # ---- table : plateau epais a chant arrondi, pieds, entretoises
    box(T, (0, 0, TH - 0.022), (TW * 2, TD * 2, 0.044), HINOKI)
    box(T, (0, 0, TH - 0.002), (TW * 2 - 0.012, TD * 2 - 0.012, 0.008), HINOKI_LIGHT)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(T, (sx * (TW - 0.07), sy * (TD - 0.06), (TH - 0.044) / 2), (0.06, 0.06, TH - 0.044), HINOKI_DARK)
        box(T, (sx * (TW - 0.07), 0, 0.07), (0.045, TD * 2 - 0.12, 0.045), HINOKI_DARK)
    for sy in (-1, 1):
        box(T, (0, sy * (TD - 0.06), TH - 0.08), (TW * 2 - 0.14, 0.035, 0.06), HINOKI_DARK)
    box(T, (0, 0, 0.07), (TW * 2 - 0.14, 0.04, 0.04), HINOKI_DARK)
    # ---- tapis rouge
    top = _mosen(D, TW * 0.58, TD, TH, 0.17)
    # ---- sanbo au centre, dango
    pz = _sanbo(T, D, (0.0, 0.02), w=0.3, z0=top)
    G = TM()
    r = 0.025
    k = 0
    for layer, (n, m) in enumerate(((3, 3), (2, 2), (2, 1))):
        for i in range(n):
            for j in range(m):
                x = (i - (n - 1) / 2) * r * 2.02
                y = (j - (m - 1) / 2) * r * 2.02
                _blob(G, (x, 0.02 + y, pz + r * 0.96 + layer * r * 1.5), (r, r, r * 0.95),
                      lambda v: lin("#E9E2D2") if v < -0.6 else DANGO, nu=16, nv=10)
                k += 1
    G.build("dango")
    # ---- vase a long col (gauche, en arriere) ; les tiges de susuki sont des objets a part
    vx, vy = -0.36, 0.1
    lathe(T, [(0.045, top), (0.06, top + 0.02), (0.075, top + 0.08), (0.07, top + 0.14), (0.045, top + 0.2),
              (0.026, top + 0.25), (0.024, top + 0.3), (0.034, top + 0.32), (0.026, top + 0.325), (0.0, top + 0.31)], 16,
          (vx, vy), lambda kk: GLAZE)
    lathe(T, [(0.0745, top + 0.09), (0.0705, top + 0.135), (0.0655, top + 0.15)], 16, (vx, vy),
          lambda kk: lin("#8E8270"))                                      # coulure de glacure claire
    for i, (a, h, lean) in enumerate(((-0.6, 0.42, 0.2), (0.12, 0.52, 0.1), (0.7, 0.4, 0.22))):
        S = TM()
        _susuki_stem(S, (vx + math.sin(a) * 0.008, vy, top + 0.3), a, h, lean, seed=11 + i)
        S.build("susuki_%d" % (i + 1))
    # ---- assiette laquee (droite, en avant) et kakis
    kx, ky = 0.33, -0.08
    lathe(T, [(0.0, top), (0.06, top), (0.085, top + 0.012), (0.1, top + 0.024), (0.094, top + 0.026),
              (0.078, top + 0.016), (0.0, top + 0.014)], 20, (kx, ky), lambda kk: LACQUER if kk < 3 else MOSEN_DARK)
    for i, c in enumerate(((kx - 0.038, ky - 0.015, top + 0.048), (kx + 0.038, ky + 0.01, top + 0.048),
                           (kx + 0.002, ky + 0.0, top + 0.103))):
        K = TM()
        _kaki(K, c, seed=i * 1.7)
        K.build("kaki_%d" % (i + 1))
    # ---- feuille de ho (droite, en arriere) et chataignes
    hx, hy = 0.36, 0.14
    leaf = []
    for k2 in range(13):
        t = k2 / 12
        w = 0.07 * math.sin(math.pi * t) ** 0.8
        leaf.append((t, w))
    lv = []
    for (t, w) in leaf:
        x = hx - 0.13 + 0.26 * t
        for sgn in (-1, 1):
            lv.append((x, hy + sgn * w, top + 0.003 + 0.01 * (abs(sgn * w) / 0.07) ** 2))
    lf = [(2 * k2, 2 * k2 + 2, 2 * k2 + 3, 2 * k2 + 1) for k2 in range(12)]
    D.add(lv, lf, LEAF_GREEN, normals=[V((0, 0, 1))] * len(lv))
    D.add([(hx - 0.13, hy, top + 0.0045), (hx + 0.13, hy, top + 0.0045), (hx + 0.13, hy + 0.003, top + 0.0045),
           (hx - 0.13, hy + 0.003, top + 0.0045)], [(0, 1, 2, 3)], lin("#55602C"), normals=[V((0, 0, 1))] * 4)
    for i, (dx, dy, yaw) in enumerate(((-0.05, -0.015, 0.3), (0.0, 0.02, -0.5), (0.055, -0.01, 1.2))):
        Cn = TM()
        _chestnut(Cn, (hx + dx * 1.2, hy + dy * 1.2, top + 0.032), yaw, s=1.3, seed=i)
        Cn.build("chataigne_%d" % (i + 1))
    # ---- decor fixe : flacons de sake (omiki) et lapin de la lune
    for sx in (-1, 1):
        x, y = sx * 0.17, 0.2
        lathe(T, [(0.0, top), (0.03, top), (0.042, top + 0.04), (0.04, top + 0.08), (0.016, top + 0.12),
                  (0.012, top + 0.15), (0.018, top + 0.16), (0.0, top + 0.158)], 14, (x, y),
              lambda kk: PORCELAIN_BLUE if kk == 3 else PORCELAIN)
    # lapin de la lune en porcelaine : couche, tete relevee, longues oreilles a interieur rose, yeux rouges
    bx, by = -0.2, -0.17
    _blob(T, (bx, by, top + 0.03), (0.046, 0.032, 0.03), lambda v: PORCELAIN, nu=18, nv=10,
          shape=lambda u, v: 1.0 + 0.12 * math.cos(u) * max(0.0, -v))
    _blob(T, (bx + 0.038, by, top + 0.058), (0.025, 0.022, 0.022), lambda v: PORCELAIN, nu=16, nv=10,
          shape=lambda u, v: 1.0 + 0.15 * max(0.0, math.cos(u)) * (1 - abs(v)))
    for sgn in (-1, 1):
        base = V((bx + 0.032, by + sgn * 0.008, top + 0.074))
        ear = [base + V((-0.012 * t * t - 0.004 * t, sgn * 0.006 * t, 0.045 * t)) for t in [i / 4 for i in range(5)]]
        _sweep(T, ear, [0.004, 0.008, 0.009, 0.007, 0.002], 0.4, PORCELAIN, up=(1, 0, 0), sides=6)
        _sweep(T, [p + V((0.0035, 0, 0)) for p in ear[1:]], [0.004, 0.005, 0.004, 0.001], 0.25, lin("#E8A8A4"),
               up=(1, 0, 0), sides=5)
        T.ico((bx + 0.053, by + sgn * 0.017, top + 0.063), (0.0045, 0.003, 0.005), lin("#C0392B"), subdiv=2,
              noise=0.0)
    T.ico((bx - 0.047, by, top + 0.035), (0.011, 0.011, 0.011), PORCELAIN, subdiv=2, noise=0.0)
    T.build("table")
    D.build("table_cloth", custom_normals=True)
    collision_box("table", (1.12, 0.6, 0.5), (0, 0, 0.25))
    finish_tree("tsukimi_table", expected_dims=(1.12, 0.65, 1.4), tri_limit=(400, 30000), trunk_angle=35, yaw=-25,
                pitch=18, margin=1.0, views=[("_close", dict(yaw=-12, pitch=22, margin=0.5))])


ALL = {"festival_board": festival_board, "lantern_pole": lantern_pole,
       "nobori": lambda: nobori("nobori", INDIGO, INDIGO_DARK, CREAM, 1),
       "nobori_red": lambda: nobori("nobori_red", BANNER_RED, BANNER_RED_DARK, CREAM, 2),
       "nobori_rolled": nobori_rolled, "tsukimi_table": tsukimi_table}
if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for a in args:
        ALL[a]()
