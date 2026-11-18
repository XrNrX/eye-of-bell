shader_type canvas_item;
// Shockwave: a ring that ripples outward from a spell's impact and pushes the 3D picture under it outward for a moment.
// Drawn by a full-screen ColorRect inside the dungeon's SubViewport (scripts/shockwave.gd), reading the 3D render back
// as the screen texture.
//
// Pixel rules: the offset is worked out once per logical view pixel (a `pixel_step` x `pixel_step` block of the render,
// so a block moves as one), rounded to whole logical pixels, and the screen is read with texelFetch, so every output
// pixel is an exact copy of some rendered pixel: nothing is blended, blurred or smeared.
//
// Each wave is a vec4: centre x, centre y (render pixels), ring radius (render pixels), strength (render pixels; 0 = off).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec4 waves[4];
uniform float ring_width = 20.0;   // Render pixels: how thick the ring of pushed pixels is.
uniform float pixel_step = 1.0;    // Render pixels per logical view pixel (the window's whole-number scale).

void fragment() {
	ivec2 size = textureSize(screen_tex, 0);
	vec2 block = floor(FRAGCOORD.xy / pixel_step) * pixel_step + pixel_step * 0.5;  // the logical pixel's centre
	vec2 offset = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) {
			continue;
		}
		vec2 to = block - w.xy;
		float dist = length(to);
		if (dist < 0.5) {
			continue;
		}
		float d = (dist - w.z) / ring_width;
		float push = w.w * 4.66 * d * exp(-d * d * 4.0);  // peaks at +-strength: pushed outward just past the ring, pulled in just inside it
		offset += to / dist * push;
	}
	vec2 snapped = round(offset / pixel_step) * pixel_step;
	ivec2 src = clamp(ivec2(FRAGCOORD.xy - snapped), ivec2(0), size - ivec2(1));
	COLOR = vec4(texelFetch(screen_tex, src, 0).rgb, 1.0);
}
