class_name MorningTask
extends Node
## Tâche obligatoire du matin. Chaque matin, le jeu en tire deux au hasard dans la liste de scripts/game.gd
## (TASKS), puis les lanternes et la cloche viennent le soir comme toujours.
##
## Pour ajouter une tâche : créer un script qui étend MorningTask dans scripts/tasks/, l'ajouter à TASKS dans
## scripts/game.gd, et créer data/tasks/<id>.tres (TaskData, required = true) pour son libellé.
##
## Cycle de vie, appelé par game.gd :
##   setup()          une fois au lancement : objets permanents, zones d'interaction
##   clear()          chaque matin, pour toutes les tâches : retirer ce qui reste de la veille
##   begin(day)       chaque matin, seulement si la tâche est tirée : préparer le travail, GameState.set_target(id, n)
##   physics(delta)   à chaque image, seulement si la tâche est active
##   autoplay()       test automatique (--autoplay) : terminer la tâche par les mêmes fonctions que le joueur

var game: Node3D        # scripts/game.gd
var id: StringName
var active := false

func setup() -> void:
	pass

func clear() -> void:
	pass

func begin(_day: int) -> void:
	pass

func physics(_delta: float) -> void:
	pass

func autoplay() -> void:
	pass

## Phrase courte affichée le matin pour dire où et avec quel outil commencer.
func hint() -> String:
	return ""

# ---- raccourcis
var player: CharacterBody3D:
	get:
		return game.player
var props: Node3D:
	get:
		return game.props

func done() -> bool:
	return GameState.is_done(id)

## Hauteur du sol réellement touché (dalles, marches...) en (x, z), par un rayon vers le bas.
func ground_y(x: float, z: float, max_y: float = 3.0) -> float:
	var space := game.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, max_y, z), Vector3(x, -3.0, z), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Terrain.walk_y(x, z)
	return (hit["position"] as Vector3).y
