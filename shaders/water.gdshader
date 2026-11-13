shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Eau stylisee (ruisseau, mare, etang, bassin d'ablution, seau) :
//  - couleur selon la profondeur reelle (texture de profondeur), transparence sur les bords ;
//  - liseré d'ecume au contact des berges, des pierres et des parois ;
//  - reflets en aplats (boucles de lumiere qui ondulent), reflet du ciel en incidence rasante ;
//  - scintillements du soleil (TOON_WATER dans toon_light.gdshaderinc) ;
//  - ruisseau : ecoulement le long de UV.y (metres), COLOR.r = raideur (ecume des petites chutes) ;
//    mares et bassin : coordonnees monde.
// Atmosphere regle sky_color / tint par phase.

#define TOON_WATER

uniform vec4 shallow_color : source_color = vec4(0.30, 0.58, 0.56, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.20, 0.29, 1.0);
uniform vec4 foam_color : source_color = vec4(0.94, 0.95, 0.90, 1.0);
uniform vec4 sky_color : source_color = vec4(0.78, 0.84, 0.88, 1.0);
uniform vec4 line_color : source_color = vec4(0.85, 0.95, 0.95, 1.0);
uniform float depth_scale = 0.32;     // metres d'eau pour atteindre la couleur profonde
uniform float foam_width = 0.06;
uniform float flow_speed = 0.55;      // m/s le long du ruisseau
uniform float ripple_scale = 1.0;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

#include "res://shaders/toon_light.gdshaderinc"

vec2 w_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float w_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = w_hash2(i).x;
	float b = w_hash2(i + vec2(1.0, 0.0)).x;
	float c = w_hash2(i + vec2(0.0, 1.0)).x;
	float d = w_hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// distance au bord de cellule de Voronoi (F2 - F1), cellules qui ondulent avec le temps
float w_cells(vec2 x, float t) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = w_hash2(n + g);
			o = 0.5 + 0.45 * sin(t + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return sqrt(f2) - sqrt(f1);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// ruisseau (UV.y en metres le long du courant) ou plan d'eau (coordonnees monde) ?
	// le ruban du ruisseau (terrain.gd) porte une couleur de sommet (raideur, 0, 0) ; les mares et le bassin non
	// (COLOR blanc ou gris) : test constant par sommet, sans les derivees d'ecran qui scintillaient
	float flowing = 1.0 - step(0.02, COLOR.g + COLOR.b);
	float t = TIME;
	vec2 p = mix(wp.xz, vec2(UV.x * 2.0, UV.y), flowing) * ripple_scale;
	vec2 adv = vec2(0.0, -t * flow_speed) * flowing;          // advection le long du courant
	vec2 pa = p + adv;

	// vaguelettes : somme de sinus (normale analytique)
	vec2 grad = vec2(0.0);
	vec2 dirs[4] = vec2[](vec2(0.8, 0.6), vec2(-0.5, 0.86), vec2(0.96, -0.28), vec2(-0.2, -0.98));
	float freqs[4] = float[](2.3, 3.1, 4.7, 6.3);
	float speeds[4] = float[](0.9, 1.1, 1.6, 2.0);
	float amps[4] = float[](0.06, 0.045, 0.03, 0.02);
	for (int i = 0; i < 4; i++) {
		vec2 dd = mix(dirs[i], normalize(dirs[i] * vec2(0.4, 1.0)), flowing);
		float ph = dot(pa, dd) * freqs[i] + t * speeds[i];
		grad += dd * cos(ph) * freqs[i] * amps[i];
	}
	vec2 nw = vec2(w_noise(pa * 1.7 + t * 0.15), w_noise(pa * 1.7 - t * 0.13 + 7.1)) - 0.5;
	grad += nw * 0.18;
	grad *= mix(1.0, 0.55, flowing);
	vec3 n_world = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// profondeur d'eau (le long du rayon de vue, ramenee a la verticale)
	float d_raw = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d_raw, 1.0);
	float scene_dist = -sv.z / sv.w;
	float surf_dist = -VERTEX.z;
	vec3 vdir = normalize(-VERTEX);
	vec3 vup = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float cos_v = clamp(abs(dot(vdir, vup)), 0.08, 1.0);
	float wdepth = max(scene_dist - surf_dist, 0.0) / max(abs(vdir.z), 0.05) * cos_v;
	float deep = 1.0 - exp(-wdepth / depth_scale);

	vec3 col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 1.0, deep));

	// reflets en aplats : courbes de niveau d'un champ de bruit qui se deforme lentement -> boucles et virgules
	// de lumiere (style « eau peinte »), etirees dans le courant, interrompues par un second bruit
	vec2 cp = (p + adv * 1.2) * vec2(mix(1.0, 1.6, flowing), mix(1.0, 0.45, flowing)) * mix(1.3, 0.7, flowing);
	vec2 warp = vec2(w_noise(cp * 0.7 + t * 0.11), w_noise(cp * 0.7 - t * 0.09 + 3.7)) - 0.5;
	float fld = w_noise(cp + warp * 1.6 + vec2(0.0, t * 0.06)) * 0.65 + w_noise(cp * 2.1 - warp + t * 0.05) * 0.35;
	float band = abs(fld - 0.58);
	float lw = fwidth(fld) * 1.2 + 0.012;
	float lines = 1.0 - smoothstep(lw * 0.5, lw, band);
	float brk = w_noise(cp * 0.6 + vec2(t * 0.1, -t * 0.07));
	lines *= smoothstep(0.4, 0.55, brk);
	// petites taches de lumiere plus larges
	float blob = smoothstep(0.74, 0.76 + fwidth(fld), fld) * 0.6;
	lines = max(lines, blob * smoothstep(0.5, 0.65, 1.0 - brk));
	float far_fade = 1.0 - smoothstep(12.0, 45.0, surf_dist);
	col = mix(col, line_color.rgb, lines * mix(0.38, 0.22, flowing) * far_fade);

	// reflet du ciel en incidence rasante
	// normale adoucie pour le reflet : sinon, en vue rasante, les vaguelettes donnent des hachures
	vec3 n_soft = normalize(mix(vup, NORMAL, 0.25));
	float fres = pow(1.0 - clamp(dot(n_soft, vdir), 0.0, 1.0), 4.0);
	col = mix(col, sky_color.rgb, clamp(fres * 0.8 + 0.04, 0.0, 0.75));

	// ecume au contact : liseré net mais irregulier, et un second anneau plus fin qui respire
	float fn = w_noise(wp.xz * 6.0 + t * 0.3 + adv * 2.0);
	float fw = foam_width * (0.65 + 0.7 * fn);
	float foam = 1.0 - smoothstep(fw * 0.75, fw, wdepth);
	float ring = fw * (1.9 + 0.35 * sin(t * 1.3 + fn * 4.0));
	foam = max(foam, (1.0 - smoothstep(0.012, 0.03, abs(wdepth - ring))) * 0.55 * step(0.42, fn));
	if (flowing > 0.5) {
		// petites traînees d'ecume dans le courant
		float st = w_noise(vec2(UV.x * 7.0, (UV.y - t * flow_speed * 1.15) * 1.2));
		foam = max(foam, smoothstep(0.84, 0.88, st) * 0.55);
		// petites chutes (COLOR.r = raideur, fourni par terrain.gd) : eau blanche brassee
		float steep = clamp(COLOR.r, 0.0, 1.0);
		float churn = w_noise(vec2(UV.x * 5.0, (UV.y - t * flow_speed * 2.2) * 1.4)) * 0.65
			+ w_noise(vec2(UV.x * 9.0 + 3.0, (UV.y - t * flow_speed * 2.8) * 2.2)) * 0.35;
		float thr = 0.72 - steep * 0.3;
		foam = max(foam, smoothstep(thr, thr + 0.04, churn) * smoothstep(0.35, 0.8, steep));
	}
	col = mix(col, foam_color.rgb, foam);

	ALBEDO = col;
	ROUGHNESS = mix(0.3, 0.7, flowing);   // lu par light() : moins de scintillements sur le ruisseau
	SPECULAR = 0.5;
	ALPHA = clamp(mix(mix(0.55, 0.74, flowing), 0.96, deep) + foam + fres * 0.3, 0.0, 1.0);
}
