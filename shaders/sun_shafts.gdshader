shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Rayons de soleil (crepusculaires) a l'ecran : pour chaque pixel, on marche vers la position du soleil a l'ecran
// et on compte les echantillons qui voient le ciel. Les trouees entre les troncs et les houppiers donnent des
// faisceaux qui partent du soleil. Quad plein ecran cree par Atmosphere ; sun_dir et couleurs reglees par phase.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 sun_dir = vec3(0.0, 0.3, 1.0);           // vers le soleil (monde)
uniform vec4 shaft_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float intensity = 0.35;
uniform float decay = 0.955;
uniform float length_scale = 0.75;                     // fraction du chemin vers le soleil parcourue
uniform float near_mask = 6.0;                         // les surfaces tres proches recoivent moins de rayons

const int STEPS = 28;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float s_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 sc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(normalize(sun_dir), 0.0);
	vec3 cam_fwd = -INV_VIEW_MATRIX[2].xyz;
	float facing = dot(normalize(cam_fwd), normalize(sun_dir));
	if (sc.w <= 0.0 || facing < 0.05) {
		ALBEDO = vec3(0.0);
	} else {
		vec2 sun_uv = (sc.xy / sc.w) * 0.5 + 0.5;
		vec2 uv = SCREEN_UV;
		vec2 delta = (sun_uv - uv) * length_scale / float(STEPS);
		float jitter = s_hash(FRAGCOORD.xy + fract(TIME) * 61.0);
		vec2 p = uv + delta * jitter;
		float w = 1.0;
		float acc = 0.0;
		float norm = 0.0;
		for (int i = 0; i < STEPS; i++) {
			vec2 q = clamp(p, vec2(0.001), vec2(0.999));
			float d = textureLod(depth_tex, q, 0.0).r;
			acc += step(d, 1e-7) * w;
			norm += w;
			w *= decay;
			p += delta;
		}
		acc /= norm;
		// pixel lui-meme : le ciel n'a pas besoin d'etre eclairci (il porte deja le halo du soleil)
		float d0 = textureLod(depth_tex, uv, 0.0).r;
		float self_sky = step(d0, 1e-7);
		vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d0, 1.0);
		float dist = -v.z / v.w;
		float k = smoothstep(0.05, 0.6, facing);
		float dist_k = smoothstep(0.0, near_mask, dist);
		float radial = 1.0 - smoothstep(0.0, 1.2, length((uv - sun_uv) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)));
		float shafts = acc * k * mix(1.0, 0.35, self_sky) * dist_k * (0.35 + 0.65 * radial);
		ALBEDO = shaft_color.rgb * shafts * intensity;
	}
}
