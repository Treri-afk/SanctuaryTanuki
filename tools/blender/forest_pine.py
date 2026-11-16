"""Pin noir du Japon (kuromatsu), refait au propre (voir tree_util.Pine) : pine_tree, ~9 m.
Tronc tordu et penche, branches presque horizontales, plateaux d'aiguilles plats et etages (dessus clair,
dessous sombre), aiguilles qui rayonnent sur le bord. Objets : trunk, foliage, trunk-col.
Lancer : blender --background --python tools/blender/forest_pine.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree_util import *

BARK = bark_color("#5C4537", "#3E2F28", moss="#5F7A38", moss_h=0.7, moss_r=0.8, seed=7)
NEEDLES = ("#24382A", "#36533A", "#5A7B48")

reset_scene()
t = Pine(seed=9, bark=BARK)
trunk = [(0.0, 0.0, 0.0), (0.05, 0.0, 0.4), (0.3, 0.05, 1.2), (0.7, 0.1, 2.1), (0.8, 0.2, 3.0), (0.4, 0.28, 3.9),
         (-0.15, 0.18, 4.7), (-0.45, 0.0, 5.6), (-0.4, -0.2, 6.4), (-0.05, -0.22, 7.2), (0.2, -0.1, 7.9),
         (0.25, 0.0, 8.4)]
t.trunk(trunk, [0.52, 0.44, 0.39, 0.35, 0.32, 0.29, 0.27, 0.24, 0.2, 0.15, 0.1, 0.06], sides=9, roots=4)
# branches porteuses -> plateaux
t.branch((0.78, 0.18, 2.8), (2.3, -0.4, 3.9), 0.17, 0.06, bend=0.25)
t.branch((-0.3, 0.1, 5.0), (-2.2, 0.55, 5.9), 0.15, 0.05, bend=0.3)
t.branch((-0.3, -0.2, 6.6), (1.4, -0.8, 7.2), 0.12, 0.045, bend=0.2)
t.branch((0.55, 0.25, 3.6), (-0.9, 1.3, 4.3), 0.11, 0.04, bend=0.25)
t.branch((-0.4, -0.1, 5.8), (-1.0, -1.4, 6.5), 0.1, 0.035, bend=0.2)
t.pad((2.3, -0.4, 4.1), 1.6, 0.62, yaw=0.3, sat=3)
t.pad((-2.15, 0.55, 6.1), 1.45, 0.6, yaw=1.2, sat=3)
t.pad((1.35, -0.8, 7.4), 1.25, 0.55, yaw=-0.4, sat=2)
t.pad((0.25, 0.0, 8.4), 1.0, 0.5, yaw=0.8, sat=2)
t.pad((-0.9, 1.35, 4.45), 0.95, 0.45, yaw=2.0, sat=2)
t.pad((-1.0, -1.4, 6.65), 0.85, 0.42, yaw=-1.1, sat=1)
t.build_foliage(NEEDLES)
t.build()
trunk_collision(0.45, 3.0, at=(0.35, 0.08))
finish_tree("pine_tree", expected_dims=(6.0, 3.5, 9.0), tri_limit=(500, 4500),
            views=[("_back", dict(yaw=-130, pitch=4, margin=1.05)), ("_side", dict(yaw=90, pitch=2, margin=1.05))],
            margin=1.05)
