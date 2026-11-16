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
var _objective: Label
var _objective_keys: Label
var _marker: Control
var _marker_target: Variant = null
var _marker_t := 0.0
var _help_kept := false
var _opt_header: Label
var _task_checks: Dictionary = {}     # id -> UIKit.BrushCheck
var _task_panel: Control
var _stamp: Label
var modal_count := 0       # panneaux ouverts qui se ferment avec Échap (le menu pause attend qu'ils soient fermés)
var _last_progress: Dictionary = {}   # id -> dernière valeur vue (pour ne réagir qu'aux vrais progrès)
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

	# liste du jour : petite feuille de washi en haut à gauche, cases cochées au pinceau (scripts/ui/ui_kit.gd)
	var panel := UIKit.PaperPanel.new(Vector2(22, 16), 9.0, 17.0)
	panel.position = Vector2(2, 2)
	_task_panel = panel
	panel.modulate.a = 0.94
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 0)
	panel.add_child(_tasks_box)
	_phase = UIKit.label(_tasks_box, "", "title", 21, UIKit.VERMILION)
	var optional_started := false
	for id in GameState.task_order:
		if not (GameState.task_data[id] as TaskData).required and id != &"cloche" and not optional_started:
			optional_started = true
			var h := UIKit.label(_tasks_box, "Facultatif", "hand", 15, UIKit.INK_SOFT)
			_opt_header = h
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_tasks_box.add_child(row)
		var chk := UIKit.BrushCheck.new(false)
		chk.custom_minimum_size = Vector2(30, 26) if not optional_started else Vector2(26, 22)
		chk.scale = Vector2.ONE * (0.82 if not optional_started else 0.7)
		row.add_child(chk)
		var l := UIKit.label(row, "", "body", 18 if not optional_started else 16, UIKit.INK if not optional_started else UIKit.INK_SOFT)
		_task_labels[id] = l
		_task_checks[id] = chk

	_toast = _label(root, 24, Color(1, 0.96, 0.86))
	_place(_toast, Vector2(0.5, 1.0), Rect2(-450, -170, 900, 80))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0

	# sceau de fin de tâche : grand texte doux au-dessus du viseur, qui monte et s'efface
	_stamp = _label(root, 30, Color(1.0, 0.88, 0.55))
	_place(_stamp, Vector2(0.5, 0.5), Rect2(-520, -150, 1040, 44))
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.add_theme_constant_override("outline_size", 8)
	_stamp.modulate.a = 0.0

	_held = _label(root, 20, Color(0.96, 0.93, 0.86))
	_place(_held, Vector2(1.0, 1.0), Rect2(-460, -92, 436, 30))
	_held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint = _label(root, 15, Color(0.9, 0.9, 0.95, 0.85))
	_place(_hint, Vector2(1.0, 1.0), Rect2(-460, -60, 436, 48))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_banner = _label(root, 22, Color(1, 0.95, 0.84))
	_place(_banner, Vector2(0.5, 0.0), Rect2(-460, 78, 920, 110))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# objectif courant (premier jour guidé) : une ligne en haut, la commande utile dessous
	_objective = _label(root, 23, Color(1, 0.93, 0.74))
	_place(_objective, Vector2(0.5, 0.0), Rect2(-520, 14, 1040, 34))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_keys = _label(root, 16, Color(0.92, 0.92, 0.96, 0.9))
	_place(_objective_keys, Vector2(0.5, 0.0), Rect2(-520, 46, 1040, 24))
	_objective_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker = Control.new()
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	root.add_child(_marker)

	_help = _label(root, 16, Color(0.9, 0.9, 0.95, 0.85))
	_place(_help, Vector2(0.0, 1.0), Rect2(24, -46, 900, 30))
	_help.text = "ZQSD : marcher    E ou clic : agir    clic maintenu : geste de l'outil    R : reposer l'outil    B : décorer    Échap : pause"

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
	Events.phase_changed.connect(func(_p): _refresh_phase(); _refresh_tasks())
	Events.day_started.connect(func(_d): _refresh_phase(); _refresh_tasks())
	Events.toast.connect(show_toast)
	_coins_setup()
	_refresh_phase()
	_refresh_tasks()
	get_tree().create_timer(14.0).timeout.connect(func():
		if not _help_kept:
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
	# texte posé sur le monde : Alegreya grasse (Klee One pour les grands titres), contour d'encre chaude
	var l := Label.new()
	l.add_theme_font_override("font", UIKit.font("title" if size >= 30 else "body_bold"))
	l.add_theme_font_size_override("font_size", size + (1 if size < 30 else 0))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.07, 0.88))
	l.add_theme_constant_override("outline_size", 6)
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

## Retour quand on avance : petit « toc » et éclat doré de la ligne à chaque étape d'une tâche courte ;
## clochette, sceau au centre et anneau autour du viseur quand une tâche est terminée.
func _feedback(id: StringName, v: int, t: int, data: TaskData) -> void:
	var prev := int(_last_progress.get(id, -1))
	_last_progress[id] = v
	if prev < 0 or v <= prev or GameState.phase == GameState.Phase.NIGHT:
		return      # première valeur de la journée, remise à zéro, ou rien de neuf
	var l: Label = _task_labels[id]
	if v >= t:
		Sfx.play(&"task_done")
		pulse()
		_stamp.text = data.label
		var tw := create_tween()
		_stamp.modulate.a = 0.0
		_stamp.offset_top = -150.0
		_stamp.offset_bottom = -106.0
		tw.set_parallel(true)
		tw.tween_property(_stamp, "modulate:a", 1.0, 0.25)
		tw.tween_property(_stamp, "offset_top", -170.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_stamp, "offset_bottom", -126.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(_stamp, "modulate:a", 0.0, 0.6)
		_flash(l, Color(1.0, 0.85, 0.4))
	elif t <= 12:
		Sfx.play(&"tick")
		_flash(l, Color(1.0, 0.92, 0.65))

func _flash(l: Label, c: Color) -> void:
	var tw := create_tween()
	tw.tween_property(l, "self_modulate", c * 1.25, 0.08)
	tw.tween_property(l, "self_modulate", Color.WHITE, 0.6)

## Objectif courant du guide (texte, commande utile) ; "" pour le cacher.
func set_objective(text: String, keys: String) -> void:
	_objective.text = text
	_objective_keys.text = keys

## Repère doré sur un point du monde (Vector3), ou null pour le cacher.
func set_marker(target: Variant) -> void:
	_marker_target = target

## Garde la barre des commandes affichée (premiers pas du guide), ou la laisse s'effacer.
func keep_help(on: bool) -> void:
	_help_kept = on
	var tw := create_tween()
	tw.tween_property(_help, "modulate:a", 1.0 if on else 0.0, 0.5 if on else 2.0)

## Losange doré au-dessus de la cible si elle est à l'écran, sinon flèche au bord de l'écran.
func _draw_marker() -> void:
	if _marker_target == null or player == null or _fade.color.a > 0.5:
		return
	var cam: Camera3D = player.camera
	var target: Vector3 = _marker_target
	var dist: float = (player as Node3D).global_position.distance_to(target)
	if dist < 2.4:
		return       # on y est : l'invite d'action prend le relais
	var size := _marker.size
	var center := size * 0.5
	var behind := cam.is_position_behind(target)
	var sp := cam.unproject_position(target)
	var margin := 70.0
	var on_screen := not behind and sp.x > margin and sp.x < size.x - margin and sp.y > margin and sp.y < size.y - margin
	var gold := Color(1.0, 0.82, 0.38, 0.95)
	var ink := Color(0.12, 0.09, 0.12, 0.85)
	if on_screen:
		var bob := sin(_marker_t * 3.0) * 4.0
		var c := sp + Vector2(0, -8 + bob)
		var r := 11.0
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.72, 0), c + Vector2(0, r), c + Vector2(-r * 0.72, 0)])
		_marker.draw_colored_polygon(pts, gold)
		pts.append(pts[0])
		_marker.draw_polyline(pts, ink, 2.0, true)
		var font := ThemeDB.fallback_font
		var label := "%d m" % int(round(dist))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_marker.draw_string_outline(font, c + Vector2(-w * 0.5, r + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, ink)
		_marker.draw_string(font, c + Vector2(-w * 0.5, r + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, gold)
		return
	# hors champ : flèche sur le bord, dans la direction de la cible. Derrière soi, elle se met à gauche ou à
	# droite : elle dit de quel côté se retourner.
	var local := cam.global_transform.affine_inverse() * target
	var dir := Vector2(local.x, -local.y)
	if behind:
		dir = Vector2(1.0 if local.x >= 0.0 else -1.0, clampf(-local.y * 0.1, -0.3, 0.3))
	if dir.length() < 0.001:
		dir = Vector2(1, 0)
	dir = dir.normalized()
	var half := center - Vector2(margin, margin)
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var tip := center + dir * k
	var pulse := 1.0 + 0.12 * sin(_marker_t * 4.0)
	var side := Vector2(-dir.y, dir.x)
	var a := tip + dir * 14.0 * pulse
	var b := tip - dir * 10.0 + side * 13.0 * pulse
	var c2 := tip - dir * 10.0 - side * 13.0 * pulse
	var tri := PackedVector2Array([a, b, c2])
	_marker.draw_colored_polygon(tri, gold)
	tri.append(a)
	_marker.draw_polyline(tri, ink, 2.0, true)

func _process(dt: float) -> void:
	_coins_process(dt)
	if player == null:
		return
	_prompt.text = player.prompt_text
	_pulse = maxf(_pulse - dt * 2.2, 0.0)
	_marker_t += dt
	_marker.queue_redraw()
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
		((_task_labels[id] as Label).get_parent() as Control).visible = _task_visible(id)
		_on_progress(id, GameState.progress.get(id, 0), GameState.target.get(id, 1))
	if _opt_header:
		var any := false
		for id in _task_labels:
			if not (GameState.task_data[id] as TaskData).required and _task_visible(id):
				any = true
		_opt_header.visible = any
	if _task_panel:
		_task_panel.reset_size.call_deferred()

## Premier jour guidé : on ne montre que ce qui a du sens maintenant. Lanternes et cloche au soir ;
## les activités facultatives à partir de l'après-midi, ou dès qu'on en a commencé une.
func _task_visible(id: StringName) -> bool:
	if GameState.is_off_today(id):
		return false
	if not GameState.guide:
		return true
	if id == &"lanternes" or id == &"cloche":
		return GameState.phase >= GameState.Phase.EVENING
	if not (GameState.task_data[id] as TaskData).required:
		return GameState.phase != GameState.Phase.MORNING or int(GameState.progress.get(id, 0)) > 0
	return true

func _on_progress(id: StringName, v: int, t: int) -> void:
	if not _task_labels.has(id):
		return
	var data: TaskData = GameState.task_data[id]
	var done := v >= t
	var txt := data.label
	if t == 100 and id == &"fontaine":
		txt += "  (%d %%)" % v
	elif t > 1:
		txt += "  (%d/%d)" % [v, t]
	var l: Label = _task_labels[id]
	var row := l.get_parent() as Control
	_feedback(id, v, t, data)
	var was := row.visible
	row.visible = _task_visible(id)
	if _opt_header and row.visible and not was and not (GameState.task_data[id] as TaskData).required:
		_opt_header.visible = true
	if row.visible != was and _task_panel:
		_task_panel.reset_size.call_deferred()
	l.text = txt
	l.modulate = Color(0.55, 0.62, 0.4) if done else Color.WHITE
	var chk: UIKit.BrushCheck = _task_checks.get(id)
	if chk and chk.done != done:
		chk.done = done
		chk.queue_redraw()

func show_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_busy:
		_run_toasts()

func _run_toasts() -> void:
	_toast_busy = true
	while not _toast_queue.is_empty():
		var text: String = _toast_queue.pop_front()
		while not _toast_queue.is_empty() and _toast_queue[0] == text:
			_toast_queue.pop_front()        # même message en double : une seule fois
		_toast.text = text
		# durée selon la longueur du texte, et plus court quand d'autres messages attendent
		var hold := clampf(1.3 + text.length() * 0.035, 1.8, 4.2)
		if _toast_queue.size() >= 2:
			hold *= 0.6
		var tw := create_tween()
		tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
		tw.tween_interval(hold)
		tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
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
	modal_count += 1
	Sfx.play(&"paper")
	var sh := UIKit.open_sheet(self, Vector2(760, 0), Vector2(54, 40), 9.0)
	var box: VBoxContainer = sh["box"]
	box.add_theme_constant_override("separation", 14)
	UIKit.label(box, title, "title", 24, UIKit.VERMILION)
	var body := UIKit.label(box, text, "hand", 23, UIKit.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 0)
	var hint := UIKit.label(box, "clic pour refermer", "italic", 15, UIKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.6).timeout
	while true:
		await get_tree().process_frame
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
			break
	await UIKit.close_sheet(sh)
	await get_tree().create_timer(0.1).timeout
	modal_count -= 1

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
	sb.bg_color = Color(0.953, 0.922, 0.851, 0.94)
	sb.border_color = Color(0.36, 0.25, 0.18, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(32)
	sb.content_margin_left = 12
	sb.content_margin_right = 20
	sb.shadow_color = Color(0.1, 0.05, 0.02, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
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
	_coin_label = UIKit.label(row, "", "title", 32, Color("#7A4E16"))
	_coin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	modal_count += 1
	Sfx.play(&"paper")
	show_coins(true)
	var sh := UIKit.open_sheet(self, Vector2(900, 0), Vector2(54, 34), 7.0)
	var v: VBoxContainer = sh["box"]
	v.add_theme_constant_override("separation", 6)
	var ink := UIKit.INK
	var soft := UIKit.INK_SOFT
	UIKit.sheet_header(v, "記", "Journal du gardien", String(page.get("title", "")))
	_jrule(v)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 44)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(270, 0)
	right.add_theme_constant_override("separation", 3)
	cols.add_child(right)
	var section := func(parent: Node, t: String) -> void:
		var l := UIKit.label(parent, t, "hand", 17, UIKit.VERMILION)
		l.custom_minimum_size = Vector2(0, 26)

	section.call(left, "Travaux")
	var tasks: PackedStringArray = page.get("tasks", PackedStringArray())
	if tasks.is_empty():
		UIKit.label(left, "—", "body", 19, soft)
	for t in tasks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left.add_child(row)
		var chk := UIKit.BrushCheck.new(true)
		chk.scale = Vector2.ONE * 0.8
		chk.custom_minimum_size = Vector2(26, 26)
		row.add_child(chk)
		UIKit.label(row, t, "body", 19, ink)
	var extra: PackedStringArray = page.get("extra", PackedStringArray())
	for t in extra:
		UIKit.label(left, "      " + t, "italic", 17, soft)

	section.call(left, "Visiteurs")
	var visitors: Array = page.get("visitors", [])
	if visitors.is_empty():
		UIKit.label(left, "Personne n'est monté aujourd'hui.", "italic", 18, soft)
	for vis in visitors:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		left.add_child(row)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var vc: Color = vis["color"]
		dot.draw.connect(func():
			dot.draw_circle(Vector2(9, 9), 8.0, vc)
			dot.draw_arc(Vector2(9, 9), 8.0, 0, TAU, 20, Color(0.3, 0.2, 0.12, 0.6), 1.2, true))
		row.add_child(dot)
		UIKit.label(row, String(vis["name"]), "body", 19, ink)
		var d := int(vis["delta"])
		if d != 0:
			UIKit.label(row, ("♥ +%d" % d) if d > 0 else ("♡ %d" % d), "hand", 18, Color("#C9405A") if d > 0 else soft)

	section.call(right, "Offrandes")
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 10)
	right.add_child(coin_row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.draw.connect(func():
		var c := Vector2(22, 22)
		icon.draw_circle(c + Vector2(1, 2), 18.0, Color(0, 0, 0, 0.15))
		icon.draw_circle(c, 18.0, Color("#B8862E"))
		icon.draw_circle(c, 15.5, Color("#DDB04C"))
		icon.draw_rect(Rect2(c - Vector2(4.7, 4.7), Vector2(9.4, 9.4)), Color("#F3EBD9")))
	coin_row.add_child(icon)
	var gained := int(page.get("coins_in", 0))
	var big := UIKit.label(coin_row, "+0", "title", 34, Color("#8A5A16"))
	UIKit.label(right, "pièces reçues aujourd'hui", "italic", 15, soft)
	var spent := int(page.get("coins_out", 0))
	if spent > 0:
		UIKit.label(right, "%d dépensée%s" % [spent, "s" if spent > 1 else ""], "body", 16, soft)
	UIKit.label(right, "Dans le tronc : %d" % int(page.get("coins", 0)), "body", 18, ink)
	if int(page.get("harvest", 0)) > 0:
		UIKit.label(right, "Cueillette : %d objet%s" % [int(page["harvest"]), "s" if int(page["harvest"]) > 1 else ""], "body", 16, soft)
	var notes: Array = page.get("notes", [])
	if not notes.is_empty():
		section.call(right, "Notes")
		for n in notes.slice(0, 5):
			var nl := UIKit.label(right, String(n), "hand", 15, ink)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(270, 0)

	_jrule(v)
	var end := UIKit.label(v, String(page.get("ending", "")), "hand", 19, soft)
	end.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end.custom_minimum_size = Vector2(780, 0)
	var hint := UIKit.label(v, "clic pour dormir  ›", "italic", 15, soft)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate.a = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	await UIKit.close_sheet(sh)
	show_coins(false)
	modal_count -= 1

func _jlabel(parent: Node, text: String, size: int, color: Color) -> Label:
	# police du kit d'interface : titres en Klee One (écriture au crayon), texte en Alegreya
	var l := UIKit.label(parent, text, "title" if size >= 24 else "body", size + (1 if size < 24 else 0), color)
	return l

func _jrule(parent: Node) -> void:
	parent.add_child(UIKit.BrushRule.new(12))

# ---- mur des ema : une carte par personnage, son ema (qui s'abîme quand le lien se dégrade), ses vœux, son affection
const EMA_STATUS := ["Monte avec plaisir", "Le lien est fragile", "S'éloigne du sanctuaire", "Ne monte plus"]

func show_ema_board(cards: Array) -> void:
	modal_count += 1
	Sfx.play(&"paper")
	var sh := UIKit.open_sheet(self, Vector2(1140, 0), Vector2(46, 30), 5.0)
	var box: VBoxContainer = sh["box"]
	UIKit.sheet_header(box, "絵馬", "Le présentoir à ema", "Les vœux des visiteurs. Un ema s'abîme quand le lien se défait.")
	_jrule(box)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	var i := 0
	for c in cards:
		var card := _ema_card(c)
		grid.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.15 + 0.05 * i)
		i += 1
	var hint := UIKit.label(box, "clic, E ou Échap pour refermer", "italic", 15, UIKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.45).timeout
	while true:
		await get_tree().process_frame
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ESCAPE):
			break
	await UIKit.close_sheet(sh)
	await get_tree().create_timer(0.15).timeout
	modal_count -= 1

func _ema_card(c: Dictionary) -> Control:
	var met: bool = c.get("met", false)
	var st := int(c.get("state", 0))
	var panel := UIKit.card(c["color"] if met else Color.GRAY, not met)
	panel.custom_minimum_size = Vector2(336, 214)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	# l'ema dessiné
	var plaque := Control.new()
	plaque.custom_minimum_size = Vector2(92, 128)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.draw.connect(_draw_ema.bind(plaque, st, met, c["color"]))
	h.add_child(plaque)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var ink := UIKit.INK
	var soft := UIKit.INK_SOFT
	var red := Color("#A0402C")
	if not met:
		UIKit.label(v, "?", "title", 30, Color("#7A7060"))
		UIKit.label(v, "Pas encore venu", "italic", 16, Color("#6A6050"))
		return panel
	UIKit.label(v, String(c["name"]), "title", 22, ink)
	var wrap := func(l: Label) -> void:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(196, 0)
	if c.get("self", false):
		# les vœux du gardien : pas de cœurs ni de lien, seulement ce qu'on a écrit
		for w in (c.get("wishes", []) as Array).slice(maxi((c.get("wishes", []) as Array).size() - 4, 0)):
			wrap.call(UIKit.label(v, "Jour %d · « %s »" % [int(w["day"]), String(w["wish"])], "hand", 15, ink))
		return panel
	var hearts := UIKit.Hearts.new(int(c["affection"]), int(c["max"]))
	hearts.tooltip_text = "affection %d" % int(c["affection"])
	v.add_child(hearts)
	wrap.call(UIKit.label(v, EMA_STATUS[clampi(st, 0, 3)], "italic", 15, soft if st == 0 else red))
	if int(c.get("missed", 0)) > 0:
		UIKit.label(v, "Reparti sans réponse ×%d" % int(c["missed"]), "italic", 14, red)
	if String(c.get("tastes", "")) != "":
		wrap.call(UIKit.label(v, String(c["tastes"]), "body", 14, UIKit.MOSS.darkened(0.1)))
	var wishes: Array = c.get("wishes", [])
	if wishes.is_empty():
		UIKit.label(v, "Aucun vœu accroché.", "italic", 15, soft)
	for w in wishes.slice(maxi(wishes.size() - 3, 0)):
		wrap.call(UIKit.label(v, "Jour %d · « %s »" % [int(w["day"]), String(w["wish"])], "hand", 15, ink if st < 3 else soft))
	return panel

## Ema en forme de maison : bois veiné, petit toit, cordon rouge, rond de la couleur du personnage ;
## pâli, fendu ou brisé selon le lien.
func _draw_ema(ctl: Control, st: int, met: bool, col: Color) -> void:
	var wood := Color("#C99C64")
	if not met:
		wood = Color("#9A9080")
	elif st == 1:
		wood = wood.lerp(Color("#D8C8A8"), 0.35)
	elif st >= 2:
		wood = wood.lerp(Color("#9A9284"), 0.55)
	var line := Color(0.3, 0.2, 0.12, 0.85)
	var cx := 46.0
	var top := 30.0
	var pts := PackedVector2Array([Vector2(cx, top), Vector2(cx + 40, top + 22), Vector2(cx + 40, top + 88),
		Vector2(cx - 40, top + 88), Vector2(cx - 40, top + 22)])
	# ombre portée
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(2, 4))
	ctl.draw_colored_polygon(sh, Color(0.2, 0.1, 0.05, 0.15))
	# cordon et nœud
	ctl.draw_line(Vector2(cx, 6), Vector2(cx - 12, top + 8), Color("#B83A26"), 2.5, true)
	ctl.draw_line(Vector2(cx, 6), Vector2(cx + 12, top + 8), Color("#B83A26"), 2.5, true)
	ctl.draw_circle(Vector2(cx, 6), 3.5, Color("#B83A26"))
	if st >= 3:
		# brisé : deux morceaux écartés, l'un tombé de travers
		var left := PackedVector2Array([pts[0], Vector2(cx + 6, top + 40), Vector2(cx - 4, top + 88), pts[3], pts[4]])
		var right := PackedVector2Array([pts[0] + Vector2(10, 18), pts[1] + Vector2(10, 18), pts[2] + Vector2(10, 18), Vector2(cx + 6, top + 106), Vector2(cx + 16, top + 58)])
		ctl.draw_colored_polygon(left, wood)
		ctl.draw_colored_polygon(right, wood.darkened(0.12))
		ctl.draw_polyline(left + PackedVector2Array([left[0]]), line, 1.5, true)
		ctl.draw_polyline(right + PackedVector2Array([right[0]]), line, 1.5, true)
		return
	ctl.draw_colored_polygon(pts, wood)
	# veines du bois
	for k in 5:
		var y := top + 32 + k * 11.0
		var vein := PackedVector2Array()
		for i in 9:
			var x := cx - 36 + i * 9.0
			vein.append(Vector2(x, y + sin(i * 0.9 + k * 1.7) * 1.6))
		ctl.draw_polyline(vein, Color(0.45, 0.28, 0.14, 0.18), 1.0, true)
	# petit toit (bande plus sombre le long des pentes)
	ctl.draw_polyline(PackedVector2Array([pts[4], pts[0], pts[1]]), wood.darkened(0.35), 6.0, true)
	ctl.draw_polyline(pts + PackedVector2Array([pts[0]]), line, 1.6, true)
	if met:
		var cc := Vector2(cx, top + 56)
		ctl.draw_circle(cc, 15.0, Color(1, 1, 1, 0.25))
		ctl.draw_circle(cc, 13.0, col.lerp(wood, 0.2 if st == 0 else 0.6))
		ctl.draw_arc(cc, 13.0, 0, TAU, 28, line, 1.2, true)
	if st >= 1:
		var crack := PackedVector2Array([Vector2(cx + 12, top + 6), Vector2(cx + 4, top + 30), Vector2(cx + 14, top + 48)])
		if st >= 2:
			crack.append_array(PackedVector2Array([Vector2(cx + 2, top + 68), Vector2(cx + 8, top + 88)]))
		ctl.draw_polyline(crack, Color(0.22, 0.16, 0.12), 2.0 if st >= 2 else 1.2, true)

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
		UIKit.label(empty, "Poches vides  ·  ramassez kakis, châtaignes, champignons... dans la montagne", "italic", 16, UIKit.INK_SOFT)
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
		UIKit.label(row, "%s ×%d" % [String(it.get("name", id)), GameState.item_count(id)], "body", 17, UIKit.INK)
		_inv_root.add_child(slot)
	var cap := _label(_inv_root, 15, Color(0.97, 0.93, 0.84))
	cap.text = "%d/%d" % [GameState.inventory_total(), GameState.INVENTORY_MAX]
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _inv_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.953, 0.922, 0.851, 0.94)
	sb.border_color = Color(0.36, 0.25, 0.18, 0.45)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0.1, 0.05, 0.02, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
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

## Boutique : panneau de papier, une ligne par objet (nom, description, réserve, prix, bouton Acheter).
## Renvoie l'id choisi, ou "" quand on ferme (bouton ou Échap).
func show_shop(title: String, rows: Array) -> String:
	return await show_list("店", title, "Les offrandes des visiteurs font vivre le sanctuaire. On les dépense ici.",
		"%d pièce%s" % [GameState.coins, "s" if GameState.coins > 1 else ""], rows, true)

## Liste de papier générique (boutique, décoration) : une ligne par entrée {id, name, desc, note, ok, why}, plus
## facultatifs : price (caché si < 0), action (texte du bouton, « Acheter » par défaut), color (pastille).
func show_list(kanji: String, title: String, subtitle: String, right: String, rows: Array, coins := false) -> String:
	modal_count += 1
	var sh := UIKit.open_sheet(self, Vector2(900, 0), Vector2(50, 32), 11.0)
	var v: VBoxContainer = sh["box"]
	v.add_theme_constant_override("separation", 8)
	UIKit.sheet_header(v, kanji, title, subtitle, right)
	_jrule(v)
	var state := {"done": false, "id": ""}
	# liste longue (boutique avec la déco) : elle défile au lieu de sortir de l'écran
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rows.size() > 6:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(0, minf(470.0, get_viewport().get_visible_rect().size.y * 0.56))
		sc.add_child(list)
		v.add_child(sc)
	else:
		v.add_child(list)
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)
		var col := Color.from_string(String(r.get("color", Shop.item(String(r["id"])).get("color", "#C9A06A"))), Color("#C9A06A"))
		if String(r["id"]).begins_with("priere_retour:"):
			col = Color("#E8D9B0")
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(40, 40)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.draw.connect(func():
			ic.draw_circle(Vector2(21, 22), 17.0, Color(0, 0, 0, 0.12))
			ic.draw_circle(Vector2(20, 20), 17.0, col)
			ic.draw_circle(Vector2(14, 14), 5.0, col.lightened(0.35))
			ic.draw_arc(Vector2(20, 20), 17.0, 0, TAU, 28, Color(0.3, 0.2, 0.12, 0.6), 1.3, true))
		row.add_child(ic)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", -2)
		row.add_child(info)
		var name_line := HBoxContainer.new()
		name_line.add_theme_constant_override("separation", 12)
		info.add_child(name_line)
		UIKit.label(name_line, String(r["name"]), "title", 21, UIKit.INK)
		if String(r.get("note", "")) != "":
			var nt := UIKit.label(name_line, String(r["note"]), "hand", 15, UIKit.MOSS)
			nt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var d := UIKit.label(info, String(r["desc"]), "italic", 15, UIKit.INK_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(480, 0)
		if int(r.get("price", -1)) >= 0:
			var price := UIKit.label(row, "%d pièce%s" % [int(r["price"]), "s" if int(r["price"]) > 1 else ""], "hand", 19, Color("#8A5A16"))
			price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			price.custom_minimum_size = Vector2(86, 0)
		var b := UIKit.button(String(r.get("action", "Acheter")) if r["ok"] else String(r["why"]))
		b.disabled = not r["ok"]
		b.custom_minimum_size = Vector2(170, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 16)
		var id := String(r["id"])
		b.pressed.connect(func():
			state["id"] = id
			state["done"] = true)
		row.add_child(b)
	_jrule(v)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	var close := UIKit.button("Refermer  (Échap)")
	close.pressed.connect(func(): state["done"] = true)
	foot.add_child(close)
	if coins:
		show_coins(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_cmdline_user_args().has("--autoplay"):
		state["done"] = true
	while not state["done"]:
		await get_tree().process_frame
		if Input.is_key_pressed(KEY_ESCAPE):
			break
	await UIKit.close_sheet(sh)
	if coins:
		show_coins(false)
	await get_tree().create_timer(0.12).timeout
	modal_count -= 1
	return String(state["id"])

func show_calendar(d: Dictionary) -> String:
	modal_count += 1
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.03, 0.0)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var sheet: Array = UIKit.paper(Vector2(1000, 640), Vector2(50, 34), 16.0, 3.0)
	var root: Control = sheet[0]
	var v: VBoxContainer = sheet[1]
	v.add_theme_constant_override("separation", 8)
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = -root.size / 2.0
	shade.add_child(root)
	# en-tête : sceau, titre, compte à rebours
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var seal := UIKit.Hanko.new("暦", 52, false, 2.0)
	seal.rotation = -0.06
	head.add_child(seal)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	UIKit.label(titles, String(d.get("title", "Calendrier")), "title", 30, UIKit.INK)
	UIKit.label(titles, "Automne, au sanctuaire de la montagne", "italic", 16, UIKit.INK_SOFT)
	var cd := UIKit.label(head, String(d.get("countdown", "")), "hand", 22, UIKit.VERMILION)
	cd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# fiches des jours
	var cord := UIKit.DayCord.new(int(d.get("days", 5)), int(d.get("today", 1)), int(d.get("festival_day", 0)),
		String(d.get("festival", "")), String(d.get("festival_sub", "")))
	v.add_child(cord)
	v.add_child(UIKit.BrushRule.new(10))
	UIKit.label(v, "Préparatifs de %s" % String(d.get("festival", "la fête")), "title", 22, UIKit.INK)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for r in d.get("preps", []):
		var done := bool(r.get("done", false))
		var chk := UIKit.BrushCheck.new(done)
		chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(chk)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", -2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.custom_minimum_size = Vector2(400, 0)
		grid.add_child(info)
		UIKit.label(info, String(r.get("label", "")), "body", 19, UIKit.MOSS.darkened(0.15) if done else UIKit.INK)
		if String(r.get("detail", "")) != "":
			UIKit.label(info, String(r["detail"]), "italic", 14, UIKit.INK_SOFT)
		var right := HBoxContainer.new()
		right.add_theme_constant_override("separation", 6)
		right.alignment = BoxContainer.ALIGNMENT_END
		right.custom_minimum_size = Vector2(360, 38)
		grid.add_child(right)
		var id := String(r.get("id", ""))
		var val := int(r.get("value", 0))
		var tgt := int(r.get("target", 1))
		match id:
			"lanternes":
				right.add_child(UIKit.Pips.new("lantern", val, tgt))
			"nobori":
				right.add_child(UIKit.Pips.new("banner", val, tgt))
			"offrandes":
				right.add_child(_offering_pips(r.get("pips", [])))
			"invitations":
				var flow := HFlowContainer.new()
				flow.alignment = FlowContainer.ALIGNMENT_END
				flow.add_theme_constant_override("h_separation", 6)
				flow.add_theme_constant_override("v_separation", 4)
				flow.custom_minimum_size = Vector2(360, 0)
				flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				right.add_child(flow)
				for nm in r.get("names", []):
					flow.add_child(UIKit.chip(String(nm)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var note := UIKit.label(foot, "On ne rate pas une fête : elle ressemble à ce qu'on a préparé, et à ceux qu'on a invités.",
		"italic", 15, UIKit.INK_SOFT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var state := {"done": false, "id": ""}
	var close := UIKit.button("Refermer")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): state["done"] = true)
	foot.add_child(close)
	if String(d.get("action", "")) != "":
		var act := UIKit.button(String(d["action"]), true)
		act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		act.pressed.connect(func():
			state["id"] = "action"
			state["done"] = true)
		foot.add_child(act)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# entrée : le voile tombe, la feuille se pose, les fiches descendent, les tampons claquent
	root.pivot_offset = root.size / 2.0
	root.scale = Vector2.ONE * 0.96
	root.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(shade, "color:a", 0.62, 0.3)
	tw.tween_property(root, "modulate:a", 1.0, 0.25)
	tw.tween_property(root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seal.stamp(0.25)
	cord.appear.call_deferred()
	if OS.get_cmdline_user_args().has("--autoplay"):
		await get_tree().create_timer(0.4).timeout
		state["done"] = true
	while not state["done"]:
		await get_tree().process_frame
		if Input.is_key_pressed(KEY_ESCAPE):
			break
	var out := create_tween().set_parallel(true)
	out.tween_property(shade, "color:a", 0.0, 0.2)
	out.tween_property(root, "modulate:a", 0.0, 0.2)
	await out.finished
	shade.queue_free()
	await get_tree().create_timer(0.1).timeout
	modal_count -= 1
	return String(state["id"])

## Offrandes : une icône par objet attendu, colorée quand il est sur la table.
func _offering_pips(pips: Array) -> Control:
	var cols := []
	for pp in pips:
		cols.append(pp["color"])
	var c := UIKit.Pips.new("items", 0, cols.size(), cols)
	c.set_meta("on", pips.map(func(x): return bool(x["on"])))
	c.draw.connect(func():
		var ons: Array = c.get_meta("on")
		for i in ons.size():
			if ons[i]:
				var cc := Vector2(12.0 + i * 22.0, 18)
				c.draw_circle(cc + Vector2(0, 1.5), 8.0, Color(0, 0, 0, 0.12))
				c.draw_circle(cc, 8.0, cols[i])
				c.draw_circle(cc + Vector2(-2.5, -2.5), 2.6, (cols[i] as Color).lightened(0.35)))
	return c

# ---- saisie d'un court texte (nommer une carpe...) : retourne "" si l'on annule
func ask_text(title: String, placeholder: String, max_len: int = 16) -> String:
	modal_count += 1
	var w := 460 if max_len <= 16 else 660
	var sh := UIKit.open_sheet(self, Vector2(w, 0), Vector2(44, 28), 13.0)
	var v: VBoxContainer = sh["box"]
	v.add_theme_constant_override("separation", 12)
	UIKit.label(v, title, "title", 24, UIKit.INK)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_len
	edit.add_theme_font_override("font", UIKit.font("hand"))
	edit.add_theme_font_size_override("font_size", 26)
	edit.add_theme_color_override("font_color", UIKit.INK)
	edit.add_theme_color_override("font_placeholder_color", Color(0.36, 0.25, 0.18, 0.35))
	edit.add_theme_color_override("caret_color", UIKit.VERMILION)
	edit.add_theme_color_override("selection_color", Color(0.75, 0.24, 0.16, 0.25))
	var line := StyleBoxFlat.new()
	line.bg_color = Color(1, 1, 1, 0.25)
	line.border_color = UIKit.INK_SOFT
	line.border_width_bottom = 2
	line.content_margin_left = 6
	line.content_margin_bottom = 4
	edit.add_theme_stylebox_override("normal", line)
	edit.add_theme_stylebox_override("focus", line)
	v.add_child(edit)
	UIKit.label(v, "Entrée pour valider, Échap pour annuler", "italic", 15, UIKit.INK_SOFT)
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
	await UIKit.close_sheet(sh)
	await get_tree().create_timer(0.1).timeout
	modal_count -= 1
	return String(state["text"])

