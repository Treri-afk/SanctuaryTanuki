class_name Shop
extends Node
## Boutique du bureau du sanctuaire (shamusho, à l'ouest de la cour) : on y dépense les pièces des offrandes.
##
## Catalogue (ITEMS) — chaque objet a un vrai effet en jeu :
##   encens      réserve ; à allumer au brûle-parfum près du tronc à offrandes. Ce jour-là, chaque visiteur
##               reçu gagne +1 d'affection en plus (l'odeur l'apaise).
##   granules    réserve ; la prochaine fois qu'on nourrit les carpes, elles grandissent deux fois plus
##               le lendemain (scripts/koi_pond.gd). Les granulés lancés sont dorés tant qu'il en reste.
##   omamori     objet de poche (inventaire) à offrir ; tout le monde l'apprécie (« aime », +1), sauf goût
##               contraire écrit dans l'éditeur d'histoire.
##   ema_vierge  on y écrit son propre vœu, accroché aussitôt au présentoir (un par jour).
##   priere_retour:<personnage>  n'apparaît que pour quelqu'un qui ne monte plus (son ema s'est brisé) :
##               il pourra revenir (GameState.bring_back).
## Les prix suivent l'économie actuelle : ~5 pièces de départ, ~4 à 8 pièces d'offrandes par jour.

const ITEMS := {
	"encens": {"name": "Bâton d'encens", "price": 2, "max": 5, "color": "#9C6B3E",
		"desc": "À allumer dans le brûle-parfum, près du tronc à offrandes. Les visiteurs du jour en sont apaisés."},
	"granules": {"name": "Granulés de qualité", "price": 2, "max": 5, "color": "#E2B04A",
		"desc": "Pour les carpes : nourries avec, elles grandissent deux fois plus le lendemain."},
	"omamori": {"name": "Omamori", "price": 3, "color": "#C8442B", "gift": "like",
		"desc": "Amulette brodée, dans son petit sachet de soie. Un cadeau que chacun apprécie."},
	"ema_vierge": {"name": "Ema vierge", "price": 1, "color": "#C9A06A",
		"desc": "Une plaquette de bois à votre vœu. Écrivez-le, elle rejoint le présentoir."},
}
const RETURN_PRICE := 6
const COUNTER := Vector3(-17.35, 0.0, -3.05)    # devant le comptoir du bureau (si le repère du modèle manque)
const KORO_POS := Vector3(-1.9, 0.0, -15.6)     # à gauche du tronc à offrandes

var game: Node3D
var incense_lit := false
var _ema_day := 0
var _koro: Node3D
var _incense: Node3D

## Fiche d'un objet de la boutique ({} si inconnu) : sert aussi à Story pour les noms et couleurs.
static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

func setup(g: Node3D) -> void:
	game = g
	var counter := Node3D.new()
	counter.name = "ShopCounter"
	game.props.add_child(counter)
	# le comptoir est un repère du modèle du bureau (shamusho.glb : shop_counter) ; sinon position par défaut
	var office: Node3D = game.props.get_node_or_null("Shamusho")
	var mark: Node3D = office.find_child("shop_counter", true, false) if office else null
	counter.global_position = mark.global_position if mark else COUNTER
	game._make(counter, Vector3(1.4, 2.0, 4.0), Vector3(0.35, 1.0, 0),
		func() -> String:
			if GameState.phase == GameState.Phase.NIGHT:
				return "Le bureau est fermé pour la nuit"
			return "E : Bureau du sanctuaire  (encens, omamori, ema...)",
		func(_p): open())
	# brûle-parfum
	_koro = game._model("koro", Color("#6A5638"))
	_koro.name = "Koro"
	_koro.position = KORO_POS
	_koro.rotation_degrees.y = 20.0
	game.props.add_child(_koro)
	game._make(_koro, Vector3(0.8, 1.2, 0.8), Vector3(0, 0.6, 0),
		func() -> String:
			if incense_lit:
				return "L'encens se consume doucement"
			if int(GameState.stock.get("encens", 0)) > 0:
				return "E : Allumer un bâton d'encens  (%d en réserve)" % int(GameState.stock["encens"])
			return "Brûle-parfum — l'encens se trouve au bureau du sanctuaire",
		func(_p): light_incense())

func on_day_start() -> void:
	incense_lit = false
	if _incense and is_instance_valid(_incense):
		_incense.queue_free()
	_incense = null

## Après un dialogue : l'encens du jour apaise le visiteur.
func after_visit(who: String) -> void:
	if not incense_lit or Story.is_animal(who):
		return
	GameState.add_affection(who, 1, Story.affection_max(who))
	Events.toast.emit("%s s'attarde un instant dans l'odeur de l'encens." % Story.display_name(who))

# ---------------------------------------------------------------- catalogue et achats
func catalog() -> Array:
	var rows := []
	for id in ITEMS:
		var it: Dictionary = ITEMS[id]
		var row := {"id": id, "name": it["name"], "desc": it["desc"], "price": int(it["price"]), "note": "", "ok": true, "why": ""}
		match id:
			"encens", "granules":
				var n := int(GameState.stock.get(id, 0))
				row["note"] = "en réserve : %d" % n
				if n >= int(it["max"]):
					row["ok"] = false
					row["why"] = "Réserve pleine"
			"omamori":
				row["note"] = "dans vos poches : %d" % GameState.item_count("omamori")
				if GameState.inventory_total() >= GameState.INVENTORY_MAX:
					row["ok"] = false
					row["why"] = "Poches pleines"
			"ema_vierge":
				if _ema_day == GameState.day:
					row["ok"] = false
					row["why"] = "Un vœu par jour"
		rows.append(row)
	for who in GameState.gone:
		if GameState.gone[who]:
			rows.append({"id": "priere_retour:" + String(who), "name": "Prière de retour — %s" % Story.display_name(who),
				"desc": "Une prière pour %s, qui ne monte plus. On dit qu'elle est toujours entendue." % Story.display_name(who),
				"price": RETURN_PRICE, "note": "", "ok": true, "why": ""})
	for r in rows:
		if r["ok"] and GameState.coins < int(r["price"]):
			r["ok"] = false
			r["why"] = "Pas assez de pièces"
	return rows

func open() -> void:
	if GameState.phase == GameState.Phase.NIGHT:
		return
	game.player.input_enabled = false
	Sfx.play(&"door_slide", game.player.global_position)
	while true:
		var pick: String = await game.hud.show_shop("Bureau du sanctuaire", catalog())
		if pick == "":
			break
		await _buy(pick)
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _buy(id: String) -> void:
	var price := RETURN_PRICE if id.begins_with("priere_retour:") else int(item(id).get("price", 0))
	if not GameState.spend_coins(price):
		return
	Sfx.play(&"coin")
	match id:
		"encens", "granules":
			GameState.stock[id] = int(GameState.stock.get(id, 0)) + 1
		"omamori":
			if not GameState.add_item("omamori"):
				GameState.add_coins(price)       # poches pleines : on rend la monnaie
		"ema_vierge":
			var wish: String = await game.hud.ask_text("Votre vœu, sur l'ema", "Que la montagne...", 48)
			wish = wish.strip_edges()
			if wish == "":
				GameState.add_coins(price)
				return
			_ema_day = GameState.day
			game.extras.hang_player_ema(wish)
		_:
			if id.begins_with("priere_retour:"):
				var who := id.trim_prefix("priere_retour:")
				GameState.bring_back(who)
				game.extras.refresh_visitor_ema()
				GameState.note("J'ai fait une prière de retour pour %s." % Story.display_name(who))
				Events.toast.emit("La prière s'élève. %s remontera peut-être l'escalier." % Story.display_name(who))

## Test : godot --path . -- --shoptest  (achète chaque objet par les mêmes fonctions que l'interface)
func selftest() -> void:
	var ok := func(cond: bool, what: String): print("SHOPTEST %s %s" % ["ok" if cond else "ÉCHEC", what])
	GameState.add_coins(30)
	var c0 := GameState.coins
	await _buy("encens")
	ok.call(int(GameState.stock.get("encens", 0)) == 1 and GameState.coins == c0 - 2, "encens acheté, 2 pièces")
	light_incense()
	ok.call(incense_lit and int(GameState.stock["encens"]) == 0, "encens allumé")
	var a0 := int(GameState.affection.get("vieille_dame", 0))
	after_visit("vieille_dame")
	ok.call(int(GameState.affection.get("vieille_dame", 0)) == a0 + 1, "visiteur apaisé : affection +1")
	await _buy("granules")
	ok.call(int(GameState.stock.get("granules", 0)) == 1, "granulés en réserve")
	await _buy("omamori")
	ok.call(GameState.item_count("omamori") == 1, "omamori dans les poches")
	ok.call(Story.gift_tier("moine", "omamori") == "like" and Story.item_name("omamori") == "Omamori", "omamori : apprécié, nom connu")
	GameState.met["facteur"] = true
	GameState.gone["facteur"] = true
	var rows := catalog()
	var has_return := false
	for r in rows:
		if String(r["id"]) == "priere_retour:facteur":
			has_return = true
	ok.call(has_return, "prière de retour proposée pour un visiteur parti")
	await _buy("priere_retour:facteur")
	ok.call(not GameState.gone.get("facteur", false), "prière de retour : le facteur peut revenir")
	GameState.coins = 0
	var all_blocked := true
	for r in catalog():
		if r["ok"]:
			all_blocked = false
	ok.call(all_blocked, "sans pièces, rien n'est achetable")
	print("SHOPTEST fin")
	get_tree().quit()

# ---------------------------------------------------------------- encens
func light_incense() -> void:
	if incense_lit or int(GameState.stock.get("encens", 0)) <= 0:
		return
	GameState.stock["encens"] = int(GameState.stock["encens"]) - 1
	incense_lit = true
	game.player.kick(Vector3(0.3, 0, 0), Vector3(0, -0.05, -0.08), 0.08, 0.4)
	Sfx.play(&"tick", _koro.global_position)
	var anchor: Node3D = _koro.find_child("incense_anchor", true, false)
	var at: Vector3 = anchor.global_position if anchor else _koro.global_position + Vector3(0, 0.7, 0)
	_incense = Node3D.new()
	_incense.name = "Incense"
	game.props.add_child(_incense)
	_incense.global_position = at
	# trois bâtons plantés dans la cendre, la pointe rougeoie
	# matériaux transparents : les contours tracés à l'écran les ignorent (sinon ces brins de 3 mm
	# deviennent une tache noire de loin)
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = Color(0.36, 0.22, 0.14, 0.99)
	stick_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.45, 0.2, 0.99)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 3:
		var s := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0035
		cm.bottom_radius = 0.0035
		cm.height = 0.24
		cm.radial_segments = 5
		s.mesh = cm
		s.material_override = stick_mat
		var off := Vector3(cos(k * 2.1) * 0.025, 0.12, sin(k * 2.1) * 0.025)
		s.position = off
		s.rotation_degrees = Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		_incense.add_child(s)
		var tip := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.006
		sm.height = 0.012
		tip.mesh = sm
		tip.material_override = glow
		tip.position = off + Vector3(0, 0.12, 0)
		_incense.add_child(tip)
	_incense.add_child(_smoke())
	GameState.note("J'ai allumé de l'encens au brûle-parfum.")
	Events.toast.emit("Un filet de fumée monte du brûle-parfum. Les visiteurs d'aujourd'hui l'apprécieront.")

## Fumée d'encens : volutes douces qui montent, s'élargissent et s'effacent, poussées par l'air.
func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/smoke.gdshader")
	q.material = m
	p.mesh = q
	p.amount = 22
	p.lifetime = 4.5
	p.position = Vector3(0, 0.25, 0)
	p.direction = Vector3.UP
	p.spread = 6.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0.05, 0.07, 0.02)
	p.damping_min = 0.02
	p.damping_max = 0.05
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.92, 0.9, 0.88, 0.0))
	ramp.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	ramp.add_point(0.15, Color(0.92, 0.9, 0.88, 0.5))     # ajouté après : l'ajout décale les index
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
