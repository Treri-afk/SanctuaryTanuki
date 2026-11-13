shader_type canvas_item;
// Fond des dialogues visual novel : le décor 3D est flouté et assombri.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 6.0) = 3.2;
uniform float darken : hint_range(0.0, 1.0) = 0.42;
uniform vec4 tint : source_color = vec4(0.16, 0.12, 0.22, 1.0);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	c = mix(c, tint.rgb, darken);
	COLOR = vec4(c, 1.0);
}
