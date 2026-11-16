"""Cedres du Japon (sugi), refaits au propre (voir tree_util.Conifer) :
- cedar_tree   : 16 m, droit, cone etroit et bombe, fleche fine ;
- cedar_tree_b : 12 m, trapu et penche, un etage casse (rameaux roussis, chicots nus).
Objets : trunk, foliage, trunk-col.
Lancer : blender --background --python tools/blender/forest_cedar.py [-- cedar_tree cedar_tree_b]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree_util import *

SUGI = [("#22392A", "#335238", "#456A40"), ("#253C2C", "#38563A", "#4D7142"), ("#213628", "#2F4C37", "#406343")]
SUGI_OLIVE = [("#2C3A24", "#46592F", "#5A6E38"), ("#263826", "#3A5232", "#4E683D")]
BARK = bark_color("#7A4E38", "#4E3326", moss="#5F7A38", moss_h=0.9, moss_r=0.7, seed=2)
VIEWS = [("_back", dict(yaw=-130, pitch=4, margin=1.05))]


def cedar_tree():
    reset_scene()
    t = Conifer(seed=5, H=16.0, z0=4.0, R=2.35, trunk_r=0.44, bark=BARK)
    t.build_trunk(roots=5)
    t.gen_clumps(21, size=(0.52, 0.44))
    t.build_branches(dead=[(2.3, 0.6, 0.5), (3.0, 3.1, 0.4), (3.6, 4.7, 0.45)])
    t.build_foliage(SUGI, density=1.05)
    t.build()
    trunk_collision(0.5, 4.0)
    finish_tree("cedar_tree", expected_dims=(4.6, 4.6, 16.0), tri_limit=(500, 4500), views=VIEWS, margin=1.05)


def cedar_tree_b():
    reset_scene()
    t = Conifer(seed=17, H=12.0, z0=3.1, R=2.6, trunk_r=0.5, bark=BARK, lean=(0.02, -0.01))
    t.build_trunk(roots=6)
    broken = lambda z, a: 4.6 < z < 6.0 and (a < 2.2 or a > 5.4)
    t.gen_clumps(21, size=(0.48, 0.45), skip=lambda z, a: 4.6 < z < 6.0 and 2.6 < a < 4.4)
    t.build_branches(dead=[(1.6, 2.0, 0.5), (5.2, 3.4, 1.2), (5.5, 3.9, 0.9)])
    t.build_foliage(SUGI_OLIVE, dry=broken, density=1.05)
    t.build()
    trunk_collision(0.55, 4.0)
    finish_tree("cedar_tree_b", expected_dims=(5.4, 5.4, 12.0), tri_limit=(500, 4500), views=VIEWS, margin=1.05)


ALL = {"cedar_tree": cedar_tree, "cedar_tree_b": cedar_tree_b}
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
for a in args:
    ALL[a]()
