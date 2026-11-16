extends Node
## Captures de la table d'offrandes : vide, à moitié garnie, complète (de jour), complète de nuit.
##   godot --path . -- --tool res://tools/table_test.gd dossier --day=5

func run(g: Node3D, a: PackedStringArray) -> void:
	await get_tree().create_timer(2.0).timeout
	var f: Node = g.festival
	if not f.built:
		f._build()
	var dir: String = a[2]
	g.hud.visible = false
	g.player.input_enabled = false
	var tp: Vector3 = f.TABLE_POS
	g.player.global_position = Vector3(tp.x - 1.0, g.TERRAIN.walk_y(tp.x - 1.0, tp.z) + 0.05, tp.z + 0.25)
	g.player.rotation_degrees.y = -105.0
	g.player.head.rotation_degrees.x = -38.0
	for step in [["vide", {}], ["moitie", {"dango": 1, "kaki": 2, "chataigne": 1, "susuki": 1}],
			["complete", {"dango": 1, "kaki": 3, "chataigne": 3, "susuki": 3}]]:
		GameState.festival["offrandes"] = step[1]
		f._refresh_table()
		await _snap(dir + "/table_%s.png" % step[0])
	GameState.set_phase(3)
	g._apply_lighting(3, true)
	for i in g.lanterns.size():
		g._light(i)
	await get_tree().create_timer(0.5).timeout
	await _snap(dir + "/table_nuit.png")
	get_tree().quit()

func _snap(path: String) -> void:
	for i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("TABLE ", path)
