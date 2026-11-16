# Tanuki Sanctuary (prototype)

Godot 4.7, Forward+. Lancer `scenes/main.tscn` (scène principale du projet).

**Contrôles** : ZQSD / WASD, souris, E ou clic = agir, clic maintenu = geste de l'outil, R = reposer l'outil,
Tab maintenu = HUD complet (pièces), Échap = pause (options, retour à l'écran titre). Tests : Espace = saut, F = vol libre (Espace / Maj = monter / descendre).

**Menus et sauvegardes** : le jeu s'ouvre sur l'écran titre (continuer, nouvelle partie, charger, options, quitter).
Trois emplacements de sauvegarde (`user://saves/`, sur Mac `~/Library/Application Support/TanukiSanctuary/saves/` ; `scripts/save_game.gd`) ; la partie se sauvegarde chaque soir après le
journal et reprend au matin du jour suivant. Échap ouvre la pause (options, retour au titre). Options enregistrées dans
`user://settings.cfg` (`autoload/settings.gd`) : volumes, souris, balancement de tête, qualité, résolution 3D, plein écran.
Après le troisième jour : écran de fin de démo avec le bilan de la partie (`scenes/ui/menus.gd`).

**Premier jour** : guidé (lettre de Seiji, objectif courant, repère doré), matin fixé : feuilles de l'allée et prière.

**Journée** : matin (2 tâches tirées au hasard, jamais les mêmes deux jours de suite si possible) -> après-midi (un
visiteur, dialogue visual novel) -> soir (allumettes + 8 lanternes, puis cloche) -> jour suivant (5 jours, jusqu'à Tsukimi, la fête de la lune : voir `scripts/festival.gd` ; le soir de la fête, quatre stands de mini-jeux : `scripts/stalls/`).

**Tâches du matin** (`scripts/tasks/`, liste dans `TASKS` de `scripts/game.gd`) :
- feuilles : balai, clic maintenu en marchant, le tas grossit devant le balai ; le pousser jusqu'à un panier (3 paniers).
  Un tas abandonné peut être dispersé par une bourrasque ;
- fontaine : au puits, clic maintenu et souris tirée vers le bas pour hisser le seau ; le porter sans virage brusque ni
  saut (l'eau déborde) ; clic maintenu à la fontaine pour verser ;
- prière : devant le tronc à offrandes, rite pièce, deux saluts (baisser le regard), deux frappes (clic), un salut ;
- palissade : remettre trois planches (E), enfoncer les clous au marteau en frappant quand le cercle touche le viseur ;
- haies : cisaille, clic maintenu en passant le viseur sur les rameaux qui dépassent ;
- bambous : serpe, viser une pousse au bord de l'étang, clic maintenu puis geste vif de la souris sur le côté.
Marteau, cisaille et serpe sont sur l'établi près du bureau du sanctuaire.

**Histoire** : `data/story/story.json` (personnages, visites, nuits, objets), à écrire avec l'éditeur web
`editeur-histoire/index.html` (Chrome ou Edge). Format : `docs/story-format.md`. Suivi : `docs/feuille-de-route.md`.

**Outils de dev**
- `tools/blender/*.py` : un script par modèle (`blender --background --python ...`), module commun `common.py`.
- `tools/build_world.gd` : régénère `scenes/world/shrine.tscn` (`godot --headless --script res://tools/build_world.gd`).
- `tools/shot.sh x y z yaw pitch nom [phase 0-2] [attente] [outil|vn]` : capture du vrai rendu.
- `godot --path . -- --autoplay [--tasks=a,b]` : joue automatiquement une journée complète (test).
- Premier jour guidé (`scripts/guide.gd`) : actif au jour 1 d'une partie lancée normalement. Les modes de test
  le coupent, sauf avec `--guide` (ex. `-- --autoplay --guide`) ; `--noguide` le coupe toujours.
- `godot --path . -- --feeltest --tasks=a,b` : teste les gestes avec de vraies entrées souris simulées.
- `godot --path . -- --shoptest` : achète chaque objet de la boutique et vérifie ses effets.
- `godot --path . -- --savetest` : sauvegarde, recharge et compare la partie, puis pause et nouvelle partie (dossier de test à part).
- `godot --path . -- --menushot fichier.png title|options|slots|pause|end` : capture d'un menu.
- `godot --path . -- --fete` / `--fete-prete` : jour de Tsukimi, rien de préparé / tout préparé.
- `godot --path . -- --stand=kingyo|shateki|wanage|dango` : soirée de Tsukimi ouverte, directement à un stand de
  mini-jeu ; `--standtest` y joue une manche seul et affiche le score, `--standshot=fichier.png` fait une capture.
- Les modes de test (`--shot`, `--autoplay`...) sautent l'écran titre, gardent les réglages par défaut et n'écrivent aucune sauvegarde.
- `godot --path . -- --walktest` : fait marcher le joueur (entrée du salon de thé, murs) et vérifie la hauteur libre sous chaque torii.
- `godot --path . -- --soundtest` : liste les sons chargés depuis des fichiers et les ambiances qui jouent.
- `python3 tools/convert_sounds.py` : extrait les sons du jeu de la banque `sound design/` (voir `assets/sounds/LISEZMOI.md`).
- `godot --path . -- --deep` / `--groups`, `godot --headless --path . -- --cpu` : audit de performance approfondi (voir `docs/audit-performance.md`).
- `godot --path . -- --perf` : audit de fluidité (temps d'image par point de vue, puis chaque poste coupé un par un ;
  `--quick` : seulement la base, `--fixes` : réglages candidats).
- Portraits : déposer `assets/portraits/<id_visiteur>_<expression>.png` (expressions : neutre, sourire, inquiet).
