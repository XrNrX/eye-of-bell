shader_type canvas_item;
// Palette filter: snaps every pixel of the 3D view to the nearest of the game's 32 palette colours, after a light
// ordered (Bayer 4x4) dither, so lights, bloom, fog and particles all land on palette colours and match the pixel
// art. Optional (Options: PALETTE FILTER). Drawn by a full-screen ColorRect inside the dungeon's SubViewport
// (scripts/palette_filter.gd), reading the 3D render back as the screen texture.
//
// `dither` is how far the ordered pattern pushes a colour before it is snapped: 0 gives hard bands, a few percent
// breaks them up into the familiar crosshatch.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;  // One row, `palette_size` pixels, in sRGB.
uniform int palette_size = 32;
uniform float dither = 0.05;

float bayer4(ivec2 p) {
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[(p.y & 3) * 4 + (p.x & 3)]) / 16.0;
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 t = c + vec3((bayer4(ivec2(FRAGCOORD.xy)) - 0.5) * dither);
	vec3 best = c;
	float best_d = 1e9;
	for (int i = 0; i < palette_size; i++) {
		vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
		vec3 d = t - p;
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = p;
		}
	}
	COLOR = vec4(best, 1.0);
}
