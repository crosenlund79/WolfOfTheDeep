// Arctic island: snow on gentle slopes, dark rock on cliffs and scree, wet
// stone and kelp-dark shallows at the waterline.
shader_type spatial;

global uniform float thermal_mode;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - n.y;
	float h = v_world.y;
	float nn = vnoise(v_world.xz * 0.004) * 0.6 + vnoise(v_world.xz * 0.03) * 0.4;
	vec3 snow = vec3(0.88, 0.92, 0.97);
	vec3 rock = vec3(0.13, 0.12, 0.12) * (0.7 + nn * 0.6);
	float snow_w = smoothstep(0.5, 0.3, slope + (nn - 0.5) * 0.25);
	snow_w *= smoothstep(4.0, 14.0, h + nn * 6.0);
	vec3 col = mix(rock, snow, snow_w);
	if (h < 1.5) {
		col = mix(col, vec3(0.05, 0.06, 0.06), clamp((1.5 - h) / 6.0, 0.0, 1.0));
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.65, snow_w);
	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.02 + (1.0 - snow_w) * 0.03);
	}
}
