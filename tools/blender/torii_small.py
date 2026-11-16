"""Petit torii myojin (portes de l'enceinte, sentiers), ~3,2 m pour 2,8 m de large, sans plaque.
La traverse basse (nuki) passe a 2,42 m, bien au-dessus des yeux du joueur (1,6 m) : plus bas, la camera la
traversait. La largeur tient dans les ouvertures de 2 m du mur d'enceinte. Voir torii_util.py.
Lancer : blender --background --python tools/blender/torii_small.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from torii_util import *

reset_scene()
make_torii(px=0.8, nuki_z=2.42, shim_z=2.78, kasa_z=2.9, kasa_half=1.38, kasa_lift=0.17, r_foot=0.165, r_top=0.135,
           scale_d=0.68, plaque=False, seed=7)
finish_tree("torii_small", expected_dims=(2.85, 0.6, 3.2), tri_limit=(300, 3500), trunk_angle=40, yaw=28, pitch=12,
            margin=1.05, views=[("_b", dict(yaw=-30, pitch=8, margin=1.05))])
