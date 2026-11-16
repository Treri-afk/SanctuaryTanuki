extends StallGame
## 輪投げ : le lancer d'anneaux, au stand de M. Tanaka.
##
## Debout derrière la corde. La souris oriente le lancer (gauche, droite). Clic maintenu : la force monte et
## redescend (jauge à droite, repères des trois rangs) ; relâcher : l'anneau part en cloche, en tournant.
## Il doit retomber AUTOUR d'un piquet : il descend alors le long du piquet (points). S'il heurte la tête d'un
## piquet, il rebondit (parfois sur un autre...). Les piquets du fond valent plus ; celui du centre, cinq.
## Cinq anneaux par manche.

const FIELD_Z := 1.95                  # centre de la natte (repère du stand)
const LINE_Z := 3.55                   # ligne de lancer
const MAT_Y := 0.026                   # dessus de la natte
## [x, z, hauteur, points]
const PEGS := [[-0.42, 2.38, 0.2, 1], [0.0, 2.42, 0.2, 1], [0.42, 2.38, 0.2, 1],
	[-0.46, 1.95, 0.25, 2], [0.0, 1.95, 0.25, 5], [0.46, 1.95, 0.25, 2],
	[-0.42, 1.5, 0.3, 3], [0.0, 1.46, 0.3, 3], [0.42, 1.5, 0.3, 3]]
const RINGS := 5
const R_CENTER := 0.085                # rayon de l'anneau (axe de la corde)
const R_TUBE := 0.012
const RING_SCALE := 0.085 / 0.075      # le modèle fait 7,5 cm de rayon
const PEG_R := 0.017
const GRAV := 9.0
const LAUNCH_ANGLE := 0.62             # rad au-dessus de l'horizontale
const V_MIN := 1.8
const V_MAX := 3.6
const POWER_PERIOD := 2.4
const SENS := 0.0016
const YAW_LIM := 0.36
const BASE_PITCH := -0.5
const NUM := ["", "一", "二", "三", "四", "五"]

var rings_left := 0
var points := 0
var ringed := 0
var _pegs: Array = []                   # {node, pos (Vector3 local, pied), h, pts, plaque}
var _rings: Array = []                  # {node, pos, vel, state, spin, peg, wob, t, cool}
var _aim := 0.0
var _power := 0.0
var _charge_t := 0.0
var _charging := false
var _gauge: Control
var _hand_ring: Node3D
var _ending := false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	id = "wanage"
	title = "Lancer d'anneaux"
	kanji = "輪投"
	host = "facteur"
	booth = "yatai_wanage"
	unit = "point"
	rules = PackedStringArray([
		"Orientez le lancer avec la souris. Maintenez le clic : la force monte et redescend ; relâchez au bon moment.",
		"L'anneau doit retomber autour d'un piquet. Ceux du fond valent trois points ; celui du milieu, cinq.",
		"Cinq anneaux. Un anneau qui heurte une tête de piquet rebondit... parfois sur un autre.",
	])
	controls = "souris : orienter   ·   clic maintenu : doser la force   ·   relâcher : lancer"

func _build() -> void:
	_rng.randomize()
	var mat := ToolModels.glb("wanage_mat")
	if mat != null:
		mat.position = Vector3(0, 0, FIELD_Z)
		add_child(mat)
	var line := ToolModels.glb("wanage_line")
	if line != null:
		line.position = Vector3(0, 0, LINE_Z)
		add_child(line)
	for p in PEGS:
		var node := ToolModels.glb("wanage_peg")
		if node == null:
			node = Node3D.new()
			ToolModels.cyl(node, PEG_R, 0.3, Color("#C79A64"), Vector3(0, 0.15, 0))
		var h := float(p[2])
		node.position = Vector3(float(p[0]), MAT_Y - 0.01, float(p[1]))
		node.scale = Vector3(1, h / 0.3, 1)
		add_child(node)
		# points sur la plaque, en chiffres japonais
		var lbl := Label3D.new()
		lbl.text = NUM[int(p[3])]
		lbl.font = UIKit.font("title")
		lbl.font_size = 64
		lbl.pixel_size = 0.0006
		lbl.modulate = Color("#2A2024") if int(p[3]) < 5 else Color("#B8341F")
		lbl.shaded = false
		lbl.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		var plq: Node3D = node.find_child("plaque", true, false)
		lbl.position = (plq.position if plq else Vector3(0, 0.22, 0.022)) + Vector3(0, 0, 0.002)
		lbl.scale = Vector3(1, 0.3 / h, 1)
		node.add_child(lbl)
		_pegs.append({"node": node, "pos": Vector3(float(p[0]), MAT_Y, float(p[1])), "h": h, "pts": int(p[3]), "label": lbl})

func view() -> Dictionary:
	return {"pos": to_global(Vector3(0, 0, LINE_Z + 0.3)), "yaw": rotation_degrees.y, "pitch": rad_to_deg(BASE_PITCH),
		"crouch": 0.0, "fov": 52.0}

func area_size() -> Vector3:
	return Vector3(1.9, 0.8, 2.7)

func area_offset() -> Vector3:
	return Vector3(0, 0.4, 2.4)

func host_spot() -> Vector3:
	return to_global(Vector3(-1.45, 0, 4.25))       # à côté du joueur, pour l'encourager

# ---------------------------------------------------------------- entrer, sortir
func _on_enter() -> void:
	_gauge = Control.new()
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_ui.add_child(_gauge)
	_ui.move_child(_gauge, 0)
	_hand_ring = ToolModels.glb("wanage_ring")
	if _hand_ring != null:
		_hand_ring.position = Vector3(0.2, -0.24, -0.42)
		_hand_ring.rotation_degrees = Vector3(70, 0, -15)
		game.player.camera.add_child(_hand_ring)

func _on_leave() -> void:
	if _hand_ring != null:
		_hand_ring.queue_free()
		_hand_ring = null
	game.player.rotation.y = global_rotation.y

# ---------------------------------------------------------------- manche
func _round_start() -> void:
	for r in _rings:
		if is_instance_valid(r["node"]):
			(r["node"] as Node).queue_free()
	_rings.clear()
	rings_left = RINGS
	points = 0
	ringed = 0
	_ending = false
	_charging = false
	_power = 0.0
	if _hand_ring:
		_hand_ring.visible = true

func status() -> String:
	return "Anneaux : %d / %d   ·   %d point%s" % [rings_left, RINGS, points, "s" if points > 1 else ""]

func _motion(rel: Vector2) -> void:
	_aim = clampf(_aim - rel.x * SENS, -YAW_LIM, YAW_LIM)

func _press() -> void:
	if rings_left <= 0:
		return
	_charging = true
	_charge_t = 0.0

func _release() -> void:
	if not _charging:
		return
	_charging = false
	_throw(_power)

func _tick(delta: float) -> void:
	var pl: CharacterBody3D = game.player
	pl.rotation.y = global_rotation.y + _aim
	pl.head.rotation.x = BASE_PITCH
	if _charging:
		_charge_t += delta
		_power = 0.5 - 0.5 * cos(_charge_t * TAU / POWER_PERIOD)
		if _hand_ring:
			_hand_ring.position = Vector3(0.2, -0.24 - _power * 0.06, -0.42 + _power * 0.08)
	for r in _rings:
		_step_ring(r, delta)
	if _gauge:
		_gauge.queue_redraw()
	refresh_status()
	if rings_left <= 0 and not _ending and _rings.all(func(r): return r["state"] == "rest"):
		_ending = true
		_finish_later()

func _throw(power: float) -> void:
	rings_left -= 1
	var pl: CharacterBody3D = game.player
	var start := _launch_start()
	var fwd := -pl.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var speed := lerpf(V_MIN, V_MAX, power)
	var vel := fwd * speed * cos(LAUNCH_ANGLE) + Vector3.UP * speed * sin(LAUNCH_ANGLE)
	var node := ToolModels.glb("wanage_ring")
	if node == null:
		node = Node3D.new()
		var t := TorusMesh.new()
		t.inner_radius = R_CENTER - R_TUBE
		t.outer_radius = R_CENTER + R_TUBE
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.material_override = Toon.material(Color("#C9432C"))
		node.add_child(mi)
	node.scale = Vector3.ONE * RING_SCALE
	add_child(node)
	var lp := to_local(start)
	var lv := global_basis.inverse() * vel
	_rings.append({"node": node, "pos": lp, "vel": lv, "state": "fly", "spin": 0.0, "tilt": Vector2(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.1, 0.25)),
		"peg": -1, "wob": 0.0, "t": 0.0, "cool": 0.0})
	sfx(["whoosh", "sweep"], start, -10.0)
	if _hand_ring:
		_hand_ring.visible = false
		get_tree().create_timer(0.5).timeout.connect(func():
			if _hand_ring and rings_left > 0:
				_hand_ring.visible = true
				_hand_ring.position = Vector3(0.2, -0.24, -0.42))

## D'où part l'anneau (monde) : la main, sous le regard.
func _launch_start() -> Vector3:
	var pl: CharacterBody3D = game.player
	var fwd := -pl.global_basis.z
	fwd.y = 0.0
	return pl.camera.global_position - Vector3(0, 0.42, 0) + fwd.normalized() * 0.3

## Vol, rebonds sur les têtes de piquets, descente autour d'un piquet, glissade sur la natte.
func _step_ring(r: Dictionary, delta: float) -> void:
	var node: Node3D = r["node"]
	var p: Vector3 = r["pos"]
	var v: Vector3 = r["vel"]
	r["t"] = float(r["t"]) + delta
	r["cool"] = maxf(0.0, float(r["cool"]) - delta)
	match String(r["state"]):
		"fly":
			v.y -= GRAV * delta
			var np := p + v * delta
			for k in _pegs.size():
				var pg: Dictionary = _pegs[k]
				var top := MAT_Y + float(pg["h"])
				var axis := Vector2((pg["pos"] as Vector3).x, (pg["pos"] as Vector3).z)
				# passage du plan de l'anneau à la hauteur de la tête du piquet, en descendant
				if p.y > top and np.y <= top and v.y < 0.0 and float(r["cool"]) <= 0.0:
					var t := (p.y - top) / maxf(p.y - np.y, 0.0001)
					var at := p.lerp(np, t)
					var d := Vector2(at.x, at.z).distance_to(axis)
					# dedans ; ou la corde accroche à peine la tête et l'anneau bascule autour (une fois sur deux)
					var tips_in := d < R_CENTER - 0.004 and _rng.randf() < 0.5
					if d < R_CENTER - R_TUBE - PEG_R or tips_in:
						r["state"] = "ringed"
						r["peg"] = k
						r["pos"] = at
						r["vel"] = Vector3(0, minf(v.y, -0.6), 0)
						r["wob"] = 1.0
						_score(k, at)
						_place(r)
						return
					elif d < R_CENTER + R_TUBE + PEG_R + 0.004:
						# la corde heurte la tête : rebond vers l'extérieur
						var out := (Vector2(at.x, at.z) - axis).normalized()
						if out.length() < 0.1:
							out = Vector2(_rng.randf_range(-1, 1), 1).normalized()
						var hs := Vector2(v.x, v.z).length() * 0.45
						v = Vector3(out.x * hs, absf(v.y) * 0.35, out.y * hs)
						np = Vector3(at.x, top + 0.005, at.z)
						r["cool"] = 0.08
						r["tilt"] = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6))
						sfx(["ring_clack", "hammer"], to_global(at), -16.0)
						break
				# flanc d'un piquet sous la tête : l'anneau s'y cogne
				elif np.y < top and np.y > MAT_Y:
					var dn := Vector2(np.x, np.z).distance_to(axis)
					var inner := R_CENTER - R_TUBE - PEG_R
					var outer := R_CENTER + R_TUBE + PEG_R
					if dn > inner and dn < outer and float(r["cool"]) <= 0.0:
						var dirv := (Vector2(np.x, np.z) - axis).normalized()
						var push := (outer - dn) if dn > R_CENTER else -(dn - inner)
						np += Vector3(dirv.x, 0, dirv.y) * push
						var hv := Vector2(v.x, v.z)
						var nrm := dirv if dn > R_CENTER else -dirv
						hv = hv.bounce(nrm) * 0.5 if hv.dot(nrm) < 0.0 else hv
						v = Vector3(hv.x, v.y, hv.y)
						r["cool"] = 0.05
			if np.y <= MAT_Y + R_TUBE:
				np.y = MAT_Y + R_TUBE
				if absf(v.y) > 0.9:
					v.y = -v.y * 0.22
					v.x *= 0.55
					v.z *= 0.55
					sfx(["ring_land", "putdown"], to_global(np), -18.0)
				else:
					v.y = 0.0
					r["state"] = "slide"
			r["spin"] = float(r["spin"]) + delta * 9.0
			r["pos"] = np
			r["vel"] = v
		"slide":
			var hv := Vector2(v.x, v.z)
			var sp := hv.length()
			sp = maxf(0.0, sp - 3.2 * delta)
			hv = hv.normalized() * sp if sp > 0.0 else Vector2.ZERO
			p += Vector3(hv.x, 0, hv.y) * delta
			# les piquets arrêtent l'anneau qui glisse
			for pg in _pegs:
				var axis := Vector2((pg["pos"] as Vector3).x, (pg["pos"] as Vector3).z)
				var dn := Vector2(p.x, p.z).distance_to(axis)
				var outer := R_CENTER + R_TUBE + PEG_R
				if dn < outer and dn > R_CENTER:
					var dirv := (Vector2(p.x, p.z) - axis).normalized()
					p += Vector3(dirv.x, 0, dirv.y) * (outer - dn)
					hv = hv.bounce(dirv) * 0.4 if hv.dot(dirv) < 0.0 else hv
			r["pos"] = p
			r["vel"] = Vector3(hv.x, 0, hv.y)
			r["spin"] = float(r["spin"]) + delta * sp * 6.0
			r["tilt"] = (r["tilt"] as Vector2).lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
			if sp <= 0.01:
				r["state"] = "rest"
		"ringed":
			# l'anneau descend le long du piquet en tournoyant, puis se pose et vacille comme une pièce
			var pg: Dictionary = _pegs[int(r["peg"])]
			var axis3: Vector3 = pg["pos"]
			p.x = lerpf(p.x, axis3.x, 1.0 - exp(-5.0 * delta))
			p.z = lerpf(p.z, axis3.z, 1.0 - exp(-5.0 * delta))
			v.y -= GRAV * 0.5 * delta
			p.y += v.y * delta
			if p.y <= MAT_Y + R_TUBE:
				p.y = MAT_Y + R_TUBE
				v = Vector3.ZERO
				if float(r["wob"]) >= 1.0:
					sfx(["ring_land", "putdown"], to_global(p), -12.0)
				r["wob"] = maxf(0.0, float(r["wob"]) - delta * 0.7)
				if float(r["wob"]) <= 0.0:
					r["state"] = "rest"
			r["pos"] = p
			r["vel"] = v
			r["spin"] = float(r["spin"]) + delta * 4.0 * (0.3 + float(r["wob"]))
			var w := float(r["wob"])
			r["tilt"] = Vector2(sin(float(r["t"]) * 14.0) * 0.22 * w, cos(float(r["t"]) * 14.0) * 0.22 * w)
	_place(r)

func _place(r: Dictionary) -> void:
	var node: Node3D = r["node"]
	node.position = r["pos"]
	var tl: Vector2 = r["tilt"]
	node.rotation = Vector3(tl.x, float(r["spin"]), tl.y)

func _score(k: int, at: Vector3) -> void:
	var pg: Dictionary = _pegs[k]
	var pts := int(pg["pts"])
	points += pts
	ringed += 1
	pop("+%d" % pts, to_global(at + Vector3(0, 0.2, 0)), Color("#FFD45A") if pts >= 3 else Color("#FFF3D6"), 30 + pts * 3)
	sfx(["ring_on", "tick"], to_global(at), -6.0)
	game.hud.pulse()
	var lbl: Label3D = pg["label"]
	var base_col := lbl.modulate
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate", Color("#E8A21E"), 0.1)
	tw.tween_interval(0.6)
	tw.tween_property(lbl, "modulate", base_col, 0.5)

func _finish_later() -> void:
	await get_tree().create_timer(1.0).timeout
	if not playing:
		return
	var prizes := {}
	if points >= 10:
		prizes["furin"] = 1
	elif points >= 5:
		prizes["omen"] = 1
	elif points >= 1:
		prizes["ame"] = 1
	var line := "Aucun anneau autour d'un piquet." if ringed == 0 else "%d anneau%s autour des piquets." % [ringed, "x" if ringed > 1 else ""]
	end_round(points, line, prizes)

## Jauge de force : bandelette de papier verticale à droite, encre qui monte ; repères des trois rangs.
func _draw_gauge() -> void:
	if not playing:
		return
	var sz := _gauge.size
	var x := sz.x * 0.5 + 230.0
	var h := 240.0
	var y0 := sz.y * 0.5 + h * 0.5
	var r := Rect2(x - 15, y0 - h, 30, h)
	_gauge.draw_rect(r.grow(5), Color(0.18, 0.1, 0.06, 0.35))
	_gauge.draw_rect(r, Color("#F3EBD9"))
	for k in 3:
		var pz: float = [2.4, 1.95, 1.48][k]
		var pw := _power_for(pz)
		var yy := y0 - h * pw
		_gauge.draw_line(Vector2(x - 22, yy), Vector2(x + 22, yy), Color(0.75, 0.24, 0.16, 0.85), 2.0)
		_gauge.draw_string(UIKit.font("title"), Vector2(x + 26, yy + 7), ["一", "二", "三"][k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#FBF1DC"))
	var fill := _power if _charging else 0.0
	if fill > 0.0:
		_gauge.draw_rect(Rect2(x - 11, y0 - h * fill, 22, h * fill), Color(0.23, 0.16, 0.12, 0.85))
	_gauge.draw_rect(r, UIKit.INK, false, 1.5)

## Force qui fait retomber l'anneau à la profondeur z (repère du stand), pour placer les repères de la jauge.
func _power_for(z: float) -> float:
	var start := to_local(_launch_start())
	var dist := start.z - z
	var h := start.y - (MAT_Y + 0.25)
	# portée d'un tir parabolique : on cherche la vitesse par dichotomie
	var lo := 0.0
	var hi := 1.0
	for i in 18:
		var mid := (lo + hi) * 0.5
		var sp := lerpf(V_MIN, V_MAX, mid)
		var vx := sp * cos(LAUNCH_ANGLE)
		var vy := sp * sin(LAUNCH_ANGLE)
		var t := (vy + sqrt(vy * vy + 2.0 * GRAV * maxf(h, 0.0))) / GRAV
		if vx * t < dist:
			lo = mid
		else:
			hi = mid
	return clampf((lo + hi) * 0.5, 0.0, 1.0)

func host_line(score: int) -> String:
	if score <= 0:
		return "Allez ! Même les lettres n'arrivent pas toujours du premier coup."
	if score < 5:
		return "Pas mal ! Le poignet souple, comme pour glisser une lettre sous une porte."
	if score < 10:
		return "Joli lancer ! Tiens, un masque de renard. Il te va bien."
	return "Formidable ! Trente ans de tournées, et je n'ai jamais lancé comme ça."

# ---------------------------------------------------------------- test
## Capture : un anneau autour du piquet central, un autre en vol.
func debug_pose() -> void:
	_aim = 0.0
	_throw(_power_for(1.95))
	await get_tree().create_timer(0.35).timeout
	_charging = true
	_power = 0.62
	await get_tree().create_timer(0.1).timeout

## Test : un lancer calculé vers chaque rang, renvoie les points.
func autoplay_round() -> int:
	for z in [1.95, 2.4, 1.48, 1.95, 2.4]:
		_aim = 0.0
		var pw := _power_for(z)
		_throw(pw)
		var r: Dictionary = _rings[-1]
		var apex := 0.0
		var cross := []
		var prev: Vector3 = r["pos"]
		for i in 120:
			await get_tree().physics_frame
			var pp: Vector3 = r["pos"]
			apex = maxf(apex, pp.y)
			if prev.y > MAT_Y + 0.25 and pp.y <= MAT_Y + 0.25:
				cross.append(pp)
			prev = pp
		print("TEST anneau visé z=%.2f puissance %.2f : état %s, fin %s, apex %.2f, passage h=0.25 %s, départ joueur %s" % [z, pw, r["state"], str(r["pos"]), apex, str(cross), str(to_local(game.player.camera.global_position))])
	await get_tree().create_timer(1.5).timeout
	return points
