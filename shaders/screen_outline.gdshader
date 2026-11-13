shader_type spatial;
render_mode unshaded, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Contours a l'ecran (remplacent l'inverted hull en jeu) : un quad plein ecran lit la profondeur et les normales
// et assombrit (multiplie) les pixels situes sur les silhouettes et les plis marques.
//  - silhouettes : laplacien de 1/profondeur (nul sur un plan, donc pas de faux traits sur le sol rasant) ;
//    le trait est pose du cote de l'objet le plus proche, largeur constante en pixels ;
//  - plis : ecart de normales entre voisins ;
//  - la couleur du trait est une teinte brun-violet qui multiplie la couleur sous-jacente (encre « coloree ») ;
//  - les traits s'estompent avec la distance, comme dans la brume.
// Le quad (QuadMesh 2x2) est cree par Toon.make_screen_outline().

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.36, 0.26, 0.34, 1.0);
uniform float line_width = 0.8;          // en pixels a 720p (echantillons entre deux pixels : bord adouci)
uniform float depth_threshold = 0.035;   // relatif
uniform float normal_threshold = 0.45;
uniform float crease_strength = 0.55;
uniform float fade_start = 18.0;
uniform float fade_end = 85.0;
uniform float near_fade = 0.25;          // pas de traits sur l'outil tenu tout pres de la camera

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float inv_depth(vec2 uv, mat4 inv_proj) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.w / v.z;   // 1 / distance lineaire
}

void fragment() {
	vec2 px = line_width * max(VIEWPORT_SIZE.y / 720.0, 1.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float ic = inv_depth(uv, INV_PROJECTION_MATRIX);
	float il = inv_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float ir = inv_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float iu = inv_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float idn = inv_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dist = 1.0 / max(ic, 1e-6);
	// laplacien relatif : negatif quand le pixel est plus proche que ses voisins (bord de silhouette cote objet)
	float lap_x = (il + ir - 2.0 * ic) / ic;
	float lap_y = (iu + idn - 2.0 * ic) / ic;
	float e = max(-lap_x, -lap_y);
	float edge = smoothstep(depth_threshold, depth_threshold * 2.5, e);
	// plis : normales en espace vue
	vec3 nc = textureLod(normal_tex, uv, 0.0).xyz * 2.0 - 1.0;
	vec3 nr = textureLod(normal_tex, uv + vec2(px.x, 0.0), 0.0).xyz * 2.0 - 1.0;
	vec3 nd = textureLod(normal_tex, uv + vec2(0.0, px.y), 0.0).xyz * 2.0 - 1.0;
	float nn = max(1.0 - dot(nc, nr), 1.0 - dot(nc, nd));
	float crease = smoothstep(normal_threshold, normal_threshold * 1.6, nn) * crease_strength;
	// pas de plis aux sauts de profondeur cote lointain (deja traites) ni sur le ciel
	float far_side = max(lap_x, lap_y);
	crease *= 1.0 - smoothstep(depth_threshold, depth_threshold * 2.0, far_side);
	float k = max(edge, crease);
	// herbe (ROUGHNESS = 0, demande GND) : pas de traits sur les brins ni au contact des brins
	float rc = textureLod(normal_tex, uv, 0.0).a;
	float rr = textureLod(normal_tex, uv + vec2(px.x, 0.0), 0.0).a;
	float rd = textureLod(normal_tex, uv + vec2(0.0, px.y), 0.0).a;
	k *= smoothstep(0.03, 0.12, min(rc, min(rr, rd)));
	k *= 1.0 - smoothstep(fade_start, fade_end, dist);
	k *= smoothstep(near_fade, near_fade * 2.0, dist);
	k *= step(ic, 1e5) * step(1e-4, ic);
	ALBEDO = mix(vec3(1.0), line_color.rgb, clamp(k, 0.0, 1.0));
}
