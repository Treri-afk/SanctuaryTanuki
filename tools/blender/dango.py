"""Pyramide de dango (tsukimi dango) : le stand de Madame Fumiko a la fete de Tsukimi.

- sanbo  : plateau d'offrande en hinoki clair (sanbo) : plateau a rebord bas sur un pied a trois faces percees
  (kurikata), feuille de papier blanc pliee posee dessus. Origine au centre du dessous ; repere « tray » au
  dessus du papier (le jeu y empile les dango).
- hashi  : paire de baguettes de service, laquees, bouts clairs ; tenues en main au-dessus du plateau.
  Origine aux bouts (la ou se tient la boulette), baguettes vers +Y (= -Z dans Godot) et vers le haut.
- dango_ball : boulette de riz blanche, a peine aplatie, legerement irreguliere (r = 19 mm).
Un seul materiau par objet (couleurs aux sommets). Lancer : blender --background --python tools/blender/dango.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from festival import *

HINOKI_L = lin("#E6D2AE")
HINOKI_M = lin("#D4BC92")
HINOKI_E = lin("#BFA47E")
PAPER = lin("#F7F3EA")
PAPER_SH = lin("#E8E1D2")
LACQUER = lin("#9E2C1C")
LACQUER_D = lin("#6E1E14")
TIP = lin("#E9D8B4")
RICE = lin("#F6F1E6")


def sanbo():
    reset_scene()
    T = TM()
    hw, rim_h, tray_t = 0.135, 0.012, 0.012
    z_tray = 0.15
    # pied : boite a trois faces visibles, percee d'un motif en cloche (kurikata) sur les faces
    bw, bh = 0.095, z_tray
    for sx, sy, w, d in ((0, -bw, 2 * bw, 0.008), (0, bw, 2 * bw, 0.008), (-bw, 0, 0.008, 2 * bw), (bw, 0, 0.008, 2 * bw)):
        box(T, (sx, sy, bh / 2), (w, d, bh), HINOKI_M)
    for (x, y, nx, ny) in ((0, -bw - 0.005, 0, -1), (-bw - 0.005, 0, -1, 0), (bw + 0.005, 0, 1, 0)):
        # trou en forme de cloche, figure par une piece sombre en retrait
        c = (x, y, bh * 0.5)
        if nx == 0:
            box(T, c, (0.06, 0.002, 0.05), HINOKI_E)
            T.ico((x, y, bh * 0.5 + 0.025), (0.03, 0.001, 0.02), HINOKI_E, subdiv=1, noise=0.0)
        else:
            box(T, c, (0.002, 0.06, 0.05), HINOKI_E)
            T.ico((x, y, bh * 0.5 + 0.025), (0.001, 0.03, 0.02), HINOKI_E, subdiv=1, noise=0.0)
    box(T, (0, 0, 0.004), (2 * bw + 0.03, 2 * bw + 0.03, 0.008), HINOKI_E)          # semelle
    # plateau (oshiki) : fond et rebord bas, coins coupes
    box(T, (0, 0, z_tray + tray_t / 2), (2 * hw, 2 * hw, tray_t), HINOKI_L)
    for s in (-1, 1):
        box(T, (0, s * (hw - 0.004), z_tray + tray_t + rim_h / 2), (2 * hw, 0.008, rim_h), HINOKI_M)
        box(T, (s * (hw - 0.004), 0, z_tray + tray_t + rim_h / 2), (0.008, 2 * hw, rim_h), HINOKI_M)
    # papier plie en diagonale
    top = z_tray + tray_t
    T.add([(-0.1, -0.1, top + 0.001), (0.1, -0.1, top + 0.001), (0.1, 0.1, top + 0.001), (-0.1, 0.1, top + 0.001)],
          [(0, 1, 2, 3)], PAPER)
    T.add([(0.1, -0.1, top + 0.0015), (0.12, 0.0, top + 0.0015), (0.1, 0.1, top + 0.0015)], [(0, 1, 2)], PAPER_SH)
    T.build("sanbo")
    empty("tray", loc=(0, 0, top + 0.002))
    finish_tree("sanbo", expected_dims=(0.27, 0.27, 0.2), tri_limit=(60, 1500), trunk_angle=30, yaw=-25, pitch=25,
                margin=1.2)


def hashi():
    reset_scene()
    T = TM()
    for sx in (-1, 1):
        a = V((sx * 0.004, 0.0, 0.0))
        b = V((sx * 0.012, 0.21, 0.07))
        mid = a + (b - a) * 0.3
        T.tube([a, mid], [0.0016, 0.0026], 6, TIP)
        T.tube([mid, b], [0.0026, 0.0042], 6, lambda i, j, p: LACQUER if p.y < 0.17 else LACQUER_D)
    T.build("hashi")
    finish_tree("hashi", expected_dims=(0.03, 0.21, 0.07), tri_limit=(20, 800), trunk_angle=40, yaw=-60, pitch=20,
                margin=1.2)


def dango_ball():
    reset_scene()
    T = TM()
    T.ico((0, 0, 0), (0.0195, 0.0195, 0.0182), RICE, subdiv=3, noise=0.012, seed=3)
    T.build("ball")
    finish_tree("dango_ball", expected_dims=(0.039, 0.039, 0.036), tri_limit=(100, 2000), trunk_angle=80, yaw=0,
                pitch=30, margin=1.4)


ALL_D = {"sanbo": sanbo, "hashi": hashi, "dango_ball": dango_ball}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in (argv or list(ALL_D)):
        ALL_D[a]()
