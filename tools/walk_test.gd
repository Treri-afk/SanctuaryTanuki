extends Node
## Test de déplacement : godot --path . -- --walktest
## Fait marcher le joueur (vraie touche « avancer ») et vérifie où il arrive : entrer dans le salon de thé
## par les marches, et rester bloqué par ses murs.

func run(game: Node3D) -> void:
	var p: CharacterBody3D = game.player
	await get_tree().create_timer(2.0).timeout
	var th: Node3D = game.props.get_node("TeaHouse")
	# devant les marches, face à l'entrée (l'avant du salon regarde vers -X)
	var front := th.global_position + Vector3(-5.6, 0.0, 0.0)
	await _walk(p, front, -90.0, 3.2)
	var inside := p.global_position
	print("WALK entrée : x=%.2f y=%.2f (plancher à 0,68 ; intérieur si x > %.2f)" % [inside.x, inside.y, th.global_position.x - 1.75])
	print("WALK %s on entre dans le salon de thé" % ["ok" if inside.y > 0.55 and inside.x > th.global_position.x - 1.75 else "ÉCHEC"])
	var amb: Ambience = game.get("ambience")
	if amb:
		await game.get_tree().create_timer(1.2).timeout
		print("WALK %s ambiance d'intérieur dans le salon (dedans=%.2f)" % ["ok" if amb.get("_in") > 0.5 else "ÉCHEC", amb.get("_in")])
	# contre le mur du fond : on ne doit pas le traverser
	await _walk(p, inside, -90.0, 3.0)
	print("WALK %s le mur du fond arrête (x=%.2f, mur à %.2f)" % ["ok" if p.global_position.x < th.global_position.x + 3.1 else "ÉCHEC", p.global_position.x, th.global_position.x + 3.1])
	# à côté de l'entrée : le shoji fermé bloque
	await _walk(p, th.global_position + Vector3(-5.6, 0.0, 2.4), -90.0, 3.0)
	print("WALK %s le shoji fermé bloque (x=%.2f)" % ["ok" if p.global_position.x < th.global_position.x - 1.6 else "ÉCHEC", p.global_position.x])
	# sous chaque petit torii (portes de l'enceinte, sentier) : la traverse basse doit passer au-dessus de la caméra
	# chemin des mille torii : on le remonte d'un bout à l'autre sans rester coincé entre les piliers
	p.global_position = Vector3(0.0, Terrain.walk_y(0.0, -37.4) + 0.05, -37.4)
	p.velocity = Vector3.ZERO
	p.input_enabled = true
	var goals := [Vector2(0, -41), Vector2(-4, -47), Vector2(-9, -55), Vector2(-7.6, -60.4)]
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	for gpt in goals:
		while Vector2(p.global_position.x, p.global_position.z).distance_to(gpt) > 0.9 and Time.get_ticks_msec() - t0 < 30000:
			var d: Vector2 = gpt - Vector2(p.global_position.x, p.global_position.z)
			p.rotation_degrees.y = rad_to_deg(atan2(-d.x, -d.y))
			await get_tree().physics_frame
	Input.action_release("move_forward")
	var end := Vector2(p.global_position.x, p.global_position.z)
	print("WALK %s tunnel de torii traversé en %.1f s (arrivée %.1f, %.1f)" % ["ok" if end.distance_to(goals[-1]) < 1.2 else "ÉCHEC",
		(Time.get_ticks_msec() - t0) / 1000.0, end.x, end.y])
	await get_tree().create_timer(0.3).timeout
	for n in ["ToriiWest", "ToriiEast", "ToriiBack", "Senbon/Senbon_0", "Senbon/Senbon_40", "Torii", "ToriiBottom"]:
		var t: Node3D = game.props.get_node_or_null(n)
		if t == null:
			continue
		var lowest := INF
		var inv := t.global_transform.affine_inverse()
		for mi in t.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for si in m.mesh.get_surface_count():
				var arr := m.mesh.surface_get_arrays(si)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				# triangles qui enjambent l'axe du passage (x local = 0), au-dessus de 1 m : ce que la tête croise
				for k in range(0, ids.size(), 3):
					var a3: Array = []
					for q in 3:
						a3.append(inv * (m.global_transform * vs[ids[k + q]]))
					var xs := [a3[0].x, a3[1].x, a3[2].x]
					if xs.min() <= 0.0 and xs.max() >= 0.0 and absf(a3[0].z) < 0.6:
						var wy: float = minf(minf(a3[0].y, a3[1].y), a3[2].y) * t.scale.y
						if wy > 1.0:
							lowest = minf(lowest, wy)
		var eye := 1.6 + 0.04       # yeux + balancement de tête
		print("WALK %s %s : traverse la plus basse à %.2f m (yeux à %.2f)" % ["ok" if lowest > eye + 0.5 else "ÉCHEC", n, lowest, eye])
	print("WALK fin")
	get_tree().quit()

func _walk(p: CharacterBody3D, from: Vector3, yaw: float, seconds: float) -> void:
	p.global_position = Vector3(from.x, Terrain.walk_y(from.x, from.z) + 0.05, from.z) if from.y < 0.3 else from
	p.velocity = Vector3.ZERO
	p.rotation_degrees.y = yaw
	p.head.rotation_degrees.x = 0.0
	p.input_enabled = true
	await get_tree().physics_frame
	Input.action_press("move_forward")
	await get_tree().create_timer(seconds).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.4).timeout
