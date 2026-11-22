// Floes and growlers: ride the shared Gerstner swell at each instance origin
// and tilt with the local slope.
shader_type spatial;
render_mode specular_schlick_ggx;

#define MAX_WAVES 12

global uniform float thermal_mode;
uniform vec4 wave_a[MAX_WAVES];
uniform vec4 wave_b[MAX_WAVES];
uniform float ocean_time = 0.0;

varying float v_world_y;

vec3 gerstner(vec2 p) {
	vec3 d = vec3(0.0);
	for (int i = 0; i < MAX_WAVES; i++) {
		vec4 a = wave_a[i];
		vec4 b = wave_b[i];
		float th = a.z * dot(a.xy, p) - b.x * ocean_time + b.z;
		float qa = b.y * a.w;
		d.x += qa * a.x * cos(th);
		d.z += qa * a.y * cos(th);
		d.y += a.w * sin(th);
	}
	return d;
}

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 d0 = gerstner(origin.xz);
	vec3 dx = gerstner(origin.xz + vec2(4.0, 0.0));
	vec3 dz = gerstner(origin.xz + vec2(0.0, 4.0));
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rel = wp - origin;
	vec3 disp = vec3(d0.x, d0.y + rel.x * (dx.y - d0.y) / 4.0 * 0.7 + rel.z * (dz.y - d0.y) / 4.0 * 0.7, d0.z) * 0.92;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * disp;
	v_world_y = wp.y + disp.y - d0.y;
}

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col = mix(vec3(0.5, 0.75, 0.85), vec3(0.94, 0.96, 1.0), smoothstep(0.2, 0.8, nw.y));
	if (v_world_y < -0.2) {
		col = mix(col, vec3(0.1, 0.38, 0.45), 0.6);
	}
	ALBEDO = col;
	ROUGHNESS = 0.75;
	BACKLIGHT = vec3(0.05, 0.2, 0.25);
	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.01);
	}
}
