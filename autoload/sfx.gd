extends Node
## Autoload "Sfx" : tous les sons du jeu, synthétisés au lancement (aucun fichier audio).
## Le reste du code n'appelle que ces deux fonctions ; un nom inconnu est ignoré sans erreur.
##
##   Sfx.play(&"nom", position_ou_null, volume_db)   son ponctuel (3D si une position Vector3 est donnée)
##   Sfx.loop(&"nom", actif)                         son continu (pas encore de boucles : ignoré)
##
## Chaque son a plusieurs variantes tirées au hasard, et une petite variation de hauteur : on n'entend jamais
## deux fois exactement le même pas.
## Sons disponibles :
##   pas            step_gravel, step_stone, step_wood, step_earth
##   outils         pickup, putdown, snip, hammer, slash, leaves, sweep
##   rite, pièces   clap, coin
##   retour         task_done (tâche terminée), tick (une étape d'une tâche), ui_click
## Pas encore : ambiances (vent, ruisseau), boucles (balai, versement), eau, thé, corde.
##
## Vrais sons : déposer des fichiers dans assets/sounds/, nommés comme le son, avec ou sans numéro de variante
## (step_gravel.ogg, step_gravel_2.ogg, task_done.wav...). Formats : .ogg, .wav, .mp3. Ils remplacent alors
## le son synthétisé du même nom, et peuvent aussi en ajouter de nouveaux (n'importe quel nom appelé par le jeu).
const SOUND_DIR := "res://assets/sounds/"
## Volume de base (dB) des sons venus de fichiers (crête normalisée à -1 dB par tools/convert_sounds.py).
const FILE_GAIN := {
	"pickup": -8.0, "putdown": -7.0, "hammer": -5.0, "snip": -8.0, "slash": -6.0, "coin": -13.0,
	"bell": -5.0, "paper": -10.0, "paper_crumple": -10.0, "door_slide": -9.0, "cat": -8.0,
	"match_strike": -12.0, "plop": -12.0, "drip": -14.0, "water_draw": -9.0, "rope": -10.0, "tea": -12.0,
	"pour_loop": -10.0, "woodpecker": -6.0, "basin_drips": -6.0,
}
## Autres noms appelés par le jeu pour un même son (créature de la nuit « chat »...).
const ALIASES := {"chat": "cat", "flame": "match_strike"}

const RATE := 22050
const VARIANTS := 3

var _bank: Dictionary = {}          # nom -> Array[AudioStreamWAV]
var _gain: Dictionary = {}          # nom -> dB de base
var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _i2 := 0
var _i3 := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players_2d.append(p)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 40.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players_3d.append(p)
	_build()
	_load_files()

## Vrai si un son de ce nom existe (fichier ou synthèse).
func has(sound: StringName) -> bool:
	return _bank.has(StringName(ALIASES.get(String(sound), String(sound))))

func play(sound: StringName, at: Variant = null, volume_db: float = 0.0) -> void:
	sound = StringName(ALIASES.get(String(sound), String(sound)))
	var list: Array = _bank.get(sound, [])
	if list.is_empty():
		return
	var stream: AudioStream = list[_rng.randi() % list.size()]
	var vol: float = float(_gain.get(sound, 0.0)) + volume_db
	var pitch := _rng.randf_range(0.94, 1.06)
	if at is Vector3:
		var p := _players_3d[_i3]
		_i3 = (_i3 + 1) % _players_3d.size()
		if not p.is_inside_tree():
			return
		p.global_position = at
		p.stream = stream
		p.volume_db = vol
		p.pitch_scale = pitch
		p.play()
	else:
		var p2 := _players_2d[_i2]
		_i2 = (_i2 + 1) % _players_2d.size()
		p2.stream = stream
		p2.volume_db = vol
		p2.pitch_scale = pitch
		p2.play()

var _loops: Dictionary = {}    # nom -> {player, on}

## Son continu (versement d'eau...) : démarre ou s'arrête en fondu ; relancé à chaque fin tant qu'il est actif.
func loop(sound: StringName, on: bool) -> void:
	var list: Array = _bank.get(sound, [])
	if list.is_empty():
		return
	var l: Dictionary = _loops.get(sound, {})
	if l.is_empty():
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.stream = list[0]
		p.volume_db = -60.0
		l = {"player": p, "on": false}
		p.finished.connect(func(): if l["on"]: p.play())
		_loops[sound] = l
	if bool(l["on"]) == on:
		return
	l["on"] = on
	var pl: AudioStreamPlayer = l["player"]
	var tw := create_tween()
	if on:
		if not pl.playing:
			pl.play()
		tw.tween_property(pl, "volume_db", float(_gain.get(sound, 0.0)), 0.25)
	else:
		tw.tween_property(pl, "volume_db", -60.0, 0.4)
		tw.tween_callback(func(): if not l["on"]: pl.stop())

## Fichiers de assets/sounds/ : ils prennent la place des sons synthétisés du même nom.
func _load_files() -> void:
	var dir := DirAccess.open(SOUND_DIR)
	if dir == null:
		return
	var found := {}
	for f in dir.get_files():
		var fn := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := fn.get_extension().to_lower()
		if not ext in ["ogg", "wav", "mp3"]:
			continue
		var base := fn.get_basename()
		if base.begins_with("amb_"):
			continue                            # ambiances : gérées par scripts/ambience.gd
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			base = parts[0]                     # step_gravel_2 -> step_gravel
		var res := load(SOUND_DIR + fn)
		if res is AudioStream:
			if not found.has(base):
				found[base] = []
			if not (found[base] as Array).has(res):
				(found[base] as Array).append(res)
	for snd in found:
		_bank[StringName(snd)] = found[snd]
		_gain[StringName(snd)] = float(FILE_GAIN.get(snd, -8.0))

# ---------------------------------------------------------------- synthèse
func _build() -> void:
	_add(&"step_gravel", -13.0, _gravel_step)
	_add(&"step_stone", -12.0, _stone_step)
	_add(&"step_wood", -10.0, _wood_step)
	_add(&"step_earth", -15.0, _earth_step)
	_add(&"pickup", -9.0, func(v): return _knock(v, 520.0, 0.07, 0.5) )
	_add(&"putdown", -9.0, func(v): return _knock(v, 330.0, 0.09, 0.6))
	_add(&"tick", -12.0, func(v): return _knock(v, 1250.0, 0.05, 0.25))
	_add(&"ui_click", -14.0, func(v): return _knock(v, 1600.0, 0.03, 0.2))
	_add(&"task_done", -8.0, _chime)
	_add(&"coin", -11.0, _coin)
	_add(&"clap", -8.0, _clap)
	_add(&"snip", -10.0, _snip)
	_add(&"hammer", -6.0, _hammer)
	_add(&"slash", -10.0, _swoosh)
	_add(&"leaves", -14.0, _rustle)
	_add(&"sweep", -16.0, _rustle)

func _add(sound: StringName, gain: float, gen: Callable) -> void:
	var list: Array = []
	for v in VARIANTS:
		var data: PackedFloat32Array = gen.call(v)
		list.append(_to_wav(data))
	_bank[sound] = list
	_gain[sound] = gain

func _to_wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	var peak := 0.0001
	for x in data:
		peak = maxf(peak, absf(x))
	var g := 0.9 / peak
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

## Filtre passe-bande simple (biquad RBJ) appliqué en place.
func _bandpass(b: PackedFloat32Array, f: float, q: float) -> void:
	var w0 := TAU * f / RATE
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in b.size():
		var x := b[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		b[i] = y

func _lowpass(b: PackedFloat32Array, f: float) -> void:
	var k := 1.0 - exp(-TAU * f / RATE)
	var y := 0.0
	for i in b.size():
		y += (b[i] - y) * k
		b[i] = y

# ---- pas
## Gravier : une poignée de petits craquements serrés, plus un souffle sourd.
func _gravel_step(v: int) -> PackedFloat32Array:
	var b := _buf(0.2)
	var r := RandomNumberGenerator.new()
	r.seed = 100 + v
	var n := b.size()
	for g in 34 + v * 4:
		var at := int(pow(r.randf(), 1.6) * n * 0.75)
		var amp := r.randf_range(0.3, 1.0) * (1.0 - float(at) / n)
		var length := r.randi_range(20, 70)
		for k in length:
			if at + k < n:
				b[at + k] += r.randf_range(-1.0, 1.0) * amp * (1.0 - float(k) / length)
	_bandpass(b, 2600.0 + v * 300.0, 0.7)
	var body := _buf(0.2)
	for i in body.size():
		var t := float(i) / RATE
		body[i] = r.randf_range(-1.0, 1.0) * exp(-t * 30.0) * 0.6
	_lowpass(body, 500.0)
	for i in n:
		b[i] += body[i]
	return b

func _stone_step(v: int) -> PackedFloat32Array:
	var b := _buf(0.12)
	var r := RandomNumberGenerator.new()
	r.seed = 200 + v
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (95.0 + v * 12.0) * t) * exp(-t * 55.0) * 0.8 + r.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.5
	_lowpass(b, 1800.0)
	return b

func _wood_step(v: int) -> PackedFloat32Array:
	var b := _buf(0.16)
	var r := RandomNumberGenerator.new()
	r.seed = 300 + v
	var f1 := 150.0 + v * 15.0
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * f1 * t) * 0.9 + sin(TAU * f1 * 2.3 * t) * 0.35) * exp(-t * 32.0) \
			+ r.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.25
	_lowpass(b, 2200.0)
	return b

func _earth_step(v: int) -> PackedFloat32Array:
	var b := _buf(0.18)
	var r := RandomNumberGenerator.new()
	r.seed = 400 + v
	for i in b.size():
		var t := float(i) / RATE
		b[i] = r.randf_range(-1.0, 1.0) * (1.0 - exp(-t * 200.0)) * exp(-t * 22.0)
	_lowpass(b, 900.0 + v * 120.0)
	return b

# ---- objets, gestes
## Petit choc de bois : prise d'un outil, pose, étape franchie.
func _knock(v: int, f: float, dur: float, noise: float) -> PackedFloat32Array:
	var b := _buf(dur * 2.5)
	var r := RandomNumberGenerator.new()
	r.seed = 500 + v + int(f)
	var ff := f * (1.0 + v * 0.04)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * ff * t) * exp(-t / dur * 3.0) + r.randf_range(-1.0, 1.0) * exp(-t * 300.0) * noise
	return b

## Tâche terminée : clochette douce (rin), deux partiels inharmoniques qui s'éteignent lentement.
func _chime(v: int) -> PackedFloat32Array:
	var b := _buf(1.8)
	var f: float = [784.0, 880.0, 988.0][v % 3]
	for i in b.size():
		var t := float(i) / RATE
		var a := minf(t * 400.0, 1.0)
		b[i] = a * (sin(TAU * f * t) * exp(-t * 2.2) + 0.45 * sin(TAU * f * 2.76 * t) * exp(-t * 4.0)
			+ 0.2 * sin(TAU * f * 5.4 * t) * exp(-t * 7.0))
	return b

func _coin(v: int) -> PackedFloat32Array:
	var b := _buf(0.6)
	var f := 2100.0 + v * 140.0
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.62 * t) + 0.3 * sin(TAU * f * 2.41 * t)) * exp(-t * 9.0)
	return b

func _clap(v: int) -> PackedFloat32Array:
	var b := _buf(0.12)
	var r := RandomNumberGenerator.new()
	r.seed = 600 + v
	for i in b.size():
		var t := float(i) / RATE
		b[i] = r.randf_range(-1.0, 1.0) * exp(-t * 60.0)
	_bandpass(b, 1300.0 + v * 150.0, 1.1)
	return b

func _snip(v: int) -> PackedFloat32Array:
	var b := _buf(0.14)
	var r := RandomNumberGenerator.new()
	r.seed = 700 + v
	for i in b.size():
		var t := float(i) / RATE
		b[i] = r.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.8 + sin(TAU * (3100.0 + v * 200.0) * t) * exp(-t * 45.0) * 0.5
	_bandpass(b, 3800.0, 0.9)
	return b

func _hammer(v: int) -> PackedFloat32Array:
	var b := _buf(0.3)
	var r := RandomNumberGenerator.new()
	r.seed = 800 + v
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (170.0 + v * 20.0) * t) * exp(-t * 22.0) + r.randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.9 \
			+ sin(TAU * 1900.0 * t) * exp(-t * 60.0) * 0.35
	return b

func _swoosh(v: int) -> PackedFloat32Array:
	var b := _buf(0.28)
	var r := RandomNumberGenerator.new()
	r.seed = 900 + v
	var n := b.size()
	for i in n:
		var t := float(i) / n
		b[i] = r.randf_range(-1.0, 1.0) * sin(PI * t) * sin(PI * t)
	_bandpass(b, 1700.0 + v * 200.0, 0.8)
	return b

func _rustle(v: int) -> PackedFloat32Array:
	var b := _buf(0.35)
	var r := RandomNumberGenerator.new()
	r.seed = 1000 + v
	var n := b.size()
	for i in n:
		var t := float(i) / n
		var crackle := 1.0 if r.randf() < 0.18 else 0.35
		b[i] = r.randf_range(-1.0, 1.0) * crackle * sin(PI * t)
	_bandpass(b, 3200.0 + v * 400.0, 0.6)
	return b
