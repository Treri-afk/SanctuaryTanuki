extends Node
## Audit de fluidité : godot --path . -- --perf
## Place la caméra sur quelques points de vue, mesure le temps d'image (GPU, CPU) puis coupe les postes
## coûteux un par un pour voir lequel pèse. V-sync coupée pendant la mesure. Sortie : lignes « PERF ».

var game: Node3D
var vp: Viewport

func run(g: Node3D) -> void:
	game = g
	vp = get_viewport()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	await get_tree().create_timer(3.0).timeout
	var atmo: Node = game.atmosphere
	var env: Environment = atmo.env
	var sun: DirectionalLight3D = atmo.sun
	var forest: Node = game.world.get_node_or_null("Forest")
	var trees: Array = []
	var grass: Node = forest.get_node_or_null("Grass") if forest else null
	if forest:
		for c in forest.get_children():
			if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).visibility_range_end == 0.0 and c.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				trees.append(c)
	var shafts: Node = atmo.get_node_or_null("SunShafts")
	print("PERF fenêtre=%s  échelle écran=%.1f  rendu 3D=%s  arbres (blocs)=%d" % [
		str(DisplayServer.window_get_size()), DisplayServer.screen_get_scale(), str(vp.get_visible_rect().size), trees.size()])
	var tri_trees := 0
	for t in trees:
		var mm: MultiMesh = (t as MultiMeshInstance3D).multimesh
		var tris := 0
		for s in mm.mesh.get_surface_count():
			tris += (mm.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		tri_trees += tris * mm.instance_count
	print("PERF triangles d'arbres sur la carte (tous dessinés à chaque image) = %d" % tri_trees)
	var tests := [
		["MSAA 4x coupé", func(): vp.msaa_3d = Viewport.MSAA_DISABLED, func(): vp.msaa_3d = Viewport.MSAA_4X],
		["SSAO coupé", func(): env.ssao_enabled = false, func(): env.ssao_enabled = true],
		["brouillard volumétrique coupé", func(): env.volumetric_fog_enabled = false, func(): env.volumetric_fog_enabled = true],
		["glow coupé", func(): env.glow_enabled = false, func(): env.glow_enabled = true],
		["ombres du soleil coupées", func(): sun.shadow_enabled = false, func(): sun.shadow_enabled = true],
		["contours (écran) coupés", func(): atmo.outline_quad.visible = false, func(): atmo.outline_quad.visible = true],
		["rayons de soleil coupés", func(): if shafts: shafts.visible = false, func(): if shafts: shafts.visible = true],
		["particules d'ambiance cachées", func(): atmo.particles.visible = false, func(): atmo.particles.visible = true],
		["arbres cachés", func(): for t in trees: t.visible = false, func(): for t in trees: t.visible = true],
		["herbe cachée", func(): if grass: grass.visible = false, func(): if grass: grass.visible = true],
		["rendu 3D à 50 %", func(): vp.scaling_3d_scale = 0.5, func(): vp.scaling_3d_scale = 1.0],
	]
	if OS.get_cmdline_user_args().has("--batiments"):
		var bats: Array = []
		for n in ["Shamusho", "TeaHouse", "Temizuya", "Haiden"]:
			var b: Node = game.props.get_node_or_null(n)
			if b:
				bats.append(b)
		tests = [
			["bureau caché", func(): bats[0].visible = false, func(): bats[0].visible = true],
			["salon de thé caché", func(): bats[1].visible = false, func(): bats[1].visible = true],
			["pavillon des ablutions caché", func(): bats[2].visible = false, func(): bats[2].visible = true],
			["haiden caché (référence)", func(): bats[3].visible = false, func(): bats[3].visible = true],
		]
	if OS.get_cmdline_user_args().has("--pixels"):
		tests = [
			["rendu 3D 85 % (FSR)", func():
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
				vp.scaling_3d_scale = 0.85, func(): vp.scaling_3d_scale = 1.0],
			["rendu 3D 75 % (FSR)", func():
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
				vp.scaling_3d_scale = 0.75, func(): vp.scaling_3d_scale = 1.0],
			["FXAA au lieu du MSAA 2x", func():
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA, func():
				vp.msaa_3d = Viewport.MSAA_2X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED],
		]
	if OS.get_cmdline_user_args().has("--fixes"):
		var Q := RenderingServer
		tests = [
			["ombres : filtre doux bas", func(): Q.directional_soft_shadow_filter_set_quality(Q.SHADOW_QUALITY_SOFT_LOW),
				func(): Q.directional_soft_shadow_filter_set_quality(Q.SHADOW_QUALITY_SOFT_HIGH)],
			["ombres : filtre dur", func(): Q.directional_soft_shadow_filter_set_quality(Q.SHADOW_QUALITY_HARD),
				func(): Q.directional_soft_shadow_filter_set_quality(Q.SHADOW_QUALITY_SOFT_HIGH)],
			["ombres : 2 cascades", func(): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
				func(): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS],
			["ombres : atlas 2048", func(): Q.directional_shadow_atlas_set_size(2048, true),
				func(): Q.directional_shadow_atlas_set_size(4096, true)],
			["ombres : distance 60 m", func(): sun.directional_shadow_max_distance = 60.0,
				func(): sun.directional_shadow_max_distance = 95.0],
			["brouillard vol. : volume 64x48", func(): Q.environment_set_volumetric_fog_volume_size(64, 48),
				func(): Q.environment_set_volumetric_fog_volume_size(128, 96)],
			["MSAA 2x", func(): vp.msaa_3d = Viewport.MSAA_2X, func(): vp.msaa_3d = Viewport.MSAA_4X],
		]
	var views := [
		["escalier", Vector3(0, -5.5, 33.0), 0.0, 6.0],
		["allée", Vector3(0, 0.1, 4.0), 0.0, -4.0],
		["lisière", Vector3(-14.0, 0.1, -20.0), 90.0, -2.0],
	]
	if OS.get_cmdline_user_args().has("--quick"):
		tests = []
	for v in views:
		_place(v[1], v[2], v[3])
		await get_tree().create_timer(1.5).timeout
		var base := await _measure()
		print("PERF [%s] base : %.1f ms/image (%.0f img/s)  scripts %.1f ms  physique %.1f ms  CPU rendu %.1f ms  appels=%d  triangles=%dk" % [
			v[0], base["frame"], 1000.0 / base["frame"], base["proc"], base["phys"], base["cpu"], base["calls"], base["prims"] / 1000])
		for t in tests:
			(t[1] as Callable).call()
			await get_tree().create_timer(0.6).timeout
			var m := await _measure()
			(t[2] as Callable).call()
			print("PERF [%s]   %-32s GPU %5.1f ms (%+.1f)   image %5.1f ms (%+.1f)" % [
				v[0], t[0], m["gpu"], m["gpu"] - base["gpu"], m["frame"], m["frame"] - base["frame"]])
		await get_tree().create_timer(0.4).timeout
	print("PERF fin")
	get_tree().quit()

func _place(pos: Vector3, yaw: float, pitch: float) -> void:
	var p: CharacterBody3D = game.player
	p.input_enabled = false
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation_degrees.y = yaw
	p.head.rotation_degrees.x = pitch

## Moyenne sur ~1,5 s : temps d'image, temps GPU et CPU de rendu, appels de dessin, triangles.
func _measure() -> Dictionary:
	var n := 0
	var acc := {"frame": 0.0, "gpu": 0.0, "cpu": 0.0, "calls": 0.0, "prims": 0.0, "proc": 0.0, "phys": 0.0}
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < 1500000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		acc["frame"] += (now - last) / 1000.0
		last = now
		acc["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		acc["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
		acc["calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		acc["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		acc["prims"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	for k in acc:
		acc[k] /= maxf(n, 1)
	return acc
