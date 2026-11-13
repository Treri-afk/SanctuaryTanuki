# Passe « beauté » : règles communes à tous les agents

Objectif fixé par l'auteur du jeu : **rendre le jeu le plus beau et le plus propre possible** (vent, lumière, eau, sols,
modèles), puis rendre les gestes agréables. Le jeu doit donner envie de s'arrêter pour regarder. Référence : décors de
Ghibli, *A Short Hike*, *Sable*, estampes japonaises d'automne. Lire aussi `docs/art-direction.md` et `docs/game-design.md`.

Plusieurs agents travaillent **en même temps** dans ce dossier. Rien n'est commité dans git : ne fais **aucun commit**,
aucun `git checkout`, `git stash` ni `git clean`.

## Qui possède quoi (ne modifie QUE tes fichiers)

| Agent | Fichiers |
|---|---|
| ATM (atmosphère, rendu) | `shaders/*` sauf `ground*` et `grass*` ; `scripts/toon.gd` ; `scripts/atmosphere.gd` ; nouveaux `scripts/atmo_*.gd` |
| GND (sols, petite végétation) | `scripts/terrain.gd` ; `scripts/forest.gd` ; `shaders/ground*.gdshader` ; `shaders/grass*.gdshader` ; `tools/blender/ground_*.py` et leurs modèles |
| ARCH-A, ARCH-B, NAT (modèles) | les scripts `tools/blender/*.py` de leurs modèles et leurs sorties (`assets/models`, `assets/blender`, `assets/previews`) |
| FEEL (gestes, animations) | `scripts/game.gd` ; `scripts/extras.gd` ; `scripts/interactable.gd` ; `scenes/player/*` ; `scenes/ui/*` ; nouveaux `scripts/feel_*.gd` |
| SFX (son) | `autoload/sfx.gd` ; nouveaux `scripts/sfx_*.gd` |
| Coordinateur (ne pas toucher) | `tools/build_world.gd`, `tools/blender/common.py`, `tools/*.sh`, `tools/model_view.gd`, `project.godot`, `scenes/main.tscn`, `scenes/world/shrine.tscn`, `autoload/game_state.gd`, `autoload/events.gd`, `data/*`, `docs/*` |

Si tu as besoin d'un changement dans un fichier qui n'est pas à toi (par exemple placer un nouveau modèle dans la scène,
ajouter un paramètre global), **ne le fais pas** : décris-le précisément dans ton rapport final, le coordinateur le fera.

## Interfaces figées (elles relient le travail des agents : ne pas les casser)

- **`Toon`** (`scripts/toon.gd`) : `kind_of`, `material`, `surface_material`, `water_material`, `apply`, `make_material`.
  Tout matériau du jeu passe par là (sauf le sol et l'herbe, qui ont leurs shaders). Ne dépend d'aucun autoload.
- **Teinte de sommet** : chaque `.glb` porte une couleur de sommet grise « Col » (occlusion ambiante + pied des objets
  assombri), calculée automatiquement à l'export par `common.export_glb`. Le shader toon la multiplie à l'albedo
  (`use_vertex_tint`). Réglages par script Blender : `common.TINT_AO`, `TINT_AO_DIST`, `TINT_GROUND`, `TINT_GROUND_H`.
- **Vent** : paramètres globaux de shader `wind_strength` (float, 1.0 = brise normale) et `wind_direction` (vec2, plan XZ),
  déclarés dans `project.godot`. Dans un shader : `global uniform float wind_strength; global uniform vec2 wind_direction;`.
- **Eau** : toutes les surfaces d'eau utilisent `Toon.water_material()`. Le ruban du ruisseau porte des UV :
  `UV.x` = travers (0 à 1), `UV.y` = distance le long du courant en mètres. Les mares et l'étang sont des disques sans UV utile :
  le shader d'eau doit donc aussi marcher en coordonnées monde.
- **`Atmosphere`** (`scripts/atmosphere.gd`, noeud « Atmosphere » de `shrine.tscn`) : `set_phase(phase, instant)` avec
  0 = matin, 1 = après-midi, 2 = soir. Le noeud trouve ses frères « Sun » et « WorldEnvironment ». Il est dans le groupe
  « atmosphere » et expose `gust(force)` : `get_tree().call_group("atmosphere", "gust", 1.0)` déclenche une bourrasque
  (feuilles qui s'envolent). Le niveau de vent courant se lit avec
  `RenderingServer.global_shader_parameter_get("wind_strength")`.
- **Éclairage toon partagé** : `shaders/toon_light.gdshaderinc` (propriété d'ATM) définit les uniforms d'ombrage et la
  fonction `light()`. Tout shader spatial du jeu (sol, herbe, eau) l'inclut avec
  `#include "res://shaders/toon_light.gdshaderinc"` au lieu de réécrire `light()`, pour que tout le décor réagisse pareil.
- **`Terrain`** (`scripts/terrain.gd`) : fonctions statiques `height`, `walk_y`, `hill`, `mesh_height`, `rect_dist`,
  `trail_dist`, `stream_dist`, `flat_dist`, `keep_clear` et constantes `TRAILS`, `FLATS`, `STREAM`, `POND`, `PREC_POND`,
  `ZEN`, `FLAT_X`, `FLAT_Z_MIN`, `STAIR_Z0`. Le plateau du sanctuaire reste à y = 0.
- **`Sfx`** (autoload) : `Sfx.play(&"nom", position_ou_null, volume_db)` et `Sfx.loop(&"nom", actif)`. Liste des noms dans
  `autoload/sfx.gd`. Un nom inconnu ne fait rien.
- **Noms dans les modèles** (le code du jeu les cherche) : `rope`, `bell`, `rope_anchor` (offering_box) ; `flame_anchor`
  (stone_lantern) ; `water_surface`, `ladle` (water_basin) ; `door` (hut) ; `ema_01..06`, `ema_slot_01..08` (ema_rack) ;
  `trunk` / `foliage` (arbres) ; les meshes dont le nom contient `foliage`, `leaves` ou `blades` bougent au vent, ceux qui
  contiennent `water` sont de l'eau, ceux qui contiennent `moss` n'ont pas de contour.
- Collisions des modèles : objets `<nom>-col` (boîte) ou `-convcol` dans Blender ; `common.py` les exporte en collision seule.

## Outils

- Blender 5.3 : `"/c/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" --background --python tools/blender/<script>.py`
- `tools/import.sh` : importe dans Godot les `.glb` nouveaux ou modifiés. **Seule façon autorisée de lancer un import**
  (il sérialise les imports ; ne lance jamais `--import` toi-même).
- `tools/model_shot.sh nom [yaw=35] [pitch=18] [zoom=1] [suffixe]` : rend un modèle seul avec le **vrai rendu du jeu**
  (toon + contours) dans `assets/previews/toon/<nom><suffixe>.png`. Lancer `tools/import.sh` avant si le `.glb` a changé.
  C'est cette image, pas la preview Blender, qui dit si un modèle est beau.
- `tools/shot.sh x y z yaw pitch nom [phase] [attente] [outil|vn]` : lance le vrai jeu, place le joueur, capture
  `assets/previews/ingame/<nom>.png`. `y` peut valoir `auto` (pose au sol). `yaw` : 0 regarde le nord (-Z, vers le
  pavillon), 90 l'ouest (-X), -90 l'est, 180 le sud. `pitch` positif regarde vers le haut. `phase` : 0 matin, 1 après-midi,
  2 soir (allume aussi les lanternes). `attente` en secondes (6 par défaut). Dernier argument : `broom`, `bucket`, `match`,
  `rake` (outil en main) ou `vn` (dialogue). **Préfixe tes captures** par ton sigle (`atm_`, `gnd_`, `feel_`...).
- Points de vue utiles (x, z, yaw) : entrée du sanctuaire (0, 8, 0) ; allée vers le torii (0, -8, 180) ; pavillon de près
  (0, -15, 0) ; salle de thé (12, -2.5, -90) ; jardin sec (-7, -10, 90) ; étang (-15, -18, 0) ; arbre sacré (9, -22, -70) ;
  bas de l'escalier (0, 33, 0, y = -5.5) ; sentier nord (0, -40, 0) ; belvédère (18, -83, 175) ; pont et ruisseau
  (-39, 5, 90) ; mare (-55, 3, 147) ; cabane (52, -15, -90).
- Test d'une journée complète (doit continuer à passer) :
  `"/c/Users/PA54F/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 800x450 -- --autoplay 2>&1 | grep -E "AUTOPLAY [^.]|SCRIPT ERROR"`
  (dernière ligne attendue : `AUTOPLAY jour 2 commencé`, environ 1 minute ; mets un `timeout 240`).
- Regarde toujours tes captures avec l'outil Read et critique-les sévèrement avant de continuer.

## Cohabitation

- D'autres agents modifient d'autres fichiers pendant que tu testes. Si une capture ou le jeu échoue avec une erreur qui
  vient d'un fichier qui n'est pas à toi, **ne le corrige pas** : attends 60 secondes et relance (jusqu'à 5 fois), puis
  signale-le dans ton rapport.
- Ne tue jamais des processus Godot ou Blender par leur nom (d'autres agents en ont en cours). Utilise `timeout`.
- Performance : le jeu doit rester au-dessus de 100 images par seconde en 1280x720 depuis l'entrée du sanctuaire
  (`tools/shot.sh` affiche `fps=`). Carte graphique de référence : RTX 4070 Super.
- N'ajoute aucun fichier binaire externe (textures, sons, polices téléchargés). Tout est généré par code ou par Blender.
  Les textures de bruit se font avec `NoiseTexture2D` / `FastNoiseLite` ou dans le shader.

## Rapport final attendu

Ce qui est fait et vérifié (avec les noms des captures qui le montrent), ce qui n'est pas fait ou pas vérifié, les
changements que tu demandes dans les fichiers des autres, et les défauts connus.
