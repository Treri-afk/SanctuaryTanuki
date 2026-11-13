"""Haiden : grand pavillon de priere ou l'on entre (echelle reelle, ~13 x 12,5 x 8,9 m).

Socle de pierre, plancher sur pilotis (1,10 m) avec veranda (engawa) et rambardes vermillon, escalier couvert d'un
auvent (kohai) qui porte le shimenawa, salle de 9 x 6 m ouverte sur l'avant (shoji sur les cotes, murs de planches,
plafond a caissons, tatamis, autel avec miroir, sakaki et offrandes), grand toit irimoya en cuivre vert-de-gris a
coins releves, chevrons apparents, consoles (masugumi) sur les piliers.

Lancer : blender --background --python tools/blender/haiden.py
Avant = -Y (vers le tronc a offrandes). Faitage le long de X. Origine au sol, au centre de la salle en X.
Empties : altar_anchor, lantern_anchor_l, lantern_anchor_r.
Collisions : plancher, socle, rampe de l'escalier (convexe, ~30 deg), piliers, murs, rambardes, autel.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrine_util import *

reset_scene()

# =========================================================== gabarit
FL = 1.10                      # dessus du plancher
PODIUM = 0.50                  # dessus du socle de pierre
PX = (-4.5, -1.5, 1.5, 4.5)    # piliers de la salle (X)
YF, YM, YB = -2.4, 0.6, 3.6    # piliers de la salle (Y) : avant, milieu, arriere
VX, VYF, VYB = 5.8, -3.7, 3.9  # bords de la veranda
BEAM_Z = (3.85, 4.05)          # poutre de tete (kashiranuki)
KAMOI_Z = (3.35, 3.50)         # linteau des ouvertures
POST_R = 0.17

# toit principal (irimoya)
E, H = 4.30, 4.00              # dessus du toit au bord de l'egout / hauteur jusqu'au faitage
YC, RY, RX = 0.6, 5.4, 6.7     # centre du toit en Y, demi-profondeur, demi-largeur (egouts)
XG = 4.0                       # position des pignons
DG = RX - XG                   # 2,7 : ou commence le pignon
OV = 0.55                      # debord du toit du pignon
T_A = 0.42                     # epaisseur du toit (tranche visible)
LIFT = 0.55                    # relevement des coins (sori)
S = 0.3375                     # pas de la grille (DG = 8 pas, RY = 16 pas)

# escalier
NR = 6
RISE = FL / NR
TREAD = 0.32
STAIR_W = 1.25                 # demi-largeur
Y_STAIR_B = VYF - (NR - 1) * TREAD     # premiere contremarche
Y_RAMP0 = Y_STAIR_B - TREAD            # pied de la rampe (sol)

# auvent (kohai)
KX = 2.3
KY0, KY1 = -2.42, -6.5
KPY = -5.85                    # piliers de l'auvent
KPX = 1.5


def f_prof(d):
    t = max(0.0, min(d / RY, 1.0))
    return E + H * (0.45 * t + 0.55 * t * t)


HG = f_prof(DG)
RIDGE_Z = f_prof(RY)


def lift(x, y):
    return LIFT * (min(abs(x) / RX, 1.0) ** 3) * (min(abs(y - YC) / RY, 1.0) ** 3)


def roof_top(x, y):
    dy = RY - abs(y - YC)
    dx = RX - abs(x)
    return min(f_prof(dy), f_prof(dx), HG) + lift(x, y)


def roof_bot(x, y):
    return roof_top(x, y) - T_A


def k_top(x, y):
    w = (y - KY1) / (KY0 - KY1)
    w = max(0.0, min(w, 1.0))
    return 3.40 + 1.40 * w ** 1.6 + 0.12 * (1 - w) ** 4 + 0.12 * (abs(x) / KX) ** 3 * (1 - w) ** 2


# =========================================================== socle et dessous du plancher
bx_span("podium", -6.2, 6.2, -4.3, 4.0, 0.0, PODIUM - 0.08, "stone", bevel=0.05, seg=2)
bx_span("podium_cap", -6.3, 6.3, -4.4, 4.1, PODIUM - 0.1, PODIUM, "stone_dark", bevel=0.03)
bx_span("podium_skirt", -6.35, 6.35, -4.45, 4.15, 0.0, 0.1, "stone_dark", bevel=0.03)
# joints du socle : quelques blocs en saillie legere sur la face avant et les cotes
for k, x in enumerate((-5.2, -3.1, -0.9, 1.3, 3.4, 5.3)):
    bx(f"podium_block_f{k}", (1.9 if k % 2 else 2.1, 0.04, 0.26), (x, -4.31, 0.25), "stone", bevel=0.015)
for sx in (-1, 1):
    for k, y in enumerate((-3.0, -0.6, 1.8)):
        bx(f"podium_block_s{sx}_{k}", (0.04, 2.2, 0.26), (sx * 6.21, y, 0.25), "stone", bevel=0.015)
# ombre sous le plancher : panneau sombre en retrait + poteaux courts
bx_span("underfloor", -5.35, 5.35, -3.25, 3.6, PODIUM, FL - 0.16, "lacquer_black", bevel=0)
for x in (-5.55, -3.0, 3.0, 5.55):
    bx(f"short_post_f{x}", (0.16, 0.16, FL - 0.16 - PODIUM), (x, VYF + 0.18, (PODIUM + FL - 0.16) / 2), "wood_dark")
for sx in (-1, 1):
    for y in (-1.5, 1.0, 3.5):
        bx(f"short_post_s{sx}_{y}", (0.16, 0.16, FL - 0.16 - PODIUM), (sx * (VX - 0.18), y, (PODIUM + FL - 0.16) / 2), "wood_dark")

# =========================================================== plancher (salle + veranda)
bx_span("deck_base", -VX, VX, VYF, VYB, FL - 0.17, FL - 0.04, "wood_dark", bevel=0.02)
# rive de la veranda (en-gamachi), un peu plus epaisse que le plancher
bx_span("deck_rim_f", -VX - 0.02, VX + 0.02, VYF - 0.02, VYF + 0.16, FL - 0.24, FL - 0.005, "wood_dark", bevel=0.025)
for sx in (-1, 1):
    bx_span(f"deck_rim_s{sx}", sx * (VX - 0.16), sx * (VX + 0.02), VYF, VYB + 0.02, FL - 0.24, FL - 0.005, "wood_dark", bevel=0.025)
# lames (le long de X), legerement alternees
n_pl = 25
pw = (VYB - (VYF + 0.16)) / n_pl
for i in range(n_pl):
    y0 = VYF + 0.16 + i * pw
    bx_span(f"plank_{i}", -VX + 0.16, VX - 0.16, y0 + 0.008, y0 + pw - 0.008, FL - 0.045, FL - 0.002,
            "wood_light" if i % 3 else "wood_faded", bevel=0.008)

# =========================================================== piliers de la salle
posts = []
for x in PX:
    for y in (YF, YB):
        posts.append((x, y))
for sx in (-1, 1):
    posts.append((sx * 4.5, YM))
for k, (x, y) in enumerate(posts):
    cyl(f"post_{k}", POST_R, PODIUM, BEAM_Z[1] + 0.2, x, y, "lacquer_red", verts=16, bevel=0.03)
    cyl(f"post_base_{k}", POST_R + 0.07, PODIUM, PODIUM + 0.12, x, y, "stone", verts=12, bevel=0.02)
    cyl(f"post_ring_{k}", POST_R + 0.025, FL, FL + 0.09, x, y, "metal_gold", verts=16, bevel=0.01)   # nemaki dore

# =========================================================== poutres et linteaux
for (y, nm) in ((YF, "f"), (YB, "b")):
    bx_span(f"head_beam_{nm}", -4.75, 4.75, y - 0.1, y + 0.1, *BEAM_Z, "lacquer_red", bevel=0.025)
    bx_span(f"kamoi_{nm}", -4.5, 4.5, y - 0.13, y + 0.13, *KAMOI_Z, "lacquer_red", bevel=0.02)
for sx in (-1, 1):
    bx_span(f"head_beam_s{sx}", sx * 4.4, sx * 4.6, YF - 0.25, YB + 0.25, *BEAM_Z, "lacquer_red", bevel=0.025)
    bx_span(f"kamoi_s{sx}", sx * 4.37, sx * 4.63, YF, YB, *KAMOI_Z, "lacquer_red", bevel=0.02)
    # embouts de poutres (kibana) blancs et dores
    for y in (YF - 0.25, YB + 0.25):
        bx(f"beam_end_{sx}_{y}", (0.24, 0.08, 0.24), (sx * 4.5, y + (0.04 if y > 0 else -0.04), sum(BEAM_Z) / 2), "metal_gold", bevel=0.015)
for y in (YF, YB):
    for sx in (-1, 1):
        bx(f"beam_end_x{sx}_{y}", (0.08, 0.24, 0.24), (sx * 4.79, y, sum(BEAM_Z) / 2), "metal_gold", bevel=0.015)

# frise (entre la poutre de tete et le toit) : volume enduit qui ferme les combles
bx_span("frieze", -4.42, 4.42, YF + 0.08, YB - 0.08, BEAM_Z[1] - 0.02, 5.35, "plaster", bevel=0)

# =========================================================== murs
WALL_T = 0.12
# murs de planches : cotes (moitie arriere) et arriere (travees laterales)
for sx in (-1, 1):
    bx_span(f"wall_side_{sx}", sx * (4.5 - WALL_T / 2), sx * (4.5 + WALL_T / 2), YM + POST_R, YB - POST_R, FL, BEAM_Z[0], "wood_light", bevel=0)
    for k in range(5):
        y = YM + 0.45 + k * 0.52
        bx(f"wall_batten_{sx}_{k}", (0.03, 0.07, KAMOI_Z[0] - FL - 0.1), (sx * (4.5 + WALL_T / 2 + 0.012), y, (FL + KAMOI_Z[0]) / 2), "wood_faded", bevel=0)
    bx_span(f"wall_back_{sx}", sx * (1.5 + POST_R), sx * (4.5 - POST_R), YB - WALL_T / 2, YB + WALL_T / 2, FL, BEAM_Z[0], "wood_light", bevel=0)
    for k in range(5):
        x = sx * (1.95 + k * 0.52)
        bx(f"back_batten_{sx}_{k}", (0.07, 0.03, KAMOI_Z[0] - FL - 0.1), (x, YB + WALL_T / 2 + 0.012, (FL + KAMOI_Z[0]) / 2), "wood_faded", bevel=0)
    # seuils (shikii) au pied des murs
    bx_span(f"sill_side_{sx}", sx * 4.36, sx * 4.64, YF, YB, FL - 0.02, FL + 0.07, "wood_dark", bevel=0.01)
bx_span("sill_back", -4.5, 4.5, YB - 0.14, YB + 0.14, FL - 0.02, FL + 0.07, "wood_dark", bevel=0.01)
# bande enduite entre linteau et poutre de tete sur les cotes et l'arriere
for sx in (-1, 1):
    bx_span(f"wall_band_s{sx}", sx * 4.44, sx * 4.56, YF, YB, KAMOI_Z[1], BEAM_Z[0], "plaster", bevel=0)
bx_span("wall_band_b", -4.5, 4.5, YB - 0.06, YB + 0.06, KAMOI_Z[1], BEAM_Z[0], "plaster", bevel=0)

# shoji sur les cotes (moitie avant) : 2 panneaux par travee, papier + croisillons
for sx in (-1, 1):
    for p in range(2):
        y0 = YF + POST_R + p * (YM - YF - 2 * POST_R) / 2
        y1 = y0 + (YM - YF - 2 * POST_R) / 2
        xc = sx * 4.5
        xo = sx * (4.5 + 0.03 * (1 if p == 0 else -1))      # panneaux decales (rails)
        bx_span(f"shoji_paper_{sx}_{p}", xo - 0.012, xo + 0.012, y0 + 0.04, y1 - 0.04, FL + 0.32, KAMOI_Z[0] - 0.04, "paper", bevel=0)
        # cadre
        for (ya, yb_) in ((y0, y0 + 0.06), (y1 - 0.06, y1)):
            bx_span(f"shoji_stile_{sx}_{p}_{ya}", xo - 0.035, xo + 0.035, ya, yb_, FL + 0.02, KAMOI_Z[0], "wood_light", bevel=0.008)
        bx_span(f"shoji_kick_{sx}_{p}", xo - 0.035, xo + 0.035, y0, y1, FL + 0.02, FL + 0.32, "wood_light", bevel=0.008)
        bx_span(f"shoji_top_{sx}_{p}", xo - 0.035, xo + 0.035, y0, y1, KAMOI_Z[0] - 0.06, KAMOI_Z[0], "wood_light", bevel=0.008)
        # croisillons (sur les deux faces)
        for side in (-1, 1):
            xf = xo + side * 0.018
            for q in range(1, 3):
                yy = y0 + (y1 - y0) * q / 3
                bx_span(f"shoji_v_{sx}_{p}_{q}_{side}", xf - 0.008, xf + 0.008, yy - 0.014, yy + 0.014, FL + 0.32, KAMOI_Z[0] - 0.06, "wood_light", bevel=0)
            for q in range(1, 6):
                zz = FL + 0.32 + (KAMOI_Z[0] - 0.06 - FL - 0.32) * q / 6
                bx_span(f"shoji_h_{sx}_{p}_{q}_{side}", xf - 0.008, xf + 0.008, y0 + 0.06, y1 - 0.06, zz - 0.014, zz + 0.014, "wood_light", bevel=0)

# portes du honden (fond de la travee centrale) : laque noire, bandes et poignees dorees
bx_span("honden_wall", -1.5 + POST_R, 1.5 - POST_R, YB - 0.05, YB + 0.07, FL, BEAM_Z[0], "wood_light", bevel=0)
for k in range(5):
    bx(f"honden_batten_{k}", (0.07, 0.03, KAMOI_Z[0] - FL - 0.1), (-1.04 + k * 0.52, YB + 0.082, (FL + KAMOI_Z[0]) / 2), "wood_faded", bevel=0)
for sx in (-1, 1):
    xc = sx * 0.62
    bx_span(f"honden_door_{sx}", xc - 0.6, xc + 0.6, YB - 0.1, YB - 0.04, FL + 0.08, KAMOI_Z[0] - 0.04, "wood_dark", bevel=0.01)
    for z in (FL + 0.35, FL + 1.25, KAMOI_Z[0] - 0.3):
        bx_span(f"honden_band_{sx}_{z}", xc - 0.58, xc + 0.58, YB - 0.115, YB - 0.095, z - 0.035, z + 0.035, "metal_gold", bevel=0)
    sphere(f"honden_knob_{sx}", 0.05, (sx * 0.1, YB - 0.13, FL + 1.25), "metal_gold", scale=(1, 0.6, 1), seg=10, rings=6)
bx_span("honden_frame_top", -1.35, 1.35, YB - 0.16, YB - 0.02, KAMOI_Z[0] - 0.06, KAMOI_Z[0] + 0.04, "lacquer_red", bevel=0.01)

# imposte ajouree (ranma) au-dessus des ouvertures avant
for k, (x0, x1) in enumerate(((-4.5, -1.5), (-1.5, 1.5), (1.5, 4.5))):
    bx_span(f"ranma_back_{k}", x0 + POST_R, x1 - POST_R, YF + 0.02, YF + 0.05, KAMOI_Z[1], BEAM_Z[0], "lacquer_black", bevel=0)
    nb = 11
    for q in range(nb):
        xx = x0 + POST_R + (x1 - x0 - 2 * POST_R) * (q + 0.5) / nb
        bx_span(f"ranma_bar_{k}_{q}", xx - 0.025, xx + 0.025, YF - 0.03, YF + 0.02, KAMOI_Z[1], BEAM_Z[0], "wood_light", bevel=0)

# rideau violet (mizuhiki-maku) sous le linteau avant, festonne entre les piliers, avec des mon blancs
for k, (x0, x1) in enumerate(((-4.5, -1.5), (-1.5, 1.5), (1.5, 4.5))):
    nseg = 10
    V, F = [], []
    yy = YF - 0.16
    for i in range(nseg + 1):
        u = i / nseg
        x = x0 + POST_R + (x1 - x0 - 2 * POST_R) * u
        zb = KAMOI_Z[0] - 0.30 - 0.08 * math.sin(math.pi * u)
        V += [(x, yy, zb), (x, yy, KAMOI_Z[0] + 0.02), (x, yy - 0.02, KAMOI_Z[0] + 0.02), (x, yy - 0.02, zb)]
    for i in range(nseg):
        a = i * 4
        for q in range(4):
            F.append((a + q, a + (q + 1) % 4, a + 4 + (q + 1) % 4, a + 4 + q))
    F.append((3, 2, 1, 0))
    F.append(tuple(range(nseg * 4, nseg * 4 + 4)))
    make_mesh(f"curtain_{k}", V, F, ["cloth_purple"] * len(F))
    o = cyl(f"curtain_mon_{k}", 0.105, -0.0175, 0.0175, 0, 0, "cloth_white", verts=16, bevel=0)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.location = ((x0 + x1) / 2, yy - 0.025, KAMOI_Z[0] - 0.16)

# =========================================================== consoles (masugumi) et pannes
PURLIN_OFF = 0.75


def purlin_top(x, y):
    return roof_bot(x, y) - 0.10


# pannes d'egout qui suivent la sous-face (meme hauteur aux coins : elles se rejoignent)
P_YF, P_YB, P_X = YF - PURLIN_OFF, YB + PURLIN_OFF, 4.5 + PURLIN_OFF
for (y, nm) in ((P_YF, "f"), (P_YB, "b")):
    xs = [-P_X - 0.25 + (2 * P_X + 0.5) * i / 16 for i in range(17)]
    sweep(f"purlin_{nm}", [(x, y, purlin_top(x, y)) for x in xs], 0.2, 0.2, "lacquer_red", dz_top=True, bevel=0.015)
for sx in (-1, 1):
    ys = [P_YF - 0.25 + (P_YB - P_YF + 0.5) * i / 14 for i in range(15)]
    sweep(f"purlin_s{sx}", [(sx * P_X, y, purlin_top(sx * P_X, y)) for y in ys], 0.2, 0.2, "lacquer_red", dz_top=True, bevel=0.015)

for k, (x, y) in enumerate(posts):
    zt = BEAM_Z[1] + 0.2
    bx(f"daito_{k}", (0.46, 0.46, 0.16), (x, y, zt + 0.08), "lacquer_red", bevel=0.03)
    # bras le long du mur + petits blocs
    along_x = abs(y - YM) > 0.1 or abs(abs(x) - 4.5) > 0.1
    if y in (YF, YB):
        bx(f"hijiki_{k}", (1.2, 0.16, 0.13), (x, y, zt + 0.225), "lacquer_red", bevel=0.02)
        for dx in (-0.45, 0.0, 0.45):
            bx(f"makito_{k}_{dx}", (0.22, 0.22, 0.12), (x + dx, y, zt + 0.35), "lacquer_red", bevel=0.02)
        out = -1 if y == YF else 1
        py = y + out * PURLIN_OFF
        ztop = purlin_top(x, py) - 0.2
        bx_span(f"arm_{k}", x - 0.08, x + 0.08, *sorted((y - out * 0.25, py + out * 0.2)), ztop - 0.15, ztop, "lacquer_red", bevel=0.02)
        bx(f"arm_block_{k}", (0.22, 0.22, 0.12), (x, py, ztop + 0.03), "lacquer_red", bevel=0.02)
        bx(f"arm_cap_{k}", (0.17, 0.03, 0.1), (x, py + out * 0.21, ztop - 0.075), "metal_gold", bevel=0)
    if abs(abs(x) - 4.5) < 0.1:
        sx = 1 if x > 0 else -1
        bx(f"hijiki_s_{k}", (0.16, 1.2, 0.13), (x, y, zt + 0.225), "lacquer_red", bevel=0.02)
        px = x + sx * PURLIN_OFF
        ztop = purlin_top(px, y) - 0.2
        bx_span(f"arm_s_{k}", *sorted((x - sx * 0.25, px + sx * 0.2)), y - 0.08, y + 0.08, ztop - 0.15, ztop, "lacquer_red", bevel=0.02)
        bx(f"arm_s_block_{k}", (0.22, 0.22, 0.12), (px, y, ztop + 0.03), "lacquer_red", bevel=0.02)
        bx(f"arm_s_cap_{k}", (0.03, 0.17, 0.1), (px + sx * 0.21, y, ztop - 0.075), "metal_gold", bevel=0)

# kaerumata (entretoises en pattes de grenouille) au milieu des travees, sur la frise
def kaerumata(name, x, y, axis):
    out = [(-0.42, 0.0), (0.42, 0.0), (0.16, 0.34), (-0.16, 0.34)]
    if axis == "x":
        prism_y(name, [(x + a, BEAM_Z[1] + b) for a, b in out], y - 0.06, y + 0.06, "lacquer_red", bevel=0.015)
        bx(name + "_gold", (0.2, 0.04, 0.14), (x, y + (0.08 if y > 0 else -0.08), BEAM_Z[1] + 0.17), "metal_gold", bevel=0.01)
        bx(name + "_block", (0.3, 0.2, 0.12), (x, y, BEAM_Z[1] + 0.4), "lacquer_red", bevel=0.02)
    else:
        prism_x(name, [(y + a, BEAM_Z[1] + b) for a, b in out], x - 0.06, x + 0.06, "lacquer_red", bevel=0.015)
        bx(name + "_gold", (0.04, 0.2, 0.14), (x + (0.08 if x > 0 else -0.08), y, BEAM_Z[1] + 0.17), "metal_gold", bevel=0.01)
        bx(name + "_block", (0.2, 0.3, 0.12), (x, y, BEAM_Z[1] + 0.4), "lacquer_red", bevel=0.02)


for k, x in enumerate((-3.0, 0.0, 3.0)):
    kaerumata(f"kaeru_f{k}", x, YF - 0.1, "x")
    kaerumata(f"kaeru_b{k}", x, YB + 0.1, "x")
for sx in (-1, 1):
    for k, y in enumerate(((YF + YM) / 2, (YM + YB) / 2)):
        kaerumata(f"kaeru_s{sx}_{k}", sx * 4.6, y, "y")

# =========================================================== toit principal (irimoya)
xs = sorted({round(sg * (RX - k * S), 5) for sg in (-1, 1) for k in range(20)} | {0.0})
ys = [YC - RY + k * S for k in range(33)]
heightfield("roof_main", xs, ys, roof_top, lambda x, y: T_A, "copper", "roof_edge", "soffit",
            diag=lambda x, y: (x > 0) != (y > YC))

# toit du pignon (au-dessus du chapeau plat du toit principal)
BAND = RY - DG
ysb = [YC - BAND + k * S for k in range(17)]
heightfield("roof_gable", [-(XG + OV), XG + OV], ysb, lambda x, y: f_prof(RY - abs(y - YC)) + 0.02,
            lambda x, y: 0.30, "copper", "roof_edge", "soffit")

# murs de pignon (tsuma) : enduit + colombages sombres + poutre de base rouge
for sx in (-1, 1):
    outline = [(YC - BAND, HG - 0.12)]
    for k in range(17):
        y = YC - BAND + k * S
        outline.append((y, f_prof(RY - abs(y - YC)) - 0.27))
    outline.append((YC + BAND, HG - 0.12))
    prism_x(f"gable_wall_{sx}", outline, sx * (XG - 0.12), sx * XG, "plaster")
    bx_span(f"gable_beam_{sx}", sx * (XG - 0.05), sx * (XG + 0.1), YC - BAND + 0.3, YC + BAND - 0.3, HG - 0.02, HG + 0.15, "lacquer_red", bevel=0.02)
    for q in range(-3, 4):
        y = YC + q * 0.62
        top = f_prof(RY - abs(y - YC)) - 0.3
        if top > HG + 0.3:
            bx_span(f"gable_stud_{sx}_{q}", sx * (XG - 0.02), sx * (XG + 0.04), y - 0.05, y + 0.05, HG + 0.2, top, "wood_dark", bevel=0)
    zt = HG + 0.6
    bx_span(f"gable_tie_{sx}", sx * (XG - 0.02), sx * (XG + 0.06), YC - 1.35, YC + 1.35, zt, zt + 0.16, "lacquer_red", bevel=0.015)

    # planches de rive (hafu) qui suivent le toit du pignon, extremites relevees
    for side in (-1, 1):
        pts = []
        for k in range(12):
            d = k / 11
            dyc = BAND * (1 - d) + 0.12 * (1 - d)       # du bas (bord) vers le faitage
            y = YC + side * dyc
            z = f_prof(RY - min(abs(y - YC), BAND)) + 0.08 + 0.10 * (1 - d) ** 6
            pts.append((sx * (XG + OV + 0.04), y, z))
        sweep(f"hafu_{sx}_{side}", pts, 0.1, 0.42, "wood_dark", dz_top=True, bevel=0.015)
        x0, y0, z0 = pts[0]
        bx(f"hafu_cap_{sx}_{side}", (0.14, 0.2, 0.44), (x0, y0, z0 - 0.21), "metal_gold", bevel=0.02)
    # ornement suspendu au sommet (gegyo)
    zt = RIDGE_Z + 0.02 + 0.08
    prism_x(f"gegyo_{sx}", [(YC - 0.32, zt - 0.36), (YC, zt - 0.62), (YC + 0.32, zt - 0.36), (YC + 0.22, zt - 0.18), (YC - 0.22, zt - 0.18)],
            sx * (XG + OV + 0.07), sx * (XG + OV + 0.13), "metal_gold", bevel=0.01)

# faitage (le long de X) : base sombre + couronnement, bouts releves, embouts sombres et dores
RL = XG + OV + 0.15
rx = [-RL + 2 * RL * i / 14 for i in range(15)]
rl = lambda x: 0.12 * (abs(x) / RL) ** 3
sweep("ridge_base", [(x, YC, RIDGE_Z + 0.12 + rl(x)) for x in rx], 0.62, 0.3, "copper_dark", bevel=0.02)
sweep("ridge_top", [(x, YC, RIDGE_Z + 0.39 + rl(x)) for x in rx], 0.42, 0.26, "copper", bevel=0.04)
for sx in (-1, 1):
    x = sx * (RL - 0.02)
    bx(f"ridge_end_{sx}", (0.22, 0.7, 0.66), (x, YC, RIDGE_Z + 0.4 + rl(x)), "lacquer_black", bevel=0.05)
    sphere(f"ridge_end_disc_{sx}", 0.17, (x + sx * 0.12, YC, RIDGE_Z + 0.42 + rl(x)), "metal_gold", scale=(0.35, 1, 1), seg=12, rings=6)

# aretiers (kudari-mune) : des coins du toit jusqu'au pied des pignons
for sx in (-1, 1):
    for sy in (-1, 1):
        pts = []
        for k in range(12):
            d = 0.05 + (DG - 0.05) * k / 11
            x, y = sx * (RX - d), YC + sy * (RY - d)
            pts.append((x, y, roof_top(x, y) + 0.1))
        sweep(f"hip_{sx}_{sy}", pts, 0.26, 0.2, "copper_dark", bevel=0.03)
        x, y, z = pts[0]
        bx(f"hip_end_{sx}_{sy}", (0.3, 0.3, 0.34), (x, y, z + 0.08), "lacquer_black", bevel=0.05,
           rot=(0, 0, math.radians(45)))
        # chevron d'angle (sumigi) sous le toit, embout dore
        under = []
        for k in range(10):
            d = 0.12 + (DG - 0.45) * k / 9
            x2, y2 = sx * (RX - d), YC + sy * (RY - d)
            under.append((x2, y2, roof_bot(x2, y2) - 0.02))
        sweep(f"sumigi_{sx}_{sy}", under, 0.2, 0.24, "wood_dark", dz_top=True, bevel=0.02)
        x2, y2, z2 = under[0]
        bx(f"sumigi_cap_{sx}_{sy}", (0.16, 0.16, 0.2), (x2, y2, z2 - 0.13), "metal_gold", bevel=0.02,
           rot=(0, 0, math.radians(45)))

# chevrons (taruki) sous l'egout : avant/arriere puis cotes
def rafter(name, p0, p1):
    pts = []
    for k in range(6):
        u = k / 5
        x = p0[0] + (p1[0] - p0[0]) * u
        y = p0[1] + (p1[1] - p0[1]) * u
        pts.append((x, y, roof_bot(x, y) - 0.005))
    sweep(name, pts, 0.09, 0.1, "wood_dark", dz_top=True)


n_r = 0
for k in range(-10, 11):
    x = k * 0.42
    if abs(x) > 4.3:
        continue
    rafter(f"rafter_f{k}", (x, YF + 0.05), (x, YC - RY + 0.07))
    rafter(f"rafter_b{k}", (x, YB - 0.05), (x, YC + RY - 0.07))
for sx in (-1, 1):
    for k in range(-7, 8):
        y = YM + k * 0.42
        if y < YF + 0.1 or y > YB - 0.1:
            continue
        rafter(f"rafter_s{sx}_{k}", (sx * 4.45, y), (sx * (RX - 0.07), y))

# lanternes suspendues : cordons sous l'egout avant (lanternes posees par build_world)
LANT = ((-3.2, -4.2), (3.2, -4.2))
for i, (x, y) in enumerate(LANT):
    zr = roof_bot(x, y) + 0.02
    bx(f"lantern_cord_{i}", (0.025, 0.025, zr - 3.86), (x, y, (zr + 3.86) / 2), "lacquer_black", bevel=0)
    bx(f"lantern_hook_{i}", (0.08, 0.08, 0.04), (x, y, zr - 0.02), "metal_gold", bevel=0)

# =========================================================== plafond a caissons (gotenjo)
CZ = BEAM_Z[1] - 0.02
bx_span("ceiling", -4.4, 4.4, YF + 0.1, YB - 0.1, CZ - 0.04, CZ, "wood_light", bevel=0)
for k in range(15):
    x = -4.2 + k * 0.6
    bx_span(f"ceil_rib_x{k}", x - 0.035, x + 0.035, YF + 0.1, YB - 0.1, CZ - 0.11, CZ - 0.04, "wood_dark", bevel=0)
for k in range(10):
    y = YF + 0.35 + k * 0.6
    bx_span(f"ceil_rib_y{k}", -4.4, 4.4, y - 0.035, y + 0.035, CZ - 0.11, CZ - 0.04, "wood_dark", bevel=0)
bx_span("ceil_cornice_f", -4.4, 4.4, YF + 0.1, YF + 0.22, CZ - 0.2, CZ, "lacquer_red", bevel=0.01)
bx_span("ceil_cornice_b", -4.4, 4.4, YB - 0.22, YB - 0.1, CZ - 0.2, CZ, "lacquer_red", bevel=0.01)
for sx in (-1, 1):
    bx_span(f"ceil_cornice_s{sx}", sx * 4.28, sx * 4.4, YF + 0.1, YB - 0.1, CZ - 0.2, CZ, "lacquer_red", bevel=0.01)

# =========================================================== interieur : tatamis, autel, lampes
for i in range(4):
    x0 = -1.8 + i * 0.9
    bx_span(f"tatami_{i}", x0 + 0.01, x0 + 0.89, -0.1, 1.7, FL, FL + 0.035, "tatami", bevel=0.008)
    for xe in (x0 + 0.01, x0 + 0.89 - 0.05):
        bx_span(f"tatami_edge_{i}_{xe}", xe, xe + 0.05, -0.1, 1.7, FL + 0.002, FL + 0.038, "lacquer_black", bevel=0)

AY0, AY1 = 2.25, 3.45
ALT_Z = FL + 0.5
bx_span("altar_base", -1.45, 1.45, AY0, AY1, FL, FL + 0.12, "lacquer_black", bevel=0.015)
bx_span("altar", -1.35, 1.35, AY0 + 0.05, AY1, FL + 0.12, ALT_Z - 0.05, "wood_light", bevel=0.015)
bx_span("altar_top", -1.42, 1.42, AY0, AY1, ALT_Z - 0.05, ALT_Z, "lacquer_black", bevel=0.015)
bx_span("altar_trim", -1.36, 1.36, AY0 + 0.035, AY0 + 0.05, FL + 0.18, ALT_Z - 0.1, "metal_gold", bevel=0)
bx_span("altar_step", -1.0, 1.0, AY1 - 0.55, AY1, ALT_Z, ALT_Z + 0.22, "wood_light", bevel=0.012)
# miroir sacre sur pied
cyl("mirror_stand", 0.04, ALT_Z + 0.22, ALT_Z + 0.55, 0, AY1 - 0.28, "wood_dark", verts=8, bevel=0)
bx("mirror_foot", (0.42, 0.22, 0.06), (0, AY1 - 0.28, ALT_Z + 0.25), "wood_dark", bevel=0.01)
o = cyl("mirror", 0.24, -0.025, 0.025, 0, 0, "metal_gold", verts=24, bevel=0.01)
o.rotation_euler = (math.radians(90), 0, 0)
o.location = (0, AY1 - 0.3, ALT_Z + 0.78)
o = cyl("mirror_rim", 0.27, -0.02, 0.02, 0, 0, "wood_dark", verts=24, bevel=0.008)
o.rotation_euler = (math.radians(90), 0, 0)
o.location = (0, AY1 - 0.27, ALT_Z + 0.78)
# sanbo (plateaux d'offrandes) : riz, sake, kakis
for k, x in enumerate((-0.75, 0.75, 0.0)):
    y = AY0 + 0.35 if k < 2 else AY0 + 0.3
    z0 = ALT_Z if k < 2 else ALT_Z
    bx(f"sanbo_foot_{k}", (0.3, 0.3, 0.14), (x, y, z0 + 0.07), "wood_light", bevel=0.01)
    bx(f"sanbo_tray_{k}", (0.4, 0.4, 0.05), (x, y, z0 + 0.165), "wood_light", bevel=0.012)
    if k == 0:
        sphere("rice", 0.11, (x, y, z0 + 0.2), "paper", scale=(1, 1, 0.6), seg=10, rings=5)
    elif k == 1:
        for dx in (-0.08, 0.08):
            cyl(f"sake_{dx}", 0.05, z0 + 0.19, z0 + 0.36, x + dx, y, "paper", verts=10, bevel=0.01)
            cyl(f"sake_neck_{dx}", 0.022, z0 + 0.36, z0 + 0.43, x + dx, y, "paper", verts=8, bevel=0)
    else:
        for (dx, dy) in ((-0.07, -0.05), (0.07, -0.04), (0.0, 0.07)):
            sphere(f"kaki_{dx}", 0.065, (x + dx, y + dy, z0 + 0.25), "foliage_orange", scale=(1, 1, 0.8), seg=10, rings=6)
# sakaki dans des vases blancs, de part et d'autre
for sx in (-1, 1):
    x = sx * 1.12
    y = AY0 + 0.45
    cyl(f"vase_{sx}", 0.09, ALT_Z, ALT_Z + 0.3, x, y, "paper", verts=12, bevel=0.01, r2=0.06)
    cyl(f"sakaki_stem_{sx}", 0.015, ALT_Z + 0.25, ALT_Z + 0.75, x, y, "wood_dark", verts=6, bevel=0)
    for q, (dx, dy, dz, r) in enumerate(((0, 0, 0.82, 0.16), (0.1, 0.04, 0.68, 0.12), (-0.09, -0.03, 0.7, 0.12), (0.02, -0.08, 0.95, 0.1))):
        sphere(f"sakaki_{sx}_{q}", r, (x + dx, y + dy, ALT_Z + dz), "sakaki", scale=(1, 0.8, 0.75), seg=8, rings=5)
# gohei (baton et papier en zigzag) devant le miroir
bx("gohei_stick", (0.025, 0.025, 0.8), (0, AY0 + 0.15, ALT_Z + 0.4), "wood_light", bevel=0)
bx("gohei_base", (0.16, 0.16, 0.06), (0, AY0 + 0.15, ALT_Z + 0.03), "lacquer_black", bevel=0.01)


for sx in (-1, 1):
    shide(f"gohei_paper_{sx}", sx * 0.04, AY0 + 0.15, ALT_Z + 0.78, 0.9)

# andon (lampes de papier sur pied) de chaque cote de l'autel
for sx in (-1, 1):
    x, y = sx * 2.05, AY0 + 0.6
    for (dx, dy) in ((-0.15, -0.15), (0.15, -0.15), (-0.15, 0.15), (0.15, 0.15)):
        bx(f"andon_leg_{sx}_{dx}_{dy}", (0.035, 0.035, 0.95), (x + dx, y + dy, FL + 0.475), "wood_dark", bevel=0)
    bx(f"andon_paper_{sx}", (0.28, 0.28, 0.42), (x, y, FL + 0.66), "paper", bevel=0.005)
    bx(f"andon_top_{sx}", (0.36, 0.36, 0.04), (x, y, FL + 0.9), "wood_dark", bevel=0.01)
    bx(f"andon_shelf_{sx}", (0.34, 0.34, 0.03), (x, y, FL + 0.43), "wood_dark", bevel=0.005)

# =========================================================== rambardes (koran) vermillon
RAIL_H = 0.88
RY_F = VYF + 0.08


def rail_run(name, a, b, along):
    """Rambarde droite de a a b (coordonnee variable selon 'along'), poteaux tous les ~1,4 m."""
    (x0, y0), (x1, y1) = a, b
    L = math.hypot(x1 - x0, y1 - y0)
    n = max(1, round(L / 1.4))
    for i in range(n + 1):
        u = i / n
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
        bx(f"{name}_post_{i}", (0.13, 0.13, RAIL_H + 0.08), (x, y, FL + (RAIL_H + 0.08) / 2), "lacquer_red", bevel=0.025)
        if i in (0, n):
            giboshi(f"{name}_gib_{i}", x, y, FL + RAIL_H + 0.08)
    for z, t, m in ((FL + RAIL_H, 0.1, "lacquer_red"), (FL + 0.52, 0.07, "lacquer_red"), (FL + 0.1, 0.09, "lacquer_red")):
        if along == "x":
            bx_span(f"{name}_rail_{z}", min(x0, x1), max(x0, x1), y0 - t / 2, y0 + t / 2, z - t / 2, z + t / 2, m, bevel=0.02)
        else:
            bx_span(f"{name}_rail_{z}", x0 - t / 2, x0 + t / 2, min(y0, y1), max(y0, y1), z - t / 2, z + t / 2, m, bevel=0.02)
    # petits balustres entre la lisse basse et la lisse du milieu
    nb = int(L / 0.35)
    for i in range(1, nb):
        u = i / nb
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
        bx(f"{name}_bal_{i}", (0.05, 0.05, 0.42), (x, y, FL + 0.31), "lacquer_red", bevel=0)


for sx in (-1, 1):
    rail_run(f"rail_f{sx}", (sx * 1.45, RY_F), (sx * (VX - 0.08), RY_F), "x")
    rail_run(f"rail_s{sx}", (sx * (VX - 0.08), RY_F), (sx * (VX - 0.08), VYB - 0.08), "y")

# =========================================================== escalier
for k in range(NR - 1):
    y0 = Y_STAIR_B + k * TREAD - 0.03
    bx_span(f"step_{k}", -STAIR_W, STAIR_W, y0, VYF + 0.1, 0.0, RISE * (k + 1), "wood_light" if k % 2 == 0 else "wood_faded", bevel=0.02)


def ramp_z(y):
    return (y - Y_RAMP0) * FL / (VYF - Y_RAMP0)


for sx in (-1, 1):
    ya = Y_STAIR_B - 0.2
    prism_x(f"stringer_{sx}", [(ya, 0.0), (VYF + 0.05, 0.0), (VYF + 0.05, FL + 0.16), (ya, ramp_z(ya) + 0.16)],
            sx * STAIR_W, sx * (STAIR_W + 0.12), "lacquer_red", bevel=0.02)
    # main courante en pente : poteau bas dore + lisse vers le poteau de la veranda
    xr = sx * (STAIR_W + 0.06)
    yb = Y_STAIR_B - 0.08
    zb = ramp_z(yb) + 0.12
    bx(f"stair_newel_{sx}", (0.13, 0.13, RAIL_H + 0.05), (xr, yb, zb + (RAIL_H + 0.05) / 2 - 0.1), "lacquer_red", bevel=0.025)
    giboshi(f"stair_gib_{sx}", xr, yb, zb + RAIL_H - 0.05)
    p0 = Vector((xr, yb, zb + RAIL_H - 0.12))
    p1 = Vector((sx * 1.45, RY_F, FL + RAIL_H))
    sweep(f"stair_rail_{sx}", [tuple(p0), tuple(p0.lerp(p1, 0.5)), tuple(p1)], 0.1, 0.1, "lacquer_red", bevel=0.02)
    q0 = Vector((xr, yb, zb + 0.32))
    q1 = Vector((sx * 1.45, RY_F, FL + 0.52))
    sweep(f"stair_rail_mid_{sx}", [tuple(q0), tuple(q1)], 0.07, 0.07, "lacquer_red")
    # passage du poteau de rambarde a la veranda
    bx_span(f"stair_link_{sx}", min(xr, sx * 1.45) - 0.05, max(xr, sx * 1.45) + 0.05, RY_F - 0.05, RY_F + 0.05, FL, FL + 0.1, "lacquer_red", bevel=0.01)

# =========================================================== auvent de l'escalier (kohai)
for sx in (-1, 1):
    x = sx * KPX
    cyl(f"kohai_post_{sx}", 0.15, 0.18, 3.25, x, KPY, "lacquer_red", verts=16, bevel=0.03)
    cyl(f"kohai_post_base_{sx}", 0.26, 0.0, 0.2, x, KPY, "stone", verts=12, bevel=0.03, r2=0.22)
    cyl(f"kohai_post_ring_{sx}", 0.175, 0.2, 0.3, x, KPY, "metal_gold", verts=16, bevel=0.01)
    # longrine vers le pilier de la salle
    bx_span(f"kohai_tie_{sx}", x - 0.09, x + 0.09, KPY - 0.25, YF, 3.05, 3.25, "lacquer_red", bevel=0.02)
    bx(f"kohai_tie_cap_{sx}", (0.15, 0.03, 0.17), (x, KPY - 0.265, 3.15), "metal_gold", bevel=0)
    bx(f"kohai_daito_{sx}", (0.38, 0.38, 0.14), (x, KPY, 3.32), "lacquer_red", bevel=0.025)
for sx in (-1, 1):
    bx(f"kohai_front_cap_{sx}", (0.03, 0.15, 0.17), (sx * (KPX + 0.265), KPY, 3.15), "metal_gold", bevel=0)
# panne avant de l'auvent, qui suit la sous-face
kxs = [-KX + 0.1 + (2 * KX - 0.2) * i / 8 for i in range(9)]
sweep("kohai_purlin_f", [(x, KPY, k_top(x, KPY) - 0.26 - 0.01) for x in kxs], 0.18, 0.22, "lacquer_red", dz_top=True, bevel=0.015)
# toit de l'auvent
kys = [KY1 + (KY0 - KY1) * i / 12 for i in range(13)]
heightfield("kohai_roof", [-KX + KX * i / 4 for i in range(9)], kys, k_top, lambda x, y: 0.26, "copper", "roof_edge", "soffit")
for sx in (-1, 1):
    pts = [(sx * (KX + 0.05), y, k_top(sx * KX, y) + 0.06) for y in kys]
    sweep(f"kohai_hafu_{sx}", pts, 0.08, 0.36, "wood_dark", dz_top=True, bevel=0.015)
    bx(f"kohai_hafu_cap_{sx}", (0.12, 0.16, 0.38), (sx * (KX + 0.05), KY1 + 0.06, k_top(sx * KX, KY1) - 0.12), "metal_gold", bevel=0.02)
for k in range(-5, 6):
    x = k * 0.4
    pts = []
    for q in range(6):
        y = KY0 - 0.05 + (KY1 + 0.08 - KY0 + 0.05) * q / 5
        pts.append((x, y, k_top(x, y) - 0.26 - 0.005))
    sweep(f"kohai_rafter_{k}", pts, 0.08, 0.09, "wood_dark", dz_top=True)

# shimenawa entre les piliers de l'auvent : deux torons tresses, shide et glands de paille
SH_Z, SH_SAG = 2.95, 0.38
N = 41
for strand in range(2):
    pts, radii = [], []
    for i in range(N):
        u = i / (N - 1)
        x = -KPX + 0.12 + (2 * KPX - 0.24) * u
        rad = 0.07 + 0.09 * math.sin(math.pi * u)
        zc = SH_Z - SH_SAG * math.sin(math.pi * u)
        a = u * 2 * math.pi * 8 + strand * math.pi
        pts.append((x, KPY + 0.55 * rad * math.cos(a), zc + 0.55 * rad * math.sin(a)))
        radii.append(rad * 0.62)
    tube(f"shimenawa_{strand}", pts, radii, "straw", nseg=8)
for k, x in enumerate((-0.85, -0.3, 0.3, 0.85)):
    u = (x + KPX - 0.12) / (2 * KPX - 0.24)
    zc = SH_Z - SH_SAG * math.sin(math.pi * u) - (0.07 + 0.09 * math.sin(math.pi * u)) + 0.02
    shide(f"shide_{k}", x, KPY - 0.02, zc, 1.0)
for k, x in enumerate((-0.58, 0.0, 0.58)):
    u = (x + KPX - 0.12) / (2 * KPX - 0.24)
    zc = SH_Z - SH_SAG * math.sin(math.pi * u) - 0.1
    cyl(f"fusa_{k}", 0.055, zc - 0.32, zc, x, KPY + 0.02, "straw", verts=8, bevel=0, r2=0.035)

# =========================================================== usure : mousse sur le socle et le toit
for k, (x, y, sz) in enumerate(((-6.2, -4.0, 1.0), (6.25, -2.0, 0.8), (-6.25, 2.5, 0.9), (5.9, 4.0, 0.7), (-2.5, 4.05, 0.8))):
    sphere(f"moss_base_{k}", 0.22 * sz, (x, y, 0.08), "moss", scale=(1.6, 1.0, 0.35), seg=8, rings=4)
for k, (x, y) in enumerate(((-5.6, -4.3), (5.9, 5.3), (-6.2, 3.9), (2.8, 5.5))):
    sphere(f"moss_roof_{k}", 0.3, (x, y, roof_top(x, y) - 0.04), "moss", scale=(1.5, 1.0, 0.18), seg=8, rings=4)

# =========================================================== reperes
empty("altar_anchor", (0, AY0 - 0.05, ALT_Z), size=0.3)
empty("lantern_anchor_l", (LANT[0][0], LANT[0][1], 3.86), size=0.2)
empty("lantern_anchor_r", (LANT[1][0], LANT[1][1], 3.86), size=0.2)

# =========================================================== fusion des pieces visibles (un seul mesh multi-materiaux)
vis = [o for o in bpy.context.scene.objects if o.type == "MESH"]
haiden = join(vis, "haiden")

# =========================================================== collisions
collision_box("haiden_floor", (2 * VX, VYB - VYF, FL), (0, (VYF + VYB) / 2, FL / 2))
collision_box("haiden_podium", (12.4, 8.3, PODIUM), (0, -0.15, PODIUM / 2))
col_prism_x("haiden_stairs", [(Y_RAMP0, 0.0), (VYF + 0.02, 0.0), (VYF + 0.02, FL)], -STAIR_W, STAIR_W)
for sx in (-1, 1):
    col_prism_x(f"haiden_stair_rail_{sx}", [(Y_STAIR_B - 0.2, 0.0), (VYF, 0.0), (VYF, FL + 1.0), (Y_STAIR_B - 0.2, 1.0)],
                *sorted((sx * STAIR_W, sx * (STAIR_W + 0.15))))
    collision_box(f"haiden_rail_f_{sx}", (VX - 1.4, 0.16, 1.0), (sx * (VX + 1.4) / 2, RY_F, FL + 0.5))
    collision_box(f"haiden_rail_s_{sx}", (0.16, VYB - VYF, 1.0), (sx * (VX - 0.08), (VYF + VYB) / 2, FL + 0.5))
    collision_box(f"haiden_wall_s_{sx}", (0.24, YB - YF + 0.3, 3.0), (sx * 4.5, (YF + YB) / 2, FL + 1.5))
    collision_box(f"haiden_kohai_post_{sx}", (0.32, 0.32, 3.2), (sx * KPX, KPY, 1.6))
collision_box("haiden_wall_b", (9.3, 0.24, 3.0), (0, YB, FL + 1.5))
for k, x in enumerate(PX):
    collision_box(f"haiden_post_f{k}", (0.36, 0.36, 3.0), (x, YF, FL + 1.5))
collision_box("haiden_altar", (2.9, AY1 - AY0 + 0.1, 0.75), (0, (AY0 + AY1) / 2 + 0.05, FL + 0.375))
for sx in (-1, 1):
    collision_box(f"haiden_andon_{sx}", (0.4, 0.4, 0.95), (sx * 2.05, AY0 + 0.6, FL + 0.475))

finish_model("haiden", expected_dims=(13.6, 12.5, 8.9), tri_limit=(5000, 60000), yaw=32, pitch=14)
