shader_type spatial;
render_mode world_vertex_coords, cull_front, unshaded, depth_draw_opaque, shadows_disabled;
// Contour par inverted hull (repli : le jeu utilise des contours a l'ecran, voir screen_outline.gdshader).
// Epaisseur constante a l'ecran (en pixels), teinte brun-violet, suit le vent du feuillage.

uniform vec4 outline_color : source_color = vec4(0.17, 0.11, 0.15, 1.0);
uniform float thickness = 0.014;       // conserve pour compatibilite : sert d'echelle (0.014 = 1,4 px a 720p)
uniform float wind_sway = 0.0;

#include "res://shaders/wind.gdshaderinc"

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (wind_sway > 0.0) {
		VERTEX += wind_offset(VERTEX, origin, TIME) * wind_sway;
	}
	vec3 n = normalize(NORMAL);
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_n = PROJECTION_MATRIX * VIEW_MATRIX * vec4(VERTEX + n * 0.05, 1.0);
	vec2 sn = clip_n.xy / clip_n.w - clip.xy / clip.w;
	float l = length(sn);
	if (l > 1e-6) {
		float px = thickness / 0.014 * 1.4;
		vec2 off = sn / l * px * 2.0 / VIEWPORT_SIZE;
		clip.xy += off * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
