"""Pavillon des ablutions (temizuya) : abri a quatre poteaux vermillon pose au-dessus du bassin existant
(water_basin.glb, qui reste un modele a part : la tache de la fontaine s'en sert). Toit a deux pans en cuivre
vert-de-gris comme le haiden, planches de rive sombres et pendentif dore, poutres traversantes a abouts noirs,
plaque de bois sur la poutre avant, bases de pierre.

Meme repere que le bassin (long cote le long de X, avant = -Y) : on le pose au meme endroit, meme rotation.
Origine au sol, centree. Collisions : les quatre poteaux seulement (on accede au bassin par les longs cotes).
Lancer : blender --background --python tools/blender/temizuya.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from building_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1

PXS, PYS = 1.12, 0.80        # poteaux
TOP = 2.30
R = 0.075

for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * PXS, sy * PYS
        bx(f"base_{sx}_{sy}", (0.30, 0.30, 0.16), (x, y, 0.08), "stone", bevel=0.03)
        cyl(f"post_{sx}_{sy}", R, 0.16, TOP, x, y, "lacquer_red", verts=12, bevel=0.01)
        cyl(f"foot_{sx}_{sy}", R + 0.02, 0.16, 0.30, x, y, "lacquer_black", verts=12, bevel=0.008)
# poutres traversantes (nuki) et sablieres, abouts noirs qui depassent
for sy in (-1, 1):
    y = sy * PYS
    bx_span(f"nuki_{sy}", -PXS - 0.22, PXS + 0.22, y - 0.05, y + 0.05, 1.95, 2.06, "lacquer_red", bevel=0.012)
    bx_span(f"keta_{sy}", -PXS - 0.30, PXS + 0.30, y - 0.07, y + 0.07, TOP - 0.06, TOP + 0.10, "lacquer_red", bevel=0.015)
    for sx in (-1, 1):
        bx_span(f"nuki_end_{sx}_{sy}", sx * (PXS + 0.16), sx * (PXS + 0.24), y - 0.055, y + 0.055, 1.94, 2.07, "lacquer_black", bevel=0.008)
for sx in (-1, 1):
    x = sx * PXS
    bx_span(f"tie_{sx}", x - 0.05, x + 0.05, -PYS - 0.15, PYS + 0.15, TOP - 0.02, TOP + 0.10, "lacquer_red", bevel=0.012)
    # potelet de pignon qui porte le faitage
    bx_span(f"king_{sx}", x - 0.04, x + 0.04, -0.05, 0.05, TOP + 0.08, TOP + 0.62, "lacquer_red", bevel=0.01)
bx_span("ridge_beam", -PXS - 0.2, PXS + 0.2, -0.06, 0.06, TOP + 0.58, TOP + 0.70, "wood_dark", bevel=0.012)

# toit de cuivre
roof = GableRoof(RX=PXS + 0.55, RY=PYS + 0.62, E=TOP + 0.10, H=0.78, T=0.16, lift=0.12)
roof.build("roof")
roof.ridge("roof")
roof.bargeboards("hafu")
# chevrons sous le toit
k = 0
for sy in (-1, 1):
    x = -PXS - 0.4
    while x <= PXS + 0.4:
        y0, y1 = 0.0, sy * (PYS + 0.55)
        sweep(f"rafter_{k}", [(x, y0, roof.top(x, y0) - roof.T - 0.05), (x, y1, roof.top(x, y1) - roof.T - 0.04)],
              0.05, 0.05, "wood_dark")
        k += 1
        x += 0.28

# plaque de bois sur la poutre avant, deux caracteres a l'encre
bx("plaque", (0.62, 0.04, 0.22), (0.0, -PYS - 0.07, 2.17), "wood_light", bevel=0.012)
bx("plaque_frame", (0.68, 0.03, 0.27), (0.0, -PYS - 0.05, 2.17), "wood_dark", bevel=0.01)
for k, x in enumerate((-0.15, 0.15)):
    ink_glyph(f"plaque_g{k}", x, -PYS - 0.095, 2.17, 0.15, seed=31 + k, depth=0.01)
# shide (papiers en zigzag) sous la poutre avant
for k, x in enumerate((-0.7, 0.7)):
    shide(f"shide_{k}", x, -PYS - 0.06, 1.94, scale=0.9)

for sx in (-1, 1):
    for sy in (-1, 1):
        collision_box(f"post_{sx}_{sy}", (0.26, 0.26, TOP), (sx * PXS, sy * PYS, TOP / 2))

merge_visuals("temizuya")
finish_model("temizuya", expected_dims=(3.4, 2.9, 3.4), tri_limit=(1000, 15000), yaw=-30, pitch=14, margin=1.05)
