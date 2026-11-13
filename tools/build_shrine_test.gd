extends SceneTree
## Génère scenes/world/shrine_test.tscn (éditable ensuite dans l'éditeur).
## Usage : godot --headless --path . --script res://tools/build_shrine_test.gd
## Repère : le joueur arrive par le sud (+Z) et monte vers le nord (-Z). Les modèles regardent +Z.

const M := "res://assets/models/"
const PLATEAU_Y := 0.54
var scn: Node3D

func _init() -> void:
	scn = Node3D.new()
	scn.name = "ShrineTest"
	scn.set_script(load("res://scenes/world/shrine_test.gd"))
	_environment()
	_ground()
	_models()
	_visitors()
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 0.05, 17)
	_add(player)
	var packed := PackedScene.new()
	var err := packed.pack(scn)
	if err != OK:
		push_error("pack failed %d" % err); quit(1); return
	err = ResourceSaver.save(packed, "res://scenes/world/shrine_test.tscn")
	print("BUILD saved shrine_test.tscn err=", err)
	quit(0)

func _add(n: Node, parent: Node = null) -> Node:
	(parent if parent else scn).add_child(n)
	n.owner = scn
	return n

func _own_recursive(n: Node) -> void:
	for c in n.get_children():
		c.owner = scn
		_own_recursive(c)

## Place un modèle .glb ; les sous-noeuds ne sont pas "owned" (le glb reste une instance).
func place(model: String, pos: Vector3, yaw_deg := 0.0, scale := Vector3.ONE, tilt_deg := Vector3.ZERO, parent: Node = null) -> Node3D:
	var path := M + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("modèle absent : " + path)
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.name = model
	inst.position = pos
	inst.rotation_degrees = Vector3(tilt_deg.x, yaw_deg, tilt_deg.z)
	inst.scale = scale
	_add(inst, parent)
	return inst

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.93, 0.80, 0.66)
	sky_mat.ground_bottom_color = Color(0.32, 0.27, 0.24)
	sky_mat.ground_horizon_color = Color(0.82, 0.72, 0.60)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.50, 0.66)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.82, 0.70)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-33, 52, 0)   # soleil bas et chaud venant de la gauche, derrière le joueur : éclaire les façades (+Z) et les côtés (+X)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 0.6
	_add(sun)

func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	_add(body)
	var layout := [
		# [nom, taille, centre, couleur]
		["field", Vector3(400, 1, 400), Vector3(0, -0.5, 0), Color("#7C9644").darkened(0.1)],
		["plateau", Vector3(22, 2.0, 24), Vector3(0, PLATEAU_Y - 1.0, -1.5), Color("#A8A68C")],
	]
	for l in layout:
		_box(body, l[0], l[1], l[2], l[3])
	# escalier : 3 noyaux de pierre + marches posées dessus
	for i in 3:
		var h := 0.18 * (i + 1)
		_box(body, "stair_core_%d" % i, Vector3(2.0, h, 0.5), Vector3(0, h / 2.0, 11.75 + (2 - i) * 0.5 + 0.0), Color("#6F6B63"))

	# rampe invisible sur l'escalier : le joueur n'a pas de montée de marche automatique
	var ramp := CollisionShape3D.new()
	ramp.name = "stair_ramp"
	var rs := BoxShape3D.new()
	rs.size = Vector3(2.0, 0.1, 1.65)
	ramp.shape = rs
	ramp.position = Vector3(0, 0.33, 12.25)
	ramp.rotation_degrees = Vector3(19.8, 0, 0)
	_add(ramp, body)

func _box(parent: Node, n: String, size: Vector3, center: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = center
	mi.material_override = Toon.make_material(color, 0.0)
	_add(mi, parent)
	var cs := CollisionShape3D.new()
	cs.name = n + "_shape"
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	_add(cs, parent)

func _models() -> void:
	var y := PLATEAU_Y
	# escalier (3 marches, la plus basse au sud)
	for i in 3:
		place("stone_step", Vector3(0, 0.18 * i, 11.75 + (2 - i) * 0.5), 0.0)
	place("torii", Vector3(0, y, 8.5))
	# allée de dalles : 2 colonnes
	var variants := ["path_slab_a", "path_slab_b", "path_slab_c"]
	var k := 0
	for row in 14:
		for col in 2:
			place(variants[k % 3], Vector3(-0.5 + col, y, 6.5 - row), 90.0 * ((k * 7) % 4))
			k += 1
	# lanternes de part et d'autre de l'allée
	place("stone_lantern", Vector3(-2.4, y, 3.5))
	place("stone_lantern", Vector3(2.4, y, 3.5))
	place("stone_lantern", Vector3(-2.4, y, -3.0))
	place("water_basin", Vector3(-5.2, y, 3.0), 70.0)
	place("well", Vector3(5.2, y, 1.5))
	place("bucket", Vector3(5.0, y, 3.0), 20.0)
	place("ema_rack", Vector3(5.2, y, -3.5), -65.0)
	place("maple_tree", Vector3(-7.0, y, -2.5), 30.0)
	place("offering_box", Vector3(0, y, -6.6))
	place("haiden", Vector3(0, y, -10.8))
	place("broom", Vector3(1.9, y, 8.0), 0.0, Vector3.ONE, Vector3(-8, 0, 0))
	# murets : fond et côtés
	for i in 11:
		place("low_wall", Vector3(-10.0 + i * 2.0, y, -12.4))
	for i in 11:
		place("low_wall", Vector3(-10.4, y, 10.0 - i * 2.0), 90.0)
		place("low_wall", Vector3(10.4, y, 10.0 - i * 2.0), 90.0)
	for i in 4:
		place("low_wall", Vector3(-9.0 + i * 2.0, y, 11.2))
		place("low_wall", Vector3(3.0 + i * 2.0, y, 11.2))

func _visitors() -> void:
	var defs := [
		["La vieille dame", Color(0.72, 0.52, 0.6), Vector3(-1.5, PLATEAU_Y, 1.0)],
		["L'étudiant", Color(0.4, 0.55, 0.75), Vector3(2.0, PLATEAU_Y, -4.6)],
		["La vieille dame (retour)", Color(0.72, 0.52, 0.6), Vector3(-3.2, PLATEAU_Y, -7.0)],
	]
	for d in defs:
		var v: Node3D = load("res://scenes/visitors/visitor_placeholder.tscn").instantiate()
		v.name = String(d[0]).replace(" ", "_").replace("'", "").replace("(", "").replace(")", "")
		v.set("display_name", d[0])
		v.set("color", d[1])
		v.position = d[2]
		_add(v)
