extends Node
## Test des gestes avec de vraies entrées souris simulées (Input.parse_input_event), pas des appels directs.
## godot --path . -- --feeltest --tasks=fontaine,bambou      (lancé par game.gd)
## Chaque vérification affiche « FEEL ok » ou « FEEL ÉCHEC ».

var game: Node3D
var player: CharacterBody3D

func run(g: Node3D) -> void:
	game = g
	player = g.player
	Engine.time_scale = 1.0
	await _wait(4.5)
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if GameState.morning.has(&"fontaine"):
		await _test_water()
	if GameState.morning.has(&"bambou"):
		await _test_bamboo()
	if GameState.morning.has(&"balayer"):
		await _test_leaves()
	if GameState.morning.has(&"haies"):
		await _test_hedges()
	if GameState.morning.has(&"priere"):
		await _test_prayer()
	if GameState.morning.has(&"reparer"):
		await _test_repair()
	await _test_patience()
	print("FEEL fin")
	get_tree().quit()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _check(label: String, ok: bool, detail: String = "") -> void:
	print("FEEL %s %s %s" % ["ok" if ok else "ÉCHEC", label, detail])

func _stand_and_look(stand: Vector3, at: Vector3) -> void:
	stand.y = Terrain.walk_y(stand.x, stand.z) + 0.05
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var d := at - (stand + Vector3(0, 1.6, 0))
	player.rotation.y = atan2(-d.x, -d.z)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _frames(3)

func _press(on: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = on
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if on else 0
	Input.parse_input_event(e)
	await _frames(1)

func _move(rel: Vector2, frames: int) -> void:
	for i in frames:
		var e := InputEventMouseMotion.new()
		e.relative = rel / frames
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
		Input.parse_input_event(e)
		await get_tree().physics_frame

func _test_water() -> void:
	var t: Node = game.tasks[&"fontaine"]
	game._equip(&"bucket")
	var well: Node3D = game.props.get_node("Well")
	await _stand_and_look(well.global_position + Vector3(-1.4, 0, 1.2), well.global_position + Vector3(0, 0.7, 0))
	_check("visée du puits", player.target != null and player.target.lock_look, "invite=" + player.prompt_text)
	var yaw0: float = player.rotation.y
	await _press(true)
	await _move(Vector2(0, 450), 20)
	_check("le regard reste figé pendant la corde", absf(player.rotation.y - yaw0) < 0.001 and player.look_locked)
	var mid: float = t.rope_prog
	_check("la corde monte", mid > 0.3, "prog=%.2f" % mid)
	await _press(false)
	await _wait(0.5)
	_check("le seau redescend si on lâche", t.rope_prog < mid, "prog=%.2f" % t.rope_prog)
	await _press(true)
	await _move(Vector2(0, 900), 30)
	await _press(false)
	_check("seau plein après la corde", player.bucket_level > 0.99, "niveau=%.2f" % player.bucket_level)
	# porter : un demi-tour lent ne renverse rien, un coup sec renverse
	await _move(Vector2(700, 0), 60)
	var after_slow: float = player.bucket_level
	_check("tour lent sans perte", after_slow > 0.97, "niveau=%.2f" % after_slow)
	await _move(Vector2(1400, 0), 4)
	await _frames(2)
	var after_flick: float = player.bucket_level
	_check("coup sec : l'eau déborde", after_flick < after_slow - 0.03, "niveau=%.2f" % after_flick)
	# verser
	var basin: Node3D = game.props.get_node("WaterBasin")
	await _stand_and_look(basin.global_position + Vector3(1.5, 0, 0.6), basin.global_position + Vector3(0, 0.6, 0))
	var f0: float = t.fill
	await _press(true)
	await _wait(1.0)
	_check("verser remplit la fontaine", t.fill > f0 + 0.1 and player.action == &"" , "fontaine %.2f -> %.2f, seau %.2f" % [f0, t.fill, player.bucket_level])
	await _press(false)
	game.player_put_back_tool()

func _test_bamboo() -> void:
	var t: Node = game.tasks[&"bambou"]
	game._equip(&"sickle")
	var s: Dictionary = t.stalks[0]
	var n: Node3D = s["node"]
	await _stand_and_look(n.global_position + Vector3(1.4, 0, 0.9), n.global_position + Vector3(0, 1.0, 0))
	_check("visée d'une pousse", player.target != null and player.target == s["area"], "invite=" + player.prompt_text)
	await _press(true)
	await _move(Vector2(160, 0), 40)   # geste lent : ne coupe pas
	await _press(false)
	_check("geste lent : pas de coupe", not s["cut"])
	await _press(true)
	await _move(Vector2(-260, 0), 4)    # geste vif
	await _press(false)
	_check("geste vif : la pousse tombe", s["cut"], "progression=%d" % GameState.progress.get(&"bambou", 0))
	game.player_put_back_tool()

func _test_leaves() -> void:
	var t: Node = game.tasks[&"balayer"]
	game._equip(&"broom")
	var c: Vector3 = t.centers[0]
	await _stand_and_look(c + Vector3(0, 0, 3.0), c + Vector3(0, 0, -1))
	var before: int = GameState.progress.get(&"balayer", 0)
	await _press(true)
	var e := InputEventAction.new()
	e.action = "move_forward"
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(1.2)
	e.pressed = false
	Input.parse_input_event(e)
	var in_pile := 0
	if t.pushed != null:
		in_pile = int(t.pushed["n"])
	_check("le balai ramasse un tas en avançant", in_pile > 5, "feuilles dans le tas=%d" % in_pile)
	# pousser jusqu'au panier le plus proche
	var b: Node3D = t.baskets[0]
	await _stand_and_look(b.global_position + Vector3(2.2, 0, 0), b.global_position)
	await _frames(4)
	Input.parse_input_event(e)
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(1.0)
	e.pressed = false
	Input.parse_input_event(e)
	await _press(false)
	_check("le tas se vide dans le panier", int(GameState.progress.get(&"balayer", 0)) > int(before), "progression=%d" % GameState.progress.get(&"balayer", 0))
	game.player_put_back_tool()

func _test_hedges() -> void:
	var t: Node = game.tasks[&"haies"]
	game._equip(&"shears")
	var h: Node3D = t.hedge_nodes[0]
	await _stand_and_look(h.global_position + Vector3(0, 0, 1.6), h.global_position + Vector3(-1.5, 0.9, 0))
	var before := int(GameState.progress.get(&"haies", 0))
	await _press(true)
	await _move(Vector2(900, 120), 90)
	await _press(false)
	var after := int(GameState.progress.get(&"haies", 0))
	_check("la cisaille coupe en balayant la haie", after > before, "%d -> %d" % [before, after])
	game.player_put_back_tool()

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(1)
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(1)

func _click() -> void:
	await _press(true)
	await _frames(2)
	await _press(false)
	await _frames(2)

func _test_prayer() -> void:
	var t: Node = game.tasks[&"priere"]
	await _stand_and_look(t.spot.global_position + Vector3(0.3, 0, 1.6), t.spot.global_position + Vector3(0, 1.0, 0))
	_check("visée de la prière", player.prompt_text.begins_with("E :"), "invite=" + player.prompt_text)
	await _key(KEY_E)
	await _wait(0.8)
	_check("rite commencé, pas bloqué", t.praying and player.move_locked)
	await _click()                       # pièce
	await _click()                       # clic hors étape (salut attendu) : ne doit pas avancer
	var s1: int = t.step
	for k in 2:                          # deux saluts
		await _move(Vector2(0, 420), 12)
		await _move(Vector2(0, -420), 12)
	await _click()
	await _click()                       # deux frappes
	await _move(Vector2(0, 420), 12)
	await _move(Vector2(0, -420), 12)    # dernier salut
	await _frames(3)
	_check("rite complet", GameState.is_done(&"priere") and not player.move_locked, "étape après clic hors-rite=%d, fin=%d/6" % [s1, GameState.progress.get(&"priere", 0)])

func _test_repair() -> void:
	var t: Node = game.tasks[&"reparer"]
	game._equip(&"hammer")
	var b: Dictionary = t.boards[0]
	var bn: Node3D = b["node"]
	var nrm: Vector3 = (b["target"] as Transform3D).basis.z
	await _stand_and_look(bn.global_position + nrm * 1.6, bn.global_position)
	await _key(KEY_E)
	await _wait(0.8)
	_check("une planche remise en place", t.nails.size() >= 2, "clous=%d" % t.nails.size())
	for bb in t.boards:
		if bb["placed"]:
			b = bb
	var n: Dictionary = t.nails[0]
	var nd: Node3D = n["node"]
	var tgt: Transform3D = b["target"]
	await _stand_and_look(nd.global_position + tgt.basis.z * 1.3 + Vector3(0, -0.4, 0), nd.global_position)
	_check("visée du clou", player.target == n["area"], "invite=" + player.prompt_text)
	await _frames(2)
	await _click()                       # frappe au mauvais moment : ne doit pas suffire
	var d1: float = n["depth"]
	# attendre le bon moment du cercle
	var guard := 0
	while t.ring_t < 0.85 and guard < 200:
		await get_tree().physics_frame
		guard += 1
	await _click()
	_check("frappe au bon moment enfonce le clou", float(n["depth"]) >= 1.0, "profondeur après 1re frappe=%.2f, après frappe parfaite=%.2f" % [d1, n["depth"]])
	game.player_put_back_tool()

func _test_patience() -> void:
	var vs := Story.visits_for_day(GameState.day, RandomNumberGenerator.new())
	if vs.is_empty():
		return
	game.visit_queue.clear()
	Engine.time_scale = 4.0
	game._spawn_visit(vs[0])
	var guard := 0
	while not game._visitor_ready_flag and guard < 3000:
		await get_tree().process_frame
		guard += 1
	var who := String(vs[0]["character"])
	print("FEEL info visiteur prêt=%s après %d images, saisie=%s" % [game._visitor_ready_flag, guard, player.input_enabled])
	var a0 := int(GameState.affection.get(who, 0))
	game._patience = 0.3
	await _wait(2.0)
	Engine.time_scale = 1.0
	_check("un visiteur ignoré repart", int(GameState.missed.get(who, 0)) == 1 and int(GameState.affection.get(who, 0)) == a0 - 1 and not game._visitor_ready_flag,
		"%s : manqué=%d, affection %d -> %d, état de l'ema=%d" % [who, GameState.missed.get(who, 0), a0, GameState.affection.get(who, 0), GameState.ema_state(who)])
