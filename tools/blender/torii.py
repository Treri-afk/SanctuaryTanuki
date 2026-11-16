"""Grand torii myojin, ~3,5 m (pose a l'echelle 1,5 dans le jeu : 5,3 m, comme le pavillon).
Les hauteurs du nuki (2,42 m) et des piliers (+-1,2 m) sont gardees : la corde sacree (shimenawa) y est accrochee.
Voir torii_util.py. Lancer : blender --background --python tools/blender/torii.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from torii_util import *

reset_scene()
make_torii(px=1.2, nuki_z=2.36, shim_z=2.86, kasa_z=3.01, kasa_half=2.08, kasa_lift=0.26, r_foot=0.25, r_top=0.205,
           scale_d=1.0, plaque=True, seed=3)
finish_tree("torii", expected_dims=(4.3, 0.75, 3.5), tri_limit=(500, 4000), trunk_angle=40, yaw=30, pitch=12,
            margin=1.05, views=[("_b", dict(yaw=-25, pitch=4, margin=1.05)), ("_close", dict(yaw=12, pitch=-6, margin=0.55))])
