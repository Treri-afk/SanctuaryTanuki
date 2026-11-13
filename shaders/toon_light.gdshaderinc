// Eclairage toon partage par tous les shaders du jeu (modeles, sol, herbe, eau) :
//   #include "res://shaders/toon_light.gdshaderinc"
// Definit les uniforms d'ombrage et la fonction light(). Un shader qui l'inclut ne doit pas redefinir light().
//
// Modele : demi-lambert decoupe en 3 paliers doux (ombre propre, mi-ton chaud, lumiere pleine avec un leger degrade
// interne), ombres portees filtrees separement (bord net mais anti-crenele), petit remplissage teinte dans l'ombre.
// L'ombre elle-meme est surtout donnee par la lumiere ambiante de l'Environment (bleu-violet, reglee par Atmosphere).
// Options (0 par defaut, le sol et l'herbe n'en ont pas besoin) : rim_strength (liseré de contre-jour),
// translucency (feuillage traverse par le soleil).
// Un shader peut definir TOON_WATER avant l'include pour obtenir les reflets scintillants du soleil.

uniform vec4 shadow_tint : source_color = vec4(0.40, 0.42, 0.78, 1.0);  // remplissage colore dans l'ombre propre
uniform vec4 mid_tint : source_color = vec4(1.0, 0.86, 0.74, 1.0);      // teinte du palier intermediaire (terminateur chaud)
uniform float threshold_shadow : hint_range(0.0, 1.0) = 0.40;          // seuils sur le demi-lambert (0.5 = rasant)
uniform float threshold_mid : hint_range(0.0, 1.0) = 0.515;
uniform float softness : hint_range(0.001, 0.2) = 0.03;
uniform float lit_strength = 0.85;
uniform float mid_level : hint_range(0.0, 1.0) = 0.52;
uniform float rim_strength = 0.0;
uniform float translucency = 0.0;

float toon_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float hl = ndl * 0.5 + 0.5;
	vec3 lc = LIGHT_COLOR / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		// ombre portee : le filtrage PCF donne une rampe, on la resserre sans la rendre crenelee
		float sh = smoothstep(0.18, 0.82, ATTENUATION);
		float b_mid = smoothstep(threshold_shadow - softness, threshold_shadow + softness, hl);
		float b_lit = smoothstep(threshold_mid - softness, threshold_mid + softness, hl);
		float grad = mix(0.84, 1.0, smoothstep(threshold_mid, 0.95, hl));
		vec3 tone = mid_tint.rgb * mid_level * b_mid;
		tone = mix(tone, vec3(grad), b_lit);
		tone *= sh;
		float dark = 1.0 - clamp(toon_luma(tone), 0.0, 1.0);
		vec3 d = tone * lc * lit_strength;
		// remplissage teinte : l'ombre reste coloree meme sous une lumiere chaude
		d += shadow_tint.rgb * 0.07 * toon_luma(lc) * dark;
		float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float back = clamp(-dot(VIEW, LIGHT), 0.0, 1.0);
		if (rim_strength > 0.0) {
			// liseré de contre-jour : fin, seulement face au soleil, coupe par les ombres portees
			float rim = smoothstep(0.66, 0.78, 1.0 - nv) * (0.25 + 0.75 * back) * smoothstep(-0.25, 0.2, ndl);
			d += lc * rim * rim_strength * sh;
		}
		if (translucency > 0.0) {
			// feuillage vu a contre-jour : le soleil traverse les feuilles du cote ombre
			float tr = pow(back, 3.0) * (1.0 - b_lit) * sh;
			d += lc * mid_tint.rgb * tr * translucency;
		}
		DIFFUSE_LIGHT += d;
#ifdef TOON_WATER
		// scintillements : reflet speculaire tres serre sur les normales des vaguelettes, quantifie en eclats
		vec3 h = normalize(LIGHT + VIEW);
		float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 220.0);
		float glit = clamp(1.4 - ROUGHNESS * 2.0, 0.0, 1.0);
		SPECULAR_LIGHT += LIGHT_COLOR * smoothstep(0.25, 0.6, s) * 1.6 * sh * glit;
		float broad = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 24.0);
		SPECULAR_LIGHT += LIGHT_COLOR * broad * 0.06 * sh;
#endif
	} else {
		// lumieres locales (lanternes) : flaques de lumiere a 2 paliers doux
		float i = clamp(ndl * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
		float q = smoothstep(0.08, 0.13, i) * 0.4 + smoothstep(0.22, 0.3, i) * 0.35 + smoothstep(0.45, 0.6, i) * 0.25;
		DIFFUSE_LIGHT += lc * (q * 1.1 + i * 0.5);
	}
}
