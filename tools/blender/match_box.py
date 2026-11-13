"""Boite d'allumettes 6x4x2 cm + une allumette posee dessus (tenue en main). Origine centree au sol."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props_util import *

reset_scene()
BV = 0.0016
parts = []
# tiroir (bois clair) legerement sorti, fourreau (bois sombre + etiquette rouge)
parts.append(box("drawer", (0.058, 0.036, 0.016), (0.003, 0, 0.008), "wood_light", bevel=BV))
parts.append(box("sleeve", (0.047, 0.040, 0.0198), (-0.0055, 0, 0.0099), "wood_dark", bevel=BV))
# etiquette sur le dessus du fourreau : plaque rouge + liseré papier
parts.append(box("label", (0.036, 0.030, 0.0012), (-0.0055, 0, 0.0204), "lacquer_red", bevel=0.0004))
parts.append(box("label_inset", (0.024, 0.018, 0.0012), (-0.0055, 0, 0.0212), "paper", bevel=0.0004))
# frottoir lateral (bande sombre sur le flanc avant)
parts.append(box("striker", (0.040, 0.0012, 0.012), (-0.0055, -0.0205, 0.0099), "lacquer_black", bevel=0.0004))
# allumette posee en travers, legerement en diagonale
stick = box("match_stick", (0.044, 0.0034, 0.0034), (0, 0, 0), "wood_light", bevel=0.0006)
head = sphere("match_head", 0.0033, (0.0225, 0, 0), "lacquer_red", scale=(1.15, 1, 1), seg=8, rings=6)
m = join([stick, head], "match")
m.location = (0.003, 0.002, 0.0215 + 0.0017 + 0.0013)
m.rotation_euler = (0, 0, math.radians(-14))
bpy.ops.object.select_all(action="DESELECT"); m.select_set(True); bpy.context.view_layer.objects.active = m
bpy.ops.object.transform_apply(location=True, rotation=True)
parts.append(m)
obj = join(parts, "match_box")
obj.rotation_euler = (0, 0, math.radians(8))
bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active = obj
bpy.ops.object.transform_apply(rotation=True)
pfinish("match_box", expected_dims=(0.064, 0.044, 0.025), tri_limit=(20, 800), angles={"match_box": math.radians(40)},
        yaw=30, pitch=35, margin=1.0)
