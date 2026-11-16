extends Node
## Autoload « Settings » : réglages du joueur, enregistrés dans user://settings.cfg et appliqués au lancement.
##
##   Settings.get_value("cle") / Settings.set_value("cle", valeur)   (enregistre et applique aussitôt)
##   Settings.apply_graphics(viewport, atmosphere)                   (appelé par le jeu quand le monde est prêt)
##
## Son : trois bus, « Master », « Ambiance » (scripts/ambience.gd) et « Effets » (autoload/sfx.gd, cloche...).
## Graphismes : préréglages de qualité (basse / moyenne / haute) + résolution 3D (mise à l'échelle FSR).
## « Moyenne » correspond aux réglages mesurés avec `-- --perf` ; les modes de test gardent toujours ces défauts.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"volume_master": 0.85,
	"volume_ambience": 0.8,
	"volume_effects": 0.9,
	"mouse_sensitivity": 1.0,      # multiplicateur de la sensibilité de base du joueur
	"head_bob": 1.0,               # balancement de tête (0 = aucun)
	"quality": 1,                  # 0 basse, 1 moyenne, 2 haute
	"render_scale": 1.0,           # résolution 3D (0,5 à 1)
	"fullscreen": false,
	"vsync": true,
}
const QUALITY_NAMES := ["Basse", "Moyenne", "Haute"]

var _values: Dictionary = DEFAULTS.duplicate()
var _viewport: Viewport
var _atmo: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_old_data()
	for bus in ["Ambiance", "Effets"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			_values[k] = cfg.get_value("reglages", k, DEFAULTS[k])
	_apply_audio()
	if not testing():
		_apply_window()

## Le jeu s'appelait « Gardien de sanctuaire » : ses données (réglages, sauvegardes) étaient rangées par Godot
## dans app_userdata/Gardien de sanctuaire. Le projet a maintenant son propre dossier, fixe (TanukiSanctuary,
## voir project.godot), qui ne dépend plus du nom affiché. Au premier lancement, on y recopie les anciennes
## données ; l'ancien dossier n'est pas touché.
static func _migrate_old_data() -> void:
	if FileAccess.file_exists(PATH) or DirAccess.dir_exists_absolute("user://saves"):
		return
	var old := OS.get_data_dir().path_join("Godot/app_userdata/Gardien de sanctuaire")
	if not DirAccess.dir_exists_absolute(old):
		return
	if FileAccess.file_exists(old.path_join("settings.cfg")):
		DirAccess.copy_absolute(old.path_join("settings.cfg"), ProjectSettings.globalize_path(PATH))
	var saves := old.path_join("saves")
	if DirAccess.dir_exists_absolute(saves):
		DirAccess.make_dir_recursive_absolute("user://saves")
		for f in DirAccess.get_files_at(saves):
			if f.ends_with(".save"):
				DirAccess.copy_absolute(saves.path_join(f), ProjectSettings.globalize_path("user://saves/" + f))
	print("Données de « Gardien de sanctuaire » reprises dans ", OS.get_user_data_dir())

## Lancement en mode test (--shot, --autoplay, --perf...) : réglages par défaut, rien n'est écrit.
static func testing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			return true
	return false

func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	var cfg := ConfigFile.new()
	for k in _values:
		cfg.set_value("reglages", k, _values[k])
	cfg.save(PATH)
	match key:
		"volume_master", "volume_ambience", "volume_effects":
			_apply_audio()
		"fullscreen", "vsync":
			_apply_window()
		"quality", "render_scale":
			if _viewport and _atmo:
				apply_graphics(_viewport, _atmo)
	changed.emit(key)

func _apply_audio() -> void:
	for pair in [["Master", "volume_master"], ["Ambiance", "volume_ambience"], ["Effets", "volume_effects"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			var v: float = clampf(float(get_value(pair[1])), 0.0, 1.0)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(i, v <= 0.001)

func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if get_value("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)

## Qualité graphique : ombres, brouillard volumétrique, SSAO, anticrénelage, résolution 3D.
func apply_graphics(vp: Viewport, atmo: Node) -> void:
	_viewport = vp
	_atmo = atmo
	if testing():
		return
	var q := int(get_value("quality"))
	var env: Environment = atmo.get("env")
	var sun: DirectionalLight3D = atmo.get("sun")
	match q:
		0:      # basse : une seule cascade courte, pas de brouillard volumétrique ni de SSAO
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 40.0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			env.volumetric_fog_enabled = false
			env.ssao_enabled = false
		1:      # moyenne : réglages par défaut du jeu
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 65.0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.environment_set_volumetric_fog_volume_size(64, 48)
			env.volumetric_fog_enabled = true
			env.ssao_enabled = true
		_:      # haute : quatre cascades sur 95 m, ombres douces, brouillard fin
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 95.0
			sun.directional_shadow_split_1 = 0.06
			sun.directional_shadow_split_2 = 0.17
			sun.directional_shadow_split_3 = 0.42
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.environment_set_volumetric_fog_volume_size(128, 96)
			env.volumetric_fog_enabled = true
			env.ssao_enabled = true
	if q == 1:
		sun.directional_shadow_split_1 = 0.22
	var rs := clampf(float(get_value("render_scale")), 0.5, 1.0)
	vp.scaling_3d_scale = rs
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if rs < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
