class_name Decor
extends Node
## Décoration libre du sanctuaire : on achète ou reçoit des objets, puis on les pose où l'on veut, dans la cour
## ou dans les bâtiments.
##
## B ouvre la réserve d'objets. On choisit un objet ; une version fantôme suit le regard :
##   - verte si l'endroit convient, rouge sinon (la raison s'affiche) ;
##   - molette : tourner (15°) ; Maj : sans la grille de 25 cm ;
##   - clic : poser ; Échap, clic droit ou B : annuler.
## Mode « Arranger » : on vise un objet posé ; clic = le reprendre pour le déplacer, R = le ranger dans la réserve.
##
## Pour l'instant, seul le banc est au catalogue : les autres objets seront refaits (voir docs/feuille-de-route.md).
## Les objets ne sont pas que jolis :
##   seat   on peut s'y asseoir (E), la vue descend, ZQSD ou E pour se lever ;
##   light  une petite flamme s'allume le soir ;
##   likes  un visiteur qui l'aime le remarque après la discussion : une réplique, +1 d'affection (une seule
##          fois par objet et par visiteur).
## Interdit : l'allée centrale et l'escalier (passage des visiteurs), les places de la fête, les endroits où les
## visiteurs s'arrêtent, les petites zones d'action (outils, caisses...), et hors du sanctuaire.
## État : GameState.decor (réserve) et GameState.decor_placed ({id, pos, yaw}), sauvegardés (scripts/save_game.gd).
## Les cadeaux d'histoire passent par l'effet « item » : un id de ITEMS rejoint la réserve (scripts/story.gd).

const ITEMS := {
	"banc": {"name": "Banc de bois", "model": "bench", "price": 6, "color": "#8A6A48", "seat": Vector3(0, 0, 0.02),
		"desc": "Un banc de sentier, planches usées par la pluie. On peut s'y asseoir.",
		"likes": {"vieille_dame": "Fumiko s'assoit un instant sur le banc. « Ah... ça fait du bien aux genoux. »"}},
}
const REACH := 6.0
const GRID := 0.25
const TURN := 15.0
const OK_COLOR := Color(0.45, 0.92, 0.55, 0.36)
const BAD_COLOR := Color(0.96, 0.36, 0.3, 0.42)
const PICK_COLOR := Color(1.0, 0.88, 0.45, 0.3)
const SEAT_EYE := 1.12          # hauteur des yeux, assis
enum Mode { NONE, GHOST, ARRANGE }

var game: Node3D
var player: CharacterBody3D
var mode := Mode.NONE
var _nodes: Array = []          # aligné sur GameState.decor_placed
var _lights: Array = []
var _ghost: Node3D
var _ghost_id := ""
var _ghost_yaw := 0.0
var _ghost_ok := false
var _ghost_box := AABB()        # boîte de l'objet dans son repère (sans rotation)
var _ghost_disc: MeshInstance3D
var _moving: Dictionary = {}    # objet repris en mode Arranger (pour le remettre si on annule)
var _ghost_mat: ShaderMaterial
var _pick_mat: ShaderMaterial
var _disc_mat: StandardMaterial3D   # disque au sol sous le fantôme (même couleur que le voile)
var _hover := -1
var _seat: Node3D = null
var _seat_cool := 0.0
var _busy := false

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func display_name(id: String) -> String:
	return String(item(id).get("name", id))

## Ajoute un objet à la réserve (achat, cadeau, récompense).
static func give(id: String, n := 1) -> void:
	if not ITEMS.has(id) or n <= 0:
		return
	GameState.decor[id] = int(GameState.decor.get(id, 0)) + n
	Events.toast.emit("%s rejoint vos objets à placer  ·  B pour décorer" % display_name(id))

static func owned(id: String) -> int:
	return int(GameState.decor.get(id, 0))

static func placed_count(id := "") -> int:
	if id == "":
		return GameState.decor_placed.size()
	var n := 0
	for e in GameState.decor_placed:
		if String(e["id"]) == id:
			n += 1
	return n

func setup(g: Node3D) -> void:
	game = g
	player = g.player
	_ghost_mat = _overlay(OK_COLOR)
	_pick_mat = _overlay(PICK_COLOR)
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.no_depth_test = false
	Events.day_started.connect(func(_d):
		_cancel()
		_stand_up(true)
		rebuild())
	Events.phase_changed.connect(func(_p): _update_lights())

## Voile coloré (shaders/decor_ghost.gdshader) : gonflé le long des normales pour ne pas grésiller sur l'objet.
func _overlay(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/decor_ghost.gdshader")
	m.set_shader_parameter("tint", c)
	return m

# ---------------------------------------------------------------- objets posés
## Recrée tous les objets posés d'après GameState.decor_placed.
func rebuild() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_lights.clear()
	_hover = -1
	for i in GameState.decor_placed.size():
		_nodes.append(_spawn(i))
	_update_lights()

func _spawn(i: int) -> Node3D:
	var e: Dictionary = GameState.decor_placed[i]
	var id := String(e["id"])
	var it := item(id)
	var n: Node3D = game._model(String(it.get("model", id)), Color.from_string(String(it.get("color", "#C9A06A")), Color.TAN))
	n.name = "Decor_%s_%d" % [id, i]
	n.set_meta("decor_index", i)
	game.props.add_child(n)
	n.global_position = e["pos"]
	n.rotation_degrees.y = float(e["yaw"])
	if n.find_children("*", "CollisionObject3D", true, false).is_empty():
		_add_collision(n)
	if it.has("light"):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 0.9
		l.omni_range = 4.5
		l.shadow_enabled = false
		l.position = it["light"]
		n.add_child(l)
		_lights.append(l)
	if it.has("seat"):
		game._make(n, Vector3(1.3, 0.9, 0.7), Vector3(0, 0.45, 0),
			func() -> String:
				return "" if _seat != null else "E : S'asseoir",
			func(_p): _sit(n))
	return n

## Collision simple (boîte englobante) pour un modèle qui n'en a pas.
func _add_collision(n: Node3D) -> void:
	var box := _local_box(n)
	if box.size == Vector3.ZERO:
		return
	var body := StaticBody3D.new()
	body.name = "DecorBody"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	cs.shape = bs
	cs.position = box.get_center()
	body.add_child(cs)
	n.add_child(body)

## Boîte englobante des maillages d'un objet, dans son propre repère (rotation et échelle comprises sous la racine).
func _local_box(n: Node3D) -> AABB:
	var inv := n.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _update_lights() -> void:
	var on := GameState.phase == GameState.Phase.EVENING or GameState.phase == GameState.Phase.NIGHT
	for l in _lights:
		if is_instance_valid(l):
			l.visible = on

func _process(delta: float) -> void:
	_seat_cool = maxf(_seat_cool - delta, 0.0)
	if _seat != null:
		if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.5 and _seat_cool <= 0.0:
			_stand_up()
		return
	match mode:
		Mode.GHOST:
			_update_ghost(delta)
		Mode.ARRANGE:
			_update_arrange()
	var t := Time.get_ticks_msec() * 0.001
	for l in _lights:
		if is_instance_valid(l) and l.visible:
			l.light_energy = 0.85 + 0.1 * sin(t * 8.3) + 0.05 * sin(t * 21.0)

# ---------------------------------------------------------------- commandes
func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if _seat != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and _seat_cool <= 0.0:
			_stand_up()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				if mode != Mode.NONE:
					_cancel()
				elif player.input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.tool == &"" and player.carry == &"":
					open_picker()
				elif player.input_enabled and (player.tool != &"" or player.carry != &""):
					player.flash_prompt("Les mains sont prises : reposez d'abord ce que vous portez")
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if mode != Mode.NONE:
					_cancel()
					get_viewport().set_input_as_handled()
			KEY_R:
				if mode == Mode.ARRANGE and _hover >= 0:
					_store(_hover)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and mode != Mode.NONE:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if mode == Mode.GHOST:
					_try_place()
				elif _hover >= 0:
					_pick_up(_hover)
			MOUSE_BUTTON_RIGHT:
				_cancel()
			MOUSE_BUTTON_WHEEL_UP:
				_ghost_yaw = fposmod(_ghost_yaw + TURN, 360.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_ghost_yaw = fposmod(_ghost_yaw - TURN, 360.0)
		get_viewport().set_input_as_handled()

## Réserve d'objets : choisir quoi poser, ou passer en mode Arranger.
func open_picker() -> void:
	var rows := []
	for id in ITEMS:
		var n := owned(id)
		if n <= 0:
			continue
		var it: Dictionary = ITEMS[id]
		rows.append({"id": id, "name": it["name"], "desc": it["desc"], "note": "×%d" % n, "ok": true, "why": "",
			"price": -1, "action": "Placer", "color": it["color"]})
	if not GameState.decor_placed.is_empty():
		rows.append({"id": "__arrange", "name": "Arranger", "price": -1, "action": "Arranger", "color": "#C9A06A",
			"desc": "Déplacer ou ranger les objets déjà posés.", "note": "%d posé%s" % [placed_count(), "s" if placed_count() > 1 else ""],
			"ok": true, "why": ""})
	if rows.is_empty():
		Events.toast.emit("Aucun objet à placer pour l'instant. Le bureau du sanctuaire en vend quelques-uns.")
		return
	_busy = true
	player.input_enabled = false
	var pick: String = await game.hud.show_list("飾", "Décorer le sanctuaire",
		"Posez vos objets où vous voulez : dans la cour, près de l'étang, sous la véranda...",
		"%d objet%s posé%s" % [placed_count(), "s" if placed_count() > 1 else "", "s" if placed_count() > 1 else ""], rows)
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	_busy = false
	if pick == "__arrange":
		_enter(Mode.ARRANGE)
	elif pick != "":
		start_ghost(pick)

func _enter(m: int) -> void:
	mode = m
	player.placing = m != Mode.NONE
	player.placing_prompt = ""
	game.hud.modal_count += 1 if m != Mode.NONE else 0

func _leave() -> void:
	if mode != Mode.NONE:
		game.hud.modal_count -= 1
	mode = Mode.NONE
	player.placing = false
	player.placing_prompt = ""
	_set_hover(-1)

# ---------------------------------------------------------------- fantôme
func start_ghost(id: String, yaw := INF) -> void:
	_clear_ghost()
	var it := item(id)
	_ghost_id = id
	_ghost = game._model(String(it.get("model", id)), Color.from_string(String(it.get("color", "#C9A06A")), Color.TAN))
	_ghost.name = "DecorGhost"
	game.props.add_child(_ghost)
	for b in _ghost.find_children("*", "CollisionObject3D", true, false):
		b.get_parent().remove_child(b)
		b.free()
	_ghost_box = _local_box(_ghost)
	for m in _ghost.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = _ghost_mat
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_disc = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var r := maxf(_ghost_box.size.x, _ghost_box.size.z) * 0.5 + 0.08
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.012
	cm.radial_segments = 40
	_ghost_disc.mesh = cm
	_ghost_disc.material_override = _disc_mat
	_ghost_disc.position = Vector3(_ghost_box.get_center().x, 0.02, _ghost_box.get_center().z)
	_ghost_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_disc)
	# par défaut, l'objet nous fait face (l'avant des modèles est +Z)
	_ghost_yaw = yaw if yaw != INF else snappedf(rad_to_deg(player.rotation.y) + 180.0, TURN)
	if mode == Mode.NONE:
		_enter(Mode.GHOST)
	else:
		mode = Mode.GHOST
	_update_ghost(1.0, true)

func _clear_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_id = ""

func _aim() -> Dictionary:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		var p := to
		p.y = game.ground_y(p.x, p.z)
		return {"position": p, "normal": Vector3.UP, "collider": null}
	return hit

## Hauteur du sol (terrain ou plancher) sous un point, en partant d'un peu au-dessus.
func _floor_at(p: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 1.2, 1, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q)

func _update_ghost(delta: float, snap_now := false) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		return
	var hit := _aim()
	var p: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var col: Variant = hit.get("collider")
	if not Input.is_key_pressed(KEY_SHIFT):
		p.x = snappedf(p.x, GRID)
		p.z = snappedf(p.z, GRID)
		var f := _floor_at(p)
		if not f.is_empty():
			p.y = f["position"].y
			normal = f["normal"]
			col = f["collider"]
	var why := _blocked_reason(p, normal, col)
	_ghost_ok = why == ""
	var k := 1.0 if snap_now else 1.0 - exp(-18.0 * delta)
	_ghost.global_position = _ghost.global_position.lerp(p, k)
	_ghost.rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(_ghost.rotation_degrees.y), deg_to_rad(_ghost_yaw), k))
	_ghost.set_meta("target", p)
	_ghost_mat.set_shader_parameter("tint", OK_COLOR if _ghost_ok else BAD_COLOR)
	_disc_mat.albedo_color = OK_COLOR if _ghost_ok else BAD_COLOR
	var nm := display_name(_ghost_id)
	if _ghost_ok:
		player.placing_prompt = "Clic : poser %s     Molette : tourner     Maj : sans grille     Échap : annuler" % nm.to_lower()
	else:
		player.placing_prompt = "%s     Molette : tourner     Échap : annuler" % why

## "" si l'objet peut aller là, sinon la raison (affichée telle quelle).
func _blocked_reason(p: Vector3, normal: Vector3, col: Variant) -> String:
	if Terrain.rect_dist(p.x, p.z) > 0.6:
		return "Trop loin du sanctuaire"
	if absf(p.x) < 1.75 and p.z > -17.0:
		return "Laissez l'allée libre pour les visiteurs"
	if normal.y < 0.82:
		return "Le sol est trop en pente"
	if col is Node and _decor_index(col as Node) >= 0:
		return "Pas sur un autre objet"
	var p2 := Vector2(p.x, p.z)
	var reserved := []
	for s in Festival.STALLS:
		reserved.append([s["pos"], 3.0])
	for q in Festival.POLES:
		reserved.append([q, 0.9])
	for nb in Festival.NOBORI:
		reserved.append([nb[0], 0.8])
	for q in [Festival.BOARD_POS, Festival.LANTERN_CRATE, Festival.NOBORI_CRATE, Festival.TABLE_POS]:
		reserved.append([q, 1.3])
	for r in reserved:
		if p2.distance_to(Vector2(r[0].x, r[0].z)) < float(r[1]):
			return "Cette place sert pour la fête"
	var consts: Dictionary = game.get_script().get_script_constant_map()
	for sp in (consts["SPOTS"] as Dictionary).values():
		if p2.distance_to(Vector2(sp[0].x, sp[0].z)) < 1.1:
			return "Les visiteurs s'arrêtent ici"
	var off: Vector3 = consts["OFFERING_SPOT"]
	if p2.distance_to(Vector2(off.x, off.z)) < 1.1:
		return "Les visiteurs s'arrêtent ici"
	# encombrement : on interroge une boîte un peu plus petite que l'objet, décollée du sol
	var size := _ghost_box.size - Vector3(0.06, 0.12, 0.06)
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return ""
	var shape := BoxShape3D.new()
	shape.size = size
	var basis := Basis(Vector3.UP, deg_to_rad(_ghost_yaw))
	var c := _ghost_box.get_center()
	var origin := p + basis * Vector3(c.x, 0.0, c.z) + Vector3.UP * (_ghost_box.position.y + 0.1 + size.y * 0.5)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(basis, origin)
	q.collision_mask = 3
	q.collide_with_areas = true
	var space := player.get_world_3d().direct_space_state
	for r in space.intersect_shape(q, 16):
		var other: Object = r["collider"]
		if other == player:
			return "Reculez un peu"
		if other is Area3D:
			if _small_area(other as Area3D):
				return "Il y a déjà quelque chose ici" + _debug_name(other)
			continue
		return "Pas la place ici" + _debug_name(other)
	return ""

## Tests (--decordebug) : nom de ce qui gêne.
func _debug_name(o: Object) -> String:
	if not OS.get_cmdline_user_args().has("--decordebug") or not (o is Node):
		return ""
	return " (%s)" % String((o as Node).get_path()).trim_prefix("/root/")

## Petite zone d'action (outil, caisse, objet) : on ne pose rien dessus. Les grandes zones (allée à balayer...) ne gênent pas.
func _small_area(a: Area3D) -> bool:
	for c in a.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var s: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
			return s.x < 2.6 and s.z < 2.6
	return false

func _decor_index(n: Node) -> int:
	while n != null:
		if n.has_meta("decor_index") and n != _ghost:
			return int(n.get_meta("decor_index"))
		n = n.get_parent()
	return -1

func _try_place() -> void:
	if not _ghost_ok:
		player.kick(Vector3(0, 0, 0.12), Vector3.ZERO, 0.04, 0.2)
		return
	var p: Vector3 = _ghost.get_meta("target", _ghost.global_position)
	var id := _ghost_id
	GameState.decor_placed.append({"id": id, "pos": p, "yaw": _ghost_yaw})
	var from_move := not _moving.is_empty()
	if from_move:
		_moving = {}
	else:
		GameState.decor[id] = owned(id) - 1
		if owned(id) <= 0:
			GameState.decor.erase(id)
	_clear_ghost()
	rebuild()
	var n: Node3D = _nodes[-1]
	_pop(n)
	Sfx.play(&"putdown", p)
	if not from_move:
		GameState.note("J'ai installé %s dans le sanctuaire." % display_name(id).to_lower())
	if from_move:
		mode = Mode.ARRANGE
	else:
		_leave()

## Petit rebond à la pose.
func _pop(n: Node3D) -> void:
	var base := n.scale
	n.scale = base * Vector3(1.06, 0.9, 1.06)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _cancel() -> void:
	if mode == Mode.NONE:
		return
	if not _moving.is_empty():
		GameState.decor_placed.append(_moving)   # l'objet repris retourne à sa place
		_moving = {}
		rebuild()
	_clear_ghost()
	_leave()

# ---------------------------------------------------------------- arranger
func _update_arrange() -> void:
	var hit := _aim()
	var idx := -1
	if hit.get("collider") is Node:
		idx = _decor_index(hit["collider"])
	_set_hover(idx)
	if idx >= 0:
		var nm := display_name(String(GameState.decor_placed[idx]["id"])).to_lower()
		player.placing_prompt = "Clic : déplacer %s     R : le ranger     Échap : terminer" % nm
	else:
		player.placing_prompt = "Visez un objet posé pour le déplacer ou le ranger     Échap : terminer"

func _set_hover(i: int) -> void:
	if i == _hover:
		return
	if _hover >= 0 and _hover < _nodes.size() and is_instance_valid(_nodes[_hover]):
		for m in (_nodes[_hover] as Node).find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = null
	_hover = i
	if i >= 0 and i < _nodes.size():
		for m in (_nodes[i] as Node).find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = _pick_mat

func _pick_up(i: int) -> void:
	var e: Dictionary = GameState.decor_placed[i]
	GameState.decor_placed.remove_at(i)
	_moving = e
	_set_hover(-1)
	rebuild()
	Sfx.play(&"pickup", e["pos"])
	start_ghost(String(e["id"]), float(e["yaw"]))

func _store(i: int) -> void:
	var e: Dictionary = GameState.decor_placed[i]
	GameState.decor_placed.remove_at(i)
	GameState.decor[String(e["id"])] = owned(String(e["id"])) + 1
	_set_hover(-1)
	rebuild()
	Sfx.play(&"pickup", e["pos"])
	player.flash_prompt("%s rangé dans la réserve" % display_name(String(e["id"])))
	if GameState.decor_placed.is_empty():
		_leave()

# ---------------------------------------------------------------- s'asseoir
func _sit(n: Node3D) -> void:
	if _seat != null or mode != Mode.NONE:
		return
	var it := item(String(GameState.decor_placed[int(n.get_meta("decor_index"))]["id"]))
	_seat = n
	_seat_cool = 0.5
	player.seated = true
	player.placing = true
	player.placing_prompt = "ZQSD ou E : se lever"
	player.get_node("CollisionShape3D").disabled = true
	player.velocity = Vector3.ZERO
	var at: Vector3 = n.to_global(it.get("seat", Vector3.ZERO))
	var tw := player.create_tween().set_parallel()
	tw.tween_property(player, "global_position", at, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "rotation:y", n.rotation.y + PI, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player.head, "position:y", SEAT_EYE, 0.45).set_trans(Tween.TRANS_SINE)
	Sfx.play(&"step_wood", at, -6.0)

func _stand_up(instant := false) -> void:
	if _seat == null:
		return
	var n := _seat
	_seat = null
	var out := player.global_position + Vector3(0, 0.05, 0)
	if is_instance_valid(n):
		out = n.to_global(Vector3(0, 0.05, 0.75))
	player.head.position.y = 1.6 if instant else player.head.position.y
	if instant:
		player.global_position = out
	else:
		var tw := player.create_tween().set_parallel()
		tw.tween_property(player, "global_position", out, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player.head, "position:y", 1.6, 0.35).set_trans(Tween.TRANS_SINE)
		await tw.finished
	player.get_node("CollisionShape3D").disabled = false
	player.seated = false
	player.placing = false
	player.placing_prompt = ""

# ---------------------------------------------------------------- visiteurs
## Après une discussion : un visiteur remarque un objet qu'il aime (une fois par objet), +1 d'affection.
func after_visit(who: String) -> void:
	if who == "" or Story.is_animal(who):
		return
	var seen := {}
	for e in GameState.decor_placed:
		var id := String(e["id"])
		if seen.has(id):
			continue
		seen[id] = true
		var likes: Dictionary = item(id).get("likes", {})
		var flag := StringName("decor_vu_%s_%s" % [who, id])
		if likes.has(who) and not GameState.has_flag(flag):
			GameState.set_flag(flag)
			GameState.add_affection(who, 1, Story.affection_max(who))
			GameState.note(String(likes[who]))
			Events.toast.emit(String(likes[who]))
			return
