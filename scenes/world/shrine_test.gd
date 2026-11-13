extends Node3D
## Scène de test : applique le rendu toon aux modèles importés, sans toucher au joueur ni aux placeholders.

func _ready() -> void:
	for n in get_children():
		if n.name in ["Player", "WorldEnvironment", "Sun", "Ground"]:
			continue
		if n.has_method("set") and n.get_script() != null:
			continue   # placeholders de visiteurs
		Toon.apply(n)
