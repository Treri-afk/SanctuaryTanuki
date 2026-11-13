extends CanvasLayer
## HUD construit en code : point de visée, invite d'action, liste des tâches, phase, messages, outil en main, fondu.

var player: Node
var _prompt: Label
var _tasks_box: VBoxContainer
var _task_labels: Dictionary = {}
var _phase: Label
var _toast: Label
var _held: Label
var _help: Label
var _fade: ColorRect
var _card: Label
var _toast_queue: Array[String] = []
var _toast_busy := false
var _dot: Control
var _banner: Label
var _hint: Label
var ring_phase := -1.0      # cercle de frappe autour du viseur (0 = large, 1 = sur le point) ; -1 = caché
var _pulse := 0.0

const TOOL_NAMES := {&"broom": "Balai", &"rake": "Râteau", &"match": "Allumettes", &"hammer": "Marteau",
	&"shears": "Cisaille", &"sickle": "Serpe", &"bucket": "Seau"}
const TOOL_HINTS := {
	&"broom": "Clic maintenu en avançant : les feuilles s'amassent devant le balai. Poussez le tas jusqu'à un panier.",
	&"rake": "Clic maintenu dans le gravier du jardin sec pour y tracer des lignes.",
	&"match": "Le soir, visez une lanterne et cliquez.",
	&"hammer": "Visez un clou : frappez quand le cercle touche le point.",
	&"shears": "Clic maintenu et passez le viseur sur les rameaux qui dépassent.",
	&"sickle": "Visez une pousse, clic maintenu, puis un geste vif de la souris sur le côté.",
	&"bucket": "Au puits : clic maintenu, tirez la souris vers le bas. Portez sans brusquer.",
}

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_dot = Control.new()
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(_draw_dot)
	root.add_child(_dot)

	_prompt = _label(root, 24, Color(1, 0.96, 0.86))
	_place(_prompt, Vector2(0.5, 0.5), Rect2(-500, 34, 1000, 40))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.14, 0.55)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 4)
	panel.add_child(_tasks_box)
	_phase = _label(_tasks_box, 20, Color(0.96, 0.82, 0.55))
	var optional_started := false
	for id in GameState.task_order:
		if not (GameState.task_data[id] as TaskData).required and id != &"cloche" and not optional_started:
			optional_started = true
			var h := _label(_tasks_box, 15, Color(0.75, 0.72, 0.8))
			h.text = "Facultatif"
		var l := _label(_tasks_box, 18 if not optional_started else 16, Color(0.95, 0.93, 0.88))
		_task_labels[id] = l

	_toast = _label(root, 24, Color(1, 0.96, 0.86))
	_place(_toast, Vector2(0.5, 1.0), Rect2(-450, -170, 900, 80))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0

	_held = _label(root, 20, Color(0.96, 0.93, 0.86))
	_place(_held, Vector2(1.0, 1.0), Rect2(-460, -92, 436, 30))
	_held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint = _label(root, 15, Color(0.9, 0.9, 0.95, 0.85))
	_place(_hint, Vector2(1.0, 1.0), Rect2(-460, -60, 436, 48))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_banner = _label(root, 22, Color(1, 0.95, 0.84))
	_place(_banner, Vector2(0.5, 0.0), Rect2(-460, 60, 920, 110))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_help = _label(root, 16, Color(0.9, 0.9, 0.95, 0.85))
	_place(_help, Vector2(0.0, 1.0), Rect2(24, -46, 900, 30))
	_help.text = "ZQSD : marcher    E ou clic : agir    clic maintenu : geste de l'outil    R : reposer l'outil    Échap : souris"

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_card = _label(root, 36, Color(0.96, 0.92, 0.82))
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.modulate.a = 0.0

	Events.task_progress.connect(_on_progress)
	Events.phase_changed.connect(func(_p): _refresh_phase())
	Events.day_started.connect(func(_d): _refresh_phase(); _refresh_tasks())
	Events.toast.connect(show_toast)
	_coins_setup()
	_refresh_phase()
	_refresh_tasks()
	get_tree().create_timer(14.0).timeout.connect(func():
		create_tween().tween_property(_help, "modulate:a", 0.0, 2.0))

## Ancre un contrôle sur un point de l'écran (0..1) avec un rectangle en pixels relatif à ce point.
func _place(c: Control, anchor: Vector2, r: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y

func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _draw_dot() -> void:
	var active: bool = player != null and player.prompt_text != ""
	_dot.draw_circle(Vector2.ZERO, 5.0 if active else 3.0, Color(1, 0.95, 0.8, 0.95 if active else 0.6))
	_dot.draw_arc(Vector2.ZERO, 5.0 if active else 3.0, 0, TAU, 20, Color(0.1, 0.08, 0.12, 0.9), 1.5)
	if ring_phase >= 0.0:
		var r := lerpf(34.0, 6.0, ring_phase)
		var good := ring_phase >= 0.8
		var c := Color(1.0, 0.85, 0.35, 0.95) if good else Color(1, 0.96, 0.88, 0.75)
		_dot.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.1, 0.08, 0.12, 0.6), 4.0)
		_dot.draw_arc(Vector2.ZERO, r, 0, TAU, 40, c, 2.0)
		_dot.draw_arc(Vector2.ZERO, 9.0, 0, TAU, 24, Color(1.0, 0.85, 0.35, 0.35), 1.5)
	if _pulse > 0.0:
		var pr := lerpf(10.0, 60.0, 1.0 - _pulse)
		_dot.draw_arc(Vector2.ZERO, pr, 0, TAU, 48, Color(1, 0.95, 0.8, _pulse * 0.8), 2.5)

## Anneau lumineux qui s'étend depuis le viseur (frappe parfaite, salut, clap).
func pulse() -> void:
	_pulse = 1.0

## Texte d'étape au centre haut de l'écran (rite...) ; "" pour le cacher.
func set_banner(text: String) -> void:
	_banner.text = text

func _process(dt: float) -> void:
	_coins_process(dt)
	if player == null:
		return
	_prompt.text = player.prompt_text
	_pulse = maxf(_pulse - dt * 2.2, 0.0)
	_dot.queue_redraw()
	var t: StringName = player.tool
	var s: String = TOOL_NAMES.get(t, "")
	if t == &"bucket":
		s = "Seau  —  eau %d %%" % int(round(player.bucket_level * 100.0))
		if player.spilling:
			s += "   (ça déborde !)"
	_held.text = s
	_hint.text = TOOL_HINTS.get(t, "")

func _refresh_phase() -> void:
	_phase.text = "Jour %d — %s" % [GameState.day, GameState.PHASE_NAMES[GameState.phase]]

func _refresh_tasks() -> void:
	for id in _task_labels:
		(_task_labels[id] as Label).visible = not GameState.is_off_today(id)
		_on_progress(id, GameState.progress.get(id, 0), GameState.target.get(id, 1))

func _on_progress(id: StringName, v: int, t: int) -> void:
	if not _task_labels.has(id):
		return
	var data: TaskData = GameState.task_data[id]
	var done := v >= t
	var txt := ("[x] " if done else "[ ] ") + data.label
	if t == 100 and id == &"fontaine":
		txt += "  (%d %%)" % v
	elif t > 1:
		txt += "  (%d/%d)" % [v, t]
	var l: Label = _task_labels[id]
	l.visible = not GameState.is_off_today(id)
	l.text = txt
	l.modulate = Color(0.7, 0.9, 0.6) if done else Color.WHITE

func show_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_busy:
		_run_toasts()

func _run_toasts() -> void:
	_toast_busy = true
	while not _toast_queue.is_empty():
		_toast.text = _toast_queue.pop_front()
		var tw := create_tween()
		tw.tween_property(_toast, "modulate:a", 1.0, 0.4)
		tw.tween_interval(3.6)
		tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
		await tw.finished
	_toast_busy = false

# ---- fondu et cartes de transition ----
func fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished

func set_black() -> void:
	_fade.color.a = 1.0

func show_card(text: String, hold: float) -> void:
	_card.text = text
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)
	await tw.finished

# ---- note (lettre) : panneau de papier, fermé par un clic ----
func show_note(title: String, text: String) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFE6D2")
	sb.border_color = Color("#5A3A26")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 34
	sb.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.position = Vector2(-380, -190)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color("#C8442B"))
	v.add_child(t)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(670, 0)
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", Color("#2A2024"))
	v.add_child(body)
	var hint := Label.new()
	hint.text = "clic pour refermer"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#8A7A6A"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(0.6).timeout
	while true:
		await get_tree().process_frame
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
			break
	panel.queue_free()
	await get_tree().create_timer(0.25).timeout

# ---- jauge de geste (thé...) : barre horizontale sous le viseur, avec une zone cible optionnelle
var _gauge_val := -1.0
var _gauge_zone := Vector2(-1, -1)
var _gauge_label := ""
var _gauge_ctrl: Control

## value < 0 cache la jauge. zone = (min, max) de la zone idéale, ou (-1, -1) sans zone.
func set_gauge(label: String, value: float, zone := Vector2(-1, -1)) -> void:
	if _gauge_ctrl == null:
		_gauge_ctrl = Control.new()
		_gauge_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(_gauge_ctrl, Vector2(0.5, 0.5), Rect2(-180, 80, 360, 46))
		_gauge_ctrl.draw.connect(_draw_gauge)
		_dot.get_parent().add_child(_gauge_ctrl)
	_gauge_val = value
	_gauge_zone = zone
	_gauge_label = label
	_gauge_ctrl.visible = value >= 0.0
	_gauge_ctrl.queue_redraw()

## Cache tout le HUD sauf le fondu (moment contemplatif).
func set_quiet(on: bool) -> void:
	for c in _dot.get_parent().get_children():
		if c != _fade and c != _card:
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0 if on else 1.0, 0.8)

func _draw_gauge() -> void:
	var w := 360.0
	var y := 22.0
	var font := ThemeDB.fallback_font
	_gauge_ctrl.draw_string(font, Vector2(0, 14), _gauge_label, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1, 0.96, 0.88))
	_gauge_ctrl.draw_rect(Rect2(0, y, w, 14), Color(0.1, 0.08, 0.12, 0.6))
	if _gauge_zone.x >= 0.0:
		_gauge_ctrl.draw_rect(Rect2(w * _gauge_zone.x, y, w * (_gauge_zone.y - _gauge_zone.x), 14), Color(1.0, 0.85, 0.35, 0.45))
	_gauge_ctrl.draw_rect(Rect2(2, y + 2, (w - 4) * clampf(_gauge_val, 0.0, 1.0), 10), Color(0.62, 0.78, 0.45, 0.95))
	_gauge_ctrl.draw_rect(Rect2(0, y, w, 14), Color(1, 0.95, 0.85, 0.8), false, 1.5)

# ---- compteur de pièces : caché par défaut, il apparaît quand on gagne ou dépense des pièces,
# quand une action en demande une (show_coins), ou en maintenant Tab (HUD complet). Façon jauge d'endurance.
const COIN_SHOW_TIME := 3.5
var _coin_root: Control
var _coin_label: Label
var _coin_icon: Control
var _coin_shown := 0.0          # valeur affichée (compte animé)
var _coin_timer := 0.0
var _coin_force := 0
var _coin_bounce := 0.0

func _coins_setup() -> void:
	_coin_root = Control.new()
	_coin_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_coin_root, Vector2(1.0, 0.0), Rect2(-210, 24, 186, 64))
	_dot.get_parent().add_child(_coin_root)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.14, 0.55)
	sb.set_corner_radius_all(32)
	sb.content_margin_left = 12
	sb.content_margin_right = 20
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_root.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	bg.add_child(row)
	_coin_icon = Control.new()
	_coin_icon.custom_minimum_size = Vector2(44, 44)
	_coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coin_icon.draw.connect(_draw_coin)
	row.add_child(_coin_icon)
	_coin_label = _label(row, 32, Color(1.0, 0.92, 0.7))
	_coin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coin_label.add_theme_constant_override("outline_size", 7)
	_coin_shown = GameState.coins
	_coin_label.text = str(GameState.coins)
	_coin_root.modulate.a = 0.0
	Events.coins_changed.connect(_on_coins)
	_inv_setup()

## Affiche le compteur tant qu'une action en a besoin (true), puis le laisse disparaître (false).
func show_coins(on: bool) -> void:
	_coin_force = maxi(_coin_force + (1 if on else -1), 0)

func _on_coins(total: int, delta: int) -> void:
	_coin_timer = COIN_SHOW_TIME
	_coin_bounce = 1.0
	if delta != 0:
		var l := Label.new()
		l.text = ("+%d" % delta) if delta > 0 else str(delta)
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if delta > 0 else Color(0.9, 0.75, 0.75))
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(l, Vector2(1.0, 0.0), Rect2(-120, 88, 90, 30))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_dot.get_parent().add_child(l)
		var tw := l.create_tween().set_parallel(true)
		tw.tween_property(l, "offset_top", 70.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.7)
		tw.chain().tween_callback(l.queue_free)
	elif total == GameState.coins:
		_coin_timer = COIN_SHOW_TIME   # « pas assez » : on montre simplement le compte

func _coins_process(dt: float) -> void:
	_inv_process(dt)
	if _coin_root == null:
		return
	_coin_timer = maxf(_coin_timer - dt, 0.0)
	var full: bool = Input.is_key_pressed(KEY_TAB) and player != null and player.input_enabled
	var want := 1.0 if (_coin_timer > 0.0 or _coin_force > 0 or full) else 0.0
	_coin_root.modulate.a = move_toward(_coin_root.modulate.a, want, dt * (4.0 if want > 0.0 else 1.6))
	# le chiffre court vers la vraie valeur
	var target := float(GameState.coins)
	if absf(_coin_shown - target) > 0.01:
		_coin_shown = move_toward(_coin_shown, target, maxf(absf(target - _coin_shown) * dt * 6.0, dt * 8.0))
		_coin_label.text = str(int(round(_coin_shown)))
	_coin_bounce = maxf(_coin_bounce - dt * 3.0, 0.0)
	_coin_icon.queue_redraw()

func _draw_coin() -> void:
	# pièce de cinq yens stylisée : disque doré, liseré, trou carré au centre, léger rebond quand elle change
	var c := Vector2(22, 22)
	var s := 1.0 + 0.18 * sin(_coin_bounce * PI)
	var r := 18.0 * s
	_coin_icon.draw_circle(c + Vector2(1.5, 2.0), r, Color(0.08, 0.05, 0.04, 0.45))
	_coin_icon.draw_circle(c, r, Color("#B8862E"))
	_coin_icon.draw_circle(c, r * 0.86, Color("#DDB04C"))
	_coin_icon.draw_arc(c, r * 0.7, 0, TAU, 32, Color("#B8862E"), 1.6)
	var h := r * 0.26
	_coin_icon.draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), Color(0.12, 0.10, 0.14, 0.85))
	_coin_icon.draw_arc(c + Vector2(-r * 0.3, -r * 0.35), r * 0.45, PI * 1.05, PI * 1.45, 10, Color(1, 0.95, 0.75, 0.8), 2.0)

# ---- journal du gardien : page de fin de journée, à la place du simple fondu au noir
func show_journal(page: Dictionary) -> void:
	show_coins(true)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFE6D2")
	sb.border_color = Color("#5A3A26")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 40
	sb.content_margin_bottom = 34
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, Vector2(0.5, 0.5), Rect2(-430, -300, 860, 600))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var ink := Color("#2A2024")
	var soft := Color("#7A6A60")
	var red := Color("#C8442B")

	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _jlabel(head, "Journal du gardien", 18, soft)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jlabel(head, String(page.get("title", "")), 18, red)
	_jrule(v)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)

	_jlabel(left, "Travaux", 15, soft)
	var tasks: PackedStringArray = page.get("tasks", PackedStringArray())
	if tasks.is_empty():
		_jlabel(left, "—", 19, ink)
	for s in tasks:
		_jlabel(left, "✓  " + s, 19, ink)
	var extra: PackedStringArray = page.get("extra", PackedStringArray())
	for s in extra:
		_jlabel(left, "·  " + s, 17, soft)

	_jlabel(left, "", 6, ink)
	_jlabel(left, "Visiteurs", 15, soft)
	var visitors: Array = page.get("visitors", [])
	if visitors.is_empty():
		_jlabel(left, "Personne n'est monté aujourd'hui.", 18, soft)
	for vis in visitors:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		left.add_child(row)
		var dot := ColorRect.new()
		dot.color = vis["color"]
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		_jlabel(row, String(vis["name"]), 19, ink)
		var d := int(vis["delta"])
		if d != 0:
			_jlabel(row, ("♥ +%d" % d) if d > 0 else ("♡ %d" % d), 18, Color("#D9506E") if d > 0 else soft)

	_jlabel(right, "Offrandes", 15, soft)
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 10)
	right.add_child(coin_row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.draw.connect(func():
		var c := Vector2(22, 22)
		icon.draw_circle(c, 18.0, Color("#B8862E"))
		icon.draw_circle(c, 15.5, Color("#DDB04C"))
		icon.draw_rect(Rect2(c - Vector2(4.7, 4.7), Vector2(9.4, 9.4)), Color("#EFE6D2")))
	coin_row.add_child(icon)
	var gained := int(page.get("coins_in", 0))
	var big := _jlabel(coin_row, "+0", 34, Color("#9A6A1E"))
	_jlabel(right, "pièces reçues aujourd'hui", 14, soft)
	var spent := int(page.get("coins_out", 0))
	if spent > 0:
		_jlabel(right, "%d dépensée%s" % [spent, "s" if spent > 1 else ""], 16, soft)
	_jlabel(right, "Dans le tronc : %d" % int(page.get("coins", 0)), 18, ink)
	if int(page.get("harvest", 0)) > 0:
		_jlabel(right, "Cueillette : %d objet%s" % [int(page["harvest"]), "s" if int(page["harvest"]) > 1 else ""], 16, soft)

	var notes: Array = page.get("notes", [])
	if not notes.is_empty():
		_jlabel(right, "", 6, ink)
		_jlabel(right, "Notes", 15, soft)
		for n in notes.slice(0, 5):
			var nl := _jlabel(right, String(n), 15, ink)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(250, 0)

	_jrule(v)
	var end := _jlabel(v, String(page.get("ending", "")), 18, soft)
	end.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end.custom_minimum_size = Vector2(740, 0)
	var hint := _jlabel(v, "clic pour dormir  ›", 14, soft)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate.a = 0.0

	add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.pivot_offset = Vector2(430, 300)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.6)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# le total des offrandes se compte sous nos yeux
	var count := create_tween()
	count.tween_interval(0.7)
	count.tween_method(func(x: float): big.text = "+%d" % int(round(x)), 0.0, float(gained), clampf(0.25 * gained, 0.4, 1.6))
	count.tween_property(hint, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(1.2).timeout
	var auto := OS.get_cmdline_user_args().has("--autoplay")
	var waited := 0.0
	while true:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > 1.0:
			break
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
			break
	var out := create_tween()
	out.tween_property(panel, "modulate:a", 0.0, 0.5)
	await out.finished
	panel.queue_free()
	show_coins(false)

func _jlabel(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _jrule(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = Color("#C9B99A")
	r.custom_minimum_size = Vector2(0, 2)
	parent.add_child(r)

# ---- mur des ema : une carte par personnage, son ema (qui s'abîme quand le lien se dégrade), ses vœux, son affection
const EMA_STATUS := ["Monte avec plaisir", "Le lien est fragile", "S'éloigne du sanctuaire", "Ne monte plus"]

func show_ema_board(cards: Array) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.1, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, Vector2.ZERO, Rect2(0, 0, 0, 0))
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	add_child(shade)
	var wrap := VBoxContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("separation", 14)
	_place(wrap, Vector2(0.5, 0.5), Rect2(-560, -320, 1120, 640))
	shade.add_child(wrap)
	var title := _jlabel(wrap, "Le présentoir à ema", 28, Color("#F3E7CF"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _jlabel(wrap, "Les vœux des visiteurs. Un ema s'abîme quand le lien se défait.", 16, Color("#C9BCA8"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(grid)
	for c in cards:
		grid.add_child(_ema_card(c))
	var hint := _jlabel(wrap, "clic, E ou Échap pour refermer", 14, Color("#C9BCA8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	wrap.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(shade, "color:a", 0.78, 0.35)
	tw.tween_property(wrap, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(0.45).timeout
	while true:
		await get_tree().process_frame
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ESCAPE):
			break
	var out := create_tween().set_parallel(true)
	out.tween_property(shade, "color:a", 0.0, 0.3)
	out.tween_property(wrap, "modulate:a", 0.0, 0.3)
	await out.finished
	shade.queue_free()
	await get_tree().create_timer(0.15).timeout

func _ema_card(c: Dictionary) -> Control:
	var met: bool = c.get("met", false)
	var st := int(c.get("state", 0))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(362, 238)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFE6D2") if met else Color("#B9AE9A")
	sb.border_color = c["color"] if met else Color("#8E8473")
	sb.border_width_top = 6
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	# l'ema dessiné
	var plaque := Control.new()
	plaque.custom_minimum_size = Vector2(92, 120)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.draw.connect(_draw_ema.bind(plaque, st, met, c["color"]))
	h.add_child(plaque)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var ink := Color("#2A2024")
	var soft := Color("#7A6A60")
	if not met:
		_jlabel(v, "?", 22, Color("#5E564A"))
		_jlabel(v, "Pas encore venu", 15, Color("#5E564A"))
		return panel
	_jlabel(v, String(c["name"]), 21, ink)
	# affection : cinq coeurs, ou des coeurs brisés si elle est négative
	var a := int(c["affection"])
	var mx := maxi(int(c["max"]), 1)
	var hearts := ""
	if a >= 0:
		var full := int(round(5.0 * a / mx))
		hearts = "♥".repeat(full) + "♡".repeat(5 - full)
	else:
		hearts = "✕".repeat(clampi(int(round(5.0 * -a / mx)), 1, 5))
	var hl := _jlabel(v, hearts, 20, Color("#D9506E") if a >= 0 else Color("#6E6470"))
	hl.tooltip_text = "affection %d" % a
	var status := _jlabel(v, EMA_STATUS[clampi(st, 0, 3)], 15, soft if st == 0 else Color("#A0402C"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if int(c.get("missed", 0)) > 0:
		_jlabel(v, "Reparti sans réponse ×%d" % int(c["missed"]), 13, Color("#A0402C"))
	if String(c.get("tastes", "")) != "":
		var tl := _jlabel(v, String(c["tastes"]), 13, Color("#5E7A38"))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(220, 0)
	var wishes: Array = c.get("wishes", [])
	if wishes.is_empty():
		_jlabel(v, "Aucun vœu accroché.", 14, soft)
	for w in wishes.slice(maxi(wishes.size() - 3, 0)):
		var l := _jlabel(v, "Jour %d · « %s »" % [int(w["day"]), String(w["wish"])], 14, ink if st < 3 else soft)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(220, 0)
	return panel

## Ema en forme de maison : bois, cordon rouge, nom ; pâli, fendu ou brisé selon le lien.
func _draw_ema(ctl: Control, st: int, met: bool, col: Color) -> void:
	var wood := Color("#C79A62")
	if not met:
		wood = Color("#8E8473")
	elif st == 1:
		wood = wood.lerp(Color("#D8C8A8"), 0.35)
	elif st >= 2:
		wood = wood.lerp(Color("#9A9284"), 0.55)
	var cx := 46.0
	var top := 26.0
	var pts := PackedVector2Array([Vector2(cx, top), Vector2(cx + 40, top + 22), Vector2(cx + 40, top + 86),
		Vector2(cx - 40, top + 86), Vector2(cx - 40, top + 22)])
	# cordon
	ctl.draw_line(Vector2(cx, 4), Vector2(cx - 10, top + 6), Color("#C8442B"), 2.5)
	ctl.draw_line(Vector2(cx, 4), Vector2(cx + 10, top + 6), Color("#C8442B"), 2.5)
	if st >= 3:
		# brisé : deux morceaux écartés, l'un tombé de travers
		var left := PackedVector2Array([pts[0], Vector2(cx + 6, top + 40), Vector2(cx - 4, top + 86), pts[3], pts[4]])
		var right := PackedVector2Array([pts[0] + Vector2(10, 18), pts[1] + Vector2(10, 18), pts[2] + Vector2(10, 18), Vector2(cx + 6, top + 104), Vector2(cx + 16, top + 58)])
		ctl.draw_colored_polygon(left, wood)
		ctl.draw_colored_polygon(right, wood.darkened(0.12))
		ctl.draw_polyline(left + PackedVector2Array([left[0]]), Color(0.2, 0.15, 0.12), 1.5)
		ctl.draw_polyline(right + PackedVector2Array([right[0]]), Color(0.2, 0.15, 0.12), 1.5)
		return
	ctl.draw_colored_polygon(pts, wood)
	ctl.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.15, 0.12, 0.9), 2.0)
	if met:
		ctl.draw_circle(Vector2(cx, top + 52), 13.0, col.lerp(wood, 0.25 if st == 0 else 0.6))
	if st >= 1:
		var crack := PackedVector2Array([Vector2(cx + 12, top + 6), Vector2(cx + 4, top + 30), Vector2(cx + 14, top + 48)])
		if st >= 2:
			crack.append_array(PackedVector2Array([Vector2(cx + 2, top + 66), Vector2(cx + 8, top + 86)]))
		ctl.draw_polyline(crack, Color(0.22, 0.16, 0.12), 2.0 if st >= 2 else 1.2)

# ---- poches (inventaire) : bandeau en bas de l'écran, caché comme le compteur de pièces ;
# il apparaît quand on ramasse ou donne un objet, ou en maintenant Tab.
var _inv_root: HBoxContainer
var _inv_timer := 0.0

func _inv_setup() -> void:
	_inv_root = HBoxContainer.new()
	_inv_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_inv_root.add_theme_constant_override("separation", 10)
	_place(_inv_root, Vector2(0.5, 1.0), Rect2(-460, -78, 920, 46))
	_dot.get_parent().add_child(_inv_root)
	_inv_root.modulate.a = 0.0
	Events.inventory_changed.connect(func(_i, _c, _d):
		_inv_timer = 3.0
		_inv_rebuild())
	_inv_rebuild()

func _inv_rebuild() -> void:
	for c in _inv_root.get_children():
		c.queue_free()
	if GameState.inventory.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", _inv_style())
		_jlabel(empty, "Poches vides  ·  ramassez kakis, châtaignes, champignons... dans la montagne", 15, Color(0.95, 0.92, 0.85))
		_inv_root.add_child(empty)
		return
	for id in GameState.inventory:
		var it := Story.item(id)
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", _inv_style())
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slot.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var col := Color.from_string(String(it.get("color", "#C8442B")), Color.ORANGE)
		icon.draw.connect(func():
			icon.draw_circle(Vector2(13, 13), 12.0, col.darkened(0.35))
			icon.draw_circle(Vector2(13, 12), 10.0, col)
			icon.draw_circle(Vector2(10, 9), 3.0, col.lightened(0.45)))
		row.add_child(icon)
		_jlabel(row, "%s ×%d" % [String(it.get("name", id)), GameState.item_count(id)], 16, Color(0.97, 0.94, 0.86))
		_inv_root.add_child(slot)
	var cap := _jlabel(_inv_root, "%d/%d" % [GameState.inventory_total(), GameState.INVENTORY_MAX], 14, Color(0.85, 0.82, 0.78))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _inv_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.14, 0.62)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _inv_process(dt: float) -> void:
	if _inv_root == null:
		return
	_inv_timer = maxf(_inv_timer - dt, 0.0)
	var full: bool = Input.is_key_pressed(KEY_TAB) and player != null and player.input_enabled
	var want := 1.0 if (_inv_timer > 0.0 or full) else 0.0
	_inv_root.modulate.a = move_toward(_inv_root.modulate.a, want, dt * (4.0 if want > 0.0 else 1.6))

# ---- saisie d'un court texte (nommer une carpe...) : retourne "" si l'on annule
func ask_text(title: String, placeholder: String) -> String:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFE6D2")
	sb.border_color = Color("#5A3A26")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	_place(panel, Vector2(0.5, 0.5), Rect2(-220, -80, 440, 160))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_jlabel(v, title, 20, Color("#2A2024"))
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = 16
	edit.add_theme_font_size_override("font_size", 22)
	v.add_child(edit)
	_jlabel(v, "Entrée pour valider, Échap pour annuler", 13, Color("#7A6A60"))
	add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	edit.grab_focus()
	var state := {"done": false, "text": ""}
	edit.text_submitted.connect(func(t: String):
		state["text"] = t
		state["done"] = true)
	while not state["done"]:
		await get_tree().process_frame
		if Input.is_key_pressed(KEY_ESCAPE):
			break
	panel.queue_free()
	await get_tree().create_timer(0.15).timeout
	return String(state["text"])
