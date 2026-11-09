shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// One frame of a flipbook laid on a wall face with ordinary blending: the ash and dust of a crumbling wall, which must
// darken or grey what is behind it (added light would make it glow).
uniform sampler2D sheet : filter_nearest, source_color;
uniform float frames = 18.0;
uniform float frame = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 suv = vec2((floor(frame) + UV.x) / frames, UV.y);
	vec4 c = texture(sheet, suv);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
}
