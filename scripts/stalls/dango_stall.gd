extends StallGame
## 月見団子 : la pyramide de dango pour la lune, au stand de Madame Fumiko.
##
## Penché sur le sanbō (plateau d'offrande). Les baguettes tiennent une boulette au-dessus du plateau : la
## souris les déplace, une petite ombre montre où elle tombera ; clic : on la lâche.
## Les boulettes roulent vraiment : posée dans le creux de quatre autres, une boulette tient ; sur le dessus
## d'une seule, elle roule... et peut sauter le rebord du plateau. Immobiles un instant, elles collent (mochi).
## Quatorze dango : neuf en carré, quatre au-dessus, une au sommet. La main tremble un peu.
##
## Physique faite main (boules contre boules et plateau, au millimètre) : le moteur général laisse les objets
## s'enfoncer de 1 à 2 cm, la moitié d'une boulette.

const SANBO := Vector3(0.0, 0.885, 0.42)    # pied du sanbō sur le comptoir (repère du stand)
const TRAY_Y := 0.164                       # dessus du papier, au-dessus du pied
const TRAY_HALF := 0.123                    # intérieur du plateau
const RIM_H := 0.012
const COUNTER_DY := -0.164                  # dessus du comptoir, sous le plateau
const R := 0.0192                           # rayon d'une boulette
const COUNT := 14
const HOLD_H := 0.11                        # hauteur des baguettes au-dessus du plateau
const SENS := 0.00042
const STICK_T := 0.3                        # secondes immobile avant de « coller »
const GRAV := 9.8
const HOP_SPEED := 0.3                      # assez vite, une boulette saute le rebord
const SUBSTEPS := 4

var placed := 0
var _sanbo: Node3D
var _hashi: Node3D
var _held: Node3D
var _shadow: Decal
var _hand := Vector2.ZERO                   # position des baguettes sur le plateau (x, z autour du centre)
var _hand_prev := Vector2.ZERO
var _hand_vel := Vector2.ZERO
var _t := 0.0
var _next_in := 0.0
var _balls: Array = []                      # {node, p (repère du plateau), v, rest, stuck, lost, landed, sup}
var _ending := false
var _result := {}

func _init() -> void:
	id = "dango"
	title = "Pyramide de dango"
	kanji = "団子"
	host = "vieille_dame"
	booth = "yatai_dango"
	unit = "dango"
	rules = PackedStringArray([
		"Déplacez les baguettes avec la souris ; une petite ombre montre où la boulette tombera. Clic : la lâcher.",
		"Quatorze dango : neuf en carré bien serré, quatre dans les creux au-dessus, une au sommet.",
		"Une boulette posée dans un creux tient ; sur le dessus d'une autre, elle roule... et peut tomber du plateau.",
	])
	controls = "souris : déplacer les baguettes   ·   clic : lâcher la boulette"

func _build() -> void:
	_sanbo = ToolModels.glb("sanbo")
	if _sanbo == null:
		_sanbo = Node3D.new()
		ToolModels.box(_sanbo, Vector3(0.27, 0.16, 0.27), Color("#E6D2AE"), Vector3(0, 0.08, 0))
	_sanbo.position = SANBO
	add_child(_sanbo)
	# ombre portée de la boulette tenue (repère de visée)
	_shadow = Decal.new()
	_shadow.size = Vector3(R * 2.2, 0.03, R * 2.2)
	_shadow.texture_albedo = _blob_texture()
	_shadow.modulate = Color(0.25, 0.08, 0.04, 0.85)
	_shadow.visible = false
	add_child(_shadow)

func _blob_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func view() -> Dictionary:
	return {"pos": to_global(Vector3(0, 0, 0.92)), "yaw": rotation_degrees.y, "pitch": -44.0, "crouch": 0.05, "fov": 34.0}

func host_spot() -> Vector3:
	return to_global(Vector3(-1.6, 0, 0.6))

func _tray_top() -> Vector3:
	return SANBO + Vector3(0, TRAY_Y, 0)

# ---------------------------------------------------------------- entrer, sortir
func _on_enter() -> void:
	_hashi = Node3D.new()
	add_child(_hashi)
	var h := ToolModels.glb("hashi")
	if h != null:
		h.rotation_degrees.y = 200.0          # baguettes qui viennent de la droite, vers le joueur
		_hashi.add_child(h)
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _on_leave() -> void:
	if _hashi != null:
		_hashi.queue_free()
		_hashi = null
	_held = null
	_shadow.visible = false
	game.player.rotation.y = global_rotation.y

func _make_ball() -> Node3D:
	var b := ToolModels.glb("dango_ball")
	if b == null:
		b = Node3D.new()
		ToolModels.ball(b, R, Color("#F6F1E6"), Vector3.ZERO)
	return b

# ---------------------------------------------------------------- manche
func _round_start() -> void:
	for b in _balls:
		if is_instance_valid(b["node"]):
			(b["node"] as Node).queue_free()
	_balls.clear()
	placed = 0
	_ending = false
	_hand = Vector2(0.0, 0.03)
	_hand_prev = _hand
	_next_in = 0.0
	_give_ball()

func _give_ball() -> void:
	if _held != null:
		_held.queue_free()
	_held = _make_ball()
	_hashi.add_child(_held)
	_held.position = Vector3.ZERO
	_shadow.visible = true

func status() -> String:
	return "Dango : %d / %d   ·   sur le plateau : %d" % [placed, COUNT, _count_on_tray()]

func _motion(rel: Vector2) -> void:
	_hand += Vector2(rel.x, rel.y) * SENS
	_hand = _hand.clamp(Vector2(-0.17, -0.17), Vector2(0.17, 0.17))

func _press() -> void:
	if _held == null or placed >= COUNT:
		return
	_drop()

func _tick(delta: float) -> void:
	_t += delta
	# la main tremble un peu, de plus en plus à mesure que la pyramide monte
	var trem := 0.0012 + 0.0002 * placed
	var shake := Vector2(sin(_t * 2.3) + 0.5 * sin(_t * 5.1), cos(_t * 1.9) + 0.5 * sin(_t * 4.3 + 1.0)) * trem
	var hp := _hand + shake
	_hand_vel = (hp - _hand_prev) / maxf(delta, 0.0001)
	_hand_prev = hp
	var top := _tray_top()
	if _hashi:
		_hashi.position = top + Vector3(hp.x, HOLD_H, hp.y)
	if _held != null:
		_shadow.position = top + Vector3(hp.x, _support_height(hp), hp.y)
	if _held == null and placed < COUNT:
		_next_in -= delta
		if _next_in <= 0.0:
			_give_ball()
	_simulate(delta)
	refresh_status()
	if placed >= COUNT and not _ending and _balls.all(func(b): return b["stuck"] or b["lost"]):
		_ending = true
		_finish_later()

## Hauteur de ce qui est sous ce point (dessus d'une boulette collée, ou le papier).
func _support_height(at: Vector2) -> float:
	var h := 0.0
	for b in _balls:
		if not b["stuck"] or b["lost"]:
			continue
		var p: Vector3 = b["p"]
		var d := Vector2(p.x, p.z).distance_to(at)
		if d < R:
			h = maxf(h, p.y + sqrt(R * R - d * d))
	return h

func _drop() -> void:
	var node := _make_ball()
	node.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	add_child(node)
	var p := Vector3(_hand_prev.x, HOLD_H, _hand_prev.y)
	var v := Vector3(_hand_vel.x, 0, _hand_vel.y) * 0.35
	_held.queue_free()
	_held = null
	_shadow.visible = false
	placed += 1
	_next_in = 0.55
	_balls.append({"node": node, "p": p, "v": v, "rest": 0.0, "stuck": false, "lost": false, "landed": false, "sup": false})
	_place_ball(_balls[-1], 0.0)
	sfx(["dango_drop", "plop"], to_global(_tray_top() + p), -14.0)

## Boules contre boules (contraintes de distance), papier, rebord, comptoir. Les boulettes collées sont fixes.
func _simulate(delta: float) -> void:
	var dt := delta / SUBSTEPS
	for step in SUBSTEPS:
		for b in _balls:
			if b["stuck"]:
				continue
			var p: Vector3 = b["p"]
			var v: Vector3 = b["v"]
			var prev := p
			v.y -= GRAV * dt
			p += v * dt
			var supported := false
			for it in 3:
				for o in _balls:
					if o == b or (o["lost"] and not b["lost"]):
						continue
					var q: Vector3 = o["p"]
					var d := p - q
					var dist := d.length()
					if dist < 2.0 * R and dist > 0.000001:
						var n := d / dist
						var corr := 2.0 * R - dist
						if o["stuck"]:
							p += n * corr
						else:
							p += n * corr * 0.5
							o["p"] = q - n * corr * 0.5
						var vn := v.dot(n)
						if vn < 0.0:
							v -= n * vn
						if n.y > 0.25:
							supported = true
				var inside := absf(p.x) <= TRAY_HALF + R * 0.4 and absf(p.z) <= TRAY_HALF + R * 0.4
				if inside and p.y < R and not b["lost"]:
					p.y = R
					if v.y < 0.0:
						v.y = 0.0
					supported = true
				# rebord : il arrête une boulette qui roule doucement sur le papier ; trop vite, elle saute
				if not b["lost"] and p.y < R + RIM_H:
					for axis in [0, 2]:
						var lim := TRAY_HALF - R
						if absf(p[axis]) > lim and absf(prev[axis]) <= lim + 0.0005:
							if absf(v[axis]) > HOP_SPEED:
								v.y = maxf(v.y, absf(v[axis]) * 0.4)
							else:
								p[axis] = signf(p[axis]) * lim
								v[axis] = -v[axis] * 0.2
				if p.y < COUNTER_DY + R:
					p.y = COUNTER_DY + R
					v = Vector3(v.x, 0.0, v.z) * 0.5
					supported = true
			if not b["lost"] and (absf(p.x) > TRAY_HALF + R * 0.5 or absf(p.z) > TRAY_HALF + R * 0.5) and p.y < R + RIM_H:
				b["lost"] = true
				pop("Elle roule !", to_global(_tray_top() + p + Vector3(0, 0.05, 0)), Color("#F7C9A0"), 22)
				sfx(["dango_lost", "putdown"], to_global(_tray_top() + p), -12.0)
			if supported:
				v *= exp(-3.0 * dt)                     # le mochi accroche : il roule mais s'arrête vite
				if not b["landed"]:
					b["landed"] = true
					sfx(["dango_land", "putdown"], to_global(_tray_top() + p), -20.0)
			b["p"] = p
			b["v"] = v
			b["sup"] = supported
		for b in _balls:
			if not b["stuck"]:
				_place_ball(b, dt)
	for b in _balls:
		if b["stuck"]:
			continue
		if b["sup"] and (b["v"] as Vector3).length() < 0.02:
			b["rest"] = float(b["rest"]) + delta
			if float(b["rest"]) > STICK_T:
				_stick(b)
		else:
			b["rest"] = 0.0

func _stick(b: Dictionary) -> void:
	b["stuck"] = true
	b["v"] = Vector3.ZERO
	if b["lost"]:
		return
	var layer := _layer_of((b["p"] as Vector3).y)
	if layer >= 1:
		pop("%de étage" % (layer + 1), to_global(_tray_top() + (b["p"] as Vector3) + Vector3(0, 0.05, 0)), Color("#FFE9B8"), 20)
		sfx(["tick"], null, -16.0)

func _place_ball(b: Dictionary, dt: float) -> void:
	var node: Node3D = b["node"]
	node.position = _tray_top() + (b["p"] as Vector3)
	var v: Vector3 = b["v"]
	var hv := Vector3(v.x, 0, v.z)
	if hv.length() > 0.001 and b["sup"]:
		var axis := Vector3.UP.cross(hv).normalized()
		node.rotate(axis, hv.length() * dt / R)

## Étage d'une boulette d'après sa hauteur au-dessus du plateau (pyramide idéale : R, 2,4 R, 3,8 R ; un peu
## de marge, car un carré mal serré fait s'enfoncer les étages du dessus).
func _layer_of(y: float) -> int:
	if y < R * 1.6:
		return 0
	if y < R * 3.0:
		return 1
	if y < R * 4.4:
		return 2
	return 3

func _count_on_tray() -> int:
	var n := 0
	for b in _balls:
		if b["stuck"] and not b["lost"]:
			n += 1
	return n

func _finish_later() -> void:
	await get_tree().create_timer(0.8).timeout
	if not playing:
		return
	var layers := [0, 0, 0, 0]
	for b in _balls:
		if b["stuck"] and not b["lost"]:
			layers[_layer_of((b["p"] as Vector3).y)] += 1
	var on := _count_on_tray()
	var height := 0
	for k in 4:
		if layers[k] > 0:
			height = k + 1
	var perfect: bool = layers[0] == 9 and layers[1] == 4 and layers[2] == 1
	_result = {"perfect": perfect, "height": height, "layers": layers}
	var line := "Une pyramide parfaite pour la lune !" if perfect else "%d dango sur le plateau, %d étage%s." % [on, height, "s" if height > 1 else ""]
	var prizes := {}
	if perfect:
		prizes["dango"] = 2
	elif on >= 9 and height >= 2:
		prizes["dango"] = 1
	if perfect:
		game.hud.pulse()
		sfx(["task_done"], null, -4.0)
	end_round(on, line, prizes)

func host_line(score: int) -> String:
	if _result.get("perfect", false):
		return "Une vraie pyramide pour la lune... Mon mari aurait été fier de toi."
	if score < 5:
		return "Oh là là, elles roulent comme des billes ! Mon mari aussi, la première fois."
	if score < 9:
		return "C'est un bon début. Serre bien le premier carré, le reste suit."
	return "Comme c'est joli. Elles tiennent bien droit."

# ---------------------------------------------------------------- test
## Position idéale (pyramide 3-2-1) de la n-ième boulette, en coordonnées du plateau.
func _slot(n: int) -> Vector3:
	var s := R * 2.04
	if n < 9:
		return Vector3((n % 3 - 1) * s, R, (n / 3 - 1) * s)
	if n < 13:
		var k := n - 9
		return Vector3((k % 2 - 0.5) * s, R + R * 1.414, (k / 2 - 0.5) * s)
	return Vector3(0, R + R * 2.828, 0)

## Test : pose les quatorze boulettes à leur place idéale.
func autoplay_round() -> String:
	for n in COUNT:
		while _held == null:
			await get_tree().physics_frame
		var sl := _slot(n)
		_hand = Vector2(sl.x, sl.z)
		for i in 8:
			await get_tree().physics_frame
		_hand_prev = Vector2(sl.x, sl.z)
		_hand_vel = Vector2.ZERO
		_drop()
		await get_tree().create_timer(0.9).timeout
	await get_tree().create_timer(2.5).timeout
	return "%d sur le plateau, étages %s" % [_count_on_tray(), str(_result.get("layers", []))]

## Capture : sept boulettes déjà posées.
func debug_pose() -> void:
	for n in 7:
		while _held == null:
			await get_tree().physics_frame
		var sl := _slot(n)
		_hand = Vector2(sl.x, sl.z)
		for i in 4:
			await get_tree().physics_frame
		_hand_prev = Vector2(sl.x, sl.z)
		_hand_vel = Vector2.ZERO
		_drop()
		await get_tree().create_timer(0.7).timeout
	_hand = Vector2(0.01, 0.02)
	await get_tree().create_timer(0.6).timeout
