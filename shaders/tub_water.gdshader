shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Eau claire et peu profonde (bac des poissons rouges) : on voit le fond et les poissons ; plus un poisson nage
// profond, plus il se fond dans le bleu (indice pour savoir lequel on peut attraper). Petites rides, reflets
// nets des lanternes, et des ondes en anneau là où l'on touche l'eau (ripples : xz monde, âge, force).

uniform vec3 tint : source_color = vec3(0.55, 0.80, 0.84);
uniform vec3 deep : source_color = vec3(0.16, 0.42, 0.56);
uniform float clarity = 0.075;          // épaisseur d'eau (m) pour en absorber les deux tiers
uniform float base_alpha = 0.08;
uniform vec4 ripples[6];

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

float height(vec2 p, float t) {
	float h = (vn(p * 18.0 + vec2(t * 0.35, t * 0.2)) + vn(p * 31.0 - vec2(t * 0.25, -t * 0.3))) * 0.0015;
	for (int i = 0; i < 6; i++) {
		vec4 r = ripples[i];
		if (r.w <= 0.0) continue;
		float d = distance(p, r.xy);
		float front = r.z * 0.22;
		float w = exp(-pow((d - front) * 40.0, 2.0)) * exp(-r.z * 2.2) * r.w;
		h += sin((d - front) * 160.0) * w * 0.004;
	}
	return h;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float e = 0.004;
	float h0 = height(wp.xz, t);
	vec2 g = vec2(height(wp.xz + vec2(e, 0.0), t) - h0, height(wp.xz + vec2(0.0, e), t) - h0) / e;
	vec3 n_world = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// épaisseur d'eau derrière ce point (texture de profondeur)
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vec3 behind = up.xyz / up.w;
	float thick = max(0.0, length(behind) - length(VERTEX));
	float a = 1.0 - exp(-thick / clarity);
	// incidence rasante : le ciel se reflète davantage
	float fres = pow(1.0 - clamp(dot(normalize(-VERTEX), NORMAL), 0.0, 1.0), 4.0);
	ALBEDO = mix(tint, deep, a) + vec3(0.25) * fres;
	ALPHA = clamp(base_alpha + a * 0.62 + fres * 0.35, 0.0, 0.94);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
