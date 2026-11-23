shader_type canvas_item;
// Bathwater: a blue-green tub of water with drifting caustic light, a darker
// edge under the porcelain rim, a swirl around the drain and, while the tap
// runs, a frothy stream. Cheap: a handful of sines per pixel.

uniform vec2 half_size = vec2(860.0, 400.0);
uniform float corner = 150.0;
uniform vec2 drain = vec2(770.0, 0.0);
uniform float faucet = 0.0;
uniform vec4 deep_col : source_color = vec4(0.12, 0.5, 0.58, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.46, 0.84, 0.83, 1.0);

float sdf_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - (b - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float caustic(vec2 p, float t) {
	vec2 q = p * 0.011;
	float c = sin(q.x * 1.7 + t * 0.9 + sin(q.y * 1.3 + t * 0.6) * 1.6);
	c += sin(q.y * 2.1 - t * 0.7 + sin(q.x * 1.1 - t * 0.5) * 1.4);
	c += sin((q.x + q.y) * 1.3 + t * 0.5);
	return c / 3.0;
}

void fragment() {
	vec2 p = UV * 2.0 * half_size - half_size;
	float d = sdf_box(p, half_size, corner);
	vec2 rd = p - drain;
	float dl = length(rd);
	float sw = smoothstep(280.0, 0.0, dl);
	float ang = sw * 2.6 + TIME * 0.8 * sw;
	vec2 pr = drain + mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang))) * rd;
	float t = TIME;
	float c1 = caustic(pr, t);
	float c2 = caustic(pr * 1.9 + vec2(40.0, 13.0), t * 1.3);
	float lines = smoothstep(0.55, 0.95, c1) * 0.5 + smoothstep(0.6, 0.98, c2) * 0.35;
	vec3 col = mix(shallow_col.rgb, deep_col.rgb, 0.35 + 0.2 * (p.y / half_size.y) - 0.15 * (1.0 - abs(p.x) / half_size.x));
	float edge = smoothstep(-110.0, 0.0, d);
	col = mix(col, deep_col.rgb * 0.8, edge * 0.55);
	col += vec3(1.0) * lines * 0.2;
	float sp = pow(max(caustic(pr * 3.3, t * 2.0), 0.0), 14.0);
	col += sp * 0.4;
	col = mix(col, col * 0.45, smoothstep(60.0, 0.0, dl));
	// The tap's stream: a frothy band along the left end while it runs.
	float band = smoothstep(110.0, 20.0, abs(p.y)) * smoothstep(-440.0, -860.0, p.x);
	float froth = 0.5 + 0.5 * sin(p.x * 0.08 - t * 9.0 + sin(p.y * 0.1) * 2.0);
	col = mix(col, vec3(0.93, 0.98, 1.0), band * faucet * (0.35 + 0.35 * froth));
	COLOR = vec4(col, smoothstep(1.5, -1.5, d));
}
