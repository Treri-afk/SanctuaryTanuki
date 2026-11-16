"""Bureau du sanctuaire (shamusho) avec son comptoir de vente (juyosho) : la boutique du jeu.

6 x 4,6 m au sol (l'ancienne cabane faisait 4,5 x 3,5), socle de pierre, plancher sureleve, colombages sombres,
soubassement en planches et enduit clair, toit de tuiles grises en croupe qui avance de 1,1 m au-dessus du comptoir.
Facade (-Y) : a gauche l'entree (porte a shoji, noren indigo, pierre de seuil) ; a droite le comptoir ouvert sur
des etageres d'omamori et d'ema, chassis coulissants tires sur les cotes, enseigne de bois au-dessus.
Cotes : fenetres a barreaux. Echelle du haiden : 5,2 m au faitage.

Avant = -Y. Origine au sol, centree. Empties : shop_counter (ou se tient le joueur), lantern_anchor (lanterne).
Collisions : corps du batiment, comptoir, pierre de seuil.
Lancer : blender --background --python tools/blender/shamusho.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from building_util import *

reset_scene()
common.BEVEL_SEGMENTS = 1
rng = random.Random(4)

X0, X1 = -3.0, 3.0
Y0, Y1 = -2.3, 2.3
PL = 0.40          # dessus du socle
FL = 0.58          # plancher
KOSHI = 1.32       # haut du soubassement en planches
KAMOI = 2.50       # linteau des ouvertures
TOP = 3.02         # sabliere (haut des murs)
WIN_X = (-1.5, 3.0)
DOOR_X = (-3.0, -1.5)
COUNTER_Z = 1.02

# ------------------------------------------------------------------ socle et plancher
stone_plinth("plinth", X0 - 0.25, X1 + 0.25, Y0 - 0.25, Y1 + 0.25, PL)
bx_span("sill", X0 - 0.06, X1 + 0.06, Y0 - 0.06, Y1 + 0.06, PL, FL, "wood_dark", bevel=0.02)

# ------------------------------------------------------------------ poteaux et poutres
PX = (-3.0, -1.5, 0.0, 1.5, 3.0)
PY = (-2.3, -0.75, 0.75, 2.3)
for x in PX:
    for y in (Y0, Y1):
        post(f"post_{x}_{y}", x, y, FL, TOP)
for x in (X0, X1):
    for y in PY[1:-1]:
        post(f"post_{x}_{y}", x, y, FL, TOP)
for z0, z1, n in ((KOSHI - 0.05, KOSHI + 0.04, "nuki_low"), (KAMOI, KAMOI + 0.09, "kamoi"), (TOP - 0.17, TOP + 0.02, "keta")):
    bx_span(n + "_f", X0 - 0.09, X1 + 0.09, Y0 - 0.07, Y0 + 0.07, z0, z1, "wood_dark", bevel=0.015)
    bx_span(n + "_b", X0 - 0.09, X1 + 0.09, Y1 - 0.07, Y1 + 0.07, z0, z1, "wood_dark", bevel=0.015)
    bx_span(n + "_l", X0 - 0.07, X0 + 0.07, Y0, Y1, z0, z1, "wood_dark", bevel=0.015)
    bx_span(n + "_r", X1 - 0.07, X1 + 0.07, Y0, Y1, z0, z1, "wood_dark", bevel=0.015)

# ------------------------------------------------------------------ murs : arriere et cotes
for i in range(len(PX) - 1):
    a0, a1 = PX[i] + 0.085, PX[i + 1] - 0.085
    plank_wall(f"back_koshi_{i}", a0, a1, Y1, FL, KOSHI - 0.05, "x")
    plaster_wall(f"back_pl_{i}", a0, a1, Y1, KOSHI + 0.04, TOP - 0.17, "x")
for sx, x in ((-1, X0), (1, X1)):
    for i in range(len(PY) - 1):
        a0, a1 = PY[i] + 0.085, PY[i + 1] - 0.085
        plank_wall(f"side{sx}_koshi_{i}", a0, a1, x, FL, KOSHI - 0.05, "y")
        if i == 1:
            plaster_wall(f"side{sx}_pl_lo_{i}", a0, a1, x, KOSHI + 0.04, 1.55, "y")
            lattice_window(f"side{sx}_win", a0 + 0.12, a1 - 0.12, x - sx * 0.0, 1.62, KAMOI - 0.06, "y", bars=6)
            plaster_wall(f"side{sx}_pl_hi_{i}", a0, a1, x, KAMOI + 0.09, TOP - 0.17, "y")
        else:
            plaster_wall(f"side{sx}_pl_{i}", a0, a1, x, KOSHI + 0.04, TOP - 0.17, "y")

# ------------------------------------------------------------------ facade : entree
d0, d1 = DOOR_X[0] + 0.085, DOOR_X[1] - 0.085
shoji("door_l", d0, (d0 + d1) / 2 + 0.03, Y0 - 0.02, FL + 0.02, KAMOI, "x", cols=2, rows=5)
shoji("door_r", (d0 + d1) / 2 - 0.03, d1, Y0 + 0.03, FL + 0.02, KAMOI, "x", cols=2, rows=5)
plaster_wall("door_above", d0, d1, Y0, KAMOI + 0.09, TOP - 0.17, "x")
# noren indigo a deux pans, avec le blason clair (mon)
for k, (a, b) in enumerate(((d0 + 0.04, (d0 + d1) / 2 - 0.01), ((d0 + d1) / 2 + 0.01, d1 - 0.04))):
    bx_span(f"noren_{k}", a, b, Y0 - 0.12, Y0 - 0.10, 1.92, KAMOI + 0.02, "noren", bevel=0)
cyl("noren_mon", 0.11, -0.005, 0.005, (d0 + d1) / 2, 0, "noren_mon", verts=16, bevel=0)
for o in bpy.context.scene.objects:
    if o.name == "noren_mon":
        o.rotation_euler = (math.pi / 2, 0, 0)
        o.location = Vector(((d0 + d1) / 2, Y0 - 0.125, 2.24))
sweep("noren_rod", [(d0 - 0.05, Y0 - 0.11, KAMOI + 0.03), (d1 + 0.05, Y0 - 0.11, KAMOI + 0.03)], 0.03, 0.03, "bamboo")
# pierre de seuil et marche
bx("step_stone", (1.0, 0.55, 0.22), ((d0 + d1) / 2, Y0 - 0.55, 0.11), "stone", bevel=0.05)

# ------------------------------------------------------------------ facade : comptoir de vente
w0, w1 = WIN_X[0] + 0.085, WIN_X[1] - 0.085
plank_wall("counter_koshi", w0, w1, Y0, FL, COUNTER_Z - 0.04, "x")
# comptoir : planche epaisse qui deborde dehors, sur deux consoles
bx_span("counter", w0 - 0.05, w1 + 0.05, Y0 - 0.48, Y0 + 0.30, COUNTER_Z - 0.06, COUNTER_Z, "wood_light", bevel=0.015)
bx_span("counter_edge", w0 - 0.05, w1 + 0.05, Y0 - 0.50, Y0 - 0.44, COUNTER_Z - 0.10, COUNTER_Z, "wood_mid", bevel=0.012)
for x in (w0 + 0.4, (w0 + w1) / 2, w1 - 0.4):
    prism_x(f"bracket_{x:.2f}", [(Y0, COUNTER_Z - 0.06), (Y0 - 0.42, COUNTER_Z - 0.06), (Y0, COUNTER_Z - 0.40)],
            x - 0.04, x + 0.04, "wood_dark")
# interieur de la boutique, dans l'ombre : sol, fond, plafond, cloisons
IY = -1.05
bx_span("shop_floor", w0, w1, Y0 + 0.05, IY, FL - 0.02, FL + 0.02, "wood_faded", bevel=0)
bx_span("shop_back", w0, w1, IY, IY + 0.05, FL, TOP - 0.2, "interior", bevel=0)
bx_span("shop_ceiling", w0, w1, Y0 + 0.05, IY, KAMOI + 0.08, KAMOI + 0.12, "soffit", bevel=0)
for x in (w0, w1):
    bx_span(f"shop_side_{x:.2f}", x - 0.03, x + 0.03, Y0 + 0.05, IY, FL, KAMOI + 0.1, "interior", bevel=0)
# etageres et marchandises : omamori en rangs de couleur, ema suspendus, boites d'encens
OM = ["lacquer_red", "cloth_white", "cloth_purple", "foliage_orange", "sakaki", "metal_gold"]
for s, z in enumerate((1.42, 1.86)):
    bx_span(f"shelf_{s}", w0 + 0.1, w1 - 0.1, IY - 0.32, IY, z - 0.03, z, "wood_light", bevel=0.008)
    x = w0 + 0.22
    k = 0
    while x < w1 - 0.25:
        m = OM[(k + s * 2) % len(OM)]
        bx(f"omamori_{s}_{k}", (0.07, 0.025, 0.12), (x, IY - 0.12, z + 0.06), m, bevel=0.01)
        bx(f"omamori_cord_{s}_{k}", (0.012, 0.012, 0.03), (x, IY - 0.12, z + 0.135), "metal_gold", bevel=0)
        x += 0.13 if k % 6 != 5 else 0.3
        k += 1
# ema vierges accroches au fond
for k in range(9):
    x = w0 + 0.4 + k * (w1 - w0 - 0.8) / 8
    prism_y(f"ema_{k}", [(x - 0.09, 2.10), (x + 0.09, 2.10), (x + 0.09, 2.22), (x, 2.28), (x - 0.09, 2.22)],
            IY - 0.02, IY - 0.005, "wood_light")
    bx(f"ema_cord_{k}", (0.018, 0.006, 0.02), (x, IY - 0.012, 2.25), "lacquer_red", bevel=0)
# coffret et presentoir sur le comptoir
bx("till_box", (0.34, 0.24, 0.16), (w1 - 0.6, Y0 - 0.1, COUNTER_Z + 0.08), "lacquer_black", bevel=0.015)
bx("till_lid", (0.36, 0.26, 0.03), (w1 - 0.6, Y0 - 0.1, COUNTER_Z + 0.175), "lacquer_red", bevel=0.01)
for k in range(4):
    bx(f"display_om_{k}", (0.07, 0.025, 0.12), (w0 + 0.55 + k * 0.12, Y0 - 0.18, COUNTER_Z + 0.07), OM[k], bevel=0.01)
bx("display_stand", (0.62, 0.12, 0.04), (w0 + 0.73, Y0 - 0.16, COUNTER_Z + 0.02), "wood_mid", bevel=0.01)
# chassis coulissants tires sur les cotes de l'ouverture
shoji("slide_l", w0, w0 + 0.62, Y0 + 0.08, COUNTER_Z + 0.02, KAMOI, "x", cols=2, rows=3, paper="interior")
shoji("slide_r", w1 - 0.62, w1, Y0 + 0.08, COUNTER_Z + 0.02, KAMOI, "x", cols=2, rows=3, paper="interior")
plaster_wall("win_above", w0, w1, Y0, KAMOI + 0.09, TOP - 0.17, "x")
# enseigne de bois au-dessus du comptoir, quatre caracteres a l'encre
SB_X = (w0 + w1) / 2
bx("signboard", (1.5, 0.06, 0.30), (SB_X, Y0 - 0.09, KAMOI + 0.30), "wood_light", bevel=0.015)
bx("signboard_frame", (1.58, 0.05, 0.36), (SB_X, Y0 - 0.06, KAMOI + 0.30), "wood_dark", bevel=0.015)
for k in range(4):
    ink_glyph(f"glyph_{k}", SB_X - 0.48 + k * 0.32, Y0 - 0.125, KAMOI + 0.30, 0.22, seed=11 + k)

# ------------------------------------------------------------------ toit de tuiles en croupe
roof = HipRoof(RX=X1 + 1.05, RY=Y1 + 1.12, E=3.05, H=2.05, T=0.30, lift=0.26)
roof.build("roof")
roof.ridges("roof")
roof.rafters("rafter", inset=(X1 + 0.06, Y1 + 0.06), z_under=lambda x, y: TOP + 0.02, pitch=0.36)
# sous-face entre les chevrons (planches du voligeage, plus sombres)
bx_span("soffit_f", X0 - 1.0, X1 + 1.0, Y0 - 1.05, Y0 - 0.05, TOP + 0.06, TOP + 0.09, "soffit", bevel=0)

# ------------------------------------------------------------------ reperes et collisions
empty("shop_counter", ((w0 + w1) / 2, Y0 - 0.95, 0.0))
empty("lantern_anchor", (DOOR_X[1] + 0.05, Y0 - 0.80, 2.98))
collision_box("shamusho_body", (X1 - X0 + 0.2, Y1 - Y0 + 0.2, TOP), (0, 0, TOP / 2))
collision_box("shamusho_counter", (w1 - w0 + 0.1, 0.55, COUNTER_Z), ((w0 + w1) / 2, Y0 - 0.25, COUNTER_Z / 2))
collision_box("shamusho_plinth", (X1 - X0 + 0.5, Y1 - Y0 + 0.5, PL), (0, 0, PL / 2))

merge_visuals("shamusho")
finish_model("shamusho", expected_dims=(8.1, 6.85, 5.4), tri_limit=(3000, 40000), yaw=-30, pitch=16, margin=1.0)
