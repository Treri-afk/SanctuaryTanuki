# Éditeur d'histoire — Gardien de sanctuaire

Application web locale, sans installation, pour écrire l'histoire du jeu : personnages, visites, répliques, choix,
affection et conditions. Elle lit et écrit le fichier du jeu `data/story/story.json` (à la racine du dépôt), dont le format est décrit dans
`docs/story-format.md`.

## Lancer

Ouvrir `index.html` dans **Chrome** ou **Edge** (double-clic). Rien à installer.

Avec Chrome ou Edge, **Ouvrir…** puis **Enregistrer** écrivent directement dans le fichier du jeu : choisissez
`data/story/story.json` du dépôt. Le jeu le relit à chaque lancement.
Avec un autre navigateur, **Enregistrer** télécharge `story.json`, à copier dans `data/story/`.

Le brouillon est gardé automatiquement dans le navigateur entre deux sessions.

## Principes

- **Personnage** : nom, couleur du placeholder, expressions (portraits `assets/portraits/<id>_<expression>.png`),
  affection de départ et maximale.
- **Visite** : un personnage monte au sanctuaire. Elle a des jours possibles, une priorité, des conditions
  (affection, drapeau, jour, visite déjà jouée), un lieu où il attend, un vœu d'ema, et un dialogue.
- **Dialogue** : un graphe de noeuds.
  - **Réplique** : un personnage, vous ou la narration parle.
  - **Choix** : le joueur choisit une réponse ; chaque réponse peut changer l'affection, poser un drapeau, et
    n'être proposée que sous conditions.
  - **Condition** : bifurcation invisible (par exemple « si affection de Fumiko ≥ 3 »).
  - **Fin**.
- **Drapeaux** : marqueurs libres. Un choix les pose (« fumiko_revient »), une condition les teste plus tard
  (la visite du jour 3 n'a lieu que si le drapeau est posé).

## Utilisation

- Choisir une visite à gauche ; son dialogue s'affiche au centre.
- Tirer depuis le rond à droite d'un noeud vers un autre noeud pour les relier ; lâcher dans le vide crée la
  réplique suivante. Cliquer un lien puis **Suppr** pour le retirer.
- Double-clic dans le vide : nouvelle réplique. **Suppr** : supprimer le noeud choisi. **Ctrl+D** : dupliquer.
- **▶ Tester** : joue le dialogue comme dans le jeu, avec l'affection et les drapeaux réglables à gauche.
- **Ensemble** : quelles visites peuvent avoir lieu chaque jour, et qui pose ou teste chaque drapeau.
- En bas à gauche : erreurs (liens cassés, personnage inconnu...) et avertissements (noeud jamais atteint,
  drapeau testé mais jamais posé...). Cliquer une ligne y mène.
