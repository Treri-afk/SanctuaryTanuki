shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque, shadows_disabled;
// Cretes lointaines dans la brume (anneaux de terrain.gd, UV.y = 0 en bas, 1 au sommet).
//  - perspective aerienne : plus la crete est loin, plus elle prend la couleur de la brume d'horizon ;
//  - le pied se fond exactement dans la brume (haze_color = bande d'horizon du ciel, reglee par Atmosphere) ;
//  - les versants tournes vers le soleil se rechauffent, ceux a contre-jour restent en silhouette ;
//  - la ligne de crete des cretes proches est decoupee en silhouettes de coniferes et de feuillus.

uniform vec4 top_color : source_color = vec4(0.45, 0.55, 0.60, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.80, 0.78, 0.74, 1.0);   // conserve (compatibilite), remplace par haze_color
uniform vec4 haze_color : source_color = vec4(0.90, 0.84, 0.76, 1.0);
uniform vec4 phase_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform vec3 sun_dir = vec3(0.5, 0.4, 0.5);    // vers le soleil
uniform float haze_amount = 1.0;

varying float v_r;
varying vec3 v_wp;
varying vec2 v_dir;

float r_hash(float x) {
	return fract(sin(x * 91.17) * 43758.5453);
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_r = length(v_wp.xz);
	v_dir = v_wp.xz / max(v_r, 1.0);
}

void fragment() {
	float r = v_r;
	// silhouettes d'arbres sur les cretes proches
	float trees = 1.0 - smoothstep(280.0, 420.0, r);
	float top_y = -250.0 + (v_wp.y + 250.0) / max(UV.y, 1e-4);
	float below = top_y - v_wp.y;
	if (trees > 0.0) {
		float s = UV.x * 6.2831853 * r;           // abscisse curviligne en metres
		float w = 7.0;
		float cell = floor(s / w);
		float f = fract(s / w);
		float hgt = (4.0 + 7.0 * r_hash(cell)) * trees;
		float conifer = step(0.35, r_hash(cell + 3.1));
		float shape = conifer > 0.5 ? (1.0 - abs(f * 2.0 - 1.0)) : sqrt(max(1.0 - pow(f * 2.0 - 1.0, 2.0), 0.0));
		float cut = hgt * (1.0 - shape);
		if (below < cut) {
			discard;
		}
	}
	float far_k = smoothstep(200.0, 560.0, r);
	vec3 base = top_color.rgb * phase_tint.rgb;
	// versant eclaire : la crete fait face au centre, sa normale est -v_dir
	vec2 sd = normalize(sun_dir.xz + 1e-5);
	float facing = clamp(dot(-v_dir, sd), 0.0, 1.0);
	float low_sun = 1.0 - smoothstep(0.1, 0.6, sun_dir.y);
	base = mix(base, base * sun_color.rgb * 1.5, facing * (0.35 + 0.4 * low_sun) * (1.0 - far_k * 0.6));
	base *= mix(0.82, 1.0, 1.0 - facing * (1.0 - low_sun));
	vec3 col = mix(base, haze_color.rgb, clamp(far_k * 0.7 * haze_amount + 0.08, 0.0, 1.0));
	// pied dans la brume
	float h01 = clamp((v_wp.y + 20.0) / max(top_y + 20.0, 1.0), 0.0, 1.0);
	float foot = 1.0 - smoothstep(0.0, 0.9, h01);
	col = mix(col, haze_color.rgb, clamp(foot * haze_amount, 0.0, 1.0));
	ALBEDO = col;
}
