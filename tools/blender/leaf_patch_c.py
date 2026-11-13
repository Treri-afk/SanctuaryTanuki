import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_leaf_patch import *
make_patch("leaf_patch_c", 29, ["foliage_red", "foliage_red", "foliage_orange", "foliage_light"], lumps_n=3, leaves_n=40)
