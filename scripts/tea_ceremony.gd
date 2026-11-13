extends Node
## Préparer et prendre le thé sur la véranda de la salle de thé (activité facultative « the »).
## On s'assoit (la vue reste libre, on ne marche plus), puis trois gestes :
##  1. verser l'eau chaude : clic maintenu, relâcher quand le bol arrive dans la zone dorée ;
##  2. fouetter le matcha : clic maintenu et souris de gauche à droite, vite, jusqu'à ce que la mousse monte ;
##  3. boire : un clic. Puis un moment de contemplation, interface effacée, jusqu'à ce qu'on bouge (ZQSD).

const POUR_TIME := 2.0              # secondes pour remplir le bol de 0 à 1
const POUR_ZONE := Vector2(0.72, 0.88)
const WHISK_PX := 2600.0            # mouvement horizontal cumulé (avec changements de sens) pour une belle mousse
const QUIET_MIN := 4.0              # durée minimale du moment de calme avant de pouvoir se relever

var game: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var tea: Node3D
var active := false
var step := 0
var pour := 0.0
var whisk := 0.0
var _prev_down := false
var _last_dir := 0.0
var _quiet_t := 0.0
var _steam: CPUParticles3D
var _head_y := 1.6
var _dx_acc := 0.0

const LINES := [
	"Le thé est vert et mousseux, un peu amer. Les feuilles tombent, une à une, sans bruit.",
	"Une corneille traverse le ciel. La vapeur monte dans la lumière.",
	"Le bol réchauffe les mains. Il n'y a rien d'autre à faire, pour l'instant.",
]

func setup(g: Node3D, tea_node: Node3D) -> void:
	game = g
	player = g.player
	hud = g.hud
	tea = tea_node
	_head_y = player.head.position.y
	_steam = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	_steam.mesh = q
	_steam.amount = 16
	_steam.lifetime = 2.2
	_steam.direction = Vector3.UP
	_steam.spread = 12.0
	_steam.initial_velocity_min = 0.08
	_steam.initial_velocity_max = 0.18
	_steam.gravity = Vector3(0, 0.05, 0)
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.6
	_steam.emitting = false
	_steam.position = Vector3(0, 0.12, 0)
	tea.add_child(_steam)

func start() -> void:
	if active:
		return
	active = true
	step = 0
	pour = 0.0
	whisk = 0.0
	_prev_down = true
	player.move_locked = true
	player.gesture_lock = true
	game.player_put_back_tool()
	# s'asseoir au bord de la véranda, face au plateau
	var fwd_to_tray := tea.global_position - player.global_position
	fwd_to_tray.y = 0.0
	var seat := tea.global_position - fwd_to_tray.normalized() * 0.75
	seat.y = player.global_position.y
	var yaw := atan2(-fwd_to_tray.x, -fwd_to_tray.z)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position", seat, 0.7)
	tw.tween_property(player, "rotation:y", player.rotation.y + wrapf(yaw - player.rotation.y, -PI, PI), 0.7)
	tw.tween_property(player.head, "rotation:x", deg_to_rad(-28.0), 0.7)
	tw.tween_property(player.head, "position:y", _head_y - 0.55, 0.7)
	_steam.emitting = true
	Sfx.play(&"tea", tea.global_position, -4.0)
	_show()

func _show() -> void:
	match step:
		0:
			hud.set_banner("Versez l'eau chaude dans le bol\nmaintenez le clic, relâchez dans la zone dorée")
			hud.set_gauge("Bol", pour, POUR_ZONE)
		1:
			hud.set_banner("Fouettez le matcha\nclic maintenu, souris vite de gauche à droite")
			hud.set_gauge("Mousse", whisk)
		2:
			hud.set_banner("Buvez lentement  (clic)")
			hud.set_gauge("", -1.0)

func _physics_process(delta: float) -> void:
	if not active:
		return
	var down: bool = player.lmb_down()
	var pressed := down and not _prev_down
	var released := not down and _prev_down
	_prev_down = down
	match step:
		0:
			if down:
				pour = minf(pour + delta / POUR_TIME, 1.0)
				player.action = &"pour"
				Sfx.loop(&"pour_loop", true)
				hud.set_gauge("Bol", pour, POUR_ZONE)
			if released or pour >= 1.0:
				Sfx.loop(&"pour_loop", false)
				if pour >= POUR_ZONE.x and pour <= POUR_ZONE.y:
					player.flash_prompt("Parfait.")
					hud.pulse()
				elif pour < POUR_ZONE.x:
					player.flash_prompt("Encore un peu d'eau...")
					return
				else:
					player.flash_prompt("Un peu trop d'eau, tant pis.")
				step = 1
				_show()
		1:
			var dx := _dx_acc
			_dx_acc = 0.0
			if down:
				var dir := signf(dx)
				var gain := absf(dx)
				if dir != 0.0 and dir != _last_dir:
					gain *= 1.6   # les allers-retours fouettent mieux qu'un long glissé
					_last_dir = dir
				whisk = minf(whisk + gain / WHISK_PX, 1.0)
				player.action = &"snip"
				hud.set_gauge("Mousse", whisk)
				if whisk >= 1.0:
					hud.pulse()
					player.flash_prompt("Une mousse fine et légère.")
					step = 2
					_show()
		2:
			if pressed:
				step = 3
				_drink()
		3:
			_quiet_t += delta
			var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.2
			if _quiet_t > QUIET_MIN and moving:
				_stand_up()

func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion:
		_dx_acc += (event as InputEventMouseMotion).relative.x

func _drink() -> void:
	player.gesture_lock = false
	hud.set_banner("")
	hud.set_gauge("", -1.0)
	player.kick(Vector3(0.3, 0, 0), Vector3(0, 0.08, 0.05), 0.4, 0.8)
	Sfx.play(&"tea", tea.global_position, -6.0)
	_quiet_t = 0.0
	await get_tree().create_timer(1.0).timeout
	hud.set_quiet(true)
	Events.toast.emit(LINES[randi() % LINES.size()])
	await get_tree().create_timer(QUIET_MIN).timeout
	if active and step == 3:
		player.flash_prompt("ZQSD pour vous relever", 30.0)

func _stand_up() -> void:
	active = false
	step = 0
	player.flash_prompt("", 0.0)
	hud.set_quiet(false)
	_steam.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player.head, "position:y", _head_y, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player.head, "rotation:x", 0.0, 0.5)
	await tw.finished
	player.move_locked = false
	if GameState.add_progress_once(&"the"):
		Events.toast.emit("Un moment de calme. Le sanctuaire semble plus lumineux.")

## Test automatique : passe les étapes.
func autoplay() -> void:
	start()
	await get_tree().create_timer(0.8).timeout
	pour = 0.8
	step = 1
	whisk = 1.0
	step = 3
	_quiet_t = QUIET_MIN + 1.0
	_stand_up()
