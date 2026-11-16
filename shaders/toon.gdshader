shader_type spatial;
render_mode world_vertex_coords, specular_disabled;
// Toon / cel shading des modeles : 3 paliers doux (voir toon_light.gdshaderinc), ombres teintees, liseré de contre-jour,
// vent sur le feuillage, variation de teinte par arbre, papiers lumineux le soir.

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform bool use_vertex_color = false;   // la couleur de sommet REMPLACE l'albedo (terrain)
uniform bool use_vertex_tint = false;    // la couleur de sommet MULTIPLIE l'albedo (occlusion des modeles)
uniform float wind_sway = 0.0;           // 0 = rigide, 1 = feuillage
uniform float cloth_wave = 0.0;          // 1 = etoffe qui ondule au vent (banderoles ; UV = position sur l'etoffe)
uniform float cloth_width = 0.6;         // largeur de l'etoffe (m), pour la pente des plis
uniform float color_jitter = 0.0;        // variation de teinte d'un arbre a l'autre (0 a 1)
uniform vec4 glow_color : source_color = vec4(1.0, 0.52, 0.20, 1.0);
instance uniform float glow = 0.0;       // papiers (shoji, lanternes) eclaires de l'interieur le soir

#include "res://shaders/toon_light.gdshaderinc"
#include "res://shaders/wind.gdshaderinc"

varying vec3 v_jit;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (wind_sway > 0.0) {
		VERTEX += wind_offset(VERTEX, origin, TIME) * wind_sway;
	}
	if (cloth_wave > 0.0) {
		VERTEX += cloth_offset(UV, origin, normalize(MODEL_MATRIX[0].xyz), normalize(MODEL_MATRIX[2].xyz),
			cloth_width, TIME, NORMAL) * cloth_wave;
	}
	if (color_jitter > 0.0) {
		vec2 k = floor(origin.xz * 2.0);
		float a = wind_hash(k);
		float b = wind_hash(k + 17.3);
		// luminosite +-9 %, glissement chaud/froid +-7 %
		v_jit = vec3(1.0) + color_jitter * vec3((a - 0.5) * 0.18 + (b - 0.5) * 0.14, (a - 0.5) * 0.18, (a - 0.5) * 0.18 - (b - 0.5) * 0.14);
	} else {
		v_jit = vec3(1.0);
	}
}

void fragment() {
	vec3 c = use_vertex_color ? COLOR.rgb : albedo.rgb;
	if (use_vertex_tint) {
		c *= COLOR.rgb;
	}
	c *= v_jit;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (glow > 0.0) {
		float paper = smoothstep(0.55, 0.7, toon_luma(albedo.rgb));
		EMISSION = glow_color.rgb * c * paper * glow;
	}
}
