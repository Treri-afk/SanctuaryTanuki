shader_type spatial;
// Lumières du village de la vallée (scripts/village.gd) : fenêtres et lanternes de rue, de petits halos additifs
// qui percent la brume. Le soir les fenêtres s'allument une à une ; la nuit, une partie s'éteint. Chaque fenêtre
// change d'état de loin en loin (sa propre période), si bien qu'on voit toujours quelques lumières s'allumer ou
// s'éteindre dans la vallée.
// INSTANCE_CUSTOM : r = graine, g = 0 fenêtre / 1 lanterne de rue.
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

uniform float windows_on = 0.0;     // part des fenêtres allumées (0 le jour)
uniform float lanterns_on = 0.0;    // lanternes de rue (0 ou 1, en fondu)
uniform float energy = 4.5;
uniform vec4 window_color : source_color = vec4(1.0, 0.74, 0.42, 1.0);
uniform vec4 lantern_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);

varying float v_seed;
varying float v_kind;

float h1(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void vertex() {
	v_seed = INSTANCE_CUSTOM.r;
	v_kind = INSTANCE_CUSTOM.g;
}

// Allumée ou non pendant le cycle c (tirage propre à la fenêtre).
float lit_in(float c) {
	return step(h1(c * 1.37 + v_seed * 917.0), windows_on);
}

void fragment() {
	float s;
	vec3 col;
	if (v_kind > 0.5) {
		s = lanterns_on * (0.85 + 0.15 * sin(TIME * (5.0 + 3.0 * v_seed) + v_seed * 40.0));
		col = lantern_color.rgb;
	} else {
		float period = mix(70.0, 260.0, h1(v_seed * 3.1));
		float t = TIME / period + v_seed * 17.0;
		float c = floor(t);
		float f = fract(t) * period;              // secondes depuis le dernier changement possible
		s = mix(lit_in(c - 1.0), lit_in(c), smoothstep(0.0, 0.6, f));
		col = window_color.rgb * mix(0.8, 1.15, h1(v_seed * 5.7));
	}
	vec2 uv = UV * 2.0 - 1.0;
	float d = 1.0 - smoothstep(0.15, 1.0, length(uv));
	ALBEDO = col * energy * s * d * d;
}
