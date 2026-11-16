class_name Guide
extends Node
## Premier jour guidé : une vraie journée, simplement accompagnée.
##
## - Une lettre de Seiji, l'ancien gardien, accueille le joueur et pose le rythme d'une journée.
## - Un objectif courant (une ligne en haut de l'écran) dit quoi faire maintenant, avec la commande utile
##   à ce moment-là, et un repère doré montre où aller (flèche au bord de l'écran si c'est hors champ).
## - Le matin est fixé et court : balayer l'allée près de l'entrée (version allégée) et la prière du matin.
## - Les visiteurs n'arrivent qu'une fois le matin terminé ; la liste des activités facultatives n'apparaît
##   que l'après-midi ; lanternes et cloche n'apparaissent dans la liste qu'au soir.
##
## Les étapes s'évaluent à chaque image : si le joueur fait les choses dans le désordre (prend le balai avant
## d'avoir monté l'escalier...), les étapes déjà accomplies sont simplement sautées.
## Actif au jour 1 d'une partie lancée normalement ; désactivé par les modes de test (--shot, --autoplay,
## --tasks...) sauf avec --guide ; --noguide le coupe.

const MORNING_TASKS: Array[StringName] = [&"balayer", &"priere"]
const TORII := Vector3(0.0, 2.2, 11.2)
const LETTER_TITLE := "Une lettre glissée sous la porte du bureau"
const LETTER := "À toi qui arrives,\n\nLe sanctuaire est à toi maintenant. Rien de compliqué : le matin, on entretient le lieu. L'après-midi, on accueille ceux qui montent prier. Le soir, on allume les lanternes et on sonne la cloche.\n\nPour ce premier matin, balaie l'allée puis fais la prière. Le balai t'attend en haut des marches, près de l'entrée.\n\nPrends ton temps. La montagne n'est jamais pressée.\n\n— Seiji"

var game: Node3D
var active := false
var step := 0
var _steps: Array = []
var _last_text := ""

func setup(g: Node3D) -> void:
	game = g
	_steps = [
		{"text": func(): return "Montez l'escalier jusqu'au grand torii",
		 "keys": "ZQSD : marcher    souris : regarder",
		 "target": func(): return TORII,
		 "done": func(): return _player().global_position.z < 12.5 or _player().tool != &""},
		{"text": func(): return "Prenez le balai, contre le muret à droite de l'entrée",
		 "keys": "Visez-le, puis E : prendre",
		 "target": func(): return (game.tool_nodes[&"broom"] as Node3D).global_position + Vector3(0, 1.1, 0),
		 "done": func(): return _player().tool == &"broom" or GameState.is_done(&"balayer")},
		{"text": func(): return "Poussez le tas jusqu'au panier" if _leaves().pushing_pile() else "Balayez les feuilles de l'allée",
		 "keys": "Clic maintenu en avançant : les feuilles s'amassent devant le balai",
		 "target": _leaf_target,
		 "done": func(): return GameState.is_done(&"balayer")},
		{"text": func(): return "Reposez le balai",
		 "keys": "R : reposer l'outil (il retourne à sa place)",
		 "target": func(): return null,
		 "done": func(): return _player().tool != &"broom"},
		{"text": func(): return "" if _prayer().praying else "Faites la prière du matin devant le tronc à offrandes, au fond de l'allée",
		 "keys": "Arrivé devant, E : commencer la prière",
		 "target": func(): return null if _prayer().praying else _box() + Vector3(0, 1.5, 1.1),
		 "done": func(): return GameState.is_done(&"priere")},
		{"text": _visit_text,
		 "keys": "E : parler    (pendant un dialogue, clic pour continuer)",
		 "target": func(): return _visitor_pos() if game.visitor != null and game._visitor_ready_flag else null,
		 "done": func(): return not (GameState.day_log.get("visitors", []) as Array).is_empty()},
		{"text": func(): return "L'après-midi est à vous : la liste en haut à gauche propose de quoi flâner",
		 "keys": "Les pièces des offrandes se dépensent au bureau du sanctuaire, à l'ouest de la cour.",
		 "target": func(): return null,
		 "done": func(): return GameState.phase >= GameState.Phase.EVENING},
		{"text": func(): return "Le soir tombe. Prenez les allumettes, sur le petit socle près du puits",
		 "keys": "E : prendre",
		 "target": func(): return (game.tool_nodes[&"match"] as Node3D).global_position + Vector3(0, 0.7, 0),
		 "done": func(): return _player().tool == &"match" or GameState.is_done(&"lanternes")},
		{"text": func(): return "Allumez les lanternes de l'allée  (%d / %d)" % [GameState.progress.get(&"lanternes", 0), game.lanterns.size()],
		 "keys": "Visez une lanterne, E ou clic",
		 "target": func(): return _next_lantern(),
		 "done": func(): return GameState.is_done(&"lanternes")},
		{"text": func(): return "Sonnez la cloche du tronc à offrandes pour finir la journée",
		 "keys": "E : sonner la cloche",
		 "target": func(): return _box() + Vector3(0, 2.2, 0.3),
		 "done": func(): return game._ending},
	]

static func wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--noguide"):
		return false
	if args.has("--guide"):
		return true
	for a in args:
		if a.begins_with("--"):
			return false     # modes de test : pas de guide sauf demande explicite
	return true

## Début du premier jour guidé (avant le tirage des tâches).
func start() -> void:
	active = true
	step = 0
	_last_text = ""
	GameState.guide = true
	(game.tasks[&"balayer"] as MorningTask).set("light", true)

## Fin du guide : le lendemain matin, tout redevient normal.
func stop() -> void:
	active = false
	GameState.guide = false
	(game.tasks[&"balayer"] as MorningTask).set("light", false)
	game.hud.set_objective("", "")
	game.hud.set_marker(null)
	game.hud.keep_help(false)

## Après la carte « Jour 1 » : la lettre de Seiji, puis le premier objectif.
func welcome() -> void:
	await game.get_tree().create_timer(0.9).timeout
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay") or (not args.is_empty() and args[0] == "--shot"):
		game.hud.keep_help(true)
		return      # tests : pas de lettre qui attend un clic
	game.player.input_enabled = false
	await game.hud.show_note(LETTER_TITLE, LETTER)
	GameState.note("Une lettre de Seiji m'attendait. Le sanctuaire est à moi, maintenant.")
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.hud.keep_help(true)

func _process(_dt: float) -> void:
	if not active:
		return
	while step < _steps.size() and (_steps[step]["done"] as Callable).call():
		step += 1
		game.hud.pulse()
		if OS.get_cmdline_user_args().has("--autoplay"):
			print("GUIDE étape %d / %d" % [step, _steps.size()])
		if step == 3:
			game.hud.keep_help(false)      # les commandes de base sont acquises
	if step >= _steps.size():
		game.hud.set_objective("", "")
		game.hud.set_marker(null)
		return
	var shot := not OS.get_cmdline_user_args().is_empty() and OS.get_cmdline_user_args()[0] == "--shot"
	var busy: bool = (not game.player.input_enabled and not shot) or game.vn.visible
	var s: Dictionary = _steps[step]
	var text: String = (s["text"] as Callable).call()
	var keys: String = s["keys"]
	var target: Variant = (s["target"] as Callable).call()
	# un visiteur qui attend passe avant le reste (sauf pendant le rite ou au soir)
	if step > 5 and step < 7 and game.visitor != null and game._visitor_ready_flag:
		text = "%s vous attend : allez lui parler" % _visitor_name()
		keys = "E : parler"
		target = _visitor_pos()
	if busy:
		text = ""
	game.hud.set_objective(text, keys if text != "" else "")
	game.hud.set_marker(target if text != "" else null)

func _leaf_target() -> Variant:
	var t: Variant = _leaves().guide_target(_player().global_position)
	return null if t == null else (t as Vector3) + Vector3(0, 0.6, 0)

func _visit_text() -> String:
	if game.visitor == null:
		return "Le matin est fini. Quelqu'un ne va pas tarder à monter prier"
	if not game._visitor_ready_flag:
		return "Un visiteur monte l'escalier : il prie d'abord au tronc à offrandes"
	return "%s vous attend : allez lui parler" % _visitor_name()

# ---- raccourcis
func _player() -> CharacterBody3D:
	return game.player

func _leaves() -> MorningTask:
	return game.tasks[&"balayer"]

func _prayer() -> MorningTask:
	return game.tasks[&"priere"]

func _box() -> Vector3:
	return (game.props.get_node("OfferingBox") as Node3D).global_position

func _visitor_name() -> String:
	return Story.display_name(String(game.visit_current.get("character", "")))

func _visitor_pos() -> Vector3:
	return (game.visitor as Node3D).global_position + Vector3(0, 2.1, 0)

func _next_lantern() -> Variant:
	var from: Vector3 = _player().global_position
	var best: Variant = null
	for i in game.lanterns.size():
		if game.lit.get(i, false):
			continue
		var p: Vector3 = (game.lanterns[i] as Node3D).global_position + Vector3(0, 1.6, 0)
		if best == null or p.distance_to(from) < (best as Vector3).distance_to(from):
			best = p
	return best
