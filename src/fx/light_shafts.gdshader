// Underwater god rays: fog density streaks projected along the sun direction
// from a moving caustic pattern at the surface.
shader_type fog;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float time = 0.0;
uniform float ocean_time = 0.0;
uniform float strength = 1.0;
uniform vec3 ray_color : source_color = vec3(0.55, 0.85, 0.9);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fog() {
	vec3 p = WORLD_POSITION;
	float below = max(-p.y, 0.0);
	vec3 L = normalize(vec3(sun_dir.x, max(sun_dir.y, 0.25), sun_dir.z));
	// Where does the ray toward the sun cross the surface?
	vec2 q = p.xz + L.xz / L.y * below;
	float n1 = texture(noise_tex, q * 0.045 + vec2(time * 0.012, time * 0.007)).r;
	float n2 = texture(noise_tex, q * 0.11 - vec2(time * 0.02, -time * 0.015)).r;
	float shaft = pow(clamp(n1 * 0.65 + n2 * 0.55 - 0.35, 0.0, 1.0), 2.2) * 3.0;
	float depth_fade = exp(-below * 0.035) * smoothstep(0.0, 2.0, below);
	DENSITY = (0.008 + shaft * 0.11) * depth_fade * strength * step(p.y, 0.0);
	ALBEDO = ray_color;
	EMISSION = ray_color * shaft * 0.06 * depth_fade * strength;
}
