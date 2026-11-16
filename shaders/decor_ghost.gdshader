shader_type spatial;
// Voile coloré posé sur un objet de décoration (scripts/decor.gd) : vert = on peut poser, rouge = refusé,
// jaune = objet visé en mode Arranger. Le voile est un peu gonflé le long des normales : il ne se bat pas avec la
// surface de l'objet (sinon il grésille), et il ne s'écrit pas dans la profondeur.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.92, 0.55, 0.36);
uniform float grow = 0.008;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	// plus dense sur les bords (effet de liseré), léger souffle pour montrer que l'objet n'est pas encore posé
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * (0.55 + 0.75 * rim) * (0.9 + 0.1 * sin(TIME * 4.0));
}
