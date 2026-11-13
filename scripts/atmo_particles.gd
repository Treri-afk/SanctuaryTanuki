## (pas de class_name : chargé par preload depuis atmosphere.gd)
extends Node3D
## Particules d'ambiance, créées par Atmosphere :
##  - feuilles d'érable qui tombent autour du joueur (léger semis partout, plus dense sous les érables proches),
##    qui tourbillonnent au vent, se posent au sol puis disparaissent ; `gust()` les fait s'envoler ;
##  - poussières dorées autour du joueur, visibles seulement dans les rayons de soleil ;
##  - lucioles le soir au-dessus de l'eau (étang, mare, ruisseau).

const LEAF_PROCESS := preload("res://shaders/leaf_fall.gdshader")
const LEAF_SHADER := preload("res://shaders/leaf.gdshader")
const MOTE_SHADER := preload("res://shaders/mote.gdshader")
const FLY_SHADER := preload("res://shaders/firefly.gdshader")
const MAPLE_EMITTERS := 6

var _ambient: GPUParticles3D
var _maple_emitters: Array[GPUParticles3D] = []
var _maples: PackedVector4Array = PackedVector4Array()   # x, y, z, échelle
var _dust: GPUParticles3D
var _flies: Array[GPUParticles3D] = []
var _collider: GPUParticlesCollisionHeightField3D
var _leaf_mats: Array[ShaderMaterial] = []
var _dust_mat: ShaderMaterial
var _fly_mat: ShaderMaterial
var _leaf_level := 1.0
var _gust := 0.0
var _retarget := 0.0
var _wind := Vector2(1, 0)
var _ws := 1.0
var _last_cam := Vector3.INF

func setup(world: Node) -> void:
	_collect_maples(world)
	var draw := _leaf_draw_mesh()
	_ambient = _leaf_emitter(draw, 220, 12.0, Vector3(9.0, 3.0, 9.0))
	_ambient.name = "AmbientLeaves"
	for i in MAPLE_EMITTERS:
		var e := _leaf_emitter(draw, 40, 10.0, Vector3(2.2, 0.8, 2.2))
		e.name = "MapleLeaves%d" % i
		e.emitting = false
		_maple_emitters.append(e)
	_collider = GPUParticlesCollisionHeightField3D.new()
	_collider.name = "LeafGround"
	_collider.size = Vector3(48.0, 40.0, 48.0)
	_collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_collider.follow_camera_enabled = true
	_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_collider)
	_make_dust()
	_make_flies(world)

func _collect_maples(world: Node) -> void:
	var forest := world.get_node_or_null("Forest")
	if forest:
		for c in forest.get_children():
			if c is MultiMeshInstance3D and String(c.name).begins_with("maple") and String(c.name).contains("foliage"):
				var mm := (c as MultiMeshInstance3D).multimesh
				for i in mm.instance_count:
					var t := mm.get_instance_transform(i)
					_maples.append(Vector4(t.origin.x, t.origin.y, t.origin.z, t.basis.get_scale().x))
	var props := world.get_node_or_null("Props")
	if props:
		for c in props.get_children():
			var nm := String(c.name)
			if c is Node3D and (nm.contains("Maple") or nm == "Shinboku"):
				var n3 := c as Node3D
				_maples.append(Vector4(n3.position.x, n3.position.y, n3.position.z, n3.scale.x * (1.3 if nm == "Shinboku" else 1.0)))

func _leaf_draw_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.21, 0.21)
	var m := ShaderMaterial.new()
	m.shader = LEAF_SHADER
	m.set_shader_parameter("translucency", 0.6)
	m.set_shader_parameter("rim_strength", 0.3)
	q.material = m
	return q

func _leaf_emitter(draw: Mesh, amount: int, life: float, extents: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ShaderMaterial.new()
	pm.shader = LEAF_PROCESS
	pm.set_shader_parameter("box_extents", extents)
	_leaf_mats.append(pm)
	p.process_material = pm
	p.draw_pass_1 = draw
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.randomness = 1.0
	p.local_coords = false
	p.fixed_fps = 30
	p.interpolate = true
	p.collision_base_size = 0.02
	p.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _make_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "Dust"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 2.5, 9.0)
	pm.gravity = Vector3(0, 0.02, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_noise_speed_random = 0.3
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	_dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	_dust_mat = ShaderMaterial.new()
	_dust_mat.shader = MOTE_SHADER
	q.material = _dust_mat
	_dust.draw_pass_1 = q
	_dust.amount = 260
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40))
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)

func _make_flies(world: Node) -> void:
	_fly_mat = ShaderMaterial.new()
	_fly_mat.shader = FLY_SHADER
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = _fly_mat
	# [centre, demi-taille, nombre]
	var spots := [
		[Vector3(Terrain.PREC_POND.x, 0.5, Terrain.PREC_POND.y), Vector3(5.0, 0.7, 5.0), 26],
		[Vector3(Terrain.POND.x, Terrain.hill(Terrain.POND.x, Terrain.POND.y), Terrain.POND.y), Vector3(5.0, 0.8, 5.0), 26],
		[Vector3(-44.5, Terrain.hill(-44.5, 0.0), 0.0), Vector3(2.5, 0.8, 12.0), 30],
		[Vector3(-8.5, 0.8, 3.0), Vector3(1.5, 0.5, 1.5), 6],
	]
	for s in spots:
		var p := GPUParticles3D.new()
		p.name = "Fireflies"
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = s[1]
		pm.gravity = Vector3.ZERO
		pm.spread = 180.0
		pm.initial_velocity_min = 0.05
		pm.initial_velocity_max = 0.2
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.2
		pm.turbulence_noise_scale = 2.5
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.12
		p.process_material = pm
		p.draw_pass_1 = q
		p.amount = s[2]
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.position = s[0] + Vector3(0, s[1].y + 0.25, 0)
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-16, -4, -16), Vector3(32, 8, 32))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.emitting = false
		add_child(p)
		_flies.append(p)

func set_levels(leaves: float, dust: float, flies: float) -> void:
	_leaf_level = leaves
	if _ambient:
		_ambient.amount_ratio = clampf(leaves, 0.0, 1.0)
	if _dust_mat:
		_dust_mat.set_shader_parameter("level", dust)
		_dust.emitting = dust > 0.01
	if _fly_mat:
		_fly_mat.set_shader_parameter("level", flies)
		for f in _flies:
			f.emitting = flies > 0.05

func set_wind(dir: Vector2, strength: float) -> void:
	_wind = dir
	_ws = strength

func gust(force: float) -> void:
	_gust = clampf(force, 0.0, 2.0)
	for e in _maple_emitters:
		if e.emitting:
			e.amount_ratio = 1.0

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	_ambient.global_position = cp + Vector3(0, 6.0, 0)
	_dust.global_position = cp + Vector3(0, 0.6, 0)
	if _last_cam.distance_to(cp) > 12.0:
		# téléportation (début de journée, captures) : on remplit tout de suite l'air autour du joueur
		_assign_maples(cp)
		_ambient.restart()
		_dust.restart()
		for e in _maple_emitters:
			if e.emitting:
				e.restart()
	_last_cam = cp
	_gust = maxf(_gust - delta * 0.35, 0.0)
	var boost := smoothstep(0.0, 1.0, _gust)
	for m in _leaf_mats:
		m.set_shader_parameter("gust_boost", boost)
	_ambient.speed_scale = 1.0 + boost * 0.8
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.7
		_assign_maples(cp)

## Place les émetteurs « sous les érables » sur les érables les plus proches du joueur.
func _assign_maples(cp: Vector3) -> void:
	var best: Array = []
	for m in _maples:
		var d := Vector2(m.x - cp.x, m.z - cp.z).length()
		if d < 38.0:
			best.append([d, m])
	best.sort_custom(func(a, b): return a[0] < b[0])
	for i in _maple_emitters.size():
		var e := _maple_emitters[i]
		if i < best.size():
			var m: Vector4 = best[i][1]
			var target := Vector3(m.x, m.y + 3.6 * m.w, m.z)
			if e.global_position.distance_to(target) > 0.5:
				e.global_position = target
			e.emitting = _leaf_level > 0.01
			e.amount_ratio = clampf(_leaf_level, 0.0, 1.0)
		else:
			e.emitting = false


