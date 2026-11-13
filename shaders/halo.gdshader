shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Halo lumineux doux autour d'une flamme (billboard additif, s'efface au contact des surfaces proches).

uniform vec4 halo_color : source_color = vec4(1.0, 0.62, 0.28, 1.0);
uniform float intensity = 0.55;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

void vertex() {
	// billboard face camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = pow(max(1.0 - r, 0.0), 2.6) + pow(max(1.0 - r, 0.0), 12.0) * 0.6;
	float flick = 0.9 + 0.1 * sin(TIME * 9.0 + MODEL_MATRIX[3].x * 5.0);
	// adoucissement contre la geometrie (pas de coupure nette dans le toit de la lanterne)
	float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene = -sv.z / sv.w;
	float soft = clamp((scene + VERTEX.z) / 0.35, 0.0, 1.0);
	ALBEDO = halo_color.rgb * a * intensity * flick * soft;
}
