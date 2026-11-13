extends MorningTask
## Remplir la fontaine d'ablution, en trois gestes :
##  1. au puits, clic maintenu et souris tirée vers le bas : on hisse le seau à la corde (il redescend si on lâche) ;
##  2. on porte le seau : un virage brusque, un saut ou un choc font déborder l'eau (jauge du seau à l'écran) ;
##  3. à la fontaine, clic maintenu : on verse, le niveau monte. Ce qui a été renversé en route manque.

const PULL_PER_PX := 0.0012       # environ 830 pixels de souris pour hisser le seau
const SLIDE_BACK := 0.45          # le seau redescend si l'on lâche la corde (par seconde)
const POUR_RATE := 0.6            # part du seau versée par seconde
const BUCKET_TO_FILL := 0.55      # un seau plein remplit 55 % de la fontaine

var well: Node3D
var basin: Node3D
var water_node: Node3D
var water_base_y := 0.0
var fill := 1.0
var rope_prog := 0.0
var pulling := false
var well_bucket: Node3D
var stream: MeshInstance3D
var _told := false

func setup() -> void:
	well = props.get_node("Well")
	basin = props.get_node("WaterBasin")
	water_node = basin.find_child("water_surface", true, false)
	if water_node:
		water_base_y = water_node.position.y
	# seau qui remonte dans le puits pendant qu'on tire la corde
	well_bucket = game._model("bucket", Color("#8C7155"))
	well_bucket.scale = Vector3.ONE * 0.85
	well_bucket.visible = false
	well.add_child(well_bucket)
	for b in well_bucket.find_children("*", "CollisionObject3D", true, false):
		b.queue_free()
	# filet d'eau pendant qu'on verse
	stream = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.04
	cm.height = 1.0
	stream.mesh = cm
	stream.material_override = Toon.water_material()
	stream.visible = false
	props.add_child(stream)

	var wa: Interactable = game._make(well, Vector3(1.5, 1.3, 1.5), Vector3(0, 0.5, 0),
		func() -> String:
			if not active:
				return ""
			if player.tool != &"bucket":
				return "Il faudrait le seau"
			if player.bucket_level > 0.9:
				return "Le seau est plein"
			return "Maintenir le clic et tirer la souris vers le bas : hisser le seau",
		Callable(), _pull)
	wa.lock_look = true
	wa.release_fn = func(_p): pulling = false

	var ba: Interactable = game._make(basin, Vector3(1.6, 1.1, 1.1), Vector3(0, 0.45, 0),
		func() -> String:
			if not active or done():
				return ""
			if player.tool != &"bucket":
				return "La fontaine est basse (%d %%)" % int(fill * 100.0)
			if not player.bucket_full:
				return "Le seau est vide : retournez au puits"
			return "Maintenir le clic pour verser (%d %%)" % int(fill * 100.0),
		Callable(), _pour)
	ba.release_fn = func(_p): stream.visible = false

func hint() -> String:
	return "Fontaine : seau près du puits. Hissez-le à la corde, portez-le sans brusquer, versez."

func clear() -> void:
	fill = 1.0
	rope_prog = 0.0
	well_bucket.visible = false
	stream.visible = false
	_update_water()

func begin(_day: int) -> void:
	fill = randf_range(0.05, 0.18)
	_update_water()
	GameState.set_target(id, 100)
	GameState.add_progress(id, int(fill * 100.0))

func _update_water() -> void:
	if water_node:
		water_node.position.y = water_base_y - 0.12 * (1.0 - clampf(fill, 0.0, 1.0))

# ---------------------------------------------------------------- puits
func _pull(pl, _delta: float, motion: Vector2) -> void:
	if not active or pl.tool != &"bucket" or pl.bucket_level > 0.9:
		return
	pulling = true
	pl.action = &"pull"
	var before := rope_prog
	rope_prog = minf(rope_prog + maxf(motion.y, 0.0) * PULL_PER_PX, 1.0)
	if int(before * 4.0) != int(rope_prog * 4.0):
		Sfx.play(&"rope", well.global_position, -6.0)
		pl.kick(Vector3(0.18, 0, 0), Vector3(0, -0.05, 0.02), 0.05, 0.2)
	if rope_prog >= 1.0:
		rope_prog = 0.0
		pulling = false
		pl.set_bucket_level(1.0)
		Sfx.play(&"water_draw", well.global_position)
		if not _told:
			_told = true
			Events.toast.emit("Seau plein. Portez-le doucement : un virage brusque ou un saut fait déborder l'eau.")

func physics(delta: float) -> void:
	if not pulling and rope_prog > 0.0:
		rope_prog = maxf(rope_prog - SLIDE_BACK * delta, 0.0)
	well_bucket.visible = rope_prog > 0.01
	well_bucket.position = Vector3(0, lerpf(-1.3, 0.75, rope_prog), 0)
	well_bucket.rotation.y += delta * 0.6
	if stream.visible and player.lmb_down() == false:
		stream.visible = false

# ---------------------------------------------------------------- fontaine
func _pour(pl, delta: float, _motion: Vector2) -> void:
	if not active or done() or pl.tool != &"bucket" or not pl.bucket_full:
		stream.visible = false
		return
	pl.action = &"pour"
	var amount := minf(pl.bucket_level, POUR_RATE * delta)
	pl.set_bucket_level(pl.bucket_level - amount)
	var before := int(fill * 100.0)
	fill = minf(fill + amount * BUCKET_TO_FILL / 1.0, 1.0)
	_update_water()
	var after := int(fill * 100.0)
	if after > before:
		GameState.add_progress(id, after - before)
	# filet d'eau entre la main et le bassin
	var top: Vector3 = pl.camera.global_position + (-pl.camera.global_transform.basis.z) * 0.55 + Vector3(0, -0.25, 0)
	var bottom := basin.global_position + Vector3(0, 0.72, 0)
	if water_node:
		bottom = water_node.global_position
	var mid := (top + bottom) * 0.5
	var slen := top.distance_to(bottom)
	stream.visible = slen > 0.05
	if stream.visible:
		var up := (top - bottom).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up).normalized()
		stream.global_transform = Transform3D(Basis(side, up * slen, fwd), mid)
	Sfx.loop(&"pour_loop", true)
	if done():
		stream.visible = false
		Sfx.loop(&"pour_loop", false)
		Events.toast.emit("La fontaine est pleine. L'eau tremble à peine.")

func autoplay() -> void:
	game._equip(&"bucket")
	var guard := 0
	while not done() and guard < 20:
		guard += 1
		for k in 10:
			_pull(player, 0.016, Vector2(0, 200))
		for k in 60:
			_pour(player, 0.1, Vector2.ZERO)
			if not player.bucket_full or done():
				break
	stream.visible = false
	Sfx.loop(&"pour_loop", false)
	game.player_put_back_tool()
