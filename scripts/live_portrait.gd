class_name LivePortrait
extends SubViewportContainer
## Portrait visual novel en 3D, rendu en direct à partir du modèle VRM du personnage (VRoid).
## - les expressions passent de l'une à l'autre en fondu (poids des blend shapes interpolés) ;
## - chaque expression a sa pose du corps (POSES), atteinte en douceur ;
## - respiration, léger balancement, clignements, bouche qui bouge pendant que le texte s'écrit.
## Les modèles disponibles sont déclarés dans scripts/placeholder_visitor.gd (MODELS).

const VISITOR := preload("res://scripts/placeholder_visitor.gd")

## Expression de l'histoire (story.json) -> expression VRM.
const EXPR_MAP := {
	"neutre": "neutral",
	"sourire": "happy",
	"triste": "sad",
	"surpris": "surprised",
	"fache": "angry",
	"calme": "relaxed",
	"pensif": "relaxed",
	"inquiet": "sad",
	"gene": "relaxed",
	"penaud": "sad",
	"curieux": "surprised",
	"essouffle": "surprised",
}
## Expressions de l'histoire qui ont leur propre pose (sinon : la pose de l'expression VRM).
const EXPR_POSE := {
	"pensif": "pensif",
	"inquiet": "inquiet",
	"gene": "gene",
}
## Hauteur cadrée (mètres) pour un personnage de 1,30 m : portrait en buste, du haut de la tête
## au milieu du ventre. Proportionnelle à la taille du personnage.
const FRAME_HEIGHT := 0.64
## Durée du fondu entre deux expressions, et vitesse de passage d'une pose à l'autre.
const EXPR_FADE := 0.22
const POSE_SPEED := 5.0
## Part de la bouche qui parle retirée quand l'émotion ouvre déjà la bouche (0 = rien, 1 = tout).
const MOUTH_DAMP := 0.8

## Poses par expression. Rotations en degrés (X, Y, Z) dans le repère du personnage EN POSE EN T :
## X = vers sa gauche, Y = vers le haut, Z = vers l'avant. Ex. tête +X = baisse la tête ;
## bras gauche Z négatif = descend le long du corps, Y négatif = part vers l'avant ;
## avant-bras gauche Y négatif = plie le coude vers l'avant.
## Le côté droit est le miroir du gauche (X identique, Y et Z opposés) : on ne décrit que la gauche.
## Pour une pose asymétrique, une clé « Right... » remplace le miroir ; ses valeurs s'écrivent
## comme pour le bras gauche (elles sont retournées automatiquement).
const POSES := {
	"pensif": {   # tête inclinée et un peu baissée, mains jointes devant (les manches larges supportent mal les bras levés)
		"Spine": Vector3(1, 0, 0), "Neck": Vector3(3, 0, 0), "Head": Vector3(5, 0, -9),
		"LeftShoulder": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(0, -24, -74), "LeftLowerArm": Vector3(0, -52, 0), "LeftHand": Vector3(0, -8, 0),
	},
	"inquiet": {   # tête un peu basse, une main qui serre l'autre bras devant soi
		"Spine": Vector3(4, 0, 0), "Neck": Vector3(3, 0, 0), "Head": Vector3(7, 0, 3),
		"LeftShoulder": Vector3(0, -6, -2),
		"LeftUpperArm": Vector3(0, -26, -74), "LeftLowerArm": Vector3(0, -70, 0), "LeftHand": Vector3(0, -8, 0),
		"RightUpperArm": Vector3(0, -10, -76), "RightLowerArm": Vector3(0, -30, 0), "RightHand": Vector3(0, 0, 0),
	},
	"gene": {   # sourire gêné : tête penchée, main droite qui se gratte la nuque
		"Spine": Vector3(2, 0, 0), "Neck": Vector3(2, 0, 0), "Head": Vector3(6, 0, -8),
		"LeftShoulder": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(0, -6, -72), "LeftLowerArm": Vector3(0, -14, 0), "LeftHand": Vector3(0, 0, 0),
		"RightShoulder": Vector3(0, 0, 8),
		"RightUpperArm": Vector3(0, -50, 35), "RightLowerArm": Vector3(0, 11, 128), "RightHand": Vector3(0, 0, 10),
	},
	"neutral": {
		"Spine": Vector3(0, 0, 0), "Neck": Vector3(0, 0, 0), "Head": Vector3(0, 0, 0),
		"LeftShoulder": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(0, -6, -72), "LeftLowerArm": Vector3(0, -14, 0), "LeftHand": Vector3(0, 0, 0),
	},
	"happy": {   # tête penchée, mains jointes dans le dos
		"Spine": Vector3(-3, 0, 0), "Neck": Vector3(0, 0, 0), "Head": Vector3(-2, 0, 9),
		"LeftShoulder": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(0, 22, -68), "LeftLowerArm": Vector3(0, 48, 0), "LeftHand": Vector3(0, 0, 0),
	},
	"sad": {   # tête basse, épaules rentrées, mains jointes devant
		"Spine": Vector3(7, 0, 0), "Neck": Vector3(6, 0, 0), "Head": Vector3(12, 0, -4),
		"LeftShoulder": Vector3(0, -8, -4),
		"LeftUpperArm": Vector3(0, -28, -74), "LeftLowerArm": Vector3(0, -62, 0), "LeftHand": Vector3(0, -10, 0),
	},
	"surprised": {   # léger recul, mains levées devant la poitrine
		"Spine": Vector3(-6, 0, 0), "Neck": Vector3(-3, 0, 0), "Head": Vector3(-5, 0, 0),
		"LeftShoulder": Vector3(0, 0, 6),
		"LeftUpperArm": Vector3(0, -30, -62), "LeftLowerArm": Vector3(0, -105, 0), "LeftHand": Vector3(0, -12, 0),
	},
	"angry": {   # penchée en avant, bras tendus le long du corps
		"Spine": Vector3(4, 0, 0), "Neck": Vector3(2, 0, 0), "Head": Vector3(4, 0, 0),
		"LeftShoulder": Vector3(0, 0, 4),
		"LeftUpperArm": Vector3(0, 4, -80), "LeftLowerArm": Vector3(0, -6, 0), "LeftHand": Vector3(0, 0, 0),
	},
	"relaxed": {
		"Spine": Vector3(-1, 0, 0), "Neck": Vector3(0, 0, 0), "Head": Vector3(2, 0, -6),
		"LeftShoulder": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(0, -12, -70), "LeftLowerArm": Vector3(0, -30, 0), "LeftHand": Vector3(0, 0, 0),
	},
}

## Le personnage parle (le texte s'écrit) : la bouche bouge.
var talking := false

var _vp: SubViewport
var _skel: Skeleton3D
var _expr_shapes := {}       # nom d'expression VRM -> [[MeshInstance3D, index, valeur], ...]
var _all_shapes := []        # [MeshInstance3D, index] touchés par au moins une expression
var _weights := {}           # expression d'émotion -> poids courant (0..1)
var _target := "neutral"
var _pose_name := "neutral"
var _stoop := 0.0
var _bones := {}             # nom d'os (droite et gauche) -> index
var _rest := {}              # index -> base globale au repos
var _pose_now := {}          # index -> Quaternion courant (repère du personnage)
var _t := 0.0
var _blink_wait := 2.0
var _blink := 0.0
var _blink_phase := -1.0
var _mouth := 0.0

static func has_model(id: String) -> bool:
	return VISITOR.MODELS.has(id) and ResourceLoader.exists(String(VISITOR.MODELS[id]["path"]))

## Construit le portrait de ce personnage. À appeler une fois, avant d'ajouter le nœud à la scène.
func setup(id: String) -> void:
	var cfg: Dictionary = VISITOR.MODELS[id]
	_stoop = float(cfg.get("stoop", 0.0))
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)

	# éclairage d'ambiance seul : avec le shader MToon une lumière directe tache la peau
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.92)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	var model: Node3D = (load(String(cfg["path"])) as PackedScene).instantiate()
	_vp.add_child(model)
	for s in model.find_children("*", "Skeleton3D", true, false):
		_skel = s
		break
	var top := 1.6
	if _skel:
		var head := _skel.find_bone("Head")
		var h := _skel.get_bone_global_rest(head).origin.y + 0.2
		var k := float(cfg.get("height", h)) / h
		model.scale = Vector3.ONE * k
		top = h * k
		for side in ["Left", "Right"]:
			for b in ["Shoulder", "UpperArm", "LowerArm", "Hand"]:
				_add_bone(side + b)
		for b in ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
			_add_bone(b)
	for a in model.find_children("*", "AnimationPlayer", true, false):
		_read_expressions(a as AnimationPlayer)
		(a as AnimationPlayer).stop()
		break
	for e in EXPR_MAP.values():
		_weights[e] = 1.0 if e == "neutral" else 0.0
	_apply_pose(POSES["neutral"], 1.0)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var frame := FRAME_HEIGHT * top / 1.3
	cam.size = frame
	cam.position = Vector3(0, top + 0.2 * frame - frame * 0.5, 3.0)   # marge : la couette dépasse quand elle lève la tête
	_vp.add_child(cam)
	cam.current = true

## Change d'expression (nom de story.json : neutre, sourire, triste...). Le fondu se fait tout seul.
func set_expression(expr: String) -> void:
	_target = String(EXPR_MAP.get(expr, "neutral"))
	if not _expr_shapes.has(_target):
		_target = "neutral"
	_pose_name = String(EXPR_POSE.get(expr, _target))

func _add_bone(n: String) -> void:
	var i := _skel.find_bone(n)
	if i < 0:
		return
	_bones[n] = i
	_rest[i] = _skel.get_bone_global_rest(i).basis.orthonormalized()
	_pose_now[i] = Quaternion.IDENTITY

## Lit les expressions VRM (animations d'une image qui règlent des blend shapes) pour les doser nous-mêmes.
func _read_expressions(ap: AnimationPlayer) -> void:
	var base := ap.get_node(ap.root_node)
	var seen := {}
	for an in ap.get_animation_list():
		if an == &"RESET":
			continue
		var a := ap.get_animation(an)
		var list := []
		for t in a.get_track_count():
			if a.track_get_key_count(t) == 0:
				continue
			var p := a.track_get_path(t)
			var mi := base.get_node_or_null(NodePath(p.get_concatenated_names())) as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var shape := ""
			if a.track_get_type(t) == Animation.TYPE_BLEND_SHAPE:
				shape = String(p.get_concatenated_subnames())
			elif a.track_get_type(t) == Animation.TYPE_VALUE and String(p.get_concatenated_subnames()).begins_with("blend_shapes/"):
				shape = String(p.get_concatenated_subnames()).trim_prefix("blend_shapes/")
			else:
				continue
			var idx := mi.find_blend_shape_by_name(StringName(shape))
			if idx < 0:
				continue
			var val := float(a.track_get_key_value(t, a.track_get_key_count(t) - 1))
			list.append([mi, idx, val])
			var key := "%d:%d" % [mi.get_instance_id(), idx]
			if not seen.has(key):
				seen[key] = true
				_all_shapes.append([mi, idx])
		_expr_shapes[String(an)] = list

func _process(delta: float) -> void:
	if _skel == null or not is_visible_in_tree():
		return
	_t += delta
	# expressions : chaque émotion glisse vers 1 (la cible) ou vers 0
	for e in _weights:
		_weights[e] = move_toward(_weights[e], 1.0 if e == _target else 0.0, delta / EXPR_FADE)
	# clignement : fermeture/ouverture rapide, à intervalles irréguliers
	if _blink_phase < 0.0:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_phase = 0.0
	else:
		_blink_phase += delta / 0.16
		_blink = sin(minf(_blink_phase, 1.0) * PI)
		if _blink_phase >= 1.0:
			_blink_phase = -1.0
			_blink = 0.0
			_blink_wait = randf_range(2.2, 5.0)
	# bouche : s'ouvre et se ferme pendant que le texte s'écrit
	var mouth_goal := (0.25 + 0.55 * absf(sin(_t * 13.0)) * (0.6 + 0.4 * sin(_t * 5.3))) if talking else 0.0
	_mouth = lerpf(_mouth, mouth_goal, minf(1.0, delta * 18.0))
	_apply_shapes()
	_apply_pose(POSES.get(_pose_name, POSES["neutral"]), minf(1.0, delta * POSE_SPEED))

func _apply_shapes() -> void:
	var acc := {}
	var add := func(expr: String, w: float):
		if w <= 0.001 or not _expr_shapes.has(expr):
			return
		for s in _expr_shapes[expr]:
			var key := "%d:%d" % [s[0].get_instance_id(), s[1]]
			acc[key] = float(acc.get(key, 0.0)) + w * float(s[2])
	for e in _weights:
		add.call(e, _weights[e])
	# les émotions aux yeux fermés (joie) n'ont pas besoin de clignement
	add.call("blink", _blink * (1.0 - float(_weights.get("happy", 0.0))))
	# bouche qui parle : réduite quand l'émotion ouvre déjà la bouche (joie, surprise),
	# sinon les deux ouvertures s'additionnent et les dents passent devant les lèvres
	var open_already := clampf(float(_weights.get("happy", 0.0)) + float(_weights.get("surprised", 0.0)), 0.0, 1.0)
	var talk := _mouth * (1.0 - MOUTH_DAMP * open_already)
	add.call("aa", talk * 0.75)
	add.call("oh", talk * 0.25)
	for s in _all_shapes:
		var mi: MeshInstance3D = s[0]
		mi.set_blend_shape_value(s[1], clampf(float(acc.get("%d:%d" % [mi.get_instance_id(), s[1]], 0.0)), 0.0, 1.0))

## Approche la pose cible. Rotation q (repère du personnage) d'un os : pose locale = Gp⁻¹ · q · Gb
## (Gp, Gb : bases globales au repos du parent et de l'os). Le parent tourne avec, l'os suit.
func _apply_pose(pose: Dictionary, k: float) -> void:
	var breath := sin(_t * 1.7)
	var sway := sin(_t * 0.6)
	for n in _bones:
		var i: int = _bones[n]
		var right := String(n).begins_with("Right")
		var src := String(n).replace("Right", "Left")
		var key := String(n) if pose.has(String(n)) else src   # « Right... » explicite : pose asymétrique
		var e: Vector3 = pose.get(key, POSES["neutral"].get(src, Vector3.ZERO))
		if right:
			e = Vector3(e.x, -e.y, -e.z)
		e.x += float(HumanoidAnimator.STOOP.get(String(n), 0.0)) * _stoop
		match String(n):
			"Chest": e += Vector3(-1.2 * breath, 0, 0)
			"UpperChest": e += Vector3(-0.8 * breath, 0, 0)
			"Spine": e += Vector3(0, 0, 1.2 * sway)
			"Head": e += Vector3(0.8 * sin(_t * 0.9), 1.5 * sin(_t * 0.45), -0.8 * sway)
			"LeftShoulder": e += Vector3(0, 0, 0.8 * breath)
			"RightShoulder": e += Vector3(0, 0, -0.8 * breath)
		var goal := Quaternion.from_euler(e * (PI / 180.0))
		var q: Quaternion = (_pose_now[i] as Quaternion).slerp(goal, k)
		_pose_now[i] = q
		var parent := _skel.get_bone_parent(i)
		var gp: Basis = _skel.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		var local := gp.inverse() * (Basis(q) * (_rest[i] as Basis))
		_skel.set_bone_pose_rotation(i, local.get_rotation_quaternion())
