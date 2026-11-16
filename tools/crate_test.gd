extends Node
## Vérifie que les paniers de préparation montrent ce qu'il reste à placer.
##   godot --path . -- --tool res://tools/crate_test.gd [dossier_captures] --day=4
## Avec un dossier : capture des paniers pleins, puis après avoir posé 3 lanternes et 1 banderole.

func _count(c: Node3D) -> int:
	var n := 0
	for s in c.get_children():
		if String(s.name).begins_with("Supply_") and (s as Node3D).visible:
			n += 1
	return n

func run(g: Node3D, _a: PackedStringArray) -> void:
	await get_tree().create_timer(2.0).timeout
	var f: Node = g.festival
	if not f.built:
		f._build()
	var log := func(m: String): print("CRATE %s : lanternes %d, banderoles %d" % [m, _count(f._crate_l), _count(f._crate_n)])
	log.call("départ")
	f._take(&"chochin", "lanternes")
	log.call("lanterne en main")
	f._hang(0)
	log.call("lanterne accrochée")
	f._take(&"nobori", "nobori")
	log.call("banderole en main")
	g.player.set_carry(&"")
	log.call("banderole lâchée")
	f._take(&"nobori", "nobori")
	f._plant(0)
	log.call("banderole plantée")
	if _a.size() > 2 and not _a[2].begins_with("--"):
		await _shots(g, f, _a[2])
	get_tree().quit()

func _shot(g: Node3D, path: String) -> void:
	g.hud.visible = false
	g.player.global_position = Vector3(-3.3, g.TERRAIN.walk_y(-3.3, -12.2) + 0.05, -12.2)
	g.player.rotation_degrees.y = 90.0
	g.player.head.rotation_degrees.x = -28.0
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CRATE capture ", path)

func _shots(g: Node3D, f: Node, dir: String) -> void:
	# remet tout à zéro, capture pleine, puis en pose quelques-uns
	g.player.set_carry(&"")
	GameState.festival = {"lanternes": [], "nobori": [], "offrandes": {}}
	f._refresh()
	await _shot(g, dir + "/crates_full.png")
	for i in 3:
		f._take(&"chochin", "lanternes")
		f._hang(i)
	f._take(&"nobori", "nobori")
	f._plant(0)
	f._take(&"chochin", "lanternes")
	await _shot(g, dir + "/crates_after.png")
