import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_rocks import *
body = make_rock("rock_b", 1.3, 1.0, 0.9, seed=23, n_main=90, lean=-0.07, bevel=0.05,
                 extras=[(0.52, -0.38, 0.62, 0.55, 0.42)], top_moss=4, base_moss=5, blob_r=0.11)
pfinish("rock_b", angles={"rock_b": math.radians(20), "rock_b_moss": math.radians(50)}, expected_dims=(1.3, 1.0, 0.9), tri_limit=(50, 3000))
