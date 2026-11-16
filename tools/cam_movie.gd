extends Node
## Plan fixe pour filmer un décor qui bouge (vent, eau, lanternes) avec le Movie Maker de Godot :
##   godot --path . --write-movie film.avi --fixed-fps 30 -- --cammovie x y z yaw pitch secondes [fete|lune] --day=5
## y : position des pieds du joueur (« auto » : posé au sol). Le jeu quitte à la fin.

func run(g: Node3D, a: PackedStringArray) -> void:
	await get_tree().create_timer(1.5).timeout
	if a.size() > 7 and (a[7] == "fete" or a[7] == "lune"):
		g.festival.debug_fill()
		if a[7] == "lune":
			g.festival.debug_evening(true)
	g.hud.visible = false
	g.player.input_enabled = false
	var x := float(a[1])
	var z := float(a[3])
	var y: float = g.TERRAIN.walk_y(x, z) + 0.05 if a[2] == "auto" else float(a[2])
	g.player.global_position = Vector3(x, y, z)
	g.player.rotation_degrees.y = float(a[4])
	g.player.head.rotation_degrees.x = float(a[5])
	await get_tree().create_timer(float(a[6])).timeout
	get_tree().quit()
