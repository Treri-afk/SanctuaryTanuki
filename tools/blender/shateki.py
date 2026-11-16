"""Lots et fusil du tir au bouchon (shateki) de la fete de Tsukimi.

Lots (origine au centre du dessous, avant -Y = +Z dans Godot), poses debout sur les etageres et renverses
par les bouchons (le jeu leur donne une forme de collision simple) :
- lot_daruma  : daruma rouge, visage blanc (un oeil peint, l'autre en attente du voeu), ventre lesté ;
- lot_maneki  : maneki-neko blanc assis, patte levee, collier rouge et grelot, piece d'or ;
- lot_kokeshi : poupee de bois, corps cylindrique peint de fleurs, tete ronde ;
- lot_ame     : boite de caramels (carton creme, bande rouge, dessin de lune) ;
- lot_tanuki  : petit tanuki de terre cuite (chapeau de paille, gourde de sake).
Fusil a bouchon (cork_gun) : crosse de bois, canon de metal, levier ; tenu en main, canon vers -Y (= +Z Godot
vers l'avant de la camera : le jeu le tourne), repere « muzzle » au bout du canon.
Un seul materiau par objet (couleurs aux sommets, voir tree_util).
Lancer : blender --background --python tools/blender/shateki.py [-- lot_daruma ...]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from festival import *

DARUMA_RED = lin("#C93A26")
DARUMA_DARK = lin("#9E2C1C")
FACE = lin("#F4ECDD")
GOLD2 = lin("#D9AE4C")
BLACK = lin("#232026")
CAT_WHITE = lin("#F6F2EA")
CAT_SHADE = lin("#E3DCD0")
PINK = lin("#E9A3A6")
ORANGE = lin("#E0913E")
COLLAR = lin("#C93A26")
KOKESHI_WOOD = lin("#E8D2A6")
KOKESHI_RED = lin("#C9432C")
KOKESHI_GREEN = lin("#5E7F4A")
HAIR = lin("#26222A")
BOX_CREAM = lin("#F2E3B8")
BOX_RED = lin("#C93A26")
BOX_BLUE = lin("#2E3A5C")
CLAY = lin("#8A5E3E")
CLAY_DARK = lin("#6B4630")
CLAY_BELLY = lin("#C9A27C")
STRAW = lin("#D8B86A")
STOCK = lin("#8C5A34")
STOCK_DARK = lin("#5E3A22")
METAL = lin("#5A5E64")
METAL_LIGHT = lin("#8E959C")
CORK = lin("#C9A27A")


def finish(name, dims, views=()):
    finish_tree(name, expected_dims=dims, tri_limit=(100, 4000), trunk_angle=40, yaw=-25, pitch=12, margin=1.15,
                views=views)


# ------------------------------------------------------------------ daruma
def lot_daruma():
    reset_scene()
    T = TM()
    H = 0.13
    # corps : oeuf un peu aplati, plus large en bas
    prof = [(0.0, 0.0), (0.035, 0.003), (0.052, 0.018), (0.058, 0.045), (0.054, 0.075), (0.045, 0.1),
            (0.03, 0.12), (0.0, H)]
    lathe(T, prof, 24, (0, 0), lambda k: DARUMA_RED, phase=0.0)
    # visage : disque blanc bombe a l'avant
    T.ico((0, -0.04, 0.078), (0.032, 0.016, 0.03), FACE, subdiv=2, noise=0.0)
    for sx in (-1, 1):
        T.ico((sx * 0.013, -0.054, 0.083), (0.008, 0.004, 0.008), FACE, subdiv=1, noise=0.0)       # yeux blancs
        T.ico((sx * 0.017, -0.055, 0.096), (0.011, 0.004, 0.004), BLACK, subdiv=1, noise=0.0)      # sourcils
        T.ico((sx * 0.016, -0.054, 0.066), (0.012, 0.004, 0.005), BLACK, subdiv=1, noise=0.0)      # moustache
    T.ico((-0.013, -0.058, 0.083), (0.004, 0.003, 0.004), BLACK, subdiv=1, noise=0.0)               # un seul oeil peint
    # motifs dores sur le ventre
    T.ico((0, -0.05, 0.03), (0.028, 0.008, 0.012), GOLD2, subdiv=1, noise=0.0)
    for sx in (-1, 1):
        T.ico((sx * 0.04, -0.035, 0.035), (0.01, 0.01, 0.016), GOLD2, subdiv=1, noise=0.0)
    T.build("daruma")
    finish("lot_daruma", (0.12, 0.12, 0.13))


# ------------------------------------------------------------------ maneki-neko
def lot_maneki():
    reset_scene()
    T = TM()
    T.ico((0, 0, 0.045), (0.042, 0.036, 0.046), CAT_WHITE, subdiv=2, noise=0.0, bottom=0.6)        # corps
    T.ico((0, -0.004, 0.105), (0.04, 0.034, 0.034), CAT_WHITE, subdiv=2, noise=0.0)                # tete
    for sx in (-1, 1):
        ear = [(sx * 0.022, -0.004, 0.128), (sx * 0.038, -0.004, 0.13), (sx * 0.03, -0.006, 0.152)]
        T.add(ear + [(p[0], p[1] + 0.01, p[2]) for p in ear], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)],
              CAT_WHITE)
        T.add([(sx * 0.025, -0.0065, 0.131), (sx * 0.035, -0.0065, 0.132), (sx * 0.03, -0.0075, 0.146)], [(0, 1, 2)], PINK)
        T.ico((sx * 0.014, -0.034, 0.108), (0.0055, 0.003, 0.004), BLACK, subdiv=1, noise=0.0)       # yeux plisses
        T.ico((sx * 0.022, -0.03, 0.096), (0.006, 0.003, 0.004), PINK, subdiv=1, noise=0.0)          # joues
    T.ico((0, -0.036, 0.1), (0.003, 0.002, 0.0025), PINK, subdiv=1, noise=0.0)                      # nez
    T.ico((0.018, 0.0, 0.122), (0.012, 0.03, 0.01), ORANGE, subdiv=1, noise=0.0)                     # tache
    # collier, grelot, piece (koban)
    T.tube([(math.cos(a) * 0.033, math.sin(a) * 0.028 - 0.002, 0.08) for a in [k * math.pi / 8 for k in range(17)]],
           [0.005] * 17, 5, COLLAR, cap_end=False)
    T.ico((0, -0.032, 0.073), (0.008, 0.007, 0.008), GOLD2, subdiv=1, noise=0.0)
    T.ico((-0.012, -0.036, 0.04), (0.016, 0.004, 0.022), GOLD2, subdiv=2, noise=0.0)
    # patte levee (droite) et patte posee
    T.tube([(0.028, -0.012, 0.07), (0.04, -0.018, 0.1), (0.04, -0.02, 0.125)], [0.011, 0.01, 0.01], 8, CAT_WHITE)
    T.ico((0.04, -0.02, 0.13), (0.011, 0.01, 0.011), CAT_WHITE, subdiv=1, noise=0.0)
    T.ico((0.012, -0.032, 0.012), (0.012, 0.012, 0.01), CAT_SHADE, subdiv=1, noise=0.0)
    T.ico((0, 0.0, 0.003), (0.042, 0.036, 0.004), CAT_SHADE, subdiv=1, noise=0.0)                   # socle
    T.build("maneki")
    finish("lot_maneki", (0.09, 0.08, 0.16))


# ------------------------------------------------------------------ kokeshi
def lot_kokeshi():
    reset_scene()
    T = TM()
    body = [(0.0, 0.0), (0.022, 0.0), (0.024, 0.01), (0.02, 0.06), (0.019, 0.1), (0.016, 0.112), (0.0, 0.114)]

    def col(k):
        return KOKESHI_WOOD

    lathe(T, body, 18, (0, 0), col)
    # bandes et fleurs peintes
    for z, c in ((0.012, KOKESHI_RED), (0.103, KOKESHI_RED)):
        T.tube([(0, 0, z - 0.003), (0, 0, z + 0.003)], [0.0235 - 0.03 * (z > 0.05) * 0.1, 0.0235 - 0.003 * (z > 0.05)], 18, c)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        for j, z in enumerate((0.035, 0.07)):
            aa = a + j * 0.6
            p = (math.cos(aa) * 0.0205, math.sin(aa) * 0.0205, z)
            T.ico(p, (0.008, 0.008, 0.008), KOKESHI_RED if (k + j) % 2 else PINK, subdiv=1, noise=0.0)
            T.ico((p[0] * 1.02, p[1] * 1.02, z + 0.012), (0.005, 0.005, 0.004), KOKESHI_GREEN, subdiv=1, noise=0.0)
    # tete et cheveux
    T.ico((0, 0, 0.138), (0.026, 0.026, 0.025), KOKESHI_WOOD, subdiv=2, noise=0.0)
    T.ico((0, 0.005, 0.146), (0.0268, 0.025, 0.02), HAIR, subdiv=2, noise=0.0, bottom=0.6)
    for sx in (-1, 1):
        T.ico((sx * 0.009, -0.024, 0.134), (0.004, 0.0025, 0.0015), BLACK, subdiv=1, noise=0.0)
    T.ico((0, -0.025, 0.126), (0.003, 0.002, 0.0015), KOKESHI_RED, subdiv=1, noise=0.0)
    T.ico((-0.02, 0.0, 0.157), (0.008, 0.008, 0.006), KOKESHI_RED, subdiv=1, noise=0.0)               # noeud
    T.build("kokeshi")
    finish("lot_kokeshi", (0.054, 0.054, 0.165))


# ------------------------------------------------------------------ boite de caramels
def lot_ame():
    reset_scene()
    T = TM()
    w, d, h = 0.07, 0.03, 0.11
    box(T, (0, 0, h / 2), (w, d, h), BOX_CREAM)
    box(T, (0, -d / 2 - 0.0008, h * 0.62), (w + 0.0005, 0.0016, 0.03), BOX_RED)
    box(T, (0, d / 2 + 0.0008, h * 0.62), (w + 0.0005, 0.0016, 0.03), BOX_RED)
    box(T, (0, -d / 2 - 0.001, h * 0.2), (w * 0.8, 0.0016, 0.012), BOX_BLUE)
    disc(T, (0.0, -d / 2 - 0.002, h * 0.36), 0.014, GOLD2, 16)                                      # lune
    disc(T, (0.006, -d / 2 - 0.0028, h * 0.38), 0.012, BOX_CREAM, 16)
    box(T, (0, 0, h + 0.001), (w * 0.96, d * 0.9, 0.002), BOX_RED)
    T.build("ame")
    finish("lot_ame", (0.07, 0.03, 0.11))


# ------------------------------------------------------------------ tanuki de Shigaraki
def lot_tanuki():
    reset_scene()
    T = TM()
    T.ico((0, 0, 0.038), (0.034, 0.03, 0.038), CLAY, subdiv=2, noise=0.02, bottom=0.7)              # corps
    T.ico((0, -0.018, 0.034), (0.026, 0.016, 0.026), CLAY_BELLY, subdiv=2, noise=0.0)              # gros ventre
    T.ico((0, -0.004, 0.085), (0.026, 0.024, 0.023), CLAY, subdiv=2, noise=0.02)                   # tete
    T.ico((0, -0.025, 0.08), (0.011, 0.009, 0.008), CLAY_BELLY, subdiv=1, noise=0.0)               # museau
    T.ico((0, -0.033, 0.082), (0.004, 0.003, 0.003), BLACK, subdiv=1, noise=0.0)
    for sx in (-1, 1):
        T.ico((sx * 0.011, -0.021, 0.09), (0.008, 0.004, 0.006), CLAY_DARK, subdiv=1, noise=0.0)    # masque
        T.ico((sx * 0.011, -0.024, 0.091), (0.003, 0.002, 0.003), BLACK, subdiv=1, noise=0.0)
        T.ico((sx * 0.017, 0.0, 0.106), (0.007, 0.005, 0.008), CLAY_DARK, subdiv=1, noise=0.0)      # oreilles
        T.ico((sx * 0.016, -0.016, 0.006), (0.01, 0.012, 0.006), CLAY_DARK, subdiv=1, noise=0.0)    # pieds
    # chapeau de paille et gourde
    lathe(T, [(0.036, 0.0), (0.034, 0.003), (0.016, 0.012), (0.0, 0.016)], 16, (0, 0), lambda k: STRAW)
    for o in bpy.context.scene.objects:
        pass
    T.ico((0.0, 0.0, 0.1), (0.036, 0.034, 0.004), STRAW, subdiv=2, noise=0.0)
    T.ico((0.0, 0.0, 0.106), (0.017, 0.016, 0.01), STRAW, subdiv=1, noise=0.0)
    T.ico((0.03, -0.012, 0.04), (0.012, 0.011, 0.016), lin("#E8DCC0"), subdiv=1, noise=0.0)
    T.ico((0.03, -0.012, 0.06), (0.005, 0.005, 0.006), lin("#E8DCC0"), subdiv=1, noise=0.0)
    T.build("tanuki")
    finish("lot_tanuki", (0.075, 0.07, 0.12))


# ------------------------------------------------------------------ fusil a bouchon
def cork_gun():
    reset_scene()
    T = TM()
    # crosse : section ovale qui s'evase vers l'arriere (+Y), poignee pistolet
    stock = [(0.0, 0.10, 0.0), (0.0, 0.18, -0.008), (0.0, 0.27, -0.02), (0.0, 0.33, -0.03)]
    T.tube(stock, [0.017, 0.02, 0.026, 0.03], 10, STOCK)
    box(T, (0, 0.335, -0.03), (0.03, 0.012, 0.075), STOCK_DARK)                                  # plaque de couche
    T.tube([(0, 0.13, -0.01), (0, 0.15, -0.06), (0, 0.16, -0.085)], [0.012, 0.011, 0.012], 8, STOCK)
    # fut et canon
    T.tube([(0, -0.12, 0.004), (0, 0.11, 0.0)], [0.015, 0.016], 10, STOCK)
    T.tube([(0, -0.3, 0.018), (0, 0.04, 0.016)], [0.0095, 0.0095], 12, METAL)
    T.tube([(0, -0.305, 0.018), (0, -0.29, 0.018)], [0.011, 0.011], 12, METAL_LIGHT)             # bouche
    for y in (-0.2, -0.05):
        T.tube([(0, y - 0.006, 0.012), (0, y + 0.006, 0.012)], [0.018, 0.018], 10, METAL_LIGHT)   # bagues
    # levier d'armement sous le fut, pontet
    T.tube([(0, 0.02, -0.012), (0, -0.06, -0.022), (0, -0.1, -0.02)], [0.005, 0.005, 0.005], 5, METAL)
    T.tube([(0, 0.105, -0.012), (0, 0.112, -0.04), (0, 0.135, -0.04), (0, 0.14, -0.015)], [0.003] * 4, 4, METAL)
    T.build("gun")
    empty("muzzle", loc=(0, -0.312, 0.018))
    finish_tree("cork_gun", expected_dims=(0.06, 0.65, 0.12), tri_limit=(100, 3000), trunk_angle=40, yaw=-60,
                pitch=12, margin=1.1)


ALL_S = {"lot_daruma": lot_daruma, "lot_maneki": lot_maneki, "lot_kokeshi": lot_kokeshi, "lot_ame": lot_ame,
         "lot_tanuki": lot_tanuki, "cork_gun": cork_gun}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in (argv or list(ALL_S)):
        ALL_S[a]()
