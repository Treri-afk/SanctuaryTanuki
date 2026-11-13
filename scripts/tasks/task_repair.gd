extends MorningTask
## Réparer la palissade : la nuit a arraché trois planches d'un muret.
## On remet chaque planche en place (E), puis on enfonce ses clous au marteau. Un cercle se resserre autour du
## viseur : frapper quand il touche le point enfonce le clou d'un coup, sinon il faut plusieurs coups.

const RING_SPEED := 1.15      # tours de cercle par seconde
const PERFECT := 0.8          # fenêtre de frappe parfaite (fin du cercle)

var wall: Node3D
var boards: Array = []        # Dictionary : node, target, placed, area
var nails: Array = []         # Dictionary : node, depth, area, out
var ring_t := 0.0
var _rng := RandomNumberGenerator.new()

func hint() -> String:
	return "Palissade : marteau sur l'établi près du bureau du sanctuaire."

func clear() -> void:
	for b in boards:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	for n in nails:
		if is_instance_valid(n["node"]):
			n["node"].queue_free()
	boards.clear()
	nails.clear()

func _pick_wall() -> Node3D:
	var cands: Array[Node3D] = []
	for c in props.get_children():
		var nm := String(c.name)
		if not nm.begins_with("Wall"):
			continue
		var p: Vector3 = (c as Node3D).position
		if nm.begins_with("WallFront") and absf(p.x) < 6.0:
			continue
		if (nm.begins_with("WallW") or nm.begins_with("WallE")) and (p.z < -31.0 or p.z > 6.0):
			continue
		cands.append(c)
	return cands[_rng.randi() % cands.size()] if not cands.is_empty() else null

func begin(_day: int) -> void:
	_rng.randomize()
	wall = _pick_wall()
	if wall == null:
		GameState.set_target(id, 1)
		GameState.add_progress(id)
		return
	var along := wall.global_transform.basis.x.normalized()
	var nrm := wall.global_transform.basis.z.normalized()
	var center := Vector3(0, 0, -13)
	if nrm.dot(center - wall.global_position) < 0.0:
		nrm = -nrm
	nrm.y = 0.0
	nrm = nrm.normalized()
	along = Vector3.UP.cross(nrm).normalized()   # repère direct : along x UP = nrm
	var heights := [0.32, 0.56, 0.8]
	for i in 3:
		var node := Node3D.new()
		props.add_child(node)
		ToolModels.box(node, Vector3(1.7, 0.13, 0.035), ToolModels.WOOD_FADED.lerp(ToolModels.WOOD, _rng.randf() * 0.4), Vector3.ZERO)
		var target := Transform3D(Basis(along, Vector3.UP, nrm), wall.global_position + nrm * 0.24 + Vector3(0, heights[i], 0))
		# planche tombée au pied du muret, de travers
		var lying_pos := wall.global_position + nrm * (0.9 + i * 0.45) + along * _rng.randf_range(-0.5, 0.5)
		lying_pos.y = ground_y(lying_pos.x, lying_pos.z, 1.0) + 0.02 + 0.03 * i
		var yaw := Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4))
		var lying := Transform3D(yaw * Basis(along, nrm, -Vector3.UP), lying_pos)
		node.global_transform = lying
		var b := {"node": node, "target": target, "placed": false, "area": null}
		var a: Interactable = game._make(node, Vector3(1.8, 0.4, 0.4), Vector3.ZERO,
			func() -> String: return "" if b["placed"] else "E : Remettre la planche en place",
			func(_p): _place(b))
		b["area"] = a
		boards.append(b)
	GameState.set_target(id, boards.size() * 2)
	ring_t = 0.0

func _place(b: Dictionary) -> void:
	if b["placed"]:
		return
	b["placed"] = true
	game._area_on(b["area"], false)
	var node: Node3D = b["node"]
	var tw := node.create_tween()
	var from := node.global_transform
	var to: Transform3D = b["target"]
	tw.tween_method(func(t: float): node.global_transform = from.interpolate_with(to, t), 0.0, 1.0, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _add_nails(b))
	Sfx.play(&"putdown", to.origin)
	player.kick(Vector3(0.2, 0, 0), Vector3(0, 0.05, -0.08))

func _add_nails(b: Dictionary) -> void:
	var t: Transform3D = b["target"]
	for s in [-0.65, 0.65]:
		var nd := Node3D.new()
		props.add_child(nd)
		var out: Vector3 = t.basis.z
		nd.global_transform = Transform3D(Basis(t.basis.x, out, -t.basis.y), t.origin + t.basis.x * s + out * 0.06)
		ToolModels.cyl(nd, 0.006, 0.09, ToolModels.METAL, Vector3(0, -0.03, 0), Vector3.ZERO, -1.0, 6)
		ToolModels.cyl(nd, 0.016, 0.006, ToolModels.METAL.darkened(0.2), Vector3(0, 0.015, 0), Vector3.ZERO, -1.0, 8)
		var nail := {"node": nd, "depth": 0.0, "area": null, "base": t.origin + t.basis.x * s + out * 0.018, "out": out}
		var a: Interactable = game._make(nd, Vector3(0.18, 0.18, 0.18), Vector3.ZERO,
			func() -> String:
				if float(nail["depth"]) >= 1.0:
					return ""
				return "Clic quand le cercle touche le point : enfoncer le clou" if player.tool == &"hammer" else "Il faudrait le marteau",
			func(_p): _strike(nail))
		nail["area"] = a
		nails.append(nail)

func physics(delta: float) -> void:
	var aiming := false
	if player.tool == &"hammer" and player.target != null:
		for n in nails:
			if n["area"] == player.target and float(n["depth"]) < 1.0:
				aiming = true
	if aiming:
		ring_t = fmod(ring_t + delta * RING_SPEED, 1.0)
		game.hud.ring_phase = ring_t
	else:
		ring_t = 0.0

func _strike(nail: Dictionary, force_perfect := false) -> void:
	if player.tool != &"hammer" or float(nail["depth"]) >= 1.0:
		return
	var perfect := force_perfect or ring_t >= PERFECT
	nail["depth"] = minf(float(nail["depth"]) + (1.0 if perfect else 0.34), 1.0)
	var nd: Node3D = nail["node"]
	var target_pos: Vector3 = (nail["base"] as Vector3) + (nail["out"] as Vector3) * 0.045 * (1.0 - float(nail["depth"]))
	var tw := nd.create_tween()
	tw.tween_property(nd, "global_position", target_pos, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	player.kick(Vector3(-0.85, 0, 0.1), Vector3(0, -0.06, -0.1), 0.05, 0.3)
	Sfx.play(&"hammer", nd.global_position, 0.0 if perfect else -4.0)
	if perfect:
		player.flash_prompt("Parfait !")
		game.hud.pulse()
	ring_t = 0.0
	if float(nail["depth"]) >= 1.0:
		game._area_on(nail["area"], false)
		var was_done := done()
		GameState.add_progress(id)
		if not was_done and done():
			Events.toast.emit("La palissade tient de nouveau. Le bois sent la résine.")

func autoplay() -> void:
	for b in boards:
		_place(b)
	await game.get_tree().create_timer(0.6).timeout
	game._equip(&"hammer")
	for n in nails:
		_strike(n, true)
	game.player_put_back_tool()
