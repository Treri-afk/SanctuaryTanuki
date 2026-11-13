import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_leaf_patch import *
make_patch("leaf_patch_a", 3, ["foliage_orange", "foliage_orange", "foliage_red", "foliage_light"])
