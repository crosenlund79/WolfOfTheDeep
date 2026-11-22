class_name LiveScreen
extends Node2D
## One live display composited onto a pre-rendered plate: a perspective-
## correct grid (projected in Blender) textured with a live SubViewport, and
## masked so that anything standing in front of the display stays in front.

const SHADER := """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_linear;
uniform int channel = 0;
uniform float brightness = 1.0;
uniform vec3 tint = vec3(1.0);
varying vec2 plate_uv;
void vertex() {
	plate_uv = COLOR.rg;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 m = texture(mask_tex, plate_uv);
	float a = channel == 0 ? m.r : (channel == 1 ? m.g : m.b);
	// A little glass: lift the blacks slightly, keep highlights crisp.
	vec3 col = c.rgb * brightness * tint + vec3(0.012, 0.016, 0.02);
	COLOR = vec4(col, smoothstep(0.15, 0.6, a));
}
"""

var grid: Array = []          # rows of [x, y] in plate pixels
var plate_size := Vector2(1920, 1080)
var texture: Texture2D
var uv_rect := Rect2(0, 0, 1, 1)
var _mat: ShaderMaterial


func setup(p_grid: Array, p_plate: Vector2, mask: Texture2D, channel: int, tex: Texture2D, uv: Rect2) -> void:
	grid = p_grid
	plate_size = p_plate
	texture = tex
	uv_rect = uv
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("mask_tex", mask)
	_mat.set_shader_parameter("channel", channel)
	material = _mat


func set_look(brightness: float, tint: Color) -> void:
	if _mat:
		_mat.set_shader_parameter("brightness", brightness)
		_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))


func _draw() -> void:
	if texture == null or grid.size() < 2:
		return
	var n := grid.size() - 1
	for j in n:
		for i in n:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var p: Array = grid[c.y][c.x]
				var v := Vector2(float(p[0]), float(p[1]))
				pts.append(v)
				uvs.append(uv_rect.position + Vector2(float(c.x) / n, float(c.y) / n) * uv_rect.size)
				cols.append(Color(v.x / plate_size.x, v.y / plate_size.y, 0.0, 1.0))
			draw_polygon(pts, cols, uvs, texture)
