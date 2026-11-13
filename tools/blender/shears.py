"""Cisaille a haie japonaise (kariko-basami) : deux longues lames droites a biseau qui se croisent sur un
boulon, soies d'acier, viroles, longs manches de chene ovales termines par un talon.
Deux objets « arm_l » et « arm_r » dont l'origine est sur l'axe du boulon : on peut les faire pivoter
(rotation autour de l'axe Y de Blender = Z de Godot) pour un geste de coupe. Un objet « pivot » (boulon).
Tenue en main : lames en haut, origine au bout des manches. Pas de collision.
Lancer : blender --background --python tools/blender/shears.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1

PIVOT = Vector((0.0, 0.0, 0.360))
OPEN = math.radians(6.0)       # demi-ouverture au repos
LAYER = 0.0034                 # les lames glissent l'une sur l'autre : decalage en Y de chaque bras


def build_arm(name, s):
    """Bras dans son repere local (pivot a l'origine, le long de Z), puis incline de s * OPEN.
    s = -1 : bras gauche (manche a gauche en bas, lame a droite en haut) ; s = +1 : l'inverse."""
    y = -s * LAYER
    edge = Vector((-s, 0, 0))         # le fil regarde vers l autre lame (bras incline de s * OPEN autour de Y)
    out = -s                          # cote du manche, vers l'exterieur
    CRANK = 0.0105                    # soie coudee : les manches s'ecartent sous le pivot
    M = Mesh()

    # ---- lame : longue, droite, s'affine vers une pointe arrondie
    L0, L1 = 0.018, 0.252
    n = 9
    path = [(0.0, y, L0 + (L1 - L0) * i / (n - 1)) for i in range(n)]
    widths = [0.036, 0.0355, 0.034, 0.032, 0.0295, 0.0268, 0.0238, 0.0195, 0.0105]
    thick = [0.0026, 0.0026, 0.0025, 0.0024, 0.0023, 0.0021, 0.0020, 0.0018, 0.0014]

    def sec(i):
        # dos a l'exterieur (cote -edge), fil vers l'interieur ; le dos est decale pour que la lame
        # reste centree sur l'axe du bras a la racine et que la pointe remonte vers le dos
        w = widths[i]
        off = -0.016 + 0.006 * (i / (n - 1)) ** 2
        return [(off + u, v) for u, v in blade_section(w, thick[i], bevel=0.34)]

    rings = []
    for i, p in enumerate(path):
        p = Vector(p)
        rings.append([p + edge * su + Vector((0, 1, 0)) * sv for su, sv in sec(i)])

    def blade_mat(i, j):
        if j in (3, 4):            # faces du biseau : le fil brille
            return "steel_edge"
        if j in (0, 1, 7):
            return "steel_dark"
        return "steel"

    M.loft(rings, blade_mat, True, True)

    # ---- talon de lame autour du boulon (disque aplati)
    disk = ring((0, y, 0.004), (1, 0, 0), (0, 0, 1), 0.0215, 0.0235, 14, 2.0)
    back = [p + Vector((0, -0.0026, 0)) for p in disk]
    front = [p + Vector((0, 0.0026, 0)) for p in disk]
    M.loft([back, front], "steel", True, True)

    # ---- soie sous le pivot, jusqu'a la virole (barre ovale qui s'affine)
    shank = [(0.0, y, -0.006), (out * 0.0035, y, -0.033), (out * CRANK, y, -0.062)]
    sh_r = [(0.0105, 0.0042), (0.0085, 0.0046), (0.0072, 0.0050)]
    M.loft([ring(p, (1, 0, 0), (0, 1, 0), rx, ry, 8, 2.6) for p, (rx, ry) in zip(shank, sh_r)], "forge", True, True)

    # ---- virole d'acier (bague legerement bombee)
    fz = [-0.060, -0.064, -0.078, -0.092, -0.096]
    fr = [0.0098, 0.0118, 0.0124, 0.0118, 0.0101]
    M.loft([ring((out * CRANK, y, z), (1, 0, 0), (0, 1, 0), r, r * 0.86, 12, 2.0) for z, r in zip(fz, fr)],
           lambda i, j: "steel" if i in (1, 2) else "steel_dark", True, True)

    # ---- manche de chene (ovale, plus large au talon)
    radii = [
        (0.000, 0.0085, 0.0074),
        (0.020, 0.0135, 0.0118),
        (0.060, 0.0148, 0.0128),   # talon : la paume s'y appuie
        (0.130, 0.0132, 0.0114),
        (0.400, 0.0121, 0.0105),
        (0.700, 0.0116, 0.0101),
        (0.930, 0.0110, 0.0096),
        (0.985, 0.0101, 0.0089),
        (1.000, 0.0092, 0.0082),
    ]
    mats = [(0.0, "oak_dark"), (0.020, "oak"), (0.130, "oak_worn"), (0.700, "oak")]
    H = Mesh()
    wooden_handle(H, -PIVOT.z, -0.094, radii, mats, sides=12, expo=2.3,
                  curve=lambda t: (out * (CRANK + 0.008 * (1.0 - t) ** 1.3 + 0.003 * math.sin(math.pi * t)), 0.0))
    absorb(M, H, (0.0, y, 0.0))     # meme plan que la lame

    o = M.build(name, loc=PIVOT)
    o.rotation_euler = (0.0, s * OPEN, 0.0)
    return o


arm_l = build_arm("arm_l", -1)
arm_r = build_arm("arm_r", 1)

# ---- boulon : tete bombee devant, ecrou et rondelle derriere
B = Mesh()
B.lathe([(0.0, 0.0), (0.0098, 0.0), (0.0098, 0.0016), (0.0084, 0.0036), (0.0050, 0.0050), (0.0, 0.0054)], 12,
        "steel_dark")
head_v = [(x, z + LAYER + 0.0026, -y) for x, y, z in B.v]   # couche la tete sur l'axe Y (face avant)
B.v = head_v
N = Mesh()
N.lathe([(0.0, 0.0), (0.0110, 0.0), (0.0110, 0.0012), (0.0080, 0.0014), (0.0080, 0.0050), (0.0, 0.0050)], 6,
        "forge")
N.v = [(x, -(z + LAYER + 0.0026), y) for x, y, z in N.v]
B.add(N.v, N.f, "forge")
pivot = B.build("pivot", loc=PIVOT)

collision = None

pfinish("shears", expected_dims=(0.12, 0.03, 0.61), tri_limit=(400, 3000),
        angles={"arm_l": math.radians(40), "arm_r": math.radians(40), "pivot": math.radians(35)},
        yaw=20, pitch=10, margin=1.2,
        extra_views=[("_b", dict(yaw=-70, pitch=25, margin=1.1)), ("_top", dict(yaw=10, pitch=8, margin=0.55))])
