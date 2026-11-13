class_name Toon
extends RefCounted
## Point d'entrée unique des matériaux du jeu. Tout le code (forêt, terrain, props, main du joueur)
## passe par ici : pour changer le rendu, on ne modifie que ce fichier et les shaders.
## Ne doit dépendre d'aucun autoload (utilisé aussi par les scripts d'outils lancés avec --script).
##
## API stable :
##   Toon.kind_of(nom_du_mesh, nom_du_modele) -> &"hard" | &"foliage" | &"small" | &"water"
##   Toon.material(couleur, kind)            -> matériau partagé (mis en cache)
##   Toon.water_material()                   -> matériau des plans d'eau (ruisseau, mare, étang, bassin)
##   Toon.surface_material(mesh, i, kind)    -> matériau pour la surface i d'un mesh importé (gère la teinte de sommet)
##   Toon.apply(racine)                      -> remplace les StandardMaterial3D importés des .glb
##   Toon.make_material(couleur, épaisseur)  -> ancien nom, conservé pour compatibilité
## Contours :
##   Par défaut chaque matériau porte un contour « inverted hull » (next_pass). En jeu, Atmosphere appelle
##   Toon.use_screen_outlines(racine) : les contours sont alors dessinés à l'écran par un seul quad
##   (shaders/screen_outline.gdshader), plus fins, réguliers et teintés, et les hulls sont retirés.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const SCREEN_OUTLINE_SHADER := preload("res://shaders/screen_outline.gdshader")
const WATER_COLOR := Color("#5F8FA8")

static var _cache: Dictionary = {}
static var screen_outlines := false

## Catégorie de rendu d'un mesh, d'après son nom et celui de son modèle.
static func kind_of(mesh_name: String, model: String = "") -> StringName:
	var n := mesh_name.to_lower()
	var m := model.to_lower()
	# « water_basin » (la vasque de pierre) n'est pas de l'eau : seulement « water », « water_surface », etc.
	if n.contains("water") and not n.contains("basin"):
		return &"water"
	# feuilles mortes posées au sol : elles ne bougent pas au vent
	if m.begins_with("leaf_patch") or m.begins_with("leaf_pile") or n.begins_with("leaf_patch") or n.begins_with("leaf_pile"):
		return &"small"
	if n.contains("foliage") or n.contains("leaves") or n.contains("blades"):
		return &"foliage"
	if m.begins_with("fern") or n.contains("moss"):
		return &"small"
	return &"hard"

## tinted : le mesh porte une couleur de sommet "Col" (occlusion calculée à l'export Blender) à multiplier à l'albedo.
static func material(color: Color, kind: StringName = &"hard", tinted: bool = false) -> ShaderMaterial:
	if kind == &"water":
		return water_material()
	var key := "%s_%s_%s" % [color.to_html(), kind, tinted]
	if _cache.has(key):
		return _cache[key]
	var thick := 0.014
	if kind == &"foliage":
		thick = 0.011
	elif kind == &"small":
		thick = 0.0
	var m := _new_material(color, thick, tinted)
	if kind == &"foliage":
		m.set_shader_parameter("wind_sway", 1.0)
		m.set_shader_parameter("color_jitter", 1.0)
		m.set_shader_parameter("translucency", 0.22)
		m.set_shader_parameter("rim_strength", 0.35)
		if m.next_pass:
			(m.next_pass as ShaderMaterial).set_shader_parameter("wind_sway", 1.0)
	elif kind == &"small":
		m.set_shader_parameter("rim_strength", 0.15)
	_cache[key] = m
	return m

## Matériau de la surface `surface` d'un mesh importé d'un .glb, ou null si ce n'est pas un StandardMaterial3D.
static func surface_material(mesh: Mesh, surface: int, kind: StringName, src: Material = null) -> ShaderMaterial:
	if src == null:
		src = mesh.surface_get_material(surface)
	if not (src is StandardMaterial3D):
		return null
	var tinted := mesh is ArrayMesh and ((mesh as ArrayMesh).surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0
	return material((src as StandardMaterial3D).albedo_color, kind, tinted)

static func make_material(color: Color, outline_thickness: float = 0.014, tinted: bool = false) -> ShaderMaterial:
	var key := "%s_%s_%s" % [color.to_html(), outline_thickness, tinted]
	if _cache.has(key):
		return _cache[key]
	var m := _new_material(color, outline_thickness, tinted)
	_cache[key] = m
	return m

static func _new_material(color: Color, outline_thickness: float, tinted: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vertex_tint", tinted)
	m.set_shader_parameter("rim_strength", 0.3)
	if outline_thickness > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("thickness", outline_thickness)
		m.set_meta("outline", o)
		if not screen_outlines:
			m.next_pass = o
	return m

static func water_material() -> ShaderMaterial:
	if _cache.has("water"):
		return _cache["water"]
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	_cache["water"] = m
	return m

## Remplace les matériaux importés (une couleur unie par matériau) de tous les meshes sous `root`.
static func apply(root: Node, model: String = "") -> void:
	var nodes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for n in nodes:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var kind := kind_of(String(mi.name), model)
		for s in mi.mesh.get_surface_count():
			var m := surface_material(mi.mesh, s, kind, mi.get_active_material(s))
			if m != null:
				mi.set_surface_override_material(s, m)

## Passe aux contours dessinés à l'écran : retire les hulls des matériaux existants et ajoute le quad sous `parent`.
static func use_screen_outlines(parent: Node) -> MeshInstance3D:
	screen_outlines = true
	for k in _cache:
		var m: ShaderMaterial = _cache[k]
		if m.next_pass != null and m.next_pass.shader == OUTLINE_SHADER:
			m.next_pass = null
	var q := make_screen_outline()
	parent.add_child(q)
	return q

## Quad plein écran des contours (à ajouter n'importe où dans la scène 3D).
static func make_screen_outline() -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SCREEN_OUTLINE_SHADER
	mat.render_priority = Material.RENDER_PRIORITY_MAX
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "ScreenOutline"
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	return mi
