extends CharacterBody3D
## Joueur à la première personne : ZQSD (AZERTY) / WASD + souris, interaction par rayon, outil en main.
## E ou clic gauche : interagir. Clic maintenu : geste de l'outil (balayer, tirer, verser, tailler, trancher).
## R : reposer l'outil. Espace (saut) et F (vol libre) : outils de test uniquement.

signal tool_changed

@export var walk_speed := 4.0
@export var mouse_sensitivity := 0.0022
@export var jump_speed := 5.0
const GRAVITY := 18.0
const REACH := 2.8
const LOCK_START_DELAY := 0.6   # un geste qui fige le regard ne démarre que juste après l'appui

var input_enabled := true
var move_locked := false        # rite : on peut regarder mais pas marcher
var look_locked := false        # geste en cours : la souris sert au geste, pas au regard
var gesture_lock := false       # idem, mais tenu par une activité (thé...) et non par un clic maintenu
var noclip := false
var tool: StringName = &""
var bucket_level := 0.0         # eau dans le seau, de 0 à 1
var bucket_full: bool:
	get:
		return bucket_level > 0.02
var carry: StringName = &""
var target: Interactable = null
var hold_target: Interactable = null
var prompt_text := ""
var mouse_delta := Vector2.ZERO
var action: StringName = &""    # pose de l'outil pour cette image (sweep, pour, pull, snip, hold), remise à zéro à chaque image
var spilling := false

var _press_time := -10.0
var _flash_text := ""
var _flash_t := 0.0
var _hand_time := 0.0
var _kick_rot := Vector3.ZERO
var _kick_pos := Vector3.ZERO
var _kick_tw: Tween
var _pose_rot := Vector3.ZERO
var _pose_pos := Vector3.ZERO
var _look_rate := Vector2.ZERO
var _prev_hvel := Vector2.ZERO
var _slosh := 0.0
var _slosh_v := 0.0
var _water: MeshInstance3D
var _drops: CPUParticles3D
var _water_base := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/Ray
@onready var hand: Node3D = $Head/Camera3D/Hand

func _ready() -> void:
	add_to_group("player")
	ray.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and input_enabled:
		mouse_delta += event.relative
		if not look_locked and not gesture_lock:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif not input_enabled:
			return
		elif event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_F:
			noclip = not noclip
			$CollisionShape3D.disabled = noclip
			velocity = Vector3.ZERO
		elif event.keycode == KEY_R:
			get_tree().call_group("game", "player_put_back_tool")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif input_enabled:
			_press_time = Time.get_ticks_msec() * 0.001
			_interact()

func _interact() -> void:
	if target != null and target.use_fn.is_valid() and target.prompt() != "":
		target.use_fn.call(self)

## Clic gauche maintenu (jeu actif, souris capturée).
func lmb_down() -> bool:
	return input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

## Clic maintenu qui ne vise aucune zone à geste : sert aux gestes libres (pousser les feuilles au balai).
func lmb_free() -> bool:
	return lmb_down() and hold_target == null

## Message bref à la place de l'invite (« Parfait ! », « Trop lent »...).
func flash_prompt(text: String, duration := 1.4) -> void:
	_flash_text = text
	_flash_t = duration

func _physics_process(delta: float) -> void:
	if not noclip and global_position.y < Terrain.walk_y(global_position.x, global_position.z) - 2.5:
		global_position.y = Terrain.walk_y(global_position.x, global_position.z) + 0.2   # filet de sécurité : jamais sous le sol
		velocity = Vector3.ZERO
	_look_rate = Vector2.ZERO if look_locked else mouse_delta * mouse_sensitivity / maxf(delta, 0.0001)
	_update_target()
	_update_hold(delta)
	var speed := walk_speed * (0.93 if bucket_full else 1.0)
	var dir := Vector2.ZERO
	if input_enabled and not move_locked:
		dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if noclip and input_enabled:
		var v := (camera.global_transform.basis * Vector3(dir.x, 0, dir.y)) * speed * 2.0
		v.y += (Input.get_action_strength("jump") - Input.get_action_strength("descend")) * speed * 2.0
		global_position += v * delta
		mouse_delta = Vector2.ZERO
		action = &""
		return
	var wish := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
	velocity.x = move_toward(velocity.x, wish.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, wish.z * speed, 22.0 * delta)
	var jumped := false
	if is_on_floor():
		jumped = input_enabled and not move_locked and Input.is_action_just_pressed("jump")
		velocity.y = jump_speed if jumped else 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var hv := Vector2(velocity.x, velocity.z)
	var accel := (hv - _prev_hvel).length() / maxf(delta, 0.0001)
	_prev_hvel = hv
	_update_bucket(delta, accel, jumped)
	_animate_hand(delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		prompt_text = _flash_text
	action = &""
	mouse_delta = Vector2.ZERO

func _update_target() -> void:
	ray.force_raycast_update()
	var c := ray.get_collider()
	target = c as Interactable if c is Interactable else null
	prompt_text = target.prompt() if target != null else ""

func _update_hold(delta: float) -> void:
	if not lmb_down():
		_release_hold()
		return
	if hold_target != null and is_instance_valid(hold_target) and hold_target.lock_look:
		pass   # geste en cours : on garde la même cible même si le rayon bouge
	else:
		var nt: Interactable = null
		if target != null and target.hold_fn.is_valid() and target.prompt() != "":
			nt = target
			if nt.lock_look and Time.get_ticks_msec() * 0.001 - _press_time > LOCK_START_DELAY:
				nt = null
		if nt != hold_target:
			_release_hold()
			hold_target = nt
	if hold_target == null:
		return
	if not is_instance_valid(hold_target):
		hold_target = null
		look_locked = false
		return
	look_locked = hold_target.lock_look
	hold_target.hold_fn.call(self, delta, mouse_delta)

func _release_hold() -> void:
	if hold_target != null and is_instance_valid(hold_target) and hold_target.release_fn.is_valid():
		hold_target.release_fn.call(self)
	hold_target = null
	look_locked = false

# ---- seau : l'eau déborde dans les virages vifs, les sauts et les chocs
func set_bucket_level(v: float) -> void:
	bucket_level = clampf(v, 0.0, 1.0)

func _update_bucket(delta: float, accel: float, jumped: bool) -> void:
	if tool != &"bucket":
		spilling = false
		return
	var spill := 0.0
	if bucket_level > 0.0:
		spill += maxf(0.0, absf(_look_rate.x) - 3.2) * 0.07 * delta
		spill += maxf(0.0, absf(_look_rate.y) - 3.2) * 0.05 * delta
		spill += maxf(0.0, accel - 30.0) * 0.0035 * delta
		if jumped:
			spill += 0.18
	spilling = spill > 0.0008 and bucket_level > 0.01
	bucket_level = maxf(0.0, bucket_level - spill)
	# ballottement de la surface : ressort amorti excité par la rotation et les changements de vitesse
	var force := clampf(-_look_rate.x * 0.02, -0.6, 0.6) + clampf(accel * 0.004, 0.0, 0.3) * signf(_slosh_v + 0.0001)
	_slosh_v += (force - _slosh * 18.0 - _slosh_v * 3.5) * delta * 6.0
	_slosh = clampf(_slosh + _slosh_v * delta, -0.35, 0.35)
	if _water:
		_water.visible = bucket_level > 0.01
		_water.position = _water_base + Vector3(0, lerpf(-0.14, 0.0, bucket_level), 0)
		_water.rotation = Vector3(_slosh * 0.4, 0, _slosh)
	if _drops:
		_drops.emitting = spilling

# ---- animation de la main : balancement de marche + pose du geste + à-coups (kick)
func _animate_hand(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	_hand_time += delta * (7.5 if moving else 1.6)
	var bob := Vector3(cos(_hand_time * 0.5) * (0.01 if moving else 0.0), sin(_hand_time) * (0.012 if moving else 0.004), 0.0)
	var pr := Vector3.ZERO
	var pp := Vector3.ZERO
	var t := Time.get_ticks_msec() * 0.001
	match action:
		&"sweep":
			pr = Vector3(0.18, 0.0, sin(t * 8.5) * 0.32)
			pp = Vector3(sin(t * 8.5) * 0.13, 0.03, -0.06)
		&"pour":
			pr = Vector3(0.1, 0.0, 0.95)
			pp = Vector3(-0.16, 0.16, -0.12)
		&"pull":
			pr = Vector3(-0.15, 0.0, 0.0)
			pp = Vector3(0.0, -0.08 + sin(t * 7.0) * 0.025, 0.04)
		&"snip":
			pr = Vector3(0.12, 0.0, sin(t * 16.0) * 0.1)
			pp = Vector3(0.0, 0.03, -0.05)
		&"hold":
			pr = Vector3(0.3, 0.0, 0.25)
			pp = Vector3(0.06, 0.06, -0.04)
	var k := 1.0 - exp(-12.0 * delta)
	_pose_rot = _pose_rot.lerp(pr, k)
	_pose_pos = _pose_pos.lerp(pp, k)
	hand.position = bob + _pose_pos + _kick_pos
	hand.rotation = _pose_rot + _kick_rot

## À-coup de la main (frappe, coupe, prise) : aller rapide puis retour amorti.
func kick(rot: Vector3, pos := Vector3.ZERO, t_in := 0.06, t_out := 0.28) -> void:
	if _kick_tw:
		_kick_tw.kill()
	_kick_tw = create_tween()
	_kick_tw.tween_method(_set_kick.bind(rot, pos), 0.0, 1.0, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tw.tween_method(_set_kick.bind(rot, pos), 1.0, 0.0, t_out).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_kick(v: float, rot: Vector3, pos: Vector3) -> void:
	_kick_rot = rot * v
	_kick_pos = pos * v

# ---- outil en main (vue subjective)
const HAND_POSES := {
	&"broom": [Vector3(0.38, -0.95, -0.85), Vector3(-18, 0, -10)],
	&"bucket": [Vector3(0.34, -0.55, -0.7), Vector3(0, 0, 0)],
	&"match": [Vector3(0.28, -0.32, -0.55), Vector3(-25, 20, 0)],
	&"rake": [Vector3(0.38, -0.95, -0.85), Vector3(-18, 0, -10)],
	&"hammer": [Vector3(0.3, -0.36, -0.45), Vector3(-50, 0, -10)],
	&"shears": [Vector3(0.12, -0.42, -0.42), Vector3(-68, 0, 0)],
	&"sickle": [Vector3(0.3, -0.36, -0.45), Vector3(-45, 15, -12)],
	&"leaf_pile": [Vector3(-0.28, -0.45, -0.75), Vector3(-10, 0, 0)],
}
const HAND_MODELS := {&"match": "match_box"}

func _clear_hand() -> void:
	for c in hand.get_children():
		c.queue_free()
	_water = null
	_drops = null

func equip(tool_name: StringName) -> void:
	tool = tool_name
	bucket_level = 0.0
	_rebuild_hand()
	kick(Vector3(0.35, 0, 0), Vector3(0, -0.15, 0.05), 0.01, 0.35)
	Sfx.play(&"pickup")
	tool_changed.emit()

func unequip() -> void:
	if tool != &"":
		Sfx.play(&"putdown")
	tool = &""
	bucket_level = 0.0
	_rebuild_hand()
	tool_changed.emit()

func set_carry(c: StringName) -> void:
	carry = c
	_rebuild_hand()
	tool_changed.emit()

func _rebuild_hand() -> void:
	_clear_hand()
	if tool != &"":
		var m: String = HAND_MODELS.get(tool, String(tool))
		_add_hand_model(m, HAND_POSES.get(tool, [Vector3(0.3, -0.4, -0.5), Vector3.ZERO]))
		if tool == &"bucket":
			_water_base = HAND_POSES[tool][0] + Vector3(0, 0.235, 0)
			_water = MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.125
			cm.bottom_radius = 0.125
			cm.height = 0.01
			cm.radial_segments = 20
			_water.mesh = cm
			_water.material_override = Toon.water_material()
			_water.position = _water_base
			_water.visible = false
			hand.add_child(_water)
			_drops = CPUParticles3D.new()
			var q := SphereMesh.new()
			q.radius = 0.012
			q.height = 0.024
			q.radial_segments = 6
			q.rings = 3
			var dm := StandardMaterial3D.new()
			dm.albedo_color = Color(0.62, 0.8, 0.9)
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			q.material = dm
			_drops.mesh = q
			_drops.amount = 40
			_drops.lifetime = 0.7
			_drops.emitting = false
			_drops.local_coords = false
			_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			_drops.emission_ring_axis = Vector3.UP
			_drops.emission_ring_radius = 0.14
			_drops.emission_ring_inner_radius = 0.12
			_drops.emission_ring_height = 0.0
			_drops.direction = Vector3.UP
			_drops.spread = 60.0
			_drops.initial_velocity_min = 0.6
			_drops.initial_velocity_max = 1.4
			_drops.gravity = Vector3(0, -9.8, 0)
			_drops.position = _water_base
			hand.add_child(_drops)
	if carry != &"":
		_add_hand_model("leaf_pile", HAND_POSES[&"leaf_pile"])

func _add_hand_model(model: String, pose: Array) -> void:
	var n: Node3D = null
	var path := "res://assets/models/%s.glb" % model
	if ResourceLoader.exists(path):
		n = (load(path) as PackedScene).instantiate()
		Toon.apply(n)
	else:
		n = ToolModels.make(model)
	if n == null:
		return
	n.position = pose[0]
	n.rotation_degrees = pose[1]
	hand.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# les collisions importées ne doivent pas suivre la main
	for b in n.find_children("*", "CollisionObject3D", true, false):
		b.queue_free()
