"""Haie taillee japonaise (karikomi) de la cour : 4 m de long, ~1 m de haut, ~0,9 m d'epaisseur.

Deux couches :
- « foliage » : la masse taillee, une surface lisse en boite aux aretes tres arrondies, a peine ondulee
  (taillee a la main). Couleur sombre : elle fait l'ombre entre les feuilles.
- « leaves » : des rosettes de vraies petites feuilles pliees le long de la nervure, couchees sur la masse
  et legerement soulevees. Elles donnent la matiere de pres et une frange feuillue a la silhouette.
  Couleur par rosette (jamais par face) : plus claires dessus, plus sombres vers le pied ; deux ou trois
  branches d'azalee (tsutsuji) qui rougissent, l'automne gagne la haie par endroits.
- « stems » : tiges nues au pied, la ou la masse rentre.
Deux variantes (graines differentes) : hedge_a, hedge_b. Collision : boite « hedge-col ».
Aussi « hedge_sprig » : le rameau qui a pousse dans la nuit et depasse de la haie (tache de la cisaille).
Touffe de jeunes pousses vert tendre qui depasse d'une vingtaine de cm. Le long de +Z, 0,20 m,
origine a la base ; le jeu l'oriente et l'etire selon la longueur voulue.
Lancer : blender --background --python tools/blender/hedge.py [-- a b sprig]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *

PALETTE.update({
    "hedge_core":  "#2B3F25",   # masse : l'ombre sous les feuilles
    "hedge_deep":  "#3D5730",
    "hedge_mid":   "#4F6E37",
    "hedge_light": "#68873F",
    "hedge_sun":   "#82A04A",
    "hedge_rust":  "#A3522F",
    "hedge_amber": "#BD7A35",
    "sprig_leaf":  "#93B256",   # pousse de la nuit : plus tendre que la haie
    "sprig_leaf2": "#A9C462",
    "sprig_bark":  "#7A6A3E",   # bois vert-brun de l'annee
})

A, B, C = 1.93, 0.41, 0.475      # demi-dimensions de la boite (x long, y epaisseur, z hauteur)
ZC = 0.475                       # centre en hauteur
R = 0.17                         # aretes arrondies, mais dessus plat et flancs droits : une haie taillee
NX, NY, NZ = 34, 8, 9            # la masse est lisse : peu de faces suffisent


class Shape:
    def __init__(self, rng):
        self.ph = [rng.uniform(0, 6.283) for _ in range(6)]

    def wave(self, p):
        """Ondulation lente : la cisaille du jardinier n'est pas une regle."""
        ph = self.ph
        return (0.020 * math.sin(p.x * 1.6 + ph[0]) * math.cos(p.y * 2.0 + ph[1])
                + 0.014 * math.sin(p.x * 3.3 + ph[2] + p.z * 2.0)
                + 0.010 * math.sin(p.z * 4.0 + ph[3] + p.x * 0.8))

    def point(self, cx, cy, cz):
        """Point de la boite unite -> (point, normale) sur la masse."""
        P = Vector((cx * A, cy * B, cz * C))
        inner = Vector((A - R, B - R, C - R))
        Q = Vector((max(-inner.x, min(inner.x, P.x)), max(-inner.y, min(inner.y, P.y)),
                    max(-inner.z, min(inner.z, P.z))))
        d = P - Q
        n = d.normalized() if d.length > 1e-9 else Vector((0, 0, 1))
        p = Q + n * R
        p.y *= 1.0 + 0.04 * math.cos(p.x / A * math.pi * 0.5)       # flancs un peu bombes au milieu
        p = p + n * self.wave(p)
        p.z += ZC
        if p.z < 0.20:                                                # le pied rentre
            k = p.z / 0.20
            p.y *= 0.84 + 0.16 * k
        return p, n


def leaf(M, base, n, direction, length, width, m, lift):
    """Feuille pliee en V le long de la nervure : 4 sommets, 2 triangles. n = normale de la masse."""
    d = (direction - n * direction.dot(n)).normalized()
    d = (d * math.cos(lift) + n * math.sin(lift)).normalized()     # la feuille se souleve de la masse
    side = n.cross(d).normalized()
    up = d.cross(side).normalized()
    tip = base + d * length
    mid = base + d * (length * 0.42)
    fold = width * 0.18
    l = mid + side * (width * 0.5) - up * fold
    r = mid - side * (width * 0.5) - up * fold
    o = len(M.v)
    M.v += [tuple(base), tuple(l), tuple(tip), tuple(r)]
    M.f += [(o, o + 1, o + 2), (o, o + 2, o + 3)]
    M.fm += [M._mi(m), M._mi(m)]


def build(variant, seed):
    reset_scene()
    rng = random.Random(seed)
    sh = Shape(rng)

    # ---------------------------------------------------------------- masse (grille sur la boite unite, bas ouvert)
    keys, verts = {}, []

    def vid(ix, iy, iz):
        k = (ix, iy, iz)
        if k not in keys:
            keys[k] = len(verts)
            verts.append(sh.point(ix / NX * 2 - 1, iy / NY * 2 - 1, iz / NZ * 2 - 1)[0])
        return keys[k]

    F = Mesh()
    quads = []
    for i in range(NX):
        for j in range(NY):
            quads.append((vid(i, j, NZ), vid(i + 1, j, NZ), vid(i + 1, j + 1, NZ), vid(i, j + 1, NZ)))
    for i in range(NX):
        for k in range(NZ):
            quads.append((vid(i, 0, k), vid(i + 1, 0, k), vid(i + 1, 0, k + 1), vid(i, 0, k + 1)))
            quads.append((vid(i, NY, k + 1), vid(i + 1, NY, k + 1), vid(i + 1, NY, k), vid(i, NY, k)))
    for j in range(NY):
        for k in range(NZ):
            quads.append((vid(0, j, k + 1), vid(0, j + 1, k + 1), vid(0, j + 1, k), vid(0, j, k)))
            quads.append((vid(NX, j, k), vid(NX, j + 1, k), vid(NX, j + 1, k + 1), vid(NX, j, k + 1)))
    F.v = [tuple(p) for p in verts]
    for q in quads:
        F.f.append(q)
        F.fm.append(F._mi("hedge_core"))
    F.build("foliage")

    # ---------------------------------------------------------------- feuilles
    # couverture reguliere (grille jitteree sur chaque face de la boite unite), comme un buis taille serre.
    # La couleur suit un champ doux (hauteur + lumiere + bruit lent) : on lit des plaques de touffes,
    # pas un semis de confettis.
    rust_spots = []
    for _ in range(rng.choice((2, 3))):
        cx = rng.uniform(-A * 0.8, A * 0.8)
        rust_spots.append((Vector((cx, rng.choice((-1, 1)) * B, ZC + rng.uniform(0.05, 0.32))),
                           rng.uniform(0.20, 0.30)))
    nph = [rng.uniform(0, 6.283) for _ in range(4)]

    def field(p, n):
        h = max(0.0, min(1.0, (p.z - 0.08) / 0.92))
        nz = (math.sin(p.x * 3.1 + nph[0]) * math.cos(p.y * 4.0 + p.z * 2.3 + nph[1])
              + 0.6 * math.sin(p.x * 6.7 + p.z * 4.1 + nph[2])) / 1.6
        return 0.60 * h + 0.12 * max(0.0, n.z) + 0.28 * nz

    TONES = [(0.22, "hedge_deep"), (0.48, "hedge_mid"), (0.70, "hedge_light"), (9.0, "hedge_sun")]
    UP = Vector((0, 0, 1))
    SP = 0.068                                   # pas entre feuilles
    faces_u = [  # (nombre en u, nombre en v, fonction (u, v) -> coordonnees boite unite)
        (int(2 * A / SP), int(2 * B / SP), lambda u, v: (u, v, 1.0)),
        (int(2 * A / SP), int(2 * C / SP), lambda u, v: (u, -1.0, v)),
        (int(2 * A / SP), int(2 * C / SP), lambda u, v: (u, 1.0, v)),
        (int(2 * B / SP), int(2 * C / SP), lambda u, v: (-1.0, u, v)),
        (int(2 * B / SP), int(2 * C / SP), lambda u, v: (1.0, u, v)),
    ]
    L = Mesh()
    for nu, nv, fmap in faces_u:
        for iu in range(nu):
            for iv in range(nv):
                u = -1 + 2 * (iu + rng.uniform(0.1, 0.9)) / nu
                v = -1 + 2 * (iv + rng.uniform(0.1, 0.9)) / nv
                p, n = sh.point(*fmap(u, v))
                if p.z < 0.07:
                    continue
                f = field(p, n) + rng.uniform(-0.09, 0.09)
                m = next(t for lim, t in TONES if f < lim)
                for sp, sr in rust_spots:
                    dist = (p - sp).length
                    if dist < sr and rng.random() < 1.2 - dist / sr:
                        m = "hedge_rust" if rng.random() < 0.6 else "hedge_amber"
                # les feuilles pointent vers le haut sur les flancs, au hasard sur le dessus
                d = UP - n * UP.dot(n)
                if d.length < 0.3:
                    a = rng.uniform(0, 6.283)
                    d = Vector((math.cos(a), math.sin(a), 0.0))
                d.normalize()
                side = n.cross(d)
                a = math.radians(rng.uniform(-55, 55))
                d = d * math.cos(a) + side * math.sin(a)
                size = rng.uniform(0.88, 1.12) * (0.9 if p.z < 0.25 else 1.0)
                leaf(L, p - n * 0.006 - d * 0.03, n, d, 0.105 * size, 0.064 * size, m,
                     math.radians(rng.uniform(6, 18)))
    L.build("leaves")

    # ---------------------------------------------------------------- tiges nues au pied
    S = Mesh()
    for k in range(11):
        x = -A * 0.9 + 2 * A * 0.9 * (k + rng.uniform(0.2, 0.8)) / 11
        y = rng.uniform(-0.17, 0.17)
        lean = Vector((rng.uniform(-0.08, 0.08), rng.uniform(-0.12, 0.12), 1.0)).normalized()
        base = Vector((x, y, 0.0))
        S.tube([base, base + lean * 0.13 + Vector((0, 0, 0.01)), base + lean * 0.30],
               [0.020, 0.016, 0.011], 5, "wood_dark", caps=True)
        side = 1.0 if y > 0 else -1.0
        b0 = base + lean * 0.09
        S.tube([b0, b0 + Vector((rng.uniform(-0.05, 0.05), side * 0.13, 0.11))], [0.010, 0.006], 4,
               "wood_dark", caps=True)
    S.build("stems")

    collision_box("hedge", (2 * A + 0.1, 2 * B + 0.12, 1.04), loc=(0, 0, 0.52))

    return pfinish("hedge_" + variant, expected_dims=(4.0, 0.9, 1.04), tri_limit=(1500, 9000),
                   angles={"foliage": math.radians(80), "leaves": math.radians(8), "stems": math.radians(60)},
                   yaw=28, pitch=20, margin=1.05,
                   extra_views=[("_close", dict(yaw=12, pitch=14, margin=0.42))])


def build_sprig():
    """Touffe de pousses de la nuit : 4 jeunes pousses serrees qui partent d'un meme point, tres feuillues,
    qui depassent d'une vingtaine de centimetres. Le long de +Z, hauteur nominale 0,20 m."""
    reset_scene()
    rng = random.Random(5)
    H = 0.20

    S = Mesh()
    L = Mesh()

    def leaf_at(p, d, size, m):
        n = Vector((0, 0, 1)) - d * d.z
        if n.length < 0.2:
            n = Vector((1, 0, 0))
        n.normalize()
        leaf(L, p, n, d, 0.090 * size, 0.056 * size, m, math.radians(10))

    shoots = [(0.0, 0.0, 1.00), (0.35, 0.9, 0.80), (0.38, 3.0, 0.72), (0.32, 4.9, 0.86)]
    for lean, az, hk in shoots:
        top = Vector((math.cos(az) * lean * H, math.sin(az) * lean * H, H * hk))
        ctrl = top * 0.5 + Vector((0, 0, 0.02))
        pts = [Vector((0, 0, -0.03)), ctrl, top]
        S.tube(pts, [0.0055, 0.0040, 0.0022], 5, "sprig_bark", caps=True)
        # feuilles serrees le long de la pousse, plus claires vers la pointe
        n_l = 7
        for k in range(n_l):
            t = 0.25 + 0.75 * k / (n_l - 1)
            q = pts[0] * (1 - t) ** 2 + ctrl * 2 * t * (1 - t) + top * t * t
            ang = az + k * 2.4 + rng.uniform(-0.3, 0.3)
            d = (Vector((math.cos(ang), math.sin(ang), 0.0)) * 0.7 + Vector((0, 0, 0.9))).normalized()
            m = "sprig_leaf2" if t > 0.7 or rng.random() < 0.2 else "sprig_leaf"
            leaf_at(q, d, 1.0 - 0.25 * t, m)
        for k in range(3):                             # bourgeon terminal
            ang = az + k * 2.09
            d = (Vector((math.cos(ang), math.sin(ang), 0.0)) * 0.35 + Vector((0, 0, 1.0))).normalized()
            leaf_at(top - Vector((0, 0, 0.012)), d, 0.6, "sprig_leaf2")
    S.build("stem")
    L.build("leaves")

    common.TINT_GROUND = 0.0     # le rameau sort de la haie, a hauteur de main : pas d'assombrissement de sol
    return pfinish("hedge_sprig", expected_dims=(0.18, 0.18, 0.23), tri_limit=(80, 1200),
                   angles={"stem": math.radians(60), "leaves": math.radians(8)},
                   yaw=30, pitch=18, margin=1.05)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for v in (argv or ["a", "b", "sprig"]):
        if v == "sprig":
            build_sprig()
        else:
            build(v, {"a": 3, "b": 11}.get(v, 1))
