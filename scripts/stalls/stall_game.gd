class_name StallGame
extends Node3D
## Base des stands de la fête (yatai) : un décor, un hôte, et un mini-jeu qui prend la main sur la vue.
##
## Déroulé : on vise le stand (E) -> le gardien se met en place (la vue glisse jusqu'au poste de jeu) ->
## feuille de règles -> manches (le jeu lit la souris lui-même : mouvement, clic maintenu, relâché) ->
## feuille de résultat (score, record, lots gagnés, mot de l'hôte) -> Rejouer ou Quitter.
## Clic droit : quitter le stand à tout moment.
##
## Chaque jeu hérite de cette classe et fournit :
##   _build()                le décor du jeu (appelé une fois, à la mise en place du stand)
##   view() -> Dictionary    poste de jeu : {pos (pieds), yaw (degrés), pitch (degrés), crouch (m)}
##   _round_start()          une manche commence
##   _tick(delta)            chaque image de physique pendant la manche
##   _motion(rel)            mouvement de souris (pixels) pendant la manche
##   _press() / _release()   clic gauche enfoncé / relâché pendant la manche
##   status() -> String      ligne d'état sous le titre (« Poissons : 3 »)
## et appelle end_round(score, ligne, lots) quand la manche est finie.

signal _sheet_choice(choice: String)

const STATE_KEY := "jeux"

var game: Node3D
var festival: Node
var id := ""
var title := ""                 # « Pêche aux poissons rouges »
var kanji := ""                 # « 金魚 » (sceau)
var host := ""                  # personnage qui tient le stand ("" : personne)
var rules: PackedStringArray = []
var controls := ""              # rappel des commandes en bas de l'écran
var unit := ""                  # « poisson » : mot du score, au singulier
var booth := ""                 # modèle du yatai (assets/models/<booth>.glb)
var auto_rules := false         # test : la feuille de règles se valide seule
var active := false             # le gardien est au stand
var playing := false            # une manche est en cours
var last_score := 0

var _ui: Control
var _status: Label
var _hint: Label
var _pops: Control
var _saved: Dictionary = {}
var _lmb := false

# ---------------------------------------------------------------- mise en place
func setup(g: Node3D, fest: Node) -> void:
	game = g
	festival = fest
	_build_booth()
	_build()

func _build() -> void:
	pass

## Le yatai : modèle Blender (repère « lantern_L/R » pour les lanternes, « sign » pour l'enseigne), ou une
## silhouette provisoire. L'enseigne (kanji) est écrite en Klee One sur le lambrequin.
func _build_booth() -> void:
	var b := ToolModels.glb(booth) if booth != "" else null
	if b == null:
		b = Node3D.new()
		for x in [-1.15, 1.15]:
			for z in [-0.6, 0.6]:
				ToolModels.box(b, Vector3(0.07, 2.2, 0.07), ToolModels.WOOD, Vector3(x, 1.1, z))
		ToolModels.box(b, Vector3(2.5, 0.04, 1.6), Color("#C8442B"), Vector3(0, 2.22, 0.05), Vector3(-6, 0, 0))
	b.name = "Booth"
	add_child(b)
	# collisions importées (-col) : on ne traverse pas le stand
	var sign_node: Node3D = b.find_child("sign", true, false)
	var sp := sign_node.position if sign_node else Vector3(0, 2.02, 0.86)
	var lbl := Label3D.new()
	lbl.text = kanji
	lbl.font = UIKit.font("title")
	lbl.font_size = 96
	lbl.pixel_size = 0.0021
	lbl.modulate = Color("#2A2024")
	lbl.outline_size = 0
	lbl.position = sp + Vector3(0, 0, 0.012)
	lbl.double_sided = false
	lbl.shaded = false
	lbl.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	b.add_child(lbl)
	# ampoule chaude sous le toit : les lots et le comptoir restent lisibles le soir
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 0.9
	lamp.omni_range = 3.2
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 1.85, 0.45)
	b.add_child(lamp)
	for nm in ["lantern_L", "lantern_R"]:
		var hook: Node3D = b.find_child(nm, true, false)
		var lan := ToolModels.glb("paper_lantern")
		if lan == null:
			continue
		lan.position = hook.position if hook else Vector3(-1.1 if nm.ends_with("L") else 1.1, 1.72, 0.92)
		lan.scale = Vector3.ONE * 0.8
		b.add_child(lan)
		var atmo: Node = game.atmosphere
		if atmo and atmo.has_method("add_papers"):
			atmo.call("add_papers", lan, 1.5)

## Zone visée pour entrer au stand (repère du stand) : le comptoir, pas tout le stand (l'hôte, derrière,
## doit rester visable pour lui parler).
func area_size() -> Vector3:
	return Vector3(2.4, 1.1, 0.6)

func area_offset() -> Vector3:
	return Vector3(0, 0.55, 0.5)

## Où se tient l'hôte (monde) : derrière le stand, un peu sur le côté.
func host_spot() -> Vector3:
	return to_global(Vector3(0.75, 0, -0.35))

func view() -> Dictionary:
	return {"pos": global_position + global_basis.z * 1.2, "yaw": rotation_degrees.y, "pitch": -20.0, "crouch": 0.0}

## Invite affichée en visant le stand.
func prompt() -> String:
	if active:
		return ""
	var best := best_score()
	var s := "E : %s" % title
	if best > 0:
		s += "  (record : %d)" % best
	return s

# ---------------------------------------------------------------- état sauvegardé
func record() -> Dictionary:
	var st: Dictionary = Festival.state()
	if not st.has(STATE_KEY):
		st[STATE_KEY] = {}
	var all: Dictionary = st[STATE_KEY]
	if not all.has(id):
		all[id] = {"best": 0, "plays": 0}
	return all[id]

func best_score() -> int:
	return int(record().get("best", 0))

# ---------------------------------------------------------------- entrer, sortir
func enter() -> void:
	if active:
		return
	active = true
	var pl: CharacterBody3D = game.player
	game.player_put_back_tool()
	if pl.carry != &"":
		pl.set_carry(&"")
	pl.input_enabled = false
	pl.velocity = Vector3.ZERO
	_saved = {"head_y": pl.head.position.y, "pitch": pl.head.rotation.x, "fov": pl.camera.fov}
	game.hud.set_quiet(true)
	var v := view()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var p: Vector3 = v["pos"]
	p.y = game.ground_y(p.x, p.z) + 0.05
	var yaw := deg_to_rad(float(v["yaw"]))
	tw.tween_property(pl, "global_position", p, 0.8)
	tw.tween_property(pl, "rotation:y", pl.rotation.y + wrapf(yaw - pl.rotation.y, -PI, PI), 0.8)
	tw.tween_property(pl.head, "rotation:x", deg_to_rad(float(v["pitch"])), 0.8)
	tw.tween_property(pl.head, "position:y", float(_saved["head_y"]) - float(v.get("crouch", 0.0)), 0.8)
	tw.tween_property(pl.camera, "fov", float(v.get("fov", pl.camera.fov)), 0.8)
	await tw.finished
	_make_ui()
	_on_enter()
	var go := await _rules_sheet()
	if go:
		_start()
	else:
		leave()

func _on_enter() -> void:
	pass

func _on_leave() -> void:
	pass

func leave() -> void:
	if not active:
		return
	playing = false
	_on_leave()
	if _ui != null:
		_ui.queue_free()
		_ui = null
	var pl: CharacterBody3D = game.player
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pl.head, "position:y", float(_saved.get("head_y", 1.6)), 0.5)
	tw.tween_property(pl.head, "rotation:x", 0.0, 0.5)
	tw.tween_property(pl.camera, "fov", float(_saved.get("fov", pl.camera.fov)), 0.5)
	await tw.finished
	game.hud.set_quiet(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pl.input_enabled = true
	active = false

func _start() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_lmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	playing = true
	_round_start()
	refresh_status()

# ---------------------------------------------------------------- à fournir par chaque jeu
func _round_start() -> void:
	pass

func _tick(_delta: float) -> void:
	pass

func _motion(_rel: Vector2) -> void:
	pass

func _press() -> void:
	pass

func _release() -> void:
	pass

func status() -> String:
	return ""

# ---------------------------------------------------------------- boucle
func _physics_process(delta: float) -> void:
	if not playing:
		return
	_tick(delta)

func _input(event: InputEvent) -> void:
	if not active or get_tree().paused:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and playing:
			get_viewport().set_input_as_handled()
			leave()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and playing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if mb.pressed and not _lmb:
				_lmb = true
				_press()
			elif not mb.pressed and _lmb:
				_lmb = false
				_release()
	elif event is InputEventMouseMotion and playing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_motion((event as InputEventMouseMotion).relative)

## Clic gauche tenu en ce moment (pendant une manche).
func holding() -> bool:
	return _lmb

## Fin de manche : enregistre le score, donne les lots, affiche la feuille de résultat.
## prizes : {objet: nombre} ajoutés aux poches.
func end_round(score: int, line: String, prizes: Dictionary = {}) -> void:
	if not playing:
		return
	playing = false
	_lmb = false
	last_score = score
	var rec := record()
	var was_best := int(rec.get("best", 0))
	rec["plays"] = int(rec.get("plays", 0)) + 1
	rec["title"] = title
	var new_best := score > was_best
	if new_best:
		rec["best"] = score
	# les lots sont des souvenirs de la fête (ils ne prennent pas de place dans les poches)
	var souv: Dictionary = Festival.state().get("souvenirs", {})
	for k in prizes:
		if int(prizes[k]) > 0:
			souv[k] = int(souv.get(k, 0)) + int(prizes[k])
	Festival.state()["souvenirs"] = souv
	if host != "" and score > 0 and festival.guests.has(host) and not rec.get("affection", false):
		rec["affection"] = true            # jouer au stand d'un invité lui fait plaisir (une fois)
		GameState.add_affection(host, 1)
	await get_tree().create_timer(0.9).timeout
	var again := await _result_sheet(score, line, prizes, new_best and score > 0, was_best)
	if not active:
		return
	if again:
		_start()
	else:
		leave()

# ---------------------------------------------------------------- interface du stand
func _make_ui() -> void:
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(_ui)
	# cartouche en haut à gauche : sceau, nom du stand, hôte, état
	var panel := UIKit.PaperPanel.new(Vector2(18, 12), 12.0, float(id.length()))
	panel.position = Vector2(14, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var h := UIKit.Hanko.new(kanji, 54, false, float(id.length()))
	h.rotation = -0.05
	row.add_child(h)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	row.add_child(col)
	UIKit.label(col, title, "title", 24, UIKit.INK)
	var sub := "Stand de %s" % Story.display_name(host) if host != "" and festival.guests.has(host) else "Libre-service, ce soir"
	UIKit.label(col, sub, "italic", 15, UIKit.INK_SOFT)
	_status = UIKit.label(col, "", "hand", 20, UIKit.VERMILION)
	# rappel des commandes en bas
	_hint = Label.new()
	_hint.text = controls + "   ·   clic droit : quitter"
	_hint.add_theme_font_override("font", UIKit.font("body_bold"))
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color("#FBF1DC"))
	_hint.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.06, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -500
	_hint.offset_right = 500
	_hint.offset_top = -44
	_hint.offset_bottom = -14
	_ui.add_child(_hint)
	_pops = Control.new()
	_pops.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_pops)

func refresh_status() -> void:
	if _status != null:
		_status.text = status()

## Petit mot qui jaillit à l'écran (« +1 », « Déchiré ! ») : à une position 3D, ou au centre.
func pop(text: String, at: Variant = null, color := Color("#FFF3D6"), size := 34) -> void:
	if _pops == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font("title"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.09, 0.05, 0.9))
	l.add_theme_constant_override("outline_size", 9)
	_pops.add_child(l)
	var vp := get_viewport().get_visible_rect().size
	var p := vp * Vector2(0.5, 0.38)
	if at is Vector3:
		var cam: Camera3D = game.player.camera
		if not cam.is_position_behind(at):
			p = cam.unproject_position(at)
	l.reset_size()
	l.position = p - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 0.4
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 40.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)

## Son du jeu : le premier nom qui existe (les sons propres aux stands viendront en fichiers ; d'ici là, un proche).
func sfx(names: Array, at: Variant = null, db := 0.0) -> void:
	for n in names:
		if Sfx.has(StringName(n)):
			Sfx.play(StringName(n), at, db)
			return

# ---------------------------------------------------------------- feuilles (règles, résultat)
func _sheet_buttons(box: VBoxContainer, labels: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for i in labels.size():
		var b := UIKit.button(String(labels[i][1]), i == 0)
		b.custom_minimum_size = Vector2(190, 48)
		var key := String(labels[i][0])
		b.pressed.connect(func(): _sheet_choice.emit(key))
		row.add_child(b)

func _rules_sheet() -> bool:
	game.hud.modal_count += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sh := UIKit.open_sheet(game.hud, Vector2(600, 0), Vector2(46, 34), float(id.length()) + 3.0)
	var box: VBoxContainer = sh["box"]
	box.add_theme_constant_override("separation", 12)
	var sub := ("Le stand de %s" % Story.display_name(host)) if host != "" and festival.guests.has(host) else "Tsukimi, le soir de la fête"
	UIKit.sheet_header(box, kanji, title, sub, ("record : %d" % best_score()) if best_score() > 0 else "")
	box.add_child(UIKit.BrushRule.new(8))
	for r in rules:
		var l := UIKit.label(box, "·  " + r, "body", 19, UIKit.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
	var c := UIKit.label(box, controls + "  ·  clic droit : quitter", "italic", 16, UIKit.INK_SOFT)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_buttons(box, [["go", "Jouer"], ["no", "Plus tard"]])
	if auto_rules:
		get_tree().create_timer(1.2).timeout.connect(func(): _sheet_choice.emit("go"))
	var choice: String = await _sheet_choice
	await UIKit.close_sheet(sh)
	game.hud.modal_count -= 1
	return choice == "go"

func _result_sheet(score: int, line: String, prizes: Dictionary, new_best: bool, was_best: int) -> bool:
	game.hud.modal_count += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play(&"paper")
	var sh := UIKit.open_sheet(game.hud, Vector2(560, 0), Vector2(46, 32), float(id.length()) + 7.0)
	var box: VBoxContainer = sh["box"]
	box.add_theme_constant_override("separation", 10)
	UIKit.sheet_header(box, kanji, title, line)
	box.add_child(UIKit.BrushRule.new(8))
	var big := HBoxContainer.new()
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override("separation", 18)
	box.add_child(big)
	var n := UIKit.label(big, str(score), "title", 64, UIKit.VERMILION)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var u := UIKit.label(big, _plural(unit, score), "hand", 26, UIKit.INK)
	u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if new_best:
		var hk := UIKit.Hanko.new("新", 46, true, 3.0)
		hk.rotation = 0.12
		big.add_child(hk)
		hk.stamp(0.35)
		UIKit.label(box, "Nouveau record !", "title", 20, UIKit.LACQUER).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif was_best > 0:
		UIKit.label(box, "Record : %d" % was_best, "italic", 17, UIKit.INK_SOFT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var got := PackedStringArray()
	for k in prizes:
		if int(prizes[k]) > 0:
			got.append("%s ×%d" % [Story.item_name(String(k)), int(prizes[k])] if int(prizes[k]) > 1 else Story.item_name(String(k)))
	if not got.is_empty():
		var pl := UIKit.label(box, "Gagné : " + ", ".join(got), "body_bold", 19, UIKit.MOSS)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var said := host_line(score)
	if said != "" and host != "" and festival.guests.has(host):
		var q := UIKit.label(box, "%s : « %s »" % [Story.display_name(host), said], "hand", 20, UIKit.INK)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size = Vector2(480, 0)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_buttons(box, [["again", "Rejouer"], ["leave", "Quitter le stand"]])
	var choice: String = await _sheet_choice
	await UIKit.close_sheet(sh)
	game.hud.modal_count -= 1
	return choice == "again"

## Mot de l'hôte selon le score (à redéfinir par jeu).
func host_line(_score: int) -> String:
	return ""

static func _plural(word: String, n: int) -> String:
	if word == "" or n <= 1 or word in ["dango"]:
		return word
	if word.ends_with("s") or word.ends_with("x"):
		return word
	if word.ends_with("eau"):
		return word + "x"
	return word + "s"
