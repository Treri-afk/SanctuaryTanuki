extends Node
## Audit de performance approfondi.
##   godot --path . -- --deep        rendu : recensement de la scène, appels de dessin, matériaux, lumières,
##                                   particules, mémoire vidéo, à-coups pendant une marche
##   godot --headless --path . -- --cpu   processeur seul (pas de rendu) : coût de chaque sous-système
## Sortie : lignes « DEEP » / « CPU ».

var game: Node3D

func run(g: Node3D) -> void:
	game = g
	print("BOOT jeu prêt à %d ms après le lancement" % Time.get_ticks_msec())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(3.0).timeout
	if OS.get_cmdline_user_args().has("--cpu"):
		await _cpu()
	elif OS.get_cmdline_user_args().has("--groups"):
		await _groups()
	else:
		await _deep()
	get_tree().quit()

# ================================================================ rendu
func _deep() -> void:
	_census()
	var views := [["escalier", Vector3(0, -5.5, 33.0), 0.0, 6.0], ["allée", Vector3(0, 0.1, 4.0), 0.0, -4.0],
		["lisière", Vector3(-14.0, 0.1, -20.0), 90.0, -2.0], ["forêt (sentier nord)", Vector3(-5.0, 6.0, -55.0), 0.0, 0.0]]
	for v in views:
		_place(v[1], v[2], v[3])
		await get_tree().create_timer(1.2).timeout
		var m := await _measure(1.5)
		print("DEEP vue %-22s %5.1f ms  objets=%d  appels=%d  triangles=%dk" % [v[0], m["frame"], m["objects"], m["calls"], m["prims"] / 1000])
	# à-coups : la même marche de 8 s, deux fois. Si les pics disparaissent au second passage, c'est la
	# compilation des shaders (un coût unique à la première apparition d'un matériau).
	for pass_i in 2:
		await _walk_pass(pass_i + 1)
	print("DEEP mémoire vidéo %.0f Mo (tampons %.0f Mo)" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])

func _walk_pass(k: int) -> void:
	var p: CharacterBody3D = game.player
	_place(Vector3(0, 0.1, 9.0), 0.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	p.input_enabled = true
	Input.action_press("move_forward")
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	var t0 := last
	var turned := false
	while Time.get_ticks_usec() - t0 < 8000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		if not turned and now - t0 > 4000000:
			turned = true
			p.rotation_degrees.y = 120.0
	Input.action_release("move_forward")
	p.input_enabled = false
	times.sort()
	var n := times.size()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= maxf(n, 1)
	var spikes := times.filter(func(t): return t > 50.0).size()
	print("DEEP marche %d (8 s) : moyenne %.1f ms, p95 %.1f ms, pire %.1f ms, images > 50 ms : %d" % [k, avg, times[int(n * 0.95)], times[n - 1], spikes])

## Recensement : ce qui existe dans la scène et peut coûter au rendu.
func _census() -> void:
	var meshes := 0
	var mmi := 0
	var mm_inst := 0
	var surfaces := 0
	var mats := {}
	var shadow_casters := 0
	var lights := {"directionnelle": 0, "ponctuelle": 0, "ponctuelle ombrée": 0}
	var parts := 0
	var part_amount := 0
	var by_model := {}
	for n in get_tree().root.find_children("*", "", true, false):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			meshes += 1
			surfaces += mi.mesh.get_surface_count()
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow_casters += 1
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m:
					mats[m.get_instance_id()] = true
			var top := _top_model(mi)
			by_model[top] = int(by_model.get(top, 0)) + mi.mesh.get_surface_count()
		elif n is MultiMeshInstance3D:
			var m2 := n as MultiMeshInstance3D
			if m2.multimesh == null:
				continue
			mmi += 1
			mm_inst += m2.multimesh.instance_count
			var mesh := m2.multimesh.mesh
			if mesh:
				surfaces += mesh.get_surface_count()
				for s in mesh.get_surface_count():
					var m3: Material = m2.material_override if m2.material_override else mesh.surface_get_material(s)
					if m3:
						mats[m3.get_instance_id()] = true
		elif n is DirectionalLight3D:
			lights["directionnelle"] += 1
		elif n is OmniLight3D:
			lights["ponctuelle ombrée" if (n as Light3D).shadow_enabled else "ponctuelle"] += 1
		elif n is CPUParticles3D or n is GPUParticles3D:
			parts += 1
			part_amount += int(n.get("amount"))
	print("DEEP scène : %d nœuds, %d MeshInstance (%d projettent une ombre), %d MultiMesh (%d instances)" % [
		get_tree().get_node_count(), meshes, shadow_casters, mmi, mm_inst])
	print("DEEP %d surfaces, %d matériaux distincts, lumières %s, %d systèmes de particules (%d particules)" % [
		surfaces, mats.size(), str(lights), parts, part_amount])
	var arr := []
	for k in by_model:
		arr.append([by_model[k], k])
	arr.sort_custom(func(a, b): return a[0] > b[0])
	var top := PackedStringArray()
	for e in arr.slice(0, 10):
		top.append("%s %d" % [e[1], e[0]])
	print("DEEP surfaces (MeshInstance) par élément, les plus nombreuses : " + ", ".join(top))

func _top_model(n: Node) -> String:
	var cur := n
	while cur.get_parent() and cur.get_parent().name not in ["Props", "World", "Forest", "Terrain", "Main", "root"]:
		cur = cur.get_parent()
	var nm := String(cur.name)
	var i := nm.find("_")
	return nm.left(i) if i > 0 and nm.substr(i + 1).is_valid_int() else nm

func _place(pos: Vector3, yaw: float, pitch: float) -> void:
	var p: CharacterBody3D = game.player
	p.input_enabled = false
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation_degrees.y = yaw
	p.head.rotation_degrees.x = pitch

func _measure(seconds: float) -> Dictionary:
	var n := 0
	var acc := {"frame": 0.0, "objects": 0.0, "calls": 0.0, "prims": 0.0}
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < int(seconds * 1000000):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		acc["frame"] += (now - last) / 1000.0
		last = now
		acc["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		acc["calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc["prims"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	for k in acc:
		acc[k] /= maxf(n, 1)
	return acc

# ================================================================ processeur (sans rendu)
func _cpu() -> void:
	var p: CharacterBody3D = game.player
	_place(Vector3(0, 0.1, 2.0), 0.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	var base := await _cpu_measure()
	print("CPU base : scripts (_process) %.2f ms par image, physique %.2f ms par pas" % [base[0], base[1]])
	var subs := {
		"atmosphère (ciel, vent, transitions)": game.atmosphere,
		"particules d'ambiance": game.atmosphere.get("particles"),
		"ambiance sonore": game.ambience,
		"extras (découvertes, renard, ema)": game.extras,
		"étang aux carpes": game.koi_pond,
		"récoltes": game.harvest,
		"guide": game.guide,
		"HUD": game.hud,
		"tâche des feuilles": game.tasks.get(&"balayer"),
	}
	for label in subs:
		var node: Node = subs[label]
		if node == null:
			continue
		var old := node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(0.3).timeout
		var m := await _cpu_measure()
		node.process_mode = old
		print("CPU sans %-38s %.2f ms (%+.2f)" % [label, m[0], m[0] - base[0]])
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var m2 := await _cpu_measure()
	p.process_mode = Node.PROCESS_MODE_INHERIT
	print("CPU sans %-38s %.2f ms (%+.2f)" % ["le joueur (déplacement, visée, main)", m2[0], m2[0] - base[0]])

func _cpu_measure() -> Array:
	var n := 0
	var acc := 0.0
	var phys := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < 2000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		acc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		last = now
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	return [acc / maxf(n, 1), phys / maxf(n, 1)]

# ================================================================ coût par famille d'objets
## Masque chaque famille d'objets tour à tour : ce qu'elle coûte en temps d'image et en appels de dessin.
## Teste aussi une correction : plus d'ombre pour les petits objets plats (dalles, mousse, feuilles...).
func _groups() -> void:
	var props: Node = game.props
	var forest: Node = game.world.get_node_or_null("Forest")
	var by_prefix := func(prefixes: Array) -> Array:
		var out := []
		for c in props.get_children():
			for pf in prefixes:
				if String(c.name).begins_with(pf):
					out.append(c)
					break
		return out
	var trees := []
	var small := []
	if forest:
		for c in forest.get_children():
			if c is MultiMeshInstance3D:
				if (c as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					trees.append(c)
				else:
					small.append(c)
	var groups := {
		"murs d'enceinte": by_prefix.call(["Wall"]),
		"dalles et chemins": by_prefix.call(["Slab", "Path", "Step"]),
		"bâtiments": by_prefix.call(["Haiden", "Shamusho", "TeaHouse", "Temizuya", "OfferingBox", "Hut"]),
		"lanternes de pierre": by_prefix.call(["Lantern_", "StairLantern", "TrailLantern", "ZenLantern", "ViewLantern"]),
		"arbres (forêt)": trees,
		"petit décor (fougères...)": small,
		"herbe": [forest.get_node_or_null("Grass")] if forest else [],
		"terrain": [game.world.get_node_or_null("Terrain")],
		"particules d'ambiance": [game.atmosphere.get("particles")],
		"tout le reste du décor": [],
	}
	var listed := {}
	for k in groups:
		for n in groups[k]:
			if n:
				listed[n] = true
	for c in props.get_children():
		if not listed.has(c):
			groups["tout le reste du décor"].append(c)
	# petits objets plats ou menus qui projettent une ombre
	var flat := []
	for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if bb.size.y < 0.35 or bb.size.length() < 1.0:
			flat.append(mi)
	print("DEEP petits objets plats ou menus qui projettent une ombre : %d" % flat.size())
	for v in [["allée", Vector3(0, 0.1, 4.0), 0.0, -4.0], ["lisière", Vector3(-14.0, 0.1, -20.0), 90.0, -2.0]]:
		_place(v[1], v[2], v[3])
		await get_tree().create_timer(1.2).timeout
		var base := await _measure(1.5)
		print("DEEP [%s] base %.1f ms, %d appels" % [v[0], base["frame"], base["calls"]])
		for k in groups:
			var nodes: Array = groups[k].filter(func(n): return n != null)
			if nodes.is_empty():
				continue
			for n in nodes:
				n.set("visible", false)
			await get_tree().create_timer(0.4).timeout
			var m := await _measure(1.2)
			for n in nodes:
				n.set("visible", true)
			print("DEEP [%s]   sans %-28s %+5.1f ms  %+5d appels  (%d nœuds)" % [v[0], k, m["frame"] - base["frame"], int(m["calls"] - base["calls"]), nodes.size()])
		for mi in flat:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await get_tree().create_timer(0.4).timeout
		var m2 := await _measure(1.2)
		for mi in flat:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		print("DEEP [%s]   CORRECTIF petits objets sans ombre  %+5.1f ms  %+5d appels" % [v[0], m2["frame"] - base["frame"], int(m2["calls"] - base["calls"])])
