shader_type canvas_item;

// Animation progress driven by tween (0.0 = start, 1.0 = end)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Base flash color
uniform vec4 flash_color : source_color = vec4(0.482, 0.184, 0.745, 1.0);
// Core/highlight color (brighter wash)
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);
// Overall brightness multiplier
uniform float intensity : hint_range(0.5, 5.0) = 1.0;
// Number of secondary flashes (0 = single flash, 1+ = aftershocks)
uniform float aftershocks : hint_range(0.0, 3.0) = 0.0;

void fragment() {
	vec2 uv = UV;

	// ── Flashbang envelope: SHARP bright peak then smooth decay ──
	float flash_peak = 0.08;
	float rise = smoothstep(0.0, flash_peak, progress);
	float decay = exp(-6.0 * max(progress - flash_peak, 0.0));
	float flash = rise * decay;

	// Optional aftershock flashes (dimmer echoes for Wyrm Sphere)
	float aftershock = 0.0;
	if (aftershocks > 0.0) {
		float t2 = max(progress - 0.28, 0.0);
		aftershock += exp(-8.0 * t2) * smoothstep(0.0, 0.03, t2) * 0.5;
	}
	if (aftershocks > 1.0) {
		float t3 = max(progress - 0.48, 0.0);
		aftershock += exp(-10.0 * t3) * smoothstep(0.0, 0.03, t3) * 0.3;
	}
	if (aftershocks > 2.0) {
		float t4 = max(progress - 0.63, 0.0);
		aftershock += exp(-12.0 * t4) * smoothstep(0.0, 0.02, t4) * 0.2;
	}

	float total_flash = (flash + aftershock) * intensity;

	// ── Edge glow: flash emanates from viewport borders inward ──
	// Distance from nearest edge (0 at edge, 0.5 at center)
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	// Bright at edges, fading toward center
	// As progress increases, the flash washes further inward
	float wash_depth = 0.08 + progress * 0.85; // starts tight at edges, floods inward
	float edge_flash = smoothstep(wash_depth, 0.0, edge_dist);
	// Subtle full-screen component so the center is nearly transparent
	float full_screen = 0.05;
	float spatial = mix(full_screen, 1.0, edge_flash);

	total_flash *= spatial;

	// ── Color: blend from white-hot to colored as flash fades ──
	float whiteness = clamp(total_flash * 1.5, 0.0, 1.0);
	vec3 col = mix(flash_color.rgb, core_color.rgb, whiteness) * total_flash;

	// Alpha
	float alpha = clamp(total_flash * 1.2, 0.0, 0.92);

	COLOR = vec4(col, alpha);
}
