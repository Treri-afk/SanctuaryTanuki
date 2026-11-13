extends SceneTree
## Usage : godot --headless --path . --script res://tools/check_model.gd -- res://assets/models/x.glb
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("CHECK usage: -- res://assets/models/x.glb"); quit(1); return
	for path in args:
		var res = load(path)
		if res == null or not (res is PackedScene):
			print("CHECK ERROR: cannot load ", path); quit(1); return
		var inst: Node = (res as PackedScene).instantiate()
		var aabb := AABB()
		var first := true
		var tris := 0
		var cols := []
		var empties := []
		var stack: Array = [inst]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children(): stack.append(c)
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var a: AABB = mi.global_transform * mi.get_aabb() if n.is_inside_tree() else _xf(mi) * mi.get_aabb()
				aabb = a if first else aabb.merge(a)
				first = false
				var m := mi.mesh
				for s in m.get_surface_count():
					var arr := m.surface_get_arrays(s)
					tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			elif n is CollisionShape3D:
				cols.append(n.get_parent().name)
			elif n is Node3D and n.get_class() == "Node3D" and n.get_child_count() == 0:
				empties.append(n.name)
		print("CHECK ", path, " size=", aabb.size, " min=", aabb.position, " tris~", tris, " collisions=", cols, " leafnodes=", empties)
		inst.free()
	quit(0)

func _xf(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
