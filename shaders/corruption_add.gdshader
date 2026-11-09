shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// One frame of a flipbook (a row of frames, art/corruption/<name>_sheet.png) laid on a wall face and added to what is behind
// it, so it glows. Used for the pulsing curse veins and the gold holy light that burns them away.
// `burn` takes the picture away from the centre outward: anything nearer the middle of the face than that (0 = nothing, 1 = the
// corners) is gone, with a hard pixel edge. That is how the veins burn away from the centre as the gold light spreads.
uniform sampler2D sheet : filter_nearest, source_color;
uniform float frames = 12.0;
uniform float frame = 0.0;
uniform float burn = 0.0;
uniform float gain = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float d = distance(UV, vec2(0.5)) / 0.70710678;
	if (d < burn) {
		discard;
	}
	vec2 suv = vec2((floor(frame) + UV.x) / frames, UV.y);
	vec4 c = texture(sheet, suv);
	ALBEDO = c.rgb * tint.rgb * gain;
	ALPHA = c.a;
}
