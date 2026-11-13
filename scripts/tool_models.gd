class_name ToolModels
extends RefCounted
## Petits objets construits en code (pas encore de modèle Blender) : outils en main, établi, haies, bambous,
## planches, clous, pièce. Tout passe par Toon pour garder le rendu du jeu.
## Les outils ont leur origine à la poignée et s'étendent vers +Y.

const WOOD := Color("#A87B4F")
const WOOD_DARK := Color("#5A3A26")
const WOOD_FADED := Color("#8C7155")
const METAL := Color("#4A4E54")
const STEEL := Color("#A9B0B5")
const HEDGE := Color("#4E6B35")
const HEDGE_LIGHT := Color("#6E8C40")
const BAMBOO := Color("#7C9A4A")
const BAMBOO_NODE := Color("#5E7A38")

static func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot_deg := Vector3.ZERO, kind: StringName = &"hard") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(color, kind)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, color, pos, rot_deg)

static func cyl(parent: Node3D, r: float, h: float, color: Color, pos: Vector3, rot_deg := Vector3.ZERO, r_top: float = -1.0, seg: int = 10) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _mesh(parent, c, color, pos, rot_deg)

static func ball(parent: Node3D, r: float, color: Color, pos: Vector3, scl := Vector3.ONE, kind: StringName = &"hard") -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 7
	var mi := _mesh(parent, s, color, pos, Vector3.ZERO, kind)
	mi.scale = scl
	return mi

## Modèle d'outil par nom (utilisé pour la main du joueur et l'établi), ou null.
static func make(tool_name: String) -> Node3D:
	match tool_name:
		"hammer":
			return hammer()
		"shears":
			return shears()
		"sickle":
			return sickle()
	return null

static func hammer() -> Node3D:
	var n := Node3D.new()
	n.name = "hammer"
	cyl(n, 0.017, 0.34, WOOD, Vector3(0, 0.17, 0), Vector3.ZERO, 0.014)
	cyl(n, 0.022, 0.07, WOOD_DARK, Vector3(0, 0.035, 0))
	cyl(n, 0.03, 0.14, METAL, Vector3(0, 0.335, 0), Vector3(0, 0, 90))
	cyl(n, 0.033, 0.014, METAL.darkened(0.25), Vector3(0.072, 0.335, 0), Vector3(0, 0, 90))
	return n

static func shears() -> Node3D:
	var n := Node3D.new()
	n.name = "shears"
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "arm_l" if s < 0.0 else "arm_r"
		arm.position = Vector3(0, 0.36, 0)
		arm.rotation_degrees = Vector3(0, 0, 3.5 * s)
		n.add_child(arm)
		cyl(arm, 0.015, 0.34, WOOD, Vector3(0.0, -0.17, 0))
		cyl(arm, 0.018, 0.035, METAL, Vector3(0, -0.005, 0))
		box(arm, Vector3(0.032, 0.25, 0.007), STEEL, Vector3(-0.011 * s, 0.13, 0.005 * s))
	cyl(n, 0.013, 0.03, METAL.darkened(0.2), Vector3(0, 0.36, 0), Vector3(90, 0, 0))
	return n

static func sickle() -> Node3D:
	var n := Node3D.new()
	n.name = "sickle"
	cyl(n, 0.017, 0.32, WOOD, Vector3(0, 0.16, 0), Vector3.ZERO, 0.015)
	cyl(n, 0.02, 0.03, METAL, Vector3(0, 0.315, 0))
	# lame recourbée : trois segments en arc, tranchant vers -X
	var segs := [[Vector3(-0.05, 0.33, 0), 0.0], [Vector3(-0.13, 0.315, 0), 12.0], [Vector3(-0.2, 0.285, 0), 32.0]]
	for sg in segs:
		box(n, Vector3(0.09, 0.03, 0.006), STEEL, sg[0], Vector3(0, 0, sg[1]))
	return n

## Établi où sont posés les outils des tâches (marteau, cisaille, serpe). Origine au sol.
static func tool_table() -> Node3D:
	var n := Node3D.new()
	n.name = "ToolTable"
	box(n, Vector3(1.4, 0.07, 0.6), WOOD_FADED, Vector3(0, 0.72, 0))
	box(n, Vector3(1.3, 0.04, 0.5), WOOD_DARK, Vector3(0, 0.25, 0))
	for sx in [-0.62, 0.62]:
		for sz in [-0.24, 0.24]:
			box(n, Vector3(0.07, 0.7, 0.07), WOOD_DARK, Vector3(sx, 0.35, sz))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 0.76, 0.6)
	cs.shape = bs
	cs.position = Vector3(0, 0.38, 0)
	body.add_child(cs)
	n.add_child(body)
	return n

## Haie taillée le long de X, origine au sol au centre. Collision incluse.
static func hedge(length: float, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var count := int(length / 0.5) + 1
	for i in count:
		var x := -length * 0.5 + 0.35 + float(i) * (length - 0.7) / float(maxi(count - 1, 1))
		var c := HEDGE.lerp(HEDGE_LIGHT, rng.randf() * 0.25)
		ball(n, 0.52, c, Vector3(x, 0.56 + rng.randf_range(-0.04, 0.05), rng.randf_range(-0.05, 0.05)),
			Vector3(1.0, 1.0, 0.9), &"foliage")
	for i in count - 1:
		var x := -length * 0.5 + 0.6 + float(i) * (length - 1.2) / float(maxi(count - 2, 1))
		ball(n, 0.36, HEDGE.darkened(0.12), Vector3(x, 0.32, rng.randf_range(-0.2, 0.2)), Vector3(1.2, 0.9, 1.15), &"foliage")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, 1.05, 0.9)
	cs.shape = bs
	cs.position = Vector3(0, 0.52, 0)
	body.add_child(cs)
	n.add_child(body)
	return n

## Pousse de bambou : "base" (souche qui reste) et "upper" (partie coupée, pivot à la coupe). r = rayon du chaume.
static func bamboo_stalk(h: float, rng: RandomNumberGenerator, r: float = 0.05) -> Node3D:
	var n := Node3D.new()
	var base := Node3D.new()
	base.name = "base"
	n.add_child(base)
	cyl(base, r * 1.05, 0.3, BAMBOO, Vector3(0, 0.15, 0))
	cyl(base, r * 1.18, 0.035, BAMBOO_NODE, Vector3(0, 0.28, 0))
	var upper := Node3D.new()
	upper.name = "upper"
	upper.position = Vector3(0, 0.3, 0)
	n.add_child(upper)
	var y := 0.0
	var seg := 0.46
	var rr := r
	while y + seg < h - 0.3:
		cyl(upper, rr, seg, BAMBOO, Vector3(0, y + seg * 0.5, 0), Vector3.ZERO, rr * 0.95)
		cyl(upper, rr * 1.12, 0.03, BAMBOO_NODE, Vector3(0, y + seg, 0))
		y += seg
		seg = maxf(seg * 0.95, 0.32)
		rr *= 0.95
	for k in 7:
		var a := rng.randf() * TAU
		var leaf_y := y - rng.randf_range(0.0, 0.9)
		var leaf := ball(upper, 0.2, BAMBOO.lerp(Color("#A6C060"), rng.randf()), Vector3(cos(a) * 0.2, leaf_y, sin(a) * 0.2),
			Vector3(1.7, 0.32, 0.6), &"foliage")
		leaf.rotation.y = -a
		leaf.rotation.z = -0.35
	n.rotation_degrees = Vector3(rng.randf_range(-6, 6), rng.randf() * 360.0, rng.randf_range(-6, 6))
	return n

## Touffe de jeunes bambous (3 ou 4 chaumes) : chaque enfant est une pousse avec "base" et "upper".
static func bamboo_clump(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var count := rng.randi_range(3, 4)
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.4, 0.4)
		var st := bamboo_stalk(rng.randf_range(3.0, 4.2), rng, rng.randf_range(0.055, 0.075))
		st.position = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.12, 0.28)
		n.add_child(st)
	# petit tapis de jeunes feuilles au pied : on repère la touffe de loin
	for k in 4:
		var a2 := rng.randf() * TAU
		ball(n, 0.16, BAMBOO.lerp(Color("#A6C060"), rng.randf()), Vector3(cos(a2) * 0.35, 0.08, sin(a2) * 0.35),
			Vector3(1.4, 0.45, 1.0), &"foliage")
	return n

static func coin() -> Node3D:
	var n := Node3D.new()
	cyl(n, 0.012, 0.003, Color("#C9A24A"), Vector3.ZERO, Vector3(90, 0, 0), -1.0, 12)
	return n

## Renard roux assis, construit en formes simples (en attendant un vrai modèle). Origine au sol, regarde vers +Z.
static func fox() -> Node3D:
	var n := Node3D.new()
	var fur := Color("#D9822B")
	var cream := Color("#F1E2C6")
	var dark := Color("#3A2A24")
	ball(n, 0.16, fur, Vector3(0, 0.2, -0.04), Vector3(1.0, 1.25, 1.35))          # corps assis
	ball(n, 0.1, cream, Vector3(0, 0.25, 0.1), Vector3(0.9, 1.4, 0.6))            # poitrail
	ball(n, 0.11, fur, Vector3(0, 0.44, 0.06), Vector3(1.0, 0.95, 1.0))           # tête
	ball(n, 0.06, cream, Vector3(0, 0.41, 0.17), Vector3(0.9, 0.7, 1.4))          # museau
	ball(n, 0.022, dark, Vector3(0, 0.425, 0.245))                                  # truffe
	for s in [-1.0, 1.0]:
		cyl(n, 0.045, 0.12, fur, Vector3(0.06 * s, 0.56, 0.05), Vector3(-8, 0, -14 * s), 0.004, 6)   # oreilles
		ball(n, 0.016, dark, Vector3(0.045 * s, 0.465, 0.15))                       # yeux
		cyl(n, 0.022, 0.2, fur.darkened(0.15), Vector3(0.06 * s, 0.1, 0.09), Vector3(8, 0, 0))     # pattes avant
	var tail := ball(n, 0.09, fur, Vector3(0.14, 0.08, -0.16), Vector3(1.0, 0.9, 2.4))
	tail.rotation_degrees = Vector3(0, -55, 0)
	ball(n, 0.06, cream, Vector3(0.27, 0.07, -0.02), Vector3(1.0, 0.9, 1.3))       # bout de queue blanc
	return n

## Tanuki bedonnant, masque sombre. Origine au sol, regarde vers +Z.
static func tanuki() -> Node3D:
	var n := Node3D.new()
	var fur := Color("#8A7A64")
	var dark := Color("#3A332C")
	var belly := Color("#C9B79A")
	ball(n, 0.2, fur, Vector3(0, 0.2, 0), Vector3(1.1, 1.0, 1.2))                  # corps rond
	ball(n, 0.13, belly, Vector3(0, 0.18, 0.13), Vector3(1.0, 1.0, 0.6))          # ventre
	ball(n, 0.12, fur, Vector3(0, 0.42, 0.08))                                     # tête
	ball(n, 0.07, dark, Vector3(0, 0.43, 0.16), Vector3(1.6, 0.6, 0.6))           # masque
	ball(n, 0.05, belly, Vector3(0, 0.39, 0.19), Vector3(0.9, 0.7, 1.1))          # museau
	ball(n, 0.02, Color("#1E1E22"), Vector3(0, 0.4, 0.245))                         # truffe
	for s in [-1.0, 1.0]:
		ball(n, 0.04, dark, Vector3(0.08 * s, 0.53, 0.06), Vector3(1.0, 0.8, 0.6))  # oreilles rondes
		ball(n, 0.06, dark, Vector3(0.1 * s, 0.05, 0.08), Vector3(1.0, 0.8, 1.3))   # pattes
	ball(n, 0.08, dark, Vector3(0, 0.12, -0.22), Vector3(1.0, 0.9, 1.6))          # queue
	return n

## Créature d'un événement de nuit : renard, tanuki, chat (modèle importé) ; null pour aucune.
static func creature(kind: String) -> Node3D:
	match kind:
		"renard":
			return fox()
		"tanuki":
			return tanuki()
	return null

## Objet à récolter, construit en formes simples. shape : kaki, chataigne, champignon, feuille, galet, plume,
## fleur, pomme_pin (sinon une petite boule). Origine au sol, taille réelle d'environ 8 à 15 cm.
static func item(shape: String, col: Color) -> Node3D:
	var n := Node3D.new()
	match shape:
		"kaki":
			ball(n, 0.045, col, Vector3(0, 0.038, 0), Vector3(1.0, 0.82, 1.0))
			ball(n, 0.022, Color("#4E6B35"), Vector3(0, 0.072, 0), Vector3(1.4, 0.35, 1.4))
			cyl(n, 0.004, 0.02, Color("#5A3A26"), Vector3(0, 0.085, 0), Vector3.ZERO, -1.0, 5)
		"chataigne":
			ball(n, 0.035, col, Vector3(0, 0.03, 0), Vector3(1.0, 0.8, 0.75))
			ball(n, 0.026, col.lightened(0.35), Vector3(0, 0.012, 0), Vector3(1.0, 0.5, 0.8))
			ball(n, 0.035, col.darkened(0.1), Vector3(0.06, 0.028, 0.02), Vector3(1.0, 0.8, 0.75))
		"champignon":
			cyl(n, 0.014, 0.06, Color("#EFE6D2"), Vector3(0, 0.03, 0), Vector3.ZERO, 0.012, 8)
			ball(n, 0.045, col, Vector3(0, 0.065, 0), Vector3(1.0, 0.45, 1.0))
			cyl(n, 0.011, 0.045, Color("#EFE6D2"), Vector3(0.05, 0.022, 0.02), Vector3(0, 0, -12), 0.01, 8)
			ball(n, 0.032, col.darkened(0.1), Vector3(0.056, 0.048, 0.02), Vector3(1.0, 0.45, 1.0))
		"feuille":
			# feuille d'érable en éventail de lobes plats
			for i in 5:
				var a := deg_to_rad(-70.0 + 35.0 * i)
				var lobe := ball(n, 0.04 if i % 4 != 0 else 0.03, col, Vector3(sin(a) * 0.04, 0.006, -cos(a) * 0.04), Vector3(0.55, 0.12, 1.2))
				lobe.rotation.y = -a
			cyl(n, 0.003, 0.05, col.darkened(0.3), Vector3(0, 0.006, 0.03), Vector3(90, 0, 0), -1.0, 4)
		"galet":
			ball(n, 0.05, col, Vector3(0, 0.02, 0), Vector3(1.3, 0.5, 0.9))
		"plume":
			var p := ball(n, 0.06, col, Vector3(0, 0.01, 0), Vector3(0.28, 0.08, 1.4))
			p.rotation.y = 0.4
			var tip := ball(n, 0.03, Color("#EFE6D2"), Vector3(0.025, 0.012, -0.07), Vector3(0.3, 0.08, 1.0))
			tip.rotation.y = 0.4
		"fleur":
			# lys araignée (higanbana) : tige et pétales fins recourbés
			cyl(n, 0.004, 0.22, Color("#5E7A38"), Vector3(0, 0.11, 0), Vector3.ZERO, -1.0, 5)
			for i in 6:
				var a2 := TAU * i / 6.0
				var pet := cyl(n, 0.004, 0.08, col, Vector3(cos(a2) * 0.03, 0.24, sin(a2) * 0.03), Vector3.ZERO, 0.002, 4)
				pet.rotation = Vector3(sin(a2) * 0.9, 0.0, -cos(a2) * 0.9)
			ball(n, 0.015, col.darkened(0.2), Vector3(0, 0.225, 0))
		"pomme_pin":
			ball(n, 0.035, col, Vector3(0, 0.04, 0), Vector3(1.0, 1.4, 1.0))
			for k in 3:
				ball(n, 0.036 - k * 0.006, col.darkened(0.18), Vector3(0, 0.02 + k * 0.025, 0), Vector3(1.0, 0.3, 1.0))
		_:
			ball(n, 0.04, col, Vector3(0, 0.04, 0))
	return n

## Carpe koï stylisée (environ 30 cm), qui nage vers +Z. Un enfant "tail" (queue) à faire onduler.
## Robes : kohaku (blanche à taches rouges), sanke (+ points noirs), showa (noire, rouge et blanche),
## ogon (dorée), asagi (dos bleu-gris, flancs orange).
const KOI_PATTERNS := ["kohaku", "sanke", "showa", "ogon", "asagi"]

static func koi(pattern: String, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var white := Color("#F2EEE6")
	var red := Color("#D4462A")
	var black := Color("#24222A")
	var base := white
	match pattern:
		"showa":
			base = black
		"ogon":
			base = Color("#E0B03E")
		"asagi":
			base = Color("#7C93AE")
	ball(n, 0.055, base, Vector3(0, 0, 0.02), Vector3(0.62, 0.5, 2.1))           # corps
	ball(n, 0.04, base.lightened(0.08), Vector3(0, -0.004, 0.13), Vector3(0.75, 0.62, 0.9))   # tête
	if pattern == "asagi":
		for s in [-1.0, 1.0]:
			ball(n, 0.045, Color("#E07B3A"), Vector3(0.022 * s, -0.012, 0.02), Vector3(0.3, 0.4, 1.8))
	if pattern in ["kohaku", "sanke", "showa"]:
		var count := rng.randi_range(2, 4)
		for i in count:
			var z := rng.randf_range(-0.07, 0.13)
			ball(n, rng.randf_range(0.026, 0.038), red, Vector3(rng.randf_range(-0.01, 0.01), 0.022, z), Vector3(1.1, 0.35, 1.4))
	if pattern == "sanke":
		for i in 3:
			ball(n, 0.014, black, Vector3(rng.randf_range(-0.02, 0.02), 0.026, rng.randf_range(-0.08, 0.1)), Vector3(1.0, 0.3, 1.0))
	if pattern == "showa":
		for i in 2:
			ball(n, 0.024, white, Vector3(rng.randf_range(-0.015, 0.015), 0.02, rng.randf_range(-0.06, 0.08)), Vector3(1.0, 0.35, 1.3))
	# nageoires pectorales
	for s in [-1.0, 1.0]:
		var fin := ball(n, 0.028, base.lerp(white, 0.4), Vector3(0.04 * s, -0.016, 0.08), Vector3(1.0, 0.12, 0.7))
		fin.rotation.y = 0.5 * s
	# queue, sur un pivot pour onduler
	var tail := Node3D.new()
	tail.name = "tail"
	tail.position = Vector3(0, 0, -0.1)
	n.add_child(tail)
	var tcol := base.lerp(white, 0.3) if pattern != "showa" else black.lerp(red, 0.3)
	for s in [-1.0, 1.0]:
		var lobe := ball(tail, 0.045, tcol, Vector3(0.016 * s, 0, -0.04), Vector3(0.45, 0.12, 1.0))
		lobe.rotation.y = 0.35 * s
	return n
