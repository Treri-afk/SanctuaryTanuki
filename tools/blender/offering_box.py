"""Saisen-bako (tronc a offrandes) sous un portique vermillon a petit toit de cuivre, avec cloches suzu et corde tressee.

Le tronc : caisse de bois clair, entonnoir de lattes en V sur le dessus, cadre sombre, ferrures et mon dores.
Le portique : deux piliers vermillon sur bases de pierre (bagues dorees), traverse (nuki) et poutre haute, toit a
pignon en cuivre vert-de-gris (meme vocabulaire que le haiden), shide.
Objets separes animes par le jeu : `bell` (grappe de 3 suzu, origine au crochet), `rope` (corde rouge-blanc-violet
et gland, origine en haut, sans collision), empty `rope_anchor` (bas de la corde).
Lancer : blender --background --python tools/blender/offering_box.py     Avant = -Y."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrine_util import *

reset_scene()

# =========================================================== gabarit
BX = 0.78                 # demi-largeur du tronc
BY0, BY1 = -0.08, 0.72    # face avant / arriere du tronc
ZB = 0.80                 # dessus de la caisse (sous le cadre)
ZT = 0.92                 # dessus du cadre
PX, PY = 1.05, -0.12      # piliers du portique
RY = -0.22                # verticale de la cloche et de la corde
Z_NUKI = (2.35, 2.50)
Z_BEAM = (2.82, 3.00)

# toit a pignon (faitage le long de X)
RYC, RYH, RXH = PY, 0.78, 1.45
RE, RH, RT = 3.07, 0.50, 0.14


def r_top(x, y):
    t = max(0.0, min((RYH - abs(y - RYC)) / RYH, 1.0))
    lift = 0.13 * (abs(x) / RXH) ** 3 * (1 - t) ** 2
    return RE + RH * (0.45 * t + 0.55 * t * t) + lift


def r_bot(x, y):
    return r_top(x, y) - RT


RIDGE = r_top(0, RYC)


def disc_y(name, r, depth, x, y, z, m, verts=20):
    """Disque vertical (face vers -Y)."""
    o = cyl(name, r, -depth / 2, depth / 2, 0, 0, m, verts=verts, bevel=0)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.location = (x, y, z)
    return o


# =========================================================== tronc (saisen-bako)
bx_span("plinth", -BX - 0.12, BX + 0.12, BY0 - 0.1, BY1 + 0.1, 0.0, 0.09, "stone", bevel=0.03)
for sx in (-1, 1):
    for y in (BY0 + 0.07, BY1 - 0.07):
        bx(f"foot_{sx}_{y}", (0.16, 0.14, 0.08), (sx * (BX - 0.08), y, 0.13), "wood_dark", bevel=0.015)
bx_span("body", -BX, BX, BY0, BY1, 0.16, ZB, "wood_light", bevel=0.03, seg=2)
# cadre de facade en saillie : traverses et montants sombres, panneau clair au centre
bx_span("front_rail_lo", -BX - 0.01, BX + 0.01, BY0 - 0.03, BY0 + 0.02, 0.17, 0.27, "wood_dark", bevel=0.015)
bx_span("front_rail_hi", -BX - 0.01, BX + 0.01, BY0 - 0.03, BY0 + 0.02, 0.68, 0.78, "wood_dark", bevel=0.015)
for x in (-BX + 0.05, -0.26, 0.26, BX - 0.05):
    bx_span(f"front_stile_{x}", x - 0.05, x + 0.05, BY0 - 0.03, BY0 + 0.02, 0.27, 0.68, "wood_dark", bevel=0.012)
for sx in (-1, 1):
    bx_span(f"side_rail_lo_{sx}", sx * (BX - 0.02), sx * (BX + 0.03), BY0, BY1, 0.17, 0.27, "wood_dark", bevel=0.012)
    bx_span(f"side_rail_hi_{sx}", sx * (BX - 0.02), sx * (BX + 0.03), BY0, BY1, 0.68, 0.78, "wood_dark", bevel=0.012)
# mon dore au centre de la facade
disc_y("mon", 0.12, 0.03, 0, BY0 - 0.035, 0.475, "metal_gold", verts=24)
disc_y("mon_inner", 0.075, 0.035, 0, BY0 - 0.04, 0.475, "wood_dark", verts=20)
for k in range(3):
    a = math.radians(90 + 120 * k)
    sphere(f"mon_tomoe_{k}", 0.028, (0.042 * math.cos(a), BY0 - 0.06, 0.475 + 0.042 * math.sin(a)), "metal_gold",
           scale=(1, 0.5, 1), seg=8, rings=4)
# bande noire laquee sous le cadre du dessus
bx_span("top_band", -BX - 0.02, BX + 0.02, BY0 - 0.02, BY1 + 0.02, ZB - 0.02, ZB + 0.04, "lacquer_black", bevel=0.01)
# cadre du dessus et entonnoir de lattes en V
for (y0, y1) in ((BY0 - 0.03, BY0 + 0.06), (BY1 - 0.06, BY1 + 0.03)):
    bx_span(f"top_frame_{y0}", -BX - 0.03, BX + 0.03, y0, y1, ZB + 0.03, ZT, "wood_dark", bevel=0.018)
for sx in (-1, 1):
    bx_span(f"top_frame_s{sx}", sx * (BX - 0.06), sx * (BX + 0.03), BY0 + 0.06, BY1 - 0.06, ZB + 0.03, ZT, "wood_dark", bevel=0.018)
bx_span("funnel_dark", -BX + 0.06, BX - 0.06, BY0 + 0.06, BY1 - 0.06, ZB - 0.04, ZB + 0.01, "lacquer_black", bevel=0)
n_sl = 8
for i in range(n_sl):
    y = BY0 + 0.06 + (BY1 - BY0 - 0.12) * (i + 0.5) / n_sl
    prism_x(f"slat_{i}", [(y - 0.032, ZB + 0.01), (y + 0.032, ZB + 0.01), (y, ZT - 0.005)], -BX + 0.06, BX - 0.06,
            "wood_light")
# ferrures dorees aux angles (haut et bas), en L
for sx in (-1, 1):
    for sy, y in ((-1, BY0), (1, BY1)):
        for z in (0.2, 0.74):
            bx(f"corner_a_{sx}_{sy}_{z}", (0.14, 0.02, 0.1), (sx * (BX - 0.06), y + sy * 0.035, z), "metal_gold", bevel=0.006)
            bx(f"corner_b_{sx}_{sy}_{z}", (0.02, 0.14, 0.1), (sx * (BX + 0.035), y - sy * 0.06, z), "metal_gold", bevel=0.006)
        bx(f"top_corner_{sx}_{sy}", (0.12, 0.12, 0.02), (sx * (BX - 0.02), y - sy * 0.01, ZT + 0.008), "metal_gold", bevel=0.005)

# =========================================================== portique
for sx in (-1, 1):
    x = sx * PX
    cyl(f"post_{sx}", 0.1, 0.18, Z_BEAM[0] + 0.02, x, PY, "lacquer_red", verts=16, bevel=0.025)
    cyl(f"post_base_{sx}", 0.2, 0.0, 0.2, x, PY, "stone", verts=12, bevel=0.025, r2=0.16)
    cyl(f"post_ring_{sx}", 0.115, 0.2, 0.29, x, PY, "metal_gold", verts=16, bevel=0.01)
    cyl(f"post_ring_hi_{sx}", 0.115, Z_NUKI[0] - 0.12, Z_NUKI[0] - 0.06, x, PY, "metal_gold", verts=16, bevel=0.008)
    bx(f"post_daito_{sx}", (0.28, 0.3, 0.1), (x, PY, Z_BEAM[0] - 0.03), "lacquer_red", bevel=0.02)
bx_span("nuki", -PX - 0.3, PX + 0.3, PY - 0.07, PY + 0.07, *Z_NUKI, "lacquer_red", bevel=0.02)
bx_span("beam", -PX - 0.2, PX + 0.2, PY - 0.12, PY + 0.12, *Z_BEAM, "lacquer_red", bevel=0.025)
for sx in (-1, 1):
    bx(f"nuki_cap_{sx}", (0.03, 0.15, 0.16), (sx * (PX + 0.315), PY, sum(Z_NUKI) / 2), "metal_gold", bevel=0.005)
    bx(f"beam_cap_{sx}", (0.03, 0.25, 0.19), (sx * (PX + 0.215), PY, sum(Z_BEAM) / 2), "metal_gold", bevel=0.005)
# petit kaerumata sous la poutre, au-dessus de la traverse (sur les cotes : la cloche pend au centre)
for sx in (-1, 1):
    x = sx * 0.62
    prism_y(f"kaeru_{sx}", [(x - 0.2, Z_NUKI[1]), (x + 0.2, Z_NUKI[1]), (x + 0.07, Z_BEAM[0]), (x - 0.07, Z_BEAM[0])],
            PY - 0.05, PY + 0.05, "lacquer_red", bevel=0.01)
    bx(f"kaeru_gold_{sx}", (0.1, 0.02, 0.08), (x, PY - 0.06, (Z_NUKI[1] + Z_BEAM[0]) / 2), "metal_gold", bevel=0)
# shide accroches a la traverse
for k, x in enumerate((-0.82, 0.82)):
    shide(f"shide_{k}", x, PY - 0.08, Z_NUKI[0] + 0.01, 0.9)
    bx(f"shide_tie_{k}", (0.03, 0.03, 0.04), (x, PY - 0.08, Z_NUKI[0] + 0.01), "straw", bevel=0)

# =========================================================== toit de cuivre a pignon
# pignons : triangles de bois sous le toit, poinçon central
for sx in (-1, 1):
    out = [(RYC - 0.55, Z_BEAM[1] - 0.01)]
    for k in range(9):
        y = RYC - 0.55 + 1.1 * k / 8
        out.append((y, r_bot(sx * 1.2, y) + 0.02))
    out.append((RYC + 0.55, Z_BEAM[1] - 0.01))
    prism_x(f"gable_{sx}", out, sx * 1.14, sx * 1.22, "wood_dark")
    bx_span(f"gable_tie_{sx}", sx * 1.12, sx * 1.24, RYC - 0.3, RYC + 0.3, Z_BEAM[1] + 0.12, Z_BEAM[1] + 0.2, "lacquer_red", bevel=0.01)
bx_span("king_post", -0.07, 0.07, RYC - 0.07, RYC + 0.07, Z_BEAM[1], r_bot(0, RYC) + 0.02, "lacquer_red", bevel=0.012)
sweep("ridge_beam", [(x, RYC, r_bot(x, RYC) - 0.06) for x in (-1.3, 0.0, 1.3)], 0.14, 0.14, "wood_dark")
xs = [-RXH + RXH * i / 6 for i in range(13)]
ys = [RYC - RYH + 2 * RYH * j / 12 for j in range(13)]
heightfield("roof", xs, ys, r_top, lambda x, y: RT, "copper", "roof_edge", "soffit")
# chevrons sous l'egout
for k in range(-6, 7):
    x = k * 0.2
    for sy in (-1, 1):
        pts = []
        for q in range(4):
            y = RYC + sy * (0.08 + (RYH - 0.12) * q / 3)
            pts.append((x, y, r_bot(x, y) - 0.003))
        sweep(f"rafter_{k}_{sy}", pts, 0.05, 0.05, "wood_dark", dz_top=True)
# planches de rive et faitage
for sx in (-1, 1):
    for sy in (-1, 1):
        pts = []
        for q in range(8):
            d = q / 7
            y = RYC + sy * (RYH + 0.04) * (1 - d)
            pts.append((sx * (RXH + 0.03), y, r_top(sx * RXH, y) + 0.04 + 0.05 * (1 - d) ** 6))
        sweep(f"hafu_{sx}_{sy}", pts, 0.06, 0.2, "wood_dark", dz_top=True, bevel=0.01)
        x0, y0, z0 = pts[0]
        bx(f"hafu_cap_{sx}_{sy}", (0.08, 0.1, 0.22), (x0, y0, z0 - 0.1), "metal_gold", bevel=0.01)
    prism_x(f"gegyo_{sx}", [(RYC - 0.13, RIDGE - 0.14), (RYC, RIDGE - 0.27), (RYC + 0.13, RIDGE - 0.14), (RYC + 0.09, RIDGE - 0.05),
                            (RYC - 0.09, RIDGE - 0.05)], sx * (RXH + 0.06), sx * (RXH + 0.09), "metal_gold")
rx = [-RXH - 0.08 + (2 * RXH + 0.16) * i / 10 for i in range(11)]
rl = lambda x: 0.05 * (abs(x) / RXH) ** 3
sweep("ridge_base", [(x, RYC, RIDGE + 0.05 + rl(x)) for x in rx], 0.28, 0.14, "copper_dark", bevel=0.01)
sweep("ridge_top", [(x, RYC, RIDGE + 0.17 + rl(x)) for x in rx], 0.18, 0.12, "copper", bevel=0.02)
for sx in (-1, 1):
    x = sx * (RXH + 0.07)
    bx(f"ridge_end_{sx}", (0.1, 0.3, 0.3), (x, RYC, RIDGE + 0.15 + rl(x)), "lacquer_black", bevel=0.025)
    sphere(f"ridge_disc_{sx}", 0.075, (x + sx * 0.06, RYC, RIDGE + 0.16 + rl(x)), "metal_gold", scale=(0.4, 1, 1), seg=10, rings=6)

# usure : mousse au pied
for k, (x, y, s) in enumerate(((0.75, BY0 - 0.16, 1.0), (-0.85, BY1 + 0.12, 0.8), (-PX - 0.15, PY - 0.12, 0.7), (PX + 0.12, PY + 0.14, 0.6))):
    sphere(f"moss_{k}", 0.13 * s, (x, y, 0.05), "moss", scale=(1.5, 1.0, 0.4), seg=8, rings=4)
sphere("moss_roof", 0.16, (-0.85, RYC + 0.5, r_top(-0.85, RYC + 0.5) - 0.02), "moss", scale=(1.5, 1, 0.2), seg=8, rings=4)

static = [o for o in bpy.context.scene.objects if o.type == "MESH"]
join(static, "offering_box")

# =========================================================== cloches (objet `bell`, origine au crochet)
HOOK = Z_BEAM[0]
BAR_Z = 2.27
MAIN_Z = 2.02
b = []
b.append(cyl("bell_chain", 0.016, BAR_Z, HOOK, 0, RY, "metal", verts=6, bevel=0))
b.append(bx("bell_hook", (0.06, 0.06, 0.05), (0, RY, HOOK - 0.02), "metal_gold", bevel=0.008))
o = cyl("bell_bar", 0.022, -0.33, 0.33, 0, 0, "metal_gold", verts=8, bevel=0)
o.rotation_euler = (0, math.radians(90), 0)
o.location = (0, RY, BAR_Z)
b.append(o)


def suzu(name, r, x, z):
    parts = [sphere(name + "_body", r, (x, RY, z), "metal_gold", scale=(1, 1, 0.94), seg=18, rings=10),
             cyl(name + "_band", r * 1.03, z - r * 0.06, z + r * 0.06, x, RY, "metal_gold", verts=18, bevel=0),
             cyl(name + "_neck", r * 0.28, z + r * 0.85, z + r * 1.1, x, RY, "metal_gold", verts=10, bevel=0),
             bx(name + "_slit", (r * 1.3, r * 2.1, r * 0.12), (x, RY, z - r * 0.62), "lacquer_black", bevel=0)]
    for sx in (-1, 1):
        parts.append(sphere(name + f"_hole_{sx}", r * 0.13, (x + sx * r * 0.62, RY - r * 0.62, z - r * 0.6), "lacquer_black",
                            scale=(1, 0.5, 1), seg=8, rings=4))
    return parts


b += suzu("suzu_main", 0.22, 0, MAIN_Z)
b.append(cyl("suzu_main_link", 0.012, MAIN_Z + 0.23, BAR_Z, 0, RY, "metal", verts=6, bevel=0))
for sx in (-1, 1):
    x = sx * 0.3
    b += suzu(f"suzu_{sx}", 0.095, x, BAR_Z - 0.16)
    b.append(cyl(f"suzu_link_{sx}", 0.01, BAR_Z - 0.07, BAR_Z, x, RY, "metal", verts=6, bevel=0))
bell = join(b, "bell")
bpy.context.scene.cursor.location = (0, RY, HOOK)
bpy.ops.object.select_all(action="DESELECT")
bell.select_set(True)
bpy.context.view_layer.objects.active = bell
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

# =========================================================== corde (objet `rope`, origine en haut, sans collision)
Z_TOP, Z_KNOT, Z_BOT = MAIN_Z - 0.21, 1.16, 0.93
r = []
r.append(cyl("rope_loop", 0.035, Z_TOP - 0.04, Z_TOP + 0.02, 0, RY, "metal_gold", verts=10, bevel=0))
N = 34
cols = ("lacquer_red", "paper", "cloth_purple")
for s_i, m in enumerate(cols):
    pts, radii = [], []
    for i in range(N):
        u = i / (N - 1)
        z = Z_TOP - 0.03 - (Z_TOP - 0.03 - Z_KNOT) * u
        a = u * 2 * math.pi * 6 + s_i * 2 * math.pi / 3
        pts.append((0.028 * math.cos(a), RY + 0.028 * math.sin(a), z))
        radii.append(0.033)
    r.append(tube(f"rope_strand_{s_i}", pts, radii, m, nseg=6))
r.append(sphere("rope_knot", 0.055, (0, RY, Z_KNOT - 0.02), "lacquer_red", scale=(1, 1, 1.15), seg=10, rings=6))
r.append(cyl("rope_band", 0.05, Z_KNOT - 0.1, Z_KNOT - 0.06, 0, RY, "metal_gold", verts=10, bevel=0))
r.append(cyl("rope_tassel", 0.045, Z_BOT + 0.03, Z_KNOT - 0.08, 0, RY, "cloth_purple", verts=10, bevel=0, r2=0.04))
r.append(cyl("rope_fringe", 0.07, Z_BOT, Z_BOT + 0.1, 0, RY, "cloth_purple", verts=10, bevel=0, r2=0.045))
rope = join(r, "rope")
bpy.context.scene.cursor.location = (0, RY, Z_TOP)
bpy.ops.object.select_all(action="DESELECT")
rope.select_set(True)
bpy.context.view_layer.objects.active = rope
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
empty("rope_anchor", (0, RY, Z_BOT), size=0.08)

# =========================================================== collisions (pas sur la corde)
collision_box("offering_box", (2 * BX + 0.24, BY1 - BY0 + 0.2, ZT + 0.03), (0, (BY0 + BY1) / 2, (ZT + 0.03) / 2))
for sx in (-1, 1):
    collision_box(f"offering_post_{sx}", (0.36, 0.36, 2.9), (sx * PX, PY, 1.45))

finish_model("offering_box", expected_dims=(3.1, 1.8, 3.8), tri_limit=(2000, 20000), yaw=28, pitch=10)
