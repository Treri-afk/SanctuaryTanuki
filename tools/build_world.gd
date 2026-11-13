extends SceneTree
## Génère scenes/world/shrine.tscn (monde). scenes/main.tscn (jeu) est écrit à la main : il dépend des autoloads.
## Usage : godot --headless --path . --script res://tools/build_world.gd
## Repère : le joueur arrive par le sud (+Z) et monte vers le nord (-Z). Les modèles regardent +Z.
## Plateau du sanctuaire à y = 0 (x de -26 à 26, z de -38 à 13) ; l'escalier descend vers +Z jusqu'à y = -5,58.
## Enceinte (murets) : x de -24,2 à 24,2, z de -35,2 à 9,2.

const M := "res://assets/models/"
var scn: Node3D
var props: Node3D

func _init() -> void:
	_build_shrine()
	quit(0)

func _own(n: Node, parent: Node) -> Node:
	parent.add_child(n)
	n.owner = scn
	return n

func place(model: String, node_name: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, tilt_x := 0.0, parent: Node = null) -> Node3D:
	var path := M + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("modèle absent : " + path)
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.name = node_name
	inst.position = pos
	inst.rotation_degrees = Vector3(tilt_x, yaw_deg, 0)
	inst.scale = Vector3.ONE * scale
	_own(inst, parent if parent else props)
	return inst

## Pose un modèle au sol aux coordonnées (x, z) : la hauteur est lue sur le terrain.
func placeg(model: String, node_name: String, x: float, z: float, yaw := 0.0, scale := 1.0, dy := 0.0) -> Node3D:
	return place(model, node_name, Vector3(x, Terrain.height(x, z) + dy, z), yaw, scale)

func _build_shrine() -> void:
	scn = Node3D.new()
	scn.name = "Shrine"
	_environment()
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_script(load("res://scripts/terrain.gd"))
	_own(terrain, scn)
	var forest := Node3D.new()
	forest.name = "Forest"
	forest.set_script(load("res://scripts/forest.gd"))
	_own(forest, scn)
	props = Node3D.new()
	props.name = "Props"
	_own(props, scn)
	_stairs()
	_precinct()
	_wilderness()
	_barriers()
	var atmo := Node3D.new()
	atmo.name = "Atmosphere"
	atmo.set_script(load("res://scripts/atmosphere.gd"))
	_own(atmo, scn)
	var packed := PackedScene.new()
	var err := packed.pack(scn)
	if err != OK:
		push_error("pack shrine failed %d" % err)
		return
	print("BUILD shrine.tscn ", ResourceSaver.save(packed, "res://scenes/world/shrine.tscn"))

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.93, 0.80, 0.66)
	sky_mat.ground_bottom_color = Color(0.32, 0.27, 0.24)
	sky_mat.ground_horizon_color = Color(0.93, 0.80, 0.66)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.68)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.82, 0.70)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.04
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own(we, scn)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-23, 48, 0)
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 0.6
	_own(sun, scn)

func _stairs() -> void:
	var stairs := Node3D.new()
	stairs.name = "Stairs"
	stairs.set_script(load("res://scripts/strip_collision.gd"))
	_own(stairs, scn)
	for i in 30:
		place("stone_step", "Step_%d" % i, Vector3(0, -0.18 * (i + 1) - 0.206, 13.25 + 0.5 * i), 0.0, 1.0, 0.0, stairs)
	place("torii", "ToriiBottom", Vector3(0, -5.58, 30.4))
	for sx in [-1.7, 1.7]:
		place("stone_lantern", "StairLantern_%s" % ("L" if sx < 0 else "R"), Vector3(sx * 1.0, -0.18 * 8 - 0.0 - 0.18, 17.5), 0.0)
	var body := StaticBody3D.new()
	body.name = "StairRamp"
	_own(body, scn)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 0.3, 17.2)
	cs.shape = bs
	cs.position = Vector3(0, -2.95, 20.5)
	cs.rotation_degrees = Vector3(19.8, 0, 0)
	_own(cs, body)

## Ligne de murets (modules de 2 m). axis "x" : de a à b à z fixe ; axis "z" : de a à b à x fixe. skip : intervalles sans mur.
func _wall_line(prefix: String, axis: String, fixed: float, a: float, b: float, skip: Array) -> void:
	var n := 0
	var t := a + 1.0
	while t < b:
		var blocked := false
		for s in skip:
			if t > s[0] and t < s[1]:
				blocked = true
		if not blocked:
			if axis == "x":
				place("low_wall", "%s_%d" % [prefix, n], Vector3(t, 0.0, fixed), 0.0)
			else:
				place("low_wall", "%s_%d" % [prefix, n], Vector3(fixed, 0.0, t), 90.0)
			n += 1
		t += 2.0

## Ligne de dalles (une colonne, espacées de 1,1 m) entre deux points au sol.
func _slab_line(prefix: String, a: Vector2, b: Vector2) -> void:
	var variants := ["path_slab_a", "path_slab_b", "path_slab_c"]
	var len := a.distance_to(b)
	var n := int(len / 1.1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		place(variants[i % 3], "%s_%d" % [prefix, i], Vector3(p.x, 0.0, p.y), 90.0 * ((i * 5) % 4) + 8.0 * i)

func _precinct() -> void:
	var y := 0.0
	# ---- entrée ----
	place("torii", "Torii", Vector3(0, y, 11.2))
	place("shimenawa", "Shimenawa", Vector3(0, 2.6, 11.6))
	# ---- enceinte ----
	_wall_line("WallFront", "x", 9.2, -24.2, 24.2, [[-3.0, 3.0]])
	_wall_line("WallW", "z", -24.2, -35.2, 9.2, [[1.0, 3.0]])        # porte ouest (sentier de la mare)
	_wall_line("WallE", "z", 24.2, -35.2, 9.2, [[-9.0, -7.0]])       # porte est (sentier de la cabane)
	_wall_line("WallBack", "x", -35.2, -24.2, 24.2, [[-1.0, 1.0]])   # porte nord (sentier du belvédère)
	place("torii_small", "ToriiBack", Vector3(0, y, -35.2))
	place("torii_small", "ToriiWest", Vector3(-24.2, y, 2.0), 90.0)
	place("torii_small", "ToriiEast", Vector3(24.2, y, -8.0), 90.0)
	# ---- allée centrale (sandō) ----
	var variants := ["path_slab_a", "path_slab_b", "path_slab_c"]
	var n := 0
	for row in 30:
		for col in 2:
			place(variants[n % 3], "Slab_%d" % n, Vector3(-0.5 + col, y, 12.4 - row), 90.0 * ((n * 7) % 4))
			n += 1
	# lanternes de pierre le long de l'allée : 8 à allumer le soir
	var lp := [Vector3(-3.0, y, 6.0), Vector3(3.0, y, 6.0), Vector3(-3.0, y, -1.0), Vector3(3.0, y, -1.0),
		Vector3(-3.0, y, -8.0), Vector3(3.0, y, -8.0), Vector3(-3.0, y, -14.0), Vector3(3.0, y, -14.0)]
	for i in 8:
		place("stone_lantern", "Lantern_%d" % i, lp[i])
	# ---- cour d'entrée : purification, puits, outils ----
	place("water_basin", "WaterBasin", Vector3(-8.5, y, 3.0), 90.0)
	place("well", "Well", Vector3(9.0, y, 2.0), -20.0)
	place("bucket", "Bucket", Vector3(7.6, y, 3.6), 20.0)
	place("basket", "Basket", Vector3(-6.0, y, 7.0))
	place("broom", "Broom", Vector3(7.0, y, 8.7), 0.0, 1.0, 10.0)
	place("stone_step", "MatchPedestal", Vector3(6.5, y, 5.8))
	place("match_box", "MatchBox", Vector3(6.5, 0.206, 5.8), 30.0)
	place("jizo", "Jizo", Vector3(-4.6, y, 8.0), 25.0)
	place("jizo", "JizoB", Vector3(-12.0, y, 8.2), 15.0)
	place("jizo", "JizoC", Vector3(-13.4, y, 8.4), -10.0)
	# ---- cour principale : tronc à offrandes et pavillon ----
	place("offering_box", "OfferingBox", Vector3(0, y, -17.0))
	place("haiden", "Haiden", Vector3(0, y, -23.0), 0.0, 1.5)
	place("ema_rack", "EmaRack", Vector3(10.5, y, -14.0), -80.0)
	place("stone_marker", "MarkerCourt", Vector3(-6.5, y, -16.5), 15.0)
	place("paper_lantern", "PaperLanternA", Vector3(-3.4, 3.2, -19.6), 0.0, 1.3)
	place("paper_lantern", "PaperLanternB", Vector3(3.4, 3.2, -19.6), 0.0, 1.3)
	# ---- salle de thé (est) ----
	var teahouse := place("hut", "TeaHouse", Vector3(17.5, y, -4.0), -90.0)
	if teahouse:
		place("tea_set", "TeaSet", Vector3(1.2, 0.42, 2.3), 0.0, 1.0, 0.0, teahouse)
	place("bench", "BenchTea", Vector3(12.8, y, -6.8), -90.0)
	place("woodpile", "WoodpileTea", Vector3(18.0, y, -9.0), -90.0)
	place("paper_lantern", "PaperLanternTea", Vector3(14.0, 2.4, -1.0))
	# ---- bureau du sanctuaire (ouest) ----
	place("hut", "Shamusho", Vector3(-19.0, y, -1.0), 90.0)
	place("bench", "BenchOffice", Vector3(-14.0, y, 1.8), 90.0)
	place("woodpile", "WoodpileOffice", Vector3(-19.5, y, 3.8), 90.0)
	# ---- chemins de dalles qui relient les bâtiments à l'allée ----
	_slab_line("PathBasin", Vector2(-1.8, 3.0), Vector2(-7.2, 3.0))
	_slab_line("PathWell", Vector2(1.8, 3.0), Vector2(7.2, 3.0))
	_slab_line("PathTea", Vector2(1.8, -4.0), Vector2(13.2, -4.0))
	_slab_line("PathOffice", Vector2(-1.8, -1.0), Vector2(-14.2, -1.0))
	_slab_line("PathZen", Vector2(-1.8, -10.0), Vector2(-9.0, -10.0))
	_slab_line("PathEma", Vector2(1.8, -14.0), Vector2(8.5, -14.0))
	_slab_line("PathPond1", Vector2(-1.8, -18.5), Vector2(-14.0, -18.5))
	_slab_line("PathPond2", Vector2(-12.6, -18.5), Vector2(-12.6, -21.0))
	_slab_line("PathTree", Vector2(1.8, -19.0), Vector2(12.5, -24.0))
	# ---- jardin sec (ouest) : rocs, râteau ----
	var zen := Vector3(-16.0, y, -11.0)
	place("rock_a", "ZenRockA", zen + Vector3(-2.2, 0, -1.0), 20.0)
	place("rock_b", "ZenRockB", zen + Vector3(1.8, 0, 1.6), 80.0)
	place("rock_c", "ZenRockC", zen + Vector3(-0.5, 0, 2.6), 130.0)
	place("rock_a", "ZenRockD", zen + Vector3(3.2, 0, -2.0), 200.0, 0.7)
	place("rake", "Rake", Vector3(-9.8, y, -8.2), 0.0, 1.0, 12.0)
	place("bench", "BenchZen", Vector3(-16.0, y, -17.2), 180.0)
	place("stone_lantern", "ZenLantern", Vector3(-21.5, y, -7.0))
	# ---- étang du fond (nord-ouest) ----
	place("stone_marker", "MarkerPond2", Vector3(-9.5, y, -29.0), 60.0)
	place("bench", "BenchPond", Vector3(-15.0, y, -20.4), 180.0)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		place("rock_a" if i % 2 == 0 else "rock_b", "PondRock_%d" % i, Vector3(-15.0 + cos(a) * 5.6, y, -27.0 + sin(a) * 5.6), i * 70.0, 0.9)
	place("stepping_stone", "PondStone_0", Vector3(-17.0, -0.45, -27.0), 10.0)
	place("stepping_stone", "PondStone_1", Vector3(-15.2, -0.45, -27.6), 50.0)
	place("stepping_stone", "PondStone_2", Vector3(-13.4, -0.45, -27.0), 90.0)
	# ---- arbre sacré et fond de cour (nord-est) ----
	place("maple_tree", "Shinboku", Vector3(15.0, y, -27.0), 30.0, 1.25)
	place("shimenawa", "ShimenawaTree", Vector3(15.0, 1.1, -26.0), 20.0, 0.55)
	place("hokora", "HokoraCourt", Vector3(21.0, y, -32.0), -30.0)
	place("fox_statue", "FoxCourtA", Vector3(19.7, y, -30.7), -30.0)
	place("fox_statue", "FoxCourtB", Vector3(22.0, y, -30.4), -30.0)
	place("jizo", "JizoBack", Vector3(7.0, y, -33.0), 190.0)
	# ---- végétation et rochers dans l'enceinte ----
	place("maple_red", "CourtMapleA", Vector3(-20.5, y, 4.5), 0.0, 1.1)
	place("maple_small", "CourtMapleB", Vector3(-19.0, y, -30.5), 60.0)
	place("maple_small", "CourtMapleC", Vector3(21.5, y, 6.0), 120.0)
	place("maple_red", "CourtMapleD", Vector3(20.0, y, -20.0), 200.0)
	place("maple_tree", "CourtMapleE", Vector3(-12.0, y, 5.5), 30.0, 0.85)
	place("cedar_tree_b", "CourtCedarA", Vector3(-22.5, y, -32.0), 10.0, 0.8)
	place("cedar_tree", "CourtCedarB", Vector3(23.0, y, -34.0), 70.0, 0.75)
	place("rock_c", "CourtRockA", Vector3(21.5, y, 0.5), 10.0)
	place("rock_b", "CourtRockB", Vector3(-22.0, y, -22.0), 100.0)
	place("rock_a", "CourtRockC", Vector3(4.5, y, -30.0), 30.0)
	var fp := [Vector3(-10.0, y, 8.3), Vector3(11.0, y, 8.0), Vector3(22.5, y, -14.0), Vector3(-22.8, y, 8.0),
		Vector3(-8.0, y, -33.0), Vector3(12.0, y, -33.5), Vector3(-23.0, y, -17.0), Vector3(23.0, y, -26.0)]
	for i in fp.size():
		place("fern_clump", "Fern_%d" % i, fp[i], i * 47.0)
	place("fallen_log", "CourtLog", Vector3(-5.0, y, -31.5), 80.0)
	# ---- feuilles à balayer : 12 tas répartis dans toute l'enceinte ----
	var leaves := _own(Node3D.new(), scn)
	leaves.name = "LeafPatches"
	var lpos := [Vector3(0.45, 0.115, 6.6), Vector3(-0.6, 0.115, 2.4), Vector3(0.55, 0.115, -1.8), Vector3(-0.3, 0.115, -6.0),
		Vector3(0.5, 0.115, -10.4), Vector3(-1.9, 0.01, 4.4), Vector3(2.0, 0.01, 0.8), Vector3(-4.0, 0.01, -4.5),
		Vector3(5.2, 0.01, -9.0), Vector3(-6.0, 0.01, -12.5), Vector3(7.8, 0.01, -20.0), Vector3(-8.0, 0.01, -22.5)]
	var lm := ["leaf_patch_a", "leaf_patch_b", "leaf_patch_c"]
	for i in lpos.size():
		place(lm[i % 3], "Leaf_%d" % i, lpos[i], 70.0 * i, 1.0, 0.0, leaves)

func _wilderness() -> void:
	# ---- sentier nord : torii, sanctuaire de bord de chemin, belvédère ----
	placeg("stone_lantern", "TrailLantern_N0", -2.4, -43.0)
	placeg("stone_lantern", "TrailLantern_N1", 2.4, -43.0)
	placeg("torii_small", "ToriiTrail", -7.0, -52.0, 32.0)
	placeg("stone_lantern", "TrailLantern_N2", -4.3, -58.5)
	placeg("hokora", "Hokora", -10.6, -65.0, 50.0)
	placeg("fox_statue", "FoxA", -9.2, -65.1, 50.0)
	placeg("fox_statue", "FoxB", -10.4, -63.7, 50.0)
	placeg("jizo", "JizoTrail", -3.8, -63.0, -60.0)
	placeg("stone_marker", "MarkerView", 11.0, -83.0, 20.0)
	placeg("bench", "BenchView", 14.0, -84.0, 0.0)
	placeg("stone_lantern", "ViewLanternL", 10.2, -86.5, 0.0)
	placeg("stone_lantern", "ViewLanternR", 17.8, -86.5, 0.0)
	placeg("rock_c", "ViewRock", 19.5, -82.0, 120.0)
	# ---- sentier est : cabane de l'ancien gardien ----
	placeg("stone_lantern", "TrailLantern_E0", 36.0, -6.5)
	placeg("jizo", "JizoEast", 42.0, -10.0, -30.0)
	placeg("stone_lantern", "TrailLantern_E1", 49.0, -10.4)
	placeg("hut", "Hut", 63.5, -16.0, -90.0)
	placeg("woodpile", "Woodpile", 62.5, -20.8, -90.0)
	placeg("bench", "BenchHut", 58.0, -13.0, -90.0)
	placeg("fallen_log", "LogHut", 57.0, -20.5, 70.0)
	# ---- sentier ouest : pont, ruisseau, mare ----
	placeg("stone_lantern", "TrailLantern_W0", -33.0, 5.8)
	place("wooden_bridge", "Bridge", Vector3(-44.0, Terrain.hill(-44.0, 4.5) - 0.25, 4.5), 0.0)
	placeg("stone_marker", "MarkerPond", -56.0, 6.0, 40.0)
	placeg("stepping_stone", "Stone_0", -59.5, 14.5, 10.0)
	placeg("stepping_stone", "Stone_1", -61.0, 15.8, 50.0)
	placeg("jizo", "JizoPond_0", -55.8, 11.0, 80.0)
	placeg("jizo", "JizoPond_1", -56.4, 13.0, 70.0)
	placeg("shrine_cat", "Cat", -58.0, 8.4, 40.0)
	for i in 5:
		placeg("bamboo_clump", "PondBamboo_%d" % i, -66.0 - i * 1.5, 4.0 + i * 3.2, i * 40.0)

func _box_body(n: String, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = n
	_own(body, scn)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	_own(cs, body)

func _barriers() -> void:
	# murs invisibles : grand anneau extérieur ; l'escalier et le palier du bas sont fermés sur les côtés
	_box_body("OuterW", Vector3(0.8, 60, 120), Vector3(-84.4, 0, -45.0))
	_box_body("OuterE", Vector3(0.8, 60, 120), Vector3(84.4, 0, -45.0))
	_box_body("OuterN", Vector3(170, 60, 0.8), Vector3(0, 0, -105.4))
	_box_body("BarrierSL", Vector3(82.6, 60, 0.6), Vector3(-42.75, 0, 13.3))
	_box_body("BarrierSR", Vector3(82.6, 60, 0.6), Vector3(42.75, 0, 13.3))
	_box_body("StairSideL", Vector3(0.6, 14, 15.5), Vector3(-1.75, -3, 20.8))
	_box_body("StairSideR", Vector3(0.6, 14, 15.5), Vector3(1.75, -3, 20.8))
	_box_body("LandingL", Vector3(0.6, 14, 11.5), Vector3(-9.3, -6, 33.8))
	_box_body("LandingR", Vector3(0.6, 14, 11.5), Vector3(9.3, -6, 33.8))
	_box_body("LandingEnd", Vector3(19, 14, 0.6), Vector3(0, -6, 39.5))
