extends Node
## Bus de signaux global.
signal task_progress(id: StringName, value: int, target: int)
signal task_done(id: StringName)
signal phase_changed(phase: int)
signal day_started(day: int)
signal day_ended(day: int)
signal visitor_left(id: StringName)
signal toast(text: String)
signal affection_changed(character: String, value: int, delta: int)
signal coins_changed(total: int, delta: int)
signal inventory_changed(item: String, count: int, delta: int)   # pièces gagnées (delta > 0) ou dépensées (delta < 0)
