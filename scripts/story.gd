class_name Story
extends RefCounted
## Histoire du jeu : personnages, visites et dialogues, lus dans data/story/story.json.
## Ce fichier est écrit par l'éditeur d'histoire (application web séparée, voir docs/story-format.md).
##
## Une visite = un personnage qui monte au sanctuaire un jour donné, sous conditions (affection, drapeaux, jour,
## visites passées), et un dialogue en graphe de noeuds : réplique (line), choix (choice), condition (branch), fin (end).

const PATH := "res://data/story/story.json"
const PLAYER := "gardien"      # locuteur : le joueur
const NARRATOR := "narrateur"  # locuteur : narration, sans nom ni portrait

static var data: Dictionary = {}
static var chars: Dictionary = {}

static func ensure_loaded() -> void:
	if data.is_empty():
		reload()

static func reload() -> void:
	data = {}
	chars = {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("Histoire introuvable : " + PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("Histoire illisible (JSON invalide) : " + PATH)
		return
	data = parsed
	for c in data.get("characters", []):
		chars[String(c.get("id", ""))] = c

static func settings() -> Dictionary:
	ensure_loaded()
	return data.get("settings", {})

static func setting_range(key: String, fallback: Vector2) -> Vector2:
	var v: Variant = settings().get(key, null)
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback

static func character(id: String) -> Dictionary:
	ensure_loaded()
	return chars.get(id, {})

static func display_name(id: String) -> String:
	if id == PLAYER:
		return "Vous"
	if id == NARRATOR:
		return ""
	return String(character(id).get("name", id))

static func color_of(id: String) -> Color:
	var c: String = character(id).get("color", "#9A8FB0")
	return Color.from_string(c, Color("#9A8FB0"))

## Valeur de départ de l'affection de chaque personnage.
static func initial_affection() -> Dictionary:
	ensure_loaded()
	var out := {}
	for id in chars:
		out[id] = int(chars[id].get("affection_start", 0))
	return out

## Pièces qu'un visiteur jette dans le tronc en arrivant : valeur de la visite, sinon du personnage (2 par
## défaut), plus 1 par tranche de 3 points d'affection.
static func offering_for(visit: Dictionary) -> int:
	var who := String(visit.get("character", ""))
	var base := int(visit.get("coins", character(who).get("coins", 2)))
	return maxi(base + int(floor(maxf(float(GameState.affection.get(who, 0)), 0.0) / 3.0)), 0)

static func affection_max(id: String) -> int:
	return int(character(id).get("affection_max", 10))

# ---------------------------------------------------------------- conditions et effets
static func _cmp(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
	return false

## Toutes les conditions doivent être vraies (liste vide = toujours vrai).
static func check(conds: Variant) -> bool:
	if not (conds is Array):
		return true
	for c in conds:
		var t := String(c.get("type", ""))
		match t:
			"affection":
				var who := String(c.get("character", ""))
				if not _cmp(float(GameState.affection.get(who, 0)), String(c.get("op", ">=")), float(c.get("value", 0))):
					return false
			"flag":
				if GameState.has_flag(StringName(String(c.get("flag", "")))) != bool(c.get("is", true)):
					return false
			"day":
				if not _cmp(float(GameState.day), String(c.get("op", ">=")), float(c.get("value", 1))):
					return false
			"visited":
				if bool(GameState.visited.get(String(c.get("visit", "")), false)) != bool(c.get("is", true)):
					return false
			"item":
				if not _cmp(float(GameState.item_count(String(c.get("item", "")))), String(c.get("op", ">=")), float(c.get("value", 1))):
					return false
			"coins":
				if not _cmp(float(GameState.coins), String(c.get("op", ">=")), float(c.get("value", 1))):
					return false
	return true

## Applique des effets ; retourne les changements d'affection [{character, delta}].
static func apply(effects: Variant) -> Array:
	var out := []
	if not (effects is Array):
		return out
	for e in effects:
		var t := String(e.get("type", ""))
		match t:
			"affection":
				var who := String(e.get("character", ""))
				var d := int(e.get("delta", 0))
				if who != "" and d != 0:
					GameState.add_affection(who, d, affection_max(who))
					out.append({"character": who, "delta": d})
			"item":
				var di := int(e.get("delta", 1))
				var iid := String(e.get("item", ""))
				if di > 0:
					GameState.add_item(iid, di)
				elif di < 0:
					GameState.remove_item(iid, mini(-di, GameState.item_count(iid)))
			"coins":
				var dc := int(e.get("delta", 0))
				if dc > 0:
					GameState.add_coins(dc)
				elif dc < 0:
					GameState.spend_coins(mini(-dc, GameState.coins))
			"flag":
				var fl := StringName(String(e.get("flag", "")))
				if bool(e.get("value", true)):
					GameState.set_flag(fl)
				else:
					GameState.flags.erase(fl)
	return out

# ---------------------------------------------------------------- visites
# ---------------------------------------------------------------- objets et cadeaux
## Paliers de goût d'un personnage pour un cadeau, et l'affection qu'ils donnent.
const GIFT_TIERS := {"love": 3, "like": 1, "neutral": 0, "dislike": -1}
const GIFT_TIER_NAMES := {"love": "adore", "like": "aime", "neutral": "sans plus", "dislike": "n'aime pas"}
const GIFT_DEFAULT_LINES := {
	"love": "Oh... C'est exactement ce qu'il me fallait. Merci, vraiment.",
	"like": "C'est gentil. Merci beaucoup.",
	"neutral": "Ah... merci. Je le garde.",
	"dislike": "Hm. Merci quand même...",
}

static func items() -> Array:
	ensure_loaded()
	return data.get("items", [])

static func item(id: String) -> Dictionary:
	for it in items():
		if String(it.get("id", "")) == id:
			return it
	return {}

static func item_name(id: String) -> String:
	return String(item(id).get("name", id))

## Palier de goût (love, like, neutral, dislike) d'un personnage pour un objet.
static func gift_tier(who: String, item_id: String) -> String:
	var g: Dictionary = character(who).get("gifts", {})
	return String(g.get(item_id, "neutral"))

static func gift_line(who: String, tier: String) -> String:
	var lines: Dictionary = character(who).get("gift_lines", {})
	var l := String(lines.get(tier, ""))
	return l if l != "" else String(GIFT_DEFAULT_LINES.get(tier, ""))

## Personnage-animal (renard, tanuki...) : pas d'ema, pas de carte au présentoir.
static func is_animal(id: String) -> bool:
	return bool(character(id).get("animal", false))

## Événement de nuit (visite de type « night ») joué après la cloche : un seul, le plus prioritaire parmi ceux
## qui sont possibles ce jour-là ; tirage au hasard entre ceux de même priorité. {} s'il n'y en a aucun.
static func night_for_day(day: int, rng: RandomNumberGenerator) -> Dictionary:
	ensure_loaded()
	if rng.randf() > float(settings().get("night_chance", 1.0)):
		return {}
	var best := []
	var best_p := -999999
	for v in data.get("visits", []):
		if String(v.get("kind", "day")) != "night":
			continue
		var dmin := int(v.get("day_min", 0))
		var dmax := int(v.get("day_max", 0))
		if (dmin > 0 and day < dmin) or (dmax > 0 and day > dmax):
			continue
		if bool(v.get("once", true)) and GameState.visited.get(String(v.get("id", "")), false):
			continue
		if not check(v.get("conditions", [])):
			continue
		var p := int(v.get("priority", 0))
		if p > best_p:
			best_p = p
			best = [v]
		elif p == best_p:
			best.append(v)
	if best.is_empty():
		return {}
	return best[rng.randi() % best.size()]

## Visites du jour, dans l'ordre d'arrivée. Une seule visite par personnage et par jour.
static func visits_for_day(day: int, rng: RandomNumberGenerator) -> Array:
	ensure_loaded()
	var eligible := []
	for v in data.get("visits", []):
		if String(v.get("kind", "day")) == "night":
			continue
		var dmin := int(v.get("day_min", 0))
		var dmax := int(v.get("day_max", 0))
		if dmin > 0 and day < dmin:
			continue
		if dmax > 0 and day > dmax:
			continue
		if bool(v.get("once", true)) and GameState.visited.get(String(v.get("id", "")), false):
			continue
		if not check(v.get("conditions", [])):
			continue
		if GameState.gone.get(String(v.get("character", "")), false):
			continue   # son ema s'est brisé : il ne monte plus
		eligible.append(v)
	eligible.shuffle()
	eligible.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var r := setting_range("visits_per_day", Vector2(2, 3))
	var want := rng.randi_range(int(r.x), int(r.y))
	var chosen := []
	var seen := {}
	for v in eligible:
		var who := String(v.get("character", ""))
		if seen.has(who):
			continue
		seen[who] = true
		chosen.append(v)
		if chosen.size() >= want:
			break
	# ordre d'arrivée : la plus prioritaire n'arrive pas forcément la première
	chosen.shuffle()
	return chosen
