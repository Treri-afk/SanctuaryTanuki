"""Erables japonais (momiji) d'automne, refaits au propre (voir tree_util.py) :
- maple_tree  : grand erable de la cour et arbre sacre (shinboku), ~7,5 m, couronne large en dome ;
- maple_small : erable rond de 5 m (foret, enceinte) ;
- maple_red   : erable haut et etroit de 6 m, plus rouge.
Objets : trunk, foliage, trunk-col.
Lancer : blender --background --python tools/blender/maple_tree.py [-- maple_tree maple_small maple_red]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree_util import *

RED = ("#8E2A20", "#BE3F29", "#DD6236")
ORANGE = ("#A84E1E", "#D6772B", "#EEA03E")
AMBER = ("#A9701F", "#DDA53A", "#F2C95A")
CRIMSON = ("#7A2222", "#A83226", "#CC4B2E")
BARK = bark_color("#6A5446", "#4B3B31", moss="#6F8A3E", moss_h=0.8)

VIEWS = lambda m: [("_back", dict(yaw=-130, pitch=4, margin=m)), ("_low", dict(yaw=20, pitch=-4, margin=m * 0.75))]


def maple_tree():
    reset_scene()
    t = Broadleaf(seed=3)
    t.crown_c, t.crown_r = (0.1, 0.0, 5.0), (3.3, 3.1, 2.35)
    t.build_trunk([(0, 0, 0), (0.25, 0.05, 1.2), (0.05, 0.12, 2.3)], 0.42, BARK, roots=6, root_len=0.85, flare=0.75,
                  sides=11)
    t.gen_clumps(24, shell=(0.4, 0.78), size=(0.85, 1.2), squash=0.72, min_z=-0.45)
    t.build_branches(BARK, limbs=4, r_limb=0.2, r_twig=0.07)
    t.build_foliage([AMBER, ORANGE, RED, CRIMSON], subdiv=2)
    t.build()
    trunk_collision(0.42, 3.0)
    finish_tree("maple_tree", expected_dims=(6.6, 6.4, 7.5), tri_limit=(500, 7500), views=VIEWS(1.1), margin=1.1)


def maple_small():
    reset_scene()
    t = Broadleaf(seed=11)
    t.crown_c, t.crown_r = (0.0, 0.05, 3.55), (2.25, 2.15, 1.55)
    t.build_trunk([(0, 0, 0), (0.12, 0.04, 1.0), (0.0, 0.08, 1.9)], 0.28, BARK, roots=4, root_len=0.8, flare=0.6,
                  sides=9)
    t.gen_clumps(13, shell=(0.4, 0.75), size=(0.7, 0.95), squash=0.75, min_z=-0.4)
    t.build_branches(BARK, limbs=3, r_limb=0.13, r_twig=0.05, sides=6, twig_sides=4)
    t.build_foliage([AMBER, ORANGE, RED], card=(0.34, 0.27), density=1.9)
    t.build()
    trunk_collision(0.3, 2.4)
    finish_tree("maple_small", expected_dims=(4.5, 4.3, 5.0), tri_limit=(300, 4000), views=VIEWS(1.1), margin=1.1)


def maple_red():
    reset_scene()
    t = Broadleaf(seed=23)
    t.crown_c, t.crown_r = (0.0, 0.0, 3.95), (1.6, 1.5, 2.05)
    t.build_trunk([(0, 0, 0), (0.06, 0.05, 1.1), (-0.04, 0.0, 2.1)], 0.24, BARK, roots=4, root_len=0.7, flare=0.6,
                  sides=9)
    t.gen_clumps(12, shell=(0.4, 0.75), size=(0.62, 0.82), squash=0.85, min_z=-0.4, center=0.45)
    t.build_branches(BARK, limbs=3, r_limb=0.12, r_twig=0.045, sides=6, twig_sides=4)
    t.build_foliage([ORANGE, RED, CRIMSON], card=(0.32, 0.25), density=1.9)
    t.build()
    trunk_collision(0.28, 2.4)
    finish_tree("maple_red", expected_dims=(3.2, 3.0, 6.0), tri_limit=(300, 4000), views=VIEWS(1.1), margin=1.1)


ALL = {"maple_tree": maple_tree, "maple_small": maple_small, "maple_red": maple_red}
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
for a in args:
    ALL[a]()
