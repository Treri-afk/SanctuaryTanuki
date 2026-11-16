extends Node
## Démo du dialogue visual novel de Hina (portrait 3D en direct), sans intervention : sert à enregistrer une vidéo.
##   godot --path . --write-movie demo.avi --fixed-fps 30 -- --vndemo --day=2
## (le Movie Maker de Godot écrit chaque image ; la démo quitte le jeu à la fin)

const HOLD := 1.8   # secondes de lecture après qu'une réplique a fini de s'écrire

func run(g: Node3D) -> void:
	await get_tree().create_timer(3.0).timeout   # fin du fondu d'ouverture
	g.hud.visible = false
	g.player.global_position = Vector3(-10.6, 0.05, -21.4)
	g.player.rotation_degrees.y = 120.0
	g.player.head.rotation_degrees.x = -12.0
	g.player.input_enabled = false
	await get_tree().create_timer(0.6).timeout
	var visit := {
		"id": "demo_hina", "character": "fillette", "start": "n1",
		"nodes": {
			"n1": {"type": "line", "speaker": "fillette", "expr": "triste", "next": "n2",
				"text": "Bonjour... Vous n'avez pas vu un chat ? Il est blanc avec des taches rousses. Il s'appelle Mochi."},
			"n2": {"type": "line", "speaker": Story.PLAYER, "next": "n3",
				"text": "J'ai vu un chat comme ça près de la mare, dans la forêt."},
			"n3": {"type": "line", "speaker": "fillette", "expr": "surpris", "next": "n4",
				"text": "C'est vrai ?! La mare après le petit pont ?"},
			"n4": {"type": "line", "speaker": "fillette", "expr": "sourire", "next": "n5",
				"text": "Merci. Mochi aime bien les endroits au soleil, et les gens qui ont l'air gentils."},
			"n5": {"type": "line", "speaker": "fillette", "expr": "neutre", "next": "",
				"text": "Je laisse un ema pour lui. Les dieux d'ici, ils s'occupent aussi des chats ?"},
		},
	}
	g.vn.play_visit(visit)
	var waited := 0.0
	while g.vn.visible:
		await get_tree().process_frame
		if g.vn._typing:
			waited = 0.0
			continue
		waited += get_process_delta_time()
		if waited >= HOLD:
			waited = 0.0
			g.vn._advance = true
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
