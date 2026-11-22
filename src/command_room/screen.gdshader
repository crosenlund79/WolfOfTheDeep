// Emissive console screen: shows a live viewport texture, or a generic
// animated data display, with pixel grid, slight glare and flicker.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform int kind = 0;
uniform float brightness = 1.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col;
	if (kind == 0) {
		col = texture(tex, uv).rgb * tint;
	} else {
		// Generic data page: rows of fluctuating values and a sweeping trace.
		vec2 g = floor(uv * vec2(18.0, 10.0));
		float on = step(0.35, hash(g + floor(TIME * 0.5 + hash(g) * 3.0)));
		float cell = step(0.12, fract(uv.x * 18.0)) * step(0.35, fract(uv.y * 10.0));
		col = tint * 0.55 * on * cell * (0.4 + 0.6 * hash(g + 1.7));
		float trace = 1.0 - smoothstep(0.0, 0.012, abs(uv.y - 0.75 - 0.08 * sin(uv.x * 14.0 + TIME * 1.3)));
		col += tint * trace * 0.8 * step(0.6, uv.y);
		col += tint * 0.04;
	}
	float px = 0.88 + 0.12 * step(0.25, fract(UV.x * 480.0)) * step(0.25, fract(UV.y * 270.0));
	col *= px * (0.97 + 0.03 * sin(TIME * 60.0));
	float edge = smoothstep(0.0, 0.015, uv.x) * smoothstep(1.0, 0.985, uv.x) * smoothstep(0.0, 0.02, uv.y) * smoothstep(1.0, 0.98, uv.y);
	ALBEDO = col * brightness * edge;
}
