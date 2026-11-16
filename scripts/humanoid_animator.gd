class_name HumanoidAnimator
extends Node
## Joue les animations Mixamo (assets/animations/*.fbx) sur un modèle VRM (VRoid).
## Un squelette Mixamo invisible joue l'animation ; à chaque image, on recopie sa pose sur le squelette
## du modèle, os par os, en rotations « monde » relatives à la pose de repos (les deux sont en pose en T,
## face à +Z) : ça marche quelles que soient les proportions du modèle.
## Le bassin garde sa hauteur animée mais jamais de déplacement horizontal : c'est le jeu qui déplace.

## Nom court -> fichier, et si l'animation boucle.
const ANIMS := {
	"idle": ["res://assets/animations/idle.fbx", true],
	"walk": ["res://assets/animations/walking.fbx", true],
	"pray": ["res://assets/animations/praying.fbx", false],
}
## Vitesse de marche d'origine de walking.fbx (m/s, squelette Mixamo d'1,80 m) : mesurée sur le pied d'appui.
const WALK_NATIVE_SPEED := 1.7
const BLEND := 0.25
## Dos voûté (réglage "stoop" de MODELS, 0 = droit, 1 = vieille personne) : inclinaison vers l'avant
## de chaque os du tronc, en degrés pour stoop = 1. Elle s'additionne en remontant le dos ; la tête
## se redresse en partie pour que le regard reste à peu près horizontal.
const STOOP := {"Spine": 7.0, "Chest": 6.0, "UpperChest": 6.0, "Neck": 6.0, "Head": -22.0}

## Os Mixamo -> os VRM (profil humanoïde de Godot), du bassin vers les extrémités.
const BONE_MAP := [
	["Hips", "Hips"], ["Spine", "Spine"], ["Spine1", "Chest"], ["Spine2", "UpperChest"],
	["Neck", "Neck"], ["Head", "Head"],
	["LeftShoulder", "LeftShoulder"], ["LeftArm", "LeftUpperArm"], ["LeftForeArm", "LeftLowerArm"], ["LeftHand", "LeftHand"],
	["RightShoulder", "RightShoulder"], ["RightArm", "RightUpperArm"], ["RightForeArm", "RightLowerArm"], ["RightHand", "RightHand"],
	["LeftUpLeg", "LeftUpperLeg"], ["LeftLeg", "LeftLowerLeg"], ["LeftFoot", "LeftFoot"], ["LeftToeBase", "LeftToes"],
	["RightUpLeg", "RightUpperLeg"], ["RightLeg", "RightLowerLeg"], ["RightFoot", "RightFoot"], ["RightToeBase", "RightToes"],
	["LeftHandThumb1", "LeftThumbMetacarpal"], ["LeftHandThumb2", "LeftThumbProximal"], ["LeftHandThumb3", "LeftThumbDistal"],
	["LeftHandIndex1", "LeftIndexProximal"], ["LeftHandIndex2", "LeftIndexIntermediate"], ["LeftHandIndex3", "LeftIndexDistal"],
	["LeftHandMiddle1", "LeftMiddleProximal"], ["LeftHandMiddle2", "LeftMiddleIntermediate"], ["LeftHandMiddle3", "LeftMiddleDistal"],
	["LeftHandRing1", "LeftRingProximal"], ["LeftHandRing2", "LeftRingIntermediate"], ["LeftHandRing3", "LeftRingDistal"],
	["LeftHandPinky1", "LeftLittleProximal"], ["LeftHandPinky2", "LeftLittleIntermediate"], ["LeftHandPinky3", "LeftLittleDistal"],
	["RightHandThumb1", "RightThumbMetacarpal"], ["RightHandThumb2", "RightThumbProximal"], ["RightHandThumb3", "RightThumbDistal"],
	["RightHandIndex1", "RightIndexProximal"], ["RightHandIndex2", "RightIndexIntermediate"], ["RightHandIndex3", "RightIndexDistal"],
	["RightHandMiddle1", "RightMiddleProximal"], ["RightHandMiddle2", "RightMiddleIntermediate"], ["RightHandMiddle3", "RightMiddleDistal"],
	["RightHandRing1", "RightRingProximal"], ["RightHandRing2", "RightRingIntermediate"], ["RightHandRing3", "RightRingDistal"],
	["RightHandPinky1", "RightLittleProximal"], ["RightHandPinky2", "RightLittleIntermediate"], ["RightHandPinky3", "RightLittleDistal"],
]

static var _library: AnimationLibrary   # partagée par tous les visiteurs

var _target: Skeleton3D
var _src_root: Node
var _src: Skeleton3D
var _ap: AnimationPlayer
var _pairs := []          # [index source, index cible, index parent cible]
var _src_rest := {}       # index source -> Basis globale de repos
var _tgt_rest := {}       # index cible -> Basis globale de repos
var _src_hips := -1
var _tgt_hips := -1
var _hips_ratio := 1.0
var _walk_scale := 1.0
var _stoop := {}         # index cible -> Basis d'inclinaison cumulée (dos voûté)

static func available() -> bool:
	for k in ANIMS:
		if not ResourceLoader.exists(String(ANIMS[k][0])):
			return false
	return true

static func _load_library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	for k in ANIMS:
		var scene: Node = (load(String(ANIMS[k][0])) as PackedScene).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
		a.loop_mode = Animation.LOOP_LINEAR if ANIMS[k][1] else Animation.LOOP_NONE
		_library.add_animation(StringName(k), a)
		scene.free()
	return _library

## target : squelette du modèle VRM (déjà mis à l'échelle par son nœud parent).
## stoop : dos voûté (0 = droit, 1 = vieille personne), voir STOOP.
func setup(target: Skeleton3D, stoop := 0.0) -> void:
	_target = target
	_src_root = (load(String(ANIMS["idle"][0])) as PackedScene).instantiate()
	add_child(_src_root)
	_src = _src_root.find_children("*", "Skeleton3D", true, false)[0]
	_ap = _src_root.find_children("*", "AnimationPlayer", true, false)[0]
	for lib in _ap.get_animation_library_list():
		_ap.remove_animation_library(lib)
	_ap.add_animation_library(&"", _load_library())
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_ap.animation_finished.connect(func(_n): play("idle"))
	var mapped := {}
	for p in BONE_MAP:
		var si := _src.find_bone("mixamorig_" + String(p[0]))
		var ti := _target.find_bone(String(p[1]))
		if si < 0 or ti < 0:
			continue
		_pairs.append([si, ti, _target.get_bone_parent(ti)])
		mapped[ti] = true
		_src_rest[si] = _src.get_bone_global_rest(si).basis.orthonormalized()
		_tgt_rest[ti] = _target.get_bone_global_rest(ti).basis.orthonormalized()
	_src_hips = _src.find_bone("mixamorig_Hips")
	_tgt_hips = _target.find_bone("Hips")
	if _src_hips >= 0 and _tgt_hips >= 0:
		_hips_ratio = _target.get_bone_global_rest(_tgt_hips).origin.y / maxf(0.01, _src.get_bone_global_rest(_src_hips).origin.y)
	if stoop > 0.0:
		_build_stoop(stoop)
	play("idle")

## Chaque os reçoit l'inclinaison de ses ancêtres du tronc (les rotations recopiées sont « monde » :
## sans ça, les bras et la tête ne suivraient pas le dos qui se penche).
func _build_stoop(amount: float) -> void:
	for p in _pairs:
		var ti: int = p[1]
		var angle := 0.0
		var b := ti
		while b >= 0:
			angle += float(STOOP.get(String(_target.get_bone_name(b)), 0.0))
			b = _target.get_bone_parent(b)
		if absf(angle) > 0.01:
			_stoop[ti] = Basis(Vector3.RIGHT, deg_to_rad(angle * amount))

## Vitesse de lecture de la marche pour avancer à speed m/s sans que les pieds glissent.
## Un petit personnage fait des pas plus courts : il doit les enchaîner plus vite pour suivre.
func set_walk_speed(speed: float) -> void:
	_walk_scale = clampf(speed / (WALK_NATIVE_SPEED * _hips_ratio * _model_scale()), 0.4, 2.0)

func _model_scale() -> float:
	return (_target.get_parent() as Node3D).scale.x if _target.get_parent() is Node3D else 1.0

func play(anim: String) -> void:
	if _ap == null or not _ap.has_animation(StringName(anim)):
		return
	if _ap.current_animation == anim and _ap.is_playing():
		return
	_ap.speed_scale = _walk_scale if anim == "walk" else 1.0
	_ap.play(StringName(anim), BLEND)

func length_of(anim: String) -> float:
	return _ap.get_animation(StringName(anim)).length if _ap and _ap.has_animation(StringName(anim)) else 0.0

func current() -> String:
	return String(_ap.current_animation) if _ap else ""

func _process(delta: float) -> void:
	if _ap == null or not is_instance_valid(_target):
		return
	_ap.advance(delta)
	var new_global := {}
	for p in _pairs:
		var si: int = p[0]
		var ti: int = p[1]
		var parent: int = p[2]
		# rotation (dans l'espace du squelette) qui amène l'os source de son repos à sa pose animée
		var d: Basis = _src.get_bone_global_pose(si).basis.orthonormalized() * (_src_rest[si] as Basis).inverse()
		var g: Basis = d * (_tgt_rest[ti] as Basis)
		if _stoop.has(ti):
			g = (_stoop[ti] as Basis) * g
		new_global[ti] = g
		var gp: Basis = new_global[parent] if new_global.has(parent) else \
			(_target.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY)
		_target.set_bone_pose_rotation(ti, (gp.inverse() * g).get_rotation_quaternion())
	if _src_hips >= 0 and _tgt_hips >= 0:
		var lift := (_src.get_bone_global_pose(_src_hips).origin.y - _src.get_bone_global_rest(_src_hips).origin.y) * _hips_ratio
		_target.set_bone_pose_position(_tgt_hips, _target.get_bone_rest(_tgt_hips).origin + Vector3(0, lift, 0))
