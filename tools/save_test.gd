extends Node
## Test des sauvegardes et du menu pause : godot --path . -- --savetest  (dossier user://saves_test/, à part)

var game: Node3D

func run(g: Node3D) -> void:
	game = g
	await get_tree().create_timer(1.5).timeout
	var ok := func(c: bool, what: String): print("SAVETEST %s %s" % ["ok" if c else "ÉCHEC", what])
	for i in SaveGame.SLOTS:
		SaveGame.erase(i)
	ok.call(SaveGame.latest() == -1, "aucune sauvegarde au départ")
	# une partie bien remplie
	GameState.reset_story()
	GameState.add_coins(12)
	GameState.add_affection("vieille_dame", 3)
	GameState.met["vieille_dame"] = true
	GameState.flags[&"fumiko_revient"] = true
	GameState.ema_log.append({"character": "vieille_dame", "wish": "Que la montagne se souvienne.", "day": 1})
	GameState.add_item("kaki", 2)
	GameState.stock["encens"] = 2
	GameState.koi.append({"pattern": "ogon", "size": 1.3, "name": "Kin", "days": 2, "seed": 77})
	GameState.stats["tasks"] = 5
	game.extras.letters_read = 2
	game.extras.found["belvedere"] = true
	game._yesterday = [&"haies", &"priere"] as Array[StringName]
	var coins := GameState.coins
	ok.call(SaveGame.write(1, SaveGame.capture(game, 2)), "écriture de l'emplacement 2")
	# on abîme tout, puis on recharge
	GameState.reset_story()
	game.extras.letters_read = 0
	game.extras.found.clear()
	game._yesterday = [] as Array[StringName]
	var data := SaveGame.read(1)
	ok.call(int(data.get("day", 0)) == 2, "jour enregistré : 2")
	SaveGame.apply(game, data)
	ok.call(GameState.coins == coins, "pièces (%d)" % GameState.coins)
	ok.call(int(GameState.affection.get("vieille_dame", 0)) == 3 and GameState.met.get("vieille_dame", false), "affection et rencontre")
	ok.call(GameState.has_flag(&"fumiko_revient"), "drapeau d'histoire (StringName conservé)")
	ok.call(GameState.item_count("kaki") == 2 and int(GameState.stock.get("encens", 0)) == 2, "poches et réserve de la boutique")
	ok.call(GameState.koi.size() == 5 or (GameState.koi.back() as Dictionary).get("name", "") == "Kin", "carpes (nom conservé)")
	ok.call(game.extras.letters_read == 2 and game.extras.found.has("belvedere"), "lettres lues et découvertes")
	ok.call(game._yesterday.has(&"haies"), "tâches de la veille")
	ok.call(int(GameState.stats.get("tasks", 0)) == 5, "statistiques de la partie")
	ok.call(game.extras.visitor_ema.size() >= 1, "ema du présentoir raccrochés")
	var inf := SaveGame.info(1)
	ok.call(int(inf.get("day", 0)) == 2 and int(inf.get("coins", 0)) == coins, "résumé pour les menus")
	ok.call(SaveGame.latest() == 1, "dernière sauvegarde = emplacement 2")
	# pause : l'arbre s'arrête, puis repart
	game.menus.open_pause()
	ok.call(get_tree().paused and game.menus.paused, "pause : jeu figé")
	game.menus.close_pause()
	ok.call(not get_tree().paused, "reprise")
	SaveGame.erase(1)
	ok.call(not SaveGame.exists(1), "effacement")
	# vraie nouvelle partie puis reprise, par les mêmes fonctions que l'écran titre
	game.start_new_game(2)
	await get_tree().create_timer(4.0).timeout
	ok.call(GameState.day == 1 and GameState.slot == 2 and SaveGame.exists(2), "nouvelle partie : jour 1, sauvegarde créée")
	GameState.add_coins(4)
	SaveGame.write(2, SaveGame.capture(game, 2))
	game.load_and_start(2)
	await get_tree().create_timer(4.0).timeout
	ok.call(GameState.day == 2 and GameState.coins == int(SaveGame.info(2).get("coins", -1)), "reprise au matin du jour 2")
	SaveGame.erase(2)
	print("SAVETEST fin")
	get_tree().quit()
