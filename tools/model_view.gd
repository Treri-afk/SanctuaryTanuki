extends SceneTree
## Rend un modèle seul avec le VRAI rendu du jeu (shader toon + contours), pour juger un .glb sans lancer le jeu.
## Passer par tools/model_shot.sh. Arguments utilisateur : nom [yaw_deg] [pitch_deg] [zoom] [suffixe]
## Le devant d'un modèle (-Y Blender) est +Z dans Godot : yaw 0 = vue de face, yaw positif = caméra vers la droite.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var model := String(a[0])
	var yaw := deg_to_rad(float(a[1]) if a.size() > 1 else 35.0)
	var pitch := deg_to_rad(float(a[2]) if a.size() > 2 else 18.0)
	var zoom := float(a[3]) if a.size() > 3 else 1.0
	var suffix := String(a[4]) if a.size() > 4 else ""
	var path := "res://assets/models/%s.glb" % model
	if not ResourceLoader.exists(path):
		print("MODEL_SHOT ERREUR : modèle non importé : ", path, " (lancer tools/import.sh)")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.93, 0.80, 0.66)
	sky_mat.ground_bottom_color = Color(0.55, 0.50, 0.45)
	sky_mat.ground_horizon_color = Color(0.93, 0.80, 0.66)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.68)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 48, 0)
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	world.add_child(sun)

	var inst: Node3D = (load(path) as PackedScene).instantiate()
	world.add_child(inst)
	Toon.apply(inst, model)

	var box := AABB()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var center := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.05)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * maxf(radius * 14.0, 6.0)
	ground.mesh = pm
	ground.position = Vector3(center.x, minf(box.position.y, 0.0) - 0.002, center.z)
	ground.material_override = Toon.make_material(Color("#A8996F"), 0.0)
	world.add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.01
	cam.far = 500.0
	world.add_child(cam)
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.12 / zoom
	var cam_pos := center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.transform = Transform3D(Basis.looking_at(center - cam_pos), cam_pos)
	cam.current = true

	for i in 12:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/previews/toon"))
	var out := "res://assets/previews/toon/%s%s.png" % [model, suffix]
	root.get_texture().get_image().save_png(out)
	print("MODEL_SHOT ", out, " taille=", box.size)
	quit()
