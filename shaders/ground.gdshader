shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Sol peint par aplats : matieres procedurales en coordonnees monde (aucune texture importee).
// Sommets : CUSTOM0.x = distance au sentier (m), CUSTOM0.y = hauteur au-dessus de l'eau voisine (m, 99 = pas d'eau).
// forest_mask (pose par forest.gd, 1 texel = 1 m) : R = litiere d'erables, G = aiguilles, B = mousse, A = herbe.
// Le reste (enceinte, allees de dalles, jardin sec) est recalcule ici a partir de la position.

#include "res://shaders/toon_light.gdshaderinc"

uniform sampler2D forest_mask : hint_default_black, filter_linear, repeat_disable;
uniform bool has_mask = false;
uniform vec4 mask_rect = vec4(-128.0, -128.0, 256.0, 256.0);

// sous-bois
uniform vec4 c_soil : source_color = vec4(0.42, 0.31, 0.20, 1.0);
uniform vec4 c_soil_dark : source_color = vec4(0.38, 0.28, 0.18, 1.0);
uniform vec4 c_needles : source_color = vec4(0.55, 0.35, 0.20, 1.0);
uniform vec4 c_leaf_red : source_color = vec4(0.77, 0.31, 0.16, 1.0);
uniform vec4 c_leaf_orange : source_color = vec4(0.85, 0.54, 0.18, 1.0);
uniform vec4 c_leaf_yellow : source_color = vec4(0.89, 0.69, 0.26, 1.0);
uniform vec4 c_leaf_brown : source_color = vec4(0.56, 0.27, 0.15, 1.0);
uniform vec4 c_moss : source_color = vec4(0.36, 0.46, 0.19, 1.0);
uniform vec4 c_moss_light : source_color = vec4(0.45, 0.52, 0.24, 1.0);
uniform vec4 c_grass : source_color = vec4(0.38, 0.44, 0.20, 1.0);
uniform vec4 c_grass_dry : source_color = vec4(0.58, 0.53, 0.29, 1.0);
uniform vec4 c_rock : source_color = vec4(0.54, 0.52, 0.47, 1.0);
uniform vec4 c_rock_dark : source_color = vec4(0.42, 0.40, 0.36, 1.0);
uniform vec4 c_lichen : source_color = vec4(0.64, 0.66, 0.45, 1.0);
// enceinte
uniform vec4 c_gravel : source_color = vec4(0.76, 0.71, 0.59, 1.0);
uniform vec4 c_gravel_dark : source_color = vec4(0.67, 0.62, 0.51, 1.0);
uniform vec4 c_gravel_light : source_color = vec4(0.85, 0.81, 0.71, 1.0);
uniform vec4 c_gravel_peb : source_color = vec4(0.55, 0.51, 0.42, 1.0);
uniform vec4 c_trodden : source_color = vec4(0.60, 0.52, 0.40, 1.0);
uniform vec4 c_zen : source_color = vec4(0.84, 0.81, 0.74, 1.0);
uniform vec4 c_zen_groove : source_color = vec4(0.66, 0.63, 0.56, 1.0);
uniform vec4 c_kerb : source_color = vec4(0.45, 0.43, 0.40, 1.0);
// sentiers
uniform vec4 c_trail : source_color = vec4(0.61, 0.49, 0.33, 1.0);
uniform vec4 c_trail_light : source_color = vec4(0.70, 0.59, 0.44, 1.0);
uniform vec4 c_trail_edge : source_color = vec4(0.37, 0.27, 0.19, 1.0);
uniform vec4 c_stone : source_color = vec4(0.58, 0.56, 0.51, 1.0);
// bords de l'eau
uniform vec4 c_mud : source_color = vec4(0.35, 0.28, 0.20, 1.0);
uniform vec4 c_mud_wet : source_color = vec4(0.24, 0.20, 0.16, 1.0);
uniform vec4 c_silt : source_color = vec4(0.31, 0.32, 0.22, 1.0);
uniform vec4 c_pebble : source_color = vec4(0.53, 0.51, 0.47, 1.0);
uniform vec4 c_pebble_dark : source_color = vec4(0.42, 0.40, 0.37, 1.0);

varying vec3 g_wpos;
varying vec2 g_attr;

// allees de dalles (tools/build_world.gd) : ax, az, bx, bz
const vec4 SLABS[9] = vec4[](
	vec4(-1.8, 3.0, -7.2, 3.0), vec4(1.8, 3.0, 7.2, 3.0), vec4(1.8, -4.0, 13.2, -4.0),
	vec4(-1.8, -1.0, -14.2, -1.0), vec4(-1.8, -10.0, -9.0, -10.0), vec4(1.8, -14.0, 8.5, -14.0),
	vec4(-1.8, -18.5, -14.0, -18.5), vec4(-12.6, -18.5, -12.6, -21.0), vec4(1.8, -19.0, 12.5, -24.0));
// murets de l'enceinte, portes exclues
const vec4 WALLS[8] = vec4[](
	vec4(-24.2, 9.2, -2.2, 9.2), vec4(3.8, 9.2, 24.2, 9.2),
	vec4(-24.2, -35.2, -24.2, 0.8), vec4(-24.2, 2.8, -24.2, 9.2),
	vec4(24.2, -35.2, 24.2, -9.2), vec4(24.2, -7.2, 24.2, 9.2),
	vec4(-24.2, -35.2, -0.2, -35.2), vec4(1.8, -35.2, 24.2, -35.2));
// rochers du jardin sec : x, z, rayon
const vec3 ZEN_ROCKS[4] = vec3[](
	vec3(-18.2, -12.0, 0.42), vec3(-14.2, -9.4, 0.62), vec3(-16.5, -8.4, 0.95), vec3(-12.8, -13.0, 0.3));
// chemins tasses vers les portes de l'enceinte
const vec4 GATES[3] = vec4[](vec4(0.8, -29.5, 0.8, -38.0), vec4(-19.5, 1.8, -26.5, 1.8), vec4(19.5, -8.2, 26.5, -8.2));
const vec4 ZEN_BOX = vec4(-16.0, -11.0, 6.5, 5.0);

float g_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 g_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float g_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(g_hash(i), g_hash(i + vec2(1.0, 0.0)), u.x),
		mix(g_hash(i + vec2(0.0, 1.0)), g_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float g_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * g_vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s / 0.875;
}

// x = distance au centre de cellule le plus proche, y = hasard de la cellule, z = distance au bord (approx.)
vec3 g_voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	float md2 = 8.0;
	vec2 mid = n;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.15 + 0.7 * g_hash2(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md2 = md;
				md = d;
				mid = n + g;
			} else if (d < md2) {
				md2 = d;
			}
		}
	}
	return vec3(sqrt(md), g_hash(mid * 1.37 + 0.71), sqrt(md2) - sqrt(md));
}

// marche antialiasee : 0 sous e, 1 au-dessus
float g_step(float e, float x) {
	float w = max(fwidth(x), 0.0005);
	return smoothstep(e - w, e + w, x);
}

float g_seg(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - a - ab * t);
}

float g_box(vec2 p, vec2 c, vec2 h) {
	vec2 q = abs(p - c) - h;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

vec3 leaf_color(float h) {
	if (h < 0.3) return c_leaf_red.rgb;
	if (h < 0.6) return c_leaf_orange.rgb;
	if (h < 0.7) return c_leaf_yellow.rgb;
	return c_leaf_brown.rgb;
}

// feuilles mortes : ellipses et feuilles d'erable a 5 lobes, orientees au hasard ; rgb = couleur, a = couverture
vec4 g_leaves(vec2 p, float cover, float aa) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec4 res = vec4(0.0);
	float best = 2.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = n + vec2(float(i), float(j));
			float h = g_hash(id * 1.37 + 0.71);
			if (h > cover) {
				continue;
			}
			vec2 r = vec2(float(i), float(j)) + 0.15 + 0.7 * g_hash2(id) - f;
			float a = h * 40.0;
			float ca = cos(a);
			float sa = sin(a);
			vec2 rr = vec2(ca * r.x + sa * r.y, -sa * r.x + ca * r.y);
			float size = 0.26 + 0.16 * fract(h * 17.3);
			float maple = step(0.5, fract(h * 9.7));
			float d = length(rr * mix(vec2(1.0, 2.1), vec2(1.0, 1.0), maple)) / size;
			float th = atan(rr.y, rr.x);
			d *= 1.0 + maple * (0.13 * cos(5.0 * th + 1.57) + 0.06 * cos(10.0 * th));
			float m = 1.0 - smoothstep(1.0 - aa / size, 1.0, d);
			if (m > 0.0 && h < best) {
				best = h;
				res = vec4(leaf_color(fract(h * 13.7)) * (0.88 + 0.22 * fract(h * 5.1)), m);
			}
		}
	}
	return res;
}


// gravier clair : grandes taches, galets clairs et sombres, grain
vec3 gravel(vec2 p, float n_big, float n_mid, float fine, float mid) {
	vec3 gcol = mix(c_gravel.rgb, c_gravel_dark.rgb, g_step(0.6, n_big + (n_mid - 0.5) * 0.35) * 0.75);
	vec3 pv = g_voronoi(p * 23.0);
	float peb = (1.0 - g_step(0.26 + 0.14 * fract(pv.y * 5.3), pv.x)) * fine;
	float hp = fract(pv.y * 31.7);
	gcol = mix(gcol, c_gravel_light.rgb * 1.02, peb * step(0.84, hp) * 0.8);
	gcol = mix(gcol, mix(gcol, c_gravel_peb.rgb, 0.55), peb * step(hp, 0.14));
	gcol *= 1.0 + (fract(pv.y * 7.1) - 0.5) * 0.05 * fine;
	vec3 sv2 = g_voronoi(p * 4.5 + 3.3);
	float big = (1.0 - g_step(0.13 + 0.06 * fract(sv2.y * 3.1), sv2.x)) * step(0.93, sv2.y) * mid;
	return mix(gcol, mix(c_gravel_light.rgb * 1.04, mix(c_gravel_peb.rgb, c_gravel.rgb, 0.5), step(0.975, sv2.y)), big * 0.9);
}

void vertex() {
	g_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	g_attr = CUSTOM0.xy;
}

void fragment() {
	vec3 wp = g_wpos;
	vec2 p = wp.xz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float foot = length(fwidth(p));                      // metres par pixel
	float fine = 1.0 - smoothstep(0.006, 0.022, foot);   // grain de 4 cm
	float mid = 1.0 - smoothstep(0.030, 0.110, foot);    // touches de 15 cm
	float coarse = 1.0 - smoothstep(0.08, 0.30, foot);   // pierres de 30 cm
	float trail_d = g_attr.x;
	float water_h = g_attr.y;
	vec4 mk = vec4(0.0);
	if (has_mask) {
		mk = texture(forest_mask, (p - mask_rect.xy) / mask_rect.zw);
	}
	float n_big = g_fbm(p * 0.28);
	float n_mid = g_fbm(p * 1.1 + 7.3);
	float n_sm = g_vnoise(p * 4.3 + 2.1);

	// ---------------------------------------------------------------- sous-bois
	vec3 col = mix(c_soil.rgb, c_soil_dark.rgb, g_step(0.56, n_big + 0.25 * (n_mid - 0.5)));
	col = mix(col, c_needles.rgb, g_step(0.42, mk.g * 0.85 + (n_mid - 0.5) * 0.55 + 0.12));
	// mousse en plaques (pied des arbres et des rochers, creux ombrages)
	float moss = g_step(0.55, mk.b * 1.1 + (n_mid - 0.5) * 0.7 + smoothstep(0.62, 0.8, n_big) * 0.35);
	vec3 moss_col = mix(c_moss.rgb, c_moss_light.rgb, g_step(0.6, n_sm + (n_mid - 0.5) * 0.4));
	col = mix(col, moss_col, moss);
	// herbe rase
	float grass = g_step(0.5, mk.a + (n_mid - 0.5) * 0.35 + (n_sm - 0.5) * 0.12);
	vec3 grass_col = mix(c_grass.rgb, c_grass_dry.rgb, g_step(0.62, n_big + (n_sm - 0.5) * 0.3) * 0.55);
	col = mix(col, grass_col * 0.94, grass);
	float leaf_cover = clamp(0.16 + mk.r * 0.85 - grass * 0.12 - moss * 0.08, 0.0, 0.92);

	// roche sur les pentes raides
	float rock = g_step(0.5, (0.83 - wn.y) * 9.0 + (n_mid - 0.5) * 1.8);
	if (rock > 0.0) {
		vec2 rp = vec2(p.x + p.y * 0.37, wp.y * 2.0 + p.y * 0.2);
		// grandes faces claires et sombres, strates horizontales, fissures
		float facet = g_fbm(rp * 0.7 + 4.0);
		vec3 rc = mix(c_rock.rgb, c_rock_dark.rgb, g_step(0.52, facet));
		rc = mix(rc, c_rock.rgb * 1.1, (1.0 - g_step(0.32, facet)) * 0.8);
		float sl = fract(wp.y * 1.3 + n_mid * 1.4 + g_vnoise(p * 0.5) * 0.6);
		float strata = (1.0 - g_step(0.05, sl)) * g_step(0.35, g_vnoise(p * 1.7 + wp.y));
		rc = mix(rc, c_rock_dark.rgb * 0.7, strata * mid * 0.85);
		rc = mix(rc, c_lichen.rgb, g_step(0.68, g_fbm(p * 2.5 + wp.y)) * 0.7);
		col = mix(col, rc, rock);
		leaf_cover *= 1.0 - rock;
	}

	// ---------------------------------------------------------------- plateau du sanctuaire
	float in_walls = g_box(p, vec2(0.0, -13.0), vec2(24.2, 22.2));   // < 0 dans l'enceinte
	bool plateau = abs(p.x) <= 26.05 && p.y >= -38.05 && p.y <= 13.0;
	if (plateau && in_walls > -0.05) {
		// pourtour exterieur des murets : herbe et mousse, parvis de gravier devant le torii
		float fore = 1.0 - g_step(0.0, g_box(p, vec2(0.6, 11.2), vec2(4.6, 2.3)) + (n_sm - 0.5) * 0.5);
		col = mix(mix(grass_col * 0.94, moss_col, g_step(0.6, n_mid) * 0.8), mix(c_gravel.rgb, c_trodden.rgb, 0.5), fore);
		leaf_cover = 0.12 + mk.r * 0.6;
	}
	if (in_walls < 0.0) {
		vec3 gcol = gravel(p, n_big, n_mid, fine, mid);
		float espl = g_box(p, vec2(0.0, -11.5), vec2(9.5, 9.0));
		gcol = mix(gcol, gcol * 1.06, (1.0 - g_step(0.0, espl + (n_mid - 0.5) * 1.2)));
		// passages tasses le long des allees de dalles
		float ds = abs(p.x) - 0.55;
		ds = (p.y < 12.9 && p.y > -17.3) ? ds : 1e3;
		for (int i = 0; i < 9; i++) {
			ds = min(ds, g_seg(p, SLABS[i].xy, SLABS[i].zw));
		}
		for (int i = 0; i < 3; i++) {
			ds = min(ds, g_seg(p, GATES[i].xy, GATES[i].zw) + 0.1);
		}
		float worn = 1.0 - g_step(0.0, ds - 0.78 - (n_sm - 0.5) * 0.3 - (n_mid - 0.5) * 0.25);
		gcol = mix(gcol, mix(c_trodden.rgb, c_gravel_dark.rgb, g_step(0.5, n_sm) * 0.35), worn * 0.9);
		// jardin sec : gravier ratisse (traits droits, cercles autour des rochers), bordure de pierres
		float zb = g_box(p, ZEN_BOX.xy, ZEN_BOX.zw);
		if (zb < 0.05) {
			float rd = 1e3;
			for (int i = 0; i < 4; i++) {
				rd = min(rd, length(p - ZEN_ROCKS[i].xy) - ZEN_ROCKS[i].z);
			}
			float ring = 1.0 - g_step(1.2, rd);
			float u = mix((p.y - ZEN_BOX.y) / 0.17, max(rd, 0.0) / 0.17, ring);
			float gr = abs(fract(u) - 0.5) * 2.0;
			float keep = g_step(0.4, g_fbm(p * 0.9 + 3.0)) * mid;
			vec3 zc = mix(c_zen.rgb, c_zen_groove.rgb, (1.0 - g_step(0.32, gr)) * keep * 0.75);
			vec3 kv = g_voronoi(p * 3.4);
			vec3 kc = mix(c_kerb.rgb, c_kerb.rgb * 1.25, step(0.5, kv.y));
			kc = mix(kc, c_kerb.rgb * 0.55, (1.0 - g_step(0.05, kv.z)) * coarse);
			zc = mix(zc, kc, g_step(-0.2, zb));
			gcol = mix(zc, gcol, g_step(0.0, zb));
		}
		// bande de mousse et d'herbe au pied des murets
		float dw = 1e3;
		for (int i = 0; i < 8; i++) {
			dw = min(dw, g_seg(p, WALLS[i].xy, WALLS[i].zw));
		}
		float band = (1.0 - g_step(1.12 + (n_mid - 0.5) * 0.9 + (n_sm - 0.5) * 0.2, dw)) * (1.0 - worn);
		vec3 bcol = mix(moss_col, grass_col * 0.94, g_step(0.5, n_sm + (n_mid - 0.5) * 0.5));
		gcol = mix(gcol, bcol, band);
		// anneaux de mousse et d'herbe autour des arbres de la cour (masque)
		float moss_in = g_step(0.55, mk.b * 1.1 + (n_mid - 0.5) * 0.5);
		gcol = mix(gcol, moss_col, moss_in * (1.0 - band));
		gcol = mix(gcol, grass_col * 0.94, grass * (1.0 - band));
		col = gcol;
		leaf_cover = clamp(mk.r * 0.75 + band * 0.1, 0.0, 0.8);
	}

	// ---------------------------------------------------------------- feuilles mortes (touches de couleur)
	if (leaf_cover > 0.01) {
		float drift = smoothstep(0.25, 0.75, g_fbm(p * 0.55 + 21.0));
		float lcov = leaf_cover * mix(0.35, 1.5, drift);
		vec4 lf = g_leaves(p * 8.0 + vec2(3.1, 1.7), lcov, foot * 8.0 * 1.5);
		vec3 near_c = mix(col, mix(lf.rgb, col, 0.18), lf.a);
		vec3 far_c = mix(col, mix(c_leaf_orange.rgb, c_leaf_red.rgb, 0.4), lcov * 0.4);
		col = mix(far_c, near_c, mid);
	}

	// ---------------------------------------------------------------- sentiers de terre battue
	if (trail_d < 3.0) {
		float td = trail_d + (n_mid - 0.5) * 0.75 + (n_sm - 0.5) * 0.18;
		float tw = 1.12;
		vec3 tcol = mix(c_trail.rgb, c_trail_light.rgb, (1.0 - g_step(0.5, trail_d + (n_mid - 0.5) * 0.5)) * 0.7);
		tcol = mix(tcol, c_trail.rgb * 0.88, g_step(0.62, n_big) * 0.6);
		// trace plus sombre et tassee au milieu, la ou l'on marche
		tcol = mix(tcol, c_trail.rgb * 0.9, (1.0 - g_step(0.28, abs(trail_d - 0.15 + (n_mid - 0.5) * 0.5))) * 0.35);
		float edge = (1.0 - g_step(tw + 0.09, td)) * g_step(tw, td);
		col = mix(col, c_trail_edge.rgb, edge * 0.45);
		col = mix(col, tcol, 1.0 - g_step(tw, td));
	}

	// ---------------------------------------------------------------- bords de l'eau
	if (water_h < 0.75) {
		float wh = water_h + (n_sm - 0.5) * 0.05 + (n_mid - 0.5) * 0.06;
		// galets jointifs (mosaique) separes par de la vase
		// galets ronds de tailles variees, poses sur la vase
		vec3 wv = g_voronoi(p * 5.5 + 5.0);
		float rad = 0.28 + 0.2 * fract(wv.y * 5.7);
		float peb = (1.0 - g_step(rad, wv.x)) * step(wv.y, mix(0.42, 0.8, 1.0 - g_step(0.1, wh)));
		vec3 stone = mix(c_pebble.rgb, c_pebble_dark.rgb, step(0.5, fract(wv.y * 7.3)));
		stone *= 0.9 + 0.2 * fract(wv.y * 3.3);
		stone = mix(stone, mix(c_pebble.rgb, c_moss.rgb, 0.45), step(0.86, fract(wv.y * 11.1)));
		stone = mix(stone * 1.08, stone, g_step(rad * 0.55, length(vec2(wv.x, 0.0))));   // reflet au centre
		vec3 wv2 = g_voronoi(p * 13.0 + 1.3);
		float peb2 = (1.0 - g_step(0.3, wv2.x)) * step(wv2.y, 0.22) * fine;
		vec3 cob = mix(c_mud.rgb, mix(c_pebble.rgb, c_pebble_dark.rgb, step(0.5, fract(wv2.y * 9.1))) * 0.95, peb2);
		cob = mix(cob, c_mud_wet.rgb, (1.0 - g_step(rad + 0.06, wv.x)) * step(wv.y, 0.8) * mid * 0.6);
		cob = mix(cob, stone, peb);
		// mousse et herbe rase sur la berge de l'etang de l'enceinte
		if (in_walls < 0.0) {
			float bank = 1.0 - g_step(0.62 + (n_mid - 0.5) * 0.3, wh);
			col = mix(col, moss_col, bank);
		}
		float beach = 1.0 - g_step(0.24 + (n_mid - 0.5) * 0.16, wh);
		col = mix(col, cob, beach);
		col = mix(col, c_mud_wet.rgb, (1.0 - g_step(0.05, wh)) * 0.75);
		float under = 1.0 - g_step(0.0, wh);
		// sous l'eau : vase sombre, galets assourdis, le fond fonce avec la profondeur (l'eau se lit mieux)
		vec3 bed = mix(c_silt.rgb, mix(cob, c_silt.rgb, 0.35), step(wv.y, 0.55));
		bed *= mix(0.85, 0.6, clamp(-wh / 0.4, 0.0, 1.0));
		col = mix(col, bed, under);
	}

	// palier du bas de l'escalier : gravier tasse
	if (p.y > 25.5 && p.y < 39.0 && abs(p.x) < 9.5) {
		float lb = g_box(p, vec2(0.0, 32.0), vec2(7.5, 5.5)) + (n_mid - 0.5) * 1.2;
		vec3 lg = mix(gravel(p, n_big, n_mid, fine, mid), c_trodden.rgb, 0.35);
		col = mix(lg, col, g_step(0.0, lb));
	}

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
