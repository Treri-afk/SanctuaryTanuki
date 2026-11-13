"""Lanterne de papier suspendue (chokin / chochin) : 0,38 m de diametre x 0,6 m de haut. ORIGINE = point d'accroche (haut),
le modele pend vers -Z. Corps en papier avec nervures fines, calottes noires, anneau de suspension. Pas de collision.
Lancer : blender --background --python tools/blender/paper_lantern.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

reset_scene()
N = 18
ZT, ZB = -0.118, -0.502          # haut / bas du corps de papier
RC, RMAX = 0.100, 0.190          # rayon aux calottes / ventre
ZM = (ZT + ZB) / 2
HH = (ZT - ZB) / 2


def r_body(z):
    u = (z - ZM) / HH
    return RC + (RMAX - RC) * max(0.0, 1 - u * u) ** 0.62


# ---------------------------------------------------------------- corps : revolution, nervures en gorges
b = Mesh()
prof, gaps = [(r_body(ZT), ZT)], []
rib_z = [-0.165 - 0.0505 * k for k in range(7)]       # 7 nervures
for k, zc in enumerate(rib_z):
    prof.append((r_body(zc + 0.0045), zc + 0.0045))     # haut de la nervure
    gaps.append("paper")
    prof.append((r_body(zc - 0.0045), zc - 0.0045))     # bas de la nervure
    gaps.append("wood_dark")
    if k < len(rib_z) - 1:
        zm = (zc + rib_z[k + 1]) / 2
        prof.append((r_body(zm) + 0.008, zm))           # papier tendu qui gonfle entre les nervures
        gaps.append("paper")
prof.append((r_body(ZB), ZB))
gaps.append("paper")
rev = prof[::-1]
gaps = gaps[::-1]
b.lathe(rev, N, lambda i, j: gaps[i], cap0=True, cap1=True)
body = b.build("lantern_body")

# ---------------------------------------------------------------- calottes noires haut / bas, patte, anneau
c = Mesh()
top = [(0.100, -0.121), (0.112, -0.114), (0.118, -0.098), (0.108, -0.079), (0.078, -0.064), (0.052, -0.059)]
c.lathe(top, N, "lacquer_black")
bot = [(0.052, -0.557), (0.075, -0.552), (0.108, -0.540), (0.118, -0.522), (0.112, -0.508), (0.100, -0.499)]
c.lathe(bot, N, "lacquer_black")
c.lathe([(0.015, -0.600), (0.018, -0.585), (0.016, -0.565), (0.030, -0.557)], 10, "lacquer_black")
caps = c.build("lantern_caps")
rg = Mesh()
torus(rg, (0, 0, -0.0345), 0.0275, 0.0062, "metal", axis="y", nmaj=14, nmin=6)
ring = rg.build("hanging_ring")

# anneau de suspension = point d'accroche : empty a l'origine
empty("hang_point", (0, 0, 0), size=0.05)

parts = [body, caps, ring]
tri_report(parts)
lan = join(parts, "paper_lantern")
apply_rot(lan, (0, 0, 8.0))

tfinish("paper_lantern", expected_dims=(0.38, 0.38, 0.60), tri_limit=(200, 1500), origin="top",
        angles={"paper_lantern": math.radians(60)}, lift_preview=0.62, yaw=30, pitch=8, margin=1.1,
        extra_views=[("_b", dict(yaw=-20, pitch=-5, margin=1.1))])
