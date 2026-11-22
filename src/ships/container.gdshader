// Shipping containers: corrugated sides from instance colour.
shader_type spatial;

global uniform float thermal_mode;

void fragment() {
	float corr = 0.85 + 0.15 * sin(UV.x * 140.0);
	vec3 col = COLOR.rgb * corr;
	float edge = smoothstep(0.0, 0.02, UV.x) * smoothstep(1.0, 0.98, UV.x) * smoothstep(0.0, 0.03, UV.y) * smoothstep(1.0, 0.97, UV.y);
	col *= mix(0.6, 1.0, edge);
	ALBEDO = col;
	ROUGHNESS = 0.65;
	METALLIC = 0.2;
	if (thermal_mode > 0.5) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(0.22);
	}
}
