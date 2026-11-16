class_name SaveGame
extends RefCounted
## Sauvegardes : trois emplacements dans user://saves/slot_<n>.save, au format texte natif de Godot (var_to_str :
## les types — entiers, StringName — sont conservés).
##
## On sauvegarde le soir, après le journal (et au début d'une nouvelle partie) : reprendre une partie relance le
## MATIN du jour enregistré. L'état d'une journée en cours (tâches à moitié faites, visiteur sur le chemin) ne
## se sauvegarde pas : c'est voulu, une journée est courte et se rejoue entière.
##
## Contenu : histoire (affection, drapeaux, visites, ema, liens), pièces, poches, goûts découverts, carpes,
## réserves de la boutique, décoration (possédée et posée), lettres lues, découvertes, statistiques de la partie, tâches de la veille.

const SLOTS := 3
const DIR := "user://saves/"
const VERSION := 1

## Champs de GameState sauvegardés tels quels.
const STATE_FIELDS := ["affection", "flags", "visited", "coins", "ema_log", "missed", "gone", "met", "inventory",
	"gift_known", "koi", "koi_state", "stock", "stats", "festival", "decor", "decor_placed"]

## Dossier des sauvegardes (les tests utilisent un dossier à part pour ne jamais toucher aux vraies parties).
static func dir() -> String:
	return "user://saves_test/" if OS.get_cmdline_user_args().has("--savetest") else DIR

static func path(slot: int) -> String:
	return dir() + "slot_%d.save" % slot

static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))

## Lit une sauvegarde ({} si absente ou illisible).
static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = str_to_var(f.get_as_text())
	return v if v is Dictionary and int(v.get("version", 0)) >= 1 else {}

## Résumé d'un emplacement pour les menus : jour, date, pièces, personnages rencontrés, démo finie.
static func info(slot: int) -> Dictionary:
	var d := read(slot)
	if d.is_empty():
		return {}
	var state: Dictionary = d.get("state", {})
	return {"day": int(d.get("day", 1)), "saved_at": String(d.get("saved_at", "")), "completed": bool(d.get("completed", false)),
		"coins": int(state.get("coins", 0)), "met": (state.get("met", {}) as Dictionary).size()}

## Emplacement de la sauvegarde la plus récente (-1 s'il n'y en a pas).
static func latest() -> int:
	var best := -1
	var best_t := ""
	for i in SLOTS:
		var inf := info(i)
		if not inf.is_empty() and String(inf["saved_at"]) > best_t:
			best_t = inf["saved_at"]
			best = i
	return best

## Instantané de la partie, à reprendre au matin du jour `day`.
static func capture(game: Node, day: int, completed := false) -> Dictionary:
	var state := {}
	for k in STATE_FIELDS:
		state[k] = (GameState.get(k) as Variant)
		if state[k] is Dictionary or state[k] is Array:
			state[k] = state[k].duplicate(true)
	var ex: Node = game.get("extras")
	return {
		"version": VERSION,
		"day": day,
		"completed": completed,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"state": state,
		"yesterday": (game.get("_yesterday") as Array).duplicate(),
		"extras": {"found": (ex.get("found") as Dictionary).duplicate(), "letters_read": int(ex.get("letters_read")),
			"cat_pets": int(ex.get("cat_pets")), "fox_done": bool(ex.get("fox_done")), "fox_hinted": bool(ex.get("fox_hinted"))},
	}

static func write(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir())
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("sauvegarde impossible : " + path(slot))
		return false
	f.store_string(var_to_str(data))
	return true

static func erase(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))

## Remet la partie dans l'état sauvegardé (avant de lancer le jour enregistré).
static func apply(game: Node, data: Dictionary) -> void:
	GameState.reset_story()
	var state: Dictionary = data.get("state", {})
	for k in STATE_FIELDS:
		if state.has(k):
			GameState.set(k, state[k])
	var y: Array[StringName] = []
	for t in data.get("yesterday", []):
		y.append(StringName(t))
	game.set("_yesterday", y)
	var ex: Node = game.get("extras")
	var e: Dictionary = data.get("extras", {})
	ex.set("found", (e.get("found", {}) as Dictionary).duplicate())
	ex.set("letters_read", int(e.get("letters_read", 0)))
	ex.set("cat_pets", int(e.get("cat_pets", 0)))
	ex.set("fox_done", bool(e.get("fox_done", false)))
	ex.set("fox_hinted", bool(e.get("fox_hinted", false)))
	# le présentoir retrouve les ema accrochés par les visiteurs (et par le gardien)
	for entry in GameState.ema_log:
		ex.call("hang_visitor_ema", String(entry["character"]))
	Events.coins_changed.emit(GameState.coins, 0)
