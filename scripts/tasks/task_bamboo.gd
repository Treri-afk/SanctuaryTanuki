extends MorningTask
## Couper les pousses de bambou de l'étang : de jeunes bambous ont envahi la rive.
## Serpe en main, on vise une pousse, on maintient le clic (le regard se fige) et on tranche d'un geste vif de
## la souris vers la gauche ou la droite. Un geste trop lent ne coupe rien. La tige tombe du côté du geste.

const SLASH_PX := 90.0      # déplacement horizontal de la souris nécessaire...
const SLASH_WINDOW := 0.25  # ...en moins de ce temps (secondes)

var stalks: Array = []      # Dictionary : node, cut, area
var _rng := RandomNumberGenerator.new()
var _hist: Array = []       # [temps, dx]
var _hold_dx := 0.0
var _holding: Variant = null

func hint() -> String:
	return "Bambous : serpe sur l'établi près du bureau, puis les touffes vertes autour de l'étang de la cour (au fond à gauche)."

func clear() -> void:
	for s in stalks:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	stalks.clear()

func begin(_day: int) -> void:
	_rng.randomize()
	var c := Terrain.PREC_POND
	var angles := []
	for k in 5:
		angles.append(0.4 + 0.63 + k * TAU / 5.0)
	angles.append(0.4 + 0.63 + 2.4 * TAU / 5.0)
	for i in angles.size():
		var a: float = angles[i] + _rng.randf_range(-0.12, 0.12)
		var r := _rng.randf_range(6.0, 6.8) if i < 5 else 7.4
		var x := c.x + cos(a) * r
		var z := c.y + sin(a) * r
		var node := ToolModels.bamboo_clump(_rng)
		node.position = Vector3(x, ground_y(x, z, 1.0) - 0.02, z)
		props.add_child(node)
		var s := {"node": node, "cut": false, "area": null}
		var area: Interactable = game._make(node, Vector3(1.2, 2.8, 1.2), Vector3(0, 1.4, 0),
			func() -> String:
				if s["cut"]:
					return ""
				if player.tool != &"sickle":
					return "Des bambous envahissent la rive : il faudrait la serpe (établi du bureau)"
				return "Maintenir le clic et trancher d'un geste vif  ←  →",
			Callable(), _slash.bind(s))
		area.lock_look = true
		area.release_fn = func(_p): _release(s)
		s["area"] = area
		stalks.append(s)
	GameState.set_target(id, stalks.size())

func _slash(pl, _delta: float, motion: Vector2, s: Dictionary) -> void:
	if s["cut"] or pl.tool != &"sickle":
		return
	if not is_same(_holding, s):
		_holding = s
		_hist.clear()
		_hold_dx = 0.0
	pl.action = &"hold"
	var now := Time.get_ticks_msec() * 0.001
	_hist.append([now, motion.x])
	_hold_dx += absf(motion.x)
	while not _hist.is_empty() and now - float(_hist[0][0]) > SLASH_WINDOW:
		_hist.pop_front()
	var sum := 0.0
	for h in _hist:
		sum += float(h[1])
	if absf(sum) >= SLASH_PX:
		_cut(s, signf(sum))

func _release(s: Dictionary) -> void:
	if is_same(_holding, s) and not s["cut"] and _hold_dx > 120.0:
		player.flash_prompt("Trop lent : un geste plus vif !")
	_holding = null
	_hist.clear()

func _cut(s: Dictionary, dir_sign: float) -> void:
	s["cut"] = true
	_holding = null
	game._area_on(s["area"], false)
	var node: Node3D = s["node"]
	# les chaumes basculent du côté du geste, perpendiculairement au regard, l'un après l'autre
	var right: Vector3 = player.camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() * dir_sign
	var axis_world := Vector3.UP.cross(right).normalized()
	var k := 0
	for st in node.get_children():
		if not st.has_node("upper"):
			continue
		var upper: Node3D = st.get_node("upper")
		var axis_local := ((st as Node3D).global_transform.basis.inverse() * axis_world).normalized()
		var start := upper.transform
		var tw := upper.create_tween()
		tw.tween_interval(0.06 * k)
		tw.tween_method(func(t: float):
			var e := t * t
			upper.transform = Transform3D(Basis(axis_local, -e * 1.45) * start.basis, start.origin + Vector3(0, -0.05 * e, 0)), 0.0, 1.0, 0.8)
		tw.tween_interval(1.2)
		tw.tween_property(upper, "scale", Vector3.ONE * 0.01, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(upper.queue_free)
		k += 1
	player.kick(Vector3(0, 0.2 * dir_sign, -0.9 * dir_sign), Vector3(-0.18 * dir_sign, 0, -0.08), 0.05, 0.3)
	Sfx.play(&"slash", node.global_position + Vector3(0, 0.3, 0))
	var was_done := done()
	GameState.add_progress(id)
	if not was_done and done():
		Events.toast.emit("La rive est dégagée. L'étang reflète de nouveau le ciel.")

func autoplay() -> void:
	game._equip(&"sickle")
	for s in stalks:
		if not s["cut"]:
			_cut(s, 1.0)
	game.player_put_back_tool()
