class_name Terrain
extends Node3D
## Montagne procédurale : plateau du sanctuaire (y = 0), escalier qui descend vers le sud (+Z),
## pentes boisées autour, et crêtes brumeuses au loin. Génère aussi la collision et les plans d'eau.
## Repère : le joueur arrive par le sud (+Z) et monte vers le nord (-Z).
##
## Le sol est dessiné par shaders/ground.gdshader (matières procédurales en coordonnées monde). Chaque sommet porte
## CUSTOM0 = (distance au sentier, hauteur au-dessus de l'eau voisine, 0, 0) ; le reste (enceinte, jardin sec, allées)
## est recalculé dans le shader. forest.gd ajoute un masque (litière, mousse, herbe) via `ground_material`.

const HALF := 150.0
const FLAT_X := 26.0
const FLAT_Z_MIN := -38.0
const STAIR_Z0 := 13.0
const STAIR_N := 30
const STAIR_SLOPE := 0.36        # 0,18 m de contremarche / 0,5 m de giron
const LANDING_Y := -5.58

const GROUND_SHADER := preload("res://shaders/ground.gdshader")
## Couleur de l'herbe rase au sol : le pied des touffes d'herbe (grass.gdshader) reprend la même.
const GRASS_GROUND := Color("#627034")

static var _noise: FastNoiseLite
static var _noise2: FastNoiseLite
static var ground_material: ShaderMaterial   # matériau du sol (forest.gd y pose son masque)

# grille du maillage (plus fine là où l'on marche) et champs mis en cache par _build_ground
static var _xs := PackedFloat32Array()
static var _zs := PackedFloat32Array()
static var _gh := PackedFloat32Array()       # hauteurs
static var _gtrail := PackedFloat32Array()   # distance aux sentiers
static var _gwater := PackedFloat32Array()   # hauteur au-dessus de l'eau voisine (99 = pas d'eau)
static var _gny := PackedFloat32Array()      # composante verticale de la normale

# ruisseau : ligne lissée échantillonnée tous les ~0,5 m, avec le niveau du lit (bassins et petites chutes)
static var _sp := PackedVector2Array()
static var _sb := PackedFloat32Array()
static var _sstep := 0.5

static func _setup() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 11
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_noise2 = FastNoiseLite.new()
	_noise2.seed = 5
	_noise2.frequency = 0.11
	_build_axes()
	_stream_setup()

static func rect_dist(x: float, z: float) -> float:
	var dx := maxf(absf(x) - FLAT_X, 0.0)
	var dz := maxf(maxf(FLAT_Z_MIN - z, z - STAIR_Z0), 0.0)
	return sqrt(dx * dx + dz * dz)

static func stair_line(z: float) -> float:
	return maxf(-STAIR_SLOPE * (z - STAIR_Z0) - 0.27, LANDING_Y)

# ---- sentiers, clairières, ruisseau (x, z). Les hauteurs suivent la pente de la montagne. ----
const TRAILS := {
	&"nord": [[0, -37], [0, -41], [-4, -47], [-9, -55], [-6, -64], [2, -71], [9, -77], [14, -85]],
	&"est": [[26, -8], [34, -9], [41, -13], [48, -13], [52, -16]],
	&"ouest": [[-26, 2], [-35, 3], [-44, 4.5], [-52, 7], [-58, 9]],
}
const FLATS := [   # [x, z, rayon, décalage de hauteur] : belvédère, cabane, mare
	[14.0, -85.0, 5.5, 0.0], [58.0, -16.0, 6.5, 0.0], [-62.0, 12.0, 3.2, -1.1],
]
const STREAM := [[-46, -26], [-45, -12], [-44, 4.5], [-46, 18], [-50, 30]]
const POND := Vector3(-62.0, 12.0, 3.4)        # mare de la montagne : x, z, rayon de l'eau
const PREC_POND := Vector3(-15.0, -27.0, 3.8)  # étang de l'enceinte : x, z, rayon du fond
const ZEN := Vector4(-16.0, -11.0, 6.5, 5.0)   # jardin sec : x, z, demi-largeur, demi-profondeur
const PREC_POND_LEVEL := -0.3                  # niveau de l'eau de l'étang de l'enceinte
const STREAM_DEPTH := 0.36                     # hauteur de l'eau au-dessus du lit du ruisseau

## Distance au segment ab ; retourne (distance, abscisse t 0..1).
static func _seg(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> Vector2:
	var abx := bx - ax
	var abz := bz - az
	var t := clampf(((px - ax) * abx + (pz - az) * abz) / maxf(abx * abx + abz * abz, 0.0001), 0.0, 1.0)
	var qx := ax + abx * t
	var qz := az + abz * t
	return Vector2(sqrt((px - qx) * (px - qx) + (pz - qz) * (pz - qz)), t)

## Point le plus proche sur une polyligne : retourne Vector3(distance, qx, qz).
static func _nearest(pts: Array, x: float, z: float) -> Vector3:
	var best := Vector3(1e9, 0, 0)
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var r := _seg(x, z, a[0], a[1], b[0], b[1])
		if r.x < best.x:
			best = Vector3(r.x, lerpf(a[0], b[0], r.y), lerpf(a[1], b[1], r.y))
	return best

static func _trail_near(x: float, z: float) -> Vector3:
	var best := Vector3(1e9, 0, 0)
	for k in TRAILS:
		var r := _nearest(TRAILS[k], x, z)
		if r.x < best.x:
			best = r
	return best

static func trail_dist(x: float, z: float) -> float:
	return _trail_near(x, z).x

static func stream_dist(x: float, z: float) -> float:
	return _nearest(STREAM, x, z).x

static func flat_dist(x: float, z: float) -> float:
	var best := 1e9
	for f in FLATS:
		best = minf(best, Vector2(x - f[0], z - f[1]).length() - f[2])
	return best

## Vrai si (x, z) doit rester dégagé d'arbres (sentiers, clairières, ruisseau).
static func keep_clear(x: float, z: float, margin: float = 0.0) -> bool:
	return trail_dist(x, z) < 2.8 + margin or stream_dist(x, z) < 2.6 + margin or flat_dist(x, z) < 1.8 + margin

## Pente générale de la montagne, sans bruit ni sentiers.
static func hill(x: float, z: float) -> float:
	var d := rect_dist(x, z)
	if d <= 0.0:
		return 0.0
	var cx := clampf(x, -FLAT_X, FLAT_X)
	var cz := clampf(z, FLAT_Z_MIN, STAIR_Z0)
	var nx := (x - cx) / d
	var nz := (z - cz) / d
	var slope := 0.5 * maxf(-nz, 0.0) - 0.36 * maxf(nz, 0.0) + 0.16 * nx - 0.05
	var rounded := sqrt(d * d + 9.0) - 3.0
	var h := slope * rounded
	if nz > 0.3:
		h = maxf(h, LANDING_Y)
	if z > STAIR_Z0:
		var w := smoothstep(FLAT_X, FLAT_X + 10.0, absf(x))
		h = lerpf(stair_line(z), h, w)
		if z > 40.0:
			h += 0.08 * (z - 40.0)
	return h

# ---- plans d'eau aux rives organiques ----

## Rayon de la rive de l'étang de l'enceinte selon l'angle.
static func _prec_shore_r(a: float) -> float:
	return 4.05 + 0.3 * sin(2.0 * a + 1.3) + 0.2 * sin(3.0 * a + 0.4) + 0.09 * sin(5.0 * a + 2.0)

static func _mare_shore_r(a: float) -> float:
	return 3.75 + 0.32 * sin(2.0 * a + 0.5) + 0.22 * sin(3.0 * a + 2.1) + 0.1 * sin(5.0 * a + 0.7)

## Niveau de l'eau de la mare de la montagne.
static func mare_level() -> float:
	return hill(POND.x, POND.y) - 1.0

## Ligne du ruisseau lissée (Catmull-Rom) puis rééchantillonnée ; lit en bassins successifs séparés de petites chutes.
static func _stream_setup() -> void:
	var ctrl: Array = []
	for p in STREAM:
		ctrl.append(Vector2(p[0], p[1]))
	var dense := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for k in 24:
			var t := float(k) / 24.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(ctrl[n - 1])
	var cum := PackedFloat32Array([0.0])
	for i in range(1, dense.size()):
		cum.append(cum[i - 1] + dense[i].distance_to(dense[i - 1]))
	var total := cum[cum.size() - 1]
	var count := int(total / 0.5)
	_sstep = total / count
	_sp = PackedVector2Array()
	var j := 0
	for k in count + 1:
		var s := k * _sstep
		while j < dense.size() - 2 and cum[j + 1] < s:
			j += 1
		var t := clampf((s - cum[j]) / maxf(cum[j + 1] - cum[j], 0.0001), 0.0, 1.0)
		_sp.append(dense[j].lerp(dense[j + 1], t))
	# lit : suit la pente ; là où elle descend vite, des bassins séparés par de petites chutes de 0,5 m environ
	var raw := PackedFloat32Array()
	for p in _sp:
		raw.append(hill(p.x, p.y) - 0.75)
	_sb = PackedFloat32Array()
	_sb.resize(raw.size())
	_sb[0] = raw[0]
	var level := raw[0]
	var k := 1
	while k < raw.size():
		if raw[k] >= level:
			level = raw[k]
			_sb[k] = level
		elif raw[k] < level - 0.5 and k + 1 < raw.size():
			var tgt := minf(raw[k], raw[k + 1] + 0.02)
			_sb[k] = lerpf(level, tgt, 0.5)
			_sb[k + 1] = tgt
			level = tgt
			k += 2
			continue
		else:
			_sb[k] = maxf(raw[k], level - 0.004)
			level = _sb[k]
		k += 1

static func _stream_q(x: float, z: float) -> Vector2:
	var best := 1e9
	var bs := 0.0
	for i in _sp.size() - 1:
		var a := _sp[i]
		var b := _sp[i + 1]
		var r := _seg(x, z, a.x, a.y, b.x, b.y)
		if r.x < best:
			best = r.x
			bs = (i + r.y) * _sstep
	return Vector2(best, bs)

static func _bed_at(s: float) -> float:
	var f := clampf(s / _sstep, 0.0, _sb.size() - 1.001)
	var i := int(f)
	return lerpf(_sb[i], _sb[i + 1], f - i)

## Demi-largeur du lit du ruisseau à l'abscisse s (mètres le long du courant).
static func _stream_halfw(s: float) -> float:
	return 0.9 + 0.22 * sin(s * 0.37) + 0.12 * sin(s * 0.91 + 1.7)

## Hauteur du sol à (x, z).
static func height(x: float, z: float) -> float:
	return _eval(x, z).x

## (hauteur, distance au sentier, hauteur au-dessus de l'eau voisine ou 99).
static func _eval(x: float, z: float) -> Vector3:
	_setup()
	var d := rect_dist(x, z)
	var tn := _trail_near(x, z)
	if d <= 0.0:
		var pdx := x - PREC_POND.x
		var pdz := z - PREC_POND.y
		var pd := sqrt(pdx * pdx + pdz * pdz)
		if pd < 7.5:
			var rs := _prec_shore_r(atan2(pdz, pdx))
			var hp := -0.82 + 0.82 * smoothstep(rs - 1.8, rs + 0.9, pd)
			return Vector3(hp, tn.x, hp - PREC_POND_LEVEL + maxf(pd - rs - 0.3, 0.0) * 0.25)
		return Vector3(0.0, tn.x, 99.0)
	var sd := stream_dist(x, z)
	var fd := flat_dist(x, z)
	var amp := 2.6 * smoothstep(3.0, 16.0, d)
	amp *= smoothstep(2.0, 9.0, minf(minf(tn.x, sd), maxf(fd, 0.0) + 2.0))
	if z > STAIR_Z0:   # pas de bruit sur l'escalier ni sur le palier du bas
		var dxl := maxf(absf(x) - (2.0 if z < 30.0 else 9.0), 0.0)
		var dzl := maxf(z - 38.0, 0.0)
		amp *= smoothstep(0.5, 7.0, sqrt(dxl * dxl + dzl * dzl))
	var h := hill(x, z) + _noise.get_noise_2d(x, z) * amp
	var wh := 99.0
	var sdd := sd
	if sd < 6.5:   # ruisseau : lit creusé, berges, bourrelet qui retient l'eau
		var q := _stream_q(x, z)
		sdd = q.x
		var bed := _bed_at(q.y)
		var wl := bed + STREAM_DEPTH
		var wd := _stream_halfw(q.y)
		var g := bed + 0.62 * smoothstep(wd * 0.35, wd + 0.45, sdd)
		h = lerpf(g, h, smoothstep(wd + 0.5, wd + 2.8, sdd))
		var rim := wl + 0.2 - 3.0 * (1.0 - smoothstep(wd + 0.1, wd + 0.4, sdd)) - 2.5 * smoothstep(wd + 1.2, wd + 3.4, sdd)
		h = maxf(h, rim)
		wh = h - wl + maxf(sdd - wd - 0.6, 0.0) * 0.6
	if tn.x < 7.0:   # sentiers
		var target := hill(tn.y, tn.z)
		var w := (1.0 - smoothstep(1.7, 6.5, tn.x)) * smoothstep(1.3, 2.7, sdd)
		h = lerpf(h, target, w)
	for f in FLATS:   # clairières et mare
		var dd := Vector2(x - f[0], z - f[1]).length()
		if dd < f[2] + 6.0:
			var target2: float = hill(f[0], f[1]) + float(f[3])
			h = lerpf(h, target2, 1.0 - smoothstep(f[2], f[2] + 6.0, dd))
	var mdx := x - POND.x
	var mdz := z - POND.y
	var md := sqrt(mdx * mdx + mdz * mdz)
	if md < 10.0:   # mare : cuvette aux rives irrégulières, bourrelet côté aval
		var wl2 := mare_level()
		var rs2 := _mare_shore_r(atan2(mdz, mdx))
		var b := wl2 - 0.5 + 0.75 * smoothstep(rs2 - 1.6, rs2 + 0.8, md)
		var rim2 := wl2 + 0.25 - 2.0 * smoothstep(rs2 + 0.8, rs2 + 4.0, md)
		h = lerpf(b, maxf(h, rim2), smoothstep(rs2 + 0.4, rs2 + 1.6, md))
		wh = h - wl2 + maxf(md - rs2 - 0.8, 0.0) * 0.6
	return Vector3(h, tn.x, wh)

# ---- grille du maillage ----

## Pas de 1 m sur toute la zone jouable (et l'escalier), 2 m au-delà.
static func _build_axes() -> void:
	_xs = PackedFloat32Array()
	var x := -HALF
	while x <= HALF + 0.001:
		_xs.append(x)
		x += 1.0 if (x >= -72.001 and x < 71.999) else 2.0
	_zs = PackedFloat32Array()
	var z := -HALF
	while z <= HALF + 0.02:
		_zs.append(z)
		if absf(z - STAIR_Z0) < 0.001:
			z = STAIR_Z0 + 0.01       # petite falaise de 0,27 m au bord du plateau, côté escalier
			continue
		z += 1.0 if (z >= -100.001 and z < 44.999) else 2.0

static func _cell(axis: PackedFloat32Array, v: float) -> Vector2:
	var i := clampi(axis.bsearch(v) - 1, 0, axis.size() - 2)
	return Vector2(i, clampf((v - axis[i]) / (axis[i + 1] - axis[i]), 0.0, 1.0))

## Hauteur de la surface du maillage (interpolation exacte des triangles de la grille), pour poser des plans d'eau,
## de l'herbe ou des cailloux exactement sur le sol visible.
static func mesh_height(x: float, z: float) -> float:
	_setup()
	var cx := _cell(_xs, x)
	var cz := _cell(_zs, z)
	var i := int(cx.x)
	var j := int(cz.x)
	var nx := _xs.size()
	var ha: float
	var hb: float
	var hc: float
	var he: float
	if _gh.size() == nx * _zs.size():
		ha = _gh[j * nx + i]
		hb = _gh[j * nx + i + 1]
		hc = _gh[(j + 1) * nx + i]
		he = _gh[(j + 1) * nx + i + 1]
	else:
		ha = height(_xs[i], _zs[j])
		hb = height(_xs[i + 1], _zs[j])
		hc = height(_xs[i], _zs[j + 1])
		he = height(_xs[i + 1], _zs[j + 1])
	var fx := cx.y
	var fz := cz.y
	if fx + fz <= 1.0:   # triangle (a, b, c)
		return ha + fx * (hb - ha) + fz * (hc - ha)
	return he + (1.0 - fx) * (hc - he) + (1.0 - fz) * (hb - he)

## Champs du sol interpolés : (distance au sentier, hauteur au-dessus de l'eau voisine, normale verticale).
## Disponible une fois le sol construit ; sinon calculé directement.
static func field(x: float, z: float) -> Vector3:
	_setup()
	var nx := _xs.size()
	if _gtrail.size() != nx * _zs.size():
		var e := _eval(x, z)
		return Vector3(e.y, e.z, 1.0)
	var cx := _cell(_xs, x)
	var cz := _cell(_zs, z)
	var a := int(cz.x) * nx + int(cx.x)
	var c := a + nx
	var fx := cx.y
	var fz := cz.y
	var t := lerpf(lerpf(_gtrail[a], _gtrail[a + 1], fx), lerpf(_gtrail[c], _gtrail[c + 1], fx), fz)
	var w := lerpf(lerpf(_gwater[a], _gwater[a + 1], fx), lerpf(_gwater[c], _gwater[c + 1], fx), fz)
	var ny := lerpf(lerpf(_gny[a], _gny[a + 1], fx), lerpf(_gny[c], _gny[c + 1], fx), fz)
	return Vector3(t, w, ny)

## Échantillons du ruisseau pour la décoration : [position (x, z), abscisse, niveau du lit, demi-largeur, chute (bool)].
static func stream_samples() -> Array:
	_setup()
	var out: Array = []
	for k in _sp.size():
		var fall := k > 0 and _sb[k - 1] - _sb[k] > 0.15
		out.append([_sp[k], k * _sstep, _sb[k], _stream_halfw(k * _sstep), fall])
	return out

## Hauteur où marche un PNJ.
static func walk_y(x: float, z: float) -> float:
	if absf(x) < 1.6 and z > STAIR_Z0 and z < STAIR_Z0 + STAIR_N * 0.5:
		return -STAIR_SLOPE * (z - STAIR_Z0) - 0.09
	if absf(x) < FLAT_X + 1.0 and z <= STAIR_Z0 and z >= FLAT_Z_MIN:
		return 0.0
	return height(x, z)

func _ready() -> void:
	_setup()
	_build_ground()
	_build_water()
	_build_precinct_pond()
	_build_ridges()

func _build_ground() -> void:
	var xs := _xs
	var zs := _zs
	var nx := xs.size()
	var nz := zs.size()
	var total := nx * nz
	_gh.resize(total)
	_gtrail.resize(total)
	_gwater.resize(total)
	_gny.resize(total)
	for j in nz:
		var z := zs[j]
		for i in nx:
			var e := _eval(xs[i], z)
			var k := j * nx + i
			_gh[k] = e.x
			_gtrail[k] = minf(e.y, 60.0)
			_gwater[k] = clampf(e.z, -5.0, 99.0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var custom := PackedFloat32Array()
	verts.resize(total)
	norms.resize(total)
	custom.resize(total * 4)
	for j in nz:
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, nz - 1)
		for i in nx:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nx - 1)
			var k := j * nx + i
			var dhx := (_gh[j * nx + i1] - _gh[j * nx + i0]) / (xs[i1] - xs[i0])
			var dhz := (_gh[j1 * nx + i] - _gh[j0 * nx + i]) / (zs[j1] - zs[j0])
			var n := Vector3(-dhx, 1.0, -dhz).normalized()
			verts[k] = Vector3(xs[i], _gh[k], zs[j])
			norms[k] = n
			_gny[k] = n.y
			custom[k * 4] = _gtrail[k]
			custom[k * 4 + 1] = _gwater[k]
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var w := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var e := c + 1
			idx[w] = a
			idx[w + 1] = b
			idx[w + 2] = c
			idx[w + 3] = b
			idx[w + 4] = e
			idx[w + 5] = c
			w += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_CUSTOM0] = custom
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("c_grass", GRASS_GROUND)
	ground_material = m
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _build_ridges() -> void:
	var radii := [235.0, 310.0, 410.0, 530.0]
	var peaks := [38.0, 62.0, 90.0, 120.0]
	var tops := [Color(0.35, 0.45, 0.46), Color(0.50, 0.59, 0.62), Color(0.66, 0.72, 0.75), Color(0.80, 0.80, 0.80)]
	var shader: Shader = load("res://shaders/ridge.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 21
	n.frequency = 0.9
	for k in radii.size():
		var seg := 160
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		for i in seg + 1:
			var a := TAU * float(i) / float(seg)
			var r: float = radii[k]
			var nv := n.get_noise_1d(float(i) * 0.35 + k * 40.0)
			var hh: float = peaks[k] * (0.55 + 0.45 * nv) + 18.0 * sin(a * 3.0 + k)
			verts.append(Vector3(cos(a) * r, -250.0, sin(a) * r))
			uvs.append(Vector2(float(i) / seg, 0.0))
			verts.append(Vector3(cos(a) * r, hh, sin(a) * r))
			uvs.append(Vector2(float(i) / seg, 1.0))
		for i in seg:
			var q := i * 2
			idx.append_array([q, q + 1, q + 2, q + 1, q + 3, q + 2])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("top_color", tops[k])
		mat.set_shader_parameter("bottom_color", Color(0.86, 0.80, 0.70))
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Ridge%d" % k
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## Ruban du ruisseau : UV.x = travers (0 à 1), UV.y = distance le long du courant (m).
## COLOR.r = raideur (1 sur les petites chutes : écume possible côté shader d'eau).
func _build_water() -> void:
	var wm := Toon.water_material()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n := _sp.size()
	for k in n:
		var p := _sp[k]
		var dirv := (_sp[mini(k + 1, n - 1)] - _sp[maxi(k - 1, 0)]).normalized()
		var s := k * _sstep
		var hw := _stream_halfw(s) + 0.6
		var side := Vector2(-dirv.y, dirv.x) * hw
		var y := _sb[k] + STREAM_DEPTH
		var drop := (_sb[maxi(k - 1, 0)] - _sb[mini(k + 1, n - 1)]) / (2.0 * _sstep)
		var steep := clampf(drop * 2.0, 0.0, 1.0)
		verts.append(Vector3(p.x - side.x, y, p.y - side.y))
		verts.append(Vector3(p.x + side.x, y, p.y + side.y))
		uvs.append(Vector2(0.0, s))
		uvs.append(Vector2(1.0, s))
		var nrm := Vector3(dirv.x * drop, 1.0, dirv.y * drop).normalized()
		norms.append(nrm)
		norms.append(nrm)
		cols.append(Color(steep, 0, 0))
		cols.append(Color(steep, 0, 0))
	for k in n - 1:
		var q := k * 2
		idx.append_array([q, q + 1, q + 2, q + 1, q + 3, q + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, wm)
	var mi := MeshInstance3D.new()
	mi.name = "Stream"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var pm := _pond_mesh("Pond", Vector2(POND.x, POND.y), mare_level(), 9.0)
	add_child(pm)

func _build_precinct_pond() -> void:
	add_child(_pond_mesh("PrecinctPond", Vector2(PREC_POND.x, PREC_POND.y), PREC_POND_LEVEL, 7.0))

## Plan d'eau dont le contour suit la rive réelle (courbe de niveau du sol), un peu élargi sous la berge.
## UV.x = 0,5 (pas de bord) ; UV.y = 0. Le shader d'eau travaille en coordonnées monde.
func _pond_mesh(node_name: String, c: Vector2, level: float, rmax: float) -> MeshInstance3D:
	var seg := 72
	var verts := PackedVector3Array([Vector3(c.x, level, c.y)])
	var uvs := PackedVector2Array([Vector2(0.5, 0.0)])
	var norms := PackedVector3Array([Vector3.UP])
	for i in seg:
		var a := TAU * float(i) / seg
		var dir := Vector2(cos(a), sin(a))
		var r := 0.3
		while r < rmax and mesh_height(c.x + dir.x * r, c.y + dir.y * r) < level + 0.02:
			r += 0.05
		r += 0.3
		while r < rmax and mesh_height(c.x + dir.x * r, c.y + dir.y * r) < level + 0.03:
			r += 0.05
		verts.append(Vector3(c.x + dir.x * r, level, c.y + dir.y * r))
		uvs.append(Vector2(0.5, 0.0))
		norms.append(Vector3.UP)
	var idx := PackedInt32Array()
	for i in seg:
		idx.append_array([0, 1 + i, 1 + (i + 1) % seg])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, Toon.water_material())
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
