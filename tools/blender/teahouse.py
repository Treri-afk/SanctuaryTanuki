"""Salon de the (sukiya) : pavillon et veranda (engawa) ou l'on s'assoit pour le the. On peut y entrer :
deux marches de bois (et une rampe de collision invisible) menent aux shoji ouverts. Tout le modele est construit
a l'echelle 1 puis agrandi de SCALE (1,35) : ~7,3 x 6,2 m au sol, linteau a 2,77 m, plafond a 2,9 m.

Poteaux en rondins poses sur des pierres de fondation, plancher sureleve, murs de terre ocre, facade de shoji dont
deux sont tires et laissent voir les tatamis et l'alcove (tokonoma : rouleau suspendu, vase et branche d'erable),
fenetre ronde (marumado) sur le cote, epais toit de chaume a quatre pentes qui couvre la veranda.

Avant = -Y. Origine au sol, au centre du pavillon (veranda comprise). Empties : tea_anchor (service a the, sur la
veranda), lantern_anchor. Collision : le pavillon et sa veranda (on ne monte pas).
Lancer : blender --background --python tools/blender/teahouse.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from building_util import *

PALETTE.update({
    "earth_wall":  "#B39B74",   # mur de terre (tsuchi-kabe)
    "log":         "#9C7B57",   # rondin ecorce
    "log_dark":    "#7A5C40",
    "tatami_edge": "#2F3A2E",
    "ink":         "#26221F",
})

reset_scene()
common.BEVEL_SEGMENTS = 1
rng = random.Random(9)

X0, X1 = -2.7, 2.7
YF, YB = -1.3, 2.3          # pavillon
YV = -2.3                   # bord de la veranda
FL = 0.50
KAMOI = 2.05
TOP = 2.45

# ------------------------------------------------------------------ pierres de fondation et rondins
def log_post(name, x, y, z0, z1, r=0.085):
    # rondin a peine irregulier, pose sur une pierre plate
    sphere(name + "_stone", 1.0, (x, y, 0.06), "stone", scale=(r * 2.6, r * 2.4, 0.12), seg=10, rings=5)
    cyl(name, r, z0, z1, x + rng.uniform(-0.01, 0.01), y, "log", verts=10, bevel=0, r2=r * 0.93)

POSTS = [(x, y) for x in (X0, -0.9, 0.9, X1) for y in (YF, YB)] + [(X0, 0.5), (X1, 0.5)]
for i, (x, y) in enumerate(POSTS):
    log_post(f"post_{i}", x, y, 0.08, TOP)
VPOSTS = (X0, -1.75, 1.75, X1)        # rien au milieu : c'est l'entree
for i, x in enumerate(VPOSTS):
    log_post(f"vpost_{i}", x, YV + 0.1, 0.08, TOP - 0.05, r=0.075)
# dessous du plancher, dans l'ombre
bx_span("underfloor", X0 + 0.1, X1 - 0.1, YV + 0.25, YB - 0.1, 0.05, FL - 0.1, "interior", bevel=0)

# ------------------------------------------------------------------ plancher et veranda
bx_span("floor", X0 - 0.05, X1 + 0.05, YF, YB + 0.05, FL - 0.1, FL, "wood_dark", bevel=0.015)
n = 12
for i in range(n):
    x0 = X0 - 0.05 + (X1 - X0 + 0.1) * i / n
    x1 = X0 - 0.05 + (X1 - X0 + 0.1) * (i + 1) / n
    bx_span(f"engawa_{i}", x0 + 0.006, x1 - 0.006, YV, YF, FL - 0.07, FL, "wood_light" if i % 3 else "wood_faded", bevel=0.008)
bx_span("engawa_rim", X0 - 0.08, X1 + 0.08, YV - 0.04, YV + 0.08, FL - 0.16, FL - 0.005, "wood_dark", bevel=0.015)
# pierre a chaussures devant la veranda
bx("shoe_stone", (0.8, 0.45, 0.24), (-2.15, YV - 0.42, 0.12), "stone", bevel=0.06)
# deux marches de bois devant l'entree (une rampe de collision invisible les double)
bx_span("step_1", -0.85, 0.85, YV - 0.95, YV - 0.47, 0.0, FL * 0.34, "wood_mid", bevel=0.015)
bx_span("step_2", -0.85, 0.85, YV - 0.50, YV - 0.02, 0.0, FL * 0.67, "wood_light", bevel=0.015)
for x in (-0.85, 0.85):
    bx_span(f"step_side_{x}", x - 0.05, x + 0.05, YV - 0.97, YV, 0.0, FL * 0.5, "wood_dark", bevel=0.01)

# ------------------------------------------------------------------ poutres
for z0, z1, nm in ((KAMOI, KAMOI + 0.08, "kamoi"), (TOP - 0.14, TOP + 0.02, "keta")):
    bx_span(nm + "_f", X0 - 0.08, X1 + 0.08, YF - 0.06, YF + 0.06, z0, z1, "log_dark", bevel=0.015)
    bx_span(nm + "_b", X0 - 0.08, X1 + 0.08, YB - 0.06, YB + 0.06, z0, z1, "log_dark", bevel=0.015)
    bx_span(nm + "_l", X0 - 0.06, X0 + 0.06, YF, YB, z0, z1, "log_dark", bevel=0.015)
    bx_span(nm + "_r", X1 - 0.06, X1 + 0.06, YF, YB, z0, z1, "log_dark", bevel=0.015)
bx_span("veranda_beam", X0 - 0.1, X1 + 0.1, YV + 0.04, YV + 0.16, TOP - 0.2, TOP - 0.06, "log_dark", bevel=0.015)

# ------------------------------------------------------------------ interieur (vu par les shoji ouverts)
bx_span("tatami_base", X0 + 0.08, X1 - 0.08, YF + 0.05, YB - 0.08, FL, FL + 0.03, "tatami", bevel=0)
for k, x in enumerate((-1.6, -0.2, 1.2)):
    bx_span(f"tatami_edge_{k}", x - 0.02, x + 0.02, YF + 0.05, YB - 0.9, FL + 0.03, FL + 0.035, "tatami_edge", bevel=0)
bx_span("tatami_edge_y", X0 + 0.08, X1 - 0.08, YB - 0.92, YB - 0.88, FL + 0.03, FL + 0.035, "tatami_edge", bevel=0)
bx_span("back_inside", X0 + 0.06, X1 - 0.06, YB - 0.1, YB - 0.06, FL, KAMOI, "interior", bevel=0)
bx_span("ceiling", X0 + 0.06, X1 - 0.06, YF, YB, KAMOI + 0.1, KAMOI + 0.14, "wood_faded", bevel=0)
# tokonoma : estrade, rouleau suspendu, vase et branche d'erable
bx_span("toko_dais", -1.1, 0.4, YB - 0.62, YB - 0.1, FL, FL + 0.14, "wood_mid", bevel=0.01)
bx_span("toko_back", -1.1, 0.4, YB - 0.12, YB - 0.07, FL + 0.14, KAMOI, "earth_wall", bevel=0)
bx_span("scroll", -0.6, -0.1, YB - 0.14, YB - 0.125, FL + 0.55, KAMOI - 0.12, "shoji_paper", bevel=0)
bx_span("scroll_rod", -0.66, -0.04, YB - 0.15, YB - 0.12, FL + 0.52, FL + 0.56, "wood_dark", bevel=0)
for k in range(3):      # une colonne de calligraphie
    ink_glyph(f"scroll_ink_{k}", -0.35, YB - 0.152, FL + 1.18 - 0.2 * k, 0.15, seed=51 + k, m="ink", depth=0.006)
cyl("vase", 0.06, FL + 0.14, FL + 0.36, 0.05, YB - 0.38, "lacquer_black", verts=12, bevel=0.01, r2=0.04)
sweep("branch", [(0.05, YB - 0.38, FL + 0.34), (0.12, YB - 0.4, FL + 0.55), (0.28, YB - 0.42, FL + 0.66)], 0.015, 0.015, "wood_dark")
for k in range(5):
    sphere(f"leaf_{k}", 1.0, (0.12 + 0.04 * k, YB - 0.41, FL + 0.55 + 0.03 * k), "foliage_red", scale=(0.035, 0.012, 0.03), seg=8, rings=4)

# ------------------------------------------------------------------ facade : quatre shoji, deux tires
xs = [X0 + 0.07, -1.35, -0.02, 1.33, X1 - 0.07]
shoji("shoji_0", xs[0], xs[1], YF + 0.02, FL + 0.02, KAMOI, "x", cols=3, rows=6)
shoji("shoji_1", xs[0] + 0.15, xs[1] + 0.15, YF - 0.04, FL + 0.02, KAMOI, "x", cols=3, rows=6)       # tire a gauche
shoji("shoji_2", xs[3] - 0.15, xs[4] - 0.15, YF - 0.04, FL + 0.02, KAMOI, "x", cols=3, rows=6)       # tire a droite
shoji("shoji_3", xs[3], xs[4], YF + 0.02, FL + 0.02, KAMOI, "x", cols=3, rows=6)
bx_span("above_front", X0, X1, YF - 0.04, YF + 0.04, KAMOI + 0.08, TOP - 0.14, "earth_wall", bevel=0)

# ------------------------------------------------------------------ murs de terre, fenetre ronde
for sx, x in ((-1, X0), (1, X1)):
    plaster_wall(f"side{sx}_a", YF + 0.08, 0.5 - 0.08, x, FL, TOP - 0.14, "y", m="earth_wall")
    plaster_wall(f"side{sx}_b", 0.5 + 0.08, YB - 0.08, x, FL, TOP - 0.14, "y", m="earth_wall")
    bx_span(f"side{sx}_kick", x - 0.06, x + 0.06, YF, YB, FL, FL + 0.18, "log_dark", bevel=0.01)
plaster_wall("back", X0 + 0.08, X1 - 0.08, YB, FL, TOP - 0.14, "x", m="earth_wall")
bx_span("back_kick", X0, X1, YB - 0.06, YB + 0.06, FL, FL + 0.18, "log_dark", bevel=0.01)
# marumado : disque sombre, anneau de bois, croisillon de bambou dans le cercle
MC = (X1 + 0.055, 1.35, 1.35)
R = 0.42
cyl("marumado_back", R, -0.01, 0.01, 0, 0, "interior", verts=24, bevel=0)
ring_pts = [(MC[0], MC[1] + R * math.cos(2 * math.pi * k / 24), MC[2] + R * math.sin(2 * math.pi * k / 24)) for k in range(25)]
tube("marumado_ring", ring_pts, [0.035] * 25, "log_dark", nseg=6)
for k in (-2, -1, 0, 1, 2):
    off = k * R / 3
    h = math.sqrt(max(R * R - off * off, 0.0))
    bx_span(f"maru_v{k}", MC[0] - 0.012, MC[0] + 0.012, MC[1] + off - 0.012, MC[1] + off + 0.012, MC[2] - h, MC[2] + h, "bamboo", bevel=0)
    bx_span(f"maru_h{k}", MC[0] - 0.012, MC[0] + 0.012, MC[1] - h, MC[1] + h, MC[2] + off - 0.012, MC[2] + off + 0.012, "bamboo", bevel=0)
for o in bpy.context.scene.objects:
    if o.name == "marumado_back":
        o.rotation_euler = (0, math.pi / 2, 0)
        o.location = Vector(MC) + Vector((-0.02, 0, 0))

# ------------------------------------------------------------------ toit de chaume
CY = (YV + YB) / 2
roof = ThatchRoof(RX=X1 + 1.0, RY=(YB - YV) / 2 + 0.95, E=2.55, H=2.35, T=0.55, seed=5, cy=CY)
roof.build("roof")
roof.ridge_cap("ridge")
# sous-face : voligeage de bambou serre (plan sombre juste sous le chaume, entre les murs et l'egout)
bx_span("soffit_v", X0 - 1.0, X1 + 1.0, YV - 0.95, YV + 0.1, TOP + 0.04, TOP + 0.07, "soffit", bevel=0)

# ------------------------------------------------------------------ reperes et collisions
empty("tea_anchor", (1.1, YV + 0.18, FL))    # pres du bord : le joueur s assoit devant, hors de la collision
empty("lantern_anchor", (X0 - 0.4, YV - 0.55, 2.55))
# collisions : plancher (veranda comprise), murs, shoji fermes, poteaux de veranda, rampe d'entree
collision_box("th_floor", (X1 - X0 + 0.2, YB - YV, FL), (0, (YV + YB) / 2, FL / 2))
collision_box("th_wall_back", (X1 - X0 + 0.1, 0.16, TOP - FL), (0, YB, (FL + TOP) / 2))
for sx, x in ((-1, X0), (1, X1)):
    collision_box(f"th_wall_{sx}", (0.16, YB - YF + 0.1, TOP - FL), (x, (YF + YB) / 2, (FL + TOP) / 2))
OPEN = (-1.2, 1.18)                      # les deux shoji tires laissent ce passage
collision_box("th_front_l", (OPEN[0] - X0, 0.12, TOP - FL), ((X0 + OPEN[0]) / 2, YF, (FL + TOP) / 2))
collision_box("th_front_r", (X1 - OPEN[1], 0.12, TOP - FL), ((OPEN[1] + X1) / 2, YF, (FL + TOP) / 2))
for i, x in enumerate(VPOSTS):
    collision_box(f"th_vpost_{i}", (0.2, 0.2, TOP), (x, YV + 0.1, TOP / 2))
col_prism_x("th_ramp", [(YV - 0.95, 0.0), (YV, FL), (YV, 0.0)], -0.85, 0.85)

merge_visuals("teahouse")
# agrandissement : tout (maillage, collisions, reperes) autour de l'origine au sol
SCALE = 1.35
for o in bpy.context.scene.objects:
    o.location = o.location * SCALE
    o.scale = o.scale * SCALE
finish_model("teahouse", expected_dims=(10.0, 8.8, 7.3), tri_limit=(3000, 40000), yaw=-32, pitch=15, margin=1.0)
