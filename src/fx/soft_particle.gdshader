// Soft round billboard for spray, mist and bubbles.
shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float light_level = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = dot(d, d);
	float a = exp(-r * 3.5) * (1.0 - smoothstep(0.7, 1.0, r));
	ALBEDO = tint.rgb * light_level;
	ALPHA = a * tint.a * COLOR.a;
}
