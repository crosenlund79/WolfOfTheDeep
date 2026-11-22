// Optronic mast camera feed: sensor modes (TV / low-light / thermal),
// digital noise, slight lens aberration, and seawater washing over the window.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0;
uniform float wash = 0.0;
uniform float submerged = 0.0;
uniform float time = 0.0;
uniform float flash = 0.0;
uniform vec2 resolution = vec2(1920.0, 1080.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 drops(vec2 uv, float t) {
	// Droplets clinging to the window, slowly running down.
	vec2 off = vec2(0.0);
	for (int i = 0; i < 3; i++) {
		float sc = 9.0 + float(i) * 7.0;
		vec2 g = uv * vec2(sc * resolution.x / resolution.y, sc);
		g.y += t * (0.15 + float(i) * 0.1);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + float(i) * 17.0);
		vec2 c = vec2(h - 0.5, fract(h * 13.7) - 0.5) * 0.6;
		float r = 0.12 + 0.2 * fract(h * 7.3);
		float d = length(f - c);
		float m = smoothstep(r, r * 0.6, d) * step(0.45, fract(h * 3.1));
		off += (f - c) * m * 0.06;
	}
	return off;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float lod = 0.0;
	if (wash > 0.001) {
		uv += drops(uv, time) * wash;
		uv.y += sin(uv.x * 30.0 + time * 6.0) * 0.004 * wash;
		lod = wash * 2.5;
	}
	float ca = 0.0018 * dot(c, c) * 4.0;
	vec3 col;
	col.r = textureLod(screen_tex, uv + c * ca, lod).r;
	col.g = textureLod(screen_tex, uv, lod).g;
	col.b = textureLod(screen_tex, uv - c * ca, lod).b;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float n = hash(floor(SCREEN_UV * resolution * 0.75) + fract(time * 37.0) * 91.0) - 0.5;
	if (mode == 0) {
		// Camera-feed grade: cooler, less saturated, crisper.
		col = mix(vec3(lum), col, 0.6) * vec3(0.94, 1.0, 1.04);
		col = (col - 0.45) * 1.18 + 0.45;
		col += n * 0.018;
	} else if (mode == 1) {
		float g = pow(clamp(lum * 5.0, 0.0, 1.0), 0.65);
		col = vec3(0.62, 0.95, 0.72) * (g + n * 0.12);
	} else {
		float heat = pow(clamp(lum * 3.2, 0.0, 1.0), 0.85);
		col = vec3(heat * 0.96, heat * 0.98, heat) + n * 0.05;
	}
	// Submerged mast window: dark green-blue murk.
	col = mix(col, vec3(0.02, 0.09, 0.1) + col * 0.15, submerged);
	// Wash tint.
	col = mix(col, col * vec3(0.75, 0.9, 0.95), wash * 0.5);
	float vig = smoothstep(0.85, 0.35, length(c * vec2(resolution.x / resolution.y, 1.0)) * 0.75);
	col *= mix(0.55, 1.0, vig);
	col += flash;
	COLOR = vec4(col, 1.0);
}
