class_name WakeMap
extends SubViewport
## Top-down orthographic render of all wake ribbons into a world-space texture
## that the ocean shader samples for foam and churned water.

const SIZE_M := 4000.0
const RES := 2048

var follow: Node3D
var ocean: Ocean
var trails: Array[WakeTrail] = []
var _cam: Camera3D


func _ready() -> void:
	size = Vector2i(RES, RES)
	transparent_bg = false
	msaa_3d = Viewport.MSAA_DISABLED
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	positional_shadow_atlas_size = 0
	use_hdr_2d = true
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = SIZE_M
	_cam.near = 1.0
	_cam.far = 2000.0
	_cam.cull_mask = WakeTrail.LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam.environment = env
	add_child(_cam)


func add_trail(trail: WakeTrail) -> void:
	trails.append(trail)
	add_child(trail)


func advance() -> void:
	if follow == null:
		return
	var texel := SIZE_M / float(RES)
	var c := follow.global_position
	var cx := snappedf(c.x, texel)
	var cz := snappedf(c.z, texel)
	_cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(cx, 800.0, cz))
	if ocean:
		ocean.set_param("wake_map", get_texture())
		ocean.set_param("wake_rect", Vector3(cx, cz, SIZE_M))
