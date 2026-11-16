class_name Ambience
extends Node
## Ambiance sonore : fonds de forêt selon le moment du jour, forêt profonde hors de l'enceinte, vent qui suit
## les bourrasques, ruisseau et cascade qui suivent le joueur le long du cours d'eau, gouttes au bassin des
## ablutions, pics-verts lointains de temps en temps, insectes des herbes sèches dans la prairie du belvédère.
## Dans le salon de thé, le dehors s'étouffe et l'on entend le calme d'une pièce. Les fichiers viennent de assets/sounds/amb_*.mp3
## (tools/convert_sounds.py) ; chaque boucle est jouée sur deux lecteurs qui se relaient en fondu croisé
## (les extraits ont des fondus de 2,5 s à chaque bout), on n'entend donc jamais de raccord.
## Pendant un dialogue, tout baisse un peu.

const DIR := "res://assets/sounds/"
const XF := 2.5                      # recouvrement entre deux passages d'une boucle (s)
const SILENT := -60.0

var game: Node3D
var _beds: Dictionary = {}           # nom -> Bed
var _t := 0.0
var _sprinkle := 40.0
var _streams: Array = []             # échantillons du ruisseau [Vector3, chute]
var _rng := RandomNumberGenerator.new()
var _tea: Node3D                     # salon de thé (intérieur : dehors étouffé, calme de la pièce)
var _in := 0.0                       # 0 dehors, 1 dedans (glisse doucement)
const MEADOW := Rect2(-3.0, -93.0, 35.0, 40.0)   # prairie dégagée devant le belvédère (comme Forest._view_clear)

## Une boucle : deux lecteurs (2D ou 3D) qui se relaient, volume qui glisse vers une cible.
class Bed:
	const XF := 2.5
	const SILENT := -60.0
	var players: Array = []
	var cur := 0
	var stream: AudioStream
	var vol := -60.0
	var target := -60.0
	var length := 0.0

	func _init(parent: Node, s: AudioStream, positional: bool, unit := 6.0, max_d := 70.0) -> void:
		stream = s
		length = s.get_length()
		for i in 2:
			var p: Node
			if positional:
				var p3 := AudioStreamPlayer3D.new()
				p3.unit_size = unit
				p3.max_distance = max_d
				p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
				p = p3
			else:
				p = AudioStreamPlayer.new()
			p.set("stream", s)
			p.set("volume_db", SILENT)
			p.set("bus", &"Ambiance")
			parent.add_child(p)
			players.append(p)

	func step(delta: float, rate: float, duck: float) -> void:
		vol = move_toward(vol, target, rate * delta)
		var audible := vol > SILENT + 1.0
		var a: Node = players[cur]
		if audible and not a.get("playing"):
			a.call("play", randf() * maxf(length - 2.0 * XF, 0.0))   # départ au hasard dans la boucle
		if not audible:
			for p in players:
				if p.get("playing"):
					p.call("stop")
			return
		# relais avant la fin : l'autre lecteur repart du début, les fondus intégrés font le fondu croisé
		if a.get("playing") and float(a.call("get_playback_position")) >= length - XF:
			cur = 1 - cur
			(players[cur] as Node).call("play", 0.0)
		for p in players:
			p.set("volume_db", vol + duck)

	func place(pos: Vector3) -> void:
		for p in players:
			if p is AudioStreamPlayer3D:
				(p as AudioStreamPlayer3D).global_position = pos

func setup(g: Node3D) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS     # l'ambiance continue, plus douce, dans le menu pause
	_rng.randomize()
	for n in ["amb_morning", "amb_day", "amb_day_b", "amb_evening", "amb_night", "amb_forest", "amb_wind"]:
		_add(n, false)
	_add("amb_stream", true, 7.0, 60.0)
	_add("amb_falls", true, 9.0, 80.0)
	_add("basin_drips", true, 1.2, 12.0)
	_add("amb_room", false)
	_add("amb_meadow", false)
	_tea = game.props.get_node_or_null("TeaHouse")
	for smp in Terrain.stream_samples():
		var p2: Vector2 = smp[0]
		_streams.append([Vector3(p2.x, float(smp[2]) + 0.2, p2.y), bool(smp[4])])
	var basin: Node3D = game.props.get_node_or_null("WaterBasin")
	if basin and _beds.has("basin_drips"):
		(_beds["basin_drips"] as Bed).place(basin.global_position + Vector3(0, 0.8, 0))

## Le joueur est-il dans le salon de thé (plancher surélevé, entre les murs) ?
func _indoors(p: Vector3) -> bool:
	if _tea == null:
		return false
	var l := _tea.to_local(p)
	return absf(l.x) < 3.5 and l.z > -3.0 and l.z < 1.6 and l.y > 0.3

func _add(n: String, positional: bool, unit := 6.0, max_d := 70.0) -> void:
	for ext in [".mp3", ".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + n + ext):
			var s: AudioStream = load(DIR + n + ext)
			_beds[n] = Bed.new(self, s, positional, unit, max_d)
			return

func _vol(n: String, db: float) -> void:
	if _beds.has(n):
		(_beds[n] as Bed).target = db

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_t += delta
	var p: Vector3 = game.player.global_position
	var ph := GameState.phase
	# 1. fond selon le moment du jour (jour pair / impair : deux chants d'oiseaux différents l'après-midi)
	var bed := "amb_morning"
	match ph:
		GameState.Phase.VISIT:
			bed = "amb_day" if GameState.day % 2 == 1 else "amb_day_b"
		GameState.Phase.EVENING:
			bed = "amb_evening"
		GameState.Phase.NIGHT:
			bed = "amb_night"
	# 2. hors de l'enceinte, la forêt prend le dessus
	var outside := clampf(Terrain.rect_dist(p.x, p.z) / 14.0, 0.0, 1.0)
	for n in ["amb_morning", "amb_day", "amb_day_b", "amb_evening", "amb_night"]:
		_vol(n, (-14.0 - 5.0 * outside) if n == bed else SILENT)
	_vol("amb_forest", lerpf(-30.0, -15.0, outside) - (8.0 if ph == GameState.Phase.NIGHT else 0.0))
	# 3. le vent suit les bourrasques de l'atmosphère
	var ws: float = game.atmosphere.wind_strength if game.atmosphere else 1.0
	_vol("amb_wind", clampf(-30.0 + 9.0 * ws, -32.0, -10.0))
	# 4. le ruisseau et la cascade : émetteurs posés au point le plus proche du cours d'eau
	if int(_t * 4.0) != int((_t - delta) * 4.0):
		var near := _nearest(p, false)
		var fall := _nearest(p, true)
		if _beds.has("amb_stream") and near != Vector3.INF:
			(_beds["amb_stream"] as Bed).place(near)
		if _beds.has("amb_falls") and fall != Vector3.INF:
			(_beds["amb_falls"] as Bed).place(fall)
	_vol("amb_stream", -6.0)
	_vol("amb_falls", -8.0)
	_vol("basin_drips", -10.0 if ph != GameState.Phase.NIGHT else -16.0)
	# 5. prairie du belvédère : insectes des herbes sèches l'après-midi et le soir
	var md := Vector2(maxf(maxf(MEADOW.position.x - p.x, p.x - MEADOW.end.x), 0.0), maxf(maxf(MEADOW.position.y - p.z, p.z - MEADOW.end.y), 0.0)).length()
	var mf := 1.0 - clampf(md / 18.0, 0.0, 1.0)
	var insects := ph == GameState.Phase.VISIT or ph == GameState.Phase.EVENING
	_vol("amb_meadow", lerpf(-40.0, -15.0, mf) if insects and mf > 0.0 else SILENT)
	# 6. dans le salon de thé : le dehors s'étouffe, le calme de la pièce monte
	_in = move_toward(_in, 1.0 if _indoors(p) else 0.0, delta * 1.2)
	if _in > 0.0:
		for n in _beds:
			if n != "amb_room":
				var b: Bed = _beds[n]
				if b.target > SILENT:
					b.target -= 11.0 * _in
	_vol("amb_room", lerpf(-34.0, -17.0, _in) if _in > 0.01 else SILENT)
	# 7. pendant un dialogue, l'ambiance baisse ; la nuit, tout est plus calme
	var duck := -7.0 if game.vn.visible else 0.0
	if get_tree().paused:
		duck = -9.0
	for n in _beds:
		(_beds[n] as Bed).step(delta, 10.0, duck)
	# 6. pics-verts au loin, de jour
	_sprinkle -= delta
	if _sprinkle <= 0.0:
		_sprinkle = _rng.randf_range(60.0, 140.0)
		if ph == GameState.Phase.MORNING or ph == GameState.Phase.VISIT:
			var a := _rng.randf() * TAU
			Sfx.play(&"woodpecker", p + Vector3(cos(a), 0.0, sin(a)) * 22.0 + Vector3(0, 6, 0), -4.0)

func _nearest(p: Vector3, falls_only: bool) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for s in _streams:
		if falls_only and not s[1]:
			continue
		var d := (s[0] as Vector3).distance_squared_to(p)
		if d < bd:
			bd = d
			best = s[0]
	return best

## Rapport de test : godot --path . -- --soundtest
func report() -> void:
	await get_tree().create_timer(4.0).timeout
	var files := PackedStringArray()
	for k in Sfx._bank:
		var l: Array = Sfx._bank[k]
		if not l.is_empty() and not (l[0] is AudioStreamWAV and (l[0] as AudioStreamWAV).resource_path == ""):
			files.append(String(k))
	files.sort()
	print("SOUND fichiers (%d) : %s" % [files.size(), ", ".join(files)])
	for n in _beds:
		var b: Bed = _beds[n]
		var playing := false
		for p in b.players:
			playing = playing or bool(p.get("playing"))
		print("SOUND %-12s %s  %.0f dB  (boucle %.0f s)" % [n, "joue" if playing else "  - ", b.vol, b.length])
	get_tree().quit()
