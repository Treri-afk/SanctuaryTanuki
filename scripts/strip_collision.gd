extends Node3D
## Supprime les collisions importées des enfants (les marches de l'escalier sont franchies par une rampe invisible).
func _ready() -> void:
	for b in find_children("*", "CollisionObject3D", true, false):
		b.queue_free()
