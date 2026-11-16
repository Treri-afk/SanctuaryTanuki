class_name Cat
extends Node3D
## Mochi, le chat (blanc à taches rousses) : modèle animé assets/animals/chat/mochi.glb, fabriqué par
## tools/blender/mochi.py à partir de « Toon Cat FREE » (Omabuarts Studio, CC-BY-4.0).
## Animations : walk, idle, sit, sleep, content. L'avant du chat est +Z (comme les autres créatures : game._face).
##
## Comportement (behave = true, le chat posé dans le monde) : il dort au soleil ; quand on s'approche il se réveille
## et s'assoit en nous regardant ; caressé, il ferme les yeux et tend la tête ; quand on s'éloigne, il se rendort.
## Les scènes (nuit, fête) le pilotent elles-mêmes : walk_to, play.

const MODEL := "res://assets/animals/chat/mochi.glb"
const MODEL_HEIGHT := 370.3     # hauteur du chat debout dans le fichier (tools/blender/mochi.py l'affiche)
const MODEL_GROUND := -13.8     # point le plus bas debout, dans le fichier
const HEIGHT := 0.5             # haut des oreilles, debout, en mètres (grosse tête : style « chibi »)
const STRIDE := 0.28            # distance parcourue par cycle de marche (m), pour que les pattes ne glissent pas
const WALK_CYCLE := 0.833       # durée de la marche dans le fichier (s)
const BLEND := 0.45
const WAKE_DIST := 2.4
const SLEEP_AFTER := 7.0

var behave := false
var anim: AnimationPlayer
var current := ""
var _model: Node3D
var _away := 0.0
var _petting := false

func _ready() -> void:
	var scene := load(MODEL) as PackedScene
	_model = scene.instantiate()
	var k := HEIGHT / MODEL_HEIGHT
	_model.scale = Vector3.ONE * k
	_model.position.y = -MODEL_GROUND * k
	add_child(_model)
	for b in _model.find_children("*", "CollisionObject3D", true, false):
		b.queue_free()
	var mat := Toon.vertex_color_material(0.006)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)
	anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for n in ["walk", "idle", "sit", "sleep", "content"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	play("sleep" if behave else "idle", 0.0)

## Joue une animation en fondu (rien si elle tourne déjà).
func play(n: String, blend := BLEND, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	if n == current and is_equal_approx(anim.speed_scale, speed):
		return
	current = n
	anim.speed_scale = speed
	anim.play(n, blend)

## Marche jusqu'à `to` (sol suivi par `ground`), à `speed` m/s ; pattes calées sur la vitesse.
func walk_to(to: Vector3, speed := 0.45, ground: Callable = Callable()) -> void:
	var from := position
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	if dist < 0.02:
		return
	rotation.y = atan2(to.x - from.x, to.z - from.z)
	play("walk", 0.2, speed / STRIDE * WALK_CYCLE)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var x := lerpf(from.x, to.x, t)
		var z := lerpf(from.z, to.z, t)
		var y := lerpf(from.y, to.y, t)
		if ground.is_valid():
			y = ground.call(x, z)
		position = Vector3(x, y, z), 0.0, 1.0, dist / speed)
	await tw.finished
	play("idle", 0.3)

## Caresse : yeux mi-clos, tête tendue, puis il se rassoit.
func pet() -> void:
	if _petting:
		return
	_petting = true
	play("content", 0.3)
	await get_tree().create_timer(2.6).timeout
	_petting = false
	if current == "content":
		play("sit", 0.5)

func _process(delta: float) -> void:
	if not behave or _petting:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var near := p.global_position.distance_to(global_position) < WAKE_DIST
	if near:
		_away = 0.0
		if current == "sleep":
			play("sit", 0.8)
		# il tourne doucement le corps vers nous quand on est franchement sur le côté
		var want := atan2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
		if absf(angle_difference(rotation.y, want)) > 0.9:
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-1.5 * delta))
	else:
		_away += delta
		if _away > SLEEP_AFTER and current != "sleep":
			play("sleep", 1.2)
