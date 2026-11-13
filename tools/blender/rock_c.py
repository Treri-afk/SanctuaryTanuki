import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_rocks import *
body = make_rock("rock_c", 2.0, 1.5, 1.45, seed=37, n_main=130, lean=0.08, bevel=0.07,
                 extras=[(-0.75, -0.55, 0.95, 0.75, 0.6), (0.7, 0.45, 0.8, 0.7, 0.5)],
                 top_moss=6, base_moss=7, blob_r=0.15)
pfinish("rock_c", angles={"rock_c": math.radians(20), "rock_c_moss": math.radians(50)}, expected_dims=(2.0, 1.5, 1.45), tri_limit=(50, 3000))
