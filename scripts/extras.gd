class_name Extras
extends Node
## Activités facultatives qui allongent la journée et poussent à explorer la montagne :
## ema égarés, thé sur la véranda, renard roux, chat, lettres de l'ancien gardien, découvertes.

const TERRAIN := preload("res://scripts/terrain.gd")

const DISCOVERIES := {
	&"belvedere": [Vector2(14, -85), 8.0, "Le belvédère"],
	&"cabane": [Vector2(58, -16), 10.0, "La cabane de l'ancien gardien"],
	&"source": [Vector2(-62, 11), 8.0, "La source cachée"],
	&"renards": [Vector2(-10, -65), 7.0, "Le sanctuaire des renards"],
	&"etang": [Vector2(-15, -27), 6.0, "L'étang du sanctuaire"],
	&"jardin": [Vector2(-16, -11), 6.0, "Le jardin sec"],
}
const EMA_SPOTS := [
	Vector2(-4.5, -66.0), Vector2(4.0, -69.5), Vector2(11.0, -80.0), Vector2(-7.5, -52.5),
	Vector2(37.0, -9.5), Vector2(55.0, -18.5), Vector2(-37.0, 2.0), Vector2(-51.0, 9.5), Vector2(-59.0, 13.5),
	Vector2(-20.0, -6.0), Vector2(18.0, -30.0), Vector2(8.0, -30.0), Vector2(-21.0, 7.0), Vector2(22.0, 3.0),
]
const FOX_SPOTS := [Vector2(-8.5, -59.0), Vector2(31.0, -10.0), Vector2(-41.0, 8.5), Vector2(6.0, -75.0), Vector2(51.0, -9.0)]
const LETTERS := [
	"À celui ou celle qui reprendra ce lieu,\n\nLes marches sont longues et les feuilles ne cesseront jamais de tomber. C'est bien ainsi. Balayer, c'est dire au sanctuaire qu'on pense encore à lui.\n\n— Seiji",
	"Tu auras remarqué les visiteurs. Ils montent chargés de choses qu'ils ne diront à personne d'autre.\n\nÉcoute-les sans leur donner de conseils. Parfois, une cloche suffit.\n\n— S.",
	"Si tu lis ceci, c'est que tu es resté jusqu'à l'automne suivant. J'ai laissé du thé sur la véranda : il est meilleur quand personne n'est pressé.\n\nMerci d'avoir pris soin de la montagne.\n\n— Seiji",
]
const TEA_LINES := [
	"Le thé est tiède, un peu amer. Les feuilles tombent, une à une, sans bruit.",
	"Une corneille traverse le ciel. Le temps s'étire.",
	"La vapeur monte dans la lumière. Vous ne pensez plus à rien.",
]

var game: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var props: Node3D
var found: Dictionary = {}
var letters_read := 0
var _letter_day := 0
var ema_nodes: Array = []
var hung: Array = []
var ema_held := 0
var fox: Node3D
var fox_hinted := false
var fox_done := false
var cat_pets := 0
var door: Node3D
var door_open := false
var tea_ceremony: Node
var visitor_ema: Array = []     # ema accrochés par les visiteurs : {node, character}

func setup(g: Node3D) -> void:
	game = g
	player = g.player
	hud = g.hud
	props = g.props
	_setup_tea()
	_setup_cat()
	_setup_cabin()
	_setup_ema_rack()

func _process(_dt: float) -> void:
	if player == null or not player.input_enabled:
		return
	var p := player.global_position
	for k in DISCOVERIES:
		if found.has(k):
			continue
		var d: Array = DISCOVERIES[k]
		if Vector2(p.x, p.z).distance_to(d[0]) < float(d[1]):
			found[k] = true
			GameState.add_progress(&"decouvertes")
			Events.toast.emit("Découverte : %s" % d[2])
			GameState.note("Découvert : %s." % d[2])
			if found.size() == DISCOVERIES.size():
				GameState.set_flag(&"montagne_connue")
				Events.toast.emit("Vous connaissez maintenant chaque recoin de la montagne.")
	_update_fox(p)

# ---------------------------------------------------------------- début de journée
func on_day_start() -> void:
	GameState.set_target(&"ema", 3)
	GameState.set_target(&"the", 1)
	GameState.set_target(&"renard", 1)
	GameState.set_target(&"decouvertes", DISCOVERIES.size())
	GameState.add_progress(&"decouvertes", found.size())
	ema_held = 0
	if GameState.ema_log.is_empty():   # nouvelle partie : le présentoir se vide
		for v in visitor_ema:
			if is_instance_valid(v["node"]):
				v["node"].queue_free()
		visitor_ema.clear()
	refresh_visitor_ema()
	for n in ema_nodes:
		if is_instance_valid(n):
			n.queue_free()
	ema_nodes.clear()
	for n in hung:
		if is_instance_valid(n):
			n.queue_free()
	hung.clear()
	door_open = false
	_spawn_ema()
	_spawn_fox()
	if GameState.day == 1:
		Events.toast.emit("Des ema se sont envolés dans la nuit : cherchez les halos dorés sur les sentiers.")

# ---------------------------------------------------------------- ema égarés
func _setup_ema_rack() -> void:
	var rack: Node3D = props.get_node_or_null("EmaRack")
	if rack == null:
		return
	game._make(rack, Vector3(1.6, 1.8, 1.2), Vector3(0, 0.9, 0.2),
		func() -> String:
			if ema_held > 0:
				return "E : Raccrocher l'ema"
			return "E : Lire les ema",
		func(_p):
			if ema_held > 0:
				_hang_ema(rack)
			else:
				_read_board())

## Mur des ema : une carte par personnage rencontré (vœux, affection, état du lien).
func _read_board() -> void:
	player.input_enabled = false
	await hud.show_ema_board(_board_data())
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _board_data() -> Array:
	var out := []
	for c in Story.data.get("characters", []):
		var who := String(c.get("id", ""))
		if bool(c.get("animal", false)):
			continue   # les animaux n'accrochent pas d'ema
		var wishes := []
		for e in GameState.ema_log:
			if e["character"] == who:
				wishes.append(e)
		out.append({
			"id": who, "name": String(c.get("name", who)), "color": Story.color_of(who),
			"met": GameState.met.get(who, false), "affection": int(GameState.affection.get(who, 0)),
			"max": Story.affection_max(who), "state": GameState.ema_state(who), "wishes": wishes,
			"missed": int(GameState.missed.get(who, 0)),
			"tastes": _tastes(who),
		})
	return out

## Goûts découverts en offrant des cadeaux, par palier : « Adore : Kaki · N'aime pas : Galet ».
func _tastes(who: String) -> String:
	var known: Dictionary = GameState.gift_known.get(who, {})
	var parts := PackedStringArray()
	for tier in ["love", "like", "dislike"]:
		var names := PackedStringArray()
		for id in known:
			if known[id] == tier:
				names.append(Story.item_name(id))
		if not names.is_empty():
			parts.append("%s : %s" % [String(Story.GIFT_TIER_NAMES[tier]).capitalize(), ", ".join(names)])
	return " · ".join(parts)

## Ema accroché par un visiteur en partant : il reste au présentoir et s'abîme avec le lien.
func hang_visitor_ema(who: String) -> void:
	var rack: Node3D = props.get_node_or_null("EmaRack")
	if rack == null:
		return
	var i := visitor_ema.size()
	var e: Node3D = game._model("ema_loose", Color("#A87B4F"))
	rack.add_child(e)
	var slot: Node3D = rack.find_child("ema_slot_0%d" % (1 + i % 8), true, false)
	if slot:
		e.transform = slot.transform
		var row := int(i / 8.0)
		e.position += Vector3(0.05 * row, -0.04 * row, 0.02 + 0.01 * row)
	else:
		e.position = Vector3(-0.5 + 0.15 * (i % 8), 1.3 - 0.2 * int(i / 8.0), 0.05)
	e.rotation.z += randf_range(-0.12, 0.12)
	e.set_meta("base_rot", e.rotation)
	visitor_ema.append({"node": e, "character": who})
	refresh_visitor_ema()

## Les ema suivent l'état du lien : penchés quand il se fissure, tombés quand il est brisé.
func refresh_visitor_ema() -> void:
	for v in visitor_ema:
		var n: Node3D = v["node"]
		if not is_instance_valid(n):
			continue
		var st := GameState.ema_state(String(v["character"]))
		n.visible = st < 3
		var r: Vector3 = n.get_meta("base_rot", n.rotation)
		n.rotation = r + Vector3(0, 0, 0.35 if st >= 2 else 0.0)

func _spawn_ema() -> void:
	var spots := EMA_SPOTS.duplicate()
	spots.shuffle()
	for i in 3:
		var sp: Vector2 = spots[i]
		var y := TERRAIN.height(sp.x, sp.y)
		var root := Node3D.new()
		root.position = Vector3(sp.x, y, sp.y)
		props.add_child(root)
		var m: Node3D = game._model("ema_loose", Color("#A87B4F"))
		m.scale = Vector3.ONE * 2.2
		m.rotation_degrees = Vector3(0, randf() * 360.0, 0)
		root.add_child(m)
		# halo doré pour repérer l'ema de loin
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.28
		cm.height = 2.2
		beam.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.82, 0.4, 0.3)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = mat
		beam.position.y = 1.1
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(beam)
		var r := root
		game._make(root, Vector3(0.8, 0.6, 0.8), Vector3(0, 0.2, 0),
			func() -> String: return "E : Ramasser l'ema égaré",
			func(_p):
				ema_held += 1
				ema_nodes.erase(r)
				r.queue_free()
				Events.toast.emit("Un ema trouvé. Rapportez-le au présentoir.")
		)
		ema_nodes.append(root)

func _hang_ema(rack: Node3D) -> void:
	ema_held -= 1
	var slot: Node3D = rack.find_child("ema_slot_0%d" % (7 + mini(hung.size(), 1)), true, false)
	var e: Node3D = game._model("ema_loose", Color("#A87B4F"))
	rack.add_child(e)
	if slot:
		e.transform = slot.transform
	else:
		e.position = Vector3(0.3 - 0.2 * hung.size(), 1.2, 0.0)
	if hung.size() >= 2:
		e.position += Vector3(0.0, -0.18, 0.02)
	hung.append(e)
	GameState.add_progress(&"ema")
	Events.toast.emit("L'ema est accroché au présentoir.")
	GameState.note("Un ema égaré a retrouvé sa place.")

# ---------------------------------------------------------------- thé
func _setup_tea() -> void:
	var tea: Node3D = props.find_child("TeaSet", true, false)
	if tea == null:
		return
	tea_ceremony = preload("res://scripts/tea_ceremony.gd").new()
	tea_ceremony.name = "TeaCeremony"
	add_child(tea_ceremony)
	tea_ceremony.setup(game, tea)
	game._make(tea, Vector3(0.7, 0.5, 0.6), Vector3(0, 0.15, 0),
		func() -> String: return "" if (game._ending or tea_ceremony.active) else "E : Préparer le thé et s'asseoir",
		func(_p): _tea_time())

func _tea_time() -> void:
	tea_ceremony.start()

# ---------------------------------------------------------------- chat
func _setup_cat() -> void:
	var cat: Node3D = props.get_node_or_null("Cat")
	if cat == null:
		return
	game._make(cat, Vector3(0.8, 0.7, 0.8), Vector3(0, 0.3, 0),
		func() -> String: return "E : Caresser le chat",
		func(_p):
			cat_pets += 1
			GameState.set_flag(&"chat_vu")
			var lines := ["Le chat ronronne et vous regarde à peine.", "Il s'étire au soleil, une patte sur votre main.", "Le chat cligne lentement des yeux : c'est un sourire."]
			Events.toast.emit(lines[cat_pets % lines.size()]))

# ---------------------------------------------------------------- cabane et lettres
func _setup_cabin() -> void:
	var hut: Node3D = props.get_node_or_null("Hut")
	if hut == null:
		return
	door = hut.find_child("door", true, false)
	game._make(hut, Vector3(1.4, 2.2, 1.0), Vector3(0, 1.1, 2.6),
		func() -> String:
			if letters_read >= LETTERS.size() and _letter_day == GameState.day:
				return "Il n'y a plus de lettre à lire ici."
			if _letter_day == GameState.day and letters_read > 0 and letters_read <= LETTERS.size() and door_open:
				return "Vous avez déjà lu la lettre du jour."
			return "E : Ouvrir la porte de la cabane",
		func(_p): _read_letter())

func _read_letter() -> void:
	if _letter_day == GameState.day or letters_read >= LETTERS.size():
		return
	_letter_day = GameState.day
	door_open = true
	if door:
		create_tween().tween_property(door, "position:x", door.position.x + 0.9, 0.8)
	player.input_enabled = false
	await get_tree().create_timer(0.8).timeout
	var idx := letters_read
	letters_read += 1
	GameState.note("J'ai lu une lettre de Seiji, l'ancien gardien.")
	await hud.show_note("Lettre %d / %d" % [letters_read, LETTERS.size()], LETTERS[idx])
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if letters_read == LETTERS.size():
		GameState.set_flag(&"lettres_lues")
		Events.toast.emit("C'était la dernière lettre de l'ancien gardien.")

# ---------------------------------------------------------------- renard
func _spawn_fox() -> void:
	if fox and is_instance_valid(fox):
		fox.queue_free()
	fox_hinted = false
	fox_done = false
	var sp: Vector2 = FOX_SPOTS[randi() % FOX_SPOTS.size()]
	fox = load("res://scenes/visitors/visitor_placeholder.tscn").instantiate()
	fox.set("display_name", "Renard")
	fox.set("color", Color(0.85, 0.45, 0.2))
	fox.position = Vector3(sp.x, TERRAIN.height(sp.x, sp.y), sp.y)
	fox.scale = Vector3(0.55, 0.32, 0.55)
	props.add_child(fox)

func _update_fox(p: Vector3) -> void:
	if fox == null or not is_instance_valid(fox) or fox_done:
		return
	var d := Vector2(p.x, p.z).distance_to(Vector2(fox.position.x, fox.position.z))
	if d < 34.0 and not fox_hinted:
		fox_hinted = true
		Events.toast.emit("Vous apercevez un renard roux entre les arbres...")
	if d < 7.5:
		fox_done = true
		Events.toast.emit("Le renard vous observait. Il file entre les troncs.")
		GameState.note("Un renard roux m'a observé depuis les arbres.")
		GameState.add_progress(&"renard")
		GameState.set_flag(&"renard_vu")
		var f := fox
		var tw := create_tween()
		tw.tween_property(f, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
		tw.tween_callback(f.queue_free)
