shader_type canvas_item;

// Thin bright border line with soft inner glow.
// Drawn on top of the slot contents to frame the item.

uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float border_width : hint_range(0.005, 0.08) = 0.025;
uniform float glow_size : hint_range(0.0, 0.3) = 0.1;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	// Distance from nearest edge (0 at edge, 0.5 at centre)
	float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));

	// Thin bright border line
	float border = 1.0 - smoothstep(border_width - 0.006, border_width + 0.006, d);

	// Soft glow that fades inward from the edge
	float glow = (1.0 - smoothstep(0.0, glow_size, d)) * glow_intensity;

	float alpha = max(border, glow);

	COLOR = vec4(border_color.rgb, alpha * border_color.a);
}
