class_name WakeTrail
extends MeshInstance3D
## Records a vessel's path and draws its Kelvin wake (two diverging arms) and
## turbulent centre churn as additive ribbons into the top-down wake map.
## Red channel = foam, green channel = churned water.

const LAYER := 1 << 19

var source: Node3D
var beam := 8.0
var length_ahead := 38.0
var intensity := 1.0
var spacing := 6.0
var max_points := 110
var max_age := 160.0

var _pts: Array[Vector3] = []
var _ages: Array[float] = []
var _time := 0.0
var _imesh: ImmediateMesh


func _ready() -> void:
	layers = LAYER
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	material_override = mat
	top_level = true
	global_transform = Transform3D.IDENTITY
	extra_cull_margin = 16384.0


func advance(dt: float, speed: float, surface_factor: float) -> void:
	_time += dt
	if source == null:
		return
	var p := source.global_position
	p.y = 0.0
	if _pts.is_empty() or _pts[0].distance_to(p) > spacing:
		_pts.insert(0, p)
		_ages.insert(0, _time)
	while _pts.size() > max_points or (_ages.size() > 2 and _time - _ages[_ages.size() - 1] > max_age):
		_pts.pop_back()
		_ages.pop_back()
	_rebuild(p, speed, surface_factor)


func _rebuild(head: Vector3, speed: float, surface_factor: float) -> void:
	_imesh.clear_surfaces()
	var strength := intensity * surface_factor * smoothstep(0.3, 4.5, speed)
	if strength < 0.01 or _pts.size() < 2:
		return
	var path: Array[Vector3] = [head]
	var ages: Array[float] = [0.0]
	for i in _pts.size():
		path.append(_pts[i])
		ages.append(_time - _ages[i])
	var dists: Array[float] = [0.0]
	for i in range(1, path.size()):
		dists.append(dists[i - 1] + path[i].distance_to(path[i - 1]))
	var fwd := (path[0] - path[1]).normalized() if path[0].distance_to(path[1]) > 0.01 else Vector3.FORWARD
	var head_pt := head + fwd * length_ahead

	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Centre churn: starts at the stern and broadens with age.
	_ribbon(path, dists, ages, strength, 0.0, 1)
	# Kelvin arms start at the bow and diverge at ~19.5 degrees.
	_ribbon(path, dists, ages, strength, -1.0, 0, head_pt)
	_ribbon(path, dists, ages, strength, 1.0, 0, head_pt)
	_imesh.surface_end()


func _ribbon(path: Array[Vector3], dists: Array[float], ages: Array[float], strength: float, side: float, kind: int, head_pt: Vector3 = Vector3.INF) -> void:
	var prev_l := Vector3.ZERO
	var prev_c := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_col := Color.BLACK
	var have_prev := false
	var n := path.size()
	var start := 0
	if kind == 0 and head_pt != Vector3.INF:
		path = path.duplicate()
		dists = dists.duplicate()
		ages = ages.duplicate()
		path.insert(0, head_pt)
		dists.insert(0, -length_ahead)
		ages.insert(0, 0.0)
		n = path.size()
	for i in range(start, n):
		var p := path[i]
		var tangent: Vector3
		if i < n - 1:
			tangent = (path[i] - path[i + 1]).normalized()
		else:
			tangent = (path[i - 1] - path[i]).normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		var d := dists[i] + length_ahead
		var age := ages[i]
		var centre: Vector3
		var half: float
		var col: Color
		if kind == 1:
			var behind := dists[i] - length_ahead * 0.9
			half = beam * 0.45 + maxf(behind, 0.0) * 0.045 + age * 0.08
			centre = p
			var fade_in := smoothstep(-6.0, 6.0, behind)
			var a := exp(-age / 55.0) * fade_in * strength
			col = Color(a * 0.85, a * 1.0, 0.0)
		else:
			var spread := minf(d * 0.354, 260.0)
			half = 1.6 + d * 0.012 + age * 0.04
			centre = p + right * side * (beam * 0.5 + spread)
			var a2 := exp(-age / 70.0) * smoothstep(-2.0, 10.0, d) * strength * 0.75
			col = Color(a2, a2 * 0.35, 0.0)
		var l := centre - right * half
		var r := centre + right * half
		if have_prev:
			var z := Color(0, 0, 0)
			_quad(prev_l, l, prev_c, centre, z, z, prev_col, col)
			_quad(prev_c, centre, prev_r, r, prev_col, col, z, z)
		prev_l = l
		prev_c = centre
		prev_r = r
		prev_col = col
		have_prev = true


func _quad(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, ca0: Color, ca1: Color, cb0: Color, cb1: Color) -> void:
	_v(a0, ca0)
	_v(b0, cb0)
	_v(a1, ca1)
	_v(a1, ca1)
	_v(b0, cb0)
	_v(b1, cb1)


func _v(p: Vector3, c: Color) -> void:
	_imesh.surface_set_color(c)
	_imesh.surface_add_vertex(p)
