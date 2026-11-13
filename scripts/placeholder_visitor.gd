extends Node3D
## Placeholder de visiteur dans le monde : rectangle de couleur + nom, toujours tourné vers la caméra.
@export var display_name := "Visiteur"
@export var color := Color(0.6, 0.5, 0.7)

func _ready() -> void:
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.8, 1.6)
	quad.mesh = qm
	quad.position.y = 0.8
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = m
	add_child(quad)
	var l := Label3D.new()
	l.text = display_name
	l.font_size = 48
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position.y = 0.8
	l.modulate = Color(0.1, 0.08, 0.12)
	l.outline_size = 0
	l.no_depth_test = true
	add_child(l)
