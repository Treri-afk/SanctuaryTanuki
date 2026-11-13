# Format de l'histoire (`data/story/story.json`)

L'histoire du jeu tient dans un seul fichier JSON, écrit par l'éditeur d'histoire
(`C:\Users\PA54F\Documents\programme\gardien-histoire`, application web séparée) et lu par le jeu (`scripts/story.gd`).
On peut aussi l'éditer à la main.

## Structure

```json
{
  "format": "gardien-story",
  "version": 1,
  "title": "Gardien de sanctuaire — automne",
  "settings": {
    "visits_per_day": [2, 3],      // nombre de visites tirées chaque jour (min, max)
    "first_visit_delay": [25, 50], // secondes avant le premier visiteur
    "visit_gap": [50, 100],        // secondes entre le départ d'un visiteur et l'arrivée du suivant
    "start_coins": 5,              // pièces au début de la partie
    "visitor_patience": 150        // secondes avant qu'un visiteur qu'on ignore ne reparte (affection -1, ema abîmé)
  },
  "spots": ["offrandes", "ema", "etang", "the", "jardin", "arbre", "torii"],
  "characters": [ ... ],
  "items": [ ... ],
  "visits": [ ... ]
}
```

### Personnage

| Clé | Rôle |
|---|---|
| `id` | identifiant (minuscules, sans espace) ; sert aussi au nom des portraits `assets/portraits/<id>_<expression>.png` |
| `name` | nom affiché |
| `color` | couleur du placeholder (`#RRGGBB`) |
| `expressions` | expressions disponibles (`neutre`, `sourire`...) |
| `affection_start`, `affection_max` | affection de départ et maximale (l'affection va de `-max` à `max`) |
| `coins` | pièces jetées dans le tronc à chaque visite (plus 1 par tranche de 3 points d'affection) ; une visite peut avoir sa propre valeur `coins` |
| `gifts` | goûts pour les cadeaux : `{"kaki": "love", "galet": "dislike"}` ; paliers `love` (+3), `like` (+1), `neutral` (0, par défaut), `dislike` (−1) |
| `gift_lines` | réaction à chaque palier : `{"love": "...", "like": "...", "neutral": "...", "dislike": "..."}` (sinon phrase par défaut) |
| `animal` | `true` pour un animal (renard, tanuki) : pas d'ema ni de carte au présentoir |
| `notes` | notes d'écriture, ignorées par le jeu |

### Visite

Une visite = un personnage qui monte au sanctuaire et le dialogue qu'on a avec lui.

| Clé | Rôle |
|---|---|
| `id` | identifiant unique |
| `kind` | `day` (visite de jour, par défaut) ou `night` (événement de nuit, voir plus bas) |
| `character` | personnage qui vient |
| `title` | titre (éditeur seulement) |
| `day_min`, `day_max` | jours où elle peut avoir lieu (0 = pas de limite) |
| `priority` | quand plus de visites sont possibles que de places, les plus prioritaires passent |
| `once` | jouée une seule fois dans la partie |
| `conditions` | conditions pour qu'elle puisse avoir lieu (voir plus bas) |
| `spot` | où le visiteur attend : `offrandes`, `ema`, `etang`, `the`, `jardin`, `arbre`, `torii` |
| `wish` | vœu écrit sur l'ema accroché en partant ("" = pas d'ema) |
| `start` | noeud de départ du dialogue |
| `nodes` | noeuds du dialogue, par identifiant |

Chaque jour, le jeu prend les visites possibles (jour, conditions, pas déjà jouées si `once`), garde au plus une
visite par personnage, trie par priorité, en garde 2 ou 3 (`visits_per_day`) et les fait arriver dans un ordre
aléatoire pendant que le joueur travaille.

### Objet

Les objets se ramassent dans la montagne (`settings.harvest_per_day` par matin, 12 par défaut) et s'offrent aux
visiteurs après leur dialogue. On porte 12 objets au plus.

| Clé | Rôle |
|---|---|
| `id`, `name`, `description` | identifiant, nom affiché, description |
| `shape` | forme dans le jeu : `kaki`, `chataigne`, `champignon`, `feuille`, `galet`, `plume`, `fleur`, `pomme_pin` |
| `color` | couleur |
| `zones` | où il apparaît : `enceinte`, `sentier`, `foret`, `mare`, `belvedere` |
| `weight` | fréquence relative (1 = rare) |

### Événements de nuit

Une visite de type `"kind": "night"` est jouée après la cloche du soir, quand la nuit tombe. Chaque nuit, le jeu
joue au plus un événement : le plus prioritaire parmi ceux qui sont possibles (jours, conditions, pas déjà joués),
au hasard entre ceux de même priorité (`settings.night_chance` : probabilité qu'il y en ait un, 1 par défaut).
`actor` choisit la créature qui sort de l'ombre avant le dialogue : `renard`, `tanuki`, `chat` ou `""` (aucune :
souvenir, narration). `spot` et `wish` sont ignorés.

### Noeuds de dialogue

Tous les noeuds ont `type`, et `x`, `y` (position dans l'éditeur).

- **`line`** (réplique) : `speaker` (id de personnage, `gardien` pour le joueur, `narrateur` pour la narration),
  `expr`, `text`, `next`, `effects`.
- **`choice`** (choix du joueur) : `text` (réplique facultative affichée au-dessus des choix), `speaker`,
  `choices` : liste de `{ "text", "next", "effects", "conditions" }`. Un choix dont les conditions sont fausses
  n'est pas proposé.
- **`branch`** (condition) : `rules` : liste de `{ "conditions", "next" }`, testées dans l'ordre ; `else` si
  aucune n'est vraie. Invisible pour le joueur.
- **`end`** (fin) : `effects` appliqués en fin de dialogue.

### Conditions (toutes doivent être vraies)

```json
{ "type": "affection", "character": "vieille_dame", "op": ">=", "value": 3 }
{ "type": "flag", "flag": "fumiko_revient", "is": true }
{ "type": "day", "op": ">=", "value": 2 }
{ "type": "visited", "visit": "kenta_j2", "is": true }
{ "type": "item", "item": "kaki", "op": ">=", "value": 1 }   // le joueur porte l'objet
{ "type": "coins", "op": ">=", "value": 5 }
```
`op` : `>=`, `<=`, `>`, `<`, `==`, `!=`.

### Effets

```json
{ "type": "affection", "character": "vieille_dame", "delta": 2 }
{ "type": "flag", "flag": "fumiko_revient", "value": true }
{ "type": "coins", "delta": -3 }      // pièces reçues (+) ou perdues (-)
{ "type": "item", "item": "kaki", "delta": -1 }   // objet reçu (+) ou donné (-)
```

Les drapeaux (flags) sont des marqueurs libres : un choix les pose, une condition les teste plus tard.
