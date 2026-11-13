extends Node3D
## Contrôleur du prototype : interactions, tâches, phases de la journée, visiteurs, lumière.
## Journée : MATIN (2 tâches tirées au hasard dans TASKS) -> APRÈS-MIDI -> SOIR (lanternes, cloche).
## Les visiteurs du jour (2 ou 3, tirés de data/story/story.json) montent à des moments aléatoires, pendant le travail.
## Le soir tombe quand les tâches du matin sont faites et que tous les visiteurs du jour sont repartis.

enum Phase { MORNING, VISIT, EVENING, NIGHT }   # identique à GameState.Phase
const TERRAIN := preload("res://scripts/terrain.gd")

## Tâches obligatoires du matin : deux sont tirées chaque jour. Pour en ajouter une, voir scripts/tasks/morning_task.gd.
const TASKS := {
	&"balayer": preload("res://scripts/tasks/task_leaves.gd"),
	&"fontaine": preload("res://scripts/tasks/task_water.gd"),
	&"priere": preload("res://scripts/tasks/task_prayer.gd"),
	&"reparer": preload("res://scripts/tasks/task_repair.gd"),
	&"haies": preload("res://scripts/tasks/task_hedges.gd"),
	&"bambou": preload("res://scripts/tasks/task_bamboo.gd"),
}
const MORNING_COUNT := 2

@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var vn: CanvasLayer = $VN

var props: Node3D
var atmosphere: Atmosphere
var tool_nodes: Dictionary = {}
var tool_areas: Dictionary = {}
var tasks: Dictionary = {}          # id -> MorningTask
var _yesterday: Array[StringName] = []
var _forced: Array[StringName] = []   # --tasks=a,b sur la ligne de commande (tests)
var lanterns: Array = []
var lantern_areas: Array = []
var flames: Array = []
var lit: Dictionary = {}
var rope: Node3D
var bell: Node3D
var visitor: Node3D
var visit_queue: Array = []        # visites qui doivent encore arriver aujourd'hui
var visit_timer := 0.0             # secondes avant la prochaine arrivée (le compte ne court que sans visiteur présent)
var visit_current: Dictionary = {}
var _visitor_ready_flag := false
var _patience := 0.0               # secondes avant qu'un visiteur qu'on ignore ne reparte
var _patience_warned := false
var _evening_pending := false
var _rng := RandomNumberGenerator.new()
var _ending := false
var _visit_pending := false
var _t := 0.0
var _bell_sound: AudioStreamPlayer
var extras: Extras
var harvest: Node
var koi_pond: Node
var zen_marks: Array = []
var zen_last := Vector3.INF
var zen_mat: ShaderMaterial

func _ready() -> void:
	add_to_group("game")
	randomize()
	props = world.get_node("Props")
	atmosphere = world.get_node("Atmosphere")
	hud.player = player
	_setup_workshop()
	_setup_tools()
	_setup_tasks()
	_setup_lanterns()
	_setup_bell()
	_setup_zen()
	extras = Extras.new()
	extras.name = "Extras"
	add_child(extras)
	extras.setup(self)
	harvest = preload("res://scripts/harvest.gd").new()
	harvest.name = "Harvest"
	add_child(harvest)
	harvest.setup(self)
	koi_pond = preload("res://scripts/koi_pond.gd").new()
	koi_pond.name = "KoiPond"
	add_child(koi_pond)
	koi_pond.setup(self)
	Events.task_done.connect(_on_task_done)
	_bell_sound = AudioStreamPlayer.new()
	_bell_sound.stream = _make_bell_sound()
	_bell_sound.volume_db = -4.0
	add_child(_bell_sound)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--tasks="):
			for t in a.trim_prefix("--tasks=").split(","):
				if TASKS.has(StringName(t)):
					_forced.append(StringName(t))
	await get_tree().process_frame
	_start_day(1)
	if args.size() >= 7 and args[0] == "--shot":
		_debug_shot(args)
	elif args.size() >= 1 and args[0] == "--autoplay":
		_autoplay()
	elif args.size() >= 1 and args[0] == "--feeltest":
		var ft: Node = load("res://scripts/feel_test.gd").new()
		add_child(ft)
		ft.run(self)

## Test automatique d'une journée complète (appelle les mêmes callbacks que les interactions du joueur).
## godot --path . -- --autoplay
func _autoplay() -> void:
	Engine.time_scale = 5.0
	print("AUTOPLAY ===== jour %d" % GameState.day)
	var log := func(m: String): print("AUTOPLAY ", m)
	await get_tree().create_timer(4.0).timeout
	log.call("tâches du matin : %s" % str(GameState.morning))
	harvest.autoplay(3)
	koi_pond.autoplay()
	log.call("carpes : %d, nourries = %s" % [GameState.koi.size(), GameState.is_done(&"carpes")])
	log.call("inventaire : %s" % str(GameState.inventory))
	for id in GameState.morning:
		await (tasks[id] as MorningTask).autoplay()
		log.call("%s = %s (%d/%d)" % [id, GameState.is_done(id), GameState.progress.get(id, 0), GameState.target.get(id, 1)])
	log.call("matin terminé = %s, phase = %d" % [GameState.morning_done(), GameState.phase])
	for n in extras.ema_nodes.duplicate():
		for c in n.get_children():
			if c is Interactable:
				(c as Interactable).use_fn.call(player)
	var rack: Node3D = props.get_node("EmaRack")
	for i in 3:
		for c in rack.get_children():
			if c is Interactable and (c as Interactable).prompt() != "":
				(c as Interactable).use_fn.call(player)
	log.call("ema = %s (tenus %d)" % [GameState.is_done(&"ema"), extras.ema_held])
	extras._read_letter()
	await get_tree().create_timer(2.0).timeout
	log.call("lettres lues = %d" % extras.letters_read)
	player.input_enabled = true
	var guard := 0
	var talked := 0
	var vnl := vn
	while GameState.phase != Phase.EVENING:
		guard += 1
		if guard > 3000:
			log.call("ÉCHEC : le soir n'arrive jamais (file=%d, visiteur=%s)" % [visit_queue.size(), str(visitor)])
			get_tree().quit(1)
			return
		if vnl.visible:
			vnl._advance = true
			for b in vnl._choices.get_children():
				if b is Button:
					(b as Button).pressed.emit()
					break
		elif visitor != null and _visitor_ready_flag:
			log.call("visiteur prêt : %s (%s)" % [Story.display_name(String(visit_current.get("character", ""))), visit_current.get("id", "")])
			talked += 1
			for c in visitor.get_children():
				if c is Interactable:
					(c as Interactable).use_fn.call(player)
		await get_tree().create_timer(0.2).timeout
	log.call("visites jouées aujourd'hui : %d, affection = %s, pièces = %d (reçues %d)" % [talked, str(GameState.affection), GameState.coins, GameState.day_log.get("coins_in", 0)])
	log.call("soir, flags = %s" % str(GameState.flags))
	await get_tree().create_timer(2.0).timeout
	_equip(&"match") if tool_nodes.has(&"match") else null
	for l in lantern_areas:
		(l as Interactable).use_fn.call(player)
	log.call("lanternes = %s" % GameState.is_done(&"lanternes"))
	var box: Node3D = props.get_node("OfferingBox")
	for c in box.get_children():
		if c is Interactable:
			log.call("cloche prompt = %s" % (c as Interactable).prompt())
			(c as Interactable).use_fn.call(player)
	var d0 := GameState.day
	while GameState.day == d0:
		if vn.visible:
			vn._advance = true
			for b in vn._choices.get_children():
				if b is Button:
					(b as Button).pressed.emit()
					break
		await get_tree().create_timer(0.2).timeout
	log.call("jour %d commencé" % GameState.day)
	var want := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			want = int(a.trim_prefix("--days="))
	if d0 < want and GameState.day > d0:
		_autoplay()
		return
	get_tree().quit()

## Capture d'écran automatique : godot --path . -- --shot x y z yaw pitch fichier.png [phase] [attente]
func _debug_shot(a: PackedStringArray) -> void:
	if a.size() > 7:
		var ph := int(a[7])
		GameState.set_phase(ph)
		_apply_lighting(ph, true)
	await get_tree().create_timer(float(a[8]) if a.size() > 8 else 3.5).timeout
	if a.size() > 7 and int(a[7]) == 2:
		for i in lanterns.size():
			_light(i)
	if a.size() > 9 and a[9] == "vn":
		var vs := Story.visits_for_day(GameState.day, _rng)
		if not vs.is_empty():
			vn.play_visit(vs[0])
		await get_tree().create_timer(3.0).timeout
	elif a.size() > 9 and a[9] == "journal":
		# capture du journal avec une journée remplie à la main
		GameState.add_coins(6)
		GameState.spend_coins(1)
		GameState.add_affection("vieille_dame", 2)
		GameState.add_affection("moine", 1)
		(GameState.day_log["visitors"] as Array).append_array(["vieille_dame", "moine", "facteur"])
		(GameState.day_log["tasks"] as Array).append_array([&"haies", &"bambou", &"lanternes", &"the"])
		GameState.note("Découvert : le belvédère.")
		GameState.note("J'ai lu une lettre de Seiji, l'ancien gardien.")
		hud.show_journal(_journal_page())
		await get_tree().create_timer(3.0).timeout
	elif a.size() > 9 and a[9] == "ema":
		# capture du mur des ema avec des liens dans tous les états
		for who in ["vieille_dame", "etudiant", "moine", "facteur"]:
			GameState.met[who] = true
		GameState.add_affection("vieille_dame", 6)
		GameState.add_affection("etudiant", 2)
		GameState.add_affection("facteur", -4)
		GameState.missed["moine"] = 1
		GameState.met["fillette"] = true
		GameState.missed["fillette"] = 3
		GameState.ema_log.append({"character": "vieille_dame", "wish": "Que la montagne se souvienne de moi.", "day": 1})
		GameState.ema_log.append({"character": "etudiant", "wish": "Que mes examens se passent bien.", "day": 2})
		GameState.ema_log.append({"character": "vieille_dame", "wish": "Merci d'avoir veillé sur ce lieu.", "day": 3})
		for who in ["vieille_dame", "etudiant", "vieille_dame"]:
			extras.hang_visitor_ema(who)
		extras._read_board()
		await get_tree().create_timer(1.2).timeout
	elif a.size() > 9 and (a[9] == "renard" or a[9] == "tanuki" or a[9] == "chat"):
		# capture d'une créature de la nuit, posée devant le joueur
		GameState.set_phase(Phase.NIGHT)
		_apply_lighting(Phase.NIGHT, true)
		for i in lanterns.size():
			_light(i)
		var cr: Node3D = ToolModels.creature(a[9])
		if cr == null:
			cr = _model("shrine_cat", Color.WHITE)
			cr.scale = Vector3.ONE * 1.4
		else:
			Toon.apply(cr)
		var px := float(a[1])
		var pz := float(a[3])
		var yaw := deg_to_rad(float(a[4]))
		var p2 := Vector3(px - sin(yaw) * 1.6, 0.0, pz - cos(yaw) * 1.6)
		cr.position = Vector3(p2.x, TERRAIN.walk_y(p2.x, p2.z), p2.z)
		cr.rotation.y = yaw
		world.add_child(cr)
		await get_tree().create_timer(0.5).timeout
	elif a.size() > 9 and a[9] == "recolte":
		# capture : on se place devant un objet à ramasser, poches déjà un peu remplies
		GameState.add_item("kaki", 2)
		GameState.add_item("plume", 1)
		var h: Node3D = harvest.nodes[0]
		var hp := h.global_position
		player.global_position = hp + Vector3(0, 0, 1.3)
		player.rotation_degrees.y = 0.0
		player.head.rotation_degrees.x = -42.0
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(a[6])
		print("SHOT ", a[6], " objet=", h.get_child(0).name)
		get_tree().quit()
		return
	elif a.size() > 9 and a[9] == "cadeau":
		GameState.add_item("kaki", 2)
		GameState.add_item("chataigne", 1)
		GameState.gift_known["fillette"] = {"kaki": "love"}
		vn.choose_gift("fillette", [{"id": "kaki", "name": "Kaki", "count": 2, "hint": "adore"},
			{"id": "chataigne", "name": "Châtaigne", "count": 1, "hint": ""}])
		await get_tree().create_timer(2.5).timeout
	elif a.size() > 9 and a[9] == "carpes":
		# capture : depuis la rive de l'étang, on vient de lancer des granulés
		player.global_position = Vector3(-15.0, 0.05, -22.4)
		player.rotation_degrees.y = 0.0
		player.head.rotation_degrees.x = -38.0
		await get_tree().create_timer(0.3).timeout
		koi_pond._throw(Vector3(-15.0, -0.3, -25.6))
		await get_tree().create_timer(float(a[10]) if a.size() > 10 else 2.5).timeout
		get_viewport().get_texture().get_image().save_png(a[6])
		print("SHOT ", a[6], " carpes=", GameState.koi.size(), " mangés=", koi_pond.eaten_today)
		get_tree().quit()
		return
	elif a.size() > 9 and a[9] == "coins":
		GameState.add_coins(3)
		await get_tree().create_timer(0.7).timeout
	elif a.size() > 9 and a[9] != "":
		_equip(StringName(a[9]))
	var py := TERRAIN.walk_y(float(a[1]), float(a[3])) + 0.05 if a[2] == "auto" else float(a[2])
	player.global_position = Vector3(float(a[1]), py, float(a[3]))
	player.rotation_degrees.y = float(a[4])
	player.head.rotation_degrees.x = float(a[5])
	player.input_enabled = false
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(a[6])
	print("SHOT ", a[6], " fps=", Engine.get_frames_per_second(), " pos=", player.global_position, " ground=", TERRAIN.height(player.global_position.x, player.global_position.z), " floor=", player.is_on_floor())
	get_tree().quit()

func _physics_process(delta: float) -> void:
	hud.ring_phase = -1.0
	for id in tasks:
		var t: MorningTask = tasks[id]
		if t.active:
			t.physics(delta)

func _process(delta: float) -> void:
	_t += delta
	_tick_visits(delta)
	_tick_patience(delta)
	for i in flames.size():
		var l: OmniLight3D = flames[i]
		if is_instance_valid(l):
			l.light_energy = 0.95 * (0.88 + 0.12 * sin(_t * 9.0 + i * 1.7) + 0.05 * sin(_t * 23.0 + i))

# ---------------------------------------------------------------- utilitaires
func _make(node: Node3D, size: Vector3, offset: Vector3, prompt_fn: Callable, use_fn: Callable = Callable(), hold_fn: Callable = Callable()) -> Interactable:
	var a := Interactable.create(node, size, offset)
	a.prompt_fn = prompt_fn
	a.use_fn = use_fn
	a.hold_fn = hold_fn
	return a

func _area_on(a: Interactable, on: bool) -> void:
	a.collision_layer = 2 if on else 0

func _model(name: String, color := Color(0.8, 0.5, 0.2)) -> Node3D:
	var path := "res://assets/models/%s.glb" % name
	if ResourceLoader.exists(path):
		var n: Node3D = (load(path) as PackedScene).instantiate()
		Toon.apply(n)
		return n
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.5
	mi.mesh = sm
	mi.material_override = Toon.make_material(color)
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder

# ---------------------------------------------------------------- outils
func _setup_tools() -> void:
	var defs := {
		&"broom": ["Broom", Vector3(0.8, 1.5, 0.8), Vector3(0, 0.7, 0), "Prendre le balai"],
		&"bucket": ["Bucket", Vector3(0.6, 0.5, 0.6), Vector3(0, 0.2, 0), "Prendre le seau"],
		&"match": ["MatchBox", Vector3(0.35, 0.3, 0.35), Vector3(0, 0.08, 0), "Prendre les allumettes"],
		&"rake": ["Rake", Vector3(0.8, 1.5, 0.8), Vector3(0, 0.7, 0), "Prendre le râteau"],
		&"hammer": ["Hammer", Vector3(0.45, 0.25, 0.45), Vector3(0, 0.05, 0), "Prendre le marteau"],
		&"shears": ["Shears", Vector3(0.45, 0.25, 0.7), Vector3(0, 0.05, 0), "Prendre la cisaille"],
		&"sickle": ["Sickle", Vector3(0.45, 0.25, 0.45), Vector3(0, 0.05, 0), "Prendre la serpe"],
	}
	for k in defs:
		var d: Array = defs[k]
		if not props.has_node(d[0]):
			push_warning("outil absent : " + String(d[0]))
			continue
		var node: Node3D = props.get_node(d[0])
		tool_nodes[k] = node
		var label: String = d[3]
		var key: StringName = k
		var a := _make(node, d[1], d[2],
			func() -> String: return "" if player.tool == key else "E : " + label,
			func(_p): _equip(key))
		tool_areas[k] = a

## Établi près du bureau du sanctuaire (outils des tâches) et paniers supplémentaires pour les feuilles.
func _setup_workshop() -> void:
	var table := ToolModels.tool_table()
	table.position = Vector3(-13.4, 0.0, -3.4)
	props.add_child(table)
	var lay := {"Hammer": [Vector3(-0.45, 0.76, 0.05), Vector3(0, 30, 90)], "Shears": [Vector3(0.05, 0.76, 0.0), Vector3(90, 0, 80)],
		"Sickle": [Vector3(0.48, 0.76, -0.05), Vector3(0, -20, 90)]}
	var models := {"Hammer": "hammer", "Shears": "shears", "Sickle": "sickle"}
	for n in lay:
		var tool_node := Node3D.new()
		tool_node.name = n
		tool_node.position = table.position + (lay[n][0] as Vector3)
		var m := ToolModels.make(models[n])
		m.rotation_degrees = lay[n][1]
		tool_node.add_child(m)
		props.add_child(tool_node)
	for b in [["Basket2", Vector3(5.8, 0, -17.2)], ["Basket3", Vector3(-4.6, 0, -19.8)]]:
		var basket := _model("basket", Color("#A87B4F"))
		basket.name = b[0]
		basket.position = b[1]
		props.add_child(basket)

func _equip(k: StringName) -> void:
	if player.tool != &"":
		_return_tool(player.tool)
	player.equip(k)
	tool_nodes[k].visible = false
	_area_on(tool_areas[k], false)

func _return_tool(k: StringName) -> void:
	tool_nodes[k].visible = true
	_area_on(tool_areas[k], true)

func player_put_back_tool() -> void:
	if player.tool != &"":
		_return_tool(player.tool)
		player.unequip()

# ---------------------------------------------------------------- tâches du matin
func _setup_tasks() -> void:
	for id in TASKS:
		var t: MorningTask = (TASKS[id] as GDScript).new()
		t.name = "Task_" + String(id)
		t.id = id
		t.game = self
		add_child(t)
		t.setup()
		tasks[id] = t

## Tire les tâches du matin : jamais deux jours de suite la même si on peut l'éviter.
func _choose_morning() -> Array[StringName]:
	var chosen: Array[StringName] = []
	if not _forced.is_empty():
		chosen = _forced.duplicate()
		return chosen
	var fresh: Array[StringName] = []
	var old: Array[StringName] = []
	for id in TASKS:
		if _yesterday.has(id):
			old.append(id)
		else:
			fresh.append(id)
	fresh.shuffle()
	old.shuffle()
	for id in fresh + old:
		if chosen.size() < MORNING_COUNT:
			chosen.append(id)
	return chosen

# ---------------------------------------------------------------- jardin sec
func _setup_zen() -> void:
	zen_mat = Toon.make_material(Color("#8F8B7C"), 0.0)
	var holder := Node3D.new()
	holder.name = "ZenGarden"
	holder.position = Vector3(Terrain.ZEN.x, 0.0, Terrain.ZEN.y)
	props.add_child(holder)
	_make(holder, Vector3(Terrain.ZEN.z * 2.0, 0.5, Terrain.ZEN.w * 2.0), Vector3(0, 0.1, 0),
		func() -> String:
			if GameState.is_done(&"zen"):
				return "Le jardin est bien ratissé"
			return "Maintenir le clic et ratisser" if player.tool == &"rake" else "Il faudrait un râteau",
		Callable(),
		func(pl, _delta, _motion):
			if pl.tool != &"rake":
				return
			var hp: Vector3 = pl.ray.get_collision_point()
			if zen_last == Vector3.INF:
				zen_last = hp
				return
			var step := Vector3(hp.x - zen_last.x, 0.0, hp.z - zen_last.z)
			if step.length() < 0.35:
				return
			var dir := step.normalized()
			_add_zen_mark(Vector3(hp.x, 0.025, hp.z), dir)
			zen_last = hp)

func _add_zen_mark(p: Vector3, dir: Vector3) -> void:
	if zen_marks.size() > 600:
		return
	var yaw := -atan2(dir.z, dir.x)
	var side := Vector3(-dir.z, 0.0, dir.x)
	for k in [-1, 0, 1]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.012, 0.045)
		mi.mesh = bm
		mi.material_override = zen_mat
		mi.position = p + side * (0.11 * k)
		mi.rotation.y = yaw
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props.add_child(mi)
		zen_marks.append(mi)
	GameState.add_progress(&"zen")

# ---------------------------------------------------------------- lanternes
func _setup_lanterns() -> void:
	var i := 0
	while props.has_node("Lantern_%d" % i):
		var l: Node3D = props.get_node("Lantern_%d" % i)
		lanterns.append(l)
		var idx := i
		var a := _make(l, Vector3(0.9, 2.0, 0.9), Vector3(0, 0.95, 0),
			func() -> String:
				if lit.get(idx, false):
					return ""
				if GameState.phase != Phase.EVENING:
					return "Elle ne s'allume que le soir"
				if player.tool != &"match":
					return "Il faudrait des allumettes"
				return "E : Allumer la lanterne",
			func(_p):
				if not lit.get(idx, false) and GameState.phase == Phase.EVENING and player.tool == &"match":
					_light(idx))
		lantern_areas.append(a)
		i += 1

func _light(i: int) -> void:
	lit[i] = true
	var anchor: Node3D = lanterns[i].find_child("flame_anchor", true, false)
	var parent: Node3D = anchor if anchor else lanterns[i]
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.14
	flame.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.38)
	flame.material_override = m
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flame)
	var light := OmniLight3D.new()
	light.name = "FlameLight"
	light.light_color = Color(1.0, 0.68, 0.34)
	light.omni_range = 8.0
	light.omni_attenuation = 1.3
	light.light_energy = 1.5
	parent.add_child(light)
	flames.append(light)
	GameState.add_progress(&"lanternes")

# ---------------------------------------------------------------- cloche
func _setup_bell() -> void:
	var box: Node3D = props.get_node("OfferingBox")
	rope = box.find_child("rope", true, false)
	bell = box.find_child("bell", true, false)
	_make(box, Vector3(0.7, 1.9, 0.7), Vector3(0, 1.85, 0.22),
		func() -> String:
			if _ending:
				return ""
			if GameState.phase != Phase.EVENING:
				return "La cloche sonne le soir"
			if not GameState.bell_ready():
				return "Il reste à faire avant de sonner la cloche"
			return "E : Sonner la cloche",
		func(_p):
			if not _ending and GameState.phase == Phase.EVENING and GameState.bell_ready():
				_ring_bell())

func _make_bell_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 5
	var data := PackedByteArray()
	data.resize(n * 2)
	var partials := [[196.0, 1.0, 0.55], [392.0 * 1.003, 0.6, 0.9], [196.0 * 2.76, 0.4, 1.4], [196.0 * 5.4, 0.2, 2.2]]
	for i in n:
		var t := float(i) / rate
		var s := 0.0
		for p in partials:
			s += p[1] * sin(TAU * p[0] * t) * exp(-t * p[2])
		s *= minf(t * 60.0, 1.0) * 0.38
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _ring_bell() -> void:
	_ending = true
	player.input_enabled = false
	if rope:
		var tw := create_tween()
		for k in 3:
			tw.tween_property(rope, "rotation:x", 0.2, 0.25)
			tw.tween_property(rope, "rotation:x", -0.1, 0.3)
		tw.tween_property(rope, "rotation:x", 0.0, 0.3)
	if bell:
		var tb := create_tween()
		for k in 3:
			tb.tween_property(bell, "rotation:x", -0.12, 0.3)
			tb.tween_property(bell, "rotation:x", 0.08, 0.35)
		tb.tween_property(bell, "rotation:x", 0.0, 0.3)
	_bell_sound.play()
	GameState.add_progress(&"cloche")
	await get_tree().create_timer(4.5).timeout
	await _night()
	_end_day()

# ---------------------------------------------------------------- nuit
## Après la cloche : la nuit tombe, et parfois un événement (renard, tanuki, souvenir...) a lieu.
## Les événements sont des visites de type « night » dans data/story/story.json.
func _night() -> void:
	GameState.set_phase(Phase.NIGHT)
	_apply_lighting(Phase.NIGHT, false)
	player.input_enabled = true
	player.move_locked = true            # on regarde autour de soi, on ne part plus
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(4.0).timeout
	var ev := Story.night_for_day(GameState.day, _rng)
	if ev.is_empty():
		Events.toast.emit("La nuit tombe sur le sanctuaire. Les lanternes veillent.")
		await get_tree().create_timer(4.0).timeout
	else:
		await _play_night(ev)
	player.move_locked = false
	player.input_enabled = false

func _play_night(ev: Dictionary) -> void:
	var actor_kind := String(ev.get("actor", ""))
	var creature: Node3D = null
	var start := Vector3.ZERO
	if actor_kind != "":
		creature = ToolModels.creature(actor_kind)
		if creature == null and actor_kind == "chat":
			creature = _model("shrine_cat", Color("#EFE6D2"))
			for b in creature.find_children("*", "CollisionObject3D", true, false):
				b.queue_free()
		elif creature != null:
			Toon.apply(creature)
	if creature != null:
		# la créature sort de l'ombre, devant le joueur, et s'arrête à deux pas
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		start = player.global_position + fwd * 9.0 + side * _rng.randf_range(-4.0, 4.0)
		start.x = clampf(start.x, -23.0, 23.0)
		start.z = clampf(start.z, -34.0, 8.0)
		var stop := player.global_position + fwd * 2.3
		creature.position = Vector3(start.x, TERRAIN.walk_y(start.x, start.z), start.z)
		creature.scale = Vector3.ONE * 0.01
		world.add_child(creature)
		var tw := creature.create_tween()
		tw.tween_property(creature, "scale", Vector3.ONE * (1.4 if actor_kind == "chat" else 1.0), 0.8)
		Sfx.play(StringName(actor_kind), creature.position, -4.0)
		await _creature_walk(creature, stop, 2.2)
		_face(creature, player.global_position)
		await get_tree().create_timer(1.2).timeout
	player.input_enabled = false
	if OS.get_cmdline_user_args().has("--autoplay"):
		print("AUTOPLAY nuit : %s (%s)" % [ev.get("id", ""), actor_kind])
	await vn.play_visit(ev)
	GameState.visited[String(ev.get("id", ""))] = true
	GameState.note("Cette nuit : %s." % String(ev.get("title", "un moment étrange")).to_lower())
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if creature != null and is_instance_valid(creature):
		await _creature_walk(creature, start, 3.2)
		var out := creature.create_tween()
		out.tween_property(creature, "scale", Vector3.ONE * 0.01, 0.6)
		await out.finished
		creature.queue_free()
	await get_tree().create_timer(1.5).timeout

func _face(n: Node3D, target: Vector3) -> void:
	n.rotation.y = atan2(target.x - n.position.x, target.z - n.position.z)

## Petits bonds réguliers jusqu'au point visé (créatures de la nuit).
func _creature_walk(n: Node3D, to: Vector3, speed: float) -> void:
	var from := n.position
	_face(n, to)
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var x := lerpf(from.x, to.x, t)
		var z := lerpf(from.z, to.z, t)
		n.position = Vector3(x, TERRAIN.walk_y(x, z) + absf(sin(t * dist * 3.5)) * 0.08, z), 0.0, 1.0, maxf(dist / speed, 0.1))
	await tw.finished

func _end_day() -> void:
	GameState.update_bonds()
	Events.day_ended.emit(GameState.day)
	await hud.fade_to(1.0, 2.0)
	var d := GameState.day
	await hud.show_journal(_journal_page())
	if d >= GameState.MAX_DAYS:
		await hud.show_card("Le sanctuaire est calme.\nFin du prototype — merci d'avoir veillé sur ce lieu.", 5.0)
		_start_day(1)
		return
	_start_day(d + 1)

const JOURNAL_ENDINGS := [
	"Le vent est tombé avec la nuit. On entend le ruisseau, plus bas.",
	"Les lanternes brûlaient encore quand j'ai fermé les yeux.",
	"Une feuille d'érable s'est posée sur le seuil. Je l'ai laissée là.",
	"La montagne a l'air de respirer plus lentement, ce soir.",
	"Il fait froid. Demain, les arbres auront encore changé de couleur.",
]

## Contenu du journal du soir, tiré du carnet de la journée (GameState.day_log).
func _journal_page() -> Dictionary:
	var lg: Dictionary = GameState.day_log
	var tasks_done := PackedStringArray()
	var extra_done := PackedStringArray()
	for id in lg.get("tasks", []):
		var td: TaskData = GameState.task_data.get(id)
		if td == null or id == &"cloche" or tasks_done.has(td.label) or extra_done.has(td.label):
			continue
		if td.required:
			tasks_done.append(td.label)
		else:
			extra_done.append(td.label)
	var visitors := []
	var seen := {}
	for who in lg.get("visitors", []):
		if seen.has(who):
			continue
		seen[who] = true
		visitors.append({"name": Story.display_name(who), "color": Story.color_of(who),
			"delta": int((lg.get("affection", {}) as Dictionary).get(who, 0))})
	return {
		"title": "Jour %d — automne" % GameState.day,
		"tasks": tasks_done, "extra": extra_done, "visitors": visitors,
		"coins_in": int(lg.get("coins_in", 0)), "coins_out": int(lg.get("coins_out", 0)), "coins": GameState.coins,
		"harvest": int(lg.get("harvest", 0)),
		"notes": lg.get("notes", []),
		"ending": JOURNAL_ENDINGS[(GameState.day * 7 + visitors.size()) % JOURNAL_ENDINGS.size()],
	}

# ---------------------------------------------------------------- lumière
func _apply_lighting(phase: int, instant: bool) -> void:
	atmosphere.set_phase(phase, instant)

# ---------------------------------------------------------------- journée
func _start_day(d: int) -> void:
	_ending = false
	_visit_pending = false
	player.input_enabled = false
	hud.set_black()
	# remise à zéro du décor
	for k in tool_nodes:
		_return_tool(k)
	player.unequip()
	player.set_carry(&"")
	player.move_locked = false
	hud.set_banner("")
	for l in lanterns:
		for n in ["Flame", "FlameLight"]:
			var f: Node = l.find_child(n, true, false)
			if f:
				f.queue_free()
	flames.clear()
	lit.clear()
	if rope:
		rope.rotation.x = 0.0
	if visitor and is_instance_valid(visitor):
		visitor.queue_free()
		visitor = null
	_visitor_ready_flag = false
	_evening_pending = false
	visit_current = {}
	var morning := _choose_morning()
	_yesterday = morning.duplicate()
	GameState.morning = morning
	GameState.today = morning.duplicate()
	GameState.today.append_array([&"lanternes", &"cloche"])
	if d == 1:
		GameState.reset_story()
	GameState.begin_day(d)
	_rng.randomize()
	visit_queue = Story.visits_for_day(d, _rng)
	var first := Story.setting_range("first_visit_delay", Vector2(30, 60))
	visit_timer = _rng.randf_range(first.x, first.y)
	for id in tasks:
		var t: MorningTask = tasks[id]
		t.active = false
		t.clear()
	for id in morning:
		var t: MorningTask = tasks[id]
		t.active = true
		t.begin(d)
	GameState.set_target(&"lanternes", lanterns.size())
	GameState.set_target(&"cloche", 1)
	GameState.set_target(&"zen", 40)
	for m in zen_marks:
		if is_instance_valid(m):
			m.queue_free()
	zen_marks.clear()
	zen_last = Vector3.INF
	extras.on_day_start()
	harvest.on_day_start()
	koi_pond.on_day_start(d)
	_apply_lighting(Phase.MORNING, true)
	player.global_position = Vector3(0, TERRAIN.walk_y(0.0, 36.0) + 0.05, 36.0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.head.rotation.x = 0.12
	await hud.show_card("Jour %d\nAutomne" % d, 1.0)
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade_to(0.0, 1.6)
	var names := PackedStringArray()
	for id in morning:
		names.append((GameState.task_data[id] as TaskData).label.to_lower())
	Events.toast.emit(("Montez l'escalier. " if d == 1 else "") + "Ce matin : %s." % " et ".join(names))
	for id in morning:
		var h := (tasks[id] as MorningTask).hint()
		if h != "":
			Events.toast.emit(h)

func _on_task_done(id: StringName) -> void:
	if GameState.morning.has(id) and not _visit_pending and GameState.phase == Phase.MORNING and GameState.morning_done():
		_visit_pending = true
		await get_tree().create_timer(2.0).timeout
		GameState.set_phase(Phase.VISIT)
		_apply_lighting(Phase.VISIT, false)
		if visitor != null or not visit_queue.is_empty():
			Events.toast.emit("Les tâches du matin sont faites. L'après-midi s'étire ; d'autres visiteurs viendront peut-être.")
			visit_timer = minf(visit_timer, 6.0)
		_check_evening()

## Le soir tombe quand le matin est fini et que plus aucun visiteur n'est attendu.
func _check_evening() -> void:
	if _evening_pending or _ending or GameState.phase == Phase.EVENING:
		return
	if not GameState.morning_done() or visitor != null or not visit_queue.is_empty():
		return
	_evening_pending = true
	await get_tree().create_timer(4.0).timeout
	_start_evening()

func _start_evening() -> void:
	GameState.set_phase(Phase.EVENING)
	_apply_lighting(Phase.EVENING, false)
	Events.toast.emit("Le soir tombe. Prenez les allumettes et allumez les lanternes, puis sonnez la cloche.")

# ---------------------------------------------------------------- visiteurs
const VISITOR_PATH := [Vector3(0, 0, 36.0), Vector3(0, 0, 28.5), Vector3(0, 0, 13.0), Vector3(0, 0, 9.0)]
## Endroits où un visiteur s'arrête et attend qu'on vienne lui parler (clé "spot" d'une visite).
const SPOTS := {
	"offrandes": [Vector3(1.0, 0, -15.2), "devant le tronc à offrandes"],
	"ema": [Vector3(8.8, 0, -12.6), "près du présentoir à ema"],
	"etang": [Vector3(-13.4, 0, -19.8), "au bord de l'étang"],
	"the": [Vector3(12.4, 0, -2.6), "devant la salle de thé"],
	"jardin": [Vector3(-10.2, 0, -8.6), "devant le jardin sec"],
	"arbre": [Vector3(11.0, 0, -23.0), "sous l'arbre sacré"],
	"torii": [Vector3(1.8, 0, 6.8), "près du torii d'entrée"],
}

func _tick_visits(delta: float) -> void:
	if _ending or GameState.phase == Phase.EVENING or visitor != null or visit_queue.is_empty():
		return
	if not player.input_enabled and not OS.get_cmdline_user_args().has("--autoplay"):
		return   # transitions, dialogues : le temps des visites ne court pas
	visit_timer -= delta
	if visit_timer <= 0.0:
		_spawn_visit(visit_queue.pop_front())

func _walk(node: Node3D, pts: Array) -> void:
	for i in range(1, pts.size()):
		var from: Vector3 = node.position
		var to: Vector3 = pts[i]
		var dist := Vector2(to.x - from.x, to.z - from.z).length()
		var dur := maxf(dist / 1.7, 0.05)
		var face := atan2(to.x - from.x, to.z - from.z)
		node.rotation.y = face
		var tw := create_tween()
		tw.tween_method(func(t: float):
			var x := lerpf(from.x, to.x, t)
			var z := lerpf(from.z, to.z, t)
			node.position = Vector3(x, TERRAIN.walk_y(x, z) + absf(sin(t * dist * 2.6)) * 0.04, z), 0.0, 1.0, dur)
		await tw.finished

func _spawn_visit(v: Dictionary) -> void:
	visit_current = v
	_visitor_ready_flag = false
	var who := String(v.get("character", ""))
	var spot: Array = SPOTS.get(String(v.get("spot", "offrandes")), SPOTS["offrandes"])
	visitor = load("res://scenes/visitors/visitor_placeholder.tscn").instantiate()
	visitor.set("display_name", Story.display_name(who))
	visitor.set("color", Story.color_of(who))
	var start: Vector3 = VISITOR_PATH[0]
	visitor.position = Vector3(start.x, TERRAIN.walk_y(start.x, start.z), start.z)
	world.add_child(visitor)
	Events.toast.emit("Quelqu'un monte l'escalier...")
	# chaque visiteur commence par prier au tronc : il y jette ses pièces, ramassées automatiquement
	var path := VISITOR_PATH.duplicate()
	path.append(OFFERING_SPOT)
	var v_node := visitor
	await _walk(v_node, path)
	if not is_instance_valid(v_node):
		return
	v_node.rotation.y = PI
	await get_tree().create_timer(0.8).timeout
	await _toss_offering(v_node, Story.offering_for(v))
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(v_node):
		return
	if (spot[0] as Vector3).distance_to(OFFERING_SPOT) > 0.5:
		await _walk(v_node, [v_node.position, spot[0]])
		if not is_instance_valid(v_node):
			return
		await get_tree().create_timer(1.0).timeout
	_visitor_ready_flag = true
	GameState.met[who] = true
	_patience = float(Story.settings().get("visitor_patience", 150))
	_patience_warned = false
	Events.toast.emit("%s vous attend %s." % [Story.display_name(who), spot[1]])
	_make(v_node, Vector3(1.1, 1.9, 1.1), Vector3(0, 0.95, 0),
		func() -> String: return "E : Parler à %s" % Story.display_name(who),
		func(_p): _talk())

const OFFERING_SPOT := Vector3(0.9, 0, -15.3)

## Pièces lancées par un visiteur dans le tronc à offrandes : arc, tintement, ajoutées au compte.
func _toss_offering(v_node: Node3D, n: int) -> void:
	if n <= 0:
		return
	var box: Node3D = props.get_node("OfferingBox")
	var target := box.global_position + Vector3(0, 0.95, 0.05)
	for i in n:
		if not is_instance_valid(v_node):
			return
		var c := ToolModels.coin()
		c.scale = Vector3.ONE * 2.0
		props.add_child(c)
		var from := v_node.global_position + Vector3(0, 1.25, 0)
		c.global_position = from
		var tw := c.create_tween()
		tw.tween_method(func(t: float):
			c.global_position = from.lerp(target, t) + Vector3(0, sin(t * PI) * 0.7, 0)
			c.rotation.x = t * 16.0, 0.0, 1.0, 0.5)
		tw.tween_callback(func():
			Sfx.play(&"coin", target, -2.0)
			GameState.add_coins(1)
			c.queue_free())
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.5).timeout

## Après le dialogue : si l'on porte quelque chose, on peut l'offrir. Le personnage réagit selon ses goûts
## (adore +3, aime +1, sans plus 0, n'aime pas -1) et l'on retient ce qu'on a appris de lui.
func _offer_gift(who: String) -> void:
	if GameState.inventory.is_empty() or Story.is_animal(who):
		return
	var options := []
	for id in GameState.inventory:
		var known: Dictionary = GameState.gift_known.get(who, {})
		options.append({"id": id, "name": Story.item_name(id), "count": GameState.item_count(id),
			"hint": String(Story.GIFT_TIER_NAMES.get(known.get(id, ""), ""))})
	var pick: String = await vn.choose_gift(who, options)
	if pick == "":
		return
	GameState.remove_item(pick)
	var tier := Story.gift_tier(who, pick)
	var known2: Dictionary = GameState.gift_known.get(who, {})
	known2[pick] = tier
	GameState.gift_known[who] = known2
	var expr: String = {"love": "sourire", "like": "sourire", "neutral": "neutre", "dislike": "neutre"}[tier]
	var reaction := {"character": who, "start": "r", "nodes": {"r": {"type": "line", "speaker": who, "expr": expr,
		"text": Story.gift_line(who, tier), "next": "",
		"effects": [{"type": "affection", "character": who, "delta": int(Story.GIFT_TIERS.get(tier, 0))}]}}}
	await vn.play_visit(reaction)
	GameState.note("J'ai offert : %s à %s (%s)." % [Story.item_name(pick).to_lower(), Story.display_name(who), Story.GIFT_TIER_NAMES.get(tier, "")])

## Un visiteur qu'on laisse attendre trop longtemps repart : affection -1 et son ema s'abîme.
func _tick_patience(delta: float) -> void:
	if visitor == null or not _visitor_ready_flag or not player.input_enabled:
		return
	if OS.get_cmdline_user_args().has("--autoplay"):
		return
	_patience -= delta
	var who := String(visit_current.get("character", ""))
	if _patience < 40.0 and not _patience_warned:
		_patience_warned = true
		Events.toast.emit("%s semble s'impatienter..." % Story.display_name(who))
	if _patience <= 0.0:
		_leave_unheard()

func _leave_unheard() -> void:
	_visitor_ready_flag = false
	var who := String(visit_current.get("character", ""))
	for c in visitor.get_children():
		if c is Interactable:
			_area_on(c, false)
	GameState.missed[who] = int(GameState.missed.get(who, 0)) + 1
	GameState.add_affection(who, -1, Story.affection_max(who))
	GameState.note("%s est reparti sans que je lui parle." % Story.display_name(who))
	Events.toast.emit("%s redescend l'escalier sans vous avoir parlé." % Story.display_name(who))
	await _visitor_goes_home()

func _visitor_goes_home() -> void:
	var back: Array = VISITOR_PATH.duplicate()
	back.reverse()
	back.push_front(visitor.position)
	var v := visitor
	var vid := String(visit_current.get("id", ""))
	await _walk(v, back)
	v.queue_free()
	visitor = null
	visit_current = {}
	Events.visitor_left.emit(StringName(vid))
	var gap := Story.setting_range("visit_gap", Vector2(60, 120))
	visit_timer = _rng.randf_range(gap.x, gap.y) * (0.15 if GameState.morning_done() else 1.0)
	_check_evening()

func _talk() -> void:
	if visitor == null or not _visitor_ready_flag:
		return
	_visitor_ready_flag = false
	for c in visitor.get_children():
		if c is Interactable:
			_area_on(c, false)
	player.input_enabled = false
	await vn.play_visit(visit_current)
	GameState.visited[String(visit_current.get("id", ""))] = true
	(GameState.day_log["visitors"] as Array).append(String(visit_current.get("character", "")))
	await _offer_gift(String(visit_current.get("character", "")))
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var wish := String(visit_current.get("wish", ""))
	if wish != "":
		var who_w := String(visit_current.get("character", ""))
		GameState.ema_log.append({"character": who_w, "wish": wish, "day": GameState.day})
		extras.hang_visitor_ema(who_w)
		Events.toast.emit("%s accroche un ema au présentoir. (E devant le présentoir pour lire les vœux)" % Story.display_name(who_w))
	await _visitor_goes_home()
