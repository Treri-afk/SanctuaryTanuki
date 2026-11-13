"""Plaquette d'ema seule : 12 x 9 cm, epaisseur 9 mm, forme de maison pentagonale, bois clair, ficelle courte.
Origine = sol, centree ; plaquette debout (face vers -Y), bord bas sur z = 0 ; la ficelle forme une boucle au-dessus du sommet.
Pas de collision. Lancer : blender --background --python tools/blender/ema_loose.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *

reset_scene()
T = 0.009
HOLE_Z = 0.074

# ---------------------------------------------------------------- plaquette pentagonale, trouee au sommet
plate = Mesh()
prism_y(plate, [(-0.06, 0.0), (0.06, 0.0), (0.06, 0.056), (0.0, 0.09), (-0.06, 0.056)], -T / 2, T / 2, "wood_light")
pl = plate.build("ema_plate")
hole = cylinder("hole", 0.0042, 0.03, (0, 0, HOLE_Z), "wood_light", rot=(math.radians(90), 0, 0), verts=8, bevel=0)
bool_cut(pl, hole)
common._finalize_obj(pl, None, 0.0014, "ema_plate")

# ---------------------------------------------------------------- traits d'encre (suggestion d'ecriture) + ficelle
d = Mesh()
YF = -T / 2 - 0.0004
for z, w in ((0.044, 0.075), (0.030, 0.06), (0.016, 0.068)):
    add_box(d, (0.0, YF, z), (w, 0.0010, 0.0045), "wood_dark")
add_box(d, (0.036, YF, 0.059), (0.011, 0.0010, 0.011), "lacquer_red")      # petit sceau
ink = d.build("ema_ink")
cm = Mesh()
loop_tube_yz(cm, (0.0, HOLE_Z + 0.022), 0.0115, 0.022, 0.0022, "rope", nseg=16, nsides=5)
cord = cm.build("ema_cord")

parts = [pl, ink, cord]
tri_report(parts)
em = join(parts, "ema_loose")

tfinish("ema_loose", expected_dims=(0.12, 0.028, 0.12), tri_limit=(50, 600),
        angles={"ema_loose": math.radians(40)}, yaw=25, pitch=15, margin=1.1,
        extra_views=[("_b", dict(yaw=-35, pitch=10, margin=1.1))])
