shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Feuille d'erable en particule : silhouette a 5 lobes decoupee dans un quad, tournoie en tombant
// (axe et vitesse propres a chaque feuille), se pose a plat au sol. Eclairage toon partage.

uniform vec4 col_a : source_color = vec4(0.72, 0.27, 0.16, 1.0);
uniform vec4 col_b : source_color = vec4(0.85, 0.51, 0.17, 1.0);
uniform vec4 col_c : source_color = vec4(0.91, 0.67, 0.24, 1.0);
uniform vec4 col_d : source_color = vec4(0.62, 0.21, 0.14, 1.0);

#include "res://shaders/toon_light.gdshaderinc"

varying vec3 v_col;

mat3 rot_axis(vec3 a, float ang) {
	float s = sin(ang);
	float c = cos(ang);
	float oc = 1.0 - c;
	return mat3(vec3(oc * a.x * a.x + c, oc * a.x * a.y + a.z * s, oc * a.z * a.x - a.y * s),
		vec3(oc * a.x * a.y - a.z * s, oc * a.y * a.y + c, oc * a.y * a.z + a.x * s),
		vec3(oc * a.z * a.x + a.y * s, oc * a.y * a.z - a.x * s, oc * a.z * a.z + c));
}

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	vec3 v = VERTEX;
	// legere courbure de la feuille
	v.z += (v.x * v.x) * 2.5;
	if (INSTANCE_CUSTOM.w > 0.5) {
		// posee a plat
		mat3 r = rot_axis(vec3(1.0, 0.0, 0.0), -1.5708) ;
		r = rot_axis(vec3(0.0, 1.0, 0.0), seed * 6.2831) * r;
		v = r * v;
		NORMAL = r * NORMAL;
	} else {
		vec3 ax = normalize(vec3(fract(seed * 3.7) - 0.5, 0.35, fract(seed * 7.9) - 0.5));
		float spin = TIME * (2.0 + 3.0 * fract(seed * 11.3)) + seed * 40.0;
		mat3 r = rot_axis(ax, spin);
		// battement : la feuille oscille comme une feuille morte (falling leaf)
		r = rot_axis(vec3(0.0, 0.0, 1.0), sin(TIME * 3.1 + seed * 20.0) * 0.8) * r;
		v = r * v;
		NORMAL = r * NORMAL;
	}
	// les feuilles qui frolent la camera retrecissent (pas de grosse etoile plein ecran)
	vec3 wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float cd = length(wpos - CAMERA_POSITION_WORLD);
	v *= smoothstep(0.5, 2.2, cd);
	VERTEX = v;
	float h = fract(seed * 17.31);
	v_col = h < 0.3 ? col_a.rgb : (h < 0.6 ? col_b.rgb : (h < 0.85 ? col_c.rgb : col_d.rgb));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float ang = atan(p.x, p.y);
	float r = length(p);
	// 5 lobes pointus + petite tige
	// lobes pointus (onde triangulaire), les deux lobes du bas plus petits
	float tri = 1.0 - abs(fract(ang * 5.0 / 6.2831853 + 0.5) * 2.0 - 1.0);
	float lobes = 0.42 + 0.55 * pow(tri, 1.6);
	lobes *= 1.0 - 0.4 * smoothstep(1.9, 3.14, abs(ang));
	float stem = step(abs(p.x), 0.05) * step(p.y, -0.4) * step(-0.95, p.y);
	if (r > lobes && stem < 0.5) {
		discard;
	}
	float vein = (1.0 - smoothstep(0.0, 0.05, (1.0 - tri) * r)) * step(r, 0.8);
	ALBEDO = v_col * (1.0 - vein * 0.18);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		ALBEDO *= 0.85;
	}
}
