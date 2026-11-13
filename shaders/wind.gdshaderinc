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
