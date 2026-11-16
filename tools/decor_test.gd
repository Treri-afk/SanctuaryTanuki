extends Node
## Vérifie la décoration libre (scripts/decor.gd) par les mêmes fonctions que le joueur : fantôme, raisons de refus,
## pose, arranger/ranger, s'asseoir, remarques des visiteurs, sauvegarde.
##   godot --path . -- --tool res://tools/decor_test.gd [dossier_captures]

var g: Node3D
var d: Decor
var out := ""

func run(game: Node3D, a: PackedStringArray) -> void:
	g = game
	d = g.decor
	out = a[2] if a.size() > 2 and not a[2].begins_with("--") else ""
	await get_tree().create_timer(4.0).timeout
	var ok := func(c: bool, what: String): print("DECORTEST %s %s" % ["ok" if c else "ÉCHEC", what])
	Decor.give("banc", 2)
	ok.call(Decor.owned("banc") == 2, "bancs reçus dans la réserve")
	# refus : l'allée
	var why: String = await _aim_ghost("banc", Vector3(0.3, 0, -3.0), 0.0)
	ok.call(why.contains("allée"), "refus sur l'allée : « %s »" % why)
	if out != "":
		await _shot(out + "/decor_ghost_refus.png")
	d._cancel()
	var spots := [["banc", Vector3(-5.6, 0, 0.6), 90.0], ["banc", Vector3(-4.0, 0, 3.0), 120.0]]
	for s in spots:
		why = await _aim_ghost(s[0], s[1], s[2])
		if out != "" and not FileAccess.file_exists(out + "/decor_ghost_ok.png"):
			await _shot(out + "/decor_ghost_ok.png")
		if why != "":
			print("DECORTEST note %s refusé en %s : %s" % [s[0], str(s[1]), why])
			d._cancel()
			continue
		d._try_place()
		await get_tree().process_frame
	ok.call(Decor.placed_count() == 2 and Decor.owned("banc") == 0, "deux bancs posés, réserve vide")
	if out != "":
		await _look(Vector3(0.6, 0, 5.5), Vector3(-4.5, 0, -1.0), -10.0)
		await _shot(out + "/decor_cour.png")
		await _look(Vector3(-1.4, 0, 1.6), Vector3(-4.0, 0, -1.6), -22.0)
		await _shot(out + "/decor_proche.png")
	# sauvegarde : capture, on vide, on recharge
	var data := SaveGame.capture(g, GameState.day)
	var n0 := Decor.placed_count()
	GameState.decor_placed = []
	d.rebuild()
	SaveGame.apply(g, data)
	d.rebuild()
	ok.call(Decor.placed_count() == n0 and d._nodes.size() == n0, "sauvegarde : %d objets retrouvés" % Decor.placed_count())
	# arranger : on reprend le banc, on annule, il revient ; puis on range le kiku
	var bi := _index("banc")
	if bi >= 0:
		d._enter(Decor.Mode.ARRANGE)
		d._pick_up(bi)
		ok.call(d.mode == Decor.Mode.GHOST and Decor.placed_count() == n0 - 1, "banc repris en main")
		d._cancel()
		ok.call(Decor.placed_count() == n0 and d.mode == Decor.Mode.NONE and not g.player.placing, "annuler : le banc revient")
	d._enter(Decor.Mode.ARRANGE)
	d._store(_index("banc"))
	d._leave()
	ok.call(Decor.owned("banc") == 1 and Decor.placed_count() == n0 - 1, "un banc rangé dans la réserve")
	# s'asseoir
	bi = _index("banc")
	if bi >= 0:
		d._sit(d._nodes[bi])
		await get_tree().create_timer(0.8).timeout
		ok.call(g.player.seated and absf(g.player.head.position.y - Decor.SEAT_EYE) < 0.05, "assis sur le banc")
		if out != "":
			await _shot(out + "/decor_assis.png")
		await d._stand_up()
		ok.call(not g.player.seated and not g.player.placing, "relevé")
	# visiteurs : Fumiko remarque le banc une seule fois
	var a0 := int(GameState.affection.get("vieille_dame", 0))
	d.after_visit("vieille_dame")
	d.after_visit("vieille_dame")
	ok.call(int(GameState.affection.get("vieille_dame", 0)) == a0 + 1, "Fumiko remarque le banc (+1, une fois)")
	print("DECORTEST fin")
	get_tree().quit()

func _index(id: String) -> int:
	for i in GameState.decor_placed.size():
		if String(GameState.decor_placed[i]["id"]) == id:
			return i
	return -1

## Place le joueur à 3 m, le regard sur `at`, et sort le fantôme ; renvoie la raison du refus ("" = possible).
func _aim_ghost(id: String, at: Vector3, yaw: float) -> String:
	var from := at + Vector3(2.6, 0, 1.6)
	await _view(from, rad_to_deg(atan2(-(at.x - from.x), -(at.z - from.z))), 0.0)
	var dist := Vector2(at.x - from.x, at.z - from.z).length()
	g.player.head.rotation.x = -atan2(1.6, dist)
	d.start_ghost(id, yaw)
	for i in 12:
		await get_tree().physics_frame
	return "" if d._ghost_ok else String(g.player.placing_prompt).split("     ")[0]

func _look(p: Vector3, at: Vector3, pitch: float) -> void:
	await _view(p, rad_to_deg(atan2(-(at.x - p.x), -(at.z - p.z))), pitch)

func _view(p: Vector3, yaw: float, pitch: float) -> void:
	g.player.global_position = Vector3(p.x, g.ground_y(p.x, p.z) + 0.05, p.z)
	g.player.rotation_degrees.y = yaw
	g.player.head.rotation_degrees.x = pitch
	for i in 4:
		await get_tree().physics_frame

func _shot(path: String) -> void:
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
