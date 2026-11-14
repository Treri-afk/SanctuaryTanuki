extends Node3D
## Visiteur dans le monde. Si le personnage a un modèle 3D (VRM exporté depuis VRoid, voir MODELS),
## on l'affiche ; sinon placeholder : rectangle de couleur + nom, toujours tourné vers la caméra.
@export var display_name := "Visiteur"
@export var color := Color(0.6, 0.5, 0.7)
@export var character_id := ""

## id du personnage (story.json) -> modèle VRM et taille voulue en mètres (le modèle est mis à l'échelle).
const MODELS := {
	"fillette": {"path": "res://assets/characters/hina/Hina.vrm", "height": 1.3},
}
## Angle (degrés) dont on baisse les bras : les modèles VRoid sont exportés en pose en T.
const ARM_DROP := 72.0

var _expressions: AnimationPlayer
var _blink_timer := 0.0

func _ready() -> void:
	var cfg: Dictionary = MODELS.get(character_id, {})
	if not cfg.is_empty() and ResourceLoader.exists(String(cfg["path"])):
		_build_model(cfg)
	else:
		_build_placeholder()

func _build_model(cfg: Dictionary) -> void:
	var model: Node3D = (load(String(cfg["path"])) as PackedScene).instantiate()
	add_child(model)
	var skel: Skeleton3D = null
	for s in model.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel:
		var head := skel.find_bone("Head")
		if head >= 0:
			# hauteur du modèle ≈ sommet de la tête (os Head + ~20 cm)
			var h := skel.get_bone_global_rest(head).origin.y + 0.2
			model.scale = Vector3.ONE * (float(cfg.get("height", h)) / h)
		_lower_arm(skel, "LeftUpperArm", "LeftHand")
		_lower_arm(skel, "RightUpperArm", "RightHand")
	for a in model.find_children("*", "AnimationPlayer", true, false):
		_expressions = a
		break
	_blink_timer = randf_range(1.5, 4.0)

## Fait pivoter le bras (dans l'espace du squelette) de la pose en T vers le bas, le long du corps.
func _lower_arm(skel: Skeleton3D, upper: String, hand: String) -> void:
	var ui := skel.find_bone(upper)
	var hi := skel.find_bone(hand)
	if ui < 0 or hi < 0:
		return
	var g_upper := skel.get_bone_global_rest(ui)
	var dir := (skel.get_bone_global_rest(hi).origin - g_upper.origin).normalized()
	var axis := dir.cross(Vector3.DOWN)
	if axis.length() < 0.01:
		return
	var turn := Basis(axis.normalized(), deg_to_rad(ARM_DROP))
	var parent := skel.get_bone_parent(ui)
	var p_basis := skel.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	var local := p_basis.inverse() * (turn * g_upper.basis)
	skel.set_bone_pose_rotation(ui, local.get_rotation_quaternion())

func _process(delta: float) -> void:
	if _expressions == null:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.5, 5.5)
		if _expressions.has_animation(&"blink"):
			_expressions.stop()
			_expressions.play(&"blink")

func _build_placeholder() -> void:
	set_process(false)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.8, 1.6)
	quad.mesh = qm
	quad.position.y = 0.8
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = m
	add_child(quad)
	var l := Label3D.new()
	l.text = display_name
	l.font_size = 48
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position.y = 0.8
	l.modulate = Color(0.1, 0.08, 0.12)
	l.outline_size = 0
	l.no_depth_test = true
	add_child(l)
