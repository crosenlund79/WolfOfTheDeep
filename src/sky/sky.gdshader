// Silent Sea — sky dome: atmosphere graded toward and away from the sun,
// sun and moon, stars, and a drifting cloud deck lit from the sun's side,
// with lightning flashes inside the clouds.
shader_type sky;

global uniform float thermal_mode;

uniform vec3 zenith_color : source_color = vec3(0.12, 0.25, 0.45);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.68, 0.72);
uniform vec3 horizon_sun : source_color = vec3(0.9, 0.7, 0.5);
uniform vec3 ground_color : source_color = vec3(0.05, 0.07, 0.09);
uniform vec3 sun_dir = vec3(0.0, 0.3, -0.95);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.82);
uniform float sun_disk = 40.0;
uniform float sun_glow = 1.0;
uniform vec3 moon_dir = vec3(0.3, 0.5, 0.8);
uniform float moon_intensity = 0.0;
uniform float star_intensity = 0.0;
uniform float cloud_coverage = 0.5;
uniform float cloud_softness = 0.18;
uniform vec3 cloud_lit : source_color = vec3(0.95, 0.93, 0.9);
uniform vec3 cloud_ambient : source_color = vec3(0.7, 0.72, 0.78);
uniform vec3 cloud_dark : source_color = vec3(0.35, 0.38, 0.42);
uniform float cloud_time = 0.0;
uniform vec2 cloud_wind = vec2(0.0035, 0.0012);
uniform float cloud_scale = 0.11;
uniform float lightning = 0.0;
uniform vec2 lightning_pos = vec2(0.2, -0.3);
uniform float sky_energy = 1.0;
uniform float horizon_haze = 0.12;
uniform float aurora = 0.0;

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_detail : filter_linear_mipmap, repeat_enable;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float clouds_at(vec2 uv) {
	float n1 = texture(cloud_noise, uv).r;
	float n2 = texture(cloud_detail, uv * 3.3 - cloud_wind * cloud_time * 1.6).r;
	float n3 = texture(cloud_detail, uv * 9.7 + cloud_wind * cloud_time * 2.3).r;
	return n1 * 0.68 + n2 * 0.27 + n3 * 0.12;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float hp = max(h, 0.0);
	vec3 sd3 = normalize(sun_dir);
	float sd = max(dot(d, sd3), 0.0);

	// Horizon colour swings toward the sun's side of the sky.
	vec3 dh = normalize(vec3(d.x, 0.0, d.z) + vec3(1e-4));
	vec3 sh = normalize(vec3(sd3.x, 0.0, sd3.z) + vec3(1e-4));
	float toward = pow(clamp(dot(dh, sh) * 0.5 + 0.5, 0.0, 1.0), 3.0);
	vec3 hor = mix(horizon_color, horizon_sun, toward);

	vec3 col = mix(hor, zenith_color, pow(hp, 0.45));
	col = mix(col, hor * 1.04, exp(-hp / max(horizon_haze, 0.01)) * 0.55);
	if (h < 0.0) {
		col = mix(hor * 0.85, ground_color, smoothstep(0.0, 0.2, -h));
	}

	vec3 glow = sun_color * (pow(sd, 5.0) * 0.18 + pow(sd, 40.0) * 0.5 + pow(sd, 500.0) * 2.5) * sun_glow;
	float disk = smoothstep(0.99986, 0.99994, sd) * step(-0.02, sd3.y);
	vec3 sun = sun_color * disk * sun_disk;

	vec3 night = vec3(0.0);
	if (star_intensity > 0.001 && h > 0.0) {
		vec3 cell = floor(d * 420.0);
		float s = hash13(cell);
		float tw = 0.75 + 0.25 * sin(cloud_time * 3.0 + s * 60.0);
		night += vec3(0.85, 0.9, 1.0) * step(0.9975, s) * tw * star_intensity * smoothstep(0.0, 0.2, h) * (0.5 + 3.0 * (s - 0.9975) / 0.0025);
		float band = exp(-pow(dot(d, normalize(vec3(0.3, 0.6, 0.74))) * 4.0, 2.0));
		night += vec3(0.5, 0.55, 0.7) * band * 0.025 * star_intensity * texture(cloud_detail, d.xz * 2.0).r;
	}
	// Aurora borealis: two slowly flowing curtains in the northern sky.
	if (aurora > 0.01 && h > 0.0) {
		vec2 ap = d.xz / (h + 0.35);
		float at = cloud_time * 0.02;
		float a_tot = 0.0;
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float curve = ap.y + 0.95 + fi * 0.55 + 0.35 * sin(ap.x * (0.7 + fi * 0.3) + at * (1.0 + fi)) + 0.15 * sin(ap.x * 2.3 - at * 1.7);
			float band = exp(-curve * curve * (6.0 + fi * 3.0));
			float rays = texture(cloud_detail, vec2(ap.x * (0.9 + fi * 0.4) + at * 0.3, 0.37 + fi * 0.2)).r;
			rays = pow(clamp(rays * 1.4, 0.0, 1.0), 2.5);
			a_tot += band * (0.25 + rays * 1.1) * (1.0 - fi * 0.35);
		}
		float afade = smoothstep(0.03, 0.25, h) * (1.0 - smoothstep(0.75, 0.98, h));
		vec3 aur_col = mix(vec3(0.15, 1.0, 0.45), vec3(0.55, 0.25, 0.85), smoothstep(0.3, 0.7, h));
		night += aur_col * a_tot * afade * aurora * 0.5;
	}
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	night += vec3(0.85, 0.88, 0.95) * smoothstep(0.99955, 0.99965, md) * moon_intensity * 6.0;
	night += vec3(0.4, 0.5, 0.7) * pow(md, 24.0) * moon_intensity * 0.2;

	float cover = 0.0;
	if (h > -0.02) {
		vec2 uv = d.xz / (max(h, 0.0) + 0.09);
		vec2 cuv = uv * cloud_scale + cloud_wind * cloud_time;
		float n = clouds_at(cuv);
		float thr = 1.0 - cloud_coverage;
		cover = smoothstep(thr - cloud_softness, thr + cloud_softness, n);
		vec2 to_sun = normalize(sd3.xz + vec2(1e-4)) * 0.045;
		float ns = clouds_at(cuv + to_sun);
		float lit = clamp(0.5 + (n - ns) * 4.5, 0.0, 1.0);
		float thick = smoothstep(thr, thr + 0.38, n);
		// Ambient sky light on the cloud, darkened where it is thick.
		vec3 ccol = mix(cloud_ambient, cloud_dark, clamp(thick * 0.9 - lit * 0.3, 0.0, 1.0));
		// Sun-facing edges pick up sunlight, strongest toward the sun.
		ccol += cloud_lit * lit * (0.25 + 1.1 * pow(sd, 3.0)) * (1.0 - thick * 0.55);
		ccol += sun_color * pow(sd, 10.0) * (1.0 - thick) * 1.6 * sun_glow;
		float ld = length(uv * 0.12 - lightning_pos);
		ccol += vec3(0.75, 0.8, 1.0) * lightning * exp(-ld * 2.2) * (0.4 + thick) * 1.5;
		float hf = smoothstep(-0.02, 0.18, h);
		ccol = mix(hor * 0.95, ccol, hf);
		cover *= mix(0.6, 1.0, hf);
		col = mix(col + night, ccol, cover);
		sun *= 1.0 - smoothstep(0.0, 0.5, cover);
	} else {
		col += night;
	}
	col += glow * (1.0 - cover * 0.75) + sun;
	col += vec3(0.6, 0.65, 0.8) * lightning * 0.08;

	if (thermal_mode > 0.5) {
		col = vec3(0.015 + cover * 0.05);
	}
	COLOR = col * sky_energy;
}
