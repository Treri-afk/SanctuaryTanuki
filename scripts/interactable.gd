class_name Interactable
extends Area3D
## Zone visée par le rayon du joueur. Comportement fourni par des Callables (voir game.gd et scripts/tasks/).
## prompt_fn  : () -> String                      texte d'invite ; "" = rien à proposer pour l'instant
## use_fn     : (player) -> void                  appelé par E ou un clic
## hold_fn    : (player, delta, souris: Vector2)  appelé à chaque image tant que le clic est maintenu
## release_fn : (player) -> void                  appelé quand le clic maintenu se termine
## lock_look  : pendant le clic maintenu, la souris ne tourne plus la vue (elle sert au geste : tirer, trancher)

var prompt_fn: Callable
var use_fn: Callable
var hold_fn: Callable
var release_fn: Callable
var lock_look := false

static func create(parent: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO, node_name: String = "Interactable") -> Interactable:
	var a := Interactable.new()
	a.name = node_name
	a.collision_layer = 2
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = offset
	a.add_child(cs)
	parent.add_child(a)
	return a

func prompt() -> String:
	if prompt_fn.is_valid():
		return prompt_fn.call()
	return ""
