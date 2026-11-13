extends Node
## État global : jour, phase de la journée, flags d'histoire, progression des tâches.

enum Phase { MORNING, VISIT, EVENING, NIGHT }
const PHASE_NAMES := {Phase.MORNING: "Matin", Phase.VISIT: "Après-midi", Phase.EVENING: "Soir", Phase.NIGHT: "Nuit"}
const MAX_DAYS := 3

var day := 1
var phase: int = Phase.MORNING
var flags: Dictionary = {}
var affection: Dictionary = {}   # personnage -> affection (voir scripts/story.gd)
var visited: Dictionary = {}     # visites déjà jouées (id -> true)
var coins := 0                   # pièces du sanctuaire (offrandes des visiteurs)
## Lien avec chaque personnage, montré sur le mur des ema.
var ema_log: Array = []          # ema accrochés par les visiteurs : {character, wish, day}
var missed: Dictionary = {}      # personnage -> visites où on ne lui a pas parlé
var gone: Dictionary = {}        # personnages qui ne montent plus (leur ema s'est brisé)
var met: Dictionary = {}         # personnages déjà rencontrés
var inventory: Dictionary = {}   # objet -> nombre (récoltes, objets trouvés)
var gift_known: Dictionary = {}  # personnage -> {objet: palier} : goûts découverts en offrant
const INVENTORY_MAX := 12        # objets portés au total
var koi: Array = []              # carpes de l'étang : {pattern, size, name, days, seed}
var koi_state: Dictionary = {}   # fed_yesterday, streak (jours nourris d'affilée)
## Carnet de la journée, pour le journal du gardien (remis à zéro chaque matin).
## coins_in, coins_out, visitors [id personnage], affection {id: delta}, tasks [id], notes [texte]
var day_log: Dictionary = {}
var task_order: Array[StringName] = []
var today: Array[StringName] = []    # tâches obligatoires du jour (2 du matin tirées au hasard + lanternes + cloche)
var morning: Array[StringName] = []  # les 2 tâches du matin
var task_data: Dictionary = {}     # id -> TaskData
var progress: Dictionary = {}
var target: Dictionary = {}

func _ready() -> void:
	_load_tasks()
	_reset_log()
	reset_story()

## Remet l'affection et les drapeaux à leur état de départ (nouvelle partie).
func reset_story() -> void:
	Story.reload()
	affection = Story.initial_affection()
	visited.clear()
	flags.clear()
	coins = int(Story.settings().get("start_coins", 5))
	ema_log.clear()
	missed.clear()
	gone.clear()
	met.clear()
	inventory.clear()
	gift_known.clear()
	koi.clear()
	koi_state.clear()
	Events.coins_changed.emit(coins, 0)

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

func inventory_total() -> int:
	var n := 0
	for k in inventory:
		n += int(inventory[k])
	return n

## Ajoute un objet ; faux si les poches sont pleines.
func add_item(id: String, n: int = 1) -> bool:
	if n > 0 and inventory_total() + n > INVENTORY_MAX:
		Events.inventory_changed.emit(id, item_count(id), 0)
		return false
	inventory[id] = maxi(item_count(id) + n, 0)
	if int(inventory[id]) == 0:
		inventory.erase(id)
	Events.inventory_changed.emit(id, item_count(id), n)
	return true

func remove_item(id: String, n: int = 1) -> bool:
	if item_count(id) < n:
		return false
	return add_item(id, -n)

## État de l'ema d'un personnage : 0 intact, 1 fragile, 2 fissuré, 3 brisé (il ne monte plus).
## Il s'abîme quand l'affection devient négative ou qu'on laisse repartir le visiteur sans lui parler.
func ema_state(who: String) -> int:
	if gone.get(who, false):
		return 3
	var a := int(affection.get(who, 0))
	var m := int(missed.get(who, 0))
	if a <= -5 or m >= 3:
		return 3
	if a <= -3 or m >= 2:
		return 2
	if a < 0 or m >= 1:
		return 1
	return 0

## Fin de journée : un ema qui atteint l'état « brisé » fait partir le personnage pour de bon.
func update_bonds() -> void:
	for who in met:
		if not gone.get(who, false) and ema_state(who) >= 3:
			gone[who] = true
			note("L'ema de %s s'est brisé. Je crois que cette personne ne remontera plus." % Story.display_name(who))

## Fait revenir un personnage parti (prière de retour, à venir dans la boutique).
func bring_back(who: String) -> void:
	gone.erase(who)
	missed[who] = 0
	affection[who] = maxi(int(affection.get(who, 0)), 0)

func _reset_log() -> void:
	day_log = {"coins_in": 0, "coins_out": 0, "visitors": [], "affection": {}, "tasks": [], "notes": [], "harvest": 0}

## Ajoute des pièces (offrande d'un visiteur...).
func add_coins(n: int) -> void:
	if n <= 0:
		return
	coins += n
	day_log["coins_in"] = int(day_log.get("coins_in", 0)) + n
	Events.coins_changed.emit(coins, n)

## Dépense des pièces ; retourne faux (sans rien dépenser) s'il n'y en a pas assez.
func spend_coins(n: int) -> bool:
	if n > coins:
		Events.coins_changed.emit(coins, 0)   # montre le compteur : pas assez
		return false
	coins -= n
	day_log["coins_out"] = int(day_log.get("coins_out", 0)) + n
	Events.coins_changed.emit(coins, -n)
	return true

## Ligne libre pour le journal du soir (découverte, lettre lue...).
func note(text: String) -> void:
	(day_log["notes"] as Array).append(text)

func add_affection(who: String, delta: int, max_value: int = 10) -> void:
	var v := clampi(int(affection.get(who, 0)) + delta, -max_value, max_value)
	affection[who] = v
	var a: Dictionary = day_log.get("affection", {})
	a[who] = int(a.get(who, 0)) + delta
	day_log["affection"] = a
	Events.affection_changed.emit(who, v, delta)

func _load_tasks() -> void:
	var dir := DirAccess.open("res://data/tasks")
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		var fn := f.trim_suffix(".remap")
		if fn.ends_with(".tres"):
			var t: TaskData = load("res://data/tasks/" + fn)
			if t:
				task_data[t.id] = t
	# ordre d'affichage voulu
	for id in [&"balayer", &"fontaine", &"priere", &"reparer", &"haies", &"bambou", &"lanternes", &"cloche", &"ema", &"the", &"zen", &"carpes", &"renard", &"decouvertes"]:
		if task_data.has(id):
			task_order.append(id)

func begin_day(d: int) -> void:
	day = d
	_reset_log()
	phase = Phase.MORNING
	progress.clear()
	Events.day_started.emit(d)
	Events.phase_changed.emit(phase)

func set_phase(p: int) -> void:
	phase = p
	Events.phase_changed.emit(p)

func set_target(id: StringName, n: int) -> void:
	target[id] = n
	progress[id] = 0
	Events.task_progress.emit(id, 0, n)

func add_progress(id: StringName, n: int = 1) -> void:
	var before := is_done(id)
	progress[id] = mini(int(progress.get(id, 0)) + n, int(target.get(id, 1)))
	Events.task_progress.emit(id, progress[id], target.get(id, 1))
	if not before and is_done(id):
		(day_log.get("tasks", []) as Array).append(id)
		Events.task_done.emit(id)

## Avance une tâche d'un cran ; retourne vrai seulement si elle vient d'être terminée.
func add_progress_once(id: StringName) -> bool:
	if is_done(id):
		return false
	add_progress(id)
	return true

func is_done(id: StringName) -> bool:
	return int(progress.get(id, 0)) >= int(target.get(id, 1))

func bell_ready() -> bool:
	for id in today:
		if id != &"cloche" and not is_done(id):
			return false
	return true

func morning_done() -> bool:
	for id in morning:
		if not is_done(id):
			return false
	return true

## Tâche obligatoire qui n'est pas au programme d'aujourd'hui (le HUD la masque).
func is_off_today(id: StringName) -> bool:
	var t: TaskData = task_data.get(id)
	return t != null and t.required and not today.has(id)

func set_flag(f: StringName) -> void:
	if f != &"":
		flags[f] = true

func has_flag(f: StringName) -> bool:
	return f == &"" or flags.get(f, false)
