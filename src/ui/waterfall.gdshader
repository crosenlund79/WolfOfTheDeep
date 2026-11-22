// Broadband bearing-time waterfall. Contact history is a small float texture
// (columns = contacts, rows = time); noise is hashed per bearing bin and per
// absolute row so it scrolls with the trace.
shader_type canvas_item;

uniform sampler2D history : filter_nearest;
uniform int rows = 240;
uniform int head = 0;
uniform float total = 0.0;
uniform float frac = 0.0;
uniform float heading_deg = 0.0;
uniform float selected_bearing = -1.0;
uniform float self_noise = 0.15;
uniform vec3 tint_lo : source_color = vec3(0.02, 0.06, 0.05);
uniform vec3 tint_mid : source_color = vec3(0.15, 0.75, 0.45);
uniform vec3 tint_hi : source_color = vec3(0.85, 1.0, 0.9);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float rowf = UV.y * float(rows) + frac;
	int r = int(rowf);
	int idx = (head - r + rows * 8) % rows;
	float abs_row = total - float(r);
	float b = UV.x * 360.0;
	float bin = floor(UV.x * 720.0);
	float n = hash(vec2(bin, abs_row)) * 0.7 + hash(vec2(bin * 0.5, abs_row * 1.7)) * 0.3;
	float v = 0.06 + n * 0.22;
	// Baffles: own-ship noise astern.
	float rel = mod(b - heading_deg + 540.0, 360.0) - 180.0;
	float baffle = smoothstep(158.0, 172.0, abs(rel));
	v += baffle * (0.06 + n * 0.12) * (0.4 + self_noise);
	for (int c = 0; c < 8; c++) {
		vec4 h = texelFetch(history, ivec2(c, idx), 0);
		if (h.g > 0.001) {
			float db = abs(b - h.r * 360.0);
			db = min(db, 360.0 - db);
			float w = 0.7 + h.b * 3.0;
			float trace = exp(-db * db / (2.0 * w * w));
			v += h.g * trace * (0.55 + 0.6 * hash(vec2(bin + float(c) * 13.0, abs_row)));
		}
	}
	v = clamp(v, 0.0, 1.4);
	vec3 col = mix(tint_lo, tint_mid, smoothstep(0.05, 0.55, v));
	col = mix(col, tint_hi, smoothstep(0.6, 1.1, v));
	// Selected bearing cursor.
	if (selected_bearing >= 0.0) {
		float ds = abs(b - selected_bearing);
		ds = min(ds, 360.0 - ds);
		col += vec3(1.0, 0.7, 0.3) * (1.0 - smoothstep(0.0, 0.35, ds)) * 0.35;
	}
	// Faint grid every 30 degrees.
	col += vec3(0.12, 0.25, 0.3) * (1.0 - smoothstep(0.0, 0.18, abs(mod(b + 15.0, 30.0) - 15.0))) * 0.5;
	COLOR = vec4(col, 1.0);
}
