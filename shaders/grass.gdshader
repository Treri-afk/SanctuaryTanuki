shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Touffes d'herbe et de susuki en MultiMesh (construites par forest.gd), sans contour.
// UV.y = hauteur relative sur la lame (0 au pied, 1 a la pointe) ; UV.x = hasard de la lame.
// COLOR.r = 1 pour les plumeaux de susuki. INSTANCE_CUSTOM : r = secheresse, g = phase, b = souplesse.
// La normale est celle du sol (vers le haut) : l'herbe recoit la lumiere comme le sol, le pied s'y fond.

#include "res://shaders/toon_light.gdshaderinc"

global uniform float wind_strength;
global uniform vec2 wind_direction;

uniform vec4 root_color : source_color = vec4(0.43, 0.50, 0.21, 1.0);
uniform vec4 tip_color : source_color = vec4(0.55, 0.58, 0.29, 1.0);
uniform vec4 dry_color : source_color = vec4(0.74, 0.62, 0.36, 1.0);
uniform vec4 rust_color : source_color = vec4(0.70, 0.38, 0.20, 1.0);
uniform vec4 plume_color : source_color = vec4(0.84, 0.77, 0.65, 1.0);
uniform float fade_start = 24.0;
uniform float fade_end = 38.0;
uniform float sway = 0.16;

varying float v_h;
varying float v_kind;
varying vec4 v_custom;
varying float v_rand;

void vertex() {
	mat3 m3 = mat3(MODEL_MATRIX);
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(root - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	v_h = UV.y;
	v_rand = UV.x;
	v_kind = COLOR.r;
	v_custom = INSTANCE_CUSTOM;
	// la touffe s'enfonce dans le sol au loin (le sol porte la meme couleur d'herbe)
	VERTEX.y *= fade;
	// vent : balancement le long de wind_direction, en vagues qui traversent le pre
	vec2 wd = wind_direction;
	float wl = length(wd);
	wd = wl > 0.001 ? wd / wl : vec2(1.0, 0.0);
	float ws = max(wind_strength, 0.0);
	float phase = dot(root.xz, wd) * 0.45 - TIME * (1.3 + 0.5 * ws) + INSTANCE_CUSTOM.g * 6.2832;
	// fronts de rafale qui traversent le pre (meme rythme que le feuillage : ~45 m, 7 m/s)
	float front = dot(root.xz, wd) - TIME * 7.0;
	float gust = sin(front * 0.14) * 0.5 + 0.5;
	gust *= gust;
	float wave = 0.45 + 0.3 * sin(phase) + 0.15 * sin(phase * 2.3 + 1.7) + gust * 0.9;
	float flutter = sin(TIME * 5.3 + INSTANCE_CUSTOM.g * 31.0 + UV.x * 12.0) * 0.25;
	float height_w = VERTEX.y;   // metres au-dessus du pied (deja tasses par le fondu)
	float bend = UV.y * UV.y * sway * (0.4 + INSTANCE_CUSTOM.b) * ws * (wave + flutter * 0.5) * max(height_w, 0.0) * 2.0;
	vec3 disp = vec3(wd.x, 0.0, wd.y) * bend + vec3(-wd.y, 0.0, wd.x) * flutter * bend * 0.35;
	disp.y = -abs(bend) * 0.25 * UV.y;
	// deplacement monde -> espace du modele (rotation + echelle de l'instance)
	vec3 ld = transpose(m3) * disp;
	ld /= vec3(dot(m3[0], m3[0]), dot(m3[1], m3[1]), dot(m3[2], m3[2]));
	VERTEX += ld;
	NORMAL = normalize(vec3(m3[0].y, m3[1].y, m3[2].y));
}

void fragment() {
	float dry = v_custom.r;
	vec3 tip = mix(tip_color.rgb, dry_color.rgb, smoothstep(0.25, 0.85, dry));
	tip = mix(tip, rust_color.rgb, step(0.9, fract(v_rand * 7.3 + dry * 3.1)) * 0.7);
	vec3 c = mix(root_color.rgb * 0.94, tip, smoothstep(0.08, 0.95, v_h));
	c *= 0.95 + 0.1 * fract(v_rand * 13.1);
	c = mix(c, plume_color.rgb * mix(0.92, 1.05, v_h), v_kind);
	ALBEDO = c;
	// marqueur pour les contours a l'ecran (screen_outline peut ignorer les pixels de rugosite ~0) : pas de contour sur l'herbe
	ROUGHNESS = 0.0;
	SPECULAR = 0.0;
}
