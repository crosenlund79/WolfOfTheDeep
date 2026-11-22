// Exterior camera lens: rain beading and running on the glass in heavy
// weather, and a gentle refractive wobble with darker edges underwater.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float rain = 0.0;
uniform float underwater = 0.0;
uniform float time = 0.0;
uniform vec2 resolution = vec2(1920.0, 1080.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// One layer of droplets; some slide down leaving a faint trail.
vec3 drop_layer(vec2 uv, float scale, float t, float seed) {
	vec2 aspect = vec2(resolution.x / resolution.y, 1.0);
	vec2 g = uv * aspect * scale;
	vec2 id = floor(g);
	float h = hash(id + seed);
	float slide = step(0.75, h) * fract(t * (0.08 + h * 0.15) + h);
	vec2 f = fract(g) - 0.5;
	vec2 c = vec2(hash(id + 3.7 + seed) - 0.5, hash(id + 9.1 + seed) - 0.5) * 0.5;
	c.y += slide * 0.9 - 0.45 * step(0.75, h);
	float r = 0.08 + 0.12 * hash(id + 5.3 + seed);
	vec2 d = f - c;
	float m = smoothstep(r, r * 0.55, length(d * vec2(1.0, 0.85)));
	float life = smoothstep(0.0, 0.2, fract(t * 0.05 + h * 7.0)) * step(0.35, hash(id + 1.1 + seed));
	float trail = smoothstep(0.04, 0.0, abs(d.x)) * smoothstep(0.0, 0.3, d.y) * smoothstep(0.6, 0.0, d.y) * step(0.75, h) * 0.3;
	return vec3(d * m * life, max(m * life, trail));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = vec2(0.0);
	float wet = 0.0;
	if (rain > 0.001) {
		vec3 a = drop_layer(uv, 7.0, time, 0.0);
		vec3 b = drop_layer(uv, 13.0, time * 1.3, 17.0);
		off += (a.xy * 0.09 + b.xy * 0.05) * rain;
		wet = max(a.z, b.z * 0.7) * rain;
	}
	if (underwater > 0.001) {
		off += vec2(sin(uv.y * 22.0 + time * 1.4), cos(uv.x * 18.0 + time * 1.1)) * 0.0022 * underwater;
	}
	vec3 col = textureLod(screen_tex, uv + off, wet * 1.5).rgb;
	col = mix(col, col * 1.08 + vec3(0.02), wet * 0.4);
	vec2 c = uv - 0.5;
	float vig = 1.0 - dot(c, c) * (0.35 + underwater * 0.9);
	col *= vig;
	COLOR = vec4(col, 1.0);
}
