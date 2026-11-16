"""Stands de fete (yatai) pour la soiree de Tsukimi : un modele par jeu, meme charpente.

Charpente : quatre poteaux de cedre (l'avant plus bas), un toit de toile tendue a rayures qui deborde vers
l'avant, un lambrequin (maku) en tissu clair borde de couleur, ou le jeu ecrit l'enseigne (repere « sign »),
deux reperes « lantern_L/R » pour les lanternes de papier. Puis selon le jeu :
- yatai_kingyo  : rayures rouges ; pas de comptoir (le bac est pose devant) ; banc a l'arriere et barre de
  sachets de poissons rouges ;
- yatai_shateki : rayures indigo ; comptoir ; gradins de lots au fond sur un tissu rouge (le jeu y pose les lots) ;
- yatai_wanage  : rayures vertes ; pas de comptoir ; etageres de lots au fond (masques de renard, furin) ;
- yatai_dango   : rayures roses ; comptoir drape ; rechaud et assiettes (le sanbo est pose par le jeu).
Un seul materiau par objet (couleurs aux sommets, voir tree_util). L'avant est -Y (= +Z dans Godot).
Lancer : blender --background --python tools/blender/yatai.py [-- yatai_kingyo ...]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from festival import *          # TM, box, lathe, quad_box, disc, capsule, couleurs de la fete

W, D = 1.2, 0.62                # demi-largeur, demi-profondeur entre poteaux
Z_FRONT, Z_BACK = 2.08, 2.32    # haut des poteaux
OVER = 0.32                     # debord du toit vers l'avant
COUNTER_Z = 0.86

WHITE_CLOTH = lin("#F2ECDD")
CLOTH_SHADE = lin("#E1D8C4")
RED = lin("#C9432C")
RED_DARK = lin("#A33522")
INDIGO2 = lin("#34446B")
GREEN = lin("#5E7F4A")
GREEN_DARK = lin("#4A6639")
PINK = lin("#D98C98")
PINK_DARK = lin("#B86F7C")
TABLE = lin("#9C7550")
TABLE_DARK = lin("#7A5A3C")
FELT_RED = lin("#A83A2C")
BAG = lin("#DCEAF0")
BAG_WATER = lin("#BCD9E4")
FISH = lin("#E2552A")
MASK = lin("#F3EEE4")
MASK_RED = lin("#C8442B")
MASK_GOLD = lin("#D3A84E")
GLASS = lin("#CFE3EA")
CHARCOAL = lin("#2F2A2A")
EMBER = lin("#D9622B")
PLATE = lin("#EFE9DC")

VARIANTS = {
    "kingyo": dict(stripe=RED, stripe_dark=RED_DARK, counter=False),
    "shateki": dict(stripe=INDIGO2, stripe_dark=INDIGO_DARK, counter=True),
    "wanage": dict(stripe=GREEN, stripe_dark=GREEN_DARK, counter=False),
    "dango": dict(stripe=PINK, stripe_dark=PINK_DARK, counter=True),
}


def roof_z(y):
    """Hauteur du toit a la profondeur y (avant = -Y)."""
    t = (y + D + OVER) / (2 * D + OVER + 0.08)
    return Z_FRONT - 0.05 + (Z_BACK + 0.04 - (Z_FRONT - 0.05)) * t


def frame(T):
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = roof_z(sy * D) - 0.05
            box(T, (sx * W, sy * D, h / 2), (0.07, 0.07, h), CEDAR)
            lathe(T, [(0.06, 0.0), (0.065, 0.03), (0.055, 0.06), (0.0, 0.06)], 8, (sx * W, sy * D), lambda k: STONE)
    # traverses du haut (avant, arriere, cotes), sous la toile
    box(T, (0, -D, roof_z(-D) - 0.1), (2 * W + 0.1, 0.06, 0.07), CEDAR_DARK)
    box(T, (0, D, roof_z(D) - 0.1), (2 * W + 0.1, 0.06, 0.07), CEDAR_DARK)
    for sx in (-1, 1):
        a, b = V((sx * W, -D - OVER, roof_z(-D - OVER) - 0.05)), V((sx * W, D + 0.05, roof_z(D + 0.05) - 0.05))
        T.tube([a, b], [0.028, 0.028], 6, CEDAR_DARK)
    # perche avant qui tient le debord de toile
    T.tube([(-W - 0.08, -D - OVER, roof_z(-D - OVER) - 0.05), (W + 0.08, -D - OVER, roof_z(-D - OVER) - 0.05)],
           [0.025, 0.025], 6, BAMBOO)


def canopy(T, stripe, stripe_dark):
    """Toile tendue, a rayures dans la profondeur, legerement creusee entre les traverses."""
    nx, ny = 16, 6
    x0, x1 = -W - 0.12, W + 0.12
    y0, y1 = -D - OVER - 0.02, D + 0.1

    def pos(u, v):
        x = x0 + (x1 - x0) * u
        y = y0 + (y1 - y0) * v
        sag = 0.035 * math.sin(math.pi * u) * math.sin(math.pi * v)
        return (x, y, roof_z(y) - sag)

    verts = [pos(i / nx, j / ny) for j in range(ny + 1) for i in range(nx + 1)]
    faces, cols = [], []
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + nx + 1, a + nx + 2, a + 1))
            cols.append(stripe if i % 2 == 0 else WHITE_CLOTH)
    off = len(verts)
    under = [(p[0], p[1], p[2] - 0.008) for p in verts]
    for k, f in enumerate(list(faces)):
        faces.append(tuple(reversed([i + off for i in f])))
        cols.append(stripe_dark if k % 2 == 0 else CLOTH_SHADE)
    T.add(verts + under, faces, lambda k: cols[k])
    # cotes : rabats festonnes sur les flancs
    for sx in (-1, 1):
        x = sx * (W + 0.12)
        pts = []
        n = 8
        for k in range(n + 1):
            y = y0 + (y1 - y0) * k / n
            pts.append((x, y, roof_z(y) - 0.03))
        for k in range(n):
            ya, yb = pts[k][1], pts[k + 1][1]
            za, zb = pts[k][2], pts[k + 1][2]
            ym = (ya + yb) / 2
            v = [(x, ya, za), (x, yb, zb), (x, yb, zb - 0.12), (x, ym, (za + zb) / 2 - 0.17), (x, ya, za - 0.12)]
            T.add(v, [(0, 1, 2, 3, 4)], stripe if k % 2 == 0 else WHITE_CLOTH)
            T.add(v, [(4, 3, 2, 1, 0)], stripe_dark if k % 2 == 0 else CLOTH_SHADE)


def valance(T, stripe, stripe_dark):
    """Lambrequin de l'avant : bande claire bordee de couleur, ou s'ecrit l'enseigne ; festons en bas."""
    y = -D - OVER - 0.03
    zt = roof_z(y) - 0.02
    zb = zt - 0.36
    xw = W + 0.12
    box(T, (0, y, (zt + zb) / 2), (2 * xw, 0.012, zt - zb), WHITE_CLOTH)
    box(T, (0, y - 0.004, zt - 0.025), (2 * xw, 0.008, 0.05), stripe)
    box(T, (0, y - 0.004, zb + 0.02), (2 * xw, 0.008, 0.04), stripe)
    # festons sous la bande
    n = 12
    for k in range(n):
        xa = -xw + 2 * xw * k / n
        xb = xa + 2 * xw / n
        xm = (xa + xb) / 2
        v = [(xa, y, zb), (xm, y, zb - 0.07), (xb, y, zb)]
        T.add(v, [(0, 1, 2)], stripe_dark if k % 2 else stripe)
        T.add(v, [(2, 1, 0)], stripe_dark)
    # cordon de chaque cote
    for sx in (-1, 1):
        T.tube([(sx * (xw - 0.04), y - 0.01, zt), (sx * (xw - 0.06), y - 0.03, zb - 0.1), (sx * (xw - 0.05), y - 0.03, zb - 0.2)],
               [0.01, 0.009, 0.006], 5, GOLD)
        T.ico((sx * (xw - 0.05), y - 0.03, zb - 0.24), (0.018, 0.018, 0.05), stripe_dark, subdiv=1, noise=0.1)
    empty("sign", loc=(0, y - 0.012, (zt + zb) / 2 + 0.005))
    for sx, nm in ((-1, "lantern_L"), (1, "lantern_R")):
        empty(nm, loc=(sx * (W - 0.05), -D - OVER + 0.06, zb - 0.38))
        T.tube([(sx * (W - 0.05), -D - OVER + 0.06, roof_z(-D - OVER) - 0.03),
                (sx * (W - 0.05), -D - OVER + 0.06, zb - 0.38 + 0.2)], [0.004, 0.004], 4, ROPE)


def back_wall(T, stripe):
    """Fond : planches basses et toile tendue jusqu'au toit."""
    y = D + 0.03
    for k in range(6):
        x = -W + 0.2 + k * (2 * W - 0.4) / 5
        box(T, (x, y, 0.5), ((2 * W) / 6 - 0.01, 0.025, 1.0), PLANK if k % 2 else PLANK_DARK)
    box(T, (0, y + 0.005, 1.68), (2 * W - 0.06, 0.012, 1.3), mixc(stripe, WHITE_CLOTH, 0.55))


def counter(T, drape=None):
    y0, y1 = -D - 0.05, -D + 0.38
    box(T, (0, (y0 + y1) / 2, COUNTER_Z), (2 * W + 0.06, y1 - y0, 0.05), TABLE)
    box(T, (0, y0 + 0.02, COUNTER_Z - 0.04), (2 * W + 0.06, 0.04, 0.05), TABLE_DARK)
    if drape is not None:
        # tissu qui retombe devant le comptoir, plis verticaux
        n = 14
        for k in range(n):
            xa = -W - 0.03 + (2 * W + 0.06) * k / n
            xb = xa + (2 * W + 0.06) / n
            dy = -0.012 if k % 2 else 0.0
            T.add([(xa, y0 - 0.01 + dy, COUNTER_Z - 0.03), (xb, y0 - 0.01 - dy - 0.012, COUNTER_Z - 0.03),
                   (xb, y0 - 0.01 - dy - 0.012, 0.03), (xa, y0 - 0.01 + dy, 0.03)], [(0, 1, 2, 3)],
                  drape if k % 2 else mixc(drape, WHITE_CLOTH, 0.12))
    else:
        # facade de planches verticales, joints sombres
        box(T, (0, y0 + 0.02, COUNTER_Z / 2), (2 * W - 0.1, 0.03, COUNTER_Z - 0.06), PLANK)
        for k in range(1, 8):
            x = -W + 0.05 + k * (2 * W - 0.1) / 8
            box(T, (x, y0 + 0.003, COUNTER_Z / 2), (0.012, 0.006, COUNTER_Z - 0.08), PLANK_DARK)
        box(T, (0, y0 + 0.0, 0.08), (2 * W - 0.06, 0.04, 0.1), TABLE_DARK)
    for sx in (-1, 1):
        box(T, (sx * (W - 0.05), (y0 + y1) / 2, COUNTER_Z / 2), (0.06, y1 - y0 - 0.04, COUNTER_Z), TABLE_DARK)


def kingyo_extras(T):
    # banc bas a l'arriere, et barre de sachets de poissons rouges
    box(T, (0, D - 0.18, 0.42), (2 * W - 0.3, 0.3, 0.04), TABLE)
    for sx in (-1, 1):
        box(T, (sx * (W - 0.25), D - 0.18, 0.21), (0.05, 0.26, 0.42), TABLE_DARK)
    zb = 1.55
    T.tube([(-W + 0.08, D - 0.08, zb), (W - 0.08, D - 0.08, zb)], [0.014, 0.014], 6, BAMBOO)
    rng = random.Random(4)
    for k in range(7):
        x = -W + 0.3 + k * (2 * W - 0.6) / 6
        z = zb - 0.24 - rng.uniform(0.0, 0.05)
        T.tube([(x, D - 0.08, zb), (x, D - 0.08, z + 0.1)], [0.003, 0.003], 3, ROPE)
        T.ico((x, D - 0.08, z), (0.07, 0.06, 0.09), BAG, subdiv=2, noise=0.04, seed=k)
        T.ico((x, D - 0.08, z - 0.03), (0.062, 0.052, 0.055), BAG_WATER, subdiv=2, noise=0.0)
        T.ico((x + 0.01, D - 0.14, z - 0.025), (0.022, 0.008, 0.012), FISH, subdiv=1, noise=0.0)
    # deux bacs a poissons en reserve, sous le banc
    for sx in (-1, 1):
        box(T, (sx * 0.45, D - 0.2, 0.09), (0.5, 0.32, 0.16), lin("#7FB6CC"))
        box(T, (sx * 0.45, D - 0.2, 0.165), (0.44, 0.26, 0.01), lin("#9CCBDA"))


# etageres du tir : trois planches etagees separees par un vide (un lot renverse vers l'arriere tombe dans le vide)
SHATEKI_SHELVES = [(0.95, -0.02), (1.2, 0.2), (1.45, 0.42)]     # (hauteur du dessus, y du centre) ; profondeur 0.15


def shateki_extras(T):
    for k, (z, y) in enumerate(SHATEKI_SHELVES):
        box(T, (0, y, z - 0.02), (2 * W - 0.24, 0.15, 0.04), TABLE)
        box(T, (0, y - 0.072, z - 0.01), (2 * W - 0.24, 0.012, 0.035), FELT_RED)        # chant de feutre
        box(T, (0, y + 0.0, z + 0.001), (2 * W - 0.26, 0.13, 0.004), FELT_RED)
        for sx in (-1, 1):
            box(T, (sx * (W - 0.14), y + 0.02, z / 2), (0.04, 0.04, z), TABLE_DARK)    # montants
    for sx in (-1, 1):                                                                    # longerons
        T.tube([(sx * (W - 0.14), -0.02, 0.5), (sx * (W - 0.14), 0.42, 0.5)], [0.018, 0.018], 6, TABLE_DARK)
    box(T, (0, D - 0.02, 1.1), (2 * W - 0.1, 0.02, 2.0), lin("#2E3350"))                # tenture sombre au fond
    # lots tombes au sol, entre les etageres (decor)
    box(T, (-0.3, 0.1, 0.05), (0.09, 0.04, 0.1), lin("#E8C34A"))
    T.ico((0.4, 0.32, 0.05), (0.05, 0.05, 0.05), RED, subdiv=1, noise=0.0)
    # fusils de liege poses debout dans un coin, sur le comptoir
    for k in range(2):
        x = W - 0.18 - k * 0.07
        T.tube([(x, -D + 0.05, COUNTER_Z + 0.02), (x - 0.02, -D + 0.1, COUNTER_Z + 0.62)], [0.012, 0.009], 6, TABLE_DARK)
        T.tube([(x - 0.02, -D + 0.1, COUNTER_Z + 0.62), (x - 0.025, -D + 0.11, COUNTER_Z + 0.75)], [0.006, 0.006], 5,
               lin("#5A5E64"))
    # petit panier de bouchons
    lathe(T, [(0.05, 0.0), (0.07, 0.07), (0.072, 0.075), (0.0, 0.01)], 10, (-W + 0.25, -D + 0.12),
          lambda k: TABLE_DARK)
    for k in range(6):
        a = k * 1.05
        T.ico((-W + 0.25 + 0.03 * math.cos(a), -D + 0.12 + 0.03 * math.sin(a), COUNTER_Z + 0.08), (0.012, 0.012, 0.014),
              lin("#C9A27A"), subdiv=1, noise=0.0)


def wanage_extras(T):
    # etageres de lots au fond : masques de renard, furin, petits jouets
    for k, z in enumerate((0.8, 1.25)):
        box(T, (0, D - 0.12, z), (2 * W - 0.2, 0.26, 0.035), TABLE)
    for sx in (-1, 1):
        box(T, (sx * (W - 0.12), D - 0.12, 0.65), (0.04, 0.26, 1.3), TABLE_DARK)
    rng = random.Random(7)
    for k in range(5):           # masques de renard (kitsune) accroches au fond
        x = -W + 0.35 + k * (2 * W - 0.7) / 4
        z = 1.72
        c = (x, D - 0.02, z)
        T.ico(c, (0.085, 0.03, 0.1), MASK, subdiv=2, noise=0.0)
        T.ico((x, D - 0.06, z - 0.04), (0.035, 0.035, 0.04), MASK, subdiv=1, noise=0.0)
        for sx in (-1, 1):
            T.ico((x + sx * 0.055, D - 0.02, z + 0.1), (0.022, 0.018, 0.045), MASK, subdiv=1, noise=0.0)
            T.ico((x + sx * 0.055, D - 0.042, z + 0.1), (0.012, 0.008, 0.028), MASK_RED, subdiv=1, noise=0.0)
            box(T, (x + sx * 0.035, D - 0.055, z + 0.01), (0.04, 0.006, 0.01), MASK_RED)
        T.ico((x, D - 0.09, z - 0.07), (0.012, 0.01, 0.01), INK, subdiv=1, noise=0.0)
        box(T, (x, D - 0.058, z + 0.06), (0.012, 0.006, 0.03), MASK_GOLD)
    for k in range(4):           # furin (clochettes de verre) sur l'etagere du haut
        x = -W + 0.4 + k * (2 * W - 0.8) / 3
        T.ico((x, D - 0.12, 1.25 + 0.08), (0.04, 0.04, 0.045), GLASS, subdiv=2, noise=0.0, bottom=0.2)
        T.tube([(x, D - 0.12, 1.25 + 0.035), (x, D - 0.12, 1.25 + 0.0)], [0.003, 0.003], 3, RED)
    for k in range(6):           # petites boites de lots sur l'etagere du bas
        x = -W + 0.3 + k * (2 * W - 0.6) / 5
        c = [RED, INDIGO2, GOLD, GREEN, PINK, CREAM][k]
        box(T, (x, D - 0.12, 0.8 + 0.07), (0.14, 0.12, 0.1 + 0.03 * (k % 2)), c)


def dango_extras(T):
    # rechaud a braises (shichirin) et brochettes, pile d'assiettes, sur le comptoir
    x0 = W - 0.4
    lathe(T, [(0.11, COUNTER_Z + 0.02), (0.12, COUNTER_Z + 0.12), (0.11, COUNTER_Z + 0.2), (0.0, COUNTER_Z + 0.2)], 12,
          (x0, -D + 0.15), lambda k: lin("#C9B28C"))
    for k in range(5):
        T.tube([(x0 - 0.12, -D + 0.08 + k * 0.035, COUNTER_Z + 0.22), (x0 + 0.12, -D + 0.08 + k * 0.035, COUNTER_Z + 0.22)],
               [0.003, 0.003], 3, lin("#B79C6E"))
        for j in range(3):
            T.ico((x0 - 0.03 + j * 0.03, -D + 0.08 + k * 0.035, COUNTER_Z + 0.235), (0.013, 0.013, 0.012),
                  lin("#E8C890"), subdiv=1, noise=0.0)
    T.ico((x0, -D + 0.15, COUNTER_Z + 0.205), (0.09, 0.09, 0.01), EMBER, subdiv=1, noise=0.2)
    for k in range(4):
        lathe(T, [(0.07, COUNTER_Z + 0.025 + k * 0.018), (0.09, COUNTER_Z + 0.04 + k * 0.018), (0.0, COUNTER_Z + 0.03 + k * 0.018)],
              14, (-W + 0.3, -D + 0.15), lambda kk: PLATE)
    # jarre de sucre et bols au fond
    lathe(T, [(0.1, 0.0), (0.14, 0.2), (0.12, 0.38), (0.08, 0.42), (0.0, 0.42)], 12, (-W + 0.35, D - 0.2),
          lambda k: lin("#6E4A3A"))


def yatai(kind):
    reset_scene()
    v = VARIANTS[kind]
    T = TM()
    frame(T)
    canopy(T, v["stripe"], v["stripe_dark"])
    valance(T, v["stripe"], v["stripe_dark"])
    back_wall(T, v["stripe"])
    if v["counter"]:
        counter(T, drape=v["stripe"] if kind == "dango" else None)
    {"kingyo": kingyo_extras, "shateki": shateki_extras, "wanage": wanage_extras, "dango": dango_extras}[kind](T)
    T.build("booth")
    collision_box("back", (2 * W + 0.1, 0.12, 2.2), (0, D + 0.05, 1.1))
    for sx, nm in ((-1, "postL"), (1, "postR")):
        collision_box(nm, (0.1, 2 * D + 0.1, 2.0), (sx * W, 0, 1.0))
    if v["counter"]:
        collision_box("counter", (2 * W + 0.1, 0.45, COUNTER_Z + 0.03), (0, -D + 0.16, (COUNTER_Z + 0.03) / 2))
    finish_tree("yatai_" + kind, expected_dims=(2.6, 1.6, 2.4), tri_limit=(400, 9000), trunk_angle=35, yaw=-28,
                pitch=12, margin=1.05)


ALL_Y = {"yatai_" + k: (lambda kk=k: yatai(kk)) for k in VARIANTS}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in (argv or list(ALL_Y)):
        ALL_Y[a]()
