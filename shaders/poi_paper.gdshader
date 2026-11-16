shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded;
// Papier de l'épuisette (poi) : blanc et presque opaque à sec, gris et translucide une fois mouillé ;
// il se troue au fil des dégâts (des déchirures irrégulières qui partent du centre), puis cède.

uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.5) = 0.0;
uniform float seed = 1.0;
uniform vec3 light_col = vec3(1.0, 0.96, 0.9);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.37);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;               // disque de rayon 1
	float r = length(p);
	if (r > 1.0) discard;
	// déchirure : bruit + préférence pour le centre (là où l'on appuie)
	float n = vnoise(p * 3.2) * 0.6 + vnoise(p * 7.0 + 3.1) * 0.4;
	float tear = n * 0.85 + r * 0.55;
	float hole = damage * 1.25;
	if (tear < hole - 0.25) discard;
	// bord de la déchirure : effiloché, plus sombre
	float edge = smoothstep(hole - 0.25, hole - 0.05, tear);
	vec3 dry = vec3(0.97, 0.96, 0.93) * light_col;
	vec3 soaked = vec3(0.70, 0.74, 0.76) * light_col;
	vec3 col = mix(dry, soaked, wet);
	// fibres du papier
	col *= 0.94 + vnoise(p * 30.0) * 0.08;
	col = mix(col * 0.7, col, edge);
	ALBEDO = col;
	ALPHA = mix(0.95, 0.55, wet) * mix(0.6, 1.0, edge);
}
