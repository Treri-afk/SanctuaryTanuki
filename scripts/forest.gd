class_name Forest
extends Node3D
## Forêt de montagne autour du sanctuaire : arbres, bambous, rochers, fougères, feuilles mortes, herbe.
## Les modèles sont placés en MultiMesh (un par pièce de modèle) sur le relief de Terrain, en petites compositions
## (bord de sentier, pied de lanterne, rive, pied d'arbre) plutôt qu'en semis uniforme.
## Construit aussi le masque du sol lu par shaders/ground.gdshader (R litière d'érable, G aiguilles, B mousse,
## A herbe) et l'herbe : touffes et susuki générées par code, en MultiMesh par tuiles (shaders/grass.gdshader).

const M := "res://assets/models/"
const AREA := 120.0
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const MASK_N := 256            # masque du sol : 1 texel = 1 m, de -128 à 128 m
const MASK_O := -128.0
const GRASS_CHUNK := 12.0      # tuiles d'herbe (culling)
const GRASS_FADE_END := 38.0   # au-delà, l'herbe est rentrée dans le sol (le sol porte la même couleur)

# nom du modèle -> [échelle min, échelle max]
const SCALES := {
	"cedar_tree": [0.85, 1.3], "cedar_tree_b": [0.85, 1.25], "pine_tree": [0.85, 1.25],
	"maple_small": [0.9, 1.4], "maple_red": [0.9, 1.3], "bamboo_clump": [0.9, 1.4],
	"stump_mossy": [0.8, 1.3], "rock_a": [0.7, 1.5], "rock_b": [0.7, 1.4], "rock_c": [0.8, 1.6],
	"fern_clump": [0.7, 1.5], "leaf_patch_a": [1.0, 2.2], "leaf_patch_b": [1.0, 2.2], "leaf_patch_c": [1.0, 2.2],
	"fallen_log": [0.8, 1.3],
}

## Arbres de l'enceinte posés par tools/build_world.gd : x, z, érable ?, échelle.
const COURT_TREES := [
	[-20.5, 4.5, true, 1.1], [-19.0, -30.5, true, 1.0], [21.5, 6.0, true, 1.0], [20.0, -20.0, true, 1.1],
	[-12.0, 5.5, true, 0.85], [15.0, -27.0, true, 1.5], [-22.5, -32.0, false, 0.8], [23.0, -34.0, false, 0.75],
]
## Objets posés par tools/build_world.gd hors des allées : x, z, rayon (ni herbe ni décor dessous).
const PROPS := [
	[-2.4, -43.0, 0.7], [2.4, -43.0, 0.7], [-7.0, -52.0, 1.9], [-4.3, -58.5, 0.7], [-10.6, -65.0, 1.4],
	[-9.2, -65.1, 0.5], [-10.4, -63.7, 0.5], [-3.8, -63.0, 0.5], [11.0, -83.0, 0.5], [14.0, -84.0, 1.3],
	[10.2, -86.5, 0.7], [17.8, -86.5, 0.7], [19.5, -82.0, 1.5], [36.0, -6.5, 0.7], [42.0, -10.0, 0.5],
	[49.0, -10.4, 0.7], [63.5, -16.0, 4.2], [62.5, -20.8, 1.6], [58.0, -13.0, 1.3], [57.0, -20.5, 1.7],
	[-33.0, 5.8, 0.7], [-44.0, 4.5, 3.0], [-56.0, 6.0, 0.5], [-59.5, 14.5, 0.45], [-61.0, 15.8, 0.45],
	[-55.8, 11.0, 0.5], [-56.4, 13.0, 0.5], [-58.0, 8.4, 0.45],
	[-66.0, 4.0, 0.9], [-67.5, 7.2, 0.9], [-69.0, 10.4, 0.9], [-70.5, 13.6, 0.9], [-72.0, 16.8, 0.9],
	# enceinte
	[-4.6, 8.0, 0.5], [-12.0, 8.2, 0.5], [-13.4, 8.4, 0.5], [-6.0, 7.0, 0.6], [7.0, 8.7, 0.7], [7.0, -33.0, 0.5],
	[19.7, -30.7, 0.5], [22.0, -30.4, 0.5], [21.0, -32.0, 1.0], [-2.2, 11.2, 0.6], [2.2, 11.2, 0.6],
	[0.0, -35.2, 1.6], [-24.2, 2.0, 1.6], [24.2, -8.0, 1.6], [-21.5, -7.0, 0.7], [-5.0, -31.5, 1.6],
	[21.5, 0.5, 1.2], [-22.0, -22.0, 0.9], [4.5, -30.0, 0.6], [15.0, -27.0, 0.9], [-9.5, -29.0, 0.5],
	[-6.5, -16.5, 0.5], [10.5, -14.0, 1.6], [-16.0, -17.2, 1.2], [-15.0, -20.4, 1.2],
]
const TRAIL_LANTERNS := [[-2.4, -43.0], [2.4, -43.0], [-4.3, -58.5], [36.0, -6.5], [49.0, -10.4], [-33.0, 5.8],
	[10.2, -86.5], [17.8, -86.5]]
## Allées de dalles de l'enceinte (comme dans ground.gdshader).
const SLABS := [
	[-1.8, 3.0, -7.2, 3.0], [1.8, 3.0, 7.2, 3.0], [1.8, -4.0, 13.2, -4.0], [-1.8, -1.0, -14.2, -1.0],
	[-1.8, -10.0, -9.0, -10.0], [1.8, -14.0, 8.5, -14.0], [-1.8, -18.5, -14.0, -18.5], [-12.6, -18.5, -12.6, -21.0],
	[1.8, -19.0, 12.5, -24.0], [0.0, 12.9, 0.0, -17.3],
	[0.8, -29.5, 0.8, -38.0], [-19.5, 1.8, -26.5, 1.8], [19.5, -8.2, 26.5, -8.2],   # chemins vers les portes
]
## Murets de l'enceinte, portes exclues.
const WALLS := [
	[-24.2, 9.2, -2.2, 9.2], [3.8, 9.2, 24.2, 9.2], [-24.2, -35.2, -24.2, 0.8], [-24.2, 2.8, -24.2, 9.2],
	[24.2, -35.2, 24.2, -9.2], [24.2, -7.2, 24.2, 9.2], [-24.2, -35.2, -0.2, -35.2], [1.8, -35.2, 24.2, -35.2],
]

var _rng := RandomNumberGenerator.new()
var _placements: Dictionary = {}   # nom -> Array[Transform3D]
var _collision_trees: Array = []   # [position, rayon]
var _trees: Array = []             # [x, z, genre (0 érable, 1 conifère, 2 souche, 3 bambou), échelle]
var _noise := FastNoiseLite.new()
var _mr := PackedFloat32Array()
var _mg := PackedFloat32Array()
var _mb := PackedFloat32Array()
var _ma := PackedFloat32Array()
var _grass: Dictionary = {}        # Vector2i -> {"tuft": [[Transform3D, Color]], "susuki": [...]}

func _ready() -> void:
	_rng.seed = 424242
	_noise.seed = 77
	_noise.frequency = 0.07
	_noise.fractal_octaves = 2
	_scatter_big()
	_build_mask()
	_scatter_small()
	_apply_mask()
	_scatter_grass()
	_build_multimeshes()
	_build_grass()
	_build_collisions()

func _add(model: String, pos: Vector3, yaw: float, s: float) -> void:
	if not _placements.has(model):
		_placements[model] = []
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), pos)
	_placements[model].append(t)

func _rand_scale(model: String) -> float:
	var r: Array = SCALES.get(model, [1.0, 1.0])
	return _rng.randf_range(r[0], r[1])

func _in_exclusion(x: float, z: float) -> bool:
	if Terrain.keep_clear(x, z):
		return true
	if z > 10.0 and z < 42.0 and absf(x) < 6.0:   # escalier et palier du bas
		return true
	if z > 24.0 and z < 40.0 and absf(x) < 11.0:
		return true
	return false

func _near_prop(x: float, z: float, margin: float = 0.0) -> bool:
	for p in PROPS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var r: float = p[2] + margin
		if dx * dx + dz * dz < r * r:
			return true
	return false

func _pick_big(x: float, z: float, d: float) -> String:
	var r := _rng.randf()
	var near := d < 22.0
	var maple_w := 0.22 if near else 0.12
	var bamboo_w := 0.07 if (x < -16.0 and z > -50.0 and z < 40.0) else 0.0
	var cedar_w := 0.30 if near else 0.42
	var acc := 0.0
	var table := [
		["cedar_tree", cedar_w], ["cedar_tree_b", 0.15], ["pine_tree", 0.09],
		["maple_small", maple_w], ["maple_red", maple_w * 0.8], ["bamboo_clump", bamboo_w],
		["stump_mossy", 0.01],
	]
	for e in table:
		acc += e[1]
		if r < acc:
			return e[0]
	return ""

## Prairie dégagée devant le belvédère : la vue sur la vallée ne doit pas être bouchée par les arbres.
func _view_clear(x: float, z: float) -> bool:
	return x > -3.0 and x < 32.0 and z > -93.0 and z < -53.0

func _in_play_area(x: float, z: float) -> bool:
	return absf(x) < 84.0 and z > -94.0 and z < 16.0

func _scatter_big() -> void:
	var cell := 5.0
	var n := int(AREA * 2.0 / cell)
	for j in n:
		for i in n:
			var x := -AREA + (i + _rng.randf()) * cell
			var z := -AREA + (j + _rng.randf()) * cell
			var d := Terrain.rect_dist(x, z)
			if d < 3.5 or _in_exclusion(x, z) or _view_clear(x, z):
				continue
			if Vector2(x, z).length() > AREA:
				continue
			if d > 45.0 and _rng.randf() < 0.4:   # forêt plus clairsemée au loin (performances)
				continue
			var model := _pick_big(x, z, d)
			if model == "":
				continue
			var s := _rand_scale(model)
			var y := Terrain.height(x, z) - 0.1
			_add(model, Vector3(x, y, z), _rng.randf() * TAU, s)
			var kind := 1
			if model.begins_with("maple"):
				kind = 0
			elif model.begins_with("stump"):
				kind = 2
			elif model.begins_with("bamboo"):
				kind = 3
			_trees.append([x, z, kind, s])
			if _in_play_area(x, z) and (model.begins_with("cedar") or model.begins_with("pine") or model.begins_with("maple") or model.begins_with("stump")):
				_collision_trees.append([Vector3(x, y, z), 0.5 * s])

# ---------------------------------------------------------------- masque du sol

func _stamp(arr: PackedFloat32Array, x: float, z: float, r: float, strength: float) -> void:
	var i0 := maxi(int(floor(x - r - MASK_O)), 0)
	var i1 := mini(int(ceil(x + r - MASK_O)), MASK_N - 1)
	var j0 := maxi(int(floor(z - r - MASK_O)), 0)
	var j1 := mini(int(ceil(z + r - MASK_O)), MASK_N - 1)
	for j in range(j0, j1 + 1):
		var cz := MASK_O + j + 0.5
		for i in range(i0, i1 + 1):
			var cx := MASK_O + i + 0.5
			var d := sqrt((cx - x) * (cx - x) + (cz - z) * (cz - z))
			if d >= r:
				continue
			var v := strength * (1.0 - smoothstep(r * 0.4, r, d))
			var k := j * MASK_N + i
			arr[k] = maxf(arr[k], v)

## Anneau (entre r0 et r1) : herbe au pied des arbres.
func _stamp_ring(arr: PackedFloat32Array, x: float, z: float, r0: float, r1: float, strength: float) -> void:
	var i0 := maxi(int(floor(x - r1 - MASK_O)), 0)
	var i1 := mini(int(ceil(x + r1 - MASK_O)), MASK_N - 1)
	var j0 := maxi(int(floor(z - r1 - MASK_O)), 0)
	var j1 := mini(int(ceil(z + r1 - MASK_O)), MASK_N - 1)
	for j in range(j0, j1 + 1):
		var cz := MASK_O + j + 0.5
		for i in range(i0, i1 + 1):
			var cx := MASK_O + i + 0.5
			var d := sqrt((cx - x) * (cx - x) + (cz - z) * (cz - z))
			if d >= r1:
				continue
			var v := strength * smoothstep(r0 * 0.5, r0, d) * (1.0 - smoothstep(r1 * 0.6, r1, d))
			var k := j * MASK_N + i
			arr[k] = maxf(arr[k], v)

func _mask_at(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x - MASK_O - 0.5, 0.0, MASK_N - 1.001)
	var fz := clampf(z - MASK_O - 0.5, 0.0, MASK_N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var k := j * MASK_N + i
	return lerpf(lerpf(arr[k], arr[k + 1], tx), lerpf(arr[k + MASK_N], arr[k + MASK_N + 1], tx), tz)

func _inside_walls(x: float, z: float) -> bool:
	return absf(x) < 24.2 and z > -35.2 and z < 9.2

func _wall_dist(x: float, z: float) -> float:
	var best := 1e9
	for w in WALLS:
		best = minf(best, Terrain._seg(x, z, w[0], w[1], w[2], w[3]).x)
	return best

func _slab_dist(x: float, z: float) -> float:
	var best := 1e9
	for s in SLABS:
		best = minf(best, Terrain._seg(x, z, s[0], s[1], s[2], s[3]).x)
	return best

## Densité d'herbe (0..1) hors des anneaux au pied des arbres.
func _grass_density(x: float, z: float, conifer: float) -> float:
	if _inside_walls(x, z):
		return 0.0
	if z > 10.0 and z < 40.0 and absf(x) < 3.0:
		return 0.0                                     # escalier
	var d := Terrain.rect_dist(x, z)
	var f := Terrain.field(x, z)
	if f.z < 0.86 or f.y < 0.14:
		return 0.0                                     # roche, eau
	var n := (_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var g := smoothstep(0.5, 0.74, n) * 0.72
	if d <= 0.0:
		g = 0.85                                       # pourtour du plateau, hors des murets
		if z > 9.2 and absf(x - 0.6) < 5.4:
			return 0.0                                 # parvis devant le torii
	var t := f.x
	if t < 4.8:
		g = maxf(g, smoothstep(1.2, 1.8, t) * (1.0 - smoothstep(3.4, 4.8, t)) * (0.8 + 0.2 * n))
	if t < 1.3:
		return 0.0
	if _view_clear(x, z):
		g = maxf(g, 0.62 + 0.38 * n)
	if Terrain.flat_dist(x, z) < 1.5:
		g = maxf(g, 0.75 + 0.2 * n)
	var hut := Vector2(x - 58.0, z + 16.0).length()
	if hut < 6.5:
		g *= smoothstep(4.5, 6.5, hut)                 # cour de terre battue devant la cabane
	if f.y < 1.0:
		g = maxf(g, 0.9 * smoothstep(0.14, 0.32, f.y))  # berges
	if z > 25.0 and z < 39.0 and absf(x) < 8.0:
		g *= smoothstep(5.0, 8.0, absf(x))            # palier du bas
	return g * (1.0 - 0.7 * conifer)

func _build_mask() -> void:
	var n2 := MASK_N * MASK_N
	_mr.resize(n2)
	_mg.resize(n2)
	_mb.resize(n2)
	_ma.resize(n2)
	var rings := PackedFloat32Array()
	rings.resize(n2)
	var all_trees: Array = _trees.duplicate()
	for t in COURT_TREES:
		all_trees.append([t[0], t[1], 0 if t[2] else 1, t[3]])
	for t in all_trees:
		var x: float = t[0]
		var z: float = t[1]
		var s: float = t[3]
		match int(t[2]):
			0:
				_stamp(_mr, x, z, 4.2 * s, 0.95)
				_stamp(_mb, x, z, 1.4 * s, 0.75)
				_stamp_ring(rings, x, z, 1.0 * s, 2.6 * s, 0.85)
			1:
				_stamp(_mg, x, z, 3.4 * s, 0.9)
				_stamp(_mb, x, z, 1.7 * s, 0.8)
			2:
				_stamp(_mb, x, z, 1.6 * s, 0.9)
				_stamp_ring(rings, x, z, 0.9 * s, 2.0 * s, 0.8)
			3:
				_stamp(_mg, x, z, 2.0 * s, 0.5)
				_stamp_ring(rings, x, z, 1.0 * s, 2.0 * s, 0.6)
	for j in MASK_N:
		var z := MASK_O + j + 0.5
		if z < -112.0 or z > 42.0:
			continue
		for i in MASK_N:
			var x := MASK_O + i + 0.5
			if absf(x) > 100.0:
				continue
			var k := j * MASK_N + i
			var g := _grass_density(x, z, _mg[k])
			var ring := rings[k]
			if _inside_walls(x, z):
				ring *= smoothstep(0.6, 1.4, _slab_dist(x, z))   # pas sur les allées
			_ma[k] = maxf(g, ring)

## Pose (ou met à jour) la texture du masque sur le matériau du sol.
func _apply_mask() -> void:
	var bytes := PackedByteArray()
	bytes.resize(MASK_N * MASK_N * 4)
	for k in MASK_N * MASK_N:
		bytes[k * 4] = int(clampf(_mr[k], 0.0, 1.0) * 255.0)
		bytes[k * 4 + 1] = int(clampf(_mg[k], 0.0, 1.0) * 255.0)
		bytes[k * 4 + 2] = int(clampf(_mb[k], 0.0, 1.0) * 255.0)
		bytes[k * 4 + 3] = int(clampf(_ma[k], 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(MASK_N, MASK_N, false, Image.FORMAT_RGBA8, bytes)
	var tex := ImageTexture.create_from_image(img)
	if Terrain.ground_material != null:
		Terrain.ground_material.set_shader_parameter("forest_mask", tex)
		Terrain.ground_material.set_shader_parameter("mask_rect", Vector4(MASK_O, MASK_O, MASK_N, MASK_N))
		Terrain.ground_material.set_shader_parameter("has_mask", true)

# ---------------------------------------------------------------- petit décor (compositions)

## Pose un modèle sur la surface visible du sol, un peu enfoncé.
func _put(model: String, x: float, z: float, s: float, sink: float = 0.05, yaw: float = -1.0) -> void:
	var y := Terrain.mesh_height(x, z) - sink * s
	_add(model, Vector3(x, y, z), _rng.randf() * TAU if yaw < 0.0 else yaw, s)

func _ok_ground(x: float, z: float, trail_margin: float = 1.3) -> bool:
	var f := Terrain.field(x, z)
	return f.x > trail_margin and f.y > 0.12 and not _near_prop(x, z, 0.25)

func _scatter_small() -> void:
	_scatter_precinct()
	_scatter_trail_edges()
	_scatter_lanterns()
	_scatter_stream()
	_scatter_ponds()
	_scatter_forest_floor()

## Enceinte : feuilles sous les érables, fougères et pierres dans la bande de mousse des murets.
func _precinct_blocked(x: float, z: float) -> bool:
	if absf(x) < 2.4 and z > -20.0:
		return true                                              # allée centrale
	if x > 11.0 and x < 24.0 and z > -10.0 and z < 2.0:
		return true                                              # salle de thé
	if x > -23.0 and x < -14.0 and z > -5.0 and z < 3.5:
		return true                                              # bureau
	if Vector2(x - Terrain.ZEN.x, z - Terrain.ZEN.y).length() < 8.5:
		return true                                              # jardin sec
	if Vector2(x - Terrain.PREC_POND.x, z - Terrain.PREC_POND.y).length() < 6.4:
		return true                                              # étang
	if absf(x) < 5.0 and z < -17.0 and z > -27.0:
		return true                                              # pavillon
	return _slab_dist(x, z) < 1.2 or _near_prop(x, z, 0.3)

func _scatter_precinct() -> void:
	for t in COURT_TREES:
		if not t[2]:
			continue
		for k in _rng.randi_range(2, 4):
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(1.2, 3.4) * float(t[3])
			var x: float = t[0] + cos(a) * r
			var z: float = t[1] + sin(a) * r
			if _precinct_blocked(x, z) or not _inside_walls(x, z):
				continue
			var m: String = ["leaf_patch_a", "leaf_patch_b", "leaf_patch_c"][_rng.randi() % 3]
			_add(m, Vector3(x, 0.02, z), _rng.randf() * TAU, _rng.randf_range(0.8, 1.5))
	# touffes de fougères au pied des murets, par petits groupes, avec une pierre de temps en temps
	for w in WALLS:
		var a := Vector2(w[0], w[1])
		var b := Vector2(w[2], w[3])
		var dirv := (b - a).normalized()
		var inward := Vector2(-dirv.y, dirv.x)
		var mid := (a + b) * 0.5
		if inward.dot(Vector2(0.0, -13.0) - mid) < 0.0:
			inward = -inward
		var t := _rng.randf_range(1.0, 4.0)
		var length := a.distance_to(b)
		while t < length - 1.0:
			var base := a + dirv * t
			for k in _rng.randi_range(1, 3):
				var p := base + dirv * _rng.randf_range(-0.8, 0.8) + inward * _rng.randf_range(0.45, 0.9)
				if _precinct_blocked(p.x, p.y):
					continue
				_add("fern_clump", Vector3(p.x, -0.04, p.y), _rng.randf() * TAU, _rng.randf_range(0.7, 1.15))
			if _rng.randf() < 0.45:
				var p2 := base + dirv * _rng.randf_range(-1.0, 1.0) + inward * _rng.randf_range(0.4, 0.7)
				if not _precinct_blocked(p2.x, p2.y):
					_add("rock_a", Vector3(p2.x, -0.05, p2.y), _rng.randf() * TAU, _rng.randf_range(0.3, 0.5))
			t += _rng.randf_range(4.0, 8.0)

## Pierres de bordure le long des sentiers, avec des trous ; plus serrées dans les montées.
func _scatter_trail_edges() -> void:
	for key in Terrain.TRAILS:
		var pts: Array = Terrain.TRAILS[key]
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			var dirv := (b - a) / seg
			var perp := Vector2(-dirv.y, dirv.x)
			var t := _rng.randf_range(0.0, 1.0)
			while t < seg:
				var c := a + dirv * t
				for side in [-1.0, 1.0]:
					if _rng.randf() < 0.4:
						continue
					var p: Vector2 = c + perp * side * _rng.randf_range(1.35, 1.6)
					if Terrain.rect_dist(p.x, p.y) <= 0.0 or not _ok_ground(p.x, p.y, 1.25):
						continue
					if _rng.randf() < 0.7:
						_put("stepping_stone", p.x, p.y, _rng.randf_range(0.55, 0.95), 0.12, atan2(dirv.x, dirv.y) + _rng.randf_range(-0.5, 0.5))
					else:
						_put("rock_a", p.x, p.y, _rng.randf_range(0.28, 0.42), 0.1)
				t += _rng.randf_range(0.9, 2.1)

## Pied de lanterne : fougères derrière, quelques cailloux, feuilles.
func _scatter_lanterns() -> void:
	for l in TRAIL_LANTERNS:
		var L := Vector2(l[0], l[1])
		var tn := Terrain._trail_near(L.x, L.y)
		var away := (L - Vector2(tn.y, tn.z)).normalized()
		var perp := Vector2(-away.y, away.x)
		var spots := [
			["fern_clump", L + away * 0.75 + perp * 0.45, 1.0], ["fern_clump", L + away * 0.55 - perp * 0.75, 0.85],
			["rock_a", L + perp * 0.8 + away * 0.1, 0.38], ["rock_a", L - perp * 0.65 - away * 0.15, 0.3],
			["leaf_patch_b", L + away * 0.2 - perp * 0.2, 0.7],
		]
		for sp in spots:
			var p: Vector2 = sp[1]
			if Terrain.field(p.x, p.y).x < 1.2:
				continue
			_put(sp[0], p.x, p.y, sp[2] * _rng.randf_range(0.9, 1.1), 0.02 if String(sp[0]).begins_with("leaf") else 0.08)

## Ruisseau : pierres dans le lit (qui percent l'eau), sur les lèvres des chutes, fougères et galets sur les berges.
func _scatter_stream() -> void:
	var samples := Terrain.stream_samples()
	var k := 0
	while k < samples.size() - 1:
		var sm: Array = samples[k]
		var p: Vector2 = sm[0]
		var nxt: Vector2 = samples[mini(k + 1, samples.size() - 1)][0]
		var dirv := (nxt - p).normalized()
		var perp := Vector2(-dirv.y, dirv.x)
		var bed: float = sm[2]
		var wd: float = sm[3]
		var near_bridge := p.distance_to(Vector2(-44.0, 4.5)) < 3.2
		if sm[4]:   # chute : pierres de lèvre de part et d'autre, une au pied
			for side in [-1.0, 1.0]:
				var q: Vector2 = p - dirv * 0.4 + perp * side * wd * _rng.randf_range(0.55, 0.85)
				_add("rock_b", Vector3(q.x, bed + 0.05, q.y), _rng.randf() * TAU, _rng.randf_range(0.42, 0.55))
			var q2 := p + dirv * 0.9 + perp * _rng.randf_range(-0.3, 0.3) * wd
			_add("rock_a", Vector3(q2.x, bed - 0.55, q2.y), _rng.randf() * TAU, _rng.randf_range(0.55, 0.75))
			k += 3
			continue
		if not near_bridge and _rng.randf() < 0.4:
			var q3 := p + perp * (1.0 if _rng.randf() < 0.5 else -1.0) * wd * _rng.randf_range(0.15, 0.95)
			var m := "rock_a" if _rng.randf() < 0.75 else "rock_b"
			var s := _rng.randf_range(0.55, 0.9) if m == "rock_a" else _rng.randf_range(0.35, 0.5)
			_add(m, Vector3(q3.x, _bed_floor(q3, bed) - 0.04, q3.y), _rng.randf() * TAU, s)
		for side in [-1.0, 1.0]:
			if near_bridge:
				continue
			var r := _rng.randf()
			if r < 0.3:
				var q4: Vector2 = p + perp * side * (wd + _rng.randf_range(1.1, 2.4))
				if _ok_ground(q4.x, q4.y, 1.8):
					_put("fern_clump", q4.x, q4.y, _rng.randf_range(0.8, 1.3), 0.06)
			elif r < 0.5:
				var q5: Vector2 = p + perp * side * (wd + _rng.randf_range(0.35, 0.7))
				if _ok_ground(q5.x, q5.y, 1.4):
					_put("stepping_stone", q5.x, q5.y, _rng.randf_range(0.5, 0.85), 0.15)
		k += 3

func _bed_floor(q: Vector2, bed: float) -> float:
	return minf(Terrain.mesh_height(q.x, q.y), bed + 0.3)

## Rives des plans d'eau : galets plats sur la ligne d'eau, quelques fougères.
func _scatter_ponds() -> void:
	var ponds := [
		[Vector2(Terrain.PREC_POND.x, Terrain.PREC_POND.y), Terrain.PREC_POND_LEVEL, 7.0, false],
		[Vector2(Terrain.POND.x, Terrain.POND.y), Terrain.mare_level(), 9.0, true],
	]
	for pd in ponds:
		var c: Vector2 = pd[0]
		var level: float = pd[1]
		var n := 34
		for i in n:
			var a := TAU * (i + _rng.randf() * 0.6) / n
			var dir := Vector2(cos(a), sin(a))
			var r := 0.5
			while r < pd[2] and Terrain.mesh_height(c.x + dir.x * r, c.y + dir.y * r) < level:
				r += 0.05
			var roll := _rng.randf()
			if roll < 0.55:
				var q: Vector2 = c + dir * (r + _rng.randf_range(-0.15, 0.35))
				if not _near_prop(q.x, q.y, 0.1):
					_put("stepping_stone", q.x, q.y, _rng.randf_range(0.45, 0.8), 0.25)
			elif roll < 0.68 and pd[3]:
				var q2: Vector2 = c + dir * (r + _rng.randf_range(0.9, 1.8))
				if _ok_ground(q2.x, q2.y, 1.5):
					_put("fern_clump", q2.x, q2.y, _rng.randf_range(0.8, 1.2), 0.05)
	# étang de l'enceinte : fougères entre les rochers de la rive
	for i in 5:
		var a := TAU * i / 5.0 + 0.4 + 0.6
		var q3 := Vector2(-15.0 + cos(a) * 5.7, -27.0 + sin(a) * 5.7)
		if not _near_prop(q3.x, q3.y, 0.2):
			_add("fern_clump", Vector3(q3.x, -0.04, q3.y), _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))

## Sous-bois : groupes de fougères au pied des arbres, rochers moussus en amas, feuilles sous les érables.
func _scatter_forest_floor() -> void:
	for t in _trees:
		var x: float = t[0]
		var z: float = t[1]
		var d := Terrain.rect_dist(x, z)
		if d > 60.0:
			continue
		var kind: int = t[2]
		var r := _rng.randf()
		if r < 0.22:
			for k in _rng.randi_range(2, 5):
				var a := _rng.randf() * TAU
				var rr := _rng.randf_range(0.8, 2.2)
				var px := x + cos(a) * rr
				var pz := z + sin(a) * rr
				if _in_exclusion(px, pz) or not _ok_ground(px, pz, 1.8):
					continue
				_put("fern_clump", px, pz, _rand_scale("fern_clump"), 0.05)
		if kind == 0 and _rng.randf() < 0.45:
			for k in _rng.randi_range(1, 3):
				var a2 := _rng.randf() * TAU
				var rr2 := _rng.randf_range(0.8, 3.0)
				var qx := x + cos(a2) * rr2
				var qz := z + sin(a2) * rr2
				if not _ok_ground(qx, qz, 1.4) or Terrain.rect_dist(qx, qz) <= 0.0:
					continue
				var m: String = ["leaf_patch_a", "leaf_patch_b", "leaf_patch_c"][_rng.randi() % 3]
				_put(m, qx, qz, _rand_scale(m), -0.02)
	# amas de rochers : un gros, quelques petits, une fougère
	var cell := 9.0
	var n := int(200.0 / cell)
	for j in n:
		for i in n:
			if _rng.randf() > 0.42:
				continue
			var x := -100.0 + (i + _rng.randf()) * cell
			var z := -100.0 + (j + _rng.randf()) * cell
			if Terrain.rect_dist(x, z) < 1.5 or _in_exclusion(x, z) or not _ok_ground(x, z, 2.5):
				continue
			var big: String = ["rock_b", "rock_c", "rock_b", "rock_a"][_rng.randi() % 4]
			var s := _rand_scale(big) * 0.8
			_put(big, x, z, s, 0.12)
			if _in_play_area(x, z):
				_collision_trees.append([Vector3(x, Terrain.mesh_height(x, z), z), 0.45 * s * (2.0 if big == "rock_c" else 1.0)])
			_stamp(_mb, x, z, 1.4 * s, 0.85)
			for k in _rng.randi_range(1, 4):
				var a := _rng.randf() * TAU
				var rr := _rng.randf_range(0.7, 1.6) * s
				var px := x + cos(a) * rr
				var pz := z + sin(a) * rr
				if not _ok_ground(px, pz, 1.6):
					continue
				if _rng.randf() < 0.6:
					_put("rock_a", px, pz, _rng.randf_range(0.25, 0.5), 0.12)
				else:
					_put("fern_clump", px, pz, _rand_scale("fern_clump"), 0.05)
			if _rng.randf() < 0.04:
				var a3 := _rng.randf() * TAU
				var lx := x + cos(a3) * 3.0
				var lz := z + sin(a3) * 3.0
				if not _in_exclusion(lx, lz) and _ok_ground(lx, lz, 3.0):
					_put("fallen_log", lx, lz, _rand_scale("fallen_log"), 0.1)

# ---------------------------------------------------------------- herbe

func _grass_add(kind: String, x: float, z: float, yaw: float, s: float, sy: float, custom: Color) -> void:
	var key := Vector2i(int(floor(x / GRASS_CHUNK)), int(floor(z / GRASS_CHUNK)))
	if not _grass.has(key):
		_grass[key] = {"tuft": [], "susuki": []}
	var y := Terrain.mesh_height(x, z) - 0.03
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * sy, s)), Vector3(x, y, z))
	_grass[key][kind].append([t, custom])

func _scatter_grass() -> void:
	var step := 0.42
	var x0 := -88.0
	var z0 := -102.0
	var nx := int(176.0 / step)
	var nz := int(126.0 / step)
	for j in nz:
		for i in nx:
			var x := x0 + (i + _rng.randf()) * step
			var z := z0 + (j + _rng.randf()) * step
			var a := _mask_at(_ma, x, z)
			if a < 0.4:
				continue
			var prob := smoothstep(0.4, 0.82, a)
			if _rng.randf() > prob:
				continue
			if _near_prop(x, z, 0.1):
				continue
			var f := Terrain.field(x, z)
			if f.x < 1.3 or f.y < 0.16 or f.z < 0.84:
				continue
			if _inside_walls(x, z) and _slab_dist(x, z) < 1.3:
				continue
			var n := (_noise.get_noise_2d(x * 1.7, z * 1.7) + 1.0) * 0.5
			var meadow := _view_clear(x, z) and Terrain.flat_dist(x, z) > 1.0
			var tall := minf(1.0 + n * 0.7 + (0.5 if meadow else 0.0) + (0.3 if f.x > 2.6 and f.x < 4.0 else 0.0), 2.1)
			var dry := clampf(n * 0.8 + _rng.randf() * 0.4 + (0.45 if meadow else 0.0), 0.0, 1.0)
			var custom := Color(dry, _rng.randf(), _rng.randf_range(0.4, 1.0), 0.0)
			# susuki : dans la prairie, au bord des sentiers et sur les berges
			var sus_p := 0.0
			if meadow:
				sus_p = 0.035
			elif f.x > 2.2 and f.x < 4.2:
				sus_p = 0.02
			elif f.y < 1.0:
				sus_p = 0.03
			if _rng.randf() < sus_p * smoothstep(0.55, 0.8, n + 0.2):
				_grass_add("susuki", x, z, _rng.randf() * TAU, _rng.randf_range(0.85, 1.2), _rng.randf_range(0.9, 1.15), Color(dry, custom.g, 0.8, 0.0))
				continue
			_grass_add("tuft", x, z, _rng.randf() * TAU, _rng.randf_range(0.8, 1.2), tall * _rng.randf_range(0.85, 1.15), custom)
	# bande d'herbe au pied des murets de l'enceinte (côté intérieur)
	for w in WALLS:
		var a := Vector2(w[0], w[1])
		var b := Vector2(w[2], w[3])
		var dirv := (b - a).normalized()
		var inward := Vector2(-dirv.y, dirv.x)
		if inward.dot(Vector2(0.0, -13.0) - (a + b) * 0.5) < 0.0:
			inward = -inward
		var length := a.distance_to(b)
		var t := 0.2
		while t < length:
			for k in 2:
				var p := a + dirv * (t + _rng.randf_range(-0.2, 0.2)) + inward * _rng.randf_range(0.3, 0.95)
				if _rng.randf() < 0.3 or _near_prop(p.x, p.y, 0.1) or _slab_dist(p.x, p.y) < 1.3:
					continue
				if not _inside_walls(p.x, p.y):
					continue
				var nn := (_noise.get_noise_2d(p.x * 1.7, p.y * 1.7) + 1.0) * 0.5
				_grass_add("tuft", p.x, p.y, _rng.randf() * TAU, _rng.randf_range(0.75, 1.1), 0.8 + nn * 0.6,
					Color(clampf(nn * 0.7 + _rng.randf() * 0.3, 0.0, 1.0), _rng.randf(), _rng.randf_range(0.4, 1.0), 0.0))
			t += 0.36

## Touffe d'herbe : lames effilées et arquées. UV.y = hauteur relative, UV.x = hasard de la lame.
func _blade(st: SurfaceTool, r: RandomNumberGenerator, base: Vector2, h: float, w: float, lean: float, lean_dir: Vector2, face: Vector2, plume: bool, f0: float = 0.0, y0: float = 0.0) -> void:
	var levels := [0.0, 0.3, 0.6, 0.85, 1.0]
	var widths := [1.0, 0.9, 0.65, 0.35, 0.0]
	var rnd := r.randf()
	var col := Color(1.0 if plume else 0.0, 0, 0)
	var first := -1
	var verts: Array = []
	for li in levels.size():
		var f: float = levels[li]
		var off: Vector2 = base + lean_dir * lean * f * f
		var y := y0 + h * f - lean * 0.35 * f * f * f
		var hw: float = w * widths[li]
		var uvy := lerpf(f0, 1.0, f)
		if li < levels.size() - 1:
			verts.append([Vector3(off.x - face.x * hw, y, off.y - face.y * hw), Vector2(rnd, uvy)])
			verts.append([Vector3(off.x + face.x * hw, y, off.y + face.y * hw), Vector2(rnd, uvy)])
		else:
			verts.append([Vector3(off.x, y, off.y), Vector2(rnd, uvy)])
	for v in verts:
		st.set_color(col)
		st.set_uv(v[1])
		st.set_normal(Vector3.UP)
		st.add_vertex(v[0])
	# indices relatifs : quads entre niveaux, triangle à la pointe
	var start: int = st.get_meta("count", 0)
	var nl := levels.size()
	for li in nl - 2:
		var q := start + li * 2
		st.add_index(q)
		st.add_index(q + 1)
		st.add_index(q + 2)
		st.add_index(q + 1)
		st.add_index(q + 3)
		st.add_index(q + 2)
	var last := start + (nl - 2) * 2
	st.add_index(last)
	st.add_index(last + 1)
	st.add_index(last + 2)
	st.set_meta("count", start + verts.size())

func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_meta("count", 0)
	var r := RandomNumberGenerator.new()
	r.seed = 9001
	for b in 11:
		var ang := r.randf() * TAU
		var off := Vector2(cos(ang), sin(ang)) * r.randf_range(0.0, 0.09)
		var lean_dir := Vector2(cos(ang), sin(ang)).rotated(r.randf_range(-0.7, 0.7))
		var face := Vector2(cos(r.randf() * TAU), sin(r.randf() * TAU)).normalized()
		face = Vector2(-lean_dir.y, lean_dir.x).lerp(face, 0.35).normalized()
		var h := r.randf_range(0.16, 0.3)
		_blade(st, r, off, h, r.randf_range(0.016, 0.024), r.randf_range(0.25, 0.75) * h, lean_dir, face, false)
	return st.commit()

func _susuki_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_meta("count", 0)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	# feuilles longues et retombantes
	for b in 14:
		var ang := r.randf() * TAU
		var off := Vector2(cos(ang), sin(ang)) * r.randf_range(0.0, 0.12)
		var lean_dir := Vector2(cos(ang), sin(ang))
		var face := Vector2(-lean_dir.y, lean_dir.x)
		var h := r.randf_range(0.55, 0.85)
		_blade(st, r, off, h, r.randf_range(0.014, 0.02), r.randf_range(0.45, 0.8) * h, lean_dir, face, false)
	# tiges et plumeaux clairs
	for p in 5:
		var ang2 := r.randf() * TAU
		var off2 := Vector2(cos(ang2), sin(ang2)) * r.randf_range(0.0, 0.07)
		var lean_dir2 := Vector2(cos(ang2), sin(ang2))
		var face2 := Vector2(-lean_dir2.y, lean_dir2.x)
		var h2 := r.randf_range(1.05, 1.4)
		var lean2 := r.randf_range(0.06, 0.18)
		_blade(st, r, off2, h2 * 0.78, 0.006, lean2 * 0.6, lean_dir2, face2, false)
		var top := off2 + lean_dir2 * lean2 * 0.6
		var st_y := h2 * 0.78 - lean2 * 0.6 * 0.35
		# plumeau : éventail de brins soyeux qui partent du haut de la tige et retombent (UV.y de 0,8 à 1)
		for k in 7:
			var dir3 := lean_dir2.rotated(r.randf_range(-0.9, 0.9))
			var len3 := r.randf_range(0.16, 0.26)
			_blade(st, r, top + dir3 * 0.01, len3, 0.02, len3 * r.randf_range(0.5, 0.9), dir3, Vector2(-dir3.y, dir3.x), true, 0.8, st_y - 0.03 * k)
	return st.commit()

func _build_grass() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mat.set_shader_parameter("root_color", Terrain.GRASS_GROUND)
	mat.set_shader_parameter("fade_end", GRASS_FADE_END)
	mat.set_shader_parameter("fade_start", GRASS_FADE_END - 14.0)
	var meshes := {"tuft": _tuft_mesh(), "susuki": _susuki_mesh()}
	var holder := Node3D.new()
	holder.name = "Grass"
	add_child(holder)
	var total := 0
	for key in _grass:
		var origin := Vector3((key.x + 0.5) * GRASS_CHUNK, 0.0, (key.y + 0.5) * GRASS_CHUNK)
		for kind in ["tuft", "susuki"]:
			var list: Array = _grass[key][kind]
			if list.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = meshes[kind]
			mm.instance_count = list.size()
			for k in list.size():
				var t: Transform3D = list[k][0]
				t.origin -= origin
				mm.set_instance_transform(k, t)
				mm.set_instance_custom_data(k, list[k][1])
			total += list.size()
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Grass_%s_%d_%d" % [kind, key.x, key.y]
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.position = origin
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = GRASS_FADE_END + GRASS_CHUNK
			holder.add_child(mmi)
	print("FOREST grass instances=", total)

# ---------------------------------------------------------------- modèles

func _local_transform(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _build_multimeshes() -> void:
	for model in _placements.keys():
		var path := M + String(model) + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("Forest : modèle absent " + path)
			continue
		var root: Node = (load(path) as PackedScene).instantiate()
		var xforms: Array = _placements[model]
		var nodes := root.find_children("*", "MeshInstance3D", true, false)
		for mi in nodes:
			var local := _local_transform(mi, root)
			var mesh: Mesh = (mi as MeshInstance3D).mesh.duplicate()
			for s in mesh.get_surface_count():
				var tm := Toon.surface_material(mesh, s, Toon.kind_of(String(mi.name), String(model)))
				if tm != null:
					mesh.surface_set_material(s, tm)
			var small := String(model).begins_with("fern") or String(model).begins_with("leaf_patch") or String(model) == "stepping_stone"
			# petit décor : tuiles de 24 m (la distance d'affichage se mesure depuis le centre de chaque tuile)
			var groups := {}
			for k in xforms.size():
				var t: Transform3D = xforms[k]
				var key := Vector2i(int(floor(t.origin.x / 24.0)), int(floor(t.origin.z / 24.0))) if small else Vector2i.ZERO
				if not groups.has(key):
					groups[key] = []
				groups[key].append(t)
			for key in groups:
				var list: Array = groups[key]
				var origin := Vector3((key.x + 0.5) * 24.0, 0.0, (key.y + 0.5) * 24.0) if small else Vector3.ZERO
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = list.size()
				for k in list.size():
					var t2: Transform3D = list[k] * local
					t2.origin -= origin
					mm.set_instance_transform(k, t2)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "%s_%s_%d_%d" % [model, mi.name, key.x, key.y]
				mmi.multimesh = mm
				mmi.position = origin
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mmi.visibility_range_end = 62.0 if small else 0.0
				add_child(mmi)
		root.free()

func _build_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "TreeCollisions"
	add_child(body)
	for e in _collision_trees:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = e[1]
		sh.height = 6.0
		cs.shape = sh
		cs.position = e[0] + Vector3(0, 3.0, 0)
		body.add_child(cs)
