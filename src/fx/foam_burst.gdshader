// Foam burst drawn into the wake map: a soft, broken ring of churned water.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;

uniform float strength = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	float ang = atan(c.y, c.x);
	float n = vnoise(vec2(ang * 3.0 + seed, d * 6.0)) * 0.6 + vnoise(c * 9.0 + seed) * 0.4;
	float edge = 0.75 + n * 0.25;
	float ring = smoothstep(edge, edge - 0.35, d) * (0.35 + 0.65 * smoothstep(0.1, 0.6, d));
	float foam = ring * (0.4 + 0.6 * n) * strength;
	ALBEDO = vec3(foam * 0.7, foam, 0.0);
}
