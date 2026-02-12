shader_type canvas_item;

uniform vec4 lightning_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform float density : hint_range(2.0, 12.0) = 5.0;
uniform float speed : hint_range(0.3, 4.0) = 1.5;
uniform float bolt_width : hint_range(0.01, 0.25) = 0.08;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.4;

vec2 _hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float _voronoi(vec2 uv, float t) {
	vec2 n = floor(uv);
	vec2 f = fract(uv);
	float md1 = 8.0, md2 = 8.0;

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = _hash(n + g);
			o = 0.5 + 0.5 * sin(t + 6.2831853 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md1) { md2 = md1; md1 = d; }
			else if (d < md2) { md2 = d; }
		}
	}
	return sqrt(md2) - sqrt(md1);
}

void fragment() {
	vec2 uv = UV;
	float center_dist = length(uv - 0.5);
	float t = TIME * speed;

	// Two layers of Voronoi for richer branching
	float e1 = _voronoi(uv * density, t);
	float e2 = _voronoi(uv * density * 1.8 + 7.3, t * 1.3 + 3.1);

	// Sharp bolt cores
	float bolt1 = 1.0 - smoothstep(0.0, bolt_width, e1);
	float bolt2 = 1.0 - smoothstep(0.0, bolt_width * 0.7, e2);
	float bolts = max(bolt1, bolt2 * 0.6);

	// Soft glow halo
	float glow1 = 1.0 - smoothstep(0.0, bolt_width * 4.0, e1);
	float glow2 = 1.0 - smoothstep(0.0, bolt_width * 3.0, e2);
	float glow = max(glow1, glow2) * 0.25;

	float combined = bolts + glow;

	// Flicker
	float flicker = 1.0 - flicker_strength + flicker_strength * (
		0.5 + 0.3 * sin(TIME * 8.3 + uv.x * 3.0)
		    + 0.2 * sin(TIME * 13.7 + uv.y * 5.0)
	);
	combined *= flicker;

	// Circular fade
	float fade = smoothstep(0.55, 0.25, center_dist);

	float alpha = combined * intensity * fade;
	alpha = clamp(alpha * 0.7, 0.0, 1.0);

	COLOR = vec4(lightning_color.rgb, alpha);
}
