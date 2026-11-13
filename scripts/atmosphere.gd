class_name Atmosphere
extends Node3D
## Tout ce qui fait « l'air » du lieu : soleil, ciel, brume, étalonnage, vent, particules d'ambiance, lueurs du soir,
## contours à l'écran, et l'habillage toon des props du monde.
## Noeud "Atmosphere" de scenes/world/shrine.tscn (frère de "Sun", "WorldEnvironment", "Props", "Stairs", "Terrain").
## Tout est (re)configuré par code au _ready : l'Environment, le ciel et le soleil de la scène sont remplacés.
##
## API stable (appelée par scripts/game.gd) :
##   set_phase(phase, instant)   phase : 0 = matin, 1 = après-midi, 2 = soir
##   gust(strength)              bourrasque (feuilles qui s'envolent, arbres qui ploient) ; le noeud est dans le groupe
##                               "atmosphere" : get_tree().call_group("atmosphere", "gust", 1.0)
## Le niveau de vent courant : RenderingServer.global_shader_parameter_get("wind_strength").

const AtmoParticles := preload("res://scripts/atmo_particles.gd")
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const FLAME_SHADER := preload("res://shaders/flame.gdshader")
const HALO_SHADER := preload("res://shaders/halo.gdshader")
const SHAFT_SHADER := preload("res://shaders/sun_shafts.gdshader")
const TRANSITION := 7.0

## Réglages par phase. Toutes les valeurs sont interpolées pendant les transitions (soleil compris).
## sun : [élévation°, azimut°] ; azimut 0 = soleil au sud (+Z), 90 = à l'est (+X), -90 = à l'ouest.
const PHASES := [
	{   # matin frais et brumeux : soleil bas à l'est, lumière pâle, ombres bleues, brume dans les creux
		"sun": Vector2(17.0, 68.0), "sun_color": Color(1.0, 0.89, 0.72), "sun_energy": 1.8,
		"amb": Color(0.56, 0.63, 0.78), "amb_e": 0.76,
		"zenith": Color(0.36, 0.56, 0.80), "horizon": Color(0.82, 0.87, 0.90), "haze": Color(0.84, 0.88, 0.93),
		"ground": Color(0.50, 0.55, 0.58), "glow_col": Color(1.0, 0.86, 0.66), "sun_glow": 0.75,
		"cloud_lit": Color(1.0, 0.97, 0.93), "cloud_shade": Color(0.70, 0.76, 0.86), "cloud_cover": 0.42,
		"fog_d": 0.94, "fog_begin": 2.0, "fog_end": 210.0, "fog_curve": 1.1, "fog_h": 0.12, "fog_scatter": 0.15, "fog_aerial": 0.6,
		"vol_d": 0.010, "vol_albedo": Color(0.90, 0.92, 1.0), "vol_aniso": 0.6, "vol_energy": 2.2,
		"ridge_tint": Color(0.88, 0.95, 1.05), "water_sky": Color(0.64, 0.76, 0.86),
		"shadow_tint": Color(0.40, 0.48, 0.80), "exposure": 1.08, "sat": 1.08, "contrast": 1.04,
		"glow": 0.32, "paper": 0.0, "wind": 0.65, "dust": 1.0, "flies": 0.0, "leaves": 0.8,
		"line": Color(0.34, 0.30, 0.40), "shafts": 0.55,
	},
	{   # après-midi doré : lumière chaude et franche, ciel profond, nuages blancs
		"sun": Vector2(30.0, -32.0), "sun_color": Color(1.0, 0.85, 0.64), "sun_energy": 1.85,
		"amb": Color(0.50, 0.57, 0.76), "amb_e": 0.70,
		"zenith": Color(0.26, 0.47, 0.80), "horizon": Color(0.86, 0.84, 0.76), "haze": Color(0.93, 0.85, 0.72),
		"ground": Color(0.45, 0.43, 0.44), "glow_col": Color(1.0, 0.80, 0.52), "sun_glow": 0.8,
		"cloud_lit": Color(1.0, 0.96, 0.88), "cloud_shade": Color(0.72, 0.72, 0.84), "cloud_cover": 0.48,
		"fog_d": 0.85, "fog_begin": 18.0, "fog_end": 380.0, "fog_curve": 1.35, "fog_h": 0.03, "fog_scatter": 0.25, "fog_aerial": 0.55,
		"vol_d": 0.006, "vol_albedo": Color(1.0, 0.94, 0.84), "vol_aniso": 0.6, "vol_energy": 1.2,
		"ridge_tint": Color(1.0, 0.98, 0.95), "water_sky": Color(0.60, 0.74, 0.82),
		"shadow_tint": Color(0.42, 0.42, 0.80), "exposure": 1.0, "sat": 1.08, "contrast": 1.05,
		"glow": 0.38, "paper": 0.0, "wind": 1.0, "dust": 1.0, "flies": 0.0, "leaves": 1.0,
		"line": Color(0.36, 0.26, 0.32), "shafts": 0.25,
	},
	{   # soir violet et orangé : soleil couchant à l'ouest, ciel mauve, brume rose, lanternes et papiers allumés
		"sun": Vector2(5.5, -84.0), "sun_color": Color(1.0, 0.56, 0.30), "sun_energy": 1.7,
		"amb": Color(0.50, 0.44, 0.70), "amb_e": 0.72,
		"zenith": Color(0.20, 0.20, 0.46), "horizon": Color(0.92, 0.58, 0.48), "haze": Color(0.74, 0.56, 0.66),
		"ground": Color(0.30, 0.26, 0.36), "glow_col": Color(1.0, 0.56, 0.30), "sun_glow": 1.0,
		"cloud_lit": Color(1.0, 0.66, 0.48), "cloud_shade": Color(0.46, 0.38, 0.62), "cloud_cover": 0.5,
		"fog_d": 0.9, "fog_begin": 22.0, "fog_end": 320.0, "fog_curve": 1.5, "fog_h": 0.06, "fog_scatter": 0.15, "fog_aerial": 0.5,
		"vol_d": 0.006, "vol_albedo": Color(0.95, 0.75, 0.78), "vol_aniso": 0.6, "vol_energy": 1.5,
		"ridge_tint": Color(0.80, 0.70, 0.92), "water_sky": Color(0.72, 0.52, 0.60),
		"shadow_tint": Color(0.46, 0.38, 0.82), "exposure": 1.02, "sat": 1.1, "contrast": 1.06,
		"glow": 0.5, "paper": 1.0, "wind": 0.7, "dust": 0.4, "flies": 1.0, "leaves": 0.7,
		"line": Color(0.32, 0.24, 0.36), "shafts": 0.45,
	},
	{   # nuit : clair de lune bleu, ciel d'encre, lanternes et papiers allumés, lucioles
		"sun": Vector2(38.0, 150.0), "sun_color": Color(0.62, 0.72, 1.0), "sun_energy": 0.42,
		"amb": Color(0.22, 0.26, 0.46), "amb_e": 0.6,
		"zenith": Color(0.03, 0.05, 0.14), "horizon": Color(0.15, 0.18, 0.33), "haze": Color(0.15, 0.17, 0.29),
		"ground": Color(0.06, 0.06, 0.10), "glow_col": Color(0.76, 0.84, 1.0), "sun_glow": 0.35,
		"cloud_lit": Color(0.42, 0.47, 0.64), "cloud_shade": Color(0.10, 0.11, 0.20), "cloud_cover": 0.35,
		"fog_d": 0.9, "fog_begin": 10.0, "fog_end": 220.0, "fog_curve": 1.3, "fog_h": 0.08, "fog_scatter": 0.05, "fog_aerial": 0.5,
		"vol_d": 0.008, "vol_albedo": Color(0.70, 0.76, 0.96), "vol_aniso": 0.5, "vol_energy": 0.8,
		"ridge_tint": Color(0.35, 0.42, 0.66), "water_sky": Color(0.18, 0.22, 0.38),
		"shadow_tint": Color(0.18, 0.20, 0.46), "exposure": 1.0, "sat": 0.9, "contrast": 1.05,
		"glow": 0.65, "paper": 1.0, "wind": 0.4, "dust": 0.0, "flies": 1.0, "leaves": 0.3,
		"line": Color(0.10, 0.10, 0.18), "shafts": 0.0,
	},
]

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var phase := 1
var particles: AtmoParticles
var outline_quad: MeshInstance3D
var shaft_mat: ShaderMaterial

var _cur: Dictionary = {}        # valeurs appliquées
var _from: Dictionary = {}
var _to: Dictionary = {}
var _k := 1.0                    # avancement de la transition (1 = arrivée)
var _t := 0.0
var _gust := 0.0                 # enveloppe de bourrasque
var _gust_force := 1.0
var _ridges: Array[ShaderMaterial] = []
var _papers: Array = []          # [MeshInstance3D, intensité]
var _wind_noise := FastNoiseLite.new()

func _ready() -> void:
	add_to_group("atmosphere")
	var world := get_parent()
	sun = world.get_node("Sun")
	var we := world.get_node("WorldEnvironment") as WorldEnvironment
	env = we.environment
	# les props posés dans la scène sortent des .glb avec des matériaux standard : on les passe au rendu toon
	for n in ["Props", "Stairs", "LeafPatches"]:
		if world.has_node(n):
			Toon.apply(world.get_node(n))
	_wind_noise.seed = 7
	_wind_noise.frequency = 0.05
	_setup_quality()
	_setup_sky()
	_setup_environment()
	_setup_sun()
	outline_quad = Toon.use_screen_outlines(self)
	_setup_shafts()
	_find_ridges(world)
	_find_papers(world)
	particles = AtmoParticles.new()
	particles.name = "Particles"
	add_child(particles)
	particles.setup(world)
	get_tree().node_added.connect(_on_node_added)
	_cur = PHASES[phase].duplicate()
	_apply(_cur)

# ------------------------------------------------------------------ configuration
func _setup_quality() -> void:
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.use_debanding = true
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.environment_set_volumetric_fog_volume_size(128, 96)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)

func _setup_sky() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.seed = 31
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	sky_mat.set_shader_parameter("cloud_noise", tex)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY

func _setup_environment() -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_sky_affect = 0.0
	env.fog_height = -3.0
	env.fog_height_density = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 72.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_emission = Color.BLACK
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.92
	env.glow_enabled = true
	env.glow_normalized = true
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	env.set_glow_level(5, 0.3)
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.4
	env.ssao_light_affect = 0.0
	env.ssao_ao_channel_affect = 0.0
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0

func _setup_sun() -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.17
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.82
	sun.directional_shadow_pancake_size = 30.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.0
	sun.light_specular = 0.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY

## Rayons de soleil à l'écran (quad plein écran additif).
func _setup_shafts() -> void:
	shaft_mat = ShaderMaterial.new()
	shaft_mat.shader = SHAFT_SHADER
	shaft_mat.render_priority = Material.RENDER_PRIORITY_MAX - 1
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.material = shaft_mat
	var mi := MeshInstance3D.new()
	mi.name = "SunShafts"
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mi)

func _find_ridges(world: Node) -> void:
	if not world.has_node("Terrain"):
		return
	for c in world.get_node("Terrain").get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Ridge"):
			var m := (c as MeshInstance3D).mesh.surface_get_material(0)
			if m is ShaderMaterial:
				_ridges.append(m)

## Papiers éclairés de l'intérieur le soir : lanternes de papier (fortes), shoji des bâtiments (douces).
func _find_papers(world: Node) -> void:
	if not world.has_node("Props"):
		return
	for c in world.get_node("Props").get_children():
		var nm := String(c.name)
		var amount := 0.0
		if nm.begins_with("PaperLantern"):
			amount = 1.5
		elif nm in ["TeaHouse", "Shamusho", "Hut", "Haiden"]:
			amount = 0.9
		if amount <= 0.0:
			continue
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			_papers.append([mi, amount])

## Les flammes des lanternes sont créées par game.gd (sphère unie) : on leur donne un vrai shader de flamme et un halo.
func _on_node_added(n: Node) -> void:
	if n.name == &"Flame" and n is MeshInstance3D:
		_dress_flame.call_deferred(n)

func _dress_flame(n: MeshInstance3D) -> void:
	if not is_instance_valid(n):
		return
	var fm := ShaderMaterial.new()
	fm.shader = FLAME_SHADER
	n.material_override = fm
	var sm := n.mesh as SphereMesh
	if sm:
		var flame := sm.duplicate() as SphereMesh
		flame.radius = 0.045
		flame.height = 0.16
		n.mesh = flame
	var halo := MeshInstance3D.new()
	halo.name = "FlameHalo"
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	halo.mesh = q
	var hm := ShaderMaterial.new()
	hm.shader = HALO_SHADER
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(halo)

# ------------------------------------------------------------------ API
func gust(strength: float = 1.0) -> void:
	_gust = 1.0
	_gust_force = clampf(strength, 0.2, 3.0)
	if particles:
		particles.gust(_gust_force)

func set_phase(p: int, instant: bool) -> void:
	phase = clampi(p, 0, PHASES.size() - 1)
	if instant:
		_k = 1.0
		_cur = PHASES[phase].duplicate()
		_apply(_cur)
		return
	_from = _cur.duplicate()
	_to = PHASES[phase]
	_k = 0.0

# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	_t += delta
	if _k < 1.0:
		_k = minf(_k + delta / TRANSITION, 1.0)
		var e := smoothstep(0.0, 1.0, _k)
		for key in _to:
			_cur[key] = lerp(_from[key], _to[key], e)
		_apply(_cur)
	_update_wind(delta)

func _update_wind(delta: float) -> void:
	_gust = maxf(_gust - delta / 4.5, 0.0)
	var g := sin(_gust * PI * 0.5)   # monte vite, retombe doucement
	g = g * g
	var base: float = _cur.get("wind", 1.0)
	var n := _wind_noise.get_noise_1d(_t)          # -1..1, lent
	var n2 := _wind_noise.get_noise_1d(_t * 3.1 + 100.0)
	var ws := base * (0.85 + 0.3 * n + 0.08 * n2) + g * 1.8 * _gust_force
	var ang := deg_to_rad(21.0 + 14.0 * _wind_noise.get_noise_1d(_t * 0.4 + 50.0))
	var dir := Vector2(cos(ang), sin(ang))
	RenderingServer.global_shader_parameter_set("wind_strength", ws)
	RenderingServer.global_shader_parameter_set("wind_direction", dir)
	if particles:
		particles.set_wind(dir, ws)

func _sun_dir(sv: Vector2) -> Vector3:
	var el := deg_to_rad(sv.x)
	var az := deg_to_rad(sv.y)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))

func _apply(c: Dictionary) -> void:
	# soleil : direction depuis l'élévation et l'azimut (le noeud regarde vers -Z)
	var to_sun := _sun_dir(c["sun"])
	sun.global_basis = Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = c["sun_color"]
	sun.light_energy = c["sun_energy"]
	sun.light_volumetric_fog_energy = c["vol_energy"]
	env.ambient_light_color = c["amb"]
	env.ambient_light_energy = c["amb_e"]
	var haze: Color = c["haze"]
	env.fog_light_color = haze
	env.fog_light_energy = 1.0
	env.fog_density = c["fog_d"]
	env.fog_depth_begin = c["fog_begin"]
	env.fog_depth_end = c["fog_end"]
	env.fog_depth_curve = c["fog_curve"]
	env.fog_height_density = c["fog_h"]
	env.fog_sun_scatter = c["fog_scatter"]
	env.fog_aerial_perspective = c["fog_aerial"]
	env.volumetric_fog_density = c["vol_d"]
	env.volumetric_fog_albedo = c["vol_albedo"]
	env.volumetric_fog_anisotropy = c["vol_aniso"]
	env.tonemap_exposure = c["exposure"]
	env.adjustment_saturation = c["sat"]
	env.adjustment_contrast = c["contrast"]
	env.glow_intensity = c["glow"]
	sky_mat.set_shader_parameter("zenith_color", c["zenith"])
	sky_mat.set_shader_parameter("horizon_color", c["horizon"])
	sky_mat.set_shader_parameter("haze_color", haze)
	sky_mat.set_shader_parameter("ground_color", c["ground"])
	sky_mat.set_shader_parameter("sun_glow_color", c["glow_col"])
	sky_mat.set_shader_parameter("sun_glow", c["sun_glow"])
	sky_mat.set_shader_parameter("cloud_lit", c["cloud_lit"])
	sky_mat.set_shader_parameter("cloud_shade", c["cloud_shade"])
	sky_mat.set_shader_parameter("cloud_cover", c["cloud_cover"])
	for m in _ridges:
		m.set_shader_parameter("haze_color", haze)
		m.set_shader_parameter("phase_tint", c["ridge_tint"])
		m.set_shader_parameter("sun_color", c["sun_color"])
		m.set_shader_parameter("sun_dir", to_sun)
	if shaft_mat:
		shaft_mat.set_shader_parameter("sun_dir", to_sun)
		shaft_mat.set_shader_parameter("shaft_color", c["glow_col"])
		shaft_mat.set_shader_parameter("intensity", c["shafts"])
	var wm := Toon.water_material()
	wm.set_shader_parameter("sky_color", c["water_sky"])
	# teinte de remplissage des ombres propres de tous les matériaux toon (bleue le matin, violette le soir)
	for k in Toon._cache:
		var tm: ShaderMaterial = Toon._cache[k]
		if tm.shader == Toon.TOON_SHADER:
			tm.set_shader_parameter("shadow_tint", c["shadow_tint"])
	if outline_quad:
		(outline_quad.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("line_color", c["line"])
	var paper: float = c["paper"]
	for e in _papers:
		if is_instance_valid(e[0]):
			(e[0] as GeometryInstance3D).set_instance_shader_parameter("glow", paper * e[1])
	if particles:
		particles.set_levels(c["leaves"], c["dust"], c["flies"])
