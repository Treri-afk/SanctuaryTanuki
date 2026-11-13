extends MorningTask
## Tailler les haies : des rameaux ont poussé dans la nuit et dépassent des trois haies de la cour.
## Cisaille en main, clic maintenu : on passe le viseur sur les rameaux et ils tombent un à un, en pluie
## de feuilles. C'est rapide et un peu grisant ; il faut juste n'en oublier aucun.

const HEDGES := [   # x, z, longueur, rotation (degrés)
	[-8.5, -4.6, 4.0, 0.0],
	[8.0, -10.5, 4.0, 0.0],
	[15.5, 4.0, 4.0, 0.0],
]
const CUT_RADIUS := 0.32

var hedge_nodes: Array[Node3D] = []
var sprigs: Array = []      # Dictionary : node, cut, hedge
var _rng := RandomNumberGenerator.new()
var _burst_mat: StandardMaterial3D

func setup() -> void:
	_rng.seed = 7
	for h in HEDGES:
		var n := ToolModels.hedge(h[2], _rng)
		n.name = "Hedge"
		n.position = Vector3(h[0], 0.0, h[1])
		n.rotation_degrees.y = h[3]
		props.add_child(n)
		hedge_nodes.append(n)
		game._make(n, Vector3(h[2] + 0.5, 1.5, 1.4), Vector3(0, 0.6, 0),
			func() -> String:
				if not active or done():
					return ""
				var left := _left()
				if player.tool != &"shears":
					return "Les haies débordent : il faudrait la cisaille"
				return "Maintenir le clic et passer sur les rameaux (%d restants)" % left,
			Callable(), _snip)
	_burst_mat = StandardMaterial3D.new()
	_burst_mat.albedo_color = ToolModels.HEDGE_LIGHT
	_burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func hint() -> String:
	return "Haies : cisaille sur l'établi près du bureau du sanctuaire."

func clear() -> void:
	for s in sprigs:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	sprigs.clear()

func begin(_day: int) -> void:
	_rng.randomize()
	for i in hedge_nodes.size():
		var hn := hedge_nodes[i]
		var length: float = HEDGES[i][2]
		for k in 9:
			var node := Node3D.new()
			hn.add_child(node)
			var x := _rng.randf_range(-length * 0.5 + 0.2, length * 0.5 - 0.2)
			var on_top := _rng.randf() < 0.55
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var pos := Vector3(x, 1.02, _rng.randf_range(-0.2, 0.2)) if on_top else Vector3(x, _rng.randf_range(0.45, 0.85), 0.42 * side)
			node.position = pos
			var dir := Vector3(_rng.randf_range(-0.3, 0.3), 1.0, _rng.randf_range(-0.3, 0.3)) if on_top else Vector3(_rng.randf_range(-0.3, 0.3), 0.35, side)
			dir = dir.normalized()
			# rameau : tige fine + petites touffes de feuilles claires
			var stem_len := _rng.randf_range(0.28, 0.45)
			var stem := ToolModels.cyl(node, 0.008, stem_len, ToolModels.WOOD_DARK, Vector3.ZERO)
			var bx := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
			stem.transform = Transform3D(Basis(bx, dir, bx.cross(dir).normalized()), dir * stem_len * 0.5)
			for j in 3:
				var t := 0.45 + 0.27 * j
				ToolModels.ball(node, 0.09, ToolModels.HEDGE_LIGHT.lerp(Color("#93AD55"), _rng.randf()),
					dir * stem_len * t + Vector3(_rng.randf_range(-0.05, 0.05), 0.0, _rng.randf_range(-0.05, 0.05)),
					Vector3(1.2, 0.7, 1.0), &"foliage")
			sprigs.append({"node": node, "cut": false, "tip": dir * stem_len * 0.7})
	GameState.set_target(id, sprigs.size())

func _left() -> int:
	var n := 0
	for s in sprigs:
		if not s["cut"]:
			n += 1
	return n

func _snip(pl, _delta: float, _motion: Vector2) -> void:
	if not active or pl.tool != &"shears":
		return
	pl.action = &"snip"
	# on coupe tout rameau proche du rayon de visée (pas seulement du point touché) : balayer la haie suffit
	var cam: Camera3D = pl.camera
	var o := cam.global_position
	var dir := -cam.global_transform.basis.z
	for s in sprigs:
		if s["cut"]:
			continue
		var node: Node3D = s["node"]
		for pt in [node.global_position, node.global_transform * (s["tip"] as Vector3)]:
			var v: Vector3 = pt - o
			var along := v.dot(dir)
			if along > 0.2 and along < 3.4 and (v - dir * along).length() < CUT_RADIUS:
				_cut(s)
				break

func _cut(s: Dictionary) -> void:
	s["cut"] = true
	var node: Node3D = s["node"]
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + Vector3(0, -0.15, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(node.queue_free)
	_burst(node.global_position + Vector3(0, 0.1, 0))
	Sfx.play(&"snip", node.global_position, -2.0)
	player.kick(Vector3(0, 0, 0.12), Vector3(0, 0.01, -0.04), 0.03, 0.12)
	var was_done := done()
	GameState.add_progress(id)
	if not was_done and done():
		Events.toast.emit("Les haies sont nettes. Les moineaux reviennent s'y cacher.")

func _burst(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = _burst_mat
	p.mesh = q
	p.amount = 14
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -6.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.particle_flag_align_y = false
	props.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

func autoplay() -> void:
	game._equip(&"shears")
	for s in sprigs:
		if not s["cut"]:
			_cut(s)
	game.player_put_back_tool()
