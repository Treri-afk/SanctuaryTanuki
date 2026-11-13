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
| 📌 | Son et ambiance | Le jeu est presque muet ; les gestes appellent déjà des sons (`Sfx`) qui n'existent pas encore |
| 📌 | Modèles 3D | Outils, haies, bambous et planches sont des formes simples faites en code ; le reste mérite une passe |
| 📌 | Débogage de certaines tâches | À lister au fil des parties |
| 📌 | Personnages | Portraits et sprites (à dessiner) ; les visiteurs sont encore des rectangles colorés |
| 🔨 | Cohérence des dialogues avec le monde | Corrigé pour Hina : la réponse « j'ai vu un chat près de la mare » n'apparaît que si on a caressé le chat ou qu'il est venu la nuit (drapeau `chat_vu`) |

---

## 3. Économie douce : pièces et boutique

| Statut | Élément | Notes |
|---|---|---|
| ✅ | Les visiteurs déposent des pièces dans le tronc à offrandes | En arrivant, chaque visiteur prie au tronc et y jette ses pièces, ramassées automatiquement. Montant : « pièces offertes » du personnage (éditeur) + 1 par tranche de 3 d'affection |
| ✅ | Compteur de pièces discret | Caché par défaut ; apparaît quand on gagne ou dépense, pendant la prière, ou en maintenant Tab (HUD complet) |
| ✅ | La pièce de la prière se dépense | S'il n'en reste aucune, le rite continue sans |
| 📌 | Boutique du bureau du sanctuaire | Dépenser les pièces pour débloquer des activités et objets |
| 💡 | Encens dans le pavillon | Première activité à débloquer ; effet à définir (ambiance, affection des visiteurs du jour...) |
| 💡 | Prière de retour | Objet de la boutique : fait revenir un visiteur qui avait décidé de ne plus venir |
| 💡 | Autres achats | Matériaux de restauration, offrandes, décorations, à compléter |

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
| 📌 | Prière de retour | Dans la boutique : `GameState.bring_back(personnage)` existe déjà, il reste à la vendre |

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
| ✅ | Carpes de l'étang | 4 carpes koï (kohaku, sanke, showa, ogon, asagi) dans l'étang de la cour. E en visant l'eau : on lance des granulés, elles accourent et gobent. Nourries, elles grandissent ; deux jours de suite, une petite carpe naît (8 au plus). E sur une carpe : lui donner un nom. Activité facultative « Nourrir les carpes » |
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
