"""Cabane de l'ancien gardien : socle de pierre, murs en planches de bois sombre, toit a pignon en bardeaux,
engawa (porche) avec deux marches, porte coulissante `door` (objet separe, origine a son centre), fenetre a croisillons,
tuyau de cheminee. Avant = -Y, faitage le long de X.
Lancer : blender --background --python tools/blender/hut.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1
rng = random.Random(21)

# ------------------------------------------------------------------ gabarit
XW = 1.80                       # demi-largeur du corps (murs)
Y_F, Y_B = -0.35, 1.40          # faces exterieures des murs avant / arriere
Z_S = 0.30                      # dessus du socle
Z_D = 0.42                      # dessus du plancher de l'engawa
Z_EAVE, Z_RIDGE = 2.40, 3.08    # dessus moyen du toit : bord / faitage
Y_TIP_F, Y_TIP_B = -1.60, 1.75  # bords du toit
YC = (Y_TIP_F + Y_TIP_B) / 2
HALF = (Y_TIP_B - Y_TIP_F) / 2
X_ROOF = 2.22                   # demi-longueur du toit (debord de 0,42 sur les pignons)
POW = 0.9
H_STEP = 0.04                   # epaisseur visible d'un rang de bardeaux


def roof_top(y):
    u = min(abs(y - YC) / HALF, 1.0)
    return Z_EAVE + (Z_RIDGE - Z_EAVE) * (1 - u) ** POW


def roof_bot(y):
    u = min(abs(y - YC) / HALF, 1.0)
    return roof_top(y) - (0.30 - 0.04 * (1 - u))


def roof_slope(y):
    d = 0.01
    return (roof_top(y + d) - roof_top(y - d)) / (2 * d)


PARTS = []
add = PARTS.append

# ------------------------------------------------------------------ murs en planches (un seul mesh, multi-materiaux)
W = Mesh()


def plank(p, t, n, u0, u1, z0, z1, d, g, mat):
    """Planche = prisme a face avant plus etroite (V entre planches). p : point du mur a u=0 ; t tangent ;
    n normale sortante ; profondeur 0 = face exterieure."""
    prof = [(u0, -d), (u1, -d), (u1 - g, 0.0 + rng.uniform(-0.004, 0.004)), (u0 + g, 0.0 + rng.uniform(-0.004, 0.004))]
    sh = rng.uniform(-0.004, 0.004)
    verts = []
    for z in (z0, z1):
        for (u, dep) in prof:
            uu = u + (sh if z == z1 else 0.0)
            verts.append((p[0] + t[0] * uu + n[0] * dep, p[1] + t[1] * uu + n[1] * dep, z))
    faces = [(0, 1, 2, 3), (7, 6, 5, 4)]
    for i in range(4):
        j = (i + 1) % 4
        faces.append((i, j, 4 + j, 4 + i))
    W.add(verts, faces, mat)


def plank_mat():
    r = rng.random()
    return "wood_dark" if r < 0.74 else ("wood_faded" if r < 0.985 else "wood_light")


def wall(p, t, n, u_a, u_b, z0, top_fn, count, openings=()):
    pitch = (u_b - u_a) / count
    for i in range(count):
        ua, ub = u_a + i * pitch, u_a + (i + 1) * pitch
        top = top_fn(ua, ub)
        segs = [(z0 + rng.uniform(0.0, 0.03), top)]
        for (oa, ob, za, zb) in openings:
            if ua < ob - 1e-6 and ub > oa + 1e-6:
                new = []
                for (s0, s1) in segs:
                    if s0 < za:
                        new.append((s0, min(s1, za)))
                    if s1 > zb:
                        new.append((max(s0, zb), s1))
                segs = new
        m = plank_mat()
        for (s0, s1) in segs:
            if s1 - s0 > 0.02:
                plank(p, t, n, ua, ub, s0, s1, 0.10, 0.016, m)


DOOR_W2 = 0.60           # demi-ouverture de la porte
Z_DOOR_T = 2.24          # haut de l'ouverture
WIN = (-1.60, -1.00, 1.15, 2.00)     # fenetre : x0, x1, z0, z1

front_top = lambda a, b: roof_bot(Y_F) + 0.05
back_top = lambda a, b: roof_bot(Y_B) + 0.05
side_top = lambda a, b: max(roof_bot(a), roof_bot(b), roof_bot(YC) if a < YC < b else -9) + 0.05

wall((0, Y_F), (1, 0), (0, -1), -XW, XW, Z_S, front_top, 18,
     openings=[(-DOOR_W2, DOOR_W2, 0.0, Z_DOOR_T + 0.02), (WIN[0], WIN[1], WIN[2], WIN[3])])
wall((0, Y_B), (1, 0), (0, 1), -XW, XW, Z_S, back_top, 18)
wall((-XW, 0), (0, 1), (-1, 0), Y_F, Y_B, Z_S, side_top, 9)
wall((XW, 0), (0, 1), (1, 0), Y_F, Y_B, Z_S, side_top, 9)
walls = W.build("walls")

# noyau sombre derriere (ferme la cabane, visible quand la porte coulisse)
add(bx("core", (3.55, 1.72, 2.2), (0, (Y_F + Y_B) / 2 + 0.01, 0.30 + 1.1), "lacquer_black", bevel=0))

# ------------------------------------------------------------------ socle de pierre
add(bx("socle_core", (3.76, 2.58, 0.29), (0, 0.13, 0.145), "stone_dark", bevel=0))


def stone_row(name, fixed, lo, hi, axis, depth, seed, mats=("stone", "stone", "stone_dark"), wr=(0.62, 0.98)):
    r = random.Random(seed)
    pos = lo
    k = 0
    while pos < hi - 0.05:
        w = r.uniform(*wr)
        if hi - (pos + w) < 0.4:
            w = hi - pos
        h = r.uniform(0.255, 0.30)
        c = pos + w / 2
        m = r.choice(mats)
        sz = (w - 0.03, depth, h) if axis == "x" else (depth, w - 0.03, h)
        loc = (c, fixed, h / 2) if axis == "x" else (fixed, c, h / 2)
        o = bx(f"{name}_{k}", sz, loc, m, bevel=0.05, seg=1)
        jitter(o, 0.01, seed + k)
        add(o)
        pos += w
        k += 1


stone_row("sf", -1.10, -1.93, 1.93, "x", 0.30, 100)       # face avant du socle (sous le porche)
stone_row("sb", 1.35, -1.93, 1.93, "x", 0.30, 200, wr=(1.0, 1.4))        # arriere
stone_row("sl", -1.78, -0.95, 1.20, "y", 0.30, 300, wr=(0.95, 1.3))       # cotes
stone_row("sr", 1.78, -0.95, 1.20, "y", 0.30, 400, wr=(0.95, 1.3))

# ------------------------------------------------------------------ engawa : plancher, marches, poteaux, poutre
add(bx("deck_frame", (3.8, 0.90, 0.06), (0, -0.80, Z_S + 0.03), "wood_dark", bevel=0))
for i in range(6):
    y = -1.25 + 0.145 * (i + 0.5) + 0.005 * i
    m = ["wood_faded", "wood_light", "wood_faded", "wood_faded", "wood_light", "wood_faded"][i]
    add(bx(f"deck_{i}", (3.78, 0.14, 0.07), (0, y, Z_D - 0.035), m, bevel=0.012))
add(bx("sill", (1.40, 0.10, 0.05), (0, Y_F - 0.02, Z_D + 0.01), "wood_dark", bevel=0.01))

# marches de bois (deux) : corps sombre + giron use
add(bx("step_2_body", (1.50, 0.26, 0.25), (0, -1.355, 0.125), "wood_dark", bevel=0.02))
add(bx("step_2", (1.58, 0.31, 0.06), (0, -1.375, 0.25), "wood_light", bevel=0.02))
add(bx("step_1_body", (1.60, 0.25, 0.11), (0, -1.62, 0.055), "wood_dark", bevel=0.02))
add(bx("step_1", (1.68, 0.30, 0.06), (0, -1.64, 0.11), "wood_faded", bevel=0.02))
for sx in (-1, 1):                  # pierres de calage de part et d'autre
    add(bx(f"step_stone_{sx}", (0.34, 0.5, 0.2), (sx * 1.02, -1.5, 0.10), "stone", bevel=0.04))

# poteaux du porche + poutre
PY = -0.95
for sx in (-1, 1):
    add(bx(f"post_{sx}", (0.20, 0.20, 1.72), (sx * 1.65, PY, 0.52 + 0.86), "wood_dark", bevel=0.04))
    add(bx(f"post_foot_{sx}", (0.36, 0.36, 0.11), (sx * 1.65, PY, Z_D + 0.055), "stone", bevel=0.035))
    # aisselier (jambe de force) vers la poutre
    add(bx(f"brace_{sx}", (0.09, 0.09, 0.56), (sx * 1.40, PY, 2.00), "wood_dark", rot=(0, -sx * 0.8, 0), bevel=0.02))
bz = roof_bot(PY) - 0.12
add(bx("porch_beam", (4.00, 0.22, 0.22), (0, PY, 2.30), "wood_dark", bevel=0.04))
# ------------------------------------------------------------------ ossature du corps
ztop = lambda y: roof_bot(y) + 0.04
for sx in (-1, 1):
    for yy, nm in ((Y_F + 0.07, "f"), (Y_B - 0.07, "b")):
        zt = ztop(yy)
        add(bx(f"corner_{nm}_{sx}", (0.20, 0.20, zt - Z_S), (sx * (XW - 0.07), yy, Z_S + (zt - Z_S) / 2),
               "wood_dark", bevel=0.035))
add(bx("girt_front", (3.74, 0.07, 0.11), (0, Y_F - 0.015, 0.95), "wood_dark", bevel=0))
add(bx("girt_back", (3.74, 0.07, 0.11), (0, Y_B + 0.015, 0.95), "wood_dark", bevel=0))
for sx in (-1, 1):
    add(bx(f"girt_side_{sx}", (0.07, 1.78, 0.11), (sx * (XW + 0.015), (Y_F + Y_B) / 2, 0.95), "wood_dark", bevel=0))

# encadrement de la porte : montants, linteau
for sx in (-1, 1):
    add(bx(f"jamb_{sx}", (0.10, 0.10, Z_DOOR_T - Z_D + 0.04), (sx * (DOOR_W2 + 0.03), Y_F - 0.005, (Z_DOOR_T + Z_D) / 2),
           "wood_dark", bevel=0.02))
add(bx("lintel", (1.62, 0.12, 0.17), (0, Y_F - 0.01, Z_DOOR_T + 0.07), "wood_dark", bevel=0.03))
add(bx("door_rail", (1.30, 0.04, 0.03), (0, Y_F - 0.052, Z_D + 0.005), "lacquer_black", bevel=0))

# fenetre a croisillons
wx0, wx1, wz0, wz1 = WIN
wcx, wcz = (wx0 + wx1) / 2, (wz0 + wz1) / 2
ww, wh = wx1 - wx0, wz1 - wz0
WY = Y_F - 0.01
add(bx("win_paper", (ww, 0.03, wh), (wcx, Y_F + 0.04, wcz), "paper", bevel=0))
for sx in (-1, 1):
    add(bx(f"win_jamb_{sx}", (0.075, 0.08, wh + 0.14), (wcx + sx * (ww / 2 + 0.005), WY, wcz), "wood_light", bevel=0.015))
for sz in (-1, 1):
    add(bx(f"win_rail_{sz}", (ww + 0.15, 0.08, 0.075), (wcx, WY, wcz + sz * (wh / 2 + 0.005)), "wood_light", bevel=0))
add(bx("win_sill", (ww + 0.24, 0.15, 0.05), (wcx, Y_F - 0.07, wz0 - 0.085), "wood_faded", bevel=0.015))
add(bx("win_bar_v", (0.032, 0.045, wh), (wcx, Y_F - 0.03, wcz), "wood_light", bevel=0))
for dz in (-0.14, 0.14):
    add(bx(f"win_bar_h_{dz}", (ww, 0.045, 0.032), (wcx, Y_F - 0.03, wcz + dz), "wood_light", bevel=0))
# ------------------------------------------------------------------ toit : profil en gradins de bardeaux, extrude le long de X
def build_roof():
    R = Mesh()
    n = 8
    top = []
    for k in range(n):
        y0 = Y_TIP_F + (YC - Y_TIP_F) * k / n
        y1 = Y_TIP_F + (YC - Y_TIP_F) * (k + 1) / n
        c = 0.02 if k < n - 1 else 0.0
        top.append((y0, roof_top(y0)))
        top.append((y1 - c, roof_top(y1 - c) - (H_STEP if k < n - 1 else 0.012)))
    mirror = [(2 * YC - y, z) for (y, z) in reversed(top)]
    top += mirror[1:]
    under = []
    for i in range(7):
        y = Y_TIP_B - (Y_TIP_B - Y_TIP_F) * i / 6
        under.append((y, roof_bot(y)))
    prof = top + under
    NP = len(prof)
    nx = 6
    xs = [-X_ROOF + 2 * X_ROOF * i / (nx - 1) for i in range(nx)]
    verts = []
    for i, x in enumerate(xs):
        for j, (y, z) in enumerate(prof):
            edge = i in (0, nx - 1)
            jy = 0.0 if j >= len(top) else rng.uniform(-0.01, 0.01)
            jz = 0.0 if j >= len(top) else rng.uniform(-0.006, 0.006)
            verts.append((x, y + jy, z + jz))
    ntop = len(top)
    for i in range(nx - 1):
        for j in range(NP):
            j2 = (j + 1) % NP
            a, b = i * NP + j, i * NP + j2
            q = (a, b, b + NP, a + NP)
            if j < ntop - 1:
                dy = abs(prof[j + 1][0] - prof[j][0])
                if dy < 0.04:
                    m = "shingle_dark"
                else:
                    r = rng.random()
                    m = "shingle" if r < 0.66 else ("shingle_light" if r < 0.88 else "shingle_dark")
            elif j == ntop - 1 or j == NP - 1:
                m = "shingle_dark"          # tranche des bords de toit
            else:
                m = "wood_dark"             # sous-face
            R.add([verts[k] for k in q], [(0, 1, 2, 3)], m)
    # pignons (tranches du toit)
    for i, rev in ((0, True), (nx - 1, False)):
        idx = [i * NP + j for j in range(NP)]
        if rev:
            idx = idx[::-1]
        R.add([verts[k] for k in idx], [tuple(range(NP))], "wood_dark")
    return R.build("roof_slab")


roof = build_roof()

# faitage de chaume : tube aux extremites arrondies + ligatures de corde
def ridge_cap():
    R = Mesh()
    cz = Z_RIDGE - 0.035
    L = 2.27
    items = [(-L, 0.18, 0), (-L + 0.04, 0.75, 0), (-L + 0.13, 1.0, 0)]
    bands = [-1.55, -0.78, 0.0, 0.78, 1.55]
    last = -L + 0.13
    for xb in bands:
        mid = (last + xb - 0.035) / 2
        items.append((mid, 1.0, 0))
        items.append((xb - 0.035, 1.09, 1))
        items.append((xb + 0.035, 1.09, 2))
        last = xb + 0.035
    items.append(((last + L - 0.13) / 2, 1.0, 0))
    items += [(L - 0.13, 1.0, 0), (L - 0.04, 0.75, 0), (L, 0.18, 0)]
    rings = []
    NS = 8
    for (x, k, fl) in items:
        ring = []
        for j in range(NS):
            a = 2 * math.pi * j / NS
            ry = 0.27 * k * (1.0 + 0.04 * math.sin(x * 5.0))
            rz = 0.155 * k
            ring.append((x, YC + ry * math.cos(a), cz + rz * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.55)))
        rings.append(ring)
    flags = [it[2] for it in items]
    R.loft(rings, lambda i, j: "rope" if (flags[i] == 1 and flags[i + 1] == 2) else "thatch")
    return R.build("ridge")


ridge = ridge_cap()


def barge_board(sx):
    """Planche de rive en bois sombre qui habille le bord des pignons (cache les gradins)."""
    B = Mesh()
    ys = [Y_TIP_F + (Y_TIP_B - Y_TIP_F) * i / 8 for i in range(9)]
    ring = [(y, roof_top(y) + 0.015) for y in ys] + [(y, roof_bot(y) - 0.005) for y in reversed(ys)]
    n = len(ring)
    xa, xb = (X_ROOF - 0.02, X_ROOF + 0.05) if sx > 0 else (-X_ROOF - 0.05, -X_ROOF + 0.02)
    v = [(xa, y, z) for (y, z) in ring] + [(xb, y, z) for (y, z) in ring]
    f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, n + j, n + i))
    B.add(v, f, "wood_dark")
    return B.build(f"barge_{sx}", bevel=0.012)


barges = [barge_board(-1), barge_board(1)]

# mousse et pierres de lestage sur le toit (toit de planchettes lestees : usage de montagne)
mos = []
for k, (x, y, rx, ry) in enumerate([(-1.5, 0.95, 0.30, 0.16), (0.4, 1.45, 0.34, 0.17), (-1.9, -1.1, 0.22, 0.12)]):
    a = math.atan(roof_slope(y))
    mos.append(moss(f"moss_roof_{k}", (x, y, roof_top(y) - 0.02), rx, ry, 0.035, rot=(a, 0, 0), seg=7, rings=3))
mos.append(sphere("moss_ridge", 1.0, (-1.2, YC, Z_RIDGE + 0.1), "moss", scale=(0.4, 0.14, 0.05), seg=7, rings=3))
for k, (x, y, sc, m, yaw) in enumerate([(-1.45, -1.12, 1.0, "stone", 0.3), (0.55, -0.95, 0.85, "stone_dark", 1.1),
                                       (1.65, -1.25, 0.9, "stone", 2.0), (-0.7, 1.15, 1.0, "stone_dark", 0.7),
                                       (0.9, 1.55, 0.85, "stone", 2.4), (1.75, 0.65, 0.9, "stone_dark", 1.7)]):
    a = math.atan(roof_slope(y))
    st = sphere(f"roof_stone_{k}", 1.0, (x, y, roof_top(y) + 0.0), m, scale=(0.20 * sc, 0.145 * sc, 0.085 * sc), seg=8, rings=3)
    st.rotation_euler = (a, 0, yaw)
    mos.append(st)

# ------------------------------------------------------------------ tuyau de cheminee (toit arriere)
CX, CY = 0.95, 1.12
cz0 = roof_top(CY) - 0.12
a_b = math.atan(roof_slope(CY))
add(bx("chimney_flash", (0.34, 0.34, 0.07), (CX, CY, roof_top(CY) - 0.01), "stone_dark", rot=(a_b, 0, 0), bevel=0.02))
top_z = 3.17
add(cyl("chimney_pipe", 0.085, top_z - cz0, (CX, CY, (top_z + cz0) / 2), "iron", verts=8, bevel=0, r2=0.078))
add(cyl("chimney_band", 0.095, 0.05, (CX, CY, roof_top(CY) + 0.14), "rust", verts=8, bevel=0))
add(cyl("chimney_cap", 0.15, 0.07, (CX, CY, top_z - 0.02), "iron", verts=8, bevel=0, r2=0.07))
add(cyl("chimney_rust", 0.088, 0.08, (CX, CY, top_z - 0.15), "rust", verts=8, bevel=0))

# ------------------------------------------------------------------ mousse au sol et sur la pierre
for k, (x, y, rr) in enumerate([(-1.92, -1.12, 0.17), (1.40, -1.14, 0.16), (-1.95, 0.4, 0.15), (1.95, -0.5, 0.17),
                                (0.7, 1.40, 0.18)]):
    add(moss(f"moss_base_{k}", (x, y, 0.075), rr * 1.3, rr, 0.07, seg=7, rings=3))
add(moss("moss_step", (0.55, -1.64, 0.14), 0.12, 0.08, 0.025, seg=7, rings=3))

# ------------------------------------------------------------------ porte coulissante (objet separe)
DC = (0.0, Y_F - 0.065, (Z_DOOR_T + Z_D + 0.02) / 2)
DW, DH = 1.34, Z_DOOR_T - Z_D - 0.02
D = []
dpos = lambda rx, rz: (DC[0] + rx, DC[1], DC[2] + rz)
for sx in (-1, 1):
    D.append(bx(f"door_stile_{sx}", (0.09, 0.05, DH), dpos(sx * (DW / 2 - 0.045), 0), "wood_light", bevel=0.012))
rails = [(-DH / 2 + 0.05, 0.10), (-DH / 2 + 0.47, 0.07), (DH / 2 - 0.045, 0.09)]
for k, (rz, rh) in enumerate(rails):
    D.append(bx(f"door_rail_{k}", (DW - 0.14, 0.05, rh), dpos(0, rz), "wood_light", bevel=0.012))
kick_h = 0.47 - 0.10 - 0.035 - 0.05
D.append(bx("door_kick", (DW - 0.14, 0.03, kick_h), dpos(0, -DH / 2 + 0.10 + 0.05 + kick_h / 2 + 0.0), "wood_faded", bevel=0))
pz0, pz1 = -DH / 2 + 0.47 + 0.035, DH / 2 - 0.09
D.append(bx("door_paper", (DW - 0.14, 0.02, pz1 - pz0), dpos(0, (pz0 + pz1) / 2), "paper", bevel=0))
for k, rx in enumerate((-0.2, 0.2)):
    D.append(bx(f"door_bar_v_{k}", (0.026, 0.035, pz1 - pz0), dpos(rx, (pz0 + pz1) / 2), "wood_light", bevel=0))
for k in range(3):
    rz = pz0 + (pz1 - pz0) * (k + 1) / 4
    D.append(bx(f"door_bar_h_{k}", (DW - 0.14, 0.035, 0.026), dpos(0, rz), "wood_light", bevel=0))
D.append(cyl("door_pull", 0.035, 0.012, (DC[0] + 0.50, DC[1] - 0.03, DC[2] - 0.15), "lacquer_black", rot=(math.pi / 2, 0, 0), verts=10, bevel=0.003))
door = merge(D, "door", origin=DC)

# ------------------------------------------------------------------ assemblage de la partie statique
import collections
_c = collections.Counter()
for _o in PARTS + mos + [walls, roof, ridge]:
    _c[_o.name.rstrip("0123456789_-").split("_")[0] if _o.name not in ("walls", "roof_slab", "ridge") else _o.name] += tri_count(_o)
print("TRIS_BY_GROUP", dict(_c))
hut = merge([walls, roof, ridge] + barges + PARTS + mos, "hut", origin=(0, 0, 0))

# ------------------------------------------------------------------ collisions
collision_box("hut_body", (3.76, 1.88, 2.7), (0, 0.56, 1.35))
collision_box("hut_porch", (3.80, 0.92, Z_D), (0, -0.82, Z_D / 2))
collision_box("hut_step_2", (1.57, 0.28, 0.28), (0, -1.36, 0.14))
collision_box("hut_step_1", (1.67, 0.27, 0.14), (0, -1.62, 0.07))
for sx in (-1, 1):
    collision_box(f"hut_post_{sx}", (0.24, 0.24, 1.9), (sx * 1.65, PY, 0.42 + 0.95))

pfinish("hut", expected_dims=(4.5, 3.5, 3.2), tri_limit=(1500, 5000),
        angles={"hut": math.radians(48), "door": math.radians(48)},
        yaw=33, pitch=17, margin=1.05,
        extra_views=[("_b", dict(yaw=150, pitch=20, margin=1.05)), ("_door", dict(yaw=8, pitch=8, margin=0.6))])
