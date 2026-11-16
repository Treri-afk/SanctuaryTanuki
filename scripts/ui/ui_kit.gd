class_name UIKit
extends RefCounted
## Habillage de l'interface (maquette, d'abord sur le tableau de la fête) : papier washi, encre, tampons hanko,
## boutons de bois et de laque, petites icônes peintes. Tout est dessiné par le code (shader ui_paper, _draw),
## sans texture. Polices libres (OFL) dans assets/fonts : Klee One (titres, écriture au crayon japonaise),
## Alegreya (texte, sérif de livre de contes).

const INK := Color("#3A2A20")
const INK_SOFT := Color("#6E5A4A")
const INK_FAINT := Color(0.36, 0.25, 0.18, 0.28)
const PAPER := Color("#F3EBD9")
const PAPER_AGED := Color("#E9DCC0")
const VERMILION := Color("#BF3E28")
const LACQUER := Color("#A8321F")
const GOLD := Color("#C9A24E")
const GOLD_PALE := Color("#F2DFAA")
const MOSS := Color("#5E7A38")
const WOOD := Color("#7A4E30")
const WOOD_DARK := Color("#4E3020")
const INDIGO := Color("#2E3A5C")
const PAPER_SHADER := preload("res://shaders/ui_paper.gdshader")

static var _fonts: Dictionary = {}
static var _theme: Theme

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		"title":
			f = load("res://assets/fonts/KleeOne-SemiBold.ttf")
		"hand":
			f = load("res://assets/fonts/KleeOne-Regular.ttf")
		"italic", "body", "body_bold":
			var fv := FontVariation.new()
			fv.base_font = load("res://assets/fonts/Alegreya-Italic-Variable.ttf" if kind == "italic" else "res://assets/fonts/Alegreya-Variable.ttf")
			var ts := TextServerManager.get_primary_interface()
			fv.variation_opentype = {ts.name_to_tag("wght"): 700 if kind == "body_bold" else 500}
			f = fv
	_fonts[kind] = f
	return f

## Thème commun : police de texte, boutons de bois (secondaires) ; les boutons de laque passent par button().
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Button", font("title"))
	t.set_font_size("font_size", "Button", 18)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "Button", _wood_box(st))
	t.set_color("font_color", "Button", Color("#F6E9CF"))
	t.set_color("font_hover_color", "Button", Color("#FFF6E2"))
	t.set_color("font_pressed_color", "Button", Color("#E9D8B4"))
	t.set_color("font_focus_color", "Button", Color("#F6E9CF"))
	t.set_color("font_disabled_color", "Button", Color(0.95, 0.9, 0.8, 0.45))
	_theme = t
	return t

static func _box(bg: Color, border: Color, bottom: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.border_width_bottom = bottom
	b.set_corner_radius_all(radius)
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 8
	b.content_margin_bottom = 8 + bottom - 1
	b.shadow_color = Color(0.1, 0.05, 0.02, 0.25)
	b.shadow_size = 3
	b.shadow_offset = Vector2(0, 2)
	b.anti_aliasing = true
	return b

static func _wood_box(state: String) -> StyleBox:
	match state:
		"hover":
			return _box(WOOD.lightened(0.1), WOOD_DARK, 4, 7)
		"pressed":
			var p := _box(WOOD.darkened(0.08), WOOD_DARK, 1, 7)
			p.content_margin_top = 11
			return p
		"disabled":
			return _box(Color(0.48, 0.38, 0.3, 0.5), Color(0.3, 0.2, 0.14, 0.4), 3, 7)
		"focus":
			var f := StyleBoxEmpty.new()
			return f
	return _box(WOOD, WOOD_DARK, 4, 7)

## Bouton : bois (secondaire) ou laque vermillon à liseré doré (action principale). Léger soulèvement au survol.
static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme()
	b.custom_minimum_size = Vector2(0, 46)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		var n := _box(LACQUER, GOLD, 4, 8)
		n.set_border_width_all(2)
		n.border_width_bottom = 5
		n.border_color = Color("#7A2414")
		n.content_margin_left = 30
		n.content_margin_right = 30
		var h := n.duplicate() as StyleBoxFlat
		h.bg_color = VERMILION.lightened(0.06)
		var p := n.duplicate() as StyleBoxFlat
		p.border_width_bottom = 2
		p.content_margin_top = 11
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_color_override("font_color", Color("#FBEFD2"))
		b.add_theme_color_override("font_hover_color", Color("#FFF8E6"))
		b.add_theme_font_size_override("font_size", 20)
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.12).set_trans(Tween.TRANS_SINE))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE))
	b.pressed.connect(func(): Sfx.play(&"ui_click"))
	return b

## Feuille de papier : retourne [racine (avec ombre et barbes), conteneur de contenu].
static func paper(sz: Vector2, padding := Vector2(54, 44), border := 16.0, seed := 1.0) -> Array:
	const M := 26.0
	var root := ColorRect.new()
	root.color = Color.WHITE
	root.size = sz + Vector2(M, M) * 2.0
	root.custom_minimum_size = root.size
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	mat.set_shader_parameter("size", root.size)
	mat.set_shader_parameter("margin", M)
	mat.set_shader_parameter("border_inset", border)
	mat.set_shader_parameter("seed", seed)
	root.material = mat
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.position = Vector2(M, M) + padding
	box.size = sz - padding * 2.0
	box.custom_minimum_size = box.size
	box.theme = theme()
	root.add_child(box)
	return [root, box]

static func label(parent: Node, text: String, kind := "body", size := 18, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l

## Tracé d'encre effilé (séparateur au pinceau).
class BrushRule extends Control:
	var color := Color(0.36, 0.25, 0.18, 0.55)
	func _init(h := 14.0) -> void:
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		var n := 40
		for i in n + 1:
			var t := float(i) / n
			var th := sin(t * PI) * 2.2 * (0.8 + 0.2 * sin(t * 23.0)) + 0.2
			var yy := y + sin(t * 5.0) * 0.8
			top.append(Vector2(t * w, yy - th))
			bot.append(Vector2(t * w, yy + th))
		bot.reverse()
		top.append_array(bot)
		draw_colored_polygon(top, color)

## Sceau hanko : carré (ou rond) vermillon aux bords un peu irréguliers, caractère en réserve. stamp() : « tchac ».
class Hanko extends Control:
	var text := "暦"
	var round := false
	var color := Color(0.75, 0.24, 0.16, 0.92)
	var seed := 0.0
	func _init(t := "暦", s := 48.0, is_round := false, sd := 0.0) -> void:
		text = t
		round = is_round
		seed = sd
		custom_minimum_size = Vector2(s, s)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = size / 2.0
	func _wob(i: int) -> float:
		return sin(i * 12.9898 + seed * 78.233) * 0.5 + 0.5
	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.46
		var pts := PackedVector2Array()
		var n := 36
		for i in n:
			var a := TAU * i / n
			var p: Vector2
			if round:
				p = c + Vector2(cos(a), sin(a)) * r
			else:
				var d := Vector2(cos(a), sin(a))
				var k := 1.0 / maxf(absf(d.x), absf(d.y))
				p = c + d * r * minf(k, 1.42) * 0.97
			pts.append(p + Vector2(_wob(i) - 0.5, _wob(i + 50) - 0.5) * size.x * 0.035)
		draw_colored_polygon(pts, color)
		# filet intérieur en réserve
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.82)
		inner.append(inner[0])
		draw_polyline(inner, Color(0.97, 0.92, 0.84, 0.75), maxf(size.x * 0.03, 1.2), true)
		var f := UIKit.font("title")
		var fs := int(size.x * (0.5 if text.length() == 1 else 0.3))
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, c + Vector2(-tw.x / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.94, 0.86, 0.95))
	func stamp(delay := 0.0) -> void:
		scale = Vector2.ONE * 1.7
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(self, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(self, "scale", Vector2.ONE * 0.94, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Case cochée au pinceau.
class BrushCheck extends Control:
	var done := false
	func _init(d := false) -> void:
		done = d
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ink := Color(0.36, 0.25, 0.18, 0.85)
		var pts := [Vector2(5, 7), Vector2(24, 5.5), Vector2(25, 25), Vector2(6, 25.5), Vector2(5, 6)]
		for i in 4:
			draw_line(pts[i], pts[i + 1], ink, 1.6 + 0.4 * (i % 2), true)
		if done:
			var stroke := PackedVector2Array([Vector2(7, 15), Vector2(10, 14), Vector2(14, 21), Vector2(28, -1),
				Vector2(29, 1), Vector2(15, 25), Vector2(12, 25)])
			draw_colored_polygon(stroke, Color(0.75, 0.24, 0.16, 0.95))

## Rangée d'icônes peintes qui se remplissent : lanternes, banderoles, ou objets d'offrande colorés.
class Pips extends Control:
	var kind := "lantern"
	var filled := 0
	var total := 1
	var colors: Array = []        # pour "items" : une couleur par icône
	func _init(k: String, f: int, t: int, cols: Array = []) -> void:
		kind = k
		filled = f
		total = t
		colors = cols
		custom_minimum_size = Vector2(total * (22 if kind == "items" else 24) + 4, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var faint := Color(0.36, 0.25, 0.18, 0.3)
		for i in total:
			var on := i < filled
			var x := 12.0 + i * (22.0 if kind == "items" else 24.0)
			match kind:
				"lantern":
					var c := Vector2(x, 18)
					if on:
						draw_line(c + Vector2(0, -15), c + Vector2(0, -10), UIKit.INK, 1.2)
						draw_rect(Rect2(c.x - 5, c.y - 11, 10, 3), UIKit.INK)
						draw_rect(Rect2(c.x - 5, c.y + 8, 10, 3), UIKit.INK)
						_ellipse(c, Vector2(8, 9), Color("#FBEFD8"))
						draw_rect(Rect2(c.x - 7.5, c.y - 7, 15, 2.5), UIKit.VERMILION)
						draw_rect(Rect2(c.x - 7.5, c.y + 4.5, 15, 2.5), UIKit.VERMILION)
						for k in 3:
							draw_line(c + Vector2(-6.5, -3 + k * 3), c + Vector2(6.5, -3 + k * 3), Color(0.6, 0.45, 0.3, 0.35), 1.0)
					else:
						_ellipse_line(c, Vector2(8, 9), faint)
				"banner":
					var r := Rect2(x - 5, 4, 11, 26)
					if on:
						draw_line(Vector2(x - 6, 2), Vector2(x - 6, 32), UIKit.WOOD_DARK, 1.6)
						draw_rect(r, UIKit.INDIGO if i % 2 == 0 else UIKit.LACQUER)
						draw_circle(Vector2(x + 0.5, 11), 3.2, Color("#F1E8D2"))
					else:
						draw_rect(r, faint, false, 1.2)
				_:
					var col: Color = colors[i] if i < colors.size() else UIKit.INK
					var cc := Vector2(x, 18)
					if on:
						draw_circle(cc + Vector2(0, 1.5), 8.0, Color(0, 0, 0, 0.12))
						draw_circle(cc, 8.0, col)
						draw_circle(cc + Vector2(-2.5, -2.5), 2.6, col.lightened(0.35))
					else:
						draw_arc(cc, 7.5, 0, TAU, 20, faint, 1.2, true)
	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.6, 0.4, 0.25, 0.6), 1.0, true)
	func _ellipse_line(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 21:
			var a := TAU * i / 20.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_polyline(pts, col, 1.2, true)

## Petite étiquette de papier (nom d'un invité).
static func chip(text: String, col := Color("#EFE2C6")) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(0.36, 0.25, 0.18, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label(p, text, "hand", 15, INK)
	return p

## Fiches des jours suspendues à une cordelette (tanzaku). Jours passés : tampon « 済 » ; jour de fête : papier doré,
## pleine lune et susuki ; aujourd'hui : ruban vermillon et léger balancement.
class DayCord extends Control:
	var days := 5
	var today := 1
	var fest := 0
	var fest_name := ""
	var fest_sub := ""
	var _t := 0.0
	var tags: Array = []
	const TAG := Vector2(126, 160)
	func _init(n: int, td: int, fd: int, fname: String, fsub: String) -> void:
		days = n
		today = td
		fest = fd
		fest_name = fname
		fest_sub = fsub
		custom_minimum_size = Vector2(0, TAG.y + 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _ready() -> void:
		for i in days:
			var tag := DayTag.new(i + 1, i + 1 < today, i + 1 == today, i + 1 == fest, fest_name, fest_sub)
			add_child(tag)
			tags.append(tag)
		resized.connect(_layout)
		_layout()
	func _layout() -> void:
		var gap := (size.x - days * TAG.x) / float(days + 1)
		for i in tags.size():
			var tag: Control = tags[i]
			tag.position = Vector2(gap + i * (TAG.x + gap), 24 + _sag(gap + i * (TAG.x + gap) + TAG.x / 2.0))
			tag.pivot_offset = Vector2(TAG.x / 2.0, -6)
		queue_redraw()
	func _sag(x: float) -> float:
		var t := x / maxf(size.x, 1.0)
		return 14.0 * sin(t * PI)
	func appear() -> void:
		for i in tags.size():
			var tag: Control = tags[i]
			var y := tag.position.y
			tag.position.y = y - 40
			tag.modulate.a = 0.0
			var tw := tag.create_tween()
			tw.tween_interval(0.12 + i * 0.07)
			tw.tween_property(tag, "position:y", y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(tag, "modulate:a", 1.0, 0.25)
			(tag as DayTag).stamp_later(0.55 + i * 0.09)
	func _process(dt: float) -> void:
		_t += dt
		for i in tags.size():
			var tag: Control = tags[i]
			var amp := 0.035 if (tag as DayTag).is_today else 0.008
			tag.rotation = sin(_t * 1.3 + i * 1.7) * amp
	func _draw() -> void:
		# cordelette tressée, deux brins
		var pts := PackedVector2Array()
		var n := 48
		for i in n + 1:
			var x := size.x * i / n
			pts.append(Vector2(x, 18 + _sag(x)))
		draw_polyline(pts, Color("#8C6A3E"), 3.0, true)
		for i in range(0, n, 2):
			var a := pts[i]
			var b := pts[i + 1]
			draw_line(a + Vector2(0, -1.2), b + Vector2(0, 1.2), Color("#5E4426"), 1.2, true)
		for tag in tags:
			var top: Vector2 = (tag as Control).position + Vector2(TAG.x / 2.0, 0)
			draw_line(Vector2(top.x, 18 + _sag(top.x)), top + Vector2(0, 10), Color("#8C6A3E"), 1.5, true)
			draw_circle(Vector2(top.x, 18 + _sag(top.x)), 3.5, Color("#6E4E2C"))

class DayTag extends Control:
	var n := 1
	var past := false
	var is_today := false
	var fest := false
	var fname := ""
	var fsub := ""
	var hanko: Control
	func _init(d: int, p: bool, t: bool, f: bool, fn: String, fs: String) -> void:
		n = d
		past = p
		is_today = t
		fest = f
		fname = fn
		fsub = fs
		size = DayCord.TAG
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var day := UIKit.label(self, "Jour", "hand", 15, UIKit.INK_SOFT)
		day.position = Vector2(16, 24)
		var num := UIKit.label(self, str(d), "title", 46, UIKit.VERMILION if t else UIKit.INK)
		num.position = Vector2(16, 38)
		if f:
			var l := UIKit.label(self, fn, "title", 22, Color("#6A4310"))
			l.position = Vector2(14, 104)
			var s := UIKit.label(self, fs, "italic", 13, UIKit.INK_SOFT)
			s.position = Vector2(14, 130)
		elif t:
			var l2 := UIKit.label(self, "aujourd'hui", "hand", 17, UIKit.VERMILION)
			l2.position = Vector2(16, 120)
		if p:
			hanko = UIKit.Hanko.new("済", 50, true, d)
			hanko.position = Vector2(size.x - 64, size.y - 72)
			hanko.rotation = -0.2 + 0.1 * d
			add_child(hanko)
	func stamp_later(delay: float) -> void:
		if hanko:
			(hanko as UIKit.Hanko).stamp(delay)
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# tanzaku : bande de papier aux coins du haut coupés, trou et œillet
		var shape := PackedVector2Array([Vector2(10, 0), Vector2(w - 10, 0), Vector2(w, 10), Vector2(w, h), Vector2(0, h), Vector2(0, 10)])
		var shade := PackedVector2Array()
		for p in shape:
			shade.append(p + Vector2(2, 4))
		draw_colored_polygon(shade, Color(0.1, 0.05, 0.02, 0.18))
		var col := UIKit.PAPER
		if fest:
			col = UIKit.GOLD_PALE
		elif past:
			col = UIKit.PAPER_AGED
		draw_colored_polygon(shape, col)
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, Color(0.36, 0.25, 0.18, 0.55) if not is_today else UIKit.VERMILION, 2.5 if is_today else 1.2, true)
		draw_circle(Vector2(w / 2.0, 10), 4.0, Color("#5E4426"))
		draw_circle(Vector2(w / 2.0, 10), 2.2, Color("#2A1E14"))
		if is_today:
			# ruban vermillon dans le coin
			draw_colored_polygon(PackedVector2Array([Vector2(w - 34, 0), Vector2(w - 18, 0), Vector2(w - 18, 34), Vector2(w - 26, 27), Vector2(w - 34, 34)]), UIKit.VERMILION)
		if fest:
			var m := Vector2(w - 38, 48)
			draw_circle(m, 31.0, Color(1, 0.96, 0.82, 0.5))
			draw_circle(m, 24.0, Color("#FCF5E2"))
			draw_circle(m + Vector2(-7, -6), 6.0, Color("#EADFC2"))
			draw_circle(m + Vector2(8, 6), 4.5, Color("#EADFC2"))
			draw_circle(m + Vector2(-2, 10), 3.0, Color("#EADFC2"))
			# susuki : trois tiges qui se courbent devant la lune
			for k in 3:
				var bx := w - 12.0 - k * 7.0
				var pts := PackedVector2Array()
				for i in 9:
					var t := i / 8.0
					pts.append(Vector2(bx - t * t * (10.0 - k * 3.0), h - 6.0 - t * (40.0 - k * 7.0)))
				draw_polyline(pts, Color("#8C7A48"), 1.6, true)
				var tip := pts[pts.size() - 1]
				for j in 4:
					draw_circle(tip + Vector2(-2.0 - j * 2.2, 2.0 + j * 3.2), 3.0 - j * 0.4, Color("#B9A878"))

## Panneau de papier washi qui s'adapte à son contenu (remplace PanelContainer + StyleBoxFlat) : ombre, barbes,
## double filet d'encre ; le contenu est placé à l'intérieur, avec `pad` de marge.
class PaperPanel extends Container:
	const M := 26.0
	var pad := Vector2(48, 36)
	var _bg: ColorRect
	var _mat: ShaderMaterial
	func _init(p := Vector2(48, 36), border := 16.0, seed := 1.0, tint := Color(0.953, 0.922, 0.851)) -> void:
		pad = p
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = ColorRect.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = UIKit.PAPER_SHADER
		_mat.set_shader_parameter("margin", M)
		_mat.set_shader_parameter("border_inset", border)
		_mat.set_shader_parameter("seed", seed)
		_mat.set_shader_parameter("paper", tint)
		_mat.set_shader_parameter("paper_dark", tint.darkened(0.08).lerp(Color(0.8, 0.72, 0.58), 0.4))
		_bg.material = _mat
		add_child(_bg, false, Node.INTERNAL_MODE_FRONT)
		theme = UIKit.theme()
	func _inner() -> Rect2:
		var o := Vector2(M, M) + pad
		return Rect2(o, size - o * 2.0)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			fit_child_in_rect(_bg, Rect2(Vector2.ZERO, size))
			_mat.set_shader_parameter("size", size)
			for c in get_children():
				if c is Control and (c as Control).visible and not (c as Control).top_level:
					fit_child_in_rect(c, _inner())
	func _get_minimum_size() -> Vector2:
		var m := Vector2.ZERO
		for c in get_children():
			if c is Control and (c as Control).visible:
				m = m.max((c as Control).get_combined_minimum_size())
		return m + (Vector2(M, M) + pad) * 2.0

## Cinq cœurs peints (affection) ; affection négative : cœurs gris fendus.
class Hearts extends Control:
	var value := 0
	var maxv := 10
	func _init(v: int, mx: int) -> void:
		value = v
		maxv = maxi(mx, 1)
		custom_minimum_size = Vector2(5 * 24 + 4, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _heart(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 32:
			var t := TAU * i / 32.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			pts.append(c + Vector2(x, y) * r / 16.0)
		return pts
	func _draw() -> void:
		var full := int(round(5.0 * absf(value) / maxv))
		if value < 0:
			full = clampi(full, 1, 5)
		for i in 5:
			var c := Vector2(12 + i * 24, 12)
			var pts := _heart(c, 9.5)
			var on := i < full
			if value >= 0 and on:
				draw_colored_polygon(pts, Color("#D2475E"))
				draw_circle(c + Vector2(-3.5, -3.5), 2.2, Color(1, 0.8, 0.82, 0.8))
			elif value < 0 and on:
				draw_colored_polygon(pts, Color("#8C8496"))
				draw_line(c + Vector2(0, -6), c + Vector2(-2, 1), Color("#F3EBD9"), 1.6)
				draw_line(c + Vector2(-2, 1), c + Vector2(2, 5), Color("#F3EBD9"), 1.6)
			pts.append(pts[0])
			draw_polyline(pts, Color(0.45, 0.2, 0.2, 0.55) if value >= 0 else Color(0.3, 0.28, 0.32, 0.6), 1.2, true)

## Fiche de papier clair avec une bande de washi tape de couleur en haut à gauche (cartes du présentoir...).
static func card(tape: Color, dim := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FBF6EA") if not dim else Color("#DCD2BE")
	sb.border_color = Color(0.36, 0.25, 0.18, 0.28)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 18
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.2, 0.1, 0.05, 0.18)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(1, 3)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := tape if not dim else Color("#A89F8E")
	p.draw.connect(func():
		var a := Vector2(-8, 8)
		var pts := PackedVector2Array([a, a + Vector2(70, -14), a + Vector2(74, 4), a + Vector2(4, 18)])
		p.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.78))
		for k in 4:
			p.draw_line(a + Vector2(14 + k * 14, -2 - k * 2.8), a + Vector2(18 + k * 14, 15 - k * 2.8), Color(1, 1, 1, 0.18), 3.0))
	return p

## Ouvre une feuille modale centrée : voile, feuille qui se pose. Retourne {shade, panel, box}.
static func open_sheet(parent: Node, min_size: Vector2, pad := Vector2(48, 36), seed := 1.0) -> Dictionary:
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.03, 0.0)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var panel := PaperPanel.new(pad, 16.0, seed)
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.96
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(shade, "color:a", 0.6, 0.3)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return {"shade": shade, "panel": panel, "box": box}

static func close_sheet(s: Dictionary) -> void:
	var shade: ColorRect = s["shade"]
	var panel: Control = s["panel"]
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(shade, "color:a", 0.0, 0.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.2)
	await tw.finished
	shade.queue_free()

## En-tête d'une feuille : sceau, titre (Klee One), sous-titre en italique, texte à droite.
static func sheet_header(box: Container, seal: String, title: String, subtitle := "", right := "") -> Hanko:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	var h := Hanko.new(seal, 50, false, title.length())
	h.rotation = -0.06
	head.add_child(h)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	label(titles, title, "title", 30, INK)
	if subtitle != "":
		label(titles, subtitle, "italic", 16, INK_SOFT)
	if right != "":
		var r := label(head, right, "hand", 22, VERMILION)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.stamp(0.2)
	return h

## Choix de dialogue : bandelette de papier, onglet vermillon à gauche qui s'élargit au survol.
static func choice_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font("hand"))
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed"]:
		var hov: bool = st == "hover"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FFF9EC") if hov else Color("#FBF6EA")
		sb.border_color = VERMILION if hov else Color(0.6, 0.28, 0.18, 0.8)
		sb.set_border_width_all(1)
		sb.border_width_left = 16 if hov else 9
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 34 if hov else 28
		sb.content_margin_right = 24
		sb.content_margin_top = 10
		sb.content_margin_bottom = 12
		sb.shadow_color = Color(0.1, 0.05, 0.02, 0.3)
		sb.shadow_size = 7 if hov else 4
		sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color("#7A2414"))
	b.add_theme_color_override("font_pressed_color", VERMILION)
	b.pressed.connect(func(): Sfx.play(&"ui_click"))
	return b
