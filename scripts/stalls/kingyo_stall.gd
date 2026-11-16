extends StallGame
## 金魚すくい : la pêche aux poissons rouges, au stand de Hina.
##
## Accroupi devant le bac. La souris promène l'épuisette (poi) au-dessus de l'eau ; clic maintenu : on la plonge ;
## relâcher : on la relève, avec les poissons qui se trouvent juste au-dessus du papier.
## Le papier est tout le jeu :
##  - il boit l'eau (plus il reste dans l'eau, plus il est fragile) ;
##  - le remuer vite sous l'eau le déchire, et fait fuir les poissons ;
##  - chaque poisson soulevé pèse (le demekin noir est lourd ; plusieurs d'un coup, c'est risqué) ;
##  - immobile sous l'eau, il intrigue les poissons qui s'en approchent... pendant qu'il se mouille.
## Un poisson ne se laisse prendre que s'il nage près de la surface (on le voit plus net) : attendre qu'il remonte.
## La manche s'arrête quand le papier cède.

const TUB := Vector3(0.0, 0.0, 0.85)       # centre du bac (repère du stand)
const HALF := Vector2(0.64, 0.36)           # demi-dimensions utiles de l'eau
const LEVEL := 0.24                         # hauteur de l'eau dans le bac
const POI_R := 0.046                        # rayon du papier
const UP_H := 0.04                          # épuisette levée : au-dessus de l'eau
const DIP_H := -0.032                       # plongée : le papier sous la surface
const SENS := 0.0011                        # m par pixel de souris
const WET_TIME := 6.0                       # secondes dans l'eau pour être trempé
const DRAG_K := 2.4                         # dégâts en remuant sous l'eau
const LIFT_K := 0.17                        # dégâts par poisson soulevé
const CATCH_DEPTH := 0.048                  # un poisson plus profond passe sous le papier
const ROBES := {
	"aka": {"weight": 1.0, "speed": 1.0, "shy": 1.0, "points": 1},
	"sarasa": {"weight": 1.0, "speed": 1.05, "shy": 1.0, "points": 1},
	"kuro": {"weight": 1.75, "speed": 0.7, "shy": 0.7, "points": 1},
	"kin": {"weight": 0.85, "speed": 1.45, "shy": 1.5, "points": 1},
}
const SCHOOL := ["aka", "aka", "aka", "aka", "aka", "aka", "aka", "sarasa", "sarasa", "sarasa", "kuro", "kuro", "kin"]

var fish: Array = []          # {node, robe, pos, dir, speed, depth, depth_to, target, tail, phase, flee, curious, state}
var caught := 0
var caught_robes: Dictionary = {}
var _tub: Node3D
var _water: MeshInstance3D
var _poi: Node3D
var _paper: MeshInstance3D
var _paper_mat: ShaderMaterial
var _bowl: Node3D
var _poi_pos := Vector2(0.0, 0.18)
var _poi_target := Vector2(0.0, 0.18)
var _poi_h := UP_H
var _poi_speed := 0.0
var _wet := 0.0
var _damage := 0.0
var _torn := false
var _still_t := 0.0
var _warned := false
var _rng := RandomNumberGenerator.new()
var _water_mat: ShaderMaterial
var _ripples: Array = []      # [Vector2 monde xz, âge, force]
var _in_bowl: Array = []

func _init() -> void:
	id = "kingyo"
	title = "Pêche aux poissons rouges"
	kanji = "金魚"
	host = "fillette"
	booth = "yatai_kingyo"
	unit = "poisson"
	rules = PackedStringArray([
		"Plongez l'épuisette sous un poisson et relevez-la : il saute dans le bol.",
		"Le papier se mouille et se déchire : ne le remuez pas trop vite sous l'eau.",
		"Seuls les poissons proches de la surface se laissent prendre. Le noir est lourd ; le doré, farouche.",
	])
	controls = "souris : déplacer l'épuisette   ·   clic maintenu : plonger   ·   relâcher : relever"

func _build() -> void:
	_rng.randomize()
	_tub = ToolModels.glb("kingyo_tub")
	if _tub == null:
		_tub = Node3D.new()
		ToolModels.box(_tub, Vector3(1.4, 0.3, 0.84), Color("#7FB6CC"), Vector3(0, 0.15, 0))
	_tub.position = TUB
	add_child(_tub)
	# eau claire : les poissons profonds se fondent dans le bleu ; ondes là où l'on touche l'eau
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/tub_water.gdshader")
	var wm := _water_mat
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.34, 0.78)
	_water.mesh = pm
	_water.material_override = wm
	_water.position = TUB + Vector3(0, LEVEL, 0)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)
	# bol flottant, à gauche
	_bowl = ToolModels.glb("kingyo_bowl")
	if _bowl == null:
		_bowl = Node3D.new()
		ToolModels.cyl(_bowl, 0.06, 0.05, Color.WHITE, Vector3(0, 0.025, 0))
	_bowl.position = _bowl_home()
	add_child(_bowl)
	# épuisette
	_poi = Node3D.new()
	add_child(_poi)
	var frame := ToolModels.glb("poi")
	if frame != null:
		frame.rotation_degrees.y = 180.0        # manche vers le joueur
		_poi.add_child(frame)
	_paper = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(POI_R * 2.0, POI_R * 2.0)
	_paper.mesh = q
	_paper_mat = ShaderMaterial.new()
	_paper_mat.shader = load("res://shaders/poi_paper.gdshader")
	_paper.material_override = _paper_mat
	_paper.position = Vector3(0, -0.001, 0)
	_paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_poi.add_child(_paper)
	_poi.visible = false
	_fill_tub()

func area_size() -> Vector3:
	return Vector3(1.5, 0.7, 0.95)

func area_offset() -> Vector3:
	return TUB + Vector3(0, 0.3, 0)

func _bowl_home() -> Vector3:
	return TUB + Vector3(-0.47, LEVEL - 0.03, 0.2)

func view() -> Dictionary:
	var p := to_global(TUB + Vector3(0, 0, 0.62))
	return {"pos": p, "yaw": rotation_degrees.y, "pitch": -50.0, "crouch": 0.82, "fov": 58.0}

# ---------------------------------------------------------------- poissons
func _fill_tub() -> void:
	for f in fish:
		if is_instance_valid(f["node"]):
			(f["node"] as Node3D).queue_free()
	fish.clear()
	for f in _in_bowl:
		if is_instance_valid(f["node"]):
			(f["node"] as Node3D).queue_free()
	_in_bowl.clear()
	for robe in SCHOOL:
		_spawn(String(robe))

func _spawn(robe: String) -> void:
	var root := Node3D.new()
	add_child(root)
	var m := ToolModels.glb("kingyo_" + robe)
	if m == null:
		m = Node3D.new()
		ToolModels.ball(m, 0.02, Color("#E2552A"), Vector3.ZERO, Vector3(0.8, 0.8, 2.0))
	var s := _rng.randf_range(0.85, 1.12) * (1.12 if robe == "kuro" else 1.0)
	m.scale = Vector3.ONE * s
	root.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f := {"node": root, "robe": robe, "pos": Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.28, 0.28)),
		"dir": _rng.randf() * TAU, "speed": 0.06, "depth": _rng.randf_range(0.03, 0.1), "depth_to": 0.06,
		"target": _wander(), "tail": m.get_node_or_null("tail"), "phase": _rng.randf() * TAU, "flee": 0.0,
		"curious": 0.0, "state": "swim", "t": _rng.randf_range(0.0, 3.0), "size": s}
	fish.append(f)
	_place_fish(f)

func _wander() -> Vector2:
	return Vector2(_rng.randf_range(-HALF.x + 0.08, HALF.x - 0.08), _rng.randf_range(-HALF.y + 0.07, HALF.y - 0.07))

func _place_fish(f: Dictionary) -> void:
	var n: Node3D = f["node"]
	var p: Vector2 = f["pos"]
	n.position = TUB + Vector3(p.x, LEVEL - float(f["depth"]), p.y)
	n.rotation.y = float(f["dir"])

func _swim(delta: float) -> void:
	var poi_wet := _poi_h < -0.005 and not _torn
	for f in fish:
		if f["state"] != "swim":
			continue
		var rb: Dictionary = ROBES[f["robe"]]
		var p: Vector2 = f["pos"]
		f["t"] = float(f["t"]) - delta
		# nouvelle envie : un autre coin du bac, une autre profondeur
		if float(f["t"]) <= 0.0 or p.distance_to(f["target"]) < 0.05:
			f["target"] = _wander()
			f["t"] = _rng.randf_range(1.5, 4.5)
			f["depth_to"] = _rng.randf_range(0.02, 0.11)
			f["cruise"] = _rng.randf_range(0.03, 0.11) if _rng.randf() < 0.8 else 0.0
		var want_speed := float(f.get("cruise", 0.06)) * float(rb["speed"])
		var to_poi := p - _poi_pos
		var d_poi := to_poi.length()
		# fuite : l'épuisette qui fouette l'eau tout près
		if poi_wet and _poi_speed > 0.16 and d_poi < 0.2 * float(rb["shy"]):
			f["flee"] = 0.7
			f["target"] = (p + to_poi.normalized() * 0.4).clamp(-HALF + Vector2(0.06, 0.06), HALF - Vector2(0.06, 0.06))
			f["depth_to"] = 0.1
		# curiosité : une épuisette immobile sous l'eau attire les poissons proches
		elif poi_wet and _still_t > 0.8 and d_poi < 0.32 and d_poi > 0.03 and float(f["flee"]) <= 0.0:
			f["curious"] = float(f["curious"]) + delta
			if float(f["curious"]) > 0.5 / float(rb["shy"]) and _rng.randf() < 0.02:
				f["target"] = _poi_pos + Vector2(_rng.randf_range(-0.02, 0.02), _rng.randf_range(-0.02, 0.02))
				f["depth_to"] = _rng.randf_range(0.015, 0.04)
				f["cruise"] = 0.035
				f["t"] = 2.5
		else:
			f["curious"] = maxf(0.0, float(f["curious"]) - delta)
		if float(f["flee"]) > 0.0:
			f["flee"] = float(f["flee"]) - delta
			want_speed = 0.38 * float(rb["speed"])
		# cap vers la cible, évitement des parois et des voisins
		var steer: Vector2 = (f["target"] as Vector2) - p
		for g in fish:
			if g == f or g["state"] != "swim":
				continue
			var dd: Vector2 = p - (g["pos"] as Vector2)
			if dd.length() < 0.055 and dd.length() > 0.0001:
				steer += dd.normalized() * 0.08
		if absf(p.x) > HALF.x - 0.07:
			steer.x -= signf(p.x) * 0.3
		if absf(p.y) > HALF.y - 0.06:
			steer.y -= signf(p.y) * 0.3
		var want_dir := atan2(steer.x, steer.y)
		var turn := 4.5 if float(f["flee"]) > 0.0 else 2.2
		f["dir"] = lerp_angle(float(f["dir"]), want_dir, 1.0 - exp(-turn * delta))
		f["speed"] = lerpf(float(f["speed"]), want_speed, 1.0 - exp(-3.0 * delta))
		var dir := Vector2(sin(float(f["dir"])), cos(float(f["dir"])))
		p += dir * float(f["speed"]) * delta
		p = p.clamp(-HALF + Vector2(0.04, 0.04), HALF - Vector2(0.04, 0.04))
		f["pos"] = p
		f["depth"] = move_toward(float(f["depth"]), float(f["depth_to"]), 0.025 * delta)
		f["phase"] = float(f["phase"]) + delta * (5.0 + float(f["speed"]) * 60.0)
		if f["tail"] != null:
			(f["tail"] as Node3D).rotation.y = sin(float(f["phase"])) * (0.25 + float(f["speed"]) * 2.0)
		_place_fish(f)
	# poissons déjà dans le bol : ils tournent en rond
	for k in _in_bowl.size():
		var b: Dictionary = _in_bowl[k]
		b["a"] = float(b["a"]) + delta * 1.4
		var a := float(b["a"])
		var n: Node3D = b["node"]
		n.position = _bowl.position + Vector3(cos(a) * 0.026, 0.022, sin(a) * 0.026)
		n.rotation.y = -a
		if b["tail"] != null:
			(b["tail"] as Node3D).rotation.y = sin(a * 6.0) * 0.4

# ---------------------------------------------------------------- manche
func _on_enter() -> void:
	_poi.visible = true

func _on_leave() -> void:
	_poi.visible = false

func _round_start() -> void:
	caught = 0
	caught_robes.clear()
	_wet = 0.0
	_damage = 0.0
	_torn = false
	_warned = false
	_poi_h = UP_H
	_poi_pos = Vector2(0.0, 0.18)
	_poi_target = _poi_pos
	_paper.visible = true
	_paper_mat.set_shader_parameter("seed", _rng.randf() * 10.0)
	_fill_tub()

func status() -> String:
	var paper := "intact"
	if _torn:
		paper = "déchiré"
	elif _damage > 0.7:
		paper = "en lambeaux"
	elif _damage > 0.4 or _wet > 0.75:
		paper = "fragile"
	elif _wet > 0.25:
		paper = "humide"
	return "Poissons : %d   ·   papier %s" % [caught, paper]

func _motion(rel: Vector2) -> void:
	if _torn:
		return
	_poi_target += Vector2(rel.x, rel.y) * SENS
	_poi_target = _poi_target.clamp(-HALF + Vector2(POI_R, POI_R), HALF - Vector2(POI_R * 0.6, POI_R * 0.6))

func _press() -> void:
	if _torn:
		return
	sfx(["plop"], to_global(TUB + Vector3(_poi_pos.x, LEVEL, _poi_pos.y)), -10.0)
	_ripple(_poi_pos, 0.6)
	_damage += 0.01 + 0.02 * _wet
	# l'épuisette qui tombe à côté d'un poisson le fait sursauter
	for f in fish:
		if f["state"] == "swim" and (f["pos"] as Vector2).distance_to(_poi_pos) < 0.09:
			f["flee"] = 0.35
			f["depth_to"] = float(f["depth"]) + 0.02

func _release() -> void:
	if _torn or _poi_h > -0.005:
		return
	_lift()

func _tick(delta: float) -> void:
	var prev := _poi_pos
	_poi_pos = _poi_pos.lerp(_poi_target, 1.0 - exp(-16.0 * delta))
	_poi_speed = prev.distance_to(_poi_pos) / maxf(delta, 0.0001)
	var want_h := DIP_H if holding() and not _torn else UP_H
	_poi_h = move_toward(_poi_h, want_h, delta * 0.55)
	var under := _poi_h < -0.005 and not _torn
	if under:
		_wet = minf(1.0, _wet + delta / WET_TIME)
		_damage += pow(maxf(0.0, _poi_speed - 0.12), 1.3) * DRAG_K * delta * (0.4 + _wet)
		_still_t = _still_t + delta if _poi_speed < 0.04 else 0.0
		if _poi_speed > 0.2 and _rng.randf() < delta * 10.0:
			_ripple(_poi_pos, 0.35)
	else:
		_still_t = 0.0
	if not _torn and _damage >= 1.0:
		_tear()
	if not _warned and _damage > 0.6 and not _torn:
		_warned = true
		pop("Le papier faiblit...", to_global(_poi.position), Color("#F5D9A8"), 26)
	# épuisette : position, inclinaison (le manche se relève quand on plonge), papier
	var tilt := remap(_poi_h, UP_H, DIP_H, 0.12, 0.28)
	_poi.position = TUB + Vector3(_poi_pos.x, LEVEL + _poi_h, _poi_pos.y)
	_poi.rotation = Vector3(-tilt, 0.0, (_poi_target.x - _poi_pos.x) * -3.0)
	_paper_mat.set_shader_parameter("wet", _wet)
	_paper_mat.set_shader_parameter("damage", minf(_damage, 1.2) if not _torn else 1.6)
	_swim(delta)
	_update_ripples(delta)
	refresh_status()

func _lift() -> void:
	var on := []
	for f in fish:
		if f["state"] != "swim":
			continue
		var d := (f["pos"] as Vector2).distance_to(_poi_pos)
		if d < POI_R * 0.95 + 0.012 * float(f["size"]) and float(f["depth"]) <= CATCH_DEPTH:
			on.append(f)
	if on.is_empty():
		return
	var load := 0.0
	for f in on:
		load += float(ROBES[f["robe"]]["weight"])
	var cost := load * LIFT_K * (0.5 + _wet) * (1.0 + _poi_speed * 1.5) * (1.0 + 0.25 * (on.size() - 1))
	cost += _rng.randf_range(0.0, 0.05) * on.size()        # ils se débattent
	if _damage + cost >= 1.0:
		# trop lourd : le papier cède, les poissons replongent
		for f in on:
			f["flee"] = 0.8
			f["depth_to"] = 0.1
		_tear()
		return
	_damage += cost
	for f in on:
		_catch(f)
	if on.size() > 1:
		pop("× %d !" % on.size(), to_global(_poi.position + Vector3(0, 0.08, 0)), Color("#FFE08A"), 40)

func _catch(f: Dictionary) -> void:
	f["state"] = "fly"
	caught += 1
	caught_robes[f["robe"]] = int(caught_robes.get(f["robe"], 0)) + 1
	var n: Node3D = f["node"]
	var from := n.position
	var to := _bowl.position + Vector3(0, 0.022, 0)
	var mid := (from + to) * 0.5 + Vector3(0, 0.16, 0)
	sfx(["plop"], to_global(from), -6.0)
	var label := "+1"
	if f["robe"] == "kin":
		label = "Le doré !"
	elif f["robe"] == "kuro":
		label = "Le demekin !"
	pop(label, to_global(from + Vector3(0, 0.06, 0)), Color("#FFE9B8") if f["robe"] != "kin" else Color("#FFD45A"))
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		n.position = a.lerp(b, t)
		n.rotation.z = sin(t * 18.0) * 0.6
		, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		n.rotation.z = 0.0
		n.scale = Vector3.ONE * 0.85
		f["state"] = "bowl"
		_in_bowl.append({"node": n, "a": _rng.randf() * TAU, "tail": f["tail"]})
		sfx(["drip", "plop"], to_global(to), -8.0)
		_bowl.position = _bowl_home() + Vector3(0, -0.006, 0)
		create_tween().tween_property(_bowl, "position", _bowl_home(), 0.4).set_trans(Tween.TRANS_BACK)
		hud_pulse())
	if fish.filter(func(g): return g["state"] == "swim").is_empty():
		await get_tree().create_timer(1.0).timeout
		if playing:
			end_round(caught, "Le bac est vide !", _prizes())

func hud_pulse() -> void:
	game.hud.pulse()

func _tear() -> void:
	if _torn:
		return
	_torn = true
	_damage = 1.2
	sfx(["paper_crumple", "paper"], to_global(_poi.position), -4.0)
	_ripple(_poi_pos, 1.0)
	pop("Le papier s'est déchiré !", to_global(_poi.position + Vector3(0, 0.1, 0)), Color("#F7C9A0"), 30)
	await get_tree().create_timer(1.6).timeout
	if playing:
		var line := "Le papier a tenu le temps de %d poisson%s." % [caught, "s" if caught > 1 else ""] if caught > 0 else "Le papier n'a pas tenu."
		end_round(caught, line, _prizes())

func _prizes() -> Dictionary:
	if caught <= 0:
		return {}
	return {"kingyo": 2 if caught >= 6 else 1}

## Petite onde à la surface (dessinée par le shader de l'eau).
func _ripple(p: Vector2, strength: float) -> void:
	var w := to_global(TUB + Vector3(p.x, LEVEL, p.y))
	_ripples.append([Vector2(w.x, w.z), 0.0, strength])
	if _ripples.size() > 6:
		_ripples.pop_front()

func _update_ripples(delta: float) -> void:
	var arr: Array[Vector4] = []
	for r in _ripples:
		r[1] = float(r[1]) + delta
	_ripples = _ripples.filter(func(r): return float(r[1]) < 1.6)
	for k in 6:
		if k < _ripples.size():
			var r: Array = _ripples[k]
			arr.append(Vector4((r[0] as Vector2).x, (r[0] as Vector2).y, float(r[1]), float(r[2])))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	_water_mat.set_shader_parameter("ripples", arr)

func host_line(score: int) -> String:
	if score <= 0:
		return "C'est pas grave ! Le papier, c'est traître. On recommence ?"
	if score <= 2:
		return "Tu en as eu un ! Regarde, il fait des ronds dans son bol."
	if score <= 5:
		return "Waouh ! Même grand-père n'en attrape pas autant."
	return "Tu vas vider le bac ! Le monsieur des poissons va pleurer !"

func _process(delta: float) -> void:
	if not playing and fish.size() > 0 and is_visible_in_tree():
		_swim(delta)        # le bac vit aussi quand on ne joue pas
		_update_ripples(delta)

# ---------------------------------------------------------------- test
## Test : place l'épuisette sous le poisson le plus proche de la surface et la relève.
func autoplay_scoop() -> bool:
	var best: Dictionary = {}
	for f in fish:
		if f["state"] == "swim" and (best.is_empty() or float(f["depth"]) < float(best["depth"])):
			best = f
	if best.is_empty():
		return false
	best["depth"] = 0.02
	_poi_pos = best["pos"]
	_poi_target = _poi_pos
	_poi_h = DIP_H
	_poi_speed = 0.0
	var before := caught
	_lift()
	return caught > before

## Capture d'écran : l'épuisette plongée près d'un poisson, papier un peu mouillé.
func debug_pose() -> void:
	var f: Dictionary = fish[0]
	_poi_target = (f["pos"] as Vector2) + Vector2(0.05, 0.04)
	_lmb = true
	_wet = 0.45
	_damage = 0.35
	await get_tree().create_timer(0.8).timeout
	if fish.size() > 3:
		autoplay_scoop()
	await get_tree().create_timer(0.25).timeout

## Test : plusieurs coups d'épuisette sous les poissons les plus hauts, jusqu'à ce que le papier cède.
func autoplay_round() -> int:
	var n := 0
	while playing and not _torn and n < 20:
		_wet = minf(1.0, _wet + 0.15)          # chaque plongée mouille le papier
		autoplay_scoop()
		n += 1
		await get_tree().create_timer(0.7).timeout
	await get_tree().create_timer(2.0).timeout
	return caught
