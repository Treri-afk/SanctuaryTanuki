"""Stand de la peche aux poissons rouges (kingyo sukui) pour la fete de Tsukimi.

- kingyo_<robe> : poisson rouge (wakin a double queue, vu surtout de dessus) ; robes : aka (rouge), sarasa (rouge
  et blanc), kuro (demekin noir aux yeux telescopes, plus lourd), kin (dore, rare). Deux objets comme les carpes :
  « body » et « tail » (double queue ecartee en V, origine sur l'articulation : le jeu la fait onduler).
  Tete vers -Y (= +Z dans Godot). Origine au centre du corps.
- poi : l'epuisette de papier (cadre de plastique rond et manche) ; le papier lui-meme est dessine par le jeu
  (shader qui se mouille et se dechire). Origine au centre de l'anneau, manche vers +Y (= -Z dans Godot).
- kingyo_bowl : le bol (owan) ou l'on verse les prises.
- kingyo_tub : le bac bleu clair, bord de bois ; l'eau est ajoutee par le jeu (niveau : repere « water »).
Lancer : blender --background --python tools/blender/kingyo.py [-- kingyo_aka poi ...]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *
from koi import fin

PALETTE.update({
    "kg_red": "#E2552A",
    "kg_red_deep": "#C93F22",
    "kg_orange": "#EE8A3A",
    "kg_white": "#F5EFE6",
    "kg_fin_red": "#EE7A4E",
    "kg_fin_pale": "#F4C7A8",
    "kg_black": "#24222A",
    "kg_black_fin": "#3A3640",
    "kg_gold": "#E8B848",
    "kg_gold_light": "#F4D683",
    "kg_eye": "#1E1A20",
    "kg_eye_ring": "#D8C7A0",
    "poi_frame": "#E8E1D2",
    "poi_frame_shade": "#C9C0AE",
    "poi_handle_red": "#C9432C",
    "bowl_white": "#F2EFE8",
    "bowl_red": "#C9432C",
    "bowl_inside": "#E6E3DA",
    "tub_blue": "#7FB6CC",
    "tub_blue_deep": "#5E9DB8",
    "tub_wood": "#A27B52",
    "tub_wood_dark": "#7A5A3A",
})

ROBES = ["aka", "sarasa", "kuro", "kin"]

Y0, LEN = -0.030, 0.054          # museau -> pedoncule
TAIL_Y = Y0 + LEN                # 0.024

# profil : (s, demi-largeur, demi-hauteur dessus, demi-hauteur dessous, centre z) ; un wakin est trapu et rond
STATIONS = [
    (0.00, 0.0030, 0.0026, 0.0026, -0.0010),
    (0.06, 0.0060, 0.0052, 0.0050, -0.0008),
    (0.18, 0.0092, 0.0084, 0.0082, -0.0005),
    (0.34, 0.0110, 0.0104, 0.0104, -0.0006),
    (0.50, 0.0112, 0.0108, 0.0110, -0.0008),
    (0.66, 0.0100, 0.0094, 0.0094, -0.0006),
    (0.82, 0.0068, 0.0066, 0.0060, -0.0002),
    (0.94, 0.0036, 0.0042, 0.0034, 0.0000),
    (1.00, 0.0026, 0.0034, 0.0026, 0.0000),
]
N_RINGS = 30
N_AROUND = 24


def station(s):
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
    e = 2.15
    k = (abs(ca) ** e + abs(sa) ** e) ** (-1.0 / e)
    h = ht if sa > 0 else hb
    return Vector((w * ca * k, Y0 + LEN * s, zc + h * sa * k))


def surface_x(y, z):
    s = min(max((y - Y0) / LEN, 0.0), 1.0)
    w, ht, hb, zc = station(s)
    h = ht if z > zc else hb
    q = min(abs(z - zc) / h, 0.999)
    return w * (1.0 - q ** 2.15) ** (1.0 / 2.15)


def blob(c, r):
    cx, cy, cz = c
    rx, ry, rz = r
    return lambda p: ((p[0] - cx) / rx) ** 2 + ((p[1] - cy) / ry) ** 2 + ((p[2] - cz) / rz) ** 2 <= 1.0


ROBE = {
    # base, nageoires (bord), base des nageoires, taches [(materiau, test)]
    "aka": dict(base="kg_red", fin="kg_fin_red", fin_base="kg_red", spots=[
        ("kg_orange", lambda p: p[2] < -0.0055),                       # ventre plus clair
    ]),
    "sarasa": dict(base="kg_red", fin="kg_fin_pale", fin_base="kg_red", spots=[
        ("kg_white", lambda p: p[2] < -0.003),                          # ventre blanc
        ("kg_white", blob((0.004, -0.004, 0.008), (0.009, 0.010, 0.008))),
        ("kg_white", blob((-0.003, 0.016, 0.007), (0.007, 0.007, 0.007))),
        ("kg_white", blob((0.0, -0.030, 0.002), (0.004, 0.006, 0.005))),  # bout du nez
    ]),
    "kuro": dict(base="kg_black", fin="kg_black_fin", fin_base="kg_black", spots=[]),
    "kin": dict(base="kg_gold", fin="kg_gold_light", fin_base="kg_gold", spots=[
        ("kg_gold_light", lambda p: p[2] < -0.005),
    ]),
}


def body_mat(robe, p):
    r = ROBE[robe]
    m = r["base"]
    for mm, test in r["spots"]:
        if test(p):
            m = mm
    return m


def build_fish(robe):
    reset_scene()
    common.TINT_GROUND = 0.0
    r = ROBE[robe]
    B = Mesh()
    rings = []
    for i in range(N_RINGS):
        s = i / (N_RINGS - 1)
        ph = (i % 2) * math.pi / N_AROUND
        rings.append([body_point(s, 2 * math.pi * j / N_AROUND - math.pi / 2 + ph) for j in range(N_AROUND)])

    def m_body(i, j):
        j2 = (j + 1) % N_AROUND
        p = (rings[i][j] + rings[i][j2] + rings[i + 1][j] + rings[i + 1][j2]) / 4
        return body_mat(robe, p)

    B.loft(rings, m_body, True, True)
    fin_m, fin_b = r["fin"], r["fin_base"]

    # yeux : grands et ronds ; le demekin a des yeux telescopes (cones saillants sur les cotes)
    for sx in (-1, 1):
        y, z = -0.0215, 0.0016
        x = surface_x(y, z)
        if robe == "kuro":
            base = Vector((sx * (x - 0.0006), y, z))
            tip = base + Vector((sx * 0.0048, -0.0006, 0.0010))
            B.tube([base, base + (tip - base) * 0.6, tip], [0.0030, 0.0034, 0.0032], 10, "kg_black", caps=True)
            B.blob(tuple(tip + Vector((sx * 0.0006, 0, 0))), (0.0016, 0.0027, 0.0027), "kg_eye", subdiv=1, noise=0.0)
        else:
            B.blob((sx * (x - 0.0003), y, z), (0.0014, 0.0024, 0.0024), "kg_eye_ring", subdiv=1, noise=0.0)
            B.blob((sx * (x + 0.0003), y, z), (0.0010, 0.0018, 0.0018), "kg_eye", subdiv=1, noise=0.0)

    # pectorales : palettes vers l'arriere et l'exterieur (bien visibles de dessus)
    for sx in (-1, 1):
        y, z = -0.012, -0.004
        o = (sx * (surface_x(y, z) - 0.0008), y, z)
        out = [(0.000, -0.002), (0.004, -0.004), (0.009, -0.004), (0.013, -0.001), (0.014, 0.003),
               (0.011, 0.006), (0.006, 0.006), (0.001, 0.003)]
        fin(B, o, (sx * 0.85, 0.5, -0.25), (0.0, 1.0, 0.0), out, 0.0007, fin_m, fin_b, center=(0.001, 0.001), inner=0.4)

    # pelviennes
    for sx in (-1, 1):
        y, z = 0.004, -0.008
        o = (sx * (surface_x(y, z) - 0.0012), y, z)
        out = [(0.0, -0.001), (0.004, -0.003), (0.008, -0.002), (0.010, 0.002), (0.007, 0.004), (0.002, 0.003)]
        fin(B, o, (sx * 0.5, 0.55, -0.65), (0.0, 1.0, 0.0), out, 0.0006, fin_m, fin_b, center=(0.001, 0.0))

    # dorsale haute, en voile
    y_d = -0.006
    _, ht_d, _, zc_d = station((y_d - Y0) / LEN)
    z_d = zc_d + ht_d - 0.0012
    out = [(0.000, -0.001), (0.002, 0.006), (0.006, 0.011), (0.012, 0.012), (0.019, 0.009), (0.024, 0.004),
           (0.026, -0.001), (0.020, -0.003), (0.008, -0.002)]
    fin(B, (0.0, y_d, z_d), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), out, 0.0006, fin_m, fin_b, center=(0.012, -0.001),
        inner=0.32)

    # anale double, petite
    for sx in (-1, 1):
        y_a = 0.013
        _, _, hb_a, zc_a = station((y_a - Y0) / LEN)
        out = [(0.0, 0.001), (0.002, -0.004), (0.007, -0.006), (0.010, -0.003), (0.008, 0.001)]
        fin(B, (sx * 0.0012, y_a, zc_a - hb_a + 0.001), (0.0, 1.0, 0.0), (sx * 0.35, 0.0, 1.0), out, 0.0005,
            fin_m, fin_b, center=(0.004, -0.001))
    B.build("body")

    # double queue : deux lobes ecartes en V (vue de dessus : un eventail ouvert), qui couvrent le pedoncule
    T = Mesh()
    w, ht, hb, zc = station(1.0)
    cone = []
    for (dy, kk) in ((-0.004, 1.05), (0.000, 0.98), (0.003, 0.75), (0.005, 0.5)):
        cone.append([Vector((w * kk * math.cos(a), dy, zc + (ht if math.sin(a) > 0 else hb) * kk * math.sin(a)))
                     for a in [2 * math.pi * j / 10 for j in range(10)]])
    T.loft(cone, r["base"], True, True)
    # chaque lobe : un large eventail arrondi, echancre au bout (la double queue du wakin)
    out = [(0.001, 0.001), (0.005, 0.006), (0.011, 0.012), (0.018, 0.017), (0.025, 0.020), (0.031, 0.020),
           (0.035, 0.016), (0.036, 0.010), (0.033, 0.005), (0.030, 0.002), (0.031, -0.002), (0.033, -0.006),
           (0.033, -0.010), (0.028, -0.012), (0.020, -0.010), (0.012, -0.007), (0.005, -0.004), (0.001, -0.001)]
    for sx in (-1, 1):
        a = math.radians(62) * sx
        v = (math.sin(a), 0.0, math.cos(a))        # plan du lobe : penche vers l'exterieur
        fin(T, (sx * 0.0006, 0.001, zc), (0.0, 1.0, 0.0), v, out, 0.0006, fin_m, r["fin_base"],
            center=(0.001, 0.0), inner=0.3, cup=0.6 * sx)
    T.build("tail", loc=(0.0, TAIL_Y, 0.0))
    return pfinish("kingyo_" + robe, expected_dims=(0.04, 0.09, 0.03), tri_limit=(300, 3000),
                   angles={"body": math.radians(60), "tail": math.radians(40)},
                   lift_preview=0.02, yaw=35, pitch=55, margin=1.0,
                   extra_views=[("_side", dict(yaw=88, pitch=4, margin=0.95))])


# ------------------------------------------------------------------ poi
def poi():
    reset_scene()
    M = Mesh()
    R = 0.046                      # rayon interieur de l'anneau (papier)
    # anneau : section en D, plat dessous (le papier y est colle)
    n = 40
    rings = []
    for k in range(9):
        a = math.pi * k / 8
        rings.append((R + 0.0035 + 0.0035 * math.cos(a), 0.0035 * math.sin(a)))
    ring_pts = []
    for (rr, zz) in rings:
        ring_pts.append([Vector((rr * math.cos(2 * math.pi * j / n), rr * math.sin(2 * math.pi * j / n), zz))
                         for j in range(n)])
    ring_pts.append(ring_pts[0])
    M.loft(ring_pts[:-1], lambda i, j: "poi_frame" if i < 4 else "poi_frame_shade", False, False)
    # fond plat de l'anneau
    flat = [[Vector((r * math.cos(2 * math.pi * j / n), r * math.sin(2 * math.pi * j / n), 0.0)) for j in range(n)]
            for r in (R, R + 0.007)]
    M.loft(flat, "poi_frame_shade", False, False)
    # manche : part de l'anneau vers +Y, un peu releve, bout arrondi rouge
    h0 = Vector((0.0, R + 0.004, 0.002))
    pts = [h0, h0 + Vector((0, 0.02, 0.004)), h0 + Vector((0, 0.05, 0.008)), h0 + Vector((0, 0.078, 0.011))]
    M.sweep(pts, lambda i, a: ((0.0062 if i else 0.0075) * math.cos(a), 0.0026 * math.sin(a)), 12,
            lambda i, j: "poi_frame" if i < 2 else "poi_handle_red", caps=True)
    M.blob(tuple(pts[-1]), (0.0064, 0.005, 0.0028), "poi_handle_red", subdiv=1, noise=0.0)
    M.build("poi")
    return pfinish("poi", expected_dims=(0.11, 0.19, 0.03), tri_limit=(200, 2500), lift_preview=0.02,
                   yaw=25, pitch=50, margin=1.1)


# ------------------------------------------------------------------ bol
def kingyo_bowl():
    reset_scene()
    M = Mesh()
    prof_out = [(0.030, 0.0), (0.034, 0.004), (0.052, 0.018), (0.062, 0.034), (0.066, 0.046)]
    prof_in = [(0.062, 0.046), (0.058, 0.034), (0.048, 0.020), (0.030, 0.008), (0.0, 0.007)]
    M.lathe(prof_out, 32, lambda i, j: "bowl_red" if i >= 3 else "bowl_white", cap0=True, cap1=False)
    M.lathe([(0.066, 0.046), (0.064, 0.048), (0.062, 0.046)], 32, "bowl_red", cap0=False, cap1=False)
    M.lathe(prof_in, 32, "bowl_inside", cap0=False, cap1=False)
    M.build("bowl")
    return pfinish("kingyo_bowl", expected_dims=(0.13, 0.13, 0.05), tri_limit=(200, 2000), yaw=25, pitch=35,
                   margin=1.1)


# ------------------------------------------------------------------ bac
def kingyo_tub():
    reset_scene()
    M = Mesh()
    W, D, H = 0.70, 0.42, 0.30          # demi-longueur, demi-largeur, hauteur
    T = 0.03                             # epaisseur des parois
    LEVEL = 0.24
    # coque : boite ouverte aux coins arrondis (bleu clair dedans et dehors)
    def rrect(hw, hd, r, n=5):
        pts = []
        for (cx, cy, a0) in ((hw - r, hd - r, 0), (-hw + r, hd - r, 90), (-hw + r, -hd + r, 180), (hw - r, -hd + r, 270)):
            for k in range(n + 1):
                a = math.radians(a0 + 90 * k / n)
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return pts
    outer = rrect(W, D, 0.07)
    inner = rrect(W - T, D - T, 0.05)
    lo = [Vector((x, y, 0.0)) for x, y in outer]
    hi = [Vector((x, y, H)) for x, y in outer]
    ilo = [Vector((x, y, 0.025)) for x, y in inner]
    ihi = [Vector((x, y, H)) for x, y in inner]
    M.loft([lo, [p + Vector((0, 0, H * 0.5)) for p in lo], hi], "tub_blue", True, False)
    M.loft([hi, ihi], "tub_wood", False, False)
    M.loft([ihi, [p + Vector((0, 0, -(H - 0.025) * 0.5)) for p in ihi], ilo], lambda i, j: "tub_blue" if i == 0 else "tub_blue_deep", False, True)
    # liston de bois sur le bord (un peu plus large) et deux poignees
    rim_o = [Vector((x * 1.025, y * 1.04, H + 0.012)) for x, y in outer]
    rim_i = [Vector((x * 0.985, y * 0.975, H + 0.012)) for x, y in outer]
    M.loft([[p + Vector((0, 0, -0.03)) for p in rim_o], rim_o, rim_i, [p + Vector((0, 0, -0.03)) for p in rim_i]],
           lambda i, j: "tub_wood" if i == 1 else "tub_wood_dark", False, False)
    for sx in (-1, 1):
        M.add(*_box_vf((sx * (W + 0.02), 0.0, H - 0.05), (0.03, 0.16, 0.025)), "tub_wood_dark")
    M.build("tub")
    o = bpy.data.objects.new("water", None)
    bpy.context.collection.objects.link(o)
    o.location = (0.0, 0.0, LEVEL)
    return pfinish("kingyo_tub", expected_dims=(1.45, 0.9, 0.33), tri_limit=(200, 3000), yaw=30, pitch=40,
                   margin=1.15)


def _box_vf(c, s):
    cx, cy, cz = c
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    v = [(cx + x * hx, cy + y * hy, cz + z * hz) for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return v, f


ALL = {"kingyo_" + r: (lambda rr=r: build_fish(rr)) for r in ROBES}
ALL.update({"poi": poi, "kingyo_bowl": kingyo_bowl, "kingyo_tub": kingyo_tub})

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in (argv or list(ALL)):
        ALL[a]()
