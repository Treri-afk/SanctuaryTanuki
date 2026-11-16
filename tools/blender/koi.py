"""Carpes koi de l'etang : un modele par robe (kohaku, sanke, showa, ogon, asagi).

Corps profile (tete ronde et camuse, dos le plus haut au tiers avant, pedoncule fin), longue dorsale basse,
grandes pectorales en palette, pelviennes, anale, barbillons, yeux. Les robes sont peintes face par face
(une couleur unie par materiau) : taches rouges en escalier du kohaku, sumi du sanke, noir enveloppant du
showa, or de l'ogon, dos en filet d'ecailles et flancs orange de l'asagi.

Repere : tete vers -Y (= +Z dans Godot : la carpe nage vers +Z). Origine au centre du corps, pas au sol
(le jeu pose l'origine 3 cm sous la surface de l'eau ; le dos affleure). Le rapport signale donc
« origine pas au sol » : c'est voulu.
Deux objets : « body » et « tail » (nageoire caudale), dont l'origine est le point d'articulation
(Y = +0.105) : le jeu le fait onduler (rotation autour de l'axe vertical).
Sorties : assets/models/koi_<robe>.glb
Lancer : blender --background --python tools/blender/koi.py [-- robe ...]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *

PALETTE.update({
    "koi_blue_dark": "#61788F",
    "koi_gold_light": "#EAC56A",
    "koi_gold_dark": "#D3A13C",
})

PATTERNS = ["kohaku", "sanke", "showa", "ogon", "asagi"]

Y0, LEN = -0.175, 0.280          # museau -> pedoncule (articulation de la queue)
TAIL_Y = Y0 + LEN                # 0.105

# profil du corps : (s, demi-largeur, demi-hauteur dessus, demi-hauteur dessous, centre z)
STATIONS = [
    (0.000, 0.0085, 0.0062, 0.0060, -0.0045),   # museau camus
    (0.022, 0.0150, 0.0118, 0.0112, -0.0038),
    (0.065, 0.0228, 0.0175, 0.0180, -0.0030),
    (0.135, 0.0292, 0.0222, 0.0238, -0.0030),
    (0.225, 0.0338, 0.0254, 0.0282, -0.0035),
    (0.330, 0.0360, 0.0268, 0.0305, -0.0040),   # le plus large et le plus profond : un koi est trapu
    (0.460, 0.0350, 0.0258, 0.0290, -0.0040),
    (0.600, 0.0298, 0.0222, 0.0240, -0.0030),
    (0.740, 0.0214, 0.0170, 0.0165, -0.0015),
    (0.870, 0.0128, 0.0118, 0.0100, 0.0000),
    (1.000, 0.0072, 0.0090, 0.0070, 0.0000),
]
N_RINGS = 42
N_AROUND = 26


def station(s):
    """Interpolation douce (cosinus) du profil."""
    for k in range(len(STATIONS) - 1):
        a, b = STATIONS[k], STATIONS[k + 1]
        if a[0] <= s <= b[0]:
            t = (s - a[0]) / (b[0] - a[0])
            t = 0.5 - 0.5 * math.cos(math.pi * t)
            return [a[i] + (b[i] - a[i]) * t for i in range(1, 5)]
    return list(STATIONS[-1][1:])


def body_point(s, a):
    w, ht, hb, zc = station(s)
    ca, sa = math.cos(a), math.sin(a)
    e = 2.25                                    # un peu plus plein qu'une ellipse
    k = (abs(ca) ** e + abs(sa) ** e) ** (-1.0 / e)
    h = ht if sa > 0 else hb
    return Vector((w * ca * k, Y0 + LEN * s, zc + h * sa * k))


def surface_x(y, z):
    """Demi-largeur du corps a la hauteur z, a l'abscisse y (pour poser yeux et nageoires sur la peau)."""
    s = min(max((y - Y0) / LEN, 0.0), 1.0)
    w, ht, hb, zc = station(s)
    h = ht if z > zc else hb
    q = min(abs(z - zc) / h, 0.999)
    return w * (1.0 - q ** 2.25) ** (1.0 / 2.25)


def s_of(y):
    return (y - Y0) / LEN


# ------------------------------------------------------------------ robes
def blob(c, r):
    """Tache ellipsoidale : renvoie un test sur le centroide d'une face."""
    cx, cy, cz = c
    rx, ry, rz = r
    return lambda p: ((p[0] - cx) / rx) ** 2 + ((p[1] - cy) / ry) ** 2 + ((p[2] - cz) / rz) ** 2 <= 1.0


ROBES = {
    # base, couleur des nageoires, couleur a la base des nageoires, taches [(materiau, test)] dans l'ordre
    "kohaku": dict(base="koi_white", fin="koi_fin", fin_base="koi_fin", spots=[
        ("koi_red", blob((0.002, -0.132, 0.030), (0.024, 0.024, 0.024))),     # tache de tete, sans le nez
        ("koi_red", blob((0.006, -0.068, 0.030), (0.034, 0.034, 0.024))),
        ("koi_red", blob((-0.006, 0.004, 0.030), (0.036, 0.038, 0.024))),
        ("koi_red", blob((0.002, 0.066, 0.022), (0.018, 0.016, 0.018))),
    ]),
    "sanke": dict(base="koi_white", fin="koi_fin", fin_base="koi_fin", spots=[
        ("koi_red", blob((-0.003, -0.128, 0.030), (0.022, 0.026, 0.024))),
        ("koi_red", blob((0.008, -0.060, 0.030), (0.034, 0.030, 0.024))),
        ("koi_red", blob((-0.004, 0.012, 0.030), (0.030, 0.036, 0.024))),
        ("koi_black", blob((0.016, -0.034, 0.026), (0.011, 0.012, 0.016))),  # sumi : jamais sur la tete
        ("koi_black", blob((-0.017, 0.030, 0.022), (0.010, 0.011, 0.016))),
        ("koi_black", blob((0.008, 0.074, 0.018), (0.007, 0.009, 0.012))),
        ("koi_black", blob((-0.010, -0.080, 0.028), (0.006, 0.007, 0.010))),
    ]),
    "showa": dict(base="koi_black", fin="koi_fin", fin_base="koi_black", spots=[
        ("koi_white", blob((0.0, -0.030, -0.030), (0.040, 0.110, 0.022))),   # ventre clair
        ("koi_red", blob((0.0, -0.138, 0.028), (0.026, 0.028, 0.026))),
        ("koi_red", blob((-0.006, -0.064, 0.030), (0.030, 0.030, 0.022))),
        ("koi_white", blob((0.012, -0.012, 0.028), (0.020, 0.022, 0.020))),
        ("koi_red", blob((0.004, 0.024, 0.030), (0.028, 0.026, 0.022))),
        ("koi_white", blob((-0.010, 0.068, 0.020), (0.016, 0.018, 0.018))),
        ("koi_black", blob((0.013, -0.140, 0.024), (0.006, 0.019, 0.014))),  # eclair noir, de biais sur la tete
    ]),
    "ogon": dict(base="koi_gold", fin="koi_gold_light", fin_base="koi_gold_light", spots=[]),
    "asagi": dict(base="koi_blue", fin="koi_fin", fin_base="koi_orange", spots=[
        ("koi_orange", lambda p: p[2] < -0.004 - 0.05 * max(0.0, p[1] - 0.04)),     # flancs et ventre
        ("koi_orange", blob((0.0, -0.160, -0.006), (0.030, 0.022, 0.014))),        # joues
        ("koi_white", blob((0.0, -0.140, 0.020), (0.030, 0.034, 0.022))),          # tete pale
    ]),
}


def body_mat(robe, i, j, p):
    r = ROBES[robe]
    m = r["base"]
    for mm, test in r["spots"]:
        if test(p):
            m = mm
    if robe == "asagi" and m == "koi_blue" and (i + j) % 2:
        m = "koi_blue_dark"                     # le filet d'ecailles du dos
    if robe == "ogon" and p[2] > -0.006 and p[1] > -0.125 and (i + j) % 2:
        m = "koi_gold_dark"                     # reflets d'ecailles, tres discrets
    return m


# ------------------------------------------------------------------ nageoires
def fin(M, origin, u, v, outline, thick, m_outer, m_inner, center=(0.0, 0.0), inner=0.42, cup=0.0):
    """Nageoire = eventail ferme et mince. outline : contour 2D (u, v) etoile depuis center.
    Deux bandes : pres de la base (m_inner) puis le bord (m_outer). cup : creuse la nageoire (m)."""
    o, u, v = Vector(origin), Vector(u).normalized(), Vector(v)
    v = (v - u * v.dot(u)).normalized()
    nrm = u.cross(v)
    cu, cv = center

    def P(a, b, side):
        d = math.hypot(a - cu, b - cv)
        return o + u * a + v * b + nrm * (side * thick * 0.5 * (1.0 - 0.6 * min(d / 0.05, 1.0)) + cup * d * d)

    n = len(outline)
    c_top, c_bot = P(cu, cv, 1), P(cu, cv, -1)
    mid = [(cu + (a - cu) * inner, cv + (b - cv) * inner) for a, b in outline]
    verts = [c_top, c_bot]
    for a, b in mid:
        verts += [P(a, b, 1), P(a, b, -1)]
    for a, b in outline:
        verts += [P(a, b, 1), P(a, b, -1)]
    MT, MB = lambda k: 2 + 2 * k, lambda k: 3 + 2 * k
    OT, OB = lambda k: 2 + 2 * n + 2 * k, lambda k: 3 + 2 * n + 2 * k
    inner_f, outer_f = [], []
    for k in range(n):
        k2 = (k + 1) % n
        inner_f += [(0, MT(k), MT(k2)), (1, MB(k2), MB(k))]
        outer_f += [(MT(k), OT(k), OT(k2), MT(k2)), (MB(k), MB(k2), OB(k2), OB(k)),
                    (OT(k), OB(k), OB(k2), OT(k2))]
    base = len(M.v)
    M.v += [tuple(p) for p in verts]
    for fc in inner_f:
        M.f.append(tuple(base + i for i in fc))
        M.fm.append(M._mi(m_inner))
    for fc in outer_f:
        M.f.append(tuple(base + i for i in fc))
        M.fm.append(M._mi(m_outer))


def build(robe):
    reset_scene()
    common.TINT_GROUND = 0.0          # la carpe n'est pas posee au sol : seulement l'occlusion des creux
    r = ROBES[robe]
    B = Mesh()

    # ---- corps
    rings = []
    for i in range(N_RINGS):
        s = (i / (N_RINGS - 1)) ** 1.15          # anneaux plus serres vers la tete (detail des taches)
        # un anneau sur deux decale d'un demi-pas : la grille devient un losange, comme les rangees d'ecailles,
        # et le bord des taches festonne (kiwa) au lieu de faire des marches d'escalier
        ph = (i % 2) * math.pi / N_AROUND
        rings.append([body_point(s, 2 * math.pi * j / N_AROUND - math.pi / 2 + ph) for j in range(N_AROUND)])

    def m_body(i, j):
        j2 = (j + 1) % N_AROUND
        p = (rings[i][j] + rings[i][j2] + rings[i + 1][j] + rings[i + 1][j2]) / 4
        return body_mat(robe, i, j, p)

    B.loft(rings, m_body, True, True)

    # ---- yeux, un peu saillants, legerement sous la ligne mediane
    for sx in (-1, 1):
        y, z = -0.149, 0.0035
        x = surface_x(y, z) - 0.0012
        B.blob((sx * x, y, z), (0.0042, 0.0046, 0.0044), "koi_eye", subdiv=1, noise=0.0)

    # ---- barbillons (deux paires, a la commissure)
    for sx in (-1, 1):
        for (y0, dy, dz, ln) in ((-0.171, -0.004, -0.008, 1.0), (-0.166, 0.002, -0.009, 0.7)):
            x0 = surface_x(y0, -0.006) - 0.0006
            p0 = Vector((sx * x0, y0, -0.006))
            pts = [p0, p0 + Vector((sx * 0.003, dy * 0.6, dz * 0.55)) * ln,
                   p0 + Vector((sx * 0.004, dy, dz)) * ln]
            B.tube(pts, [0.0011, 0.0008, 0.0004], 4, r["fin_base"] if robe != "showa" else "koi_white", caps=True)

    fin_m, fin_b = r["fin"], r["fin_base"]

    # ---- pectorales : grandes palettes, vers l'arriere, l'exterieur et le bas
    for sx in (-1, 1):
        y, z = -0.104, -0.012
        o = (sx * (surface_x(y, z) - 0.003), y, z)
        u = (sx * 0.86, 0.42, -0.30)
        v = (0.0, 1.0, 0.0)
        out = [(0.000, -0.005), (0.008, -0.011), (0.018, -0.014), (0.029, -0.013), (0.038, -0.008),
               (0.044, 0.000), (0.046, 0.009), (0.042, 0.017), (0.034, 0.022), (0.023, 0.023),
               (0.012, 0.019), (0.004, 0.011), (-0.002, 0.004)]
        fin(B, o, u, v, out, 0.0024, fin_m, fin_b, center=(0.004, 0.002), inner=0.38)

    # ---- pelviennes
    for sx in (-1, 1):
        y, z = -0.022, -0.018
        o = (sx * (surface_x(y, z) - 0.004), y, z)
        out = [(0.0, -0.004), (0.007, -0.007), (0.015, -0.006), (0.022, -0.002), (0.025, 0.004),
               (0.022, 0.010), (0.014, 0.012), (0.005, 0.008)]
        fin(B, o, (sx * 0.55, 0.55, -0.62), (0.0, 1.0, 0.0), out, 0.0018, fin_m, fin_b, center=(0.003, 0.001))

    # ---- dorsale : longue et basse, du tiers avant aux trois quarts
    y_d = -0.090
    _, ht_d, _, zc_d = station(s_of(y_d))
    z_d = zc_d + ht_d - 0.004
    out = [(0.000, -0.004), (0.003, 0.009), (0.009, 0.015), (0.022, 0.016), (0.048, 0.013), (0.078, 0.008),
           (0.102, 0.003), (0.110, -0.004), (0.104, -0.012), (0.060, -0.010), (0.020, -0.007)]
    fin(B, (0.0, y_d, z_d), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), out, 0.0020, fin_m, fin_b, center=(0.055, -0.004),
        inner=0.30)

    # ---- anale
    y_a = 0.046
    _, _, hb_a, zc_a = station(s_of(y_a))
    z_a = zc_a - hb_a + 0.003
    out = [(0.000, 0.002), (0.004, -0.009), (0.013, -0.015), (0.024, -0.012), (0.030, -0.004), (0.026, 0.004),
           (0.012, 0.004)]
    fin(B, (0.0, y_a, z_a), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), out, 0.0018, fin_m, fin_b, center=(0.013, -0.002))

    B.build("body")

    # ---- queue : origine sur l'articulation ; recouvre le pedoncule pour ne pas laisser de trou en ondulant
    T = Mesh()
    w, ht, hb, zc = station(1.0)
    cone = []
    for (dy, kk) in ((-0.010, 1.04), (0.000, 0.98), (0.010, 0.80), (0.018, 0.55)):
        cone.append([Vector((w * kk * math.cos(a), dy, zc + (ht if math.sin(a) > 0 else hb) * kk * math.sin(a)))
                     for a in [2 * math.pi * j / 12 for j in range(12)]])
    T.loft(cone, r["base"] if robe != "showa" else "koi_black", True, True)
    out = [(0.004, 0.007), (0.018, 0.018), (0.034, 0.031), (0.052, 0.044), (0.068, 0.053), (0.080, 0.057),
           (0.088, 0.051), (0.089, 0.038), (0.081, 0.022), (0.070, 0.007), (0.065, 0.000), (0.070, -0.007),
           (0.081, -0.021), (0.089, -0.035), (0.088, -0.047), (0.080, -0.052), (0.066, -0.048), (0.050, -0.039),
           (0.032, -0.027), (0.017, -0.016), (0.004, -0.006)]
    tail_base = fin_b if robe in ("showa", "asagi") else r["base"]
    fin(T, (0.0, 0.004, zc), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), out, 0.0024, fin_m, tail_base,
        center=(0.002, 0.0), inner=0.34)
    T.build("tail", loc=(0.0, TAIL_Y, 0.0))

    name = "koi_" + robe
    return pfinish(name, expected_dims=(0.13, 0.38, 0.10), tri_limit=(400, 3500),
                   angles={"body": math.radians(55), "tail": math.radians(40)},
                   lift_preview=0.06, yaw=35, pitch=38, margin=1.0,
                   extra_views=[("_side", dict(yaw=88, pitch=4, margin=0.95))])


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for robe in (argv or PATTERNS):
        build(robe)
