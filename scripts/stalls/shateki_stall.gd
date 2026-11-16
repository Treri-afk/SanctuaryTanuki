extends StallGame
## 射的 : le tir au bouchon, au stand de Kenta.
##
## Accoudé au comptoir, le fusil à bouchon en main. La souris vise (dans les limites du stand).
## Clic maintenu : on retient son souffle, la visée se stabilise... mais au bout de quelques secondes la main
## tremble. Relâcher : on tire. Le bouchon part en cloche (il faut viser un peu haut au fond).
## Les lots sont de vrais objets (physique) : touché en haut, un lot bascule ; touché en bas, il glisse à peine.
## Un lot ne compte que s'il TOMBE de l'étagère. Le daruma, lesté, se relève souvent. Cinq bouchons.

const SHELVES := [[0.95, 0.02], [1.2, -0.2], [1.45, -0.42]]     # [hauteur du dessus, z du centre] (repère du stand)
const SHELF_DEPTH := 0.15
const SHELF_HALF := 1.08
## [lot, étagère, x]
const LAYOUT := [["ame", 0, -0.55], ["tanuki", 0, 0.0], ["ame", 0, 0.55],
	["kokeshi", 1, -0.62], ["maneki", 1, 0.02], ["kokeshi", 1, 0.6],
	["daruma", 2, -0.32], ["maneki", 2, 0.36]]
## Forme de collision et masse de chaque lot.
const PRIZES := {
	"ame": {"name": "Caramels", "item": "ame", "mass": 0.04, "shape": "box", "size": Vector3(0.07, 0.11, 0.03)},
	"tanuki": {"name": "Petit tanuki", "item": "tanuki_fig", "mass": 0.11, "shape": "cyl", "r": 0.032, "h": 0.115},
	"kokeshi": {"name": "Kokeshi", "item": "kokeshi", "mass": 0.05, "shape": "cyl", "r": 0.022, "h": 0.165},
	"maneki": {"name": "Maneki-neko", "item": "maneki", "mass": 0.13, "shape": "box", "size": Vector3(0.08, 0.15, 0.07)},
	"daruma": {"name": "Daruma", "item": "daruma", "mass": 0.18, "shape": "daruma"},
}
const CORKS := 5
const SPEED := 11.0                   # m/s
const GRAVITY := 5.5
const IMPULSE := 0.034                # N·s transmis par un bouchon
const SENS := 0.0016                  # rad par pixel
const YAW_LIM := 0.42
const PITCH_LIM := Vector2(-0.32, 0.22)
const BASE_PITCH := -0.2

var corks := 0
var won: Array = []
var _bodies: Array = []               # {body, kind, shelf_y, won}
var _shelves: StaticBody3D
var _gun_pivot: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _loaded_cork: MeshInstance3D
var _aim := Vector2.ZERO              # (lacet, tangage) en radians, autour de la vue de base
var _hold_t := 0.0
var _sway_t := 0.0
var _sway_amp := 0.012
var _reload := 0.0
var _flying: Array = []               # {node, pos, vel, life, hit}
var _reticle: Control
var _cork_mat: Material
var _ending := false

func _init() -> void:
	id = "shateki"
	title = "Tir au bouchon"
	kanji = "射的"
	host = "etudiant"
	booth = "yatai_shateki"
	unit = "lot"
	rules = PackedStringArray([
		"Visez avec la souris. Un lot ne compte que s'il tombe de l'étagère.",
		"Maintenez le clic pour retenir votre souffle : la visée se stabilise. Relâchez pour tirer. Trop longtemps, et la main tremble.",
		"Cinq bouchons. Touchés en haut, les lots basculent mieux ; le daruma, lesté, se relève souvent.",
	])
	controls = "souris : viser   ·   clic maintenu : retenir son souffle   ·   relâcher : tirer"

func _build() -> void:
	_shelves = StaticBody3D.new()
	_shelves.name = "Shelves"
	add_child(_shelves)
	for sh in SHELVES:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(SHELF_HALF * 2.0, 0.04, SHELF_DEPTH)
		cs.shape = b
		cs.position = Vector3(0, float(sh[0]) - 0.02, float(sh[1]))
		_shelves.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	_shelves.physics_material_override = pm
	_cork_mat = Toon.material(Color("#C9A27A"))
	_reset_prizes()

func _reset_prizes() -> void:
	for b in _bodies:
		if is_instance_valid(b["body"]):
			(b["body"] as Node).queue_free()
	_bodies.clear()
	for l in LAYOUT:
		var kind := String(l[0])
		var sh: Array = SHELVES[int(l[1])]
		var body := _make_prize(kind)
		body.position = Vector3(float(l[2]), float(sh[0]) + 0.002, float(sh[1]) + 0.01)
		body.rotation.y = randf_range(-0.25, 0.25)
		add_child(body)
		_bodies.append({"body": body, "kind": kind, "shelf_y": float(sh[0]), "won": false})

func _make_prize(kind: String) -> RigidBody3D:
	var d: Dictionary = PRIZES[kind]
	var body := RigidBody3D.new()
	body.mass = float(d["mass"])
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.08
	body.physics_material_override = pm
	body.can_sleep = true
	body.continuous_cd = true
	match String(d["shape"]):
		"box":
			var b := BoxShape3D.new()
			b.size = d["size"]
			var cs := CollisionShape3D.new()
			cs.shape = b
			cs.position = Vector3(0, (d["size"] as Vector3).y / 2.0, 0)
			body.add_child(cs)
		"cyl":
			var c := CylinderShape3D.new()
			c.radius = float(d["r"])
			c.height = float(d["h"])
			var cs2 := CollisionShape3D.new()
			cs2.shape = c
			cs2.position = Vector3(0, float(d["h"]) / 2.0, 0)
			body.add_child(cs2)
		"daruma":
			# fond rond et lourd : il oscille et se redresse
			for s in [[0.056, 0.056], [0.034, 0.096]]:
				var sp := SphereShape3D.new()
				sp.radius = float(s[0])
				var cs3 := CollisionShape3D.new()
				cs3.shape = sp
				cs3.position = Vector3(0, float(s[1]), 0)
				body.add_child(cs3)
			body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			body.center_of_mass = Vector3(0, 0.03, 0)
	var m := ToolModels.glb("lot_" + kind)
	if m == null:
		m = Node3D.new()
		ToolModels.box(m, Vector3(0.07, 0.11, 0.05), Color("#C9432C"), Vector3(0, 0.055, 0))
	body.add_child(m)
	return body

func view() -> Dictionary:
	return {"pos": to_global(Vector3(0, 0, 1.25)), "yaw": rotation_degrees.y, "pitch": rad_to_deg(BASE_PITCH),
		"crouch": 0.1, "fov": 44.0}


func host_spot() -> Vector3:
	return to_global(Vector3(1.62, 0, 0.8))

# ---------------------------------------------------------------- entrer, sortir
func _on_enter() -> void:
	var cam: Camera3D = game.player.camera
	_gun_pivot = Node3D.new()
	_gun_pivot.position = Vector3(0.12, -0.14, -0.12)
	cam.add_child(_gun_pivot)
	_gun = ToolModels.glb("cork_gun")
	if _gun == null:
		_gun = Node3D.new()
		ToolModels.box(_gun, Vector3(0.04, 0.05, 0.6), Color("#8C5A34"), Vector3(0, 0, 0))
	_gun.rotation_degrees.y = 180.0
	_gun.position = Vector3(0, 0, 0.05)
	_gun_pivot.add_child(_gun)
	for mi in _gun.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = _gun.find_child("muzzle", true, false)
	_loaded_cork = _cork_mesh()
	if _muzzle != null:
		_muzzle.add_child(_loaded_cork)
		_loaded_cork.rotation_degrees.x = 90.0
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	_ui.add_child(_reticle)
	_ui.move_child(_reticle, 0)

func _on_leave() -> void:
	if _gun_pivot != null:
		_gun_pivot.queue_free()
		_gun_pivot = null
	for f in _flying:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_flying.clear()
	game.player.rotation.y = global_rotation.y

func _cork_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0065
	c.bottom_radius = 0.0085
	c.height = 0.016
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = _cork_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ---------------------------------------------------------------- manche
func _round_start() -> void:
	corks = CORKS
	won.clear()
	_ending = false
	_aim = Vector2.ZERO
	_hold_t = 0.0
	_reload = 0.0
	_reset_prizes()
	if _loaded_cork:
		_loaded_cork.visible = true

func status() -> String:
	return "Bouchons : %d / %d   ·   lots : %d" % [corks, CORKS, won.size()]

func _motion(rel: Vector2) -> void:
	_aim.x = clampf(_aim.x - rel.x * SENS, -YAW_LIM, YAW_LIM)
	_aim.y = clampf(_aim.y - rel.y * SENS, PITCH_LIM.x, PITCH_LIM.y)

func _press() -> void:
	_hold_t = 0.0

func _release() -> void:
	if corks <= 0 or _reload > 0.0 or _ending:
		return
	_fire()

func _tick(delta: float) -> void:
	_sway_t += delta
	# souffle : tenu, la visée se pose ; trop longtemps, elle tremble
	var target_amp := 0.012
	if holding() and corks > 0:
		_hold_t += delta
		target_amp = 0.0025 if _hold_t < 2.4 else lerpf(0.0025, 0.035, clampf((_hold_t - 2.4) / 1.5, 0.0, 1.0))
	_sway_amp = lerpf(_sway_amp, target_amp, 1.0 - exp(-4.0 * delta))
	var t := _sway_t
	var trem := 1.0 if _hold_t < 2.4 or not holding() else 2.5
	var sway := Vector2(sin(t * 1.3) + 0.6 * sin(t * 2.9 * trem + 1.0), cos(t * 1.1) * 0.8 + 0.5 * sin(t * 3.7 * trem)) * _sway_amp
	var pl: CharacterBody3D = game.player
	pl.rotation.y = global_rotation.y + _aim.x + sway.x
	pl.head.rotation.x = BASE_PITCH + _aim.y + sway.y
	# le fusil vise le point sous la croix
	if _gun_pivot != null:
		var aim_pt := _aim_point()
		_gun_pivot.look_at(aim_pt, Vector3.UP)
	if _reload > 0.0:
		_reload -= delta
		if _reload <= 0.0 and corks > 0 and _loaded_cork:
			_loaded_cork.visible = true
			sfx(["cork_load", "tick"], null, -14.0)
	_fly(delta)
	_check_falls()
	if _reticle:
		_reticle.queue_redraw()
	refresh_status()
	if corks <= 0 and _flying.is_empty() and not _ending:
		_ending = true
		_finish_later()

func _aim_point() -> Vector3:
	var cam: Camera3D = game.player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [game.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else to

func _fire() -> void:
	corks -= 1
	_reload = 0.75
	_hold_t = 0.0
	if _loaded_cork:
		_loaded_cork.visible = false
	var from: Vector3 = _muzzle.global_position if _muzzle else game.player.camera.global_position
	var dir := (_aim_point() - from).normalized()
	var c := _cork_mesh()
	get_tree().current_scene.add_child(c)
	c.global_position = from
	_flying.append({"node": c, "pos": from, "vel": dir * SPEED, "life": 2.0, "hit": false})
	sfx(["cork_pop", "snip"], from, -4.0)
	game.player.kick(Vector3(0.12, 0, 0), Vector3(0, 0.01, 0.05), 0.03, 0.25)
	if _gun:
		var tw := _gun.create_tween()
		tw.tween_property(_gun, "position:z", 0.1, 0.05)
		tw.tween_property(_gun, "position:z", 0.05, 0.3).set_trans(Tween.TRANS_BACK)

func _fly(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for f in _flying:
		var p: Vector3 = f["pos"]
		var v: Vector3 = f["vel"]
		v.y -= GRAVITY * delta
		var np := p + v * delta
		if not f["hit"]:
			var q := PhysicsRayQueryParameters3D.create(p, np)
			q.exclude = [game.player.get_rid()]
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				f["hit"] = true
				var col: Object = hit["collider"]
				var hp: Vector3 = hit["position"]
				if col is RigidBody3D:
					var rb := col as RigidBody3D
					rb.sleeping = false
					rb.apply_impulse(v.normalized() * IMPULSE, hp - rb.global_position)
					sfx(["cork_hit", "hammer"], hp, -14.0)
					pop("Touché !", hp + Vector3(0, 0.08, 0), Color("#FFF3D6"), 22)
				else:
					sfx(["cork_thud", "putdown"], hp, -16.0)
				# le bouchon rebondit et retombe
				var n: Vector3 = hit["normal"]
				v = v.bounce(n) * 0.25
				np = hp + n * 0.01
		f["pos"] = np
		f["vel"] = v
		f["life"] = float(f["life"]) - delta
		var node: MeshInstance3D = f["node"]
		node.global_position = np
		if v.length() > 0.01:
			node.look_at(np + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT)
			node.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		if np.y < global_position.y + 0.02:
			f["life"] = minf(float(f["life"]), 0.4)
			f["vel"] = Vector3.ZERO
	for f in _flying.filter(func(x): return float(x["life"]) <= 0.0):
		(f["node"] as Node).queue_free()
	_flying = _flying.filter(func(x): return float(x["life"]) > 0.0)

func _check_falls() -> void:
	for b in _bodies:
		if b["won"]:
			continue
		var body: RigidBody3D = b["body"]
		var local_y := to_local(body.global_position).y
		if local_y < float(b["shelf_y"]) - 0.12:
			b["won"] = true
			won.append(b["kind"])
			var nm := String(PRIZES[b["kind"]]["name"])
			pop(nm + " !", body.global_position + Vector3(0, 0.15, 0), Color("#FFD45A"), 32)
			sfx(["prize_fall", "coin"], body.global_position, -6.0)
			game.hud.pulse()

func _finish_later() -> void:
	await get_tree().create_timer(1.8).timeout
	_check_falls()
	if not playing:
		return
	var prizes := {}
	for k in won:
		var it := String(PRIZES[k]["item"])
		prizes[it] = int(prizes.get(it, 0)) + 1
	var line := "Aucun lot n'est tombé." if won.is_empty() else "%d lot%s tombé%s de l'étagère." % [won.size(), "s" if won.size() > 1 else "", "s" if won.size() > 1 else ""]
	if won.has("daruma"):
		line = "Même le daruma est tombé !"
	end_round(won.size(), line, prizes)

func _draw_reticle() -> void:
	var c := _reticle.size / 2.0
	var r := 9.0 + _sway_amp * 520.0
	var col := Color(1.0, 0.97, 0.9, 0.85)
	var sh := Color(0.15, 0.08, 0.05, 0.5)
	_reticle.draw_arc(c + Vector2(1, 1), r, 0, TAU, 40, sh, 2.5, true)
	_reticle.draw_arc(c, r, 0, TAU, 40, col, 2.0, true)
	_reticle.draw_circle(c, 2.2, Color(0.75, 0.24, 0.16, 0.95))
	if _reload > 0.0 and corks > 0:
		_reticle.draw_arc(c, r + 7.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - _reload / 0.75), 32, Color(1, 0.9, 0.6, 0.7), 2.0, true)

func host_line(score: int) -> String:
	if score <= 0:
		return "Les bouchons, c'est plus dur que les maths... On recommence ?"
	if score == 1:
		return "Bien visé ! Vise le haut, ça bascule mieux."
	if score <= 3:
		return "Tu as la main sûre. Tu devrais passer l'examen à ma place !"
	return "Tu vas ruiner le stand ! Le patron va me demander des comptes !"

# ---------------------------------------------------------------- test
## Capture : visée posée sur le daruma, un tir parti.
func debug_pose() -> void:
	var target: RigidBody3D = _bodies[6]["body"]
	var cam: Camera3D = game.player.camera
	for i in 30:
		var to := target.global_position + Vector3(0, 0.1, 0) - cam.global_position
		var local := global_basis.inverse() * to
		_aim.x = clampf(atan2(-local.x, -local.z), -YAW_LIM, YAW_LIM)
		_aim.y = clampf(atan2(local.y, Vector2(local.x, local.z).length()) - BASE_PITCH, PITCH_LIM.x, PITCH_LIM.y)
		await get_tree().physics_frame
	_lmb = true
	await get_tree().create_timer(0.6).timeout
	_lmb = false
	_release()
	await get_tree().create_timer(0.12).timeout

## Test automatique : vise chaque lot du bas, à mi-hauteur haute, et tire ; renvoie le nombre de lots tombés.
func autoplay_round() -> int:
	var cam: Camera3D = game.player.camera
	for k in [0, 2, 1, 3, 5]:
		var target: RigidBody3D = _bodies[k]["body"]
		for i in 20:
			var to := target.global_position + Vector3(0, 0.09, 0) - cam.global_position
			var local := global_basis.inverse() * to
			_aim.x = clampf(atan2(-local.x, -local.z), -YAW_LIM, YAW_LIM)
			_aim.y = clampf(atan2(local.y, Vector2(local.x, local.z).length()) - BASE_PITCH + 0.01, PITCH_LIM.x, PITCH_LIM.y)
			await get_tree().physics_frame
		_lmb = true
		await get_tree().create_timer(0.7).timeout
		_lmb = false
		_release()
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(1.0).timeout
	return won.size()
