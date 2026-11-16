class_name Menus
extends CanvasLayer
## Menus du jeu : écran titre (sur le vrai sanctuaire, caméra qui dérive), emplacements de sauvegarde, options,
## pause (Échap) et écran de fin de démo. Tourne même quand l'arbre est en pause.
##
## Le jeu (scripts/game.gd) appelle show_title(), show_end(bilan) ; les choix reviennent par start_new_game(slot),
## load_and_start(slot) du jeu, ou par un rechargement de la scène (retour à l'écran titre).

const INK := Color("#2A2024")
const PAPER := Color("#EFE6D2")
const WOOD := Color("#5A3A26")
const RED := Color("#C8442B")
const CREAM := Color("#F6EEDC")
const LOGO := "res://assets/ui/logo.webp"

var game: Node3D
var title_active := false
var paused := false
var _root: Control
var _title: Control
var _panel_holder: Control
var _pause: Control
var _dim: ColorRect
var _theme: Theme
var _t := 0.0
var _cam_yaw := 0.0
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _end_choice := ""

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.05, 0.07, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	_root.add_child(_dim)
	_panel_holder = Control.new()
	_panel_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_holder)

# ================================================================ style
func _make_theme() -> Theme:
	# kit d'interface commun (scripts/ui/ui_kit.gd) : boutons de bois, polices ; plus cases, curseurs, listes
	var th := Theme.new()
	th.merge_with(UIKit.theme())
	th.set_font_size("font_size", "Button", 20)
	th.set_color("font_color", "Label", INK)
	th.set_font_size("font_size", "Label", 18)
	th.set_font("font", "CheckBox", UIKit.font("body"))
	th.set_color("font_color", "CheckBox", INK)
	th.set_color("font_hover_color", "CheckBox", UIKit.VERMILION)
	th.set_color("font_pressed_color", "CheckBox", INK)
	th.set_font_size("font_size", "CheckBox", 18)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		th.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	th.set_icon("unchecked", "CheckBox", _check_icon(false))
	th.set_icon("checked", "CheckBox", _check_icon(true))
	th.set_font_size("font_size", "OptionButton", 18)
	# curseurs : trait d'encre, partie remplie vermillon, poignée ronde
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.36, 0.25, 0.18, 0.3)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UIKit.VERMILION
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	th.set_icon("grabber", "HSlider", _dot_icon(10, UIKit.LACQUER, UIKit.PAPER))
	th.set_icon("grabber_highlight", "HSlider", _dot_icon(11, UIKit.VERMILION, UIKit.PAPER))
	# listes déroulantes : papier
	var pop := StyleBoxFlat.new()
	pop.bg_color = UIKit.PAPER
	pop.border_color = Color(0.36, 0.25, 0.18, 0.6)
	pop.set_border_width_all(2)
	pop.set_corner_radius_all(4)
	pop.content_margin_left = 8
	pop.content_margin_right = 8
	pop.content_margin_top = 6
	pop.content_margin_bottom = 6
	th.set_stylebox("panel", "PopupMenu", pop)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.75, 0.24, 0.16, 0.18)
	th.set_stylebox("hover", "PopupMenu", hov)
	th.set_font("font", "PopupMenu", UIKit.font("body"))
	th.set_font_size("font_size", "PopupMenu", 18)
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", UIKit.LACQUER)
	return th

## Petite image ronde (poignée de curseur).
func _dot_icon(r: int, col: Color, ring: Color) -> ImageTexture:
	var n := r * 2 + 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r + 0.5 - d, 0.0, 1.0)
			var col2 := ring if d > r - 2.5 else col
			img.set_pixel(x, y, Color(col2.r, col2.g, col2.b, a))
	return ImageTexture.create_from_image(img)

## Case à cocher : carré d'encre, rempli de vermillon avec un point clair quand elle est cochée.
func _check_icon(on: bool) -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var edge := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var col := Color(0, 0, 0, 0)
			if edge >= 2 and edge <= 3:
				col = Color(0.36, 0.25, 0.18, 0.9)
			elif edge > 3 and on:
				col = UIKit.VERMILION
				if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 12)) < 3.5:
					col = UIKit.PAPER
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _paper(w: int) -> Container:
	var p := UIKit.PaperPanel.new(Vector2(40, 28), 16.0, float(w % 17))
	p.custom_minimum_size = Vector2(w, 0)
	return p

func _center(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH

## wrap_w > 0 : paragraphe qui revient à la ligne dans cette largeur (sinon une seule ligne : indispensable dans
## les grilles, où une étiquette à retour automatique n'a aucune largeur et s'écrit lettre par lettre).
func _label(parent: Node, text: String, size: int, color := INK, outline := 0, wrap_w := 0) -> Label:
	var l := UIKit.label(null, text, "title" if size >= 28 else ("body_bold" if outline > 0 else "body"), size, color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.07, 0.88))
		l.add_theme_constant_override("outline_size", outline)
	if wrap_w > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_w
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable, w := 340, primary := false) -> Button:
	var b := UIKit.button(text, primary)
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(func(): cb.call())
	parent.add_child(b)
	return b

func _clear_panels() -> void:
	for c in _panel_holder.get_children():
		c.queue_free()

# ================================================================ écran titre
## Écran titre sur le sanctuaire : continuer, nouvelle partie, charger, options, quitter.
func show_title() -> void:
	title_active = true
	_dim.visible = false
	game.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _title:
		_title.queue_free()
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)
	_root.move_child(_title, 0)
	# voile dégradé à gauche, pour la lisibilité du titre
	var grad := Gradient.new()
	grad.set_color(0, Color(0.08, 0.05, 0.05, 0.78))
	grad.set_color(1, Color(0.08, 0.05, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var veil := TextureRect.new()
	veil.texture = gt
	veil.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 760
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(veil)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 80
	col.offset_top = 40
	col.offset_right = 600
	col.add_theme_constant_override("separation", 12)
	_title.add_child(col)
	# logo du jeu (assets/ui/logo.webp), tel quel ; repli sur le titre en texte s'il manque
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(460, 251)      # 1408 x 768 à l échelle
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(logo)
	else:
		_label(col, "Tanuki Sanctuary", 60, CREAM, 10)
	_label(col, "Démo  ·  cinq jours d'automne, jusqu'à la lune de Tsukimi", 20, Color("#E6D8BE"), 5)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	var last := SaveGame.latest()
	if last >= 0:
		var inf := SaveGame.info(last)
		_button(col, "Continuer  —  jour %d" % int(inf["day"]), func(): _launch_load(last), 340, true)
	_button(col, "Nouvelle partie", func(): _slots(true), 340, last < 0)
	var load_b := _button(col, "Charger une partie", func(): _slots(false))
	load_b.disabled = last < 0
	_button(col, "Options", func(): _options())
	_button(col, "Quitter", func(): get_tree().quit())
	# rappel des commandes, ancré en bas de l'écran (sous les boutons, il sortait de l'écran)
	var keys := _label(_title, "Z Q S D : marcher   ·   souris : regarder   ·   E ou clic : agir   ·   Échap : pause", 15, Color("#E6D8BE"), 4)
	keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	keys.offset_left = 80
	keys.offset_top = -34
	keys.offset_bottom = -12
	# vue de la cour, lumière d'après-midi
	game.atmosphere.set_phase(GameState.Phase.VISIT, true)
	GameState.phase = GameState.Phase.VISIT
	var p: CharacterBody3D = game.player
	p.input_enabled = false
	p.global_position = Vector3(9.5, 0.1, 6.5)
	p.velocity = Vector3.ZERO
	_cam_yaw = deg_to_rad(18.0)
	p.rotation.y = _cam_yaw
	p.head.rotation.x = deg_to_rad(4.0)
	game.hud.fade_to(0.0, 1.2)

func _process(delta: float) -> void:
	_t += delta
	if title_active and game:
		# la caméra dérive lentement, comme un regard qui flâne
		game.player.rotation.y = _cam_yaw + sin(_t * 0.045) * 0.32
		game.player.head.rotation.x = deg_to_rad(4.0 + sin(_t * 0.07) * 2.0)

func _launch_new(slot: int) -> void:
	_close_title()
	game.start_new_game(slot)

func _launch_load(slot: int) -> void:
	_close_title()
	game.load_and_start(slot)

func _close_title() -> void:
	title_active = false
	_clear_panels()
	if _title:
		var tw := create_tween()
		tw.tween_property(_title, "modulate:a", 0.0, 0.6)
		tw.tween_callback(_title.queue_free)
		_title = null
	game.hud.visible = true

# ================================================================ emplacements
## Choix d'un emplacement : pour une nouvelle partie (on peut écraser) ou pour charger.
func _slots(new_game: bool) -> void:
	_clear_panels()
	var panel := _paper(720)
	_center(panel)
	_panel_holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	UIKit.sheet_header(v, "始" if new_game else "続", "Nouvelle partie" if new_game else "Charger une partie",
		"Choisissez un emplacement. La partie se sauvegarde chaque soir, après le journal." if new_game
		else "Vous reprendrez au matin du jour enregistré.")
	v.add_child(UIKit.BrushRule.new(10))
	for i in SaveGame.SLOTS:
		var inf := SaveGame.info(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var txt := "Emplacement %d  —  vide" % (i + 1)
		if not inf.is_empty():
			txt = "Emplacement %d  —  jour %d%s\n%d pièces · %d rencontre%s · %s" % [i + 1, inf["day"],
				"  (démo terminée)" if inf["completed"] else "", inf["coins"], inf["met"], "s" if int(inf["met"]) > 1 else "",
				String(inf["saved_at"]).replace("T", " ").left(16)]
		var l := _label(row, txt, 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot := i
		if new_game:
			_button(row, "Commencer ici" if inf.is_empty() else "Écraser", _on_new_slot.bind(slot, inf), 200)
		else:
			var b := _button(row, "Charger", _launch_load.bind(slot), 160)
			b.disabled = inf.is_empty()
			if not inf.is_empty():
				_button(row, "Effacer", _on_erase_slot.bind(slot), 140)
	_button(v, "Retour", func(): _clear_panels(), 200)

func _on_new_slot(slot: int, inf: Dictionary) -> void:
	if inf.is_empty():
		_launch_new(slot)
	else:
		_confirm("Écraser l'emplacement %d (jour %d) ?" % [slot + 1, inf["day"]], _launch_new.bind(slot), _slots.bind(true))

func _on_erase_slot(slot: int) -> void:
	_confirm("Effacer définitivement l'emplacement %d ?" % (slot + 1), _erase_and_back.bind(slot), _slots.bind(false))

func _erase_and_back(slot: int) -> void:
	SaveGame.erase(slot)
	show_title()
	_slots(false)

func _confirm(question: String, yes: Callable, no: Callable) -> void:
	_clear_panels()
	var panel := _paper(560)
	_center(panel)
	_panel_holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	_label(v, question, 22, INK, 0, 480)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_button(row, "Oui", yes, 220)
	_button(row, "Non", no, 220)

# ================================================================ options
func _options() -> void:
	_clear_panels()
	var panel := _paper(760)
	_center(panel)
	_panel_holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	UIKit.sheet_header(v, "設定", "Options")
	v.add_child(UIKit.BrushRule.new(10))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	_slider(grid, "Volume général", "volume_master", 0.0, 1.0, 0.05, true)
	_slider(grid, "Ambiances", "volume_ambience", 0.0, 1.0, 0.05, true)
	_slider(grid, "Effets", "volume_effects", 0.0, 1.0, 0.05, true)
	_slider(grid, "Sensibilité de la souris", "mouse_sensitivity", 0.3, 2.5, 0.05, false)
	_slider(grid, "Balancement de la tête", "head_bob", 0.0, 1.0, 0.1, true)
	_slider(grid, "Résolution 3D", "render_scale", 0.5, 1.0, 0.05, true)
	# qualité
	_label(grid, "Qualité graphique", 18)
	var ob := OptionButton.new()
	for n in Settings.QUALITY_NAMES:
		ob.add_item(n)
	ob.selected = int(Settings.get_value("quality"))
	ob.custom_minimum_size = Vector2(260, 40)
	ob.item_selected.connect(func(i: int): Settings.set_value("quality", i))
	grid.add_child(ob)
	_label(grid, "", 16)
	_check(grid, "Plein écran", "fullscreen")
	_check(grid, "Synchro verticale", "vsync")
	_label(v, "Qualité « Basse » et résolution 3D réduite : pour les machines modestes ou portables.", 14, Color("#6A5A50"), 0, 680)
	_button(v, "Retour", _options_back, 200)

func _options_back() -> void:
	_clear_panels()
	if paused:
		_pause_panel()

func _slider(grid: GridContainer, text: String, key: String, lo: float, hi: float, step: float, percent: bool) -> void:
	_label(grid, text, 18)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(260, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(s)
	var val := _label(grid, "", 16, Color("#6A5A50"))
	val.custom_minimum_size = Vector2(70, 0)
	_on_slider(s.value, key, val, percent, false)
	s.value_changed.connect(_on_slider.bind(key, val, percent, true))

func _on_slider(x: float, key: String, val: Label, percent: bool, save: bool) -> void:
	val.text = ("%d %%" % int(round(x * 100.0))) if percent else ("× %.2f" % x)
	if save:
		Settings.set_value(key, x)

## Réglage oui / non : un interrupteur qui affiche son état (plus lisible qu'une case sur le papier).
func _check(grid: GridContainer, text: String, key: String) -> void:
	_label(grid, text, 18)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = bool(Settings.get_value(key))
	b.text = "Oui" if b.button_pressed else "Non"
	b.custom_minimum_size = Vector2(260, 40)
	b.toggled.connect(_on_toggle.bind(b, key))
	grid.add_child(b)
	_label(grid, "", 16)

func _on_toggle(on: bool, b: Button, key: String) -> void:
	b.text = "Oui" if on else "Non"
	Sfx.play(&"ui_click")
	Settings.set_value(key, on)

# ================================================================ pause
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if title_active or _end_choice == "waiting" or game == null:
		return
	if paused:
		if _panel_holder.get_child_count() > 0 and _pause and not _pause_visible():
			_pause_panel()                  # Échap depuis les options : retour au menu pause
		else:
			close_pause()
		get_viewport().set_input_as_handled()
		return
	if int(game.hud.get("modal_count")) > 0:
		return                              # un panneau ouvert se ferme lui-même avec Échap
	open_pause()
	get_viewport().set_input_as_handled()

func _pause_visible() -> bool:
	return _pause != null and is_instance_valid(_pause) and _pause.is_inside_tree()

func open_pause() -> void:
	paused = true
	_prev_mouse = Input.mouse_mode
	get_tree().paused = true
	_dim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_panel()

func _pause_panel() -> void:
	_clear_panels()
	_pause = _paper(480)
	_center(_pause)
	_panel_holder.add_child(_pause)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_pause.add_child(v)
	UIKit.sheet_header(v, "休", "Pause", "Jour %d — %s" % [GameState.day, GameState.PHASE_NAMES[GameState.phase]])
	v.add_child(UIKit.BrushRule.new(10))
	_button(v, "Reprendre", func(): close_pause(), 340, true)
	_button(v, "Options", func(): _options())
	_button(v, "Retour à l'écran titre", _ask_title)
	_button(v, "Quitter le jeu", _ask_quit)
	_label(v, "La partie se sauvegarde chaque soir, après le journal.", 14, Color("#6A5A50"), 0, 400)

func _ask_title() -> void:
	_confirm("Revenir à l'écran titre ?\nLa journée en cours n'est pas sauvegardée : vous reprendrez au matin du jour %d." % GameState.day,
		_to_title, _pause_panel)

func _to_title() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _ask_quit() -> void:
	_confirm("Quitter le jeu ?\nVous reprendrez au matin du jour %d." % GameState.day, get_tree().quit, _pause_panel)

func close_pause() -> void:
	paused = false
	_clear_panels()
	_dim.visible = false
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse

# ================================================================ fin de la démo
func _set_end_choice(c: String) -> void:
	_end_choice = c

## Écran de fin : bilan des jours de la démo (et des préparatifs de la fête), personnes rencontrées, remerciements. Renvoie "title" ou "quit".
func show_end(summary: Dictionary) -> String:
	_end_choice = "waiting"
	game.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color("#1E1620")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	_root.add_child(bg)
	var sheet := UIKit.PaperPanel.new(Vector2(50, 22), 16.0, 31.0)
	sheet.custom_minimum_size = Vector2(960, 0)
	var center0 := CenterContainer.new()
	center0.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center0)
	center0.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	sheet.add_child(box)
	UIKit.sheet_header(box, "月", "Fin de la démo", "Cinq jours d'automne au sanctuaire, jusqu'à la lune de Tsukimi")
	box.add_child(UIKit.BrushRule.new(10))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 4)
	box.add_child(sep)
	var grid := GridContainer.new()
	grid.columns = 4               # deux colonnes de bilan côte à côte (avec les préparatifs de la fête)
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 0)
	var center := CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	for row in summary.get("lines", []):
		_label(grid, String(row[0]), 19, UIKit.INK_SOFT)
		var vl := UIKit.label(grid, String(row[1]), "hand", 20, INK)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var people: Array = summary.get("people", [])
	if not people.is_empty():
		var s2 := Control.new()
		s2.custom_minimum_size = Vector2(0, 10)
		box.add_child(s2)
		var h := UIKit.label(box, "Ceux qui sont montés jusqu'ici", "hand", 20, UIKit.VERMILION)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pc := CenterContainer.new()
		var pg := GridContainer.new()
		pg.columns = 4
		pg.add_theme_constant_override("h_separation", 30)
		pg.add_theme_constant_override("v_separation", 0)
		pc.add_child(pg)
		box.add_child(pc)
		for p in people:
			_label(pg, String(p[0]), 19, INK)
			UIKit.label(pg, String(p[1]), "title", 19, Color("#C9405A"))
	var s3 := Control.new()
	s3.custom_minimum_size = Vector2(0, 6)
	box.add_child(s3)
	var thanks := UIKit.label(box, "Merci d'avoir veillé sur ce lieu. La suite de l'automne — et de l'histoire de Seiji — viendra bientôt.", "hand", 18, UIKit.INK_SOFT)
	thanks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thanks.custom_minimum_size.x = 860
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_button(row, "Retour à l'écran titre", _set_end_choice.bind("title"), 300, true)
	_button(row, "Quitter", _set_end_choice.bind("quit"), 200)
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 1.4)
	if OS.get_cmdline_user_args().has("--autoplay"):
		_end_choice = "title"
	while _end_choice == "waiting":
		await get_tree().process_frame
	var c := _end_choice
	_end_choice = ""
	return c
