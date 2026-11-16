extends Node
## Mochi dans le monde (scripts/cat.gd) : endormi au soleil, réveillé quand on approche, caressé, puis une marche.
##   godot --path . -- --tool res://tools/cat_test.gd dossier_captures

func run(g: Node3D, a: PackedStringArray) -> void:
	var out := a[2]
	await get_tree().create_timer(4.0).timeout
	GameState.set_phase(GameState.Phase.VISIT)
	g._apply_lighting(GameState.Phase.VISIT, true)
	g.player.head.position.y = 0.75          # caméra basse, à hauteur de chat
	var cat: Cat = g.props.get_node("Mochi")
	var c := cat.global_position
	print("CATTEST Mochi en ", c, " anim ", cat.current)
	# loin : il dort ; on se place à 4 m pour la photo, sans le réveiller
	await _look(g, c + Vector3(1.2, 0, 2.3), c, out + "/cat_sleep.png", 4.0)
	print("CATTEST endormi : ", cat.current)
	await _look(g, c + Vector3(0.9, 0, 0.7), c, out + "/cat_sit.png", 2.0)
	print("CATTEST réveillé : ", cat.current)
	cat.pet()
	await _look(g, c + Vector3(0.9, 0, 0.7), c, out + "/cat_content.png", 1.0)
	print("CATTEST caressé : ", cat.current)
	# marche : il part vers un point à 2 m, on photographie à mi-chemin
	cat.behave = false
	var to := c + Vector3(1.6, 0, -1.6)
	to.y = g.TERRAIN.walk_y(to.x, to.z)
	cat.walk_to(to, 0.45, Callable(g.TERRAIN, "walk_y"))
	await get_tree().create_timer(2.0).timeout
	var m := cat.global_position
	print("CATTEST pendant la marche : ", m, " vers ", to, " anim ", cat.current, " vitesse ", cat.anim.speed_scale)
	await _look(g, m + Vector3(1.4, 0, 0.6), m, out + "/cat_walk.png", 0.15)
	print("CATTEST marche : ", cat.current)
	get_tree().quit()

func _look(g: Node3D, p: Vector3, at: Vector3, path: String, wait: float) -> void:
	g.hud.visible = false
	g.player.global_position = Vector3(p.x, g.ground_y(p.x, p.z) + 0.05, p.z)
	g.player.rotation.y = atan2(-(at.x - p.x), -(at.z - p.z))
	var d := Vector2(at.x - p.x, at.z - p.z).length()
	g.player.head.rotation.x = -atan2(0.55, d)
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png(path)
