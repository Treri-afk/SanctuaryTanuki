"""Shishi-odoshi (le « fait-peur-aux-cerfs ») au bord de la mare : un filet d'eau tombe d'une goulotte de bambou
(kakehi) dans un tube de bambou monte sur un axe ; plein, le tube bascule, se vide dans la vasque de pierre, puis
retombe et frappe une pierre : « toc ». scripts/landmarks.gd anime le tube (objet « tube », origine sur l'axe).

Reperes Blender : l'avant (-Y) devient +Z dans Godot. Le tube est le long de Y : bouche ouverte vers -Y (sous la
goulotte), bout ferme vers +Y (sur la pierre). Au repos, le bout ferme est en bas ; rotation autour de X.
Objets : frame (poteaux, axe, goulotte), stones (vasque, pierre de frappe, galets), water (eau de la vasque),
tube (pivot a z = PIVOT). Lancer : blender --background --python tools/blender/shishi_odoshi.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *

PALETTE.update({
    "shishi_bamboo":  "#A3A65A",    # bambou sec, plus jaune que les tiges vivantes
    "shishi_node":    "#7E8442",
    "shishi_rope":    "#3B2E22",
    "basin_stone":    "#8C887E",
    "basin_dark":     "#6C695F",
    "moss":           "#667F3A",
    "water":          "#5F8FA8",
})

PIVOT = 0.55
rnd = random.Random(5)
reset_scene()

# ---------------------------------------------------------------- tube basculant (origine sur l'axe)
tb = Builder()
tb.tube([(0, -0.56, 0), (0, 0.36, 0)], [0.052, 0.05], sides=10, m="shishi_bamboo")
for y in (-0.2, 0.18):          # noeuds
    tb.tube([(0, y - 0.015, 0), (0, y + 0.015, 0)], [0.058, 0.058], sides=10, m="shishi_node", caps=False)
tb.tube([(-0.065, 0, 0), (0.065, 0, 0)], [0.016, 0.016], sides=6, m="shishi_node")     # moyeu sur l'axe
tb.build("tube", loc=(0, 0, PIVOT))

# ---------------------------------------------------------------- bati : deux poteaux, l'axe, la goulotte
fb = Builder()
for sx in (-1, 1):
    fb.tube([(sx * 0.1, 0, 0.0), (sx * 0.1, 0, PIVOT + 0.07)], [0.032, 0.03], sides=7, m="shishi_bamboo")
    fb.tube([(sx * 0.1, 0, PIVOT + 0.07), (sx * 0.1, 0, PIVOT + 0.085)], [0.034, 0.034], sides=7, m="shishi_node")
fb.tube([(-0.13, 0, PIVOT), (0.13, 0, PIVOT)], [0.011, 0.011], sides=6, m="shishi_node")        # axe
# poteau de la goulotte et goulotte (kakehi), qui verse au-dessus de la bouche du tube
fb.tube([(0.0, -1.08, 0.0), (0.0, -1.08, 1.02)], [0.045, 0.04], sides=8, m="shishi_bamboo")
fb.tube([(0.0, -1.08, 1.02), (0.0, -1.08, 1.04)], [0.047, 0.047], sides=8, m="shishi_node")
fb.tube([(0.0, -1.12, 0.93), (0.0, -0.5, 0.9)], [0.026, 0.024], sides=7, m="shishi_bamboo")
fb.tube([(0.0, -1.1, 0.9), (0.0, -1.06, 0.96)], [0.05, 0.05], sides=6, m="shishi_rope", caps=False)   # ligature
fb.build("frame")

# ---------------------------------------------------------------- pierres : vasque, pierre de frappe, galets
sb = Builder()
sb.blob((0.0, -0.62, 0.12), (0.42, 0.34, 0.16), "basin_stone", subdiv=2, noise=0.1, seed=3, bottom=0.9)
sb.blob((0.0, -0.62, 0.02), (0.5, 0.42, 0.1), "basin_dark", subdiv=2, noise=0.12, seed=4, bottom=0.9)
sb.blob((0.0, 0.36, 0.2), (0.16, 0.14, 0.2), "basin_stone", subdiv=2, noise=0.12, seed=8, bottom=0.8)   # pierre frappee
for k in range(7):
    a = rnd.uniform(0, 2 * math.pi)
    r = rnd.uniform(0.45, 0.7)
    sb.blob((r * math.cos(a) * 0.9, -0.5 + r * math.sin(a) * 0.8, 0.03), (rnd.uniform(0.06, 0.12),) * 2 + (0.05,),
            "basin_dark" if k % 2 else "basin_stone", subdiv=1, noise=0.15, seed=20 + k, bottom=0.7)
for k in range(4):
    a = rnd.uniform(0, 2 * math.pi)
    sb.blob((0.32 * math.cos(a), -0.62 + 0.25 * math.sin(a), 0.27), (0.09, 0.07, 0.025), "moss", subdiv=1,
            noise=0.15, seed=40 + k, bottom=0.8)
sb.build("stones")

# ---------------------------------------------------------------- eau de la vasque (creux du dessus)
wb = Builder()
n = 14
verts = [(0.0, -0.62, 0.262)] + [(0.27 * math.cos(2 * math.pi * i / n), -0.62 + 0.2 * math.sin(2 * math.pi * i / n), 0.262)
                                  for i in range(n)]
wb.add(verts, [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)], "water")
wb.build("water")

finish("shishi_odoshi", expected_dims=(1.0, 1.6, 1.05), tri_limit=(300, 6000),
       angles={"stones": math.radians(70), "water": math.radians(180)}, margin=1.1)
