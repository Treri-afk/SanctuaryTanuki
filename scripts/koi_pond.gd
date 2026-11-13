extends Node
## Les carpes koï de l'étang de la cour.
## - Elles nagent tranquillement, se croisent, remontent parfois respirer.
## - On les nourrit depuis la rive : E en visant l'eau lance une poignée de granulés ; elles accourent et gobent.
##   Elles ont faim d'environ 12 granulés par jour (activité facultative « Nourrir les carpes »).
## - Bien nourries, elles grandissent ; nourries deux jours de suite, une petite carpe naît (8 au plus).
## - Visée sur une carpe : E pour lui donner un nom ; son nom et son âge s'affichent ensuite.
## L'état des carpes (robe, taille, nom) est gardé dans GameState.koi.

const CENTER := Vector2(-15.0, -27.0)
const LEVEL := Terrain.PREC_POND_LEVEL
const SWIM_Y := LEVEL - 0.03   # le dos affleure : on voit leurs couleurs
const MAX_R := 3.3
const HUNGER := 12          # granulés mangés pour être rassasiées
const FULL_ENOUGH := 8      # granulés qui comptent pour « nourries aujourd'hui »
const MAX_KOI := 8
const PER_THROW := 4

var game: Node3D
var fish: Array = []        # {node, data, pos (Vector2), dir, speed, target, tail, area, bob}
var pellets: Array = []     # {node, pos (Vector2), t}
var eaten_today := 0
var _rng := RandomNumberGenerator.new()
var _pellet_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _pond: Node3D

func setup(g: Node3D) -> void:
	game = g
	_rng.randomize()
	_pellet_mat = StandardMaterial3D.new()
	_pellet_mat.albedo_color = Color("#C9A36A")
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1, 1, 1, 0.32)
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pond = Node3D.new()
	_pond.name = "KoiPond"
	_pond.position = Vector3(CENTER.x, LEVEL, CENTER.y)
	game.props.add_child(_pond)
	# surface d'eau visable pour lancer les granulés (plus basse que les carpes, qui restent visables)
	var area: Interactable = game._make(_pond, Vector3(MAX_R * 2.0 + 1.0, 0.04, MAX_R * 2.0 + 1.0), Vector3(0, -0.03, 0),
		func() -> String:
			if eaten_today + pellets.size() >= HUNGER:
				return "Les carpes n'ont plus faim aujourd'hui"
			return "E : Lancer des granulés aux carpes",
		func(_p): _throw(game.player.ray.get_collision_point()))
	area.name = "PondWater"

## Début de journée : croissance, naissance, faim.
func on_day_start(day: int) -> void:
	if GameState.koi.is_empty():
		_populate()
	elif day > 1:
		var fed := bool(GameState.koi_state.get("fed_yesterday", false))
		if fed:
			GameState.koi_state["streak"] = int(GameState.koi_state.get("streak", 0)) + 1
			for k in GameState.koi:
				k["size"] = minf(float(k["size"]) + 0.08, 1.6)
				k["days"] = int(k.get("days", 0)) + 1
			if int(GameState.koi_state["streak"]) >= 2 and GameState.koi.size() < MAX_KOI:
				GameState.koi_state["streak"] = 0
				GameState.koi.append(_new_koi(0.5))
				Events.toast.emit("Une petite carpe est née dans l'étang !")
				GameState.note("Une petite carpe est née dans l'étang.")
		else:
			GameState.koi_state["streak"] = 0
	GameState.koi_state["fed_yesterday"] = false
	eaten_today = 0
	GameState.set_target(&"carpes", 1)
	_rebuild()

func _populate() -> void:
	for i in 4:
		GameState.koi.append(_new_koi(_rng.randf_range(0.85, 1.15)))

func _new_koi(size: float) -> Dictionary:
	var patterns: Array = ToolModels.KOI_PATTERNS
	return {"pattern": patterns[_rng.randi() % patterns.size()], "size": size, "name": "", "days": 0, "seed": _rng.randi()}

func _rebuild() -> void:
	for f in fish:
		if is_instance_valid(f["node"]):
			f["node"].queue_free()
	fish.clear()
	for k in GameState.koi:
		var r := RandomNumberGenerator.new()
		r.seed = int(k.get("seed", 1))
		var root := Node3D.new()
		game.props.add_child(root)
		var model := ToolModels.koi(String(k["pattern"]), r)
		model.scale = Vector3.ONE * float(k["size"]) * 1.5   # un peu plus grandes que nature : on les voit depuis la rive
		root.add_child(model)
		var ang := _rng.randf() * TAU
		var pos := CENTER + Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.5, 2.5)
		var f := {"node": root, "data": k, "pos": pos, "dir": _rng.randf() * TAU, "speed": 0.2,
			"target": _wander_target(), "tail": model.get_node("tail"), "phase": _rng.randf() * TAU, "rise": 0.0}
		var a: Interactable = game._make(root, Vector3(0.4, 0.3, 0.4) * maxf(float(k["size"]), 0.8), Vector3(0, 0.12, 0),
			func() -> String:
				var nm := String(k.get("name", ""))
				if nm == "":
					return "Une carpe %s — E : lui donner un nom" % String(k["pattern"])
				return "%s (%s) — E : lancer des granulés" % [nm, _age(k)],
			func(_p):
				if String(k.get("name", "")) == "":
					_name_koi(k)
				else:
					_throw(root.global_position))
		f["area"] = a
		fish.append(f)
		_place(f)

func _age(k: Dictionary) -> String:
	var d := int(k.get("days", 0))
	if float(k["size"]) < 0.7:
		return "toute petite"
	if d == 0:
		return "nouvelle venue"
	return "%d jour%s au sanctuaire" % [d, "s" if d > 1 else ""]

func _name_koi(k: Dictionary) -> void:
	game.player.input_enabled = false
	var nm: String = await game.hud.ask_text("Nommer cette carpe", "Hana, Kumo, Sumi...")
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	nm = nm.strip_edges().left(16)
	if nm != "":
		k["name"] = nm
		Events.toast.emit("La carpe s'appelle désormais %s." % nm)
		GameState.note("J'ai appelé une carpe « %s »." % nm)

func _wander_target() -> Vector2:
	for i in 12:
		var ang := _rng.randf() * TAU
		var p := CENTER + Vector2(cos(ang), sin(ang)) * sqrt(_rng.randf()) * MAX_R
		if Terrain.height(p.x, p.y) < LEVEL - 0.28:
			return p
	return CENTER

# ---------------------------------------------------------------- granulés
func _throw(at: Vector3) -> void:
	var room := HUNGER - eaten_today - pellets.size()
	if room <= 0:
		return
	var hand: Vector3 = game.player.camera.global_position + (-game.player.camera.global_transform.basis.z) * 0.4 + Vector3(0, -0.2, 0)
	var target := Vector2(at.x, at.z)
	if target.distance_to(CENTER) > MAX_R:
		target = CENTER + (target - CENTER).normalized() * MAX_R
	game.player.kick(Vector3(0.4, 0, 0), Vector3(0, 0.05, -0.12), 0.06, 0.3)
	Sfx.play(&"leaves", Vector3(target.x, LEVEL, target.y), -10.0)
	for i in mini(PER_THROW, room):
		var p := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.014
		sm.height = 0.028
		sm.radial_segments = 6
		sm.rings = 3
		p.mesh = sm
		p.material_override = _pellet_mat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.props.add_child(p)
		var land := target + Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))
		var pel := {"node": p, "pos": land, "t": 0.0, "landed": false}
		pellets.append(pel)
		p.global_position = hand
		var tw := p.create_tween()
		var from := hand
		var to := Vector3(land.x, LEVEL + 0.005, land.y)
		var delay := i * 0.05
		tw.tween_interval(delay)
		tw.tween_method(func(t: float): p.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.5, 0), 0.0, 1.0, 0.5)
		tw.tween_callback(func():
			pel["landed"] = true
			_ripple(Vector3(land.x, LEVEL + 0.01, land.y), 0.25))

func _ripple(at: Vector3, size: float) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.94
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = _ring_mat.duplicate()
	ring.scale = Vector3(size, 0.05, size)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.props.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(size * 3.0, 0.05, size * 3.0), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring.material_override, "albedo_color:a", 0.0, 1.4)
	tw.chain().tween_callback(ring.queue_free)

# ---------------------------------------------------------------- nage
func _process(delta: float) -> void:
	if fish.is_empty():
		return
	var t := Time.get_ticks_msec() * 0.001
	for f in fish:
		var pos: Vector2 = f["pos"]
		# la carpe vise le granulé posé le plus proche, sinon un point au hasard
		var goal: Vector2 = f["target"]
		var chasing: Dictionary = {}
		var best := 3.5
		for p in pellets:
			if p["landed"]:
				var d: float = (p["pos"] as Vector2).distance_to(pos)
				if d < best:
					best = d
					chasing = p
		if not chasing.is_empty():
			goal = chasing["pos"]
		elif pos.distance_to(goal) < 0.3:
			f["target"] = _wander_target()
			goal = f["target"]
		var want := atan2(goal.x - pos.x, goal.y - pos.y)
		var turn := wrapf(want - float(f["dir"]), -PI, PI)
		f["dir"] = float(f["dir"]) + clampf(turn, -2.2 * delta, 2.2 * delta)
		var target_speed := 0.75 if not chasing.is_empty() else 0.22
		f["speed"] = lerpf(float(f["speed"]), target_speed, 1.0 - exp(-2.0 * delta))
		var dir := Vector2(sin(f["dir"]), cos(f["dir"]))
		var np := pos + dir * float(f["speed"]) * delta
		if np.distance_to(CENTER) > MAX_R or Terrain.height(np.x, np.y) > LEVEL - 0.25:
			f["target"] = _wander_target()
			np = pos
		f["pos"] = np
		# gober
		if not chasing.is_empty() and (chasing["pos"] as Vector2).distance_to(np) < 0.2:
			_eat(f, chasing)
		f["rise"] = maxf(float(f["rise"]) - delta * 1.5, 0.0)
		_place(f)
		# queue qui ondule, plus vite quand elle nage vite
		var tail: Node3D = f["tail"]
		f["phase"] = float(f["phase"]) + delta * (4.0 + float(f["speed"]) * 14.0)
		tail.rotation.y = sin(f["phase"]) * (0.35 + float(f["speed"]) * 0.4)
	for p in pellets.duplicate():
		if p["landed"]:
			p["t"] = float(p["t"]) + delta
			var n: Node3D = p["node"]
			n.global_position.y = LEVEL + 0.005 + sin(t * 3.0 + float(p["t"])) * 0.004

func _place(f: Dictionary) -> void:
	var n: Node3D = f["node"]
	var pos: Vector2 = f["pos"]
	var bob := sin(Time.get_ticks_msec() * 0.0015 + float(f["phase"])) * 0.015
	n.global_position = Vector3(pos.x, SWIM_Y + bob + float(f["rise"]) * 0.1, pos.y)
	n.rotation = Vector3(-float(f["rise"]) * 0.35, float(f["dir"]), sin(float(f["phase"]) * 0.5) * 0.06)

func _eat(f: Dictionary, p: Dictionary) -> void:
	pellets.erase(p)
	if is_instance_valid(p["node"]):
		p["node"].queue_free()
	f["rise"] = 1.0
	_ripple(Vector3((p["pos"] as Vector2).x, LEVEL + 0.01, (p["pos"] as Vector2).y), 0.12)
	Sfx.play(&"water_draw", Vector3((p["pos"] as Vector2).x, LEVEL, (p["pos"] as Vector2).y), -14.0)
	eaten_today += 1
	if eaten_today >= FULL_ENOUGH and not bool(GameState.koi_state.get("fed_yesterday", false)):
		GameState.koi_state["fed_yesterday"] = true   # lu le lendemain matin
		GameState.add_progress(&"carpes")
		Events.toast.emit("Les carpes se sont régalées. Elles grandiront.")
		GameState.note("J'ai nourri les carpes de l'étang.")

## Test automatique : nourrit les carpes jusqu'à satiété.
func autoplay() -> void:
	while eaten_today < FULL_ENOUGH:
		eaten_today += 1
	GameState.koi_state["fed_yesterday"] = true
	GameState.add_progress(&"carpes")
