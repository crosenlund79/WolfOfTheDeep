// Silent Sea — open-ocean surface.
// Gerstner swell (shared with CPU buoyancy), per-pixel wave normals, detail
// normal maps, crest foam from surface compression, wake foam from a world-space
// wake map, refraction with depth absorption, subsurface glow and an
// underside (Snell's window) look when the camera is below the surface.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx, diffuse_burley;

#define MAX_WAVES 12

global uniform float thermal_mode;

uniform vec4 wave_a[MAX_WAVES];
uniform vec4 wave_b[MAX_WAVES];
uniform float ocean_time = 0.0;
uniform float lod_k = 0.0233;
uniform float lod_r0 = 21.9;
uniform float footprint = 0.0011;
uniform float wave_scale = 1.5;

uniform vec3 deep_color : source_color = vec3(0.004, 0.022, 0.034);
uniform vec3 body_color : source_color = vec3(0.01, 0.07, 0.085);
uniform vec3 sss_color : source_color = vec3(0.06, 0.42, 0.40);
uniform float sss_strength = 1.0;
uniform float light_level = 1.0;
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.97);
uniform float foam_amount = 0.5;
uniform float roughness_near = 0.05;
uniform float roughness_far = 0.22;
uniform float detail_strength = 0.6;
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float absorption = 0.09;
uniform vec3 sun_dir = vec3(0.0, 0.5, 0.8);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform float camera_underwater = 0.0;
uniform vec3 underwater_color : source_color = vec3(0.0, 0.07, 0.09);
uniform float bioluminescence = 0.0;

uniform sampler2D normal_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D wake_map : filter_linear, repeat_disable;
uniform vec3 wake_rect = vec3(0.0, 0.0, 4000.0);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_world;
varying float v_jac;
varying float v_height;

float geo_fade(float wl, float dist) {
	float sp = (dist + lod_r0) * lod_k;
	return smoothstep(2.5 * sp, 5.0 * sp, wl);
}

float px_fade(float wl, float dist) {
	float fp = dist * footprint;
	return smoothstep(3.0 * fp, 10.0 * fp, wl);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	float dist = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	vec3 disp = vec3(0.0);
	float jxx = 1.0;
	float jzz = 1.0;
	float jxz = 0.0;
	for (int i = 0; i < MAX_WAVES; i++) {
		vec4 a = wave_a[i];
		vec4 b = wave_b[i];
		float wl = 6.2831853 / max(a.z, 1e-4);
		float A = a.w * geo_fade(wl, dist);
		float th = a.z * dot(a.xy, p) - b.x * ocean_time + b.z;
		float s = sin(th);
		float c = cos(th);
		float qa = b.y * A;
		disp.x += qa * a.x * c;
		disp.z += qa * a.y * c;
		disp.y += A * s;
		float qka = qa * a.z;
		jxx -= qka * a.x * a.x * s;
		jzz -= qka * a.y * a.y * s;
		jxz -= qka * a.x * a.y * s;
	}
	VERTEX += disp;
	v_world = wp;
	v_jac = jxx * jzz - jxz * jxz;
	v_height = disp.y;
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	// Reverse-Z: 0 means nothing was drawn behind the water (open ocean / sky).
	if (d <= 1e-7) {
		return 1e6;
	}
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	float z = -v.z / v.w;
	return (z > 0.0 && z < 1e6) ? z : 1e6;
}

void fragment() {
	vec2 p = v_world.xz;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(wpos - CAMERA_POSITION_WORLD);

	// Per-pixel Gerstner normal (crisp lighting regardless of mesh density).
	vec3 n = vec3(0.0, 1.0, 0.0);
	for (int i = 0; i < MAX_WAVES; i++) {
		vec4 a = wave_a[i];
		vec4 b = wave_b[i];
		float wl = 6.2831853 / max(a.z, 1e-4);
		float A = a.w * px_fade(wl, dist);
		float th = a.z * dot(a.xy, p) - b.x * ocean_time + b.z;
		float s = sin(th);
		float c = cos(th);
		float wa = a.z * A;
		n.x -= a.x * wa * c;
		n.z -= a.y * wa * c;
		n.y -= b.y * wa * s;
	}

	// Detail ripples from scrolling normal maps.
	float t = ocean_time;
	vec2 wd = normalize(wind_dir + vec2(1e-4));
	vec2 wp_ = vec2(-wd.y, wd.x);
	vec3 d1 = texture(normal_a, p * 0.055 + wd * t * 0.032).xyz * 2.0 - 1.0;
	vec3 d2 = texture(normal_b, p * 0.13 + wp_ * t * 0.045 + wd * t * 0.02).xyz * 2.0 - 1.0;
	vec3 d3 = texture(normal_a, p * 0.011 - wp_ * t * 0.006 + wd * t * 0.01).xyz * 2.0 - 1.0;
	float near_f = 1.0 - smoothstep(25.0, 260.0, dist);
	float mid_f = 1.0 - smoothstep(150.0, 1800.0, dist);
	vec2 dn = (d1.xy * 0.6 + d2.xy * 0.45) * detail_strength * near_f + d3.xy * detail_strength * 0.6 * mid_f;
	n = normalize(vec3(n.x + dn.x, n.y, n.z + dn.y));

	bool below = camera_underwater > 0.5;
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 N = below ? -n : n;
	float NdotV = clamp(dot(N, V), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);

	// Foam: crests where the surface compresses, plus the wake map.
	vec2 fuv = p * 0.06 + wd * t * 0.018;
	float f1 = texture(foam_tex, fuv).r;
	float f2 = texture(foam_tex, p * 0.21 - wd * t * 0.03 + vec2(0.37, 0.11)).r;
	// Lace: bright bubble webs, densest where both scales agree.
	float pattern = smoothstep(0.45, 0.85, f1 * 0.55 + f2 * 0.6);
	// Surface compression (1 - Jacobian) marks breaking crests.
	float thr = mix(0.42, 0.14, foam_amount);
	float crest = smoothstep(thr, thr + 0.28, 1.0 - v_jac);
	float crest_foam = crest * mix(pattern, 1.0, crest * crest) * smoothstep(-0.1, 0.4, v_height / max(wave_scale, 0.2) + 0.3);
	crest_foam = clamp(crest_foam, 0.0, 1.0);
	// Old foam drifting on the surface in heavy weather.
	crest_foam += smoothstep(0.9, 0.98, f2) * smoothstep(0.6, 0.9, f1) * foam_amount * foam_amount * 0.35 * mid_f;

	float wake = 0.0;
	float churn = 0.0;
	vec2 wuv = (p - wake_rect.xy) / wake_rect.z + 0.5;
	if (wuv.x > 0.0 && wuv.y > 0.0 && wuv.x < 1.0 && wuv.y < 1.0) {
		vec4 wm = texture(wake_map, wuv);
		wake = wm.r;
		churn = wm.g;
	}
	float wake_foam = smoothstep(0.08, 0.75, wake * (0.35 + pattern * 1.1 + f2 * 0.35));
	wake_foam = max(wake_foam, smoothstep(0.25, 0.9, churn * (0.6 + f1 * 0.8)));

	// Refraction and the water body.
	vec2 refr_uv = SCREEN_UV + N.xz * 0.045 / (1.0 + dist * 0.015);
	float surf_depth = -VERTEX.z;
	float scene_depth = linear_depth(refr_uv, INV_PROJECTION_MATRIX);
	if (scene_depth < surf_depth) {
		refr_uv = SCREEN_UV;
		scene_depth = linear_depth(refr_uv, INV_PROJECTION_MATRIX);
	}
	float water_path = max(scene_depth - surf_depth, 0.0);
	vec3 refr = textureLod(screen_tex, refr_uv, 0.0).rgb;
	float transmit = exp(-water_path * absorption);

	// Contact foam where the water meets a hull.
	float contact = (1.0 - smoothstep(0.0, 0.9, water_path)) * (1.0 - smoothstep(150.0, 350.0, dist));
	wake_foam = max(wake_foam, contact * smoothstep(0.2, 0.7, f2 + 0.25));

	float foam = clamp(crest_foam + wake_foam, 0.0, 1.0);

	vec3 L = normalize(sun_dir);
	float up = clamp(dot(n, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	// Looking down into the water reveals more of its colour; grazing views see deep tone.
	vec3 water = mix(deep_color, body_color, pow(clamp(dot(V, vec3(0.0, 1.0, 0.0)), 0.0, 1.0), 0.6)) * light_level;
	// Sunlight scattering through thin wave crests.
	vec3 Lh = normalize(L + n * 0.35);
	float sss = pow(clamp(dot(V, -Lh), 0.0, 1.0), 4.0) * smoothstep(-0.3, 1.1, v_height / max(wave_scale, 0.2) + 0.2);
	sss += 0.18 * clamp(dot(n, L), 0.0, 1.0) * smoothstep(0.0, 1.0, v_height / max(wave_scale, 0.2) + 0.5);
	vec3 scatter = sss_color * sss * sss_strength * sun_color * clamp(L.y + 0.15, 0.0, 1.0);
	vec3 under = mix(water, refr, transmit) + scatter;
	// Wake churn shows lighter turquoise just below the foam.
	under += body_color * 3.0 * light_level * clamp(wake + churn, 0.0, 1.0) * (1.0 - foam);

	float rough = mix(roughness_near, roughness_far, smoothstep(150.0, 6000.0, dist));

	if (!below) {
		ALBEDO = foam_color * foam * light_level;
		EMISSION = under * (1.0 - fresnel) * (1.0 - foam);
		// Foam glows softly with skylight so it reads even under heavy overcast.
		EMISSION += foam_color * foam * (0.12 + light_level * 0.22);
		// Faint glowing wake on dark nights.
		EMISSION += vec3(0.1, 0.75, 0.85) * bioluminescence * (wake_foam * 0.6 + crest_foam * 0.15) * (0.6 + 0.4 * sin(t * 1.7 + f1 * 9.0));
		ROUGHNESS = mix(rough, 0.85, foam);
		SPECULAR = mix(0.354, 0.2, foam);
		METALLIC = 0.0;
	} else {
		// From below: Snell's window shows the sky, outside it total internal reflection.
		float window = smoothstep(0.58, 0.72, NdotV);
		vec3 tir = underwater_color * 0.55 * light_level;
		vec3 through = textureLod(screen_tex, SCREEN_UV + N.xz * 0.08, 0.0).rgb;
		EMISSION = mix(tir, through * 0.85 + underwater_color * 0.3, window) + foam_color * foam * 0.25 * light_level;
		ALBEDO = vec3(0.0);
		ROUGHNESS = 0.3;
		SPECULAR = 0.0;
	}

	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = vec3(0.035 + fresnel * 0.08 + foam * 0.06 + up * 0.01);
	}

	NORMAL = (VIEW_MATRIX * vec4(N, 0.0)).xyz;
}
