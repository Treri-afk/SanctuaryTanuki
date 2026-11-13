shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Halo doré au sol sous un objet à ramasser : disque doux qui respire lentement.
uniform vec4 color : source_color = vec4(1.0, 0.78, 0.35, 1.0);
uniform float strength = 0.45;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float pulse = 0.75 + 0.25 * sin(TIME * 2.2 + NODE_POSITION_WORLD.x * 3.0);
	float a = (1.0 - smoothstep(0.15, 1.0, d)) * strength * pulse;
	ALBEDO = color.rgb * a;
}
