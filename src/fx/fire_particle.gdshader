// Additive flame billboard: hot core fading to orange and transparent edges.
shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.2, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = dot(d, d);
	float core = exp(-r * 6.0);
	float a = exp(-r * 3.0) * COLOR.a * tint.a;
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.92, 0.7), core);
	ALBEDO = hot * a * 3.0;
}
