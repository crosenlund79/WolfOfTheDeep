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


## A soft, broken ring of churned white water that fades over `duration` seconds.
func add_foam_burst(world_pos: Vector3, size_m: float, strength: float, duration: float) -> void:
	var disc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size_m, size_m)
	disc.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/foam_burst.gdshader")
	mat.set_shader_parameter("seed", randf() * 50.0)
	mat.set_shader_parameter("strength", strength)
	disc.material_override = mat
	disc.layers = WakeTrail.LAYER
	disc.top_level = true
	add_child(disc)
	disc.global_position = Vector3(world_pos.x, 0.0, world_pos.z)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), strength, 0.0, duration)
	tw.tween_callback(disc.queue_free)
