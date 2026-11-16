extends CanvasLayer
## Dialogue façon visual novel : décor flouté, grand portrait, boîte de texte, choix, gain d'affection.
## Joue une visite de data/story/story.json (format : docs/story-format.md) avec play_visit(visite).
## Portraits : 3D en direct si le personnage a un modèle VRoid (scripts/live_portrait.gd), sinon
## res://assets/portraits/<personnage>_<expression>.png s'il existe, sinon placeholder coloré.

signal finished

var _root: Control
var _portrait_holder: Control
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _advance := false
var _typing := false
var _plate: PanelContainer
var _plate_sb: StyleBoxFlat

func _ready() -> void:
	layer = 20
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/vn_backdrop.gdshader")
	bg.material = sm
	_root.add_child(bg)

	_portrait_holder = Control.new()
	_portrait_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait_holder)

	# boîte de texte : feuille de washi en bas de l'écran (voir scripts/ui/ui_kit.gd)
	var box := UIKit.PaperPanel.new(Vector2(40, 18), 14.0, 21.0, Color(0.96, 0.935, 0.87))
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.anchor_top = 1.0
	box.offset_left = 110
	box.offset_right = -110
	box.offset_top = -250
	box.offset_bottom = -20
	_root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	# plaque du nom : étiquette de la couleur du personnage, posée à cheval sur le bord de la feuille
	_plate = PanelContainer.new()
	_plate.anchor_top = 1.0
	_plate.anchor_bottom = 1.0
	_plate.offset_left = 170
	_plate.offset_top = -248
	_plate.offset_bottom = -208
	_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_sb = StyleBoxFlat.new()
	_plate_sb.bg_color = UIKit.VERMILION
	_plate_sb.set_corner_radius_all(3)
	_plate_sb.content_margin_left = 22
	_plate_sb.content_margin_right = 22
	_plate_sb.content_margin_top = 4
	_plate_sb.content_margin_bottom = 6
	_plate_sb.shadow_color = Color(0.1, 0.05, 0.02, 0.3)
	_plate_sb.shadow_size = 4
	_plate_sb.shadow_offset = Vector2(1, 3)
	_plate.add_theme_stylebox_override("panel", _plate_sb)
	_root.add_child(_plate)
	_name = UIKit.label(_plate, "", "title", 24, Color("#FBF2DE"))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	v.add_child(spacer)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", UIKit.font("body"))
	_text.add_theme_font_override("italics_font", UIKit.font("italic"))
	_text.add_theme_font_override("bold_font", UIKit.font("body_bold"))
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_font_size_override("italics_font_size", 26)
	_text.add_theme_constant_override("line_separation", 4)
	_text.add_theme_color_override("default_color", UIKit.INK)
	v.add_child(_text)
	_hint = UIKit.label(v, "›  clic, Espace ou E", "italic", 15, UIKit.INK_SOFT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_choices = VBoxContainer.new()
	_choices.set_anchors_preset(Control.PRESET_CENTER)
	_choices.position = Vector2(-330, -140)
	_choices.custom_minimum_size = Vector2(660, 0)
	_choices.add_theme_constant_override("separation", 12)
	_root.add_child(_choices)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER])
	if press and _choices.get_child_count() == 0:
		_advance = true
		get_viewport().set_input_as_handled()

var _live := {}                  # id du personnage -> LivePortrait (gardé d'une visite à l'autre)
var _talker: LivePortrait = null # portrait 3D du personnage qui parle (bouche animée pendant l'écriture)

func _set_portrait(visitor_id: String, expr: String, color: Color, display_name: String) -> void:
	for c in _portrait_holder.get_children():
		if c is LivePortrait:
			c.visible = false
		else:
			c.queue_free()
	# portrait 3D en direct si le personnage a un modèle VRoid
	if LivePortrait.has_model(visitor_id):
		var lp: LivePortrait = _live.get(visitor_id)
		if lp == null:
			lp = LivePortrait.new()
			lp.setup(visitor_id)
			lp.set_anchors_preset(Control.PRESET_FULL_RECT)
			lp.offset_bottom = -200
			_portrait_holder.add_child(lp)
			_live[visitor_id] = lp
		lp.visible = true
		lp.set_expression(expr)
		return
	var path := "res://assets/portraits/%s_%s.png" % [visitor_id, expr]
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_bottom = -200
		_portrait_holder.add_child(tr)
	else:
		var ph: Control = load("res://scenes/ui/portrait_placeholder.tscn").instantiate()
		ph.display_name = "%s\n(%s)" % [display_name, expr]
		ph.color = color
		ph.set_anchors_preset(Control.PRESET_CENTER)
		ph.position = Vector2(-210, -400)
		ph.size = Vector2(420, 640)
		_portrait_holder.add_child(ph)

var _last_char := ""
var _last_expr := "neutre"

## Affiche le nom et le portrait du locuteur. Le joueur et la narration gardent le portrait du visiteur, assombri.
func _show_speaker(speaker: String, expr: String) -> void:
	var is_char := speaker != Story.PLAYER and speaker != Story.NARRATOR
	_name.text = Story.display_name(speaker)
	_plate.visible = _name.text != ""
	_plate_sb.bg_color = UIKit.INK_SOFT if speaker == Story.PLAYER else Story.color_of(speaker).darkened(0.25)
	if speaker == Story.NARRATOR:
		_text.add_theme_color_override("default_color", Color("#5E5048"))
		_text.add_theme_font_override("normal_font", UIKit.font("italic"))
	else:
		_text.add_theme_color_override("default_color", UIKit.INK)
		_text.add_theme_font_override("normal_font", UIKit.font("body"))
	if is_char and (speaker != _last_char or expr != _last_expr):
		_last_char = speaker
		_last_expr = expr
		_set_portrait(speaker, expr, Story.color_of(speaker), Story.display_name(speaker))
	_talker = _live.get(speaker) if is_char else null
	var tw := create_tween()
	tw.tween_property(_portrait_holder, "modulate", Color.WHITE if is_char else Color(0.62, 0.6, 0.66), 0.25)

## Joue une visite (dictionnaire de story.json). Applique effets et drapeaux, met à jour l'affection.
func play_visit(visit: Dictionary) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_last_char = ""
	var nodes: Dictionary = visit.get("nodes", {})
	var who := String(visit.get("character", ""))
	var id := String(visit.get("start", ""))
	_show_speaker(who, "neutre")
	var guard := 0
	while id != "" and nodes.has(id) and guard < 400:
		guard += 1
		var n: Dictionary = nodes[id]
		var t := String(n.get("type", "line"))
		match t:
			"line":
				_show_speaker(String(n.get("speaker", who)), String(n.get("expr", "neutre")))
				await _type(String(n.get("text", "")))
				_pop_affection(Story.apply(n.get("effects", [])))
				_advance = false
				while not _advance:
					await get_tree().process_frame
				id = String(n.get("next", ""))
			"choice":
				if String(n.get("text", "")) != "":
					_show_speaker(String(n.get("speaker", Story.PLAYER)), String(n.get("expr", _last_expr)))
					await _type(String(n.get("text", "")))
				var opts := []
				for c in n.get("choices", []):
					if Story.check(c.get("conditions", [])):
						opts.append(c)
				if opts.is_empty():
					id = String(n.get("next", ""))
					continue
				var pick: Dictionary = await _choose(opts)
				_pop_affection(Story.apply(pick.get("effects", [])))
				id = String(pick.get("next", ""))
			"branch":
				var nxt := String(n.get("else", ""))
				for r in n.get("rules", []):
					if Story.check(r.get("conditions", [])):
						nxt = String(r.get("next", ""))
						break
				id = nxt
			"end":
				_pop_affection(Story.apply(n.get("effects", [])))
				id = ""
			_:
				id = String(n.get("next", ""))
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()

## Propose d'offrir un objet porté. options : [{id, name, count, hint}] ; retourne l'id choisi, ou "" pour rien.
func choose_gift(who: String, options: Array) -> String:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_speaker(Story.PLAYER, _last_expr)
	_last_char = ""
	_set_portrait(who, "neutre", Story.color_of(who), Story.display_name(who))
	_portrait_holder.modulate = Color(0.62, 0.6, 0.66)
	await _type("Offrir quelque chose à %s ?" % Story.display_name(who))
	if OS.get_cmdline_user_args().has("--autoplay"):
		visible = false
		return String(options[0]["id"])
	var choices := []
	for o in options:
		var label := "%s  ×%d" % [o["name"], o["count"]]
		if String(o.get("hint", "")) != "":
			label += "   (%s)" % o["hint"]
		choices.append({"text": label, "id": o["id"]})
	choices.append({"text": "Ne rien offrir", "id": ""})
	var pick: Dictionary = await _choose(choices)
	if String(pick.get("id", "")) == "":
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return String(pick.get("id", ""))

## Petit coeur qui monte en haut à droite quand l'affection change.
func _pop_affection(changes: Array) -> void:
	for ch in changes:
		var d := int(ch["delta"])
		var l := UIKit.label(null, ("♥ +%d  " % d if d > 0 else "♡ %d  " % d) + Story.display_name(String(ch["character"])),
			"title", 28, Color("#D2475E") if d > 0 else Color("#8C8496"))
		l.add_theme_color_override("font_outline_color", Color("#FBF6EA"))
		l.add_theme_constant_override("outline_size", 8)
		l.anchor_left = 1.0
		l.anchor_right = 1.0
		l.offset_left = -420
		l.offset_right = -40
		l.offset_top = 40
		l.offset_bottom = 80
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_root.add_child(l)
		var tw := l.create_tween().set_parallel(true)
		tw.tween_property(l, "offset_top", -10.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.2)
		tw.chain().tween_callback(l.queue_free)

func _type(text: String) -> void:
	_text.text = text
	_text.visible_characters = 0
	_typing = true
	_advance = false
	var total := _text.get_total_character_count()
	var t := 0.0
	var talker := _talker
	if talker:
		talker.talking = true
	while _text.visible_characters < total:
		await get_tree().process_frame
		if _advance:
			break
		t += get_process_delta_time() * 60.0
		_text.visible_characters = int(t)
	if talker:
		talker.talking = false
	_text.visible_characters = -1
	_typing = false
	_advance = false

## Affiche les choix et retourne celui qui est cliqué (dictionnaire du choix).
func _choose(choices: Array) -> Dictionary:
	var state := {"done": false, "chosen": {}}   # un Dictionary : les lambdas ne modifient pas les variables locales capturées
	for c in choices:
		var b := UIKit.choice_button(String(c.get("text", "...")))
		b.custom_minimum_size = Vector2(660, 52)
		b.pressed.connect(func():
			state["chosen"] = c
			state["done"] = true)
		_choices.add_child(b)
	while not state["done"]:
		await get_tree().process_frame
	for c in _choices.get_children():
		c.queue_free()
	await get_tree().process_frame
	return state["chosen"]
