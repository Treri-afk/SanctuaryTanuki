extends MorningTask
## Ramasser les feuilles mortes : on ne vise plus des taches une par une.
## Balai en main, clic maintenu en avançant : les feuilles du sol s'envolent vers un tas qui grossit devant le
## balai. On pousse ce tas jusqu'à un panier, où il se vide tout seul. Un tas abandonné au sol peut être
## dispersé par une bourrasque : on a intérêt à finir ce qu'on commence.

const LEAF_SHADER := preload("res://shaders/leaf.gdshader")
const PER_PATCH := 15
const GROUND := 0
const FLYING := 1
const IN_PILE := 2
const IN_BASKET := 3
const SCATTER := 4

var centers: Array[Vector3] = []
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var flakes: Array = []      # Dictionary : pos, state, seed, t, from, pile, to
var piles: Array = []       # Dictionary : node, model, pos, n
var pushed: Variant = null  # tas poussé par le balai
var baskets: Array[Node3D] = []
var total := 0
var gust_timer := 45.0
var _rng := RandomNumberGenerator.new()
var _told_gust := false

func setup() -> void:
	var lp: Node3D = game.world.get_node_or_null("LeafPatches")
	if lp:
		for c in lp.get_children():
			centers.append((c as Node3D).position)
		lp.visible = false
		lp.process_mode = Node.PROCESS_MODE_DISABLED
	for n in ["Basket", "Basket2", "Basket3"]:
		if props.has_node(n):
			baskets.append(props.get_node(n))
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.24)
	var m := ShaderMaterial.new()
	m.shader = LEAF_SHADER
	q.material = m
	mm.mesh = q
	mm.instance_count = centers.size() * PER_PATCH
	mmi = MultiMeshInstance3D.new()
	mmi.name = "SweepLeaves"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = false
	props.add_child(mmi)

func hint() -> String:
	return "Feuilles : balai près de l'entrée, puis clic maintenu en marchant pour pousser un tas jusqu'à un panier."

func clear() -> void:
	for p in piles:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	piles.clear()
	pushed = null
	flakes.clear()
	mmi.visible = false

func begin(_day: int) -> void:
	_rng.randomize()
	for c in centers:
		for k in PER_PATCH:
			for attempt in 6:
				var a := _rng.randf() * TAU
				var r := sqrt(_rng.randf()) * 1.15
				var x := c.x + cos(a) * r
				var z := c.z + sin(a) * r
				var y := ground_y(x, z, 1.4)
				if y > 0.3:
					continue   # dans une haie, un muret...
				flakes.append({"pos": Vector3(x, y + 0.012, z), "state": GROUND, "seed": _rng.randf(),
					"t": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "pile": null})
				break
	total = flakes.size()
	mm.visible_instance_count = total
	mmi.visible = true
	gust_timer = _rng.randf_range(40.0, 55.0)
	GameState.set_target(id, int(ceil(total * 0.9)))

# ---------------------------------------------------------------- tas
func _new_pile(pos: Vector3) -> Dictionary:
	var node := Node3D.new()
	node.position = pos
	props.add_child(node)
	var model: Node3D = game._model("leaf_pile", Color("#D9822B"))
	model.scale = Vector3.ONE * 0.01
	model.rotation.y = _rng.randf() * TAU
	node.add_child(model)
	var p := {"node": node, "model": model, "pos": pos, "n": 0, "pop": 0.0}
	piles.append(p)
	return p

func _pile_radius(p: Dictionary) -> float:
	return 0.55 + 0.32 * sqrt(float(p["n"]) / 40.0)

func _update_pile_visual(p: Dictionary, delta: float) -> void:
	var n := float(p["n"])
	var s := 0.0 if n <= 0.0 else clampf(0.28 + 0.75 * sqrt(n / 45.0), 0.28, 1.35)
	p["pop"] = maxf(float(p["pop"]) - delta * 4.0, 0.0)
	var target := s * (1.0 + 0.12 * sin(float(p["pop"]) * PI))
	var model: Node3D = p["model"]
	var cur := model.scale.x
	model.scale = Vector3.ONE * lerpf(cur, target, 1.0 - exp(-14.0 * delta))
	(p["node"] as Node3D).position = p["pos"]

# ---------------------------------------------------------------- boucle
func physics(delta: float) -> void:
	var sweeping: bool = player.tool == &"broom" and player.lmb_free()
	if sweeping:
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var sp: Vector3 = player.global_position + fwd * 1.15
		sp.y = ground_y(sp.x, sp.z, player.global_position.y + 0.6)
		if pushed == null:
			pushed = _new_pile(sp)
		var pp: Dictionary = pushed
		pp["pos"] = (pp["pos"] as Vector3).lerp(sp, 1.0 - exp(-12.0 * delta))
		player.action = &"sweep"
		var r := _pile_radius(pp)
		var cpos: Vector3 = pp["pos"]
		var grabbed := 0
		for f in flakes:
			if f["state"] == GROUND:
				var fp: Vector3 = f["pos"]
				if Vector2(fp.x - cpos.x, fp.z - cpos.z).length() < r:
					f["state"] = FLYING
					f["t"] = 0.0
					f["from"] = fp
					f["pile"] = pp
					grabbed += 1
		if grabbed > 0:
			Sfx.play(&"leaves", cpos, -8.0)
		# un tas laissé au sol rejoint celui qu'on pousse
		for other in piles.duplicate():
			if is_same(other, pp) or int(other["n"]) <= 0:
				continue
			var op: Vector3 = other["pos"]
			if Vector2(op.x - cpos.x, op.z - cpos.z).length() < r + 0.35:
				pp["n"] = int(pp["n"]) + int(other["n"])
				pp["pop"] = 1.0
				for f in flakes:
					if is_same(f["pile"], other):
						f["pile"] = pp
				_free_pile(other)
		# panier
		if int(pp["n"]) > 0:
			for b in baskets:
				if Vector2(b.global_position.x - cpos.x, b.global_position.z - cpos.z).length() < 1.35:
					_dump(pp, b)
					break
	elif pushed != null:
		var p0: Dictionary = pushed
		pushed = null
		if int(p0["n"]) <= 0 and not _has_incoming(p0):
			_free_pile(p0)
	_update_flakes(delta)
	for p in piles:
		_update_pile_visual(p, delta)
	_gusts(delta)

func _has_incoming(p: Dictionary) -> bool:
	for f in flakes:
		if f["state"] == FLYING and is_same(f["pile"], p):
			return true
	return false

func _free_pile(p: Dictionary) -> void:
	piles.erase(p)
	if is_instance_valid(p["node"]):
		p["node"].queue_free()

func _dump(p: Dictionary, basket: Node3D) -> void:
	var n := int(p["n"])
	for f in flakes:
		if is_same(f["pile"], p) and f["state"] == IN_PILE:
			f["state"] = IN_BASKET
	piles.erase(p)
	pushed = null
	var node: Node3D = p["node"]
	var tw := node.create_tween().set_parallel(true)
	var top := basket.global_position + Vector3(0, 0.55, 0)
	tw.tween_property(node, "position", top, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3.ONE * 0.05, 0.32).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(node.queue_free)
	var bt := basket.create_tween()
	bt.tween_property(basket, "scale", Vector3(1.12, 0.9, 1.12), 0.1).set_delay(0.25)
	bt.tween_property(basket, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play(&"leaves", top, -2.0)
	player.kick(Vector3(0.25, 0, 0), Vector3(0, 0.04, -0.06))
	var was_done := done()
	GameState.add_progress(id, n)
	if not was_done and done():
		Events.toast.emit("La cour est propre. On entend à nouveau le gravier sous les pas.")

func _update_flakes(delta: float) -> void:
	var i := 0
	for f in flakes:
		var st: int = f["state"]
		var xf := Transform3D()
		var custom := Color(f["seed"], 0.0, 0.0, 1.0)
		if st == GROUND:
			xf = Transform3D(Basis.IDENTITY, f["pos"])
		elif st == FLYING:
			var p: Dictionary = f["pile"]
			f["t"] = float(f["t"]) + delta * 3.2
			var t: float = minf(f["t"], 1.0)
			var to: Vector3 = (p["pos"] as Vector3) + Vector3(0, 0.22, 0)
			var pos: Vector3 = (f["from"] as Vector3).lerp(to, t) + Vector3(0, sin(t * PI) * 0.45, 0)
			xf = Transform3D(Basis.IDENTITY, pos)
			custom.a = 0.0
			if t >= 1.0:
				f["state"] = IN_PILE
				p["n"] = int(p["n"]) + 1
				p["pop"] = 1.0
		elif st == SCATTER:
			f["t"] = float(f["t"]) + delta * 0.9
			var t2: float = minf(f["t"], 1.0)
			var e := 1.0 - pow(1.0 - t2, 2.0)
			var pos2: Vector3 = (f["from"] as Vector3).lerp(f["to"], e) + Vector3(0, sin(t2 * PI) * 1.1, 0)
			xf = Transform3D(Basis.IDENTITY, pos2)
			custom.a = 0.0
			if t2 >= 1.0:
				f["state"] = GROUND
				f["pos"] = f["to"]
		else:
			xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, -50, 0))
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, custom)
		i += 1

## Bourrasque : un tas abandonné au sol perd une partie de ses feuilles.
func _gusts(delta: float) -> void:
	gust_timer -= delta
	if gust_timer > 0.0:
		return
	gust_timer = _rng.randf_range(35.0, 55.0)
	var scattered := false
	for p in piles.duplicate():
		if is_same(p, pushed) or int(p["n"]) < 4:
			continue
		var k := int(ceil(int(p["n"]) * 0.5))
		var center: Vector3 = p["pos"]
		var wind: Variant = RenderingServer.global_shader_parameter_get("wind_direction")
		var wd := Vector3(1, 0, 0.3)
		if wind is Vector2:
			wd = Vector3((wind as Vector2).x, 0.0, (wind as Vector2).y).normalized()
		for f in flakes:
			if k <= 0:
				break
			if is_same(f["pile"], p) and f["state"] == IN_PILE:
				var a := _rng.randf() * TAU
				var r := _rng.randf_range(0.8, 2.6)
				var to := center + wd * _rng.randf_range(1.0, 2.5) + Vector3(cos(a) * r, 0.0, sin(a) * r)
				to.y = ground_y(to.x, to.z, center.y + 0.8) + 0.012
				if to.y > center.y + 0.5:
					to = center + Vector3(cos(a), 0, sin(a)) * 0.6
				f["state"] = SCATTER
				f["from"] = center + Vector3(0, 0.2, 0)
				f["to"] = to
				f["t"] = 0.0
				f["pile"] = null
				k -= 1
				p["n"] = int(p["n"]) - 1
		scattered = true
	if scattered:
		game.get_tree().call_group("atmosphere", "gust", 0.8)
		Sfx.play(&"leaves", null, -4.0)
		if not _told_gust:
			_told_gust = true
			Events.toast.emit("Une bourrasque disperse le tas laissé au sol. Mieux vaut le pousser jusqu'au panier.")

func autoplay() -> void:
	if baskets.is_empty():
		return
	var b := baskets[0]
	var p := _new_pile(b.global_position)
	for f in flakes:
		if f["state"] == GROUND:
			f["state"] = IN_PILE
			f["pile"] = p
			p["n"] = int(p["n"]) + 1
	_dump(p, b)
