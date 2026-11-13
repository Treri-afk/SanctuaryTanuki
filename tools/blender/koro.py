"""Brule-parfum (koro) du sanctuaire, pres du tronc a offrandes : socle de pierre, chaudron de bronze patine
sur trois pieds a pattes, deux anses, lit de cendre ou l'on plante les batons d'encens. ~0,8 m.
Un Empty « incense_anchor » marque le milieu de la cendre (le jeu y plante l'encens et fait monter la fumee).
Origine au sol, centree. Collision : boite.
Lancer : blender --background --python tools/blender/koro.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_util import *

PALETTE.update({
    "bronze":       "#6A5638",
    "bronze_dark":  "#4A3C28",
    "bronze_green": "#5F7E66",   # vert-de-gris sur les bords
    "ash":          "#BEB8AC",
})

reset_scene()
common.BEVEL_SEGMENTS = 1

# ------------------------------------------------------------------ socle de pierre (deux degres)
add_parts = []
add_parts.append(bx("plinth_low", (0.62, 0.62, 0.12), (0, 0, 0.06), "stone_dark", bevel=0.03))
add_parts.append(bx("plinth", (0.48, 0.48, 0.30), (0, 0, 0.27), "stone", bevel=0.035))
add_parts.append(bx("plinth_top", (0.54, 0.54, 0.06), (0, 0, 0.45), "stone", bevel=0.02))
for k, (x, y) in enumerate(((-0.24, -0.20), (0.22, 0.24), (-0.18, 0.25))):
    m = sphere(f"moss_{k}", 1.0, (x, y, 0.13), "moss", scale=(0.07, 0.05, 0.025), seg=8, rings=4)

# ------------------------------------------------------------------ chaudron de bronze
B = Mesh()
Z0 = 0.52          # dessous du chaudron
prof = [(0.0, Z0), (0.10, Z0 + 0.005), (0.17, Z0 + 0.03), (0.205, Z0 + 0.08), (0.212, Z0 + 0.13),
        (0.200, Z0 + 0.17), (0.215, Z0 + 0.19), (0.228, Z0 + 0.205), (0.222, Z0 + 0.215),
        (0.192, Z0 + 0.205), (0.186, Z0 + 0.17)]
B.lathe(prof, 28, lambda i, j: "bronze_green" if i >= 6 else ("bronze_dark" if i <= 1 else "bronze"), cap0=False, cap1=False)
# lit de cendre, un peu bombe
B.lathe([(0.186, Z0 + 0.168), (0.12, Z0 + 0.175), (0.0, Z0 + 0.178)], 28, "ash", cap0=False, cap1=False)
# trois pieds en patte, legerement evases
for k in range(3):
    a = math.radians(90 + 120 * k)
    top = Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, Z0 + 0.04))
    foot = Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.48))
    B.tube([top, (top + foot) * 0.5 + Vector((0, 0, -0.005)), foot], [0.028, 0.022, 0.026], 8, "bronze_dark", caps=True)
    ell(B, (foot.x * 1.08, foot.y * 1.08, 0.488), (0.034, 0.034, 0.013), "bronze_dark", 8, 4)
# deux anses
for s in (-1, 1):
    pts = []
    for i in range(7):
        t = i / 6
        ang = math.pi * t
        pts.append((s * (0.205 + 0.045 * math.sin(ang)), 0.0, Z0 + 0.12 + 0.07 * (1 - math.cos(ang)) * 0.5 + 0.035 * t))
    B.tube(pts, [0.011] * 7, 6, "bronze_green", caps=True)
B.build("koro")

empty("incense_anchor", (0.0, 0.0, Z0 + 0.178))
collision_box("koro", (0.62, 0.62, 0.74), loc=(0, 0, 0.37))

pfinish("koro", expected_dims=(0.62, 0.62, 0.74), tri_limit=(300, 4000),
        angles={"koro": math.radians(50)}, yaw=30, pitch=22, margin=1.1)
