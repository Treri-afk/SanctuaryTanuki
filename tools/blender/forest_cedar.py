"""Cedres du Japon (sugi) : cedar_tree (16 m) et cedar_tree_b (12 m, trapu, un etage casse).
Objets : trunk, foliage, trunk-col."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forest_util import *


def radius_profile(z, H, r_mid, flare, flare_len):
    return r_mid * max(0.0, 1 - z / (H * 1.04)) ** 1.1 + flare * math.exp(-z / flare_len)


def build_trunk(H, zs, r_mid, flare, flare_len, sway, lean, phase, stubs, root_n, seed):
    tb = Builder()
    pts = trunk_path(zs, sway=sway, lean=lean, phase=phase)
    radii = [radius_profile(z, H, r_mid, flare, flare_len) for z in zs]
    tb.tube(pts, radii, sides=8, m="bark_cedar")
    roots(tb, root_n, radii[0] * 0.75, 0.0, "bark_cedar", seed=seed, length=0.75, rr=0.2)
    for (z, ang, ln) in stubs:     # chicots de branches mortes sur le bas du tronc
        i = min(range(len(zs)), key=lambda k: abs(zs[k] - z))
        px, py, _ = pts[i]
        r = radii[i]
        ca, sa = math.cos(ang), math.sin(ang)
        tb.tube([(px + 0.6 * r * ca, py + 0.6 * r * sa, z), (px + (r + ln) * ca, py + (r + ln) * sa, z + 0.25 * ln)],
                [0.05, 0.03], sides=5, m="bark_cedar")
    return tb, pts


# ================================================================ cedar_tree
reset_scene()
H = 16.0
zs = [0, 0.4, 0.9, 1.6, 2.8, 4.2, 6.0, 8.0, 10.0, 12.0, 14.0, 15.6]
tb, tp = build_trunk(H, zs, 0.46, 0.26, 0.55, (0.10, 0.10), (0.0, 0.0), 0.6,
                     stubs=[(2.4, 0.5, 0.35), (3.1, 3.0, 0.28), (3.7, 4.6, 0.3)], root_n=4, seed=1)
ground_clamp(tb)
trunk = tb.build("trunk")

fb = Builder()
# base z, rayon, hauteur, materiau, decalage xy
tiers = [
    (4.3, 2.1, 3.6, "foliage_deep_green", (0.05, 0.0)),
    (6.4, 2.0, 3.5, "foliage_green", (-0.12, 0.10)),
    (8.5, 1.75, 3.4, "foliage_deep_green", (0.12, -0.06)),
    (10.6, 1.40, 3.3, "foliage_green", (0.06, 0.12)),
    (12.7, 0.95, 3.3, "foliage_deep_green", (-0.04, 0.02)),
]
for i, (z0, R, Ht, m, (dx, dy)) in enumerate(tiers):
    cx = tp[min(range(len(zs)), key=lambda k: abs(zs[k] - z0))][0] + dx
    cy = tp[min(range(len(zs)), key=lambda k: abs(zs[k] - z0))][1] + dy
    cedar_tier(fb, (cx, cy, z0), R, Ht, m, sides=20, seed=i * 2.1 + 1)
    # grappes de rameaux qui debordent (asymetrie) + petite touche plus claire
    for k, (ang, rad, sz) in enumerate([(0.9 + i * 1.7, 0.78, 0.55)]):
        fb.blob((cx + R * rad * math.cos(ang), cy + R * rad * math.sin(ang), z0 + 0.25 * Ht),
                (sz * R * 0.55, sz * R * 0.55, sz * 0.9), "foliage_green_light" if (i + k) % 3 == 0 else m,
                subdiv=2, noise=0.12, seed=i * 7 + k, bottom=0.5)
foliage = fb.build("foliage")
cylinder("trunk-col", 0.5, 4.0, loc=(0, 0, 2.0), material=None, verts=10, bevel=0).display_type = "WIRE"
finish("cedar_tree", expected_dims=(4.6, 4.6, 16.0), tri_limit=(100, 3000),
       angles={"trunk": math.radians(55), "foliage": math.radians(180)}, margin=1.05,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.05))])

# ================================================================ cedar_tree_b
reset_scene()
H = 12.0
zs = [0, 0.4, 0.9, 1.6, 2.8, 4.2, 6.0, 8.0, 10.0, 11.5]
tb, tp = build_trunk(H, zs, 0.50, 0.30, 0.5, (0.18, 0.12), (0.09, -0.04), 2.0,
                     stubs=[(1.8, 2.0, 0.4), (2.6, 5.0, 0.3)], root_n=5, seed=4)
# branche maitresse cassee, pendante (etage casse)
bx, by, bz = tp[5]
tb.tube([(bx + 0.2, by - 0.05, 4.9), (bx + 0.9, by - 0.3, 5.0), (bx + 1.5, by - 0.5, 4.5)], [0.14, 0.09, 0.05],
        sides=6, m="bark_cedar")
ground_clamp(tb)
trunk = tb.build("trunk")

fb = Builder()
tiers = [
    (2.5, 2.7, 3.0, "foliage_olive", (0.10, 0.0), None),
    (5.0, 1.9, 2.3, "foliage_dry", (-0.25, 0.15), (math.radians(-60), math.radians(115), 0.05)),   # etage casse
    (7.5, 2.0, 2.6, "foliage_green", (0.35, -0.1), None),
    (9.3, 1.3, 2.7, "foliage_olive", (0.2, 0.1), None),
]
for i, (z0, R, Ht, m, (dx, dy), bite) in enumerate(tiers):
    ci = min(range(len(zs)), key=lambda k: abs(zs[k] - z0))
    cx, cy = tp[ci][0] + dx, tp[ci][1] + dy
    cedar_tier(fb, (cx, cy, z0), R, Ht, m, sides=20, seed=i * 3.3 + 5, bite=bite, droop=0.5)
    if bite is None:
        for k, (ang, rad, sz) in enumerate([(2.2 + i * 1.3, 0.8, 0.6), (5.4 + i * 1.9, 0.7, 0.5)]):
            fb.blob((cx + R * rad * math.cos(ang), cy + R * rad * math.sin(ang), z0 + 0.25 * Ht),
                    (sz * R * 0.55, sz * R * 0.5, sz * 0.9), "foliage_green_light" if (i + k) % 3 == 1 else m,
                    subdiv=2, noise=0.12, seed=i * 5 + k, bottom=0.5)
# quelques rameaux verts survivants sur l'etage casse
fb.blob((tp[ci][0] - 1.2, tp[ci][1] - 0.2, 5.3), (0.9, 0.7, 0.55), "foliage_olive", subdiv=2, noise=0.12, seed=3, bottom=0.5)
foliage = fb.build("foliage")
cylinder("trunk-col", 0.55, 4.0, loc=(0.1, 0.05, 2.0), material=None, verts=10, bevel=0).display_type = "WIRE"
finish("cedar_tree_b", expected_dims=(5.4, 5.4, 12.0), tri_limit=(100, 3000),
       angles={"trunk": math.radians(55), "foliage": math.radians(180)}, margin=1.05,
       extra_views=[("_back", dict(yaw=-130, pitch=4, margin=1.05))])
