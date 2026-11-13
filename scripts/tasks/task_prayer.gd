extends MorningTask
## Prière du matin devant le pavillon, selon le rite « ni-rei, ni-hakushu, ichi-rei » :
## jeter une pièce dans le tronc (clic), saluer deux fois (baisser franchement le regard puis le relever),
## frapper deux fois dans les mains (clic), saluer une dernière fois. On ne bouge pas pendant le rite.

const STEPS := [&"coin", &"bow", &"bow", &"clap", &"clap", &"bow"]
const STEP_TEXT := {
	&"coin": "Jetez une pièce dans le tronc  (clic)",
	&"bow": "Inclinez-vous profondément  (baissez le regard, puis relevez-le)",
	&"clap": "Frappez dans vos mains  (clic)",
}
const BOW_DOWN := -0.75     # radians : regard baissé d'environ 43°
const BOW_UP := -0.28

var spot: Node3D
var area: Interactable
var praying := false
var step := 0
var _bowing := false
var _prev_down := false
var box: Node3D

func setup() -> void:
	box = props.get_node("OfferingBox")
	spot = Node3D.new()
	spot.name = "PrayerSpot"
	spot.position = box.position + Vector3(0, 0, 1.1)
	props.add_child(spot)
	area = game._make(spot, Vector3(1.8, 2.0, 0.5), Vector3(0, 1.0, 0),
		func() -> String:
			if not active or done() or praying or GameState.phase != GameState.Phase.MORNING:
				return ""
			return "E : Commencer la prière du matin",
		func(_p): _start())
	game._area_on(area, false)

func hint() -> String:
	return "Prière : devant le tronc à offrandes, au fond de l'allée."

func clear() -> void:
	praying = false
	game._area_on(area, false)

func begin(_day: int) -> void:
	step = 0
	game._area_on(area, true)
	GameState.set_target(id, STEPS.size())

func _start() -> void:
	if praying or done():
		return
	praying = true
	step = 0
	_bowing = false
	_prev_down = true   # le clic qui a lancé la prière ne compte pas
	game.hud.show_coins(true)
	player.move_locked = true
	# on se place face au tronc
	var tw := game.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var stand := Vector3(box.position.x, player.global_position.y, box.position.z + 2.2)
	tw.tween_property(player, "global_position", stand, 0.6)
	tw.tween_property(player, "rotation:y", _shortest(player.rotation.y, 0.0), 0.6)
	tw.tween_property(player.head, "rotation:x", 0.0, 0.6)
	_show()

func _shortest(from: float, to: float) -> float:
	return from + wrapf(to - from, -PI, PI)

func _show() -> void:
	if not praying:
		game.hud.set_banner("")
		return
	var lines := PackedStringArray()
	lines.append("二礼二拍手一礼   —   deux saluts, deux frappes, un salut")
	lines.append(STEP_TEXT[STEPS[step]])
	var dots := ""
	for i in STEPS.size():
		dots += ("●" if i < step else ("◉" if i == step else "○")) + " "
	lines.append(dots)
	game.hud.set_banner("\n".join(lines))

func physics(_delta: float) -> void:
	if not praying:
		return
	var s: StringName = STEPS[step]
	var down: bool = player.lmb_down()
	var click := down and not _prev_down
	_prev_down = down
	var pitch: float = player.head.rotation.x
	if s == &"bow":
		if not _bowing and pitch < BOW_DOWN:
			_bowing = true
			game.hud.pulse()
		elif _bowing and pitch > BOW_UP:
			_bowing = false
			_advance()
		elif click:
			player.flash_prompt("Inclinez-vous d'abord : baissez le regard vers le sol")
	elif click:
		if s == &"coin":
			if GameState.spend_coins(1):
				_throw_coin()
			else:
				player.flash_prompt("Plus aucune pièce : un salut sincère suffira.")
		else:
			Sfx.play(&"clap", null, -2.0)
			game.hud.pulse()
			player.kick(Vector3(0, 0, 0), Vector3(0, -0.03, -0.05), 0.04, 0.18)
		_advance()

func _advance() -> void:
	step += 1
	GameState.add_progress(id)
	if step >= STEPS.size():
		praying = false
		player.move_locked = false
		game.hud.show_coins(false)
		game._area_on(area, false)
		game.hud.set_banner("")
		Sfx.play(&"task_done")
		Events.toast.emit("Votre prière monte avec la brume du matin.")
		return
	_show()

func _throw_coin() -> void:
	var c := ToolModels.coin()
	props.add_child(c)
	var from: Vector3 = player.camera.global_position + (-player.camera.global_transform.basis.z) * 0.4 + Vector3(0, -0.15, 0)
	var to := box.global_position + Vector3(0, 0.95, 0.05)
	c.global_position = from
	var tw := c.create_tween()
	tw.tween_method(func(t: float):
		c.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.6, 0)
		c.rotation.x = t * 14.0, 0.0, 1.0, 0.55)
	tw.tween_callback(func():
		Sfx.play(&"coin", to)
		c.queue_free())

func autoplay() -> void:
	_start()
	while step < STEPS.size():
		await game.get_tree().process_frame
		_advance()
