shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, ambient_light_disabled, specular_disabled, shadows_disabled;
// Poussieres dorees : petits points additifs visibles seulement dans le soleil (eclaires par la lumiere directionnelle
// et ses ombres : ils s'allument dans les rayons entre les arbres et s'eteignent a l'ombre).

uniform vec4 mote_color : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float intensity = 0.9;
uniform float level = 1.0;

varying float v_life;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	v_life = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = max(1.0 - dot(p, p), 0.0);
	a *= a;
	float life = sin(clamp(v_life, 0.0, 1.0) * 3.14159);
	ALBEDO = mote_color.rgb * a * life * intensity * level;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR * smoothstep(0.3, 0.8, ATTENUATION);
	}
}
