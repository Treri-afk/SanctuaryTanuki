extends Control
## Placeholder de portrait visual novel : rectangle de couleur + nom. Remplacé par les illustrations de l'utilisateur.
@export var display_name := "Visiteur":
	set(v):
		display_name = v
		if is_node_ready(): $Name.text = v
@export var color := Color(0.6, 0.5, 0.7):
	set(v):
		color = v
		if is_node_ready(): $Fill.color = v

func _ready() -> void:
	$Name.text = display_name
	$Fill.color = color
