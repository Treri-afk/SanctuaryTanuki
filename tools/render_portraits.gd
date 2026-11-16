extends SceneTree
## Rend les portraits visual novel d'un personnage à partir de son modèle VRM (VRoid).
## Un PNG transparent par expression, dans res://assets/portraits/<id>_<expression>.png
## (le nom que scenes/ui/vn_dialogue.gd charge automatiquement).
##
## Lancer avec rendu (pas --headless) :
##   godot --path . -s res://tools/render_portraits.gd -- fillette
## puis réimporter :  godot --headless --editor --quit --path .

## Expression de l'histoire (story.json) -> expression VRM.
const EXPRESSIONS := {
	"neutre": "neutral",
	"sourire": "happy",
	"triste": "sad",
	"surpris": "surprised",
	"fache": "angry",
	"calme": "relaxed",
}
const SIZE := Vector2i(800, 1200)
## Hauteur cadrée (mètres) : portrait en buste, du haut de la tête au milieu du ventre.
const FRAME_HEIGHT := 0.64

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame   # laisser l'arbre démarrer avant d'ajouter des nœuds
	var args := OS.get_cmdline_user_args()
	var who := args[0] if args.size() > 0 else "fillette"
	var Visitor: Script = load("res://scripts/placeholder_visitor.gd")
	if not Visitor.MODELS.has(who):
		printerr("Pas de modèle pour « %s » (voir MODELS dans scripts/placeholder_visitor.gd)" % who)
		quit(1)
		return

	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.92)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	# pas de lumière directe : avec le shader MToon elle crée des taches claires sur la peau.
	# L'ambiance seule donne un rendu à plat, propre, façon illustration.

	# le visiteur du jeu : même échelle, bras baissés
	var v: Node3D = Visitor.new()
	v.set("character_id", who)
	vp.add_child(v)
	v.set_process(false)   # pas de clignement pendant les captures

	if v.find_children("*", "Skeleton3D", true, false).is_empty():
		printerr("Modèle introuvable pour « %s »" % who)
		quit(1)
		return
	var skel: Skeleton3D = v.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = v.find_children("*", "AnimationPlayer", true, false)[0]
	await process_frame
	var head_y: float = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Head"))).origin.y
	var top := head_y + 0.2 * skel.global_transform.basis.get_scale().y

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = FRAME_HEIGHT
	cam.position = Vector3(0, top + 0.1 - FRAME_HEIGHT * 0.5, 3.0)   # marge au-dessus de la couette
	vp.add_child(cam)
	cam.current = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/portraits"))
	for expr in EXPRESSIONS:
		var anim := StringName(EXPRESSIONS[expr])
		if not ap.has_animation(anim):
			print("PORTRAIT ignoré : pas d'expression %s" % anim)
			continue
		ap.stop()
		ap.play(&"RESET")
		ap.advance(0.0)
		ap.play(anim)
		ap.seek(ap.current_animation_length, true)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := "res://assets/portraits/%s_%s.png" % [who, expr]
		img.save_png(ProjectSettings.globalize_path(path))
		print("PORTRAIT ", path)
	quit()
