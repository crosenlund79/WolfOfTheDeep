// Rain streaks: thin, tapered and dim, brightened by lightning.
shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled, shadows_disabled;

uniform float brightness = 0.3;

void fragment() {
	float along = sin(UV.y * 3.14159);
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(0.7, 0.76, 0.82) * brightness * along * across * 0.6;
}
