shader_type spatial;
render_mode unshaded, shadows_disabled, world_vertex_coords;
// Flamme de lanterne : goutte etiree qui vacille, coeur blanc-jaune, bord orange, assez lumineuse pour le glow.

uniform vec4 core_color : source_color = vec4(1.0, 0.92, 0.70, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.48, 0.12, 1.0);
uniform float intensity = 4.5;

varying float v_h;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 lp = VERTEX - o;
	v_h = clamp(lp.y / 0.08 * 0.5 + 0.5, 0.0, 1.0);
	float ph = o.x * 3.1 + o.z * 1.7;
	float k = v_h * v_h;
	// pointe effilee et vacillante
	lp.xz *= mix(1.0, 0.35, k);
	lp.xz += vec2(sin(TIME * 7.3 + ph), sin(TIME * 5.9 + ph * 1.3)) * 0.012 * k;
	lp.y *= 1.0 + 0.12 * sin(TIME * 11.0 + ph) * k;
	VERTEX = o + lp;
}

void fragment() {
	float rim = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(edge_color.rgb, core_color.rgb, smoothstep(0.2, 0.9, rim) * (1.0 - v_h * 0.6));
	ALBEDO = c * intensity;
}
