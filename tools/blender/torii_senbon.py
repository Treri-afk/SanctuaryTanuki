"""Torii du chemin des mille torii (senbon torii) du sentier nord : plus petits et plus fins que les torii des
portes (~2,6 m de haut, 1,7 m entre les piliers), poses tous les 70 cm pour former un tunnel vermillon.
Sans mousse ni plaque (ils sont des dizaines : peu de triangles). La traverse basse passe a 2,2 m, au-dessus des yeux.
Sert aussi, en tout petit, de torii offerts au sanctuaire Inari (scripts/landmarks.gd).
Lancer : blender --background --python tools/blender/torii_senbon.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from torii_util import *

reset_scene()
make_torii(px=0.86, nuki_z=2.2, shim_z=2.5, kasa_z=2.6, kasa_half=1.22, kasa_lift=0.11, r_foot=0.1, r_top=0.085,
           scale_d=0.5, plaque=False, seed=11, moss=False)
finish_tree("torii_senbon", expected_dims=(2.5, 0.4, 2.75), tri_limit=(200, 2600), trunk_angle=40, yaw=28, pitch=12,
            margin=1.05)
