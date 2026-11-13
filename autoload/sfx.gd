extends Node
## Autoload "Sfx" : tous les sons du jeu (synthétisés, aucun fichier audio).
## Le reste du code n'appelle que ces deux fonctions ; un nom inconnu est ignoré sans erreur.
##
##   Sfx.play(&"nom", position_ou_null, volume_db)   son ponctuel (3D si une position Vector3 est donnée)
##   Sfx.loop(&"nom", actif)                         son continu que le code du jeu démarre et arrête
##
## Sons ponctuels attendus : sweep, leaves, pickup, putdown, water_draw, water_pour, match_strike, flame,
##   bell, rope, door_slide, paper, ema_hang, tea, rake, cat, discover, task_done, ui_click, step
## Boucles attendues : sweep_loop, rake_loop, pour_loop
## Ambiances (gérées ici, sans appel du jeu) : vent, ruisseau près de l'eau, pas du joueur (groupe "player").

func play(_sound: StringName, _at: Variant = null, _volume_db: float = 0.0) -> void:
	pass

func loop(_sound: StringName, _on: bool) -> void:
	pass
