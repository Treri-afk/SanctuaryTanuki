import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_leaf_patch import *
make_patch("leaf_patch_b", 17, ["foliage_light", "foliage_light", "foliage_orange", "foliage_orange"], lumps_n=3, leaves_n=42)
