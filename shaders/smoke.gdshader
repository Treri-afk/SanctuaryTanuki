shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;
// Fumee d'encens : disque doux toujours face camera, couleur et transparence venant de la particule
// (color_ramp du CPUParticles3D). Pas d'ecriture de profondeur : les contours d'ecran l'ignorent.

uniform vec3 tint : source_color = vec3(0.93, 0.91, 0.89);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = clamp(1.0 - dot(p, p), 0.0, 1.0);
	ALBEDO = tint * COLOR.rgb;
	ALPHA = a * a * COLOR.a;
}
