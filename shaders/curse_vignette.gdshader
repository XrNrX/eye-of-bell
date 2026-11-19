shader_type canvas_item;
// The curse zone's edge glow (scripts/curse_vignette.gd): stepped bands of murky yellow-green creeping in from the edges of the 3D view.
// Pixel rules: the bands are worked out per LOGICAL view pixel, each a fixed level (no smooth ramp), and the edge of every band is
// broken up with a Bayer 4x4 dither, so it reads as pixels like the rest of the game. It is slow and steady (the script only moves
// `strength` gently), never a flash: nothing here is sharp or red.

uniform vec2 view_size = vec2(416.0, 260.0);  // Logical view pixels.
uniform float strength = 0.0;                 // 0..1: how far in it has crept.
uniform float reach = 72.0;                   // Logical pixels in from the edge at strength 1.
uniform float bands = 5.0;
uniform float alpha = 0.7;                   // The strongest band's opacity.
uniform vec4 col_edge : source_color = vec4(0.525, 0.651, 0.447, 1.0);
uniform vec4 col_dark : source_color = vec4(0.149, 0.220, 0.173, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * view_size);
	float d = min(min(px.x, view_size.x - 1.0 - px.x), min(px.y, view_size.y - 1.0 - px.y));
	float r = max(reach * strength, 0.001);
	float t = 1.0 - d / r;  // 1 at the edge, 0 where it stops.
	if (t <= 0.0) {
		discard;
	}
	float v = t * bands + (bayer4(px) - 0.5) * 0.9;
	float level = clamp(floor(v + 0.5), 0.0, bands);
	if (level < 1.0) {
		discard;
	}
	float k = level / bands;
	COLOR = vec4(mix(col_dark.rgb, col_edge.rgb, k * k), alpha * k);
}
