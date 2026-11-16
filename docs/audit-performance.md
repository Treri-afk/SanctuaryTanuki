# Audit de performance — Tanuki Sanctuary

Mesuré le 14/11/2026 sur un Mac M1 (Metal, Forward+), fenêtre 1280 × 720, qualité « Moyenne », v-sync coupée.
Outils (à relancer après chaque correction) :

    godot --path . -- --perf             temps d'image par point de vue, chaque poste coupé un par un
    godot --path . -- --deep             recensement de la scène, appels de dessin, à-coups pendant une marche
    godot --path . -- --groups           coût de chaque famille d'objets (murs, arbres, terrain...)
    godot --headless --path . -- --cpu   temps des scripts et de la physique, sous-système par sous-système

Limites : Metal ne donne pas le temps GPU ; la machine chauffe et ralentit d'une mesure à l'autre (±3 à 8 ms).
Les **appels de dessin** et les **triangles** sont, eux, exacts et reproductibles : ce sont les chiffres les plus sûrs.

---

## 1. Où en est-on

| Mesure | Valeur | Cible |
|---|---|---|
| Temps d'image moyen | **26 à 30 ms** (33 à 38 img/s) | 16,6 ms (60 img/s) |
| Pires images pendant une marche de 8 s | **62 à 87 ms**, 4 à 12 images au-dessus de 50 ms | aucune au-dessus de 33 ms |
| Appels de dessin par image | **2 300 à 4 000** | moins de 1 000 |
| Triangles par image | 1,0 à 1,8 million | (pas un problème sur M1) |
| Scripts (`_process`) | **~2 ms** par image | — |
| Physique | **1,6 ms** par pas (2 pas par image à 30 img/s) | — |
| Chargement jusqu'au jeu | **~5 s** (terrain 1,7 s, forêt 1 s) | 1 à 2 s |
| Mémoire vidéo | 240 Mo | — |

**Verdict** : le jeu est limité par la **carte graphique**, et pas par les scripts. Les scripts et la physique
font 5 ms sur ~29 ms. Deux postes dominent : les **ombres** et le **coût par pixel** (sol, résolution, anticrénelage).
Le **nombre d'appels de dessin** reste trop élevé : chaque objet est dessiné plusieurs fois par image (profondeur,
couleur, une fois par cascade d'ombre). Enfin, les **à-coups** se sentent plus que la moyenne : c'est eux qu'on
ressent comme du « lag ».

## 2. Ce qui a déjà été fait

| Correction | Gain |
|---|---|
| Forêt découpée en tuiles de 36 m (elle était dessinée en entier à chaque image, et une fois par cascade d'ombre) | ~4 ms |
| 2 cascades d'ombre sur 65 m au lieu de 4 sur 95 m, filtre d'ombre plus simple | ~5 ms |
| Brouillard volumétrique en 64 × 48 au lieu de 128 × 96 | ~4 ms |
| MSAA 2x au lieu de 4x | 1 à 3 ms |
| Bâtiments refaits fusionnés en un seul objet chacun | (pas de surcoût) |
| Réglages de qualité Basse / Moyenne / Haute et résolution 3D dans les options | au choix du joueur |

Les ~1 000 appels de dessin en plus repérés après l'ajout des bâtiments ne se reproduisent plus (allée : 2 310
appels, comme juste après l'optimisation) : c'était un état passager pendant les mesures.

---

## 3. Problèmes et solutions, par impact

### P1 — Les ombres coûtent le plus · *gain estimé 3 à 6 ms*

**Constat.** Couper les ombres fait gagner ~10 ms. **643 des 667 objets** projettent une ombre, dont **887 pièces
petites ou plates** : dalles, mousse, feuilles, cailloux, ema, pierres de seuil. Leur ombre ne se voit pas, mais
chacune est redessinée dans chaque cascade.

**Mesuré.** Couper l'ombre de ces seules pièces fait gagner **800 à 1 400 appels de dessin** et **2 à 4 ms**.

**Solutions.**
1. *(facile, 1 h)* Pas d'ombre pour les pièces de moins de 35 cm de haut ou de moins d'un mètre. On le règle une
   fois pour toutes à l'import (Toon.apply) et dans `build_world`.
2. *(facile)* Pas d'ombre pour le petit décor de la forêt, déjà fait pour l'herbe et les fougères. À vérifier
   pour les rochers et les souches.
3. *(moyen, à évaluer)* Ombre des arbres limitée aux tuiles proches : au-delà de ~35 m, un arbre sans ombre ne
   se remarque pas, avec le brouillard et le contre-jour.

### P2 — Trop d'appels de dessin · *gain estimé 2 à 5 ms, et des à-coups en moins*

**Constat.** Chaque **matériau** d'un objet est un dessin à part, répété à chaque passe (profondeur, couleur,
2 cascades d'ombre). Les objets ont souvent 3 à 6 matériaux, puisque la règle est « une couleur unie par matériau ».

| Famille | Appels de dessin (vue lisière / allée) | Pourquoi |
|---|---|---|
| Décor posé un par un (133 objets : rochers, érables, jizō, bancs, bambous...) | **1 900 / 1 700** | chaque objet × ses matériaux × les passes |
| Arbres de la forêt | **1 500 / 1 100** | 21 pièces de modèles × tuiles visibles × passes |
| Bâtiments | 220 / 170 | normal : quelques gros objets |
| Petit décor de forêt | 110 | déjà regroupé |
| Dalles et chemins (137 pièces), murs d'enceinte (86 pièces) | 70–100 et 50–60 | une pièce = un objet |

**Solutions.**
1. *(facile à moyen, une demi-journée)* **Regrouper les pièces répétées en MultiMesh**, un seul objet par modèle :
   les 86 pièces de mur, les ~140 dalles et pierres de chemin, les lanternes de pierre, les rochers et les jizō.
   Le changement se fait dans `build_world.gd`, comme pour la forêt. Gain : quelques centaines d'appels.
2. *(structurant, 1 à 2 jours — **la plus grosse marge**)* **Un seul matériau par modèle, la couleur portée par
   les sommets.** À l'export Blender (`common.export_glb`), on écrit la couleur de chaque face dans la couleur de
   sommet, à côté de l'occlusion qui y est déjà. Le shader toon lit alors `COLOR.rgb` au lieu d'une couleur par
   matériau. Le rendu reste identique (aplats), mais **chaque modèle devient 1 dessin au lieu de 3 à 25**, ce qui
   divise le total par 3 à 5. Il faut une exception pour les matériaux spéciaux (eau, feuillage qui bouge au
   vent, émissifs), qui gardent leur matériau.
3. *(facile)* Tuiles de forêt un peu plus grandes (36 → 48 m) : moins d'objets à trier. À mesurer, car le gain
   de culling diminue en échange.

### P3 — Le coût par pixel · *gain estimé 2 à 4 ms*

**Constat.** Masquer le terrain seul fait gagner **3 ms** (vue lisière, où il couvre la moitié de l'écran) :
le shader du sol (`shaders/ground.gdshader`, 374 lignes, 6 bruits ou lectures de texture par pixel) est cher.
La résolution compte aussi : le rendu à 50 % fait gagner ~7 ms.

**Solutions.**
1. *(moyen)* **Simplifier le shader du sol avec la distance** : les détails fins (gravier, taches) seulement
   sous ~25 m, une couleur lissée au-delà. Ou précalculer les bruits dans une texture (`build_world`) au lieu
   de les calculer à chaque pixel.
2. *(facile)* **Résolution 3D à 85 % avec FSR** par défaut en qualité « Moyenne » sur les écrans Retina :
   presque invisible avec les contours tracés à l'écran, ~3 ms gagnées. Le réglage existe déjà dans les options.
3. *(facile)* En qualité « Moyenne », **FXAA au lieu du MSAA 2x** : 1 à 3 ms. À juger à l'œil, car les contours
   d'écran adoucissent déjà les bords.

### P4 — Les à-coups · *ce qu'on ressent le plus*

**Constat.** Pendant une marche de 8 s : 10 images au-dessus de 50 ms (pire : 81 ms). Au second passage
identique, il n'en reste que 4 (pire : 62 ms). Plus de la moitié vient donc de la **compilation des shaders**
la première fois qu'un matériau apparaît. Le reste vient des pics de rendu, aggravés par la **physique qui
rattrape son retard** : sur une image lente, elle enchaîne plusieurs pas d'un coup, ce qui ralentit encore
l'image suivante.

**Solutions.**
1. *(facile à moyen)* **Préchauffer les shaders pendant l'écran titre** et le fondu « Jour 1 » : faire voir à
   la caméra, une image chacun derrière l'écran noir, un exemplaire de chaque matériau (une rangée d'objets
   témoins hors champ, ou un tour de caméra dans la cour). Les compilations ont lieu avant de jouer.
2. *(facile)* **Limiter les pas de physique par image** (`physics/common/max_physics_steps_per_frame` : 8 → 3) :
   une image lente ne déclenche plus une rafale de pas de physique.
3. *(facile)* Garder le **cache de shaders** activé (par défaut) : les compilations ne se refont pas d'une
   session à l'autre.

### P5 — Le chargement de 5 s · *confort*

**Constat.** Le terrain (1,7 s) et la forêt (1 s) sont **recalculés en GDScript à chaque lancement** : maillage
du sol, placement de milliers d'arbres et de touffes d'herbe.

**Solution.** *(moyen)* Les **précalculer une fois dans `build_world`** et les enregistrer avec la scène :
maillage du sol en `ArrayMesh`, positions des arbres et de l'herbe en `MultiMesh`. Le jeu ne fait plus que
charger. Chargement attendu : 1,5 à 2 s.

### P6 — Scripts et physique · *rien d'urgent*

Scripts ~2 ms par image : aucun sous-système ne pèse (guide, HUD, feuilles, carpes, ambiance sonore : chacun
moins de 1 ms, dans le bruit de mesure). Physique 1,6 ms par pas : les zones d'interaction sont déjà en mode
« rayon seulement ». À surveiller si on ajoute des personnages animés.

---

## 4. Lot 1 appliqué — résultats (14/11/2026)

| Correction | Où | Effet mesuré |
|---|---|---|
| Petites pièces sans ombre (< 35 cm de haut ou < 60 cm) | `scripts/render_budget.gd`, au lancement et pour tout objet ajouté ensuite | objets qui projettent une ombre : **643 → 271** ; coût des ombres **~10 → ~4,5 ms** |
| Murs d'enceinte et dalles regroupés en MultiMesh (223 pièces) | `RenderBudget.batch` (les pièces restent en place, maillage masqué : collisions et tâche de la palissade intactes) | appels de dessin **−13 à −17 %** (allée 2 310 → 1 970, lisière 2 936 → 2 433) |
| 3 pas de physique au plus par image (au lieu de 8) | `project.godot` | à-coups : marche de 8 s **10 → 0 image au-dessus de 50 ms**, pire image **87 → 47 ms** (2e passage : 3 images, pire 54 ms) |
| Résolution 3D à 85 % par défaut | — | **écarté** : aucun gain mesuré (le passage FSR coûte autant qu'il fait gagner). 75 % fait gagner ~3 ms mais adoucit nettement l'image : laissé au choix dans les options |
| FXAA au lieu du MSAA 2x | — | **écarté** pour l'instant : 1 à 2 ms seulement, à juger plus tard avec le lot 3 |

Temps d'image moyen : **~27 à 28 ms** (inchangé à la précision des mesures : le coût restant est surtout par pixel).
Ce qui pèse encore, mesuré après le lot 1 : la résolution (rendu à 50 % : −9 ms), les arbres (~6 ms), les ombres
(~4,5 ms), le sol. C'est l'objet du lot 3 (un matériau par modèle, shader du sol allégé) et du lot 2 pour les
à-coups restants.

## 5. Plan conseillé

| Lot | Contenu | Effort | Gain attendu |
|---|---|---|---|
| ~~**1 — corrections rapides**~~ (fait, voir § 4) | P1.1 petits objets sans ombre · P4.2 pas de physique limités · P2.1 MultiMesh des pièces répétées (murs, dalles, lanternes, rochers) · P3.2 résolution 85 % en « Moyenne » | ~1 journée | **6 à 10 ms**, à-coups réduits → ~45 img/s |
| **2 — à-coups** | P4.1 préchauffage des shaders pendant l'écran titre | ½ journée | plus de pics à la découverte d'une zone |
| **3 — structurant** | P2.2 un matériau par modèle (couleur de sommet) · P3.1 shader du sol par distance | 2 à 3 jours | appels de dessin divisés par 3 à 5, **60 img/s visés** |
| **4 — confort** | P5 terrain et forêt précalculés | 1 jour | chargement ~2 s |

Chaque lot se vérifie avec `-- --perf`, `-- --deep` et `-- --groups`, avant et après, sur la même machine
reposée.

## Arbres et torii refaits (un matériau par modèle)

Les arbres (érables, cèdres, pin) et les torii ont été refaits (`tools/blender/tree_util.py`, `torii_util.py`) avec
les couleurs portées par les sommets : **un seul matériau par objet** (tronc, feuillage) au lieu d'un par teinte.
C'est P2.2 appliqué aux arbres. Mesuré (`--perf --quick --tasks=lanternes,cloche`, mêmes vues) :

| | avant | après |
|---|---|---|
| Appels de dessin (escalier / allée / lisière) | 2 507 / 2 002 / 2 402 | 1 773 / 1 456 / 1 720 (**−30 %**) |
| Triangles à l'image | 1 423k / 1 258k / 1 579k | 1 564k / 1 365k / 1 719k (+9 %) |
| Triangles d'arbres sur la carte | 2,83 M | 2,96 M |

Le cœur des masses de feuillage est un icosaèdre de 20 triangles : il est caché sous les touffes et ses normales
sont imposées (celles de l'enveloppe de la couronne), plus de facettes ne se verraient pas. Le temps par image
n'a pas pu être comparé proprement (machine chaude, autres instances de Godot ouvertes pendant les mesures).
