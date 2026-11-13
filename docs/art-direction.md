# Direction artistique et règles techniques des modèles 3D

## Direction artistique
- **Ambiance** : décors de Ghibli, campagne japonaise en automne, calme et mélancolique. Lieu ancien, entretenu mais usé.
- **Style** : stylisé, pas réaliste. Formes simples et lisibles, proportions légèrement généreuses (toits épais, piliers trapus), bords biseautés (bevel) partout, aucune arête parfaitement vive.
- **Rendu** (fait dans Godot, pas dans Blender) : toon / cel shading 2-3 paliers, ombres bleu-violet, contours noirs fins (inverted hull). Pas de textures : **une couleur unie par matériau**, quelques matériaux par objet.
- **Palette** (clés de `PALETTE` dans `tools/blender/common.py`) : laque vermillon #C8442B (`lacquer_red`), bois sombre #5A3A26 (`wood_dark`), bois clair #A87B4F (`wood_light`), bois décoloré `wood_faded`, pierre #8E8A80 (`stone`, `stone_dark`), mousse #6F8A3E (`moss`), papier #EFE6D2 (`paper`), noir laqué #1E1E22 (`lacquer_black`), métal, bambou, feuillage #D9822B → #B8452A (`foliage_orange`, `foliage_red`).
- **Usure** : légère et crédible, suggérée par la forme et des variations de matériau : mousse à la base des pierres (petits volumes irréguliers en `moss`), bois un peu décoloré (`wood_faded`), pierres légèrement de travers ou ébréchées. Jamais de texture.
- **Détail** : vu de près à la première personne. Soigner volumes et proportions plutôt que multiplier les petits détails. Bevel `BEVEL_WIDTH` (0.025 m) partout : ne pas changer cette valeur, pour l'harmonie entre modèles.
- Éviter le look « assemblage de primitives » : varier les épaisseurs, ajouter des débords de toit, légers évasements (cylindres coniques), asymétries subtiles, chanfreins plus gros sur les pièces massives.

## Règles techniques
- Échelle réelle, 1 unité = 1 m. Origine **au sol, centrée**. Transformations appliquées. Avant = **-Y** Blender.
- Normales propres, Shade Smooth + Smooth by Angle (géré par `finish_model`), aucune face dupliquée ni n-gone non plan.
- Budget : 500 à 5 000 triangles par objet (balai et seau jusqu'à 3 000). Pour les kits modulaires (dalles, marche, muret) un module peut être sous 500 tris : passer `tri_limit=(50, 5000)` explicitement.
- Nommage `snake_case` anglais ; matériaux nommés par usage (utiliser `mat("wood_dark")` etc.).
- **Collisions** : mesh simplifié nommé `<nom>-col` (boîtes, `collision_box`) ou `-convcol` (convexe). Aucune collision sur feuillage, corde, eau, louche, plaquettes d'ema.
- Export glTF binaire `assets/models/<nom>.glb` + source `assets/blender/<nom>.blend`. Un fichier par modèle. Les pièces séparées sont des objets distincts nommés (ex. `rope`, `water_surface`, `ladle`, `leaves`) ; les points d'ancrage sont des Empties.
- Scripts dans `tools/blender/<nom>.py`, rejouables : `blender --background --python tools/blender/<nom>.py`.

## Contrôle qualité (obligatoire avant de rendre)
1. Prévisualisation `assets/previews/<nom>.png` (générée par `finish_model`).
2. Dimensions réelles vérifiées contre le tableau (`expected_dims` + sortie `MODEL_REPORT`).
3. Import Godot vérifié (voir CLAUDE-NOTES ci-dessous).
4. Regarder la preview avec un œil critique (outil Read sur le PNG) et corriger tout ce qui fait « assemblage de primitives » : proportions, bevel manquant, pièces flottantes ou mal interpénétrées. Itérer au moins 2 fois.

## Vérifier l'import Godot
```
"C:\Users\PA54F\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
"C:\Users\PA54F\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/check_model.gd -- res://assets/models/<nom>.glb
```
`tools/check_model.gd` affiche la taille (AABB), les collisions et les erreurs.
