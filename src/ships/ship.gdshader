// Painted steel for surface ships: weathering, waterline boot-topping,
// rust streaks and a thermal signature for the infrared mast mode.
shader_type spatial;

global uniform float thermal_mode;

uniform vec3 albedo : source_color = vec3(0.35);
uniform vec3 boot_color : source_color = vec3(0.3, 0.06, 0.05);
uniform float boot_top = -100.0;
uniform float roughness = 0.55;
uniform float thermal_heat = 0.3;

varying vec3 v_local;
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
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo;
	if (v_local.y < boot_top) {
		col = boot_color;
	}
	float streak = vnoise(vec2(v_local.z * 0.8 + v_local.x * 0.8, v_local.y * 0.05));
	float grime = vnoise(v_local.xz * 0.15 + v_local.y * 0.3);
	col *= 0.82 + 0.25 * grime;
	col = mix(col, col * vec3(0.75, 0.55, 0.42), smoothstep(0.72, 0.95, streak) * 0.5);
	ALBEDO = col;
	ROUGHNESS = roughness + grime * 0.15;
	METALLIC = 0.15;
	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		float waterline = 1.0 - smoothstep(0.0, 3.0, v_local.y);
		EMISSION = vec3(thermal_heat + waterline * 0.05);
	}
}
