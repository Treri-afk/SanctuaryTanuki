extends Node3D
## Shishi-odoshi de la mare (assets/models/shishi_odoshi.glb, posé par tools/build_world.gd) : le tube de bambou
## se remplit sous la goulotte, bascule quand il est plein, se vide dans la vasque, puis retombe et frappe la
## pierre : « toc », toutes les dix secondes environ. Le tube (nœud « tube ») pivote autour de son axe (X local).
## Au repos, le bout fermé (-Z) est posé sur la pierre ; basculé, la bouche (+Z) plonge vers la vasque.

const REST := -22.0         # degrés : bout fermé sur la pierre, bouche levée sous la goulotte
const TIPPED := 32.0        # bouche vers la vasque
const FILL := Vector2(8.0, 12.0)   # durée du remplissage (s)
const HEAR := 26.0          # au-delà, on ne joue pas le son

var _tube: Node3D
var _stream: MeshInstance3D

func _ready() -> void:
	_tube = find_child("tube", true, false) as Node3D
	if _tube == null:
		return
	_tube.rotation_degrees.x = REST
	# filet d'eau de la goulotte vers la bouche du tube
	_stream = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.007
	cm.bottom_radius = 0.01
	cm.height = 0.16
	cm.radial_segments = 6
	cm.rings = 1
	_stream.mesh = cm
	_stream.material_override = Toon.water_material()
	_stream.position = Vector3(0.0, 0.82, 0.5)
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stream)
	_cycle()

func _cycle() -> void:
	await get_tree().create_timer(randf_range(1.0, 4.0)).timeout
	while is_inside_tree():
		# remplissage : le tube s'alourdit, la bouche descend un peu, puis d'un coup il bascule
		var fill := randf_range(FILL.x, FILL.y)
		var tw := create_tween()
		tw.tween_property(_tube, "rotation_degrees:x", REST + 9.0, fill).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		tw = create_tween()
		tw.tween_property(_tube, "rotation_degrees:x", TIPPED, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		_sound(&"plop", -10.0)
		await get_tree().create_timer(0.55).timeout
		# vide, il retombe et frappe la pierre
		tw = create_tween()
		tw.tween_property(_tube, "rotation_degrees:x", REST, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		_sound(&"shishi", 0.0)
		tw = create_tween()
		tw.tween_property(_tube, "rotation_degrees:x", REST + 3.5, 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(_tube, "rotation_degrees:x", REST, 0.14).set_ease(Tween.EASE_IN)
		await tw.finished

func _sound(s: StringName, db: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var sfx := get_node_or_null(^"/root/Sfx")    # autoload (absent quand tools/build_world.gd charge ce script)
	if sfx == null or cam == null or cam.global_position.distance_to(global_position) > HEAR or not sfx.has(s):
		return
	sfx.play(s, global_position, db)
