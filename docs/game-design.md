# Gardien de sanctuaire

Nov 12, 2026 · @paul

## Vision

Un jeu court (45 à 60 min) où l'on entretient un petit sanctuaire de montagne pendant une année. Le plaisir vient du soin apporté au lieu et des visiteurs qu'on y croise, pas de la performance : il n'y a ni échec ni score.

- **Le lieu** : un sanctuaire shintō isolé en haut d'un escalier de pierre, avec un torii, un petit pavillon, une fontaine d'ablution, deux lanternes et un grand arbre.
- **Le rythme** : une journée = quelques tâches simples, un ou deux visiteurs, puis on sonne la cloche le soir.
- **Le ressenti visé** : le calme, la satisfaction d'un lieu propre et vivant, une mélancolie douce quand certains visiteurs ne reviennent pas.
- **Références d'ambiance** : *A Short Hike* (petit lieu dense, ton chaleureux), *Unpacking* (récit raconté par les objets), *Spiritfarer* (prendre soin, dire au revoir), les décors de Ghibli.

## Boucle de jeu

Une journée dure 3 à 5 minutes et suit toujours le même ordre. La seule contrainte : la cloche du soir ne sonne que lorsque les tâches indispensables sont faites.

&#91;embedded content: boucle d'une journée · 4 phases, 1 passage de saison\]

Un dialogue de visiteur peut poser un flag qui le fait revenir un jour suivant : c'est ainsi que les histoires s'étirent sur plusieurs jours.

## Activités d'une journée

Une journée mélange 3 ou 4 tâches obligatoires et des activités libres. Chaque action a sa propre petite mécanique, pour que le jeu ne se résume jamais à « viser et appuyer sur E ».

| Activité | Type | Saisons | Mécanique |
| --- | --- | --- | --- |
| Balayer l'allée | Obligatoire | Toutes (feuilles, pétales, aiguilles) | Maintenir le clic en balayant à la souris ; on forme des tas, puis on les jette dans un panier |
| Déneiger | Obligatoire | Hiver | Pousser la neige hors des dalles avec une pelle |
| Remplir la fontaine | Obligatoire | Toutes | Puiser au puits, porter le seau (on marche plus lentement), verser. En hiver, casser d'abord la glace |
| Allumer les lanternes | Obligatoire, le soir | Toutes | Craquer une allumette ; par vent fort, protéger la flamme avec la main |
| Sonner la cloche du soir | Obligatoire, fin de journée | Toutes | Tirer la corde : plus on tire, plus le son porte |
| Lire et raccrocher les ema | Libre | Toutes | Lire les vœux des visiteurs ; certains donnent des indices sur leur histoire |
| Ratisser le jardin sec | Libre | Toutes sauf hiver | Tracer des motifs dans le gravier : un petit moment zen, sans score |
| Déposer les offrandes | Libre | Toutes | Riz, saké, fruits de saison sur l'autel ; certains animaux viennent les prendre |
| Proposer un omikuji | Libre | Toutes | Un visiteur tire un papier de bonne aventure ; s'il est mauvais, on l'aide à le nouer |
| Réparer | Libre, puis obligatoire si on néglige | Toutes | Corde sacrée (shimenawa) usée, papier de lanterne déchiré, tuile tombée |
| Nourrir le chat | Libre | Toutes | Il te suit ensuite et dort dans les coins ensoleillés |
| Prendre le thé sur la véranda | Libre | Toutes | Fait avancer le temps jusqu'au soir : un moment contemplatif, caméra fixe sur le paysage |

Il n'y a jamais d'échec, mais la négligence se voit : la mousse gagne les dalles, une lanterne se fissure, les visiteurs le remarquent dans leurs dialogues. Remettre le lieu en état devient alors une récompense en soi.

## Événements pour casser la routine

Chaque journée contient une petite surprise, et chaque saison un ou deux événements marquants. Le joueur ne sait jamais exactement ce qui l'attend le matin.

**Petites surprises (une par jour environ)**

| Événement | Ce qui change |
| --- | --- |
| Pluie | Flaques, sons différents, moins de visiteurs, mais ceux qui viennent ont plus à dire |
| Brouillard du matin | On voit à peine le torii ; il se lève vers midi |
| Vent fort | Les feuilles balayées reviennent, les lanternes s'éteignent, une branche peut tomber |
| Tanuki voleur | Il emporte une offrande ; on peut le suivre jusqu'à sa cachette |
| Renard au loin | Il apparaît entre les arbres et disparaît si on s'approche ; il revient plus près chaque saison |
| Objet perdu | Un visiteur oublie un parapluie ou un porte-clés ; on peut le lui rendre s'il revient |
| Ema sans nom | Un vœu étrange accroché dans la nuit, sans visiteur visible |

**Événements marquants (1 ou 2 par saison)**

| Événement | Saison | Ce qui change |
| --- | --- | --- |
| Hanami | Printemps | Les cerisiers fleurissent, des visiteurs pique-niquent sous l'arbre |
| Matsuri, la fête d'été | Été | Stands, lanternes en papier, foule, feux d'artifice le soir |
| Typhon | Été ou automne | Une journée enfermé dans le pavillon, puis une journée de réparations |
| Shichi-go-san | Automne | Des familles viennent bénir leurs enfants en kimono |
| Coupure de courant | Hiver | Seules les lanternes éclairent le sanctuaire pendant la nuit |
| Réveillon et hatsumōde | Fin d'année | 108 coups de cloche, puis la foule du premier matin de l'année |
| Lettre de l'ancien gardien | Scénarisé | Trouvée en réparant le pavillon ; elle relance l'histoire du lieu |
| Visiteur de la nuit | Secret | Il ne vient que si le sanctuaire est parfaitement entretenu |

**Comment le jeu les choisit**

Un autoload `EventDirector` tire chaque matin l'événement du jour parmi des fichiers `EventData` (saisons possibles, poids, jour minimum, délai avant de pouvoir revenir, flags requis, scène à faire apparaître). Trois règles suffisent à garder un bon rythme :

- Le premier jour d'une saison reste calme, pour qu'on profite du changement de décor.
- Jamais deux fois la même surprise d'affilée, grâce au délai minimum.
- Les événements marquants sont placés à la main sur un jour précis ; seules les petites surprises sont tirées au hasard.

## Périmètre du prototype

Le prototype couvre une seule saison, l'automne : 3 jours, 3 visiteurs, 5 tâches, soit 10 à 15 minutes de jeu. S'il est agréable à jouer, les trois autres saisons réutilisent exactement les mêmes systèmes.

**Dedans**

- Le sanctuaire complet, explorable à la première personne
- 5 tâches : balayer les feuilles, remplir la fontaine, rallumer les lanternes, raccrocher les ema tombés, sonner la cloche du soir
- 3 visiteurs, dont un qui revient le 3e jour pour conclure son histoire
- Le cycle matin, visites, soir, et la transition d'un jour à l'autre
- Le style toon (ombres en aplats et contours) et les dialogues en visual novel

**Dehors (pour plus tard)**

- Les autres saisons, la météo, la musique composée
- Les menus complets et les options
- Les choix de dialogue qui changent la fin
- La sauvegarde au milieu d'une journée

## Direction artistique

Le jeu se joue **en 3D à la première personne** : on marche dans le sanctuaire, on regarde autour de soi et on interagit avec ce qu'on vise. Les conversations basculent **en 2D façon visual novel**, avec de grands portraits illustrés, une boîte de texte et des choix.

- **Caméra** : vue à la première personne, ZQSD et souris. Marche lente, sans saut ni course au départ, pour garder le rythme calme.
- **Interaction** : un petit point au centre de l'écran ; l'objet visé affiche son action, par exemple « E : Balayer ». Le balai apparaît en bas de l'écran quand on balaie.
- **Dialogues visual novel** : quand on parle à un visiteur, le décor 3D se floute et s'assombrit, et un calque 2D affiche son portrait (2 à 4 expressions), son nom, le texte et les choix.
- **Visiteurs dans le monde 3D** : le plus simple et le plus cohérent est un sprite 2D toujours tourné vers la caméra (`Sprite3D` en mode billboard), dessiné dans le même style que les portraits. Un petit modèle 3D low-poly reste possible, mais demande plus de travail.
- **Shader toon** : un `ShaderMaterial` avec une fonction `light()` en 2 ou 3 paliers, et des ombres teintées plutôt que grises.
- **Contours** : la méthode inverted hull, avec un second passage (`next_pass`) qui gonfle le mesh et n'affiche que les faces arrière en noir.
- **Saisons** : une palette par saison passée en paramètres globaux du shader, plus des particules (feuilles, neige, pétales).

| Asset | Outil | Priorité | Notes |
| --- | --- | --- | --- |
| Torii | Blender | Prototype | Tu l'as déjà |
| Pavillon (haiden) | Blender | Prototype | Toit courbé, vu de près : soigner les détails |
| Fontaine d'ablution (chōzuya) | Blender | Prototype | Bassin en pierre, louches en bambou |
| Lanternes de pierre (tōrō) × 2 | Blender | Prototype | Version allumée et éteinte |
| Présentoir à ema | Blender | Prototype | Plaquettes séparées pour pouvoir les décrocher |
| Grand arbre (érable ou ginkgo) | Blender | Prototype | Feuillage en blocs, couleurs changeantes |
| Escalier et sol de pierre | Blender | Prototype | Modulaire |
| Balai tenu en main | Blender | Prototype | Visible en bas de l'écran pendant le balayage |
| Portraits des 3 visiteurs | Dessin 2D | Prototype | En buste, 2 à 4 expressions chacun |
| Visiteurs dans le monde | Dessin 2D | Prototype | Sprite en pied, même style que les portraits |
| Chat du sanctuaire | Blender | Plus tard | Pour la vie du lieu |

## Architecture Godot 4

Toutes les données de jeu (visiteurs, tâches, saisons) sont des fichiers `Resource` (.tres) : on ajoute du contenu sans toucher au code. Deux autoloads portent l'état global et les signaux.

```
res://
├── autoload/
│   ├── GameState.gd      # jour, saison, flags d'histoire, tâches faites
│   └── Events.gd         # bus de signaux : task_done, visitor_left, day_ended
├── data/
│   ├── tasks/            # TaskData : balayer.tres, fontaine.tres…
│   ├── visitors/         # VisitorData : vieille_dame.tres…
│   └── seasons/          # SeasonData : automne.tres…
├── scenes/
│   ├── main.tscn         # World + Player + CameraRig + UI
│   ├── world/shrine.tscn # le sanctuaire et ses Interactables
│   ├── player/player.tscn # CharacterBody3D + Camera3D + RayCast3D, 1re personne
│   ├── interactables/    # interactable.gd (base) + leaf_pile, basin, lantern, ema_rack, bell
│   ├── visitors/visitor.tscn
│   └── ui/               # vn_dialogue (portraits, nom, texte, choix), crosshair, task_list, day_transition
├── shaders/              # toon.gdshader, outline.gdshader, blur pour les dialogues
└── art/portraits/        # un PNG par visiteur et par expression
```

Les trois types de données (un fichier .gd chacun) :

```gdscript
class_name TaskData extends Resource
@export var id: StringName
@export var label: String            # "Balayer les feuilles"
@export var seasons: Array[StringName]
@export var required: bool = true    # bloque la cloche du soir tant qu'elle n'est pas faite

class_name VisitorData extends Resource
@export var id: StringName
@export var display_name: String
@export var day: int                 # jour d'arrivée
@export var dialogue: Resource       # fichier .dialogue (Dialogue Manager)
@export var wish: String             # texte écrit sur son ema
@export var portraits: Dictionary    # "neutre", "sourire"… → Texture2D
@export var world_sprite: Texture2D  # sprite en pied dans le sanctuaire
@export var requires_flag: StringName # vide = vient toujours

class_name SeasonData extends Resource
@export var id: StringName
@export var days: int = 3
@export var palette: Gradient        # envoyée au shader toon
@export var particles: PackedScene   # feuilles, neige, pétales
```

## Systèmes clés

Cinq systèmes suffisent, tous petits ; le plus délicat est l'écriture des visiteurs, pas le code.

- **Interaction** : chaque objet utile hérite d'`Interactable` (un `Area3D` avec un nom d'action). Un RayCast3D partant du centre de l'écran détecte l'objet visé (portée d'environ 2 m), affiche « E : Balayer » sous le point de visée, et appelle `interact()`. Une tâche émet `Events.task_done(id)` quand elle est finie.
- **Tâches** : au début de chaque jour, `GameState` crée la liste des tâches de la saison et les remet à zéro (les feuilles réapparaissent, la fontaine se vide). La cloche du soir n'est utilisable que si toutes les tâches `required` sont faites.
- **Visiteurs et dialogues** : un `VisitorSpawner` regarde chaque matin les `VisitorData` dont le `day` correspond et dont le `requires_flag` est vrai. Le visiteur monte l'escalier et prie. Quand on le vise et qu'on appuie sur E, le jeu passe en mode visual novel : déplacement bloqué, décor flouté, portrait, texte et choix. Ensuite il accroche son ema et repart. Pour les dialogues, l'addon **Dialogue Manager** (gratuit, écrit pour Godot 4) gère le texte, les choix et les flags ; on y branche notre propre calque visual novel, et une balise dans le texte change l'expression du portrait. Un dialogue peut poser un flag qui débloque le retour d'un visiteur.
- **Cycle jour / saison** : trois phases, matin, visites, soir. Sonner la cloche lance un fondu au noir, incrémente le jour et passe à la saison suivante tous les `SeasonData.days`. La saison applique sa palette au shader, change les particules et la lumière.
- **Sauvegarde** : une seule sauvegarde automatique au début de chaque jour, un `GameState` exporté en `.tres` dans `user://`. Pas de sauvegarde en cours de journée, ce qui garde le système trivial.

## Étapes jusqu'au prototype

Sept étapes, chacune jouable à la fin. Le gameplay passe avant les beaux assets : on joue avec des cubes jusqu'à l'étape 5.

1. **Blockout et déplacement** : le sanctuaire en cubes et un contrôleur à la première personne (ZQSD + souris).
   - Fini quand : on fait le tour du sanctuaire sans traverser de mur.
2. **Interaction et 3 tâches** : la classe `Interactable`, le point de visée et l'invite à l'écran, puis balayer, remplir la fontaine, allumer les lanternes.
   - Fini quand : les trois tâches se cochent dans une petite liste à l'écran.
3. **Cycle d'une journée** : `GameState`, la cloche du soir, le fondu au noir et la remise à zéro des tâches.
   - Fini quand : on enchaîne trois jours d'affilée.
4. **Un premier visiteur** : le `VisitorSpawner`, son trajet, le passage en mode visual novel avec un portrait provisoire, un dialogue Dialogue Manager et l'ema accroché.
   - Fini quand : il arrive le jour 1, parle, laisse son vœu et repart.
5. **Vrais assets et rendu toon** : remplacer les cubes par les modèles Blender, appliquer les shaders toon et contour, dessiner les premiers portraits définitifs.
   - Fini quand : une capture d'écran donne envie.
6. **L'automne complet** : 3 jours, 3 visiteurs dont un qui revient grâce à un flag, les particules de feuilles.
   - Fini quand : quelqu'un d'autre joue 10 minutes du début à la fin sans aide. C'est le prototype.
7. **Ambiance** : sons d'ambiance (vent, corbeaux, cloche), lumière du soir, petite musique.
   - Fini quand : le jeu est montrable.

## Idées pour plus tard

- Les trois autres saisons : neige à déblayer en hiver, cerisiers et fête au printemps, cigales et orages en été.
- Le chat du sanctuaire, qui suit le gardien et dort aux endroits ensoleillés.
- Lire les ema accrochés par les visiteurs passés : un journal des vœux de l'année.
- Des visiteurs récurrents dont l'histoire avance sur toute l'année (un étudiant avant ses examens, un couple, une vieille dame qui finit par ne plus venir).
- Une fin de cycle : le dernier soir de l'année, avec les 108 coups de cloche du réveillon (joya no kane).
- Quelques mots de japonais dans l'interface et les dialogues, avec traduction au survol.
