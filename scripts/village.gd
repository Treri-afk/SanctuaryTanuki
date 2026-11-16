class_name Village
extends Node3D
## Le village de la vallée, très loin au sud (d'où montent les visiteurs). Décor lointain, comme les crêtes de
## terrain.gd : on l'aperçoit du haut de l'escalier et du palier, à ~450 m, au bout d'une longue vallée boisée, à
## travers la brume ; on n'y va pas. Tout est généré par code, en peu de maillages :
##   - le fond de la vallée : forêt (arbres simples) qui descend vers le village, rizières dorées autour ;
##   - les maisons (minka, fermes au toit de chaume, machiya à étage, kura blancs), un temple et sa pagode ;
##   - les lumières : fenêtres qui s'allument le soir (puis s'allument et s'éteignent une à une), lanternes de rue.
## Les crêtes lointaines s'abaissent au sud pour laisser voir la vallée (Terrain._build_ridges).
## Couleurs et brume suivent la phase du jour : Atmosphere appelle apply_atmo() (comme pour les crêtes).

const Z_MIN := 149.0             # le sol de la vallée commence au bord du maillage de la montagne (Terrain.HALF)
const Z_MAX := 505.0
const FAR_R := 525.0             # dernière crête (530 m) : au-delà, rien n'est visible
const CENTER := Vector2(0.0, 450.0)
const PLAIN_Z := 235.0           # pied des collines : au-delà, la plaine de rizières jusqu'au village
const SHADER := preload("res://shaders/village.gdshader")
const LIGHT_SHADER := preload("res://shaders/village_lights.gdshader")

## Rues (x, z) : la grand-rue remonte la vallée, les autres la croisent.
const STREETS := [
	[[-3, 412], [4, 426], [-1, 442], [5, 458], [1, 474], [6, 490]],
	[[-78, 449], [-45, 445], [-15, 446], [0, 444], [30, 448], [72, 453]],
	[[-42, 428], [-15, 426], [2, 428], [30, 430], [56, 425]],
	[[-34, 471], [0, 473], [36, 477]],
]
const TEMPLE := Vector2(-64.0, 474.0)
const PAGODA := Vector2(-47.0, 467.0)

## Maisons : [largeur, profondeur, hauteur des murs, montée du toit, débord, couleur des murs, couleur du toit,
## fenêtres par étage, étages éclairés]
const KINDS := {
	"minka": [8.0, 5.5, 2.8, 2.2, 0.7, Color(0.86, 0.80, 0.68), Color(0.27, 0.29, 0.34), 2, 1],
	"ferme": [10.5, 6.5, 2.4, 3.8, 0.8, Color(0.54, 0.42, 0.30), Color(0.50, 0.40, 0.26), 1, 1],
	"machiya": [6.5, 9.0, 5.2, 1.6, 0.6, Color(0.38, 0.28, 0.21), Color(0.25, 0.27, 0.31), 2, 2],
	"kura": [5.0, 4.2, 4.0, 1.5, 0.5, Color(0.93, 0.92, 0.88), Color(0.22, 0.23, 0.27), 0, 0],
}

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _light_mat: ShaderMaterial
var _houses: Array = []          # [variante, Transform3D]
var _lights: Array = []          # [Transform3D, graine, genre]
var _trees: Array = []           # [variante, Transform3D]

func _ready() -> void:
	_rng.seed = 1867
	_noise.seed = 5
	_noise.frequency = 0.012
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = SHADER
	_ground_mat.set_shader_parameter("instanced", false)
	_ground_mat.set_shader_parameter("ground", true)
	_light_mat = ShaderMaterial.new()
	_light_mat.shader = LIGHT_SHADER
	_build_ground()
	_layout()
	_build_houses()
	_build_trees()
	_build_lights()

## Couleurs, soleil et brume de la phase (appelé par Atmosphere._apply, transitions comprises).
func apply_atmo(c: Dictionary, to_sun: Vector3) -> void:
	for m in [_mat, _ground_mat]:
		m.set_shader_parameter("haze_color", c["haze"])
		m.set_shader_parameter("phase_tint", c["ridge_tint"])
		m.set_shader_parameter("sun_color", c["sun_color"])
		m.set_shader_parameter("sun_dir", to_sun)
		m.set_shader_parameter("fog_end", c["fog_end"])
		m.set_shader_parameter("night", c.get("moon", 0.0))
	var paper: float = c.get("paper", 0.0)
	var moon: float = c.get("moon", 0.0)
	_light_mat.set_shader_parameter("windows_on", paper * (0.82 - 0.4 * moon))
	_light_mat.set_shader_parameter("lanterns_on", paper)

# ------------------------------------------------------------------ fond de vallée

## Hauteur du sol de la vallée : elle descend du pied de la montagne (Terrain.VALLEY_FLOOR) jusqu'au village,
## avec des flancs qui remontent de part et d'autre.
func floor_y(x: float, z: float) -> float:
	var t := clampf((z - Z_MIN) / (PLAIN_Z - Z_MIN), 0.0, 1.0)
	var base := Terrain.VALLEY_FLOOR - 44.0 * (1.0 - (1.0 - t) * (1.0 - t)) + 2.0 * smoothstep(PLAIN_Z, 480.0, z)
	var half := 45.0 + 0.3 * (z - Z_MIN)
	var side := 0.35 * maxf(absf(x) - half, 0.0)
	var bumps := _noise.get_noise_2d(x, z) * 5.0 * smoothstep(Z_MIN, Z_MIN + 25.0, z) * smoothstep(1.2, 2.2, _core_dist(x, z))
	return base + side + bumps

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 8.0
	var xs := []
	var x := -400.0
	while x <= 400.0:
		xs.append(x)
		x += step
	var zs := []
	var z := Z_MIN
	while z <= Z_MAX:
		zs.append(z)
		z += step
	var earth := Color(0.47, 0.41, 0.33).srgb_to_linear()
	var woods := Color(0.24, 0.26, 0.17).srgb_to_linear()
	var grid := []
	for zz in zs:
		var row := []
		for xx in xs:
			var cd := _core_dist(xx, zz)
			var plain := smoothstep(PLAIN_Z - 20.0, PLAIN_Z + 5.0, zz) * (1.0 - smoothstep(60.0, 150.0, absf(xx)))
			var paddy := smoothstep(4.0, 9.0, _street_dist(xx, zz)) * smoothstep(0.0, 1.0, cd) * maxf(plain, 1.0 - smoothstep(1.9, 2.3, cd))
			var col := earth.lerp(woods, smoothstep(1.4, 2.2, cd) * (1.0 - plain))
			row.append([Vector3(xx, floor_y(xx, zz), zz), Color(col.r, col.g, col.b, paddy)])
		grid.append(row)
	for j in zs.size() - 1:
		for i in xs.size() - 1:
			var a: Array = grid[j][i]
			var b: Array = grid[j][i + 1]
			var c: Array = grid[j + 1][i + 1]
			var d: Array = grid[j + 1][i]
			if Vector2(a[0].x, a[0].z).length() > FAR_R and Vector2(c[0].x, c[0].z).length() > FAR_R:
				continue
			for v in [a, b, c, a, c, d]:
				st.set_color(v[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "ValleyFloor"
	mi.mesh = st.commit()
	mi.material_override = _ground_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Distance à la rue la plus proche.
func _street_dist(x: float, z: float) -> float:
	var best := 1e9
	for s in STREETS:
		for i in s.size() - 1:
			var a := Vector2(s[i][0], s[i][1])
			var b := Vector2(s[i + 1][0], s[i + 1][1])
			best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z)))
	return best

## > 1 hors du cœur du village (ellipse autour des rues principales).
func _core_dist(x: float, z: float) -> float:
	return Vector2((x - CENTER.x) / 62.0, (z - CENTER.y) / 36.0).length()

# ------------------------------------------------------------------ plan du village

func _layout() -> void:
	# maisons le long des rues
	for si in STREETS.size():
		var s: Array = STREETS[si]
		for i in s.size() - 1:
			var a := Vector2(s[i][0], s[i][1])
			var b := Vector2(s[i + 1][0], s[i + 1][1])
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var t := _rng.randf_range(2.0, 6.0)
			while t < a.distance_to(b):
				for sg in [-1.0, 1.0]:
					if _rng.randf() < 0.14:
						continue
					var kind := _street_kind(si)
					var k: Array = KINDS[kind]
					var off: float = 3.6 + float(k[1]) * 0.5 + _rng.randf_range(0.0, 1.0)
					var p: Vector2 = a + dir * t + side * sg * off
					_try_house(kind, p, atan2(-dir.y, dir.x) + _rng.randf_range(-0.06, 0.06))
				t += _rng.randf_range(8.5, 11.0)
	# fermes dans les rizières autour du village, avec leur kura et quelques arbres
	for n in 40:
		var c := CENTER + Vector2(_rng.randf_range(-130.0, 130.0), _rng.randf_range(-70.0, 50.0))
		var cd := _core_dist(c.x, c.y)
		if cd < 1.05 or cd > 2.1:
			continue
		var yaw := _rng.randf_range(-0.5, 0.5) + (PI * 0.5 if _rng.randf() < 0.3 else 0.0)
		if _try_house("ferme", c, yaw):
			if _rng.randf() < 0.5:
				_try_house("kura", c + Vector2(_rng.randf_range(6.0, 9.0), _rng.randf_range(-6.0, 6.0)), yaw)
			for m in _rng.randi_range(2, 4):
				var tp := c + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(7.0, 11.0)
				_add_tree(tp, ["leaf_vert", "leaf_orange", "leaf_rouge", "cedre"][_rng.randi() % 4])
	# temple et pagode, dans un bois de cèdres
	_houses.append(["temple", _xf(TEMPLE, deg_to_rad(8.0), 1.0)])
	_houses.append(["pagode", _xf(PAGODA, deg_to_rad(8.0), 1.0)])
	_lights.append([_xf(TEMPLE + Vector2(2.0, -10.0), 0.0, 3.4, 2.2), _rng.randf(), 1.0])
	_lights.append([_xf(TEMPLE + Vector2(-2.0, -10.0), 0.0, 3.4, 2.2), _rng.randf(), 1.0])
	for n in 26:
		var tp := TEMPLE + Vector2(_rng.randf_range(-24.0, 22.0), _rng.randf_range(4.0, 20.0))
		if tp.distance_to(PAGODA) > 7.0 and tp.distance_to(TEMPLE) > 10.0:
			_add_tree(tp, "cedre" if _rng.randf() < 0.75 else "leaf_rouge")
	# la longue vallée boisée entre la montagne et le village
	for n in 5200:
		var p := Vector2(_rng.randf_range(-260.0, 260.0), _rng.randf_range(Z_MIN, Z_MAX))
		if absf(p.x) > 60.0 + 0.55 * (p.y - Z_MIN) or p.length() > FAR_R:
			continue
		# forêt dense sur les collines du pied de la montagne (le sol y tombe sous la ligne de vue) ; dans la plaine,
		# seulement quelques bosquets, sinon ils cacheraient le village
		var cd := _core_dist(p.x, p.y)
		var plain := smoothstep(PLAIN_Z - 25.0, PLAIN_Z, p.y) * (1.0 - smoothstep(55.0, 140.0, absf(p.x)))
		if cd < 1.15 or _rng.randf() < plain * 0.95 or _street_dist(p.x, p.y) < 5.0:
			continue
		var r := _rng.randf()
		if p.y < PLAIN_Z:   # au pied de la montagne, encore assez près : des cèdres seulement (les boules se voient)
			r = 0.0
		_add_tree(p, "cedre" if r < 0.55 else ("leaf_vert" if r < 0.7 else ("leaf_orange" if r < 0.88 else "leaf_rouge")))
	# lanternes de rue (grand-rue et rue principale)
	for si in [0, 1]:
		var s: Array = STREETS[si]
		for i in s.size() - 1:
			var a := Vector2(s[i][0], s[i][1])
			var b := Vector2(s[i + 1][0], s[i + 1][1])
			var dir := (b - a).normalized()
			var t := 3.0
			while t < a.distance_to(b):
				var p := a + dir * t + Vector2(-dir.y, dir.x) * (2.6 if int(t) % 2 == 0 else -2.6)
				_lights.append([_xf(p, 0.0, 3.4, 2.4), _rng.randf(), 1.0])
				t += 13.0

func _street_kind(si: int) -> String:
	var r := _rng.randf()
	if si == 0:
		return "machiya" if r < 0.55 else ("minka" if r < 0.9 else "kura")
	return "minka" if r < 0.6 else ("machiya" if r < 0.75 else ("kura" if r < 0.88 else "ferme"))

## Ajoute une maison si elle ne chevauche ni une autre ni une rue ; ajoute ses fenêtres.
func _try_house(kind: String, p: Vector2, yaw: float) -> bool:
	var k: Array = KINDS[kind]
	var r: float = Vector2(float(k[0]), float(k[1])).length() * 0.5
	if p.length() > FAR_R - 6.0 or p.y < Z_MIN + 3.0:
		return false
	if _street_dist(p.x, p.y) < r * 0.55 + 1.5:
		return false
	if p.distance_to(TEMPLE) < 16.0 or p.distance_to(PAGODA) < 9.0:
		return false
	for h in _houses:
		var o: Vector3 = (h[1] as Transform3D).origin
		if Vector2(o.x, o.z).distance_to(p) < r + 4.0:
			return false
	var xf := _xf(p, yaw, 1.0)
	_houses.append([kind, xf])
	# fenêtres sur la façade longue tournée vers la montagne (vers -Z : c'est de là qu'on les regarde)
	var front := xf.basis.z if xf.basis.z.z < 0.0 else -xf.basis.z
	var along := xf.basis.x
	var w: float = k[0]
	var d: float = k[1]
	for floor_i in int(k[8]):
		for wi in int(k[7]):
			var u := (float(wi) + 0.5) / float(k[7]) - 0.5
			var pos := xf.origin + along * u * (w - 2.0) + front * (d * 0.5 + 0.12) + Vector3.UP * (1.3 + 2.5 * floor_i)
			var lb := Basis.looking_at(-front, Vector3.UP).scaled(Vector3.ONE * 3.4)
			_lights.append([Transform3D(lb, pos), _rng.randf(), 0.0])
	return true

func _xf(p: Vector2, yaw: float, s: float, dy := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, floor_y(p.x, p.y) + dy, p.y))

func _add_tree(p: Vector2, kind: String) -> void:
	if p.length() > FAR_R or p.y < Z_MIN:
		return
	var s := _rng.randf_range(0.8, 1.3)
	if blocks_view(p.x, p.y, floor_y(p.x, p.y) + (11.0 if kind == "cedre" else 4.0) * s):
		return
	_trees.append([kind, _xf(p, _rng.randf() * TAU, s, -0.3)])

## Vrai si un sommet à la hauteur `top` en (x, z) cacherait le village, vu du haut de l'escalier ou du palier.
static func blocks_view(x: float, z: float, top: float) -> bool:
	if absf(x) > 22.0 + 0.25 * maxf(z - 38.0, 0.0):
		return false
	var aim := Vector2(415.0, Terrain.VALLEY_FLOOR - 42.0)
	for eye in [Vector2(11.0, 1.6), Vector2(38.5, -4.2)]:
		if z > eye.x:
			var sight: float = eye.y + (aim.y - eye.y) * (z - eye.x) / (aim.x - eye.x)
			if top > sight - 1.5:
				return true
	return false

# ------------------------------------------------------------------ maillages

func _build_houses() -> void:
	var meshes := {}
	for kind in KINDS:
		var k: Array = KINDS[kind]
		meshes[kind] = _house_mesh(k[0], k[1], k[2], k[3], k[4], k[5], k[6])
	meshes["temple"] = _temple_mesh()
	meshes["pagode"] = _pagoda_mesh()
	_multimesh("Houses", meshes, _houses, _mat)

func _build_trees() -> void:
	var meshes := {
		"cedre": _cone_mesh(2.6, 11.0, Color(0.17, 0.26, 0.17)),
		"leaf_vert": _blob_mesh(2.2, 3.0, Color(0.30, 0.38, 0.18)),
		"leaf_orange": _blob_mesh(2.1, 2.9, Color(0.80, 0.45, 0.14)),
		"leaf_rouge": _blob_mesh(2.0, 2.8, Color(0.70, 0.20, 0.12)),
	}
	_multimesh("Trees", meshes, _trees, _mat)

func _build_lights() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = _lights.size()
	for i in _lights.size():
		mm.set_instance_transform(i, _lights[i][0])
		mm.set_instance_custom_data(i, Color(_lights[i][1], _lights[i][2], 0.0, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Lights"
	mi.multimesh = mm
	mi.material_override = _light_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Un MultiMesh par variante (graine de couleur dans INSTANCE_CUSTOM.r).
func _multimesh(node_name: String, meshes: Dictionary, items: Array, mat: Material) -> void:
	var group := Node3D.new()
	group.name = node_name
	add_child(group)
	for kind in meshes:
		var xfs: Array = []
		for it in items:
			if it[0] == kind:
				xfs.append(it[1])
		if xfs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[kind]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_custom_data(i, Color(_rng.randf(), 0, 0, 0))
		var mi := MultiMeshInstance3D.new()
		mi.name = String(kind)
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mi)

# Triangle à normale explicite (le matériau ne cache aucune face : l'ordre des sommets importe peu).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(out) < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	_tri(st, a, b, c, col, out)
	_tri(st, a, c, d, col, out)

## Murs (boîte sans fond) de base y0, hauteur h.
func _walls(st: SurfaceTool, hw: float, hd: float, y0: float, h: float, col: Color) -> void:
	var y1 := y0 + h
	_quad(st, Vector3(-hw, y0, hd), Vector3(hw, y0, hd), Vector3(hw, y1, hd), Vector3(-hw, y1, hd), col, Vector3.BACK)
	_quad(st, Vector3(-hw, y0, -hd), Vector3(hw, y0, -hd), Vector3(hw, y1, -hd), Vector3(-hw, y1, -hd), col, Vector3.FORWARD)
	_quad(st, Vector3(hw, y0, -hd), Vector3(hw, y0, hd), Vector3(hw, y1, hd), Vector3(hw, y1, -hd), col, Vector3.RIGHT)
	_quad(st, Vector3(-hw, y0, -hd), Vector3(-hw, y0, hd), Vector3(-hw, y1, hd), Vector3(-hw, y1, -hd), col, Vector3.LEFT)

## Toit en croupe (4 pans) : bord bas en (±hw, ±hd) à y0, faîtage à y0 + rise (un point si le plan est carré).
func _hip_roof(st: SurfaceTool, hw: float, hd: float, y0: float, rise: float, col: Color) -> void:
	var r := maxf(hw - hd, 0.0)
	var y1 := y0 + rise
	var a := Vector3(-hw, y0, -hd)
	var b := Vector3(hw, y0, -hd)
	var c := Vector3(hw, y0, hd)
	var d := Vector3(-hw, y0, hd)
	var ra := Vector3(-r, y1, 0)
	var rb := Vector3(r, y1, 0)
	_quad(st, a, b, rb, ra, col, Vector3(0, 1, -1))
	_quad(st, d, c, rb, ra, col, Vector3(0, 1, 1))
	_tri(st, b, c, rb, col, Vector3(1, 1, 0))
	_tri(st, a, d, ra, col, Vector3(-1, 1, 0))

func _house_mesh(w: float, d: float, h: float, rise: float, over: float, wall: Color, roof: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wl := wall.srgb_to_linear()
	var rl := roof.srgb_to_linear()
	var hw := w * 0.5
	var hd := d * 0.5
	_walls(st, hw, hd, -0.3, h + 0.3, wl)
	# toit à deux pans, faîtage le long de x ; pignons couleur des murs
	var ex := hw + over
	var ez := hd + over
	var ye := h - over * rise / hd
	var yr := h + rise
	_quad(st, Vector3(-ex, ye, -ez), Vector3(ex, ye, -ez), Vector3(ex, yr, 0), Vector3(-ex, yr, 0), rl, Vector3(0, 1, -1))
	_quad(st, Vector3(-ex, ye, ez), Vector3(ex, ye, ez), Vector3(ex, yr, 0), Vector3(-ex, yr, 0), rl, Vector3(0, 1, 1))
	for sx in [-1.0, 1.0]:
		_tri(st, Vector3(sx * hw, h, -hd), Vector3(sx * hw, h, hd), Vector3(sx * hw, yr, 0), wl, Vector3(sx, 0, 0))
	return st.commit()

func _temple_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := Color(0.50, 0.30, 0.20).srgb_to_linear()
	var roof := Color(0.30, 0.40, 0.37).srgb_to_linear()
	var base := Color(0.62, 0.60, 0.55).srgb_to_linear()
	_walls(st, 9.5, 7.5, -0.5, 1.5, base)                     # soubassement de pierre
	_walls(st, 8.0, 6.0, 1.0, 4.6, wall)
	_hip_roof(st, 11.0, 9.0, 5.0, 2.0, roof)                  # grand toit à deux niveaux de pente
	_hip_roof(st, 8.2, 6.2, 7.0, 4.2, roof)
	return st.commit()

func _pagoda_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := Color(0.72, 0.24, 0.13).srgb_to_linear()
	var roof := Color(0.24, 0.25, 0.28).srgb_to_linear()
	var y := -0.5
	_walls(st, 4.2, 4.2, y, 1.4, Color(0.62, 0.60, 0.55).srgb_to_linear())
	y += 1.4
	for i in 5:
		var hw := 3.4 - 0.36 * i
		var th := 3.0 - 0.12 * i
		_walls(st, hw, hw, y, th, wall)
		_hip_roof(st, hw + 2.0, hw + 2.0, y + th - 0.2, 0.9, roof)
		y += th + 0.15
	_walls(st, 0.25, 0.25, y, 5.5, Color(0.35, 0.30, 0.22).srgb_to_linear())   # flèche (sōrin)
	return st.commit()

func _cone_mesh(r: float, h: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := col.srgb_to_linear()
	var seg := 7
	var top := Vector3(0, h, 0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0) * r, 1.2, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 1.2, sin(a1) * r)
		var mid := (p0 + p1) * 0.5
		_tri(st, p0, p1, top, c, Vector3(mid.x, r / h * 2.0, mid.z))
	_walls(st, 0.3, 0.3, 0.0, 1.3, Color(0.30, 0.22, 0.16).srgb_to_linear())
	return st.commit()

func _blob_mesh(r: float, h: float, col: Color) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h
	sm.radial_segments = 7
	sm.rings = 4
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	var c := col.srgb_to_linear()
	for i in verts.size():
		verts[i].y += h * 0.5 + 1.0
		cols.append(c)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
