"""Calligraphie en maillage : texte japonais (police Hiragino Mincho de macOS) converti en triangles 2D,
recoupes assez fin pour epouser une surface courbe (lanterne, etoffe). Utilise par paper_lantern.py et festival.py."""
import bpy
import bmesh

FONT = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"


def glyph_mesh(text, height, bold, max_edge=0.022, vertical=True, space=0.92):
    """Texte centre sur (0, 0), haut de `height` m ; vertical : un caractere par ligne.
    bold : epaississement du trait (unites de la police, ~0.02-0.03). Renvoie ([(x, y)], [faces])."""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = "\n".join(text) if vertical else text
    cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.space_line = space
    cu.offset = bold
    cu.resolution_u = 3
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    me = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    s = height / (max(ys) - min(ys))
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    for v in bm.verts:
        v.co.x, v.co.y, v.co.z = (v.co.x - cx) * s, (v.co.y - cy) * s, 0.0
    for _ in range(6):                        # recoupe les grands triangles
        long = [e for e in bm.edges if e.calc_length() > max_edge]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.index_update()
    verts = [(v.co.x, v.co.y) for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    bpy.data.objects.remove(ob)
    return verts, faces
