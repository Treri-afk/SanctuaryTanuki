shader_type spatial;
// Village de la vallée (scripts/village.gd) : maisons, sol des rizières, bosquets, vus de très loin.
// Comme les crêtes lointaines (ridge.gdshader) : pas d'éclairage du moteur ni de brouillard, une lumière simple
// (versant au soleil / à l'ombre) et une perspective aérienne réglée par Atmosphere (couleur de brume, fin du brouillard).
// Couleurs : celles des sommets (déjà linéaires) ; INSTANCE_CUSTOM.r = graine de variation par maison.
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 haze_color : source_color = vec4(0.90, 0.84, 0.76, 1.0);
uniform vec4 phase_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform vec3 sun_dir = vec3(0.5, 0.4, 0.5);    // vers le soleil
uniform float fog_end = 300.0;                 // fin du brouillard de la phase (Atmosphere)
uniform float night = 0.0;
uniform bool instanced = true;
uniform bool ground = false;                   // sol de la vallée : rizières en parcelles

varying vec3 v_wp;
varying vec3 v_n;
varying float v_seed;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_seed = instanced ? INSTANCE_CUSTOM.r : 0.5;
}

// Rizières en terrasses : parcelles de tailles variables, dorées (pas encore fauchées), chaume, quelques vertes,
// diguettes plus sombres entre elles.
vec3 paddies(vec2 p) {
	vec2 q = vec2(p.x * 0.96 + p.y * 0.28, p.y * 0.96 - p.x * 0.28);
	vec2 cell = vec2(16.0, 11.0);
	vec2 id = floor(q / cell);
	vec2 f = fract(q / cell);
	float r = hash2(id);
	vec3 gold = vec3(0.62, 0.48, 0.16);
	vec3 stub = vec3(0.42, 0.33, 0.20);
	vec3 green = vec3(0.30, 0.38, 0.14);
	vec3 col = r < 0.55 ? gold : (r < 0.85 ? stub : green);
	col *= 0.88 + 0.24 * hash2(id + 7.0);
	float bund = max(smoothstep(0.92, 0.985, f.x) + smoothstep(0.08, 0.015, f.x), smoothstep(0.9, 0.98, f.y) + smoothstep(0.1, 0.02, f.y));
	return mix(col, vec3(0.24, 0.24, 0.14), clamp(bund, 0.0, 1.0) * 0.7);
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (ground) {
		// COLOR.a : 1 = rizières, 0 = terre battue du village (déjà dans COLOR.rgb)
		base = mix(base, paddies(v_wp.xz), COLOR.a);
	} else {
		base *= mix(0.86, 1.12, fract(v_seed * 7.31));
	}
	vec3 n = normalize(v_n);
	vec3 sd = normalize(sun_dir);
	float lit = clamp(dot(n, sd), 0.0, 1.0) * smoothstep(-0.05, 0.12, sd.y);
	float sky = 0.58 + 0.22 * n.y;
	vec3 col = base * phase_tint.rgb * (sky + 0.75 * lit * sun_color.rgb);
	col *= 1.0 - 0.45 * night;
	// perspective aérienne : la vallée baigne dans la brume de la phase
	float dist = length(v_wp - CAMERA_POSITION_WORLD);
	float k = clamp(pow(dist / (fog_end * 2.1), 1.3), 0.0, 0.93);
	ALBEDO = mix(col, haze_color.rgb, k);
}
