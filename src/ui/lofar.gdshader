// Narrowband (frequency-time) display for the selected contact: tonal lines
// that waver slightly, over scrolling broadband noise.
shader_type canvas_item;

uniform vec4 tonals_a = vec4(0.0);
uniform vec4 tonals_b = vec4(0.0);
uniform vec4 levels_a = vec4(0.0);
uniform vec4 levels_b = vec4(0.0);
uniform float max_hz = 400.0;
uniform float scroll = 0.0;
uniform float strength = 1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float line(float hz, float f, float lvl, float row) {
	float wob = sin(row * 0.13 + f) * 0.6 + sin(row * 0.041 + f * 3.0) * 0.8;
	float d = abs(hz - f - wob);
	float fade = 0.55 + 0.45 * hash(vec2(floor(f), row));
	return lvl * exp(-d * d / 1.2) * fade;
}

void fragment() {
	float hz = UV.x * max_hz;
	float row = floor(UV.y * 200.0 - scroll);
	float n = hash(vec2(floor(UV.x * 400.0), row));
	float v = 0.05 + n * 0.2;
	for (int i = 0; i < 4; i++) {
		v += line(hz, tonals_a[i], levels_a[i], row) * strength;
		v += line(hz, tonals_b[i], levels_b[i], row) * strength;
	}
	vec3 col = mix(vec3(0.03, 0.04, 0.02), vec3(1.0, 0.68, 0.25), smoothstep(0.05, 0.7, v));
	col = mix(col, vec3(1.0, 0.95, 0.8), smoothstep(0.8, 1.2, v));
	col += vec3(0.25, 0.2, 0.1) * (1.0 - smoothstep(0.0, 0.003, abs(fract(UV.x * 8.0) - 0.0))) * 0.2;
	COLOR = vec4(col, 1.0);
}
