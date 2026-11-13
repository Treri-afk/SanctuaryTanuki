shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Lucioles / eclats chauds du soir pres de l'eau : point lumineux qui clignote lentement (assez fort pour le glow).

uniform vec4 fly_color : source_color = vec4(1.0, 0.85, 0.42, 1.0);
uniform float intensity = 3.0;
uniform float level = 1.0;

varying float v_blink;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	float b = sin(TIME * (0.9 + seed * 1.3) + seed * 30.0);
	v_blink = smoothstep(0.1, 0.9, b) * sin(clamp(INSTANCE_CUSTOM.y, 0.0, 1.0) * 3.14159);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float a = exp(-r2 * 9.0) + exp(-r2 * 2.5) * 0.25;
	ALBEDO = fly_color.rgb * a * v_blink * intensity * level;
}
