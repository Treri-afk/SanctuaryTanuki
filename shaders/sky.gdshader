shader_type sky;
// Ciel peint : degrade zenith -> horizon par phase, halo et disque du soleil, nuages en aplats qui derivent lentement
// (dessous ombre, bords eclaires cote soleil, liseré lumineux a contre-jour), bande de brume a l'horizon qui raccorde
// les cretes lointaines (ridge.gdshader) et le brouillard. La passe cubemap (eclairage ambiant / perspective aerienne
// du brouillard) n'a pas de nuages.

uniform vec4 zenith_color : source_color = vec4(0.30, 0.50, 0.78, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.90, 0.82, 0.70, 1.0);
uniform vec4 haze_color : source_color = vec4(0.92, 0.84, 0.74, 1.0);     // bande de brume sous ~6 degres
uniform vec4 ground_color : source_color = vec4(0.42, 0.40, 0.42, 1.0);
uniform vec4 sun_glow_color : source_color = vec4(1.0, 0.80, 0.55, 1.0);
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.70, 0.70, 0.82, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.9;
uniform float cloud_speed = 0.006;
uniform float sun_size = 1.6;          // degres
uniform float sun_glow = 0.6;
uniform float horizon_height = 0.06;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

float sky_fbm(vec2 p) {
	float v = textureLod(cloud_noise, p, 0.0).r * 0.55;
	v += textureLod(cloud_noise, p * 2.13 + 0.37, 0.0).r * 0.3;
	v += textureLod(cloud_noise, p * 4.71 + 0.71, 0.0).r * 0.15;
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float sdot = dot(d, sd);

	// degrade principal (courbe douce, plus de couleur d'horizon pres du sol)
	float ty = clamp(y, 0.0, 1.0);
	vec3 col = mix(horizon_color.rgb, zenith_color.rgb, smoothstep(0.0, 0.62, pow(ty, 0.7)));
	// l'horizon se rechauffe du cote du soleil
	float az = clamp(dot(normalize(d.xz + 1e-5), normalize(sd.xz + 1e-5)) * 0.5 + 0.5, 0.0, 1.0);
	col += sun_glow_color.rgb * pow(az, 3.0) * (1.0 - smoothstep(0.0, 0.45, ty)) * 0.22 * sun_glow;
	// bande de brume
	col = mix(col, haze_color.rgb, 1.0 - smoothstep(0.0, horizon_height * 2.2, y));
	// halo du soleil
	float s = max(sdot, 0.0);
	// la passe cubemap (ambiance, perspective aerienne du brouillard) ne garde qu'un halo large et doux
	float halo = AT_CUBEMAP_PASS ? pow(s, 6.0) * 0.12 : pow(s, 6.0) * 0.18 + pow(s, 48.0) * 0.35 + pow(s, 600.0) * 0.6;
	col += sun_glow_color.rgb * halo * sun_glow;

	if (!AT_CUBEMAP_PASS && y > 0.0) {
		// nuages projetes sur un plafond plat, derive lente le long du vent dominant
		vec2 uv = d.xz / (y + 0.09) * 0.11 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.37);
		float n = sky_fbm(uv);
		float cov = 1.0 - cloud_cover;
		float a = smoothstep(cov, cov + 0.07, n);
		// ombre interne : densite echantillonnee un peu vers le soleil
		vec2 toward = normalize(sd.xz + 1e-5) * 0.035;
		float n2 = sky_fbm(uv + toward);
		float lit = smoothstep(-0.03, 0.06, n - n2 + 0.02);
		float core = smoothstep(cov + 0.08, cov + 0.22, n);
		vec3 cc = mix(cloud_shade.rgb, cloud_lit.rgb, lit * 0.85 + 0.15 * (1.0 - core));
		// liseré lumineux a contre-jour sur les bords fins
		cc += sun_glow_color.rgb * pow(s, 8.0) * (1.0 - core) * 0.9;
		float fade = smoothstep(0.015, 0.22, y);
		cc = mix(cc, haze_color.rgb, (1.0 - smoothstep(0.0, 0.3, y)) * 0.55);
		col = mix(col, cc, a * fade * cloud_opacity);
	}
	// disque du soleil (devant les nuages fins, derriere les epais)
	float disc = smoothstep(cos(radians(sun_size)), cos(radians(sun_size * 0.82)), sdot);
	if (!AT_CUBEMAP_PASS) {
		col = mix(col, sun_glow_color.rgb * 3.0 + vec3(0.6), disc * smoothstep(-0.02, 0.01, y) * sun_glow);
	}

	if (y < 0.0) {
		col = mix(haze_color.rgb, ground_color.rgb, smoothstep(0.0, 0.25, -y));
	}
	COLOR = col;
}
