// Glacial ice: compressed blue strata, bright snow tops, turquoise underwater
// body, a little backlit translucency.
shader_type spatial;
render_mode specular_schlick_ggx;

global uniform float thermal_mode;

varying vec3 v_world;
varying vec3 v_local;

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
	v_local = VERTEX;
}

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float steep = 1.0 - clamp(nw.y, 0.0, 1.0);
	float strata = vnoise(vec2(v_local.x * 0.03 + v_local.z * 0.03, v_local.y * 0.45));
	float grain = vnoise(v_local.xz * 0.35 + v_local.y * 0.2);
	vec3 snow = vec3(0.93, 0.96, 1.0);
	vec3 blue = vec3(0.42, 0.7, 0.86);
	vec3 col = mix(snow, blue, clamp(steep * 0.55 + strata * 0.3 - 0.15, 0.0, 1.0));
	col *= 0.9 + grain * 0.12;
	float rough = mix(0.55, 0.28, steep);
	if (v_world.y < 0.0) {
		float d = -v_world.y;
		col = mix(col * vec3(0.5, 0.85, 0.9), vec3(0.05, 0.3, 0.38), clamp(d / 35.0, 0.0, 1.0));
		rough = 0.25;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	BACKLIGHT = vec3(0.08, 0.3, 0.38);
	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(0.012);
	}
}
