shader_type particles;
// Feuilles d'erable qui tombent : vitesse limite de chute, derive et tourbillons portes par le vent global,
// se posent sur le sol (collision par champ de hauteur), y restent un moment puis disparaissent ;
// une bourrasque (gust_boost) les fait repartir.
// CUSTOM : x = graine, y = age relatif (0..1), z = temps au sol, w = 1 si posee.

global uniform float wind_strength;
global uniform vec2 wind_direction;

uniform vec3 box_extents = vec3(14.0, 3.0, 14.0);
uniform float fall_speed = 0.8;
uniform float gust_boost = 0.0;
uniform float leaf_scale = 1.0;

float lf_hash(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void start() {
	uint s = NUMBER * 7u + RANDOM_SEED * 13u + INDEX * 101u;
	vec3 r = vec3(lf_hash(s), lf_hash(s + 1u), lf_hash(s + 2u)) * 2.0 - 1.0;
	if (RESTART_POSITION) {
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(r * box_extents, 1.0)).xyz;
	}
	if (RESTART_VELOCITY) {
		VELOCITY = vec3(0.0, -fall_speed * 0.5, 0.0);
	}
	if (RESTART_CUSTOM) {
		CUSTOM = vec4(lf_hash(s + 3u), 0.0, 0.0, 0.0);
	}
	float sc = (0.75 + 0.5 * lf_hash(s + 4u)) * leaf_scale;
	TRANSFORM[0].xyz = vec3(sc, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, sc, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, sc);
}

void process() {
	CUSTOM.y += DELTA / max(LIFETIME, 0.001);
	float seed = CUSTOM.x;
	vec3 p = TRANSFORM[3].xyz;
	vec2 wd = wind_direction;
	wd = length(wd) > 0.001 ? normalize(wd) : vec2(1.0, 0.0);
	float ws = max(wind_strength, 0.0);
	float sc = (0.75 + 0.5 * fract(seed * 7.13)) * leaf_scale;
	if (CUSTOM.w > 0.5) {
		// posee : immobile, sauf si une bourrasque la souleve
		VELOCITY = vec3(0.0);
		CUSTOM.z += DELTA;
		if (gust_boost > 0.2 && fract(seed * 13.7) < gust_boost * 0.6) {
			CUSTOM.w = 0.0;
			VELOCITY = vec3(wd.x, 0.0, wd.y) * 2.0 + vec3(0.0, 1.6 + fract(seed * 3.3) * 1.5, 0.0);
		}
	} else {
		float ph = seed * 6.2831;
		vec3 target = vec3(wd.x, 0.0, wd.y) * (0.35 + ws * 1.2);
		// tourbillons : champ de rotation lent dependant de la position
		target += vec3(sin(TIME * 1.3 + ph + p.y * 0.7), 0.0, cos(TIME * 1.1 + ph * 1.7 + p.x * 0.5)) * (0.3 + 0.35 * ws);
		target.y = -fall_speed * (0.8 + 0.35 * sin(TIME * 2.3 + ph * 3.0));
		target += vec3(wd.x, 0.0, wd.y) * gust_boost * 3.0 + vec3(0.0, gust_boost * 1.4 * fract(seed * 5.1), 0.0);
		VELOCITY = mix(VELOCITY, target, 1.0 - exp(-DELTA * 1.6));
		// une collision profonde = la feuille est sous un houppier (champ de hauteur) : on l'ignore
		if (COLLIDED && COLLISION_DEPTH < 0.3 && COLLISION_NORMAL.y > 0.5) {
			CUSTOM.w = 1.0;
			CUSTOM.z = 0.0;
			VELOCITY = vec3(0.0);
			TRANSFORM[3].xyz += COLLISION_NORMAL * (COLLISION_DEPTH + 0.004);
		}
	}
	// apparition et disparition par l'echelle
	float k = smoothstep(0.0, 0.04, CUSTOM.y) * (1.0 - smoothstep(0.88, 1.0, CUSTOM.y));
	TRANSFORM[0].xyz = vec3(sc * k, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, sc * k, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, sc * k);
}
