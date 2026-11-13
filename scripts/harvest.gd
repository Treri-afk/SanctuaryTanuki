extends Node
## Récolte : chaque matin, des objets (kakis, châtaignes, champignons...) apparaissent dans la montagne,
## selon les lieux de chaque objet dans data/story/story.json (« items »). On les ramasse avec E ; ils vont dans
## l'inventaire (GameState.inventory) et peuvent être offerts aux visiteurs.

const HALO_SHADER := preload("res://shaders/pickup_halo.gdshader")
const ZONES := ["enceinte", "sentier", "foret", "mare", "belvedere"]
const ZONE_NAMES := {"enceinte": "la cour du sanctuaire", "sentier": "le long des sentiers", "foret": "les sous-bois",
	"mare": "près de la mare et du ruisseau", "belvedere": "la prairie du belvédère"}

var game: Node3D
var nodes: Array = []
var _rng := RandomNumberGenerator.new()
var _glint_mat: StandardMaterial3D

func setup(g: Node3D) -> void:
	game = g
	_glint_mat = StandardMaterial3D.new()
	_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glint_mat.albedo_color = Color(1.0, 0.86, 0.45, 0.95)
	_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func on_day_start() -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	_rng.randomize()
	var defs := Story.items()
	if defs.is_empty():
		return
	var total := int(Story.settings().get("harvest_per_day", 12))
	var weights := []
	var sum := 0.0
	for it in defs:
		sum += maxf(float(it.get("weight", 1)), 0.0)
		weights.append(sum)
	for i in total:
		var r := _rng.randf() * sum
		var it: Dictionary = defs[0]
		for k in defs.size():
			if r <= float(weights[k]):
				it = defs[k]
				break
		var zones: Array = it.get("zones", ["foret"])
		if zones.is_empty():
			continue
		var p := _spot(String(zones[_rng.randi() % zones.size()]))
		if p != Vector3.INF:
			_place(it, p)

## Point au sol dans une zone, ou Vector3.INF si aucun n'est trouvé.
func _spot(zone: String) -> Vector3:
	for attempt in 30:
		var x := 0.0
		var z := 0.0
		match zone:
			"enceinte":
				x = _rng.randf_range(-22.5, 22.5)
				z = _rng.randf_range(-33.5, 7.5)
				var forest: Node = game.world.get_node_or_null("Forest")
				if forest and forest.has_method("_precinct_blocked") and forest._precinct_blocked(x, z):
					continue
				if absf(x) < 2.5:
					continue
			"sentier":
				var keys := Terrain.TRAILS.keys()
				var pts: Array = Terrain.TRAILS[keys[_rng.randi() % keys.size()]]
				var i := _rng.randi() % (pts.size() - 1)
				var t := _rng.randf()
				var a: Array = pts[i]
				var b: Array = pts[i + 1]
				var px := lerpf(a[0], b[0], t)
				var pz := lerpf(a[1], b[1], t)
				var d := Vector2(b[0] - a[0], b[1] - a[1]).normalized()
				var side := Vector2(-d.y, d.x) * _rng.randf_range(1.8, 3.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
				x = px + side.x
				z = pz + side.y
			"foret":
				x = _rng.randf_range(-70.0, 70.0)
				z = _rng.randf_range(-92.0, 10.0)
				if Terrain.rect_dist(x, z) < 4.0 or Terrain.trail_dist(x, z) > 18.0 or Terrain.stream_dist(x, z) < 3.0:
					continue
			"mare":
				if _rng.randf() < 0.5:
					var ang := _rng.randf() * TAU
					var rad := _rng.randf_range(Terrain.POND.z + 1.2, Terrain.POND.z + 5.0)
					x = Terrain.POND.x + cos(ang) * rad
					z = Terrain.POND.y + sin(ang) * rad
				else:
					var sp: Array = Terrain.STREAM[_rng.randi() % (Terrain.STREAM.size() - 1)]
					x = float(sp[0]) + _rng.randf_range(-3.0, 3.0)
					z = float(sp[1]) + _rng.randf_range(-4.0, 4.0)
					if Terrain.stream_dist(x, z) < 2.4:
						continue
			"belvedere":
				var f: Array = Terrain.FLATS[0]
				var ang2 := _rng.randf() * TAU
				var rad2 := _rng.randf_range(2.0, 12.0)
				x = float(f[0]) + cos(ang2) * rad2
				z = float(f[1]) + sin(ang2) * rad2
		if absf(x) > 82.0 or z < -100.0 or z > 12.0:
			continue
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var top := Terrain.height(x, z) + 4.0
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, top - 10.0, z), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var hp: Vector3 = hit["position"]
		if absf(hp.y - Terrain.height(x, z)) > 0.4:
			continue   # sur un rocher, un muret, une souche...
		return hp
	return Vector3.INF

func _place(it: Dictionary, p: Vector3) -> void:
	var id := String(it.get("id", ""))
	var holder := Node3D.new()
	holder.position = p
	holder.rotation.y = _rng.randf() * TAU
	game.props.add_child(holder)
	var m := ToolModels.item(String(it.get("shape", "")), Color.from_string(String(it.get("color", "#C8442B")), Color.ORANGE))
	m.scale = Vector3.ONE * 2.2   # plus gros que nature, pour être vu à hauteur d'yeux
	holder.add_child(m)
	# petit scintillement pour l'apercevoir de loin, sans halo voyant
	var glint := CPUParticles3D.new()
	var q := SphereMesh.new()
	q.radius = 0.018
	q.height = 0.036
	q.radial_segments = 8
	q.rings = 4
	q.material = _glint_mat
	glint.mesh = q
	glint.amount = 5
	glint.lifetime = 1.6
	glint.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glint.emission_sphere_radius = 0.12
	glint.direction = Vector3.UP
	glint.gravity = Vector3(0, 0.12, 0)
	glint.initial_velocity_min = 0.02
	glint.initial_velocity_max = 0.08
	glint.scale_amount_min = 0.4
	glint.scale_amount_max = 1.0
	glint.position = Vector3(0, 0.12, 0)
	holder.add_child(glint)
	# halo doré très doux posé au sol, qui respire : on repère l'objet sans qu'il crie
	var halo := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(0.7, 0.7)
	disc.orientation = PlaneMesh.FACE_Y
	halo.mesh = disc
	var hm := ShaderMaterial.new()
	hm.shader = HALO_SHADER
	halo.material_override = hm
	halo.position.y = 0.02
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(halo)
	var iname := String(it.get("name", id))
	game._make(holder, Vector3(0.55, 0.45, 0.55), Vector3(0, 0.15, 0),
		func() -> String:
			if GameState.inventory_total() >= GameState.INVENTORY_MAX:
				return "%s — vos poches sont pleines" % iname
			return "E : Ramasser : %s" % iname,
		func(_p): _pick(holder, id, iname))
	nodes.append(holder)

func _pick(holder: Node3D, id: String, iname: String) -> void:
	if not is_instance_valid(holder) or not GameState.add_item(id):
		return
	nodes.erase(holder)
	GameState.day_log["harvest"] = int(GameState.day_log.get("harvest", 0)) + 1
	Sfx.play(&"pickup", holder.global_position)
	game.player.kick(Vector3(0.3, 0, 0), Vector3(0, -0.08, 0.02), 0.05, 0.25)
	var tw := holder.create_tween()
	tw.tween_property(holder, "position", holder.position + Vector3(0, 0.35, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "scale", Vector3.ONE * 0.01, 0.3).set_delay(0.1)
	tw.tween_callback(holder.queue_free)
	Events.toast.emit("+1 %s  (Tab : vos poches)" % iname)

## Test automatique : ramasse quelques objets.
func autoplay(n: int = 3) -> void:
	for h in nodes.duplicate().slice(0, n):
		for c in h.get_children():
			if c is Interactable:
				(c as Interactable).use_fn.call(game.player)
