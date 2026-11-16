class_name Festival
extends Node
## Tsukimi, la fête de la lune : fin de la démo (bloc « festival » de data/story/story.json).
##
## Jour 2 : Tanaka apporte la lettre du village (drapeau fete_annoncee). Le tableau de préparation apparaît près
## du tronc à offrandes, avec deux caisses (lanternes de papier, banderoles) ; les perches de l'allée, les socles
## des banderoles et la table d'offrandes attendent d'être garnis. La préparation dure plusieurs jours et se
## sauvegarde (GameState.festival) :
##   lanternes   porter une lanterne de la caisse à une perche de l'allée (8) ;
##   nobori      planter les banderoles au torii (4) ;
##   offrandes   déposer à la table kakis, châtaignes, susuki (cueillette) et dango (bureau du sanctuaire) ;
##   invitations choix dans les dialogues des jours 3 et 4 (drapeaux invite_<personnage>).
## On ne peut pas rater la fête : elle montre ce qu'on a préparé, et qui on a invité.
## Jour 5 : pas de corvées. On ouvre la fête au tableau ; le soir tombe, les invités sont là (visites de type
## « festival »), on sonne la cloche, la pleine lune se lève (finale), puis l'épilogue et le bilan.

const TERRAIN := preload("res://scripts/terrain.gd")
const BOARD_POS := Vector3(-4.6, 0, -12.2)
const LANTERN_CRATE := Vector3(-4.75, 0, -10.55)
const NOBORI_CRATE := Vector3(-4.7, 0, -13.85)
const TABLE_POS := Vector3(4.7, 0, -11.4)
## Perches de l'allée : potence vers l'allée (gauche : +X ; droite : tournée de 180°).
## Taille de la lanterne de papier sur une perche (0,38 m de diamètre à l'échelle 1 : trop gros pour la perche).
const POLE_LANTERN_SCALE := 0.72
const POLES := [Vector3(-1.9, 0, 8.0), Vector3(1.9, 0, 8.0), Vector3(-1.9, 0, 2.5), Vector3(1.9, 0, 2.5),
	Vector3(-1.9, 0, -4.5), Vector3(1.9, 0, -4.5), Vector3(-1.9, 0, -10.6), Vector3(1.9, 0, -10.6)]
## Banderoles : deux en haut des marches, face aux arrivants ; deux dans la cour, face à l'intérieur.
## Banderoles : [socle, orientation, modèle]. Face tournée vers l'allée (x = 0), pour qu'on les lise en montant.
const NOBORI := [[Vector3(-4.0, 0, 12.3), 90.0, "nobori"], [Vector3(3.4, 0, 12.3), -90.0, "nobori_red"],
	[Vector3(-3.3, 0, 8.3), 90.0, "nobori_red"], [Vector3(4.1, 0, 8.3), -90.0, "nobori"]]
## Où se tiennent les invités pendant la fête, puis pour regarder la lune (autour de la table).
const GUEST_SPOTS := {
	"vieille_dame": [Vector3(3.3, 0, -9.9), Vector3(3.0, 0, -9.6)],
	"fillette": [Vector3(-2.7, 0, -3.2), Vector3(4.2, 0, -9.3)],
	"etudiant": [Vector3(12.4, 0, -2.6), Vector3(5.6, 0, -9.7)],
	"moine": [Vector3(11.0, 0, -22.4), Vector3(4.9, 0, -12.9)],
	"facteur": [Vector3(1.9, 0, 5.6), Vector3(1.8, 0, -9.9)],
}
## Stands de la soirée (yatai) : face à l'allée ; l'hôte, s'il est venu, se tient derrière.
const STALLS := [
	{"id": "kingyo", "script": "res://scripts/stalls/kingyo_stall.gd", "pos": Vector3(6.7, 0, 6.2), "yaw": -90.0},
	{"id": "shateki", "script": "res://scripts/stalls/shateki_stall.gd", "pos": Vector3(7.3, 0, -0.3), "yaw": -90.0},
	{"id": "dango", "script": "res://scripts/stalls/dango_stall.gd", "pos": Vector3(-6.4, 0, 6.3), "yaw": 90.0},
	{"id": "wanage", "script": "res://scripts/stalls/wanage_stall.gd", "pos": Vector3(-8.9, 0, -7.4), "yaw": 90.0},
]
const MOON_VIEW := Vector3(-1.2, 0, -2.6)     # le gardien, pour la finale (regarde la lune au-dessus du pavillon)
const PAPER_GLOW := 1.5

var game: Node3D
var built := false
var active := false               # soirée de fête en cours (jour de la fête, après l'ouverture)
var finale_running := false
var guests: Dictionary = {}       # personnage -> nœud du visiteur
var greeted: Dictionary = {}
var _root: Node3D
var _poles: Array = []            # [perche, lanterne ou null]
var _nobori: Array = []           # [socle, banderole ou null]
var _crate_l: Node3D              # panier des lanternes
var _crate_n: Node3D              # panier des banderoles
var _table: Node3D
var _cat: Node3D
var stalls: Dictionary = {}       # id -> StallGame (soirée de fête)

# ---------------------------------------------------------------- données et état (statiques : lus par Story)
static func data() -> Dictionary:
	Story.ensure_loaded()
	return Story.data.get("festival", {})

static func day() -> int:
	return int(data().get("day", 0))

static func is_festival_day(d: int) -> bool:
	return not data().is_empty() and d == day()

static func announced() -> bool:
	return not data().is_empty() and GameState.has_flag(StringName(String(data().get("announce_flag", "fete_annoncee"))))

static func state() -> Dictionary:
	if GameState.festival.is_empty():
		GameState.festival = {"lanternes": [], "nobori": [], "offrandes": {}}
	return GameState.festival

static func prep(id: String) -> Dictionary:
	for p in data().get("preparations", []):
		if String(p.get("id", "")) == id:
			return p
	return {}

static func invited() -> Array:
	var out := []
	for who in data().get("guests", {}):
		if GameState.has_flag(StringName("invite_" + String(who))):
			out.append(String(who))
	return out

## Avancée d'une préparation : lanternes / nobori (nombre posé), offrandes (objets déposés), offrandes.<objet>,
## invitations (personnes invitées) ; "" = nombre de préparations terminées. Sert aussi de condition « festival ».
static func prep_value(id: String) -> int:
	var st := state()
	if id == "":
		var n := 0
		for p in data().get("preparations", []):
			if prep_done(String(p.get("id", ""))):
				n += 1
		return n
	if id.begins_with("offrandes."):
		return int((st.get("offrandes", {}) as Dictionary).get(id.trim_prefix("offrandes."), 0))
	match id:
		"lanternes", "nobori":
			return (st.get(id, []) as Array).size()
		"offrandes":
			var t := 0
			for k in (st.get("offrandes", {}) as Dictionary):
				t += int(st["offrandes"][k])
			return t
		"invitations":
			return invited().size()
	return 0

static func prep_target(id: String) -> int:
	var p := prep(id)
	if p.has("needs"):
		var t := 0
		for k in p["needs"]:
			t += int(p["needs"][k])
		return t
	return int(p.get("target", 1))

static func prep_done(id: String) -> bool:
	return prep_value(id) >= prep_target(id)

## Jours avant la fête (0 le jour même, négatif après).
static func days_left(d: int) -> int:
	return day() - d

# ---------------------------------------------------------------- mise en place
func setup(g: Node3D) -> void:
	game = g
	_root = Node3D.new()
	_root.name = "Festival"
	game.props.add_child(_root)

func on_day_start() -> void:
	active = false
	finale_running = false
	var atmo: Node = game.atmosphere
	if atmo and atmo.get("full_moon"):
		atmo.call("set_full_moon", false)
	_clear_guests()
	_clear_stalls()
	greeted.clear()
	if GameState.festival.is_empty() and not announced():
		_teardown()
	if announced() and not built:
		_build()
	elif built:
		_refresh()

func _process(_dt: float) -> void:
	if not built and announced() and not data().is_empty():
		_build()
		Events.toast.emit("Tsukimi dans %d jours. Le tableau de préparation est près du tronc à offrandes." % days_left(GameState.day))

func _teardown() -> void:
	for c in _root.get_children():
		c.queue_free()
	_poles.clear()
	_nobori.clear()
	_table = null
	built = false

func _model(name: String) -> Node3D:
	var n := ToolModels.glb(name)
	if n == null:
		n = Node3D.new()
	return n

func _place(n: Node3D, p: Vector3, yaw_deg: float) -> Node3D:
	n.position = Vector3(p.x, TERRAIN.walk_y(p.x, p.z), p.z)
	n.rotation_degrees.y = yaw_deg
	_root.add_child(n)
	return n

func _build() -> void:
	built = true
	# tableau, caisses
	var board := _place(_model("festival_board"), BOARD_POS, 90.0)
	# guirlande de lanternes sous l'avant-toit du tableau (repères « garland_0..3 » du modèle)
	var atmo: Node = game.atmosphere
	for k in 4:
		var gh: Node3D = board.find_child("garland_%d" % k, true, false)
		var gl := ToolModels.glb("paper_lantern")
		if gh == null or gl == null:
			continue
		gl.position = gh.position
		gl.scale = Vector3.ONE * 0.42
		gl.rotation.y = randf_range(-0.3, 0.3)
		board.add_child(gl)
		if atmo and atmo.has_method("add_papers"):
			atmo.call("add_papers", gl, PAPER_GLOW)
	game._make(board, Vector3(1.8, 2.0, 0.8), Vector3(0, 1.1, 0.2),
		func() -> String:
			if active or finale_running:
				return ""
			if is_festival_day(GameState.day):
				return "E : Tableau de la fête  (ouvrir Tsukimi)"
			return "E : Tableau de la fête  (calendrier et préparatifs)",
		func(_p): open_board())
	var crate_l := _place(_crate("paper_lantern", prep_target("lanternes")), LANTERN_CRATE, 80.0)
	_crate_l = crate_l
	game._make(crate_l, Vector3(0.9, 1.0, 0.9), Vector3(0, 0.4, 0),
		func() -> String: return _crate_prompt(&"chochin", "lanternes", "une lanterne de papier"),
		func(_p): _take(&"chochin", "lanternes"))
	var crate_n := _place(_crate("nobori_rolled", prep_target("nobori")), NOBORI_CRATE, 100.0)
	_crate_n = crate_n
	if not game.player.tool_changed.is_connected(_refresh_crates):
		game.player.tool_changed.connect(_refresh_crates)
	game._make(crate_n, Vector3(0.9, 1.4, 0.9), Vector3(0, 0.5, 0),
		func() -> String: return _crate_prompt(&"nobori", "nobori", "une banderole"),
		func(_p): _take(&"nobori", "nobori"))
	# perches de l'allée
	for i in POLES.size():
		var pole := _place(_model("lantern_pole"), POLES[i], 0.0 if POLES[i].x < 0.0 else 180.0)
		_poles.append([pole, null])
		var idx := i
		game._make(pole, Vector3(1.1, 2.6, 0.7), Vector3(0.25, 1.3, 0),
			func() -> String:
				if _poles[idx][1] != null:
					return ""
				if game.player.carry == &"chochin":
					return "E : Accrocher la lanterne"
				return "Une perche vide — les lanternes sont dans la caisse, près du tableau",
			func(_p): _hang(idx))
	# socles des banderoles (un piquet et un petit repère tant qu'elles ne sont pas plantées)
	for i in NOBORI.size():
		var spot := Node3D.new()
		_place(spot, NOBORI[i][0], NOBORI[i][1])
		var peg := _peg()
		spot.add_child(peg)
		_nobori.append([spot, null, peg])
		var idx2 := i
		game._make(spot, Vector3(1.0, 2.0, 1.0), Vector3(0, 1.0, 0),
			func() -> String:
				if _nobori[idx2][1] != null:
					return ""
				if game.player.carry == &"nobori":
					return "E : Planter la banderole"
				return "Un socle de banderole — elles sont roulées près du tableau",
			func(_p): _plant(idx2))
	# table d'offrandes
	_table = _place(_model("tsukimi_table"), TABLE_POS, -90.0)
	game._make(_table, Vector3(1.2, 1.2, 0.8), Vector3(0, 0.5, 0),
		func() -> String: return _table_prompt(),
		func(_p): _deposit())
	_refresh()

## Caisse en bois avec ce qu'elle contient (quelques lanternes couchées, banderoles roulées).
## Panier rempli de ce qu'il faut placer : un objet par lanterne ou banderole à poser (voir _refresh_crates).
## Les objets du dessus sont les premiers retirés.
func _crate(content: String, count: int) -> Node3D:
	var n := Node3D.new()
	var basket := ToolModels.glb("basket")
	if basket != null:
		basket.scale = Vector3.ONE * 1.25
		n.add_child(basket)
	else:
		ToolModels.box(n, Vector3(0.7, 0.4, 0.5), ToolModels.WOOD, Vector3(0, 0.2, 0))
	for k in count:
		var m := ToolModels.glb(content)
		if m == null:
			continue
		var pivot := Node3D.new()
		pivot.name = "Supply_%d" % k
		pivot.add_child(m)
		if content == "paper_lantern":
			# lanternes couchées, deux couches de quatre (la seconde croisée sur la première)
			m.scale = Vector3.ONE * 0.5
			m.rotation_degrees = Vector3(0, 0, 90)
			m.position = Vector3(-0.142, 0, 0)          # centre de la lanterne sur le pivot
			var layer := k / 4
			var i := k % 4
			var gx := -0.11 if i % 2 == 0 else 0.11
			var gz := -0.09 if i < 2 else 0.09
			if layer == 0:
				pivot.position = Vector3(gx * 0.9, 0.42, gz)
				pivot.rotation_degrees = Vector3(0, randf_range(-8, 8), 0)
			else:
				pivot.position = Vector3(gz, 0.56, gx * 0.8)
				pivot.rotation_degrees = Vector3(0, 90 + randf_range(-10, 10), 0)
		else:
			# banderoles roulées debout, un peu penchées vers l'extérieur
			var gx2 := -0.085 if k % 2 == 0 else 0.085
			var gz2 := -0.07 if k < 2 else 0.07
			pivot.position = Vector3(gx2, 0.75, gz2)
			pivot.rotation_degrees = Vector3(gz2 * -90.0, 0, gx2 * -90.0)
		n.add_child(pivot)
	return n

## Chaque panier montre ce qu'il reste à placer : ni ce qui est déjà posé, ni ce que le joueur porte.
func _refresh_crates() -> void:
	for c in [[_crate_l, &"chochin", "lanternes"], [_crate_n, &"nobori", "nobori"]]:
		var crate: Node3D = c[0]
		if crate == null or not is_instance_valid(crate):
			continue
		var left := prep_target(String(c[2])) - prep_value(String(c[2]))
		if game.player.carry == c[1]:
			left -= 1
		for sup in crate.get_children():
			if String(sup.name).begins_with("Supply_"):
				(sup as Node3D).visible = int(String(sup.name).trim_prefix("Supply_")) < left

func _peg() -> Node3D:
	var n := Node3D.new()
	ToolModels.cyl(n, 0.16, 0.08, Color("#8E8A80"), Vector3(0, 0.04, 0), Vector3.ZERO, 0.14, 8)
	ToolModels.cyl(n, 0.025, 0.5, ToolModels.WOOD_DARK, Vector3(0, 0.3, 0), Vector3.ZERO, -1.0, 6)
	return n

func _crate_prompt(kind: StringName, id: String, what: String) -> String:
	if active or finale_running:
		return ""
	var left := prep_target(id) - prep_value(id)
	if left <= 0:
		return "Tout est en place"
	if game.player.carry == kind:
		return "Vous portez déjà %s" % what
	if game.player.carry != &"":
		return "Vous avez déjà les mains prises"
	return "E : Prendre %s  (%d à placer)" % [what, left]

func _take(kind: StringName, id: String) -> void:
	if active or finale_running or game.player.carry != &"" or prep_done(id):
		return
	if game.player.tool != &"":
		game.player_put_back_tool()
	game.player.set_carry(kind)
	Sfx.play(&"paper" if kind == &"chochin" else &"pickup", game.player.global_position)
	Events.toast.emit("Accrochez-la à une perche de l'allée." if kind == &"chochin" else "Plantez-la sur un socle, près du torii.")

func _hang(i: int) -> void:
	if _poles[i][1] != null or game.player.carry != &"chochin":
		return
	game.player.set_carry(&"")
	(state()["lanternes"] as Array).append(i)
	_show_lantern(i, true)
	Sfx.play(&"paper", (_poles[i][0] as Node3D).global_position + Vector3(0, 2.0, 0))
	_refresh_crates()
	_progress_toast("lanternes", "Lanternes accrochées")

func _plant(i: int) -> void:
	if _nobori[i][1] != null or game.player.carry != &"nobori":
		return
	game.player.set_carry(&"")
	(state()["nobori"] as Array).append(i)
	_show_nobori(i, true)
	Sfx.play(&"pickup", (_nobori[i][0] as Node3D).global_position)
	_refresh_crates()
	_progress_toast("nobori", "Banderoles plantées")

func _progress_toast(id: String, label: String) -> void:
	var v := prep_value(id)
	var t := prep_target(id)
	if v >= t:
		Events.toast.emit("%s : %d / %d. C'est prêt !" % [label, v, t])
		GameState.note("Préparatifs de Tsukimi : %s." % String(prep(id).get("label", id)).to_lower())
		Sfx.play(&"tick")
	else:
		Events.toast.emit("%s : %d / %d" % [label, v, t])

func _show_lantern(i: int, on: bool) -> void:
	var pole: Node3D = _poles[i][0]
	if on and _poles[i][1] == null:
		var lan := ToolModels.glb("paper_lantern")
		if lan == null:
			return
		var hook: Node3D = pole.find_child("hook", true, false)
		lan.position = hook.position if hook else Vector3(0.42, 2.12, 0)
		lan.scale = Vector3.ONE * POLE_LANTERN_SCALE
		pole.add_child(lan)
		_poles[i][1] = lan
		var atmo: Node = game.atmosphere
		if atmo and atmo.has_method("add_papers"):
			atmo.call("add_papers", lan, PAPER_GLOW)
		# petit balancement à l'accrochage
		lan.rotation.z = 0.25
		var tw := lan.create_tween()
		tw.tween_property(lan, "rotation:z", -0.12, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lan, "rotation:z", 0.05, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lan, "rotation:z", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	elif not on and _poles[i][1] != null:
		(_poles[i][1] as Node3D).queue_free()
		_poles[i][1] = null

func _show_nobori(i: int, on: bool) -> void:
	var spot: Node3D = _nobori[i][0]
	if on and _nobori[i][1] == null:
		var b := ToolModels.glb(String(NOBORI[i][2]))
		if b == null:
			return
		spot.add_child(b)
		_nobori[i][1] = b
		(_nobori[i][2] as Node3D).visible = false
		b.scale = Vector3(1.0, 0.05, 1.0)
		b.create_tween().tween_property(b, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not on and _nobori[i][1] != null:
		(_nobori[i][1] as Node3D).queue_free()
		_nobori[i][1] = null
		(_nobori[i][2] as Node3D).visible = true

## Remet le décor dans l'état sauvegardé (nouvelle journée, partie chargée).
func _refresh() -> void:
	var st := state()
	for i in _poles.size():
		_show_lantern(i, (st["lanternes"] as Array).has(i))
	for i in _nobori.size():
		_show_nobori(i, (st["nobori"] as Array).has(i))
	_refresh_table()
	_refresh_crates()

func _refresh_table() -> void:
	if _table == null:
		return
	var offr: Dictionary = state().get("offrandes", {})
	var needs: Dictionary = prep("offrandes").get("needs", {})
	for k in needs:
		var n := int(offr.get(k, 0))
		# une pièce par objet déposé (kaki_1, kaki_2...) ; sinon une seule pièce, visible dès le premier
		var part: Node3D = _table.find_child(String(k), true, false)
		if part:
			part.visible = n > 0
		for i in range(1, int(needs[k]) + 1):
			var piece: Node3D = _table.find_child("%s_%d" % [k, i], true, false)
			if piece:
				piece.visible = i <= n

# ---------------------------------------------------------------- table d'offrandes
func _missing() -> Dictionary:
	var out := {}
	var offr: Dictionary = state().get("offrandes", {})
	var needs: Dictionary = prep("offrandes").get("needs", {})
	for k in needs:
		var m := int(needs[k]) - int(offr.get(k, 0))
		if m > 0:
			out[k] = m
	return out

func _table_prompt() -> String:
	if active or finale_running:
		return ""
	var miss := _missing()
	if miss.is_empty():
		return "La table d'offrandes est prête pour la lune"
	for k in miss:
		if GameState.item_count(String(k)) > 0:
			return "E : Déposer les offrandes"
	var parts := PackedStringArray()
	var offr: Dictionary = state().get("offrandes", {})
	var needs: Dictionary = prep("offrandes").get("needs", {})
	for k in needs:
		parts.append("%s %d/%d" % [Story.item_name(String(k)).to_lower(), int(offr.get(k, 0)), int(needs[k])])
	return "Table d'offrandes — " + ", ".join(parts)

func _deposit() -> void:
	var miss := _missing()
	var given := PackedStringArray()
	var offr: Dictionary = state()["offrandes"]
	for k in miss:
		var n := mini(int(miss[k]), GameState.item_count(String(k)))
		if n <= 0:
			continue
		GameState.remove_item(String(k), n)
		offr[k] = int(offr.get(k, 0)) + n
		given.append("%d %s" % [n, Story.item_name(String(k)).to_lower()])
	if given.is_empty():
		return
	Sfx.play(&"pickup", _table.global_position)
	_refresh_table()
	Events.toast.emit("Déposé sur la table : " + ", ".join(given) + ".")
	if prep_done("offrandes"):
		Events.toast.emit("La table d'offrandes est prête pour la lune.")
		GameState.note("Préparatifs de Tsukimi : la table d'offrandes est prête.")
		Sfx.play(&"tick")

# ---------------------------------------------------------------- tableau et calendrier
func calendar_data() -> Dictionary:
	var preps := []
	for p in data().get("preparations", []):
		var id := String(p.get("id", ""))
		var row := {"id": id, "label": String(p.get("label", id)), "value": prep_value(id), "target": prep_target(id),
			"done": prep_done(id), "detail": "", "pips": [], "names": []}
		if id == "offrandes":
			var offr: Dictionary = state().get("offrandes", {})
			var parts := PackedStringArray()
			for k in p.get("needs", {}):
				parts.append("%s %d/%d" % [Story.item_name(String(k)).to_lower(), int(offr.get(k, 0)), int(p["needs"][k])])
				var it := Story.item(String(k))
				var col := Color.from_string(String(it.get("color", "#C8442B")), Color.ORANGE)
				for j in int(p["needs"][k]):
					(row["pips"] as Array).append({"color": col, "on": j < int(offr.get(k, 0))})
			row["detail"] = ", ".join(parts)
		elif id == "invitations":
			for who in invited():
				(row["names"] as Array).append(Story.display_name(who))
			row["detail"] = "" if not (row["names"] as Array).is_empty() else "à faire en parlant aux visiteurs"
		preps.append(row)
	var left := days_left(GameState.day)
	var sub := ""
	if left > 1:
		sub = "Pleine lune dans %d jours" % left
	elif left == 1:
		sub = "Pleine lune demain soir"
	elif left == 0:
		sub = "Ce soir, la pleine lune"
	return {"title": "Calendrier du sanctuaire", "days": GameState.max_days(), "today": GameState.day,
		"festival_day": day(), "festival": String(data().get("name", "Tsukimi")),
		"festival_sub": String(data().get("subtitle", "")), "countdown": sub, "preps": preps,
		"action": "Ouvrir la fête" if is_festival_day(GameState.day) and not active else ""}

func open_board() -> void:
	if active or finale_running:
		return
	game.player.input_enabled = false
	Sfx.play(&"paper")
	var choice: String = await game.hud.show_calendar(calendar_data())
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if choice == "action" and is_festival_day(GameState.day):
		await open_festival()

# ---------------------------------------------------------------- jour de la fête
## Le jour 5 commence sans corvées : on finit les préparatifs, puis on ouvre la fête au tableau.
func begin_festival_day() -> void:
	if not built:
		_build()
	Events.toast.emit("Jour de Tsukimi. Finissez les préparatifs ; quand vous êtes prêt, ouvrez la fête au tableau.")
	game.hud.set_objective("Tsukimi : finir les préparatifs, puis ouvrir la fête au tableau", "E")

## Qui vient : les invités, et ceux qui tiennent assez au sanctuaire pour monter quand même.
func guest_list() -> Array:
	var out := []
	for who in data().get("guests", {}):
		var w := String(who)
		if GameState.gone.get(w, false):
			continue
		if GameState.has_flag(StringName("invite_" + w)) or (GameState.met.get(w, false) and int(GameState.affection.get(w, 0)) >= 4):
			out.append(w)
	return out

func open_festival() -> void:
	if active:
		return
	active = true
	game.player.input_enabled = false
	if game.player.carry != &"":
		game.player.set_carry(&"")
	await game.hud.fade_to(1.0, 1.4)
	GameState.set_phase(GameState.Phase.EVENING)
	game._apply_lighting(GameState.Phase.EVENING, true)
	for i in game.lanterns.size():
		if not game.lit.get(i, false):
			game._light(i)
	_build_stalls()
	var who_list := guest_list()
	for who in who_list:
		_spawn_guest(who)
	await get_tree().create_timer(0.5).timeout
	game.hud.fade_to(0.0, 1.6)
	await game.hud.show_card("%s\n%s" % [String(data().get("name", "Tsukimi")), String(data().get("subtitle", ""))], 1.6)
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if who_list.is_empty():
		Events.toast.emit("Le soir tombe. Personne n'est monté... La lune viendra quand même : sonnez la cloche.")
	else:
		var names := PackedStringArray()
		for w in who_list:
			names.append(Story.display_name(w))
		Events.toast.emit("Les invités sont arrivés : %s." % ", ".join(names))
	if not stalls.is_empty():
		Events.toast.emit("Des stands ont ouvert dans la cour : poissons rouges, tir au bouchon, anneaux et dango.")
	game.hud.set_objective("Saluer les invités, essayer les stands, puis sonner la cloche pour la lune", "E")
	GameState.note("Le soir de Tsukimi, le sanctuaire était plein de monde.")

func _spawn_guest(who: String) -> void:
	var v := Story.find_visit(String(data()["guests"][who]))
	var spots: Array = GUEST_SPOTS.get(who, [Vector3(2, 0, -8), Vector3(3, 0, -10)])
	var n: Node3D = load("res://scenes/visitors/visitor_placeholder.tscn").instantiate()
	n.set("display_name", Story.display_name(who))
	n.set("color", Story.color_of(who))
	n.set("character_id", who)
	var p: Vector3 = spots[0]
	var stall := stall_of(who)
	if stall != null:
		p = stall.host_spot()
	n.position = Vector3(p.x, game.ground_y(p.x, p.z), p.z)
	game.world.add_child(n)
	if stall != null:
		n.look_at(n.position + stall.global_basis.z, Vector3.UP, true)
	else:
		n.look_at(Vector3(TABLE_POS.x, n.position.y, TABLE_POS.z + 0.01) if who != "etudiant" else Vector3(10.0, n.position.y, -2.0), Vector3.UP, true)
	guests[who] = n
	GameState.met[who] = true
	if who == "fillette":
		var mochi := Cat.new()           # Mochi est venu aussi : assis à côté de Hina
		mochi.position = n.position + Vector3(0.55, 0, 0.35)
		mochi.rotation.y = n.rotation.y
		game.world.add_child(mochi)
		mochi.play("sit", 0.0)
		_cat = mochi
	game._make(n, Vector3(1.1, 1.9, 1.1), Vector3(0, 0.95, 0),
		func() -> String:
			if not active or finale_running or greeted.get(who, false):
				return ""
			return "E : Parler à %s" % Story.display_name(who),
		func(_p): _greet(who, v))

func _greet(who: String, v: Dictionary) -> void:
	if greeted.get(who, false) or not active or finale_running:
		return
	greeted[who] = true
	game.player.input_enabled = false
	if not v.is_empty():
		await game.vn.play_visit(v)
		GameState.visited[String(v.get("id", ""))] = true
	(GameState.day_log["visitors"] as Array).append(who)
	await game._offer_gift(who)
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var left := guests.size() - greeted.size()
	if left == 0:
		Events.toast.emit("Vous avez salué tout le monde. Sonnez la cloche : la lune va se lever.")

func bell_prompt() -> String:
	if finale_running:
		return ""
	var left := guests.size() - greeted.size()
	if left > 0:
		return "E : Sonner la cloche pour la lune  (%d invité%s pas encore salué%s)" % [left, "s" if left > 1 else "", "s" if left > 1 else ""]
	return "E : Sonner la cloche pour la lune"

## Finale : la cloche, les invités se rassemblent autour de la table, la pleine lune se lève au-dessus du pavillon.
func finale() -> void:
	if finale_running:
		return
	finale_running = true
	game.hud.set_objective("", "")
	game.hud.set_quiet(true)
	var pl: CharacterBody3D = game.player
	pl.input_enabled = false
	await game.hud.fade_to(1.0, 1.6)
	_stage_moon()
	var moon := _moon_dir()
	await get_tree().create_timer(0.4).timeout
	# plan : on part des invités et du toit, puis le regard monte lentement jusqu'à la lune
	game.hud.fade_to(0.0, 2.5)
	var pitch := asin(clampf(moon.y, -1.0, 1.0))
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(pl.head, "rotation:x", pitch * 0.8, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	var fin := Story.find_visit(String(data().get("finale", "")))
	if not fin.is_empty():
		await game.vn.play_visit(fin)
		GameState.visited[String(fin.get("id", ""))] = true
	var epi := Story.find_visit(String(data().get("epilogue", "")))
	if not epi.is_empty() and Story.check(epi.get("conditions", [])):
		await game.hud.fade_to(1.0, 1.5)
		for who in guests:
			if is_instance_valid(guests[who]):
				(guests[who] as Node3D).visible = false
		pl.global_position = Vector3(0, TERRAIN.walk_y(0.0, 11.6) + 0.05, 11.6)
		pl.rotation.y = PI          # face à l'escalier : la lanterne est sur la dernière marche
		pl.head.rotation.x = -0.45
		game.hud.fade_to(0.0, 1.5)
		await get_tree().create_timer(1.6).timeout
		await game.vn.play_visit(epi)
		GameState.visited[String(epi.get("id", ""))] = true
	GameState.note("La lune s'est levée sur le sanctuaire. Le village a regardé avec moi.")
	await get_tree().create_timer(1.5).timeout
	_clear_guests()
	_clear_stalls()
	game.hud.set_quiet(false)
	active = false

## Mise en place de la finale : nuit de pleine lune, invités rassemblés autour de la table, gardien face à la lune.
func _stage_moon() -> void:
	var pl: CharacterBody3D = game.player
	# tout le monde se tourne vers la lune
	var atmo: Node = game.atmosphere
	if atmo and atmo.has_method("set_full_moon"):
		atmo.call("set_full_moon", true)
	GameState.set_phase(GameState.Phase.NIGHT)
	game._apply_lighting(GameState.Phase.NIGHT, true)
	var moon := _moon_dir()
	for who in guests:
		var n: Node3D = guests[who]
		var p: Vector3 = (GUEST_SPOTS.get(who, [Vector3.ZERO, Vector3(3, 0, -10)]) as Array)[1]
		n.position = Vector3(p.x, game.ground_y(p.x, p.z), p.z)
		n.look_at(n.position + Vector3(moon.x, 0, moon.z), Vector3.UP, true)
	if _cat != null and is_instance_valid(_cat) and guests.has("fillette"):
		_cat.position = (guests["fillette"] as Node3D).position + Vector3(0.5, 0, 0.3)
		_cat.rotation.y = atan2(moon.x, moon.z)       # Mochi regarde la lune lui aussi (l'avant du chat est +Z)
	pl.global_position = Vector3(MOON_VIEW.x, TERRAIN.walk_y(MOON_VIEW.x, MOON_VIEW.z) + 0.05, MOON_VIEW.z)
	pl.velocity = Vector3.ZERO
	pl.rotation.y = atan2(-moon.x, -moon.z)
	pl.head.rotation.x = 0.0

## Test : on arrive au jour de la fête comme après une vraie partie (annoncée, invités, de quoi acheter les dango),
## mais rien n'est préparé : godot --path . -- --fete
func debug_setup_day(prepared := false) -> void:
	GameState.reset_story()
	if prepared:                               # --fete-prete : tous les préparatifs déjà faits
		var st := state()
		st["lanternes"] = range(POLES.size())
		st["nobori"] = range(NOBORI.size())
		st["offrandes"] = (prep("offrandes").get("needs", {}) as Dictionary).duplicate()
	GameState.set_flag(StringName(String(data().get("announce_flag", "fete_annoncee"))))
	for w in data().get("guests", {}):
		GameState.set_flag(StringName("invite_" + String(w)))
		GameState.met[String(w)] = true
		GameState.add_affection(String(w), 3)
	GameState.set_flag(&"fumiko_revient")
	GameState.visited["renard_1"] = true
	GameState.visited["tanuki_1"] = true
	GameState.add_coins(6)
	for k in (prep("offrandes").get("needs", {}) as Dictionary):
		if String(k) != "dango":              # les dango s'achètent au bureau du sanctuaire
			GameState.add_item(String(k), int(prep("offrandes")["needs"][k]))

## Debug : fête annoncée, tout le monde invité, préparatifs faits (captures d'écran).
func debug_fill() -> void:
	GameState.set_flag(StringName(String(data().get("announce_flag", "fete_annoncee"))))
	for w in data().get("guests", {}):
		GameState.set_flag(StringName("invite_" + String(w)))
		GameState.met[String(w)] = true
	var st := state()
	st["lanternes"] = range(POLES.size())
	st["nobori"] = range(NOBORI.size())
	st["offrandes"] = (prep("offrandes").get("needs", {}) as Dictionary).duplicate()
	if not built:
		_build()
	else:
		_refresh()

## Debug : soirée de fête ouverte (invités à leur place) ; moon = vrai : pose de la finale.
func debug_evening(moon: bool) -> void:
	debug_fill()
	active = true
	_build_stalls()
	for who in guest_list():
		_spawn_guest(who)
	if moon:
		_stage_moon()
		game.player.head.rotation.x = asin(clampf(_moon_dir().y, -1.0, 1.0)) * 0.8

## Test d'un stand : soirée ouverte, on entre directement au stand (godot --path . -- --stand=kingyo).
## auto = vrai : la feuille de règles se valide seule (captures d'écran).
func debug_stand(id: String, auto := false) -> StallGame:
	await get_tree().create_timer(3.2).timeout      # laisse finir le carton du matin
	await open_festival()
	var st: StallGame = stalls.get(id)
	if st == null:
		push_error("stand inconnu : " + id)
		return null
	var v := st.view()
	game.player.global_position = v["pos"]
	if auto:
		st.auto_rules = true
	st.enter()
	return st

## Direction de la lune (la « lumière du soleil » de la nuit).
func _moon_dir() -> Vector3:
	var atmo: Node = game.atmosphere
	if atmo and atmo.has_method("moon_direction"):
		return atmo.call("moon_direction")
	return Vector3(0.4, 0.5, -0.75).normalized()

# ---------------------------------------------------------------- stands (mini-jeux)
func _build_stalls() -> void:
	if not stalls.is_empty():
		return
	for d in STALLS:
		if not ResourceLoader.exists(String(d["script"])):
			continue
		var st: StallGame = load(String(d["script"])).new()
		st.name = "Stall_" + String(d["id"])
		var p: Vector3 = d["pos"]
		st.position = Vector3(p.x, TERRAIN.walk_y(p.x, p.z), p.z)
		st.rotation_degrees.y = float(d["yaw"])
		_root.add_child(st)
		st.setup(game, self)
		stalls[String(d["id"])] = st
		var area: Interactable = game._make(st, st.area_size(), st.area_offset(),
			func() -> String:
				if not active or finale_running:
					return ""
				return st.prompt(),
			func(_p): st.enter())
		area.name = "StallArea"

func _clear_stalls() -> void:
	for k in stalls:
		if is_instance_valid(stalls[k]):
			(stalls[k] as Node).queue_free()
	stalls.clear()

## Le stand que tient ce personnage (null s'il n'en tient pas).
func stall_of(who: String) -> StallGame:
	for k in stalls:
		if (stalls[k] as StallGame).host == who:
			return stalls[k]
	return null

func _clear_guests() -> void:
	for who in guests:
		if is_instance_valid(guests[who]):
			(guests[who] as Node3D).queue_free()
	guests.clear()
	if _cat != null and is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null

## Bilan de la fête pour l'écran de fin de démo.
func summary_lines() -> Array:
	if data().is_empty() or not announced():
		return []
	var out := []
	for p in data().get("preparations", []):
		var id := String(p.get("id", ""))
		out.append([String(p.get("label", id)), "%d / %d" % [mini(prep_value(id), prep_target(id)), prep_target(id)]])
	var games: Dictionary = state().get(StallGame.STATE_KEY, {})
	var played := 0
	for d in STALLS:
		if int((games.get(String(d["id"]), {}) as Dictionary).get("plays", 0)) > 0:
			played += 1
	if played > 0:
		out.append(["Stands essayés", "%d / %d" % [played, STALLS.size()]])
	var souv: Dictionary = state().get("souvenirs", {})
	var n := 0
	for k in souv:
		n += int(souv[k])
	if n > 0:
		out.append(["Souvenirs de la fête", str(n)])
	return out

# ---------------------------------------------------------------- tests
## Préparatifs faits par les mêmes fonctions que le joueur (godot --path . -- --autoplay --days=5).
func autoplay_prepare() -> void:
	if not built:
		return
	var pl: CharacterBody3D = game.player
	for i in _poles.size():
		if _poles[i][1] == null and not prep_done("lanternes"):
			pl.set_carry(&"")
			_take(&"chochin", "lanternes")
			_hang(i)
	for i in _nobori.size():
		if _nobori[i][1] == null and not prep_done("nobori"):
			pl.set_carry(&"")
			_take(&"nobori", "nobori")
			_plant(i)
	for k in _missing():
		GameState.add_item(String(k), int(_missing()[k]))
	_deposit()
	print("AUTOPLAY fête : lanternes %d/%d, nobori %d/%d, offrandes %d/%d, invités %s" % [prep_value("lanternes"),
		prep_target("lanternes"), prep_value("nobori"), prep_target("nobori"), prep_value("offrandes"),
		prep_target("offrandes"), str(invited())])

func autoplay_festival() -> void:
	autoplay_prepare()
	print("AUTOPLAY calendrier : %s" % str(calendar_data().get("countdown", "")))
	await open_festival()
	print("AUTOPLAY fête ouverte, invités : %s" % str(guests.keys()))
	var vn: Node = game.vn
	var pump := func() -> void:
		if vn.visible:
			vn.set("_advance", true)
			for b in (vn.get("_choices") as Node).get_children():
				if b is Button:
					(b as Button).pressed.emit()
					break
	for who in guests.keys():
		_greet(who, Story.find_visit(String(data()["guests"][who])))
		while not game.player.input_enabled:
			pump.call()
			await get_tree().create_timer(0.2).timeout
		print("AUTOPLAY invité salué : %s" % who)
	print("AUTOPLAY cloche : %s" % bell_prompt())
	game._ring_bell()
	var d0 := GameState.day
	while GameState.day == d0:
		pump.call()
		await get_tree().create_timer(0.2).timeout
	print("AUTOPLAY fin de la fête, drapeaux : %s" % str(GameState.flags.keys()))
