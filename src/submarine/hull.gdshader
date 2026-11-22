// Anechoic-tiled pressure hull: staggered rubber tiles with per-tile tone,
// seams, grime streaks, wetness near the waterline and caustics when submerged.
shader_type spatial;
render_mode specular_schlick_ggx, diffuse_burley;

global uniform float thermal_mode;

uniform vec3 base_color : source_color = vec3(0.038, 0.041, 0.045);
uniform float tile_size = 0.6;
uniform float wetness = 0.4;
uniform float sea_level = 0.0;
uniform float ocean_time = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float caustic_strength = 1.0;
uniform float thermal_heat = 0.35;
uniform sampler2D caustic_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;

varying vec3 v_world;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV / tile_size;
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 id = floor(uv);
	vec2 f = fract(uv);
	float seam = smoothstep(0.0, 0.035, f.x) * smoothstep(1.0, 0.965, f.x) * smoothstep(0.0, 0.035, f.y) * smoothstep(1.0, 0.965, f.y);
	float h = hash12(id);
	float g = texture(grime_tex, UV * vec2(0.018, 0.06)).r;
	float streak = texture(grime_tex, vec2(UV.x * 0.09, UV.y * 0.004)).r;
	vec3 col = base_color * (0.82 + 0.32 * h) * mix(0.5, 1.0, seam);
	col = mix(col, col * vec3(1.25, 1.15, 1.0) + vec3(0.012, 0.01, 0.006), smoothstep(0.55, 0.9, g) * 0.6);
	col *= 0.85 + 0.3 * smoothstep(0.3, 0.8, streak);
	// Occasional repaired / replaced tiles.
	col = mix(col, col * 1.45, step(0.985, h));

	float above = v_world.y - sea_level;
	float wet = clamp(wetness + (1.0 - smoothstep(0.0, 1.6, above)), 0.0, 1.0);
	col *= mix(1.0, 0.62, wet);
	float rough = mix(0.8, 0.34, wet) + h * 0.06 - (1.0 - seam) * -0.1;

	vec3 emis = vec3(0.0);
	if (above < 0.0) {
		vec3 L = normalize(vec3(sun_dir.x, max(sun_dir.y, 0.2), sun_dir.z));
		vec2 q = v_world.xz + L.xz / L.y * (-above);
		float c1 = texture(caustic_tex, q * 0.09 + vec2(ocean_time * 0.03, ocean_time * 0.021)).r;
		float c2 = texture(caustic_tex, q * 0.13 - vec2(ocean_time * 0.025, -ocean_time * 0.017)).r;
		float caus = pow(clamp(min(c1, c2) * 2.2, 0.0, 1.0), 3.0);
		float facing = clamp(dot(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
		emis = vec3(0.4, 0.75, 0.8) * caus * facing * exp(above * 0.06) * caustic_strength;
	}

	// Tiles sit at very slightly different angles: subtle broken reflections.
	vec3 jitter = vec3(hash12(id + 3.1) - 0.5, hash12(id + 7.7) - 0.5, hash12(id + 1.3) - 0.5) * 0.05;
	NORMAL = normalize(NORMAL + jitter);
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.12, 0.95);
	SPECULAR = 0.3;
	EMISSION = emis;

	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(thermal_heat + 0.1 * seam);
	}
}
