"""Lancer d'anneaux (wanage) de la fete de Tsukimi.

- wanage_ring : anneau de corde tressee entoure de bandes rouges et blanches (diametre 17 cm). Origine au centre,
  a plat (axe Z de Blender = axe Y de Godot).
- wanage_peg  : piquet de bois a tete ronde, petite plaque ou le jeu ecrit les points (repere « plaque »).
  Origine au pied ; la hauteur est donnee par le jeu (le modele fait 30 cm, mis a l'echelle en Y).
- wanage_mat  : natte de paille (goza) bordee de tissu sombre, posee au sol, ou sont plantes les piquets.
- wanage_line : la ligne de lancer, une corde tendue entre deux piquets.
Un seul materiau par objet (couleurs aux sommets). Lancer : blender --background --python tools/blender/wanage.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from festival import *

ROPE_C = lin("#D9C48E")
RING_RED = lin("#C9432C")
RING_WHITE = lin("#F2ECDD")
PEG_WOOD = lin("#C79A64")
PEG_DARK = lin("#8E6A44")
PLAQUE = lin("#F1E8D2")
MAT = lin("#CDB676")
MAT_DARK = lin("#B49C5E")
MAT_EDGE = lin("#2F3A2C")


def wanage_ring():
    reset_scene()
    T = TM()
    Rc, r = 0.075, 0.0105
    n, m = 40, 8
    verts, faces, cols = [], [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        for j in range(m):
            b = 2 * math.pi * j / m
            rr = Rc + r * math.cos(b)
            # torsade de la corde : legere ondulation de la section
            k = 1.0 + 0.08 * math.sin(6 * b + a * 18)
            verts.append((rr * math.cos(a), rr * math.sin(a), r * k * math.sin(b)))
    for i in range(n):
        for j in range(m):
            i2, j2 = (i + 1) % n, (j + 1) % m
            faces.append((i * m + j, i2 * m + j, i2 * m + j2, i * m + j2))
            band = (i // 5) % 2
            cols.append(RING_RED if band == 0 else RING_WHITE)
    T.add(verts, faces, lambda k: cols[k])
    T.build("ring")
    finish_tree("wanage_ring", expected_dims=(0.17, 0.17, 0.021), tri_limit=(200, 2000), trunk_angle=60, yaw=-20,
                pitch=45, margin=1.2)


def wanage_peg():
    reset_scene()
    T = TM()
    H = 0.30
    T.tube([(0, 0, -0.04), (0, 0, H - 0.02)], [0.016, 0.014], 10, PEG_WOOD)
    T.ico((0, 0, H - 0.012), (0.019, 0.019, 0.016), PEG_DARK, subdiv=2, noise=0.0)
    for z in (0.03, H * 0.5):
        T.tube([(0, 0, z - 0.004), (0, 0, z + 0.004)], [0.0165, 0.0165], 10, PEG_DARK)
    # plaque a l'avant (-Y), clouee sous la tete
    box(T, (0, -0.017, H - 0.075), (0.05, 0.006, 0.06), PLAQUE)
    box(T, (0, -0.0205, H - 0.075 + 0.026), (0.05, 0.002, 0.006), RING_RED)
    T.build("peg")
    empty("plaque", loc=(0, -0.0215, H - 0.08))
    finish_tree("wanage_peg", expected_dims=(0.05, 0.04, 0.34), tri_limit=(60, 1500), trunk_angle=40, yaw=-20,
                pitch=10, margin=1.2)


def wanage_mat():
    reset_scene()
    T = TM()
    hx, hy = 0.85, 0.7
    nx = 14
    for i in range(nx):
        x0 = -hx + 2 * hx * i / nx
        box(T, (x0 + hx / nx, 0, 0.012), (2 * hx / nx - 0.002, 2 * hy, 0.024), MAT if i % 2 else MAT_DARK)
    for sy in (-1, 1):
        box(T, (0, sy * (hy + 0.02), 0.014), (2 * hx + 0.08, 0.05, 0.028), MAT_EDGE)
    for sx in (-1, 1):
        box(T, (sx * (hx + 0.02), 0, 0.014), (0.05, 2 * hy + 0.08, 0.028), MAT_EDGE)
    T.build("mat")
    finish_tree("wanage_mat", expected_dims=(1.8, 1.5, 0.03), tri_limit=(60, 1500), trunk_angle=30, yaw=-20,
                pitch=40, margin=1.1)


def wanage_line():
    reset_scene()
    T = TM()
    hx = 0.8
    for sx in (-1, 1):
        T.tube([(sx * hx, 0, -0.03), (sx * hx, 0, 0.12)], [0.012, 0.01], 6, PEG_DARK)
        T.ico((sx * hx, 0, 0.125), (0.014, 0.014, 0.01), PEG_DARK, subdiv=1, noise=0.0)
    pts = [(-hx + 2 * hx * k / 12, 0, 0.1 - 0.06 * math.sin(math.pi * k / 12)) for k in range(13)]
    T.tube(pts, [0.006] * 13, 5, RING_RED)
    for k in range(1, 12, 2):
        x = -hx + 2 * hx * k / 12
        T.ico((x, 0, 0.1 - 0.06 * math.sin(math.pi * k / 12) - 0.012), (0.012, 0.003, 0.02), RING_WHITE, subdiv=1,
              noise=0.0)
    T.build("line")
    finish_tree("wanage_line", expected_dims=(1.62, 0.03, 0.16), tri_limit=(60, 1500), trunk_angle=40, yaw=-10,
                pitch=15, margin=1.1)


ALL_W = {"wanage_ring": wanage_ring, "wanage_peg": wanage_peg, "wanage_mat": wanage_mat, "wanage_line": wanage_line}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in (argv or list(ALL_W)):
        ALL_W[a]()
