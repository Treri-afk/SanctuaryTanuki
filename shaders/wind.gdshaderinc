// Vent partage (feuillage, contours du feuillage, herbe si besoin).
//   global uniform float wind_strength;  (1.0 = brise normale, anime par Atmosphere)
//   global uniform vec2 wind_direction;  (plan XZ)
// wind_offset(position monde du sommet, origine monde de l'objet, temps) -> deplacement monde.
// L'amplitude croit avec la hauteur au-dessus de l'origine de l'objet (pied de l'arbre) : la base ne bouge pas.

global uniform float wind_strength;
global uniform vec2 wind_direction;

float wind_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 wind_offset(vec3 wp, vec3 origin, float t) {
	vec2 dir = wind_direction;
	float dl = length(dir);
	dir = dl > 0.001 ? dir / dl : vec2(1.0, 0.0);
	float ws = clamp(wind_strength, 0.0, 2.4);
	float h = max(wp.y - origin.y, 0.0);
	float ph = wind_hash(floor(origin.xz * 3.0)) * 6.2831;
	// rafales qui traversent la foret dans le sens du vent (fronts espaces de ~45 m, 7 m/s)
	float front = dot(origin.xz, dir) - t * 7.0;
	float gust = sin(front * 0.14) * 0.5 + 0.5;
	gust = gust * gust * (0.6 + 0.4 * sin(front * 0.037 + 1.3));
	// balancement lent des masses (le haut de l'arbre decrit une petite ellipse)
	float sway = sin(t * (0.75 + 0.2 * fract(ph)) + ph) * 0.65 + sin(t * 1.63 + ph * 1.7) * 0.25;
	float side = sin(t * 0.61 + ph * 2.3) * 0.35;
	float amp = pow(h, 1.3) * 0.0042;   // 15 m : 0,14 ; 6 m : 0,04 (les troncs restent caches)
	vec2 lean = dir * ws * (0.5 + gust * 0.7);   // inclinaison moyenne sous le vent + rafales
	vec2 bend = (dir * sway + vec2(-dir.y, dir.x) * side) * (0.45 + 0.55 * ws);
	vec3 off = vec3((bend + lean) * amp, 0.0);
	off.y = -length(off.xz) * 0.25 * min(h, 4.0) / max(h, 0.5);   // la cime s'abaisse un peu en pliant
	// fremissement fin des feuilles (par sommet), plus fort pendant les rafales
	float fl = clamp(h, 0.0, 1.2) * (0.012 + 0.018 * gust) * ws;
	vec3 q = wp * vec3(2.3, 2.9, 2.1);
	off += vec3(sin(t * 6.3 + q.x + q.y), sin(t * 7.9 + q.y + q.z) * 0.6, sin(t * 5.7 + q.z + q.x)) * fl;
	return off;
}

// Etoffe au vent (banderoles nobori). uv : position sur l'etoffe (u = 0 a la hampe -> 1 au bord libre,
// v = 0 en haut -> 1 en bas). ax_x : direction monde de la hampe vers le bord libre ; ax_n : normale de l'etoffe.
// Des vagues partent de la hampe et filent vers le bord libre ; le tissu est tenu a la hampe et par la traverse du
// haut, il bouge surtout au bord libre et vers le bas. Renvoie le deplacement ; n recoit la normale inclinee.
vec3 cloth_offset(vec2 uv, vec3 origin, vec3 ax_x, vec3 ax_n, float width, float t, inout vec3 n) {
	float ws = clamp(wind_strength, 0.0, 2.4);
	float ph = wind_hash(floor(origin.xz * 3.0)) * 6.2831;
	float u = clamp(uv.x, 0.0, 1.0);
	float v = clamp(uv.y, 0.0, 1.0);
	float top = smoothstep(0.0, 0.12, v);                           // bord du haut cousu sur la traverse
	float w = pow(u, 1.15) * (0.3 + 0.7 * v) * top;
	float amp = 0.07 + 0.07 * ws;
	float sp = 3.2 + 1.2 * ws;
	float a1 = 5.5 * u + 2.2 * v - sp * t + ph;
	float a2 = 10.0 * u - 1.6 * v - sp * 1.55 * t + ph * 1.9;
	float a3 = 2.0 * v - t * 0.9 + ph * 0.7;                       // lente respiration de toute l'etoffe
	float s = sin(a1) * 0.7 + sin(a2) * 0.2 + sin(a3) * 0.5;
	float ds = cos(a1) * 5.5 * 0.7 + cos(a2) * 10.0 * 0.2;
	float dw = 1.15 * pow(max(u, 1e-3), 0.15) * (0.3 + 0.7 * v) * top;
	float slope = amp * (w * ds + dw * s) / width;                   // pente selon la largeur (par metre)
	float sg = dot(n, ax_n) >= 0.0 ? 1.0 : -1.0;
	n = normalize(n - ax_x * slope * sg);
	// le bord libre se rapproche un peu de la hampe quand le tissu ondule (il ne s'etire pas)
	return ax_n * (amp * w * s) - ax_x * (amp * w * abs(s) * 0.25);
}
