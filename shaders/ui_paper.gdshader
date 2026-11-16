shader_type canvas_item;
// Feuille de washi pour l'interface : grain et fibres, bords irreguliers (barbes du papier fait main), double filet
// d'encre a l'interieur, ombre portee douce. Le Control qui porte ce shader est plus grand que la feuille de
// `margin` px de chaque cote (place pour l'ombre et les barbes).

uniform vec2 size = vec2(900.0, 600.0);        // taille du Control en px
uniform float margin = 26.0;                    // de la bordure du Control au bord de la feuille
uniform vec4 paper : source_color = vec4(0.953, 0.922, 0.851, 1.0);
uniform vec4 paper_dark : source_color = vec4(0.88, 0.83, 0.73, 1.0);   // fibres, bord jauni
uniform vec4 ink : source_color = vec4(0.36, 0.25, 0.18, 1.0);
uniform vec4 shadow : source_color = vec4(0.05, 0.03, 0.02, 0.55);
uniform float deckle = 3.5;                     // amplitude des barbes (px)
uniform float border_inset = 16.0;              // filet d'encre : distance au bord (0 = pas de filet)
uniform float seed = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.137);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.07 + 13.1) * 0.3 + vnoise(p * 4.3 + 7.7) * 0.15;
}

// distance signee au rectangle de la feuille (negatif dedans)
float rect_d(vec2 px, vec2 lo, vec2 hi) {
	vec2 q = max(lo - px, px - hi);
	return max(q.x, q.y);
}

void fragment() {
	vec2 px = UV * size;
	vec2 lo = vec2(margin);
	vec2 hi = size - vec2(margin);
	// position le long du bord, pour des barbes qui varient sans couture
	float along = px.x + px.y * 1.37;
	float rag = (fbm(vec2(along * 0.09, 3.0)) - 0.5) * 2.0 * deckle + (vnoise(vec2(along * 0.6, 9.0)) - 0.5) * deckle * 0.6;
	float d = rect_d(px, lo, hi) - rag;
	float a_paper = 1.0 - smoothstep(-0.8, 0.8, d);

	// ombre : decalee vers le bas, floue
	float ds = rect_d(px - vec2(0.0, 9.0), lo + 4.0, hi - 4.0);
	float a_shadow = (1.0 - smoothstep(-6.0, 20.0, ds)) * shadow.a;

	// papier : grain fin, nuages de fibres, fibres allongees, bord legerement jauni
	float grain = vnoise(px * 0.9) * 0.5 + vnoise(px * 0.35) * 0.5;
	float cloud = fbm(px * 0.012);
	vec2 fp = vec2(px.x * 0.035 + px.y * 0.012, px.y * 0.22 - px.x * 0.05);
	float fiber = smoothstep(0.78, 0.92, vnoise(fp)) * 0.6;
	vec3 col = mix(paper.rgb, paper_dark.rgb, cloud * 0.35 + fiber * 0.45);
	col *= 0.97 + grain * 0.05;
	float edge = 1.0 - smoothstep(-26.0, -2.0, d);
	col = mix(col, paper_dark.rgb * 0.95, (1.0 - edge) * 0.35);
	// quelques paillettes de fibre plus sombres (washi)
	float speck = step(0.996, hash(floor(px * 0.5)));
	col = mix(col, paper_dark.rgb * 0.8, speck * 0.5);

	// double filet d'encre, trace au pinceau (epaisseur et intensite qui ondulent)
	if (border_inset > 0.0) {
		float db = rect_d(px, lo + border_inset, hi - border_inset);
		float wob = (vnoise(vec2(along * 0.05, 1.0)) - 0.5) * 1.2;
		float w1 = 1.3 + vnoise(vec2(along * 0.03, 5.0)) * 1.1;
		float l1 = 1.0 - smoothstep(w1 * 0.5, w1 * 0.5 + 0.9, abs(db + wob));
		float l2 = 1.0 - smoothstep(0.35, 1.1, abs(db + 5.0 + wob * 0.7));
		float dry = 0.55 + 0.45 * smoothstep(0.25, 0.6, vnoise(vec2(along * 0.11, 2.0)));
		col = mix(col, ink.rgb, l1 * 0.85 * dry + l2 * 0.45 * dry);
	}
	vec4 c_paper = vec4(col, a_paper);
	vec4 c_shadow = vec4(shadow.rgb, a_shadow);
	COLOR = mix(c_shadow, c_paper, a_paper);
	COLOR.a = max(a_paper, a_shadow * (1.0 - a_paper));
}
