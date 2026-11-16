class_name RenderBudget
extends RefCounted
## Allègements de rendu appliqués au lancement (voir docs/audit-performance.md, lot 1).
##
## - batch(props, préfixes) : les pièces répétées (murs d'enceinte, dalles et pierres de chemin) sont dessinées par
##   un MultiMesh par modèle au lieu d'un objet par pièce. Les pièces restent dans la scène, maillage masqué :
##   leurs collisions et leurs positions (tâche de la palissade) servent toujours.
## - trim_shadows(racine) : pas d'ombre pour les pièces plates (< 35 cm de haut) ou menues (< 60 cm) : dalles,
##   mousse, feuilles, cailloux, ema, pièces... Leur ombre ne se voit pas, mais chacune était redessinée dans
##   chaque cascade d'ombre. Les créatures (chat, renard, ~0,7 m) gardent la leur.

const FLAT_H := 0.35
const TINY := 0.6

## Regroupe en MultiMesh les MeshInstance3D des enfants de `props` dont le nom commence par un des préfixes.
## Renvoie le nombre d'objets remplacés.
static func batch(props: Node3D, prefixes: Array) -> int:
	var groups := {}     # clé (maillage + matériaux) -> {mesh, mats, xforms, shadow}
	var count := 0
	for c in props.get_children():
		var nm := String(c.name)
		var hit := false
		for pf in prefixes:
			if nm.begins_with(pf):
				hit = true
				break
		if not hit:
			continue
		for n in (c as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var mats := []
			var key := str(mi.mesh.get_rid().get_id())
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				mats.append(m)
				key += ":" + (str(m.get_instance_id()) if m else "-")
			if not groups.has(key):
				groups[key] = {"mesh": mi.mesh, "mats": mats, "xforms": [], "shadow": mi.cast_shadow}
			(groups[key]["xforms"] as Array).append(props.global_transform.affine_inverse() * mi.global_transform)
			mi.visible = false
			count += 1
	for key in groups:
		var g: Dictionary = groups[key]
		var mesh: Mesh = (g["mesh"] as Mesh).duplicate()
		for s in mesh.get_surface_count():
			if g["mats"][s]:
				mesh.surface_set_material(s, g["mats"][s])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var xs: Array = g["xforms"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_%s" % String(prefixes[0])
		mmi.multimesh = mm
		mmi.cast_shadow = g["shadow"]
		props.add_child(mmi)
	return count

## Coupe l'ombre des pièces plates ou menues sous `root`. Renvoie le nombre de pièces concernées.
static func trim_shadows(root: Node) -> int:
	var n := 0
	for node in root.find_children("*", "", true, false):
		if trim_one(node):
			n += 1
	return n

static func trim_one(node: Node) -> bool:
	var gi := node as GeometryInstance3D
	if gi == null or not (gi is MeshInstance3D or gi is MultiMeshInstance3D):
		return false
	if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not gi.is_inside_tree():
		return false
	var size: Vector3
	if gi is MultiMeshInstance3D:
		# taille d'un exemplaire (et non de tout le groupe)
		var mmi := gi as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or mmi.multimesh.instance_count == 0:
			return false
		var sc: Vector3 = mmi.multimesh.get_instance_transform(0).basis.get_scale() * gi.global_transform.basis.get_scale()
		size = mmi.multimesh.mesh.get_aabb().size * sc
	else:
		var mi := gi as MeshInstance3D
		if mi.mesh == null:
			return false
		size = (mi.global_transform * mi.get_aabb()).size
	if size.y < FLAT_H or size.length() < TINY:
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return true
	return false
