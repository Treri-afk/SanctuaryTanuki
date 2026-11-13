# Feuille de route — Gardien de sanctuaire

Document de suivi : ce qui est fait, ce qui vient ensuite, et les idées gardées pour plus tard.
On met à jour le statut de chaque ligne au fur et à mesure.

**Légende** : ✅ fait · 🔨 en cours · 📌 prochain (validé, à faire) · 💡 idée gardée (à concevoir) · ⏸ plus tard · ❌ écarté pour l'instant

---

## 1. Déjà en place

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Sanctuaire agrandi, forêt de montagne, sentiers (belvédère, cabane, mare) | |
| ✅ | Rendu : lumière des trois moments, ciel, vent, eau, herbe, contours | Passe « beauté » sans refaire les modèles |
| ✅ | 6 tâches du matin tirées au hasard (2 par jour) | Feuilles, fontaine, prière, palissade, haies, bambous |
| ✅ | Lanternes et cloche le soir | |
| ✅ | 2 à 3 visiteurs par jour, à des moments aléatoires | Le soir tombe quand tâches faites et visiteurs repartis |
| ✅ | Dialogues visual novel avec affection, choix, conditions, drapeaux | |
| ✅ | Éditeur d'histoire (application web) | Dossier `editeur-histoire/` du dépôt : ouvrir `index.html` dans Chrome ou Edge |
| ✅ | Cérémonie du thé jouable | |
| ✅ | Activités facultatives : ema égarés, jardin sec, renard, chat, lettres, découvertes | |

## 2. À peaufiner (connu)

| Statut | Élément | Notes |
|---|---|---|
| 🔨 | Son et ambiance | Banque `sound design/` convertie en extraits légers (`tools/convert_sounds.py`, 14 Mo). Ambiances (`scripts/ambience.gd`) : forêt du matin, de l'après-midi (deux variantes), du soir, chouettes la nuit, forêt profonde hors de l'enceinte, vent qui suit les bourrasques, ruisseau et cascade qui suivent le joueur, gouttes au bassin, pics-verts au loin ; baisse pendant les dialogues. Sons : outils, pièces, clochette (prière, cloche du soir), papier (lettres, journal), coulissant (boutique, cabane), chat, allumettes, carpes, eau, corde. Reste : pas (encore synthétisés, pas d'enregistrement de pas dans la banque), pluie (la banque a une pluie en forêt, pour une future météo), musique |
| ✅ | Corps du joueur | Inertie au départ et à l'arrêt, tête qui se balance au rythme des pas, léger roulis en pas chassé, tassement à l'atterrissage, respiration à l'arrêt, main qui traîne derrière le regard (`head_bob` = 0 pour tout couper) |
| ✅ | Retour quand on agit | Fin de tâche : clochette, anneau autour du viseur, nom de la tâche qui monte au centre, ligne qui s'éclaire ; étape d'une tâche courte : petit « toc ». Messages plus courts, sans doublons, accélérés quand ils s'empilent |
| 🔨 | Fluidité | Audit `-- --perf` (`tools/perf_audit.gd`) : le jeu est limité par la carte graphique. Forêt découpée en tuiles (elle était dessinée en entier à chaque image, et une fois par cascade d'ombre), 2 cascades d'ombre sur 65 m, filtre d'ombre plus simple, brouillard volumétrique allégé, MSAA 2x : ~40 → 27 ms par image sur ce Mac. Reste : un réglage de qualité (résolution 3D surtout) dans un menu d'options |
| 🔨 | Modèles 3D | Faits au propre : marteau (genno), cisaille (kariko-basami), serpe (kama), carpes koï (5 robes), haies taillées (2 variantes) et rameaux à couper. Bâtiments secondaires à l'échelle du haiden : bureau du sanctuaire avec comptoir de vente (`shamusho.py`), salon de thé en chaume (`teahouse.py`), pavillon des ablutions (`temizuya.py`), grands torii ×1,5 ; module commun `building_util.py` (toits en croupe à tuiles, chaume, cuivre à deux pans, shoji, enseignes). Restent en formes code : établi, bambous de la tâche, planches et clous, renard, tanuki, objets de récolte |
| 📌 | Débogage de certaines tâches | À lister au fil des parties |
| 🔨 | Prise en main d'un nouveau joueur | Premier jour guidé (`scripts/guide.gd`) : lettre d'accueil de Seiji, matin fixé et court (feuilles de l'allée en version allégée + prière), objectif courant en haut de l'écran avec la commande utile, repère doré (flèche au bord si hors champ), visiteurs seulement après le matin, liste qui se dévoile (facultatif l'après-midi, lanternes et cloche au soir). À faire : retours de partie, texte de la lettre à valider |
| 📌 | Personnages | Portraits et sprites (à dessiner) ; les visiteurs sont encore des rectangles colorés |
| 🔨 | Cohérence des dialogues avec le monde | Corrigé pour Hina : la réponse « j'ai vu un chat près de la mare » n'apparaît que si on a caressé le chat ou qu'il est venu la nuit (drapeau `chat_vu`) |

---

## 2 bis. Structure du jeu

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Écran titre | Sur le vrai sanctuaire, caméra qui dérive ; continuer, nouvelle partie, charger, options, quitter |
| ✅ | Sauvegardes | 3 emplacements, sauvegarde chaque soir après le journal, reprise au matin |
| ✅ | Menu pause et options | Volumes (général, ambiances, effets), souris, balancement de tête, qualité (basse / moyenne / haute), résolution 3D, plein écran, synchro verticale |
| ✅ | Fin de la démo | Après le jour 3 : bilan (travaux, visites, pièces, cueillette, lettres, carpes, personnes rencontrées) |
| 💡 | Au-delà de la démo | Plus de 3 jours, saisons ; la fin de démo deviendra une fin de saison |

## 3. Économie douce : pièces et boutique

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Les visiteurs déposent des pièces dans le tronc à offrandes | En arrivant, chaque visiteur prie au tronc et y jette ses pièces, ramassées automatiquement. Montant : « pièces offertes » du personnage (éditeur) + 1 par tranche de 3 d'affection |
| ✅ | Compteur de pièces discret | Caché par défaut ; apparaît quand on gagne ou dépense, pendant la prière, ou en maintenant Tab (HUD complet) |
| ✅ | La pièce de la prière se dépense | S'il n'en reste aucune, le rite continue sans |
| ✅ | Boutique du bureau du sanctuaire | `scripts/shop.gd` : comptoir au porche du bureau (ouest de la cour). Encens, granulés de qualité, omamori, ema vierge, prière de retour. Test : `-- --shoptest` |
| ✅ | Encens | Brûle-parfum (koro) près du tronc à offrandes ; allumé, chaque visiteur du jour gagne +1 d'affection. Fumée d'encens (`shaders/smoke.gdshader`) |
| ✅ | Prière de retour | Proposée seulement pour un visiteur parti (6 pièces) |
| ✅ | Granulés de qualité, omamori, ema vierge | Carpes : croissance doublée le lendemain ; omamori : cadeau apprécié de tous ; ema : son propre vœu au présentoir |
| 💡 | Autres achats | Matériaux de restauration, décorations (furin, lanternes), à compléter |

## 4. Récoltes et cadeaux

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Récolter des objets dans la montagne | 8 objets (kaki, châtaigne, shiitake, feuille d'érable, galet, plume de geai, lys araignée, pomme de pin), 12 par matin selon leurs lieux (cour, sentiers, sous-bois, mare, belvédère) ; halo doré au sol, E pour ramasser |
| ✅ | Offrir un cadeau à un visiteur | Après son dialogue ; goûts par personnage (adore +3, aime +1, sans plus 0, n'aime pas −1) avec une réaction écrite ; les goûts découverts s'affichent au présentoir et dans le choix du cadeau |
| ✅ | Inventaire | 12 objets au plus ; bandeau en bas de l'écran au ramassage ou avec Tab ; cueillette du jour dans le journal |

## 5. Demandes des visiteurs et objets perdus

| Statut | Élément | Notes |
|---|---|---|
| 📌 | Objets perdus à retrouver | Un visiteur perd un objet précis (porte-bonheur, parapluie...) ; il est réellement posé quelque part dans le monde |
| 📌 | Choix : rendre ou garder | Le rendre agit sur l'affection et l'histoire ; le garder a aussi ses conséquences |
| 📌 | Demandes liées au monde | Ex. : le chat de Hina ; on doit l'avoir vu pour pouvoir aider. Nouvelles conditions dans l'éditeur : « possède l'objet », « a vu / trouvé » |

## 6. Le mur des ema (suivi des personnages)

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Ema lisibles au présentoir | Les ema des visiteurs restent accrochés ; « E : Lire les ema » ouvre le mur des vœux |
| ✅ | Carte par personnage | Ema dessiné, cœurs d'affection, état du lien, vœux par jour ; « ? » pour qui n'est pas encore venu |
| ✅ | Visiteurs qui ne reviennent plus | Un visiteur ignoré repart au bout de 150 s (réglable dans l'éditeur) : affection −1. Le lien s'abîme avec l'affection négative ou les visites manquées ; brisé, le personnage ne monte plus |
| ✅ | Ema qui s'abîme | Intact → fragile (affection < 0 ou 1 visite manquée) → fissuré (≤ −3 ou 2) → brisé (≤ −5 ou 3). Les ema du présentoir penchent puis tombent |
| ✅ | Prière de retour | Vendue au bureau du sanctuaire |

## 7. Le lieu qui change

| Statut | Élément | Notes |
|---|---|---|
| 💡 | État du sanctuaire | Usure des éléments négligés (mousse sur les dalles, lanterne fissurée, tuile tombée) ; les tâches du matin visent ce qui est le plus abîmé |
| 💡 | Remarques des visiteurs sur l'état du lieu | Optionnel, ligne par ligne : une condition « état du lieu » dans l'éditeur. Les dialogues qui n'en parlent pas restent inchangés |
| 💡 | Restaurations sur plusieurs jours | Toit du pavillon, sentier du belvédère, sanctuaire des renards ; changent durablement le décor |
| 💡 | Embellissements | Planter un arbre, poser une lanterne, accrocher des furin |

## 8. Fêtes et soirées

| Statut | Élément | Notes |
|---|---|---|
| 📌 | Calendrier des fêtes | Ex. : Shichi-go-san en automne (familles en kimono, bénédictions) ; préparation sur plusieurs jours |
| ✅ | Événement de nuit après la cloche | La nuit tombe (clair de lune, lanternes, lucioles), puis un événement : le plus prioritaire parmi ceux possibles ce jour-là. Écrit dans l'éditeur (« + 🌙 »), avec une créature qui sort de l'ombre (renard, tanuki, chat) ou aucune. 7 nuits écrites : première nuit, renard (2), tanuki voleur puis penaud, chat, lanterne de Fumiko |
| 📌 | Approfondir les nuits et construire un vrai lore | Plus d'événements de nuit, reliés entre eux : l'histoire du gardien, de Seiji, de la montagne, du renard. À poser d'abord dans une « bible » du monde (`docs/lore.md`) pour garder la cohérence |
| 💡 | Rituel de fin de saison | Les visiteurs qu'on a le plus aidés reviennent ensemble ; à caler dans les nuits ou dans une fête |

## 9. Faune

| Statut | Élément | Notes |
|---|---|---|
| 🔨 | Le renard | Deux nuits : il sort de l'ombre, puis revient plus près si on est resté calme et rapporte un vieil ema de Seiji. Reste : offrandes, il finit par nous suivre |
| 📌 | Le chat | Choisit ses endroits au soleil ; le caresser chaque jour débloque des choses (il guide vers un objet perdu...) |
| ✅ | Carpes de l'étang | 4 carpes koï (kohaku, sanke, showa, ogon, asagi ; modèles `koi_<robe>.glb`, une sur deux en miroir) dans l'étang de la cour. E en visant l'eau : on lance des granulés, elles accourent et gobent. Nourries, elles grandissent ; deux jours de suite, une petite carpe naît (8 au plus). E sur une carpe : lui donner un nom. Activité facultative « Nourrir les carpes » |
| ⏸ | Carnet d'observation | Oiseaux, insectes, plantes à observer et dessiner ; en dernier |

## 10. Journal du gardien

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Journal de fin de journée | Après la cloche, à la place du fondu : travaux faits, visiteurs reçus et affection gagnée, pièces reçues et dépensées, notes du jour (découvertes, lettres, renard...), une phrase d'ambiance |
| 💡 | Relecture des journées passées | La mémoire de la partie |

## 11. Progression par les personnages

| Statut | Élément | Notes |
|---|---|---|
| 💡 | Outils améliorés offerts par les visiteurs | Un meilleur balai, un seau à couvercle... liés à l'affection, pas à une boutique |
| ⏸ | Jardin sec qui raconte | Les motifs restent d'un jour à l'autre ; un visiteur les commente ou apprend un motif ; pas prioritaire |

## 12. Gardé pour plus tard

| Statut | Élément | Notes |
|---|---|---|
| ⏸ | Quête de l'ancien gardien (Seiji) | Les lettres mènent à des objets cachés dans la montagne ; à évaluer pour ne pas surcharger les journées |
| ⏸ | Changement de saison | Prévu (hiver : déneiger, casser la glace) |
| ⏸ | Météo jouable | Pluie, vent, brouillard ; plus complexe, moins prioritaire |
| ❌ | Liens entre personnages | Scènes à deux visiteurs ; trop complexe pour l'instant |

---

## Notes de conception

- **État du lieu et dialogues** : cela ne complexifie pas l'écriture si c'est optionnel. Il suffit d'une condition de plus
  dans l'éditeur (« état du lieu ≥ / ≤ X ») utilisée seulement sur quelques répliques ou visites. Un dialogue qui ne
  la teste pas fonctionne exactement comme aujourd'hui.
- **Nouvelles conditions et effets à prévoir dans l'éditeur d'histoire** (même format, même fichier) :
  `possède l'objet`, `a vu / trouvé`, `pièces ≥ X`, `état du lieu`, `fête en cours` ; effets : `donner un objet`,
  `retirer un objet`, `donner des pièces`, `perte d'un objet dans le monde`.
- **Ordre suggéré** : objets perdus (rendre ou garder : l'inventaire et la condition « possède l'objet » existent),
  puis la boutique (granulés de qualité pour les carpes, encens, prière de retour), puis les fêtes.
- **Éditeur** : onglet Objets ; goûts et réactions sur la fiche de chaque personnage ; condition « possède l'objet »
  et « pièces », effet « objet » (donner / recevoir).
- **Nouvel effet disponible** : `pièces` (+/−), utilisé par le tanuki ; servira aussi aux cadeaux et à la boutique.
