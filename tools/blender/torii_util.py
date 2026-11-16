"""Torii myojin refaits au propre (grand torii d'entree et petits torii des portes et des sentiers).

Pieces, de haut en bas (vocabulaire des charpentiers) :
- kasagi  : linteau superieur laque noir, courbe (sori) qui se releve aux extremites, bouts coupes en biais ;
- shimaki : second linteau rouge sous le kasagi, meme courbe en plus doux ;
- gakuzuka: court poteau central entre nuki et shimaki, qui porte la plaque (gaku) cote visiteurs ;
- nuki    : traverse droite qui passe a travers les piliers et depasse, calee par des coins noirs (kusabi) ;
- hashira : piliers ronds legerement coniques, penches vers l'interieur (uchikorobi), bague noire en haut (daiwa) ;
- kamaki  : manchon noir au pied des piliers ; daiishi : socle de pierre octogonal, moussu.
Un seul materiau : les couleurs sont portees par les sommets (voir tree_util), creux assombris par occlusion.
L'avant (cote plaque) est -Y dans Blender, soit +Z dans Godot : vers l'escalier et les visiteurs.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree_util import *

RED = lin("#CF4A2C")
RED_SHADE = lin("#B23E28")      # pied des piliers, salissures
RED_TOP = lin("#DA5B36")        # dessus des pieces, un peu passe au soleil
BLACK = lin("#29252B")
STONE = lin("#8F8B82")
STONE_DARK = lin("#6E6A62")
MOSS = lin("#667F3A")
GOLD = lin("#C9A148")
PLAQUE = lin("#2B2523")


def beam(T, prof, x0, x1, n, lift, color, slant=0.0, y0=0.0, z0=0.0):
    """Poutre : profil ferme [(y, z)] balaye le long de X de x0 a x1 ; lift(x) releve la section ;
    slant : les bouts sont coupes en biais (le haut depasse de `slant` m)."""
    zs = [z for _, z in prof]
    zlo, zhi = min(zs), max(zs)
    m = len(prof)
    verts = []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        end = -1 if i == 0 else (1 if i == n else 0)
        for (y, z) in prof:
            xx = x + end * slant * (z - zlo) / (zhi - zlo)
            verts.append((xx, y0 + y, z0 + z + lift(x)))
    faces = []
    for i in range(n):
        for j in range(m):
            j2 = (j + 1) % m
            faces.append((i * m + j, i * m + j2, (i + 1) * m + j2, (i + 1) * m + j))
    faces.append(tuple(reversed(range(m))))
    faces.append(tuple(range(n * m, (n + 1) * m)))
    cols = []
    for f in faces:
        c = color(V(verts[f[0]]), f) if callable(color) else color
        cols.append(c)
    return T.add(verts, faces, lambda k: cols[k])


def box(T, c, s, color):
    cx, cy, cz = c
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    v = [(cx + x * hx, cy + y * hy, cz + z * hz) for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return T.add(v, f, color)


def lathe(T, profile, sides, center, color, phase=0.0, noise=0.0, seed=0.0):
    """Solide de revolution : profile [(r, z)] de bas en haut ; r = 0 ferme."""
    cx, cy = center
    verts, rings = [], []
    for (r, z) in profile:
        if r <= 1e-6:
            verts.append((cx, cy, z))
            rings.append([len(verts) - 1])
            continue
        ring = []
        for j in range(sides):
            a = phase + 2 * math.pi * j / sides
            rr = r * (1 + noise * noise3(math.cos(a) * 2, math.sin(a) * 2, z * 3, seed))
            verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), z))
            ring.append(len(verts) - 1)
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for j in range(sides):
            j2 = (j + 1) % sides
            if len(a) == 1:
                faces.append((a[0], b[j2], b[j]))
            elif len(b) == 1:
                faces.append((a[j], a[j2], b[0]))
            else:
                faces.append((a[j], a[j2], b[j2], b[j]))
    if len(rings[0]) > 1:
        faces.append(tuple(reversed(rings[0])))
    return T.add(verts, faces, lambda k: color(k) if callable(color) else color)


def make_torii(px, nuki_z, shim_z, kasa_z, kasa_half, kasa_lift, r_foot, r_top, scale_d=1.0, plaque=True, seed=1,
               moss=True):
    """Construit le torii dans un seul objet « torii » (TM) et ses collisions de piliers.
    px : demi-ecartement des piliers au pied ; *_z : bas de chaque piece ; scale_d : epaisseur relative."""
    rng = random.Random(seed)
    T = TM()
    lean = 0.035 * (kasa_z / 3.0)          # inclinaison vers l'interieur (uchikorobi)
    top_z = shim_z                           # les piliers montent jusque sous le shimaki
    base_h = 0.3 * scale_d
    kam_h = 0.36 * scale_d

    def pillar_x(s, z):
        return s * (px - lean * (z / top_z))

    # ---------------------------------------------------------------- socles de pierre (daiishi)
    for s in (-1, 1):
        rb = r_foot * 1.65
        lathe(T, [(rb, 0.0), (rb * 1.02, 0.05 * scale_d), (rb * 0.94, base_h * 0.82), (rb * 0.8, base_h),
                  (0.0, base_h)], 8, (s * px, 0), lambda k: STONE if k < 16 else STONE_DARK if k < 8 else STONE,
              phase=0.2 * s + 0.39, noise=0.025, seed=s + seed)
        if moss:
            for k in range(rng.choice((3, 4))):
                a = rng.uniform(0, 6.28)
                rr = rb * rng.uniform(0.95, 1.05)
                T.ico((s * px + rr * math.cos(a), rr * math.sin(a), 0.045), (rng.uniform(0.07, 0.12) * scale_d,
                      rng.uniform(0.06, 0.1) * scale_d, 0.045 * scale_d), MOSS, subdiv=1, noise=0.15, seed=k + s * 3)

    # ---------------------------------------------------------------- piliers + manchons + bagues
    for s in (-1, 1):
        zs = [base_h, base_h + kam_h * 0.5, 0.9, 1.6, top_z * 0.62, top_z * 0.85, top_z + 0.04]
        pts = [(pillar_x(s, z), 0.0, z) for z in zs]
        rad = [r_foot + (r_top - r_foot) * (z - base_h) / (top_z - base_h) for z in zs]

        T.tube(pts, rad, 16, RED, cap_end=False)
        # kamaki : manchon noir au pied, bord haut arrondi
        kz = [base_h - 0.01, base_h + kam_h * 0.92, base_h + kam_h]
        kr = [r_foot * 1.07, r_foot * 1.07, r_foot * 1.02]
        T.tube([(pillar_x(s, z), 0.0, z) for z in kz], kr, 16, BLACK)
        # daiwa : bague noire en haut du pilier
        dz = [top_z - 0.13 * scale_d, top_z - 0.05 * scale_d, top_z]
        dr = [r_top * 1.06, r_top * 1.1, r_top * 1.08]
        T.tube([(pillar_x(s, z), 0.0, z) for z in dz], dr, 16, BLACK)

    # ---------------------------------------------------------------- nuki + coins
    nh, nd = 0.25 * scale_d, 0.17 * scale_d
    nx = px - lean * (nuki_z / top_z) + 0.42 * scale_d + r_foot
    nprof = [(-nd / 2, 0), (nd / 2, 0), (nd / 2, nh), (-nd / 2, nh)]
    beam(T, nprof, -nx, nx, 12, lambda x: 0.0, lambda p, f: RED_TOP if p.z > nuki_z + nh * 0.9 else RED, z0=nuki_z)
    for s in (-1, 1):
        xk = pillar_x(s, nuki_z) + s * (r_foot * 0.95 + 0.04 * scale_d)
        box(T, (xk, 0, nuki_z + nh / 2), (0.08 * scale_d, nd * 1.45, nh * 1.5), BLACK)

    # ---------------------------------------------------------------- gakuzuka + plaque
    gz0, gz1 = nuki_z + nh, shim_z
    box(T, (0, 0, (gz0 + gz1) / 2), (0.15 * scale_d, 0.13 * scale_d, gz1 - gz0), RED)
    if plaque:
        ph, pw = (gz1 - gz0) * 1.55, 0.44 * scale_d
        pz = (gz0 + gz1) / 2 + 0.03
        py = -0.1 * scale_d
        box(T, (0, py, pz), (pw, 0.06, ph), BLACK)                      # cadre
        box(T, (0, py - 0.035, pz), (pw * 0.78, 0.02, ph * 0.82), PLAQUE)  # champ
        box(T, (0, py - 0.032, pz), (pw * 0.84, 0.012, ph * 0.88), GOLD)   # filet dore
        # « 山王 » (Sanno, le roi de la montagne), en traits dores
        yy = py - 0.05
        st = ph * 0.03                                              # epaisseur d'un trait
        cz = pz + ph * 0.17                                         # 山
        box(T, (0, yy, cz + ph * 0.01), (st, 0.012, ph * 0.2), GOLD)
        box(T, (-pw * 0.16, yy, cz - ph * 0.03), (st, 0.012, ph * 0.12), GOLD)
        box(T, (pw * 0.16, yy, cz - ph * 0.03), (st, 0.012, ph * 0.12), GOLD)
        box(T, (0, yy, cz - ph * 0.09), (pw * 0.35, 0.012, st), GOLD)
        cz = pz - ph * 0.18                                         # 王
        for dz, w in ((0.08, 0.28), (0.0, 0.23), (-0.08, 0.34)):
            box(T, (0, yy, cz + ph * dz), (pw * w, 0.012, st), GOLD)
        box(T, (0, yy, cz), (st, 0.012, ph * 0.16), GOLD)

    # ---------------------------------------------------------------- shimaki (rouge) et kasagi (noir)
    sh, sd = 0.15 * scale_d, 0.3 * scale_d
    s_half = kasa_half * 0.9
    s_lift = lambda x: kasa_lift * 0.55 * (abs(x) / kasa_half) ** 2.3
    sprof = [(-sd / 2, 0), (sd / 2, 0), (sd / 2, sh), (-sd / 2, sh)]
    beam(T, sprof, -s_half, s_half, 22, s_lift, lambda p, f: RED, z0=shim_z, slant=0.04 * scale_d)
    kh, kd = 0.24 * scale_d, 0.42 * scale_d
    k_lift = lambda x: kasa_lift * (abs(x) / kasa_half) ** 2.3
    # profil : dessous plat, flancs droits, dessus en dos d'ane (le noir lit en volume)
    kprof = [(-kd / 2, 0), (kd / 2, 0), (kd / 2, kh * 0.62), (kd * 0.3, kh), (-kd * 0.3, kh), (-kd / 2, kh * 0.62)]
    beam(T, kprof, -kasa_half, kasa_half, 28, k_lift, BLACK, z0=kasa_z, slant=0.14 * scale_d)
    o = T.build("torii")
    # collisions : piliers seulement
    for s in (-1, 1):
        collision_box(f"pillar_{'l' if s < 0 else 'r'}", (r_foot * 2.6, r_foot * 2.6, top_z + 0.05),
                      (s * (px - lean * 0.5), 0, (top_z + 0.05) / 2))
    return o
