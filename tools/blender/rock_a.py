import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_rocks import *
body = make_rock("rock_a", 0.8, 0.65, 0.5, seed=11, n_main=70, lean=0.0, bevel=0.035,
                 extras=[(0.30, -0.26, 0.34, 0.3, 0.24)], top_moss=2, base_moss=3, blob_r=0.07)
pfinish("rock_a", angles={"rock_a": math.radians(20), "rock_a_moss": math.radians(50)}, expected_dims=(0.8, 0.65, 0.5), tri_limit=(50, 3000))
