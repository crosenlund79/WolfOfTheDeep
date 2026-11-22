class_name Submarine
extends Node3D
## Cosmetic submarine: rides the swell when surfaced, glides at depth, turns,
## dives, raises masts and shows navigation lights. Staged behaviour only.

signal depth_mode_changed(label: String)
signal vents_opened

const KNOT := 0.5144
const SPEED_STEPS := [0.0, 3.0, 6.0, 9.0, 13.0, 18.0]
const SPEED_NAMES := ["ALL STOP", "AHEAD 1/3", "AHEAD 2/3", "AHEAD STANDARD", "AHEAD FULL", "AHEAD FLANK"]
const DEPTH_MODES := [
	{"label": "SURFACED", "depth": 2.05},
	{"label": "PERISCOPE DEPTH", "depth": 10.6},
	{"label": "TRANSIT 40 M", "depth": 40.0},
	{"label": "DEEP 120 M", "depth": 120.0},
]

var ocean: Ocean
var heading := 0.0
var speed := 3.0 * KNOT
var speed_step := 2
var rudder := 0.0
var depth_mode := 0
var depth := 2.05
var masts_up := true
var nav_lights := 1.0
var wetness := 0.4

var _target_depth := 2.05
var _depth_rate := 0.0
var _pitch := 0.0
var _roll := 0.0
var _heave := 0.0
var _heave_v := 0.0
var _pitch_v := 0.0
var _roll_v := 0.0
var _mast_ext := 1.0
var _masts: Dictionary = {}
var _rotor: MeshInstance3D
var _rotor_angle := 0.0
var _hull_mat: ShaderMaterial
var _lights: Array[Node3D] = []
var _vent_spray: GPUParticles3D
var _bubbles: GPUParticles3D
var _bow_spray: GPUParticles3D
var _surfaced_time := 0.0
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_hull_mat = ShaderMaterial.new()
	_hull_mat.shader = load("res://src/submarine/hull.gdshader")
	_hull_mat.set_shader_parameter("caustic_tex", _caustic_tex())
	_hull_mat.set_shader_parameter("grime_tex", _grime_tex())
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = SubmarineBuilder.build_hull_mesh(_hull_mat)
	_body.add_child(hull)

	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.16, 0.12, 0.08)
	rotor_mat.metallic = 0.85
	rotor_mat.roughness = 0.32
	_rotor = MeshInstance3D.new()
	_rotor.name = "Rotor"
	_rotor.mesh = SubmarineBuilder.build_rotor_mesh(rotor_mat)
	_rotor.position = Vector3(0, 0, SubmarineBuilder.L * 0.5 - 2.0)
	_rotor.mesh = _recentre(_rotor.mesh as ArrayMesh, Vector3(0, 0, SubmarineBuilder.L * 0.5 - 2.0))
	_body.add_child(_rotor)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.055, 0.058, 0.062)
	metal.metallic = 0.55
	metal.roughness = 0.38
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.01, 0.012, 0.015)
	glass.metallic = 0.2
	glass.roughness = 0.04
	glass.emission_enabled = true
	glass.emission = Color(0.05, 0.12, 0.12)
	_masts = SubmarineBuilder.build_masts(_body, metal, glass)

	_build_lights()
	_build_particles()


func _recentre(m: ArrayMesh, offset: Vector3) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] -= offset
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, m.surface_get_material(s))
	return out


func hull_material() -> ShaderMaterial:
	return _hull_mat


func set_speed_step(step: int) -> void:
	speed_step = clampi(step, 0, SPEED_STEPS.size() - 1)


func speed_label() -> String:
	return SPEED_NAMES[speed_step]


func knots() -> float:
	return speed / KNOT


func set_depth_mode(mode: int) -> void:
	mode = clampi(mode, 0, DEPTH_MODES.size() - 1)
	if mode == depth_mode:
		return
	if depth_mode == 0 and mode > 0:
		vents_opened.emit()
		_vent_spray.restart()
		_vent_spray.emitting = true
	depth_mode = mode
	_target_depth = float(DEPTH_MODES[mode]["depth"])
	depth_mode_changed.emit(String(DEPTH_MODES[mode]["label"]))


func depth_label() -> String:
	return String(DEPTH_MODES[depth_mode]["label"])


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, -cos(heading))


## World position of the optronic mast head (camera position for periscope view).
func mast_head() -> Vector3:
	var m: Node3D = _masts["photonics"][0]
	var h := float(_masts["photonics"][1])
	return m.to_global(Vector3(0, h + 0.42, -0.35))


func mast_exposure() -> float:
	return mast_head().y


func mast_extension() -> float:
	return _mast_ext


func is_surfaced() -> bool:
	return depth < 3.5


func advance(dt: float) -> void:
	var target_speed := float(SPEED_STEPS[speed_step]) * KNOT
	speed = move_toward(speed, target_speed, dt * 0.09)
	var turn_rate := speed / 260.0
	heading = wrapf(heading + rudder * turn_rate * dt, -PI, PI)
	var fwd := forward()
	position += fwd * speed * dt

	# Depth change with a believable bow-down / bow-up angle.
	var dd := _target_depth - depth
	var max_rate := lerpf(0.35, 1.1, clampf(speed / 6.0, 0.0, 1.0))
	var want_rate := clampf(dd * 0.08, -max_rate, max_rate)
	_depth_rate = move_toward(_depth_rate, want_rate, dt * 0.12)
	depth += _depth_rate * dt
	var dive_pitch := clampf(-_depth_rate / maxf(speed, 1.5), -0.22, 0.22)

	# Wave response fades out with depth.
	var surf := clampf(1.0 - (depth - 2.05) / 7.0, 0.0, 1.0)
	var want_heave := 0.0
	var want_pitch := 0.0
	var want_roll := 0.0
	if ocean and surf > 0.0:
		var bow := position + fwd * 26.0
		var stern := position - fwd * 24.0
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var hb := ocean.height_at(bow.x, bow.z)
		var hs := ocean.height_at(stern.x, stern.z)
		var hc := ocean.height_at(position.x, position.z)
		var hp := ocean.height_at(position.x - right.x * 6.0, position.z - right.z * 6.0)
		var hst := ocean.height_at(position.x + right.x * 6.0, position.z + right.z * 6.0)
		want_heave = (hb + hs + hc * 2.0) * 0.25 * surf
		want_pitch = atan2(hb - hs, 50.0) * 0.85 * surf
		want_roll = atan2(hp - hst, 12.0) * 0.9 * surf
	want_roll += -rudder * clampf(speed / 8.0, 0.0, 1.0) * 0.05
	_heave_v += ((want_heave - _heave) * 3.2 - _heave_v * 2.2) * dt
	_heave += _heave_v * dt
	_pitch_v += ((want_pitch + dive_pitch - _pitch) * 2.6 - _pitch_v * 2.0) * dt
	_pitch += _pitch_v * dt
	_roll_v += ((want_roll - _roll) * 2.2 - _roll_v * 1.1) * dt
	_roll += _roll_v * dt

	position.y = -depth + _heave
	basis = Basis(Vector3.UP, -heading) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)

	# Masts.
	var want_mast := 1.0 if masts_up and depth < 30.0 else 0.0
	_mast_ext = move_toward(_mast_ext, want_mast, dt * 0.35)
	for key in _masts:
		var m: Node3D = _masts[key][0]
		var h := float(_masts[key][1])
		m.position.y = SubmarineBuilder.SAIL_TOP - 0.25 - h * (1.0 - smoothstep(0.0, 1.0, _mast_ext))

	_rotor_angle += dt * (speed / KNOT) * 0.55
	_rotor.rotation.z = _rotor_angle

	# Wetness and lights.
	if is_surfaced():
		_surfaced_time += dt
	else:
		_surfaced_time = 0.0
	wetness = clampf(1.0 - _surfaced_time / 90.0, 0.25, 1.0)
	_hull_mat.set_shader_parameter("wetness", wetness)
	if ocean:
		_hull_mat.set_shader_parameter("ocean_time", ocean.ocean_time)
	var lights_on := nav_lights > 0.5 and depth < 4.0
	for l in _lights:
		l.visible = lights_on

	_bubbles.emitting = depth > 6.0 and speed > 1.0
	_bubbles.amount_ratio = clampf(speed / 6.0, 0.2, 1.0)
	_bow_spray.emitting = is_surfaced() and speed > 2.0
	_bow_spray.amount_ratio = clampf(speed / 9.0, 0.1, 1.0)


func _build_lights() -> void:
	var defs := [
		[Vector3(0, SubmarineBuilder.SAIL_TOP + 0.25, -20.3), Color(1.0, 0.96, 0.85)],
		[Vector3(-1.25, SubmarineBuilder.SAIL_TOP - 1.2, -19.5), Color(1.0, 0.08, 0.05)],
		[Vector3(1.25, SubmarineBuilder.SAIL_TOP - 1.2, -19.5), Color(0.05, 1.0, 0.3)],
		[Vector3(0, SubmarineBuilder.DECK_Y + 0.35, 22.0), Color(1.0, 0.96, 0.85)],
	]
	for d in defs:
		var holder := Node3D.new()
		holder.position = d[0]
		_body.add_child(holder)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = d[1]
		mat.emission_enabled = true
		mat.emission = d[1]
		mat.emission_energy_multiplier = 14.0
		sm.material = mat
		bulb.mesh = sm
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(bulb)
		var omni := OmniLight3D.new()
		omni.light_color = d[1]
		omni.light_energy = 2.2
		omni.omni_range = 9.0
		omni.omni_attenuation = 1.6
		omni.light_volumetric_fog_energy = 0.0
		omni.shadow_enabled = false
		holder.add_child(omni)
		_lights.append(holder)


func _build_particles() -> void:
	# Ballast-vent spray along the casing when diving.
	_vent_spray = GPUParticles3D.new()
	_vent_spray.amount = 900
	_vent_spray.lifetime = 2.4
	_vent_spray.one_shot = true
	_vent_spray.explosiveness = 0.15
	_vent_spray.emitting = false
	_vent_spray.position = Vector3(0, SubmarineBuilder.DECK_Y + 0.2, 0)
	_vent_spray.visibility_aabb = AABB(Vector3(-20, -5, -45), Vector3(40, 30, 90))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.6, 0.1, 30.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.8
	pm.damping_min = 0.6
	pm.damping_max = 1.4
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	curve.curve = c
	pm.alpha_curve = curve
	_vent_spray.process_material = pm
	_vent_spray.draw_pass_1 = _soft_quad(Vector2(1.6, 1.6), Color(0.92, 0.95, 0.97, 0.55))
	_body.add_child(_vent_spray)

	# Prop wash bubbles at depth.
	_bubbles = GPUParticles3D.new()
	_bubbles.amount = 600
	_bubbles.lifetime = 6.0
	_bubbles.position = Vector3(0, 0, SubmarineBuilder.L * 0.5 + 1.0)
	_bubbles.local_coords = false
	_bubbles.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var bm := ParticleProcessMaterial.new()
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bm.emission_sphere_radius = 2.0
	bm.direction = Vector3(0, 0.3, 1)
	bm.spread = 25.0
	bm.initial_velocity_min = 0.5
	bm.initial_velocity_max = 2.0
	bm.gravity = Vector3(0, 0.6, 0)
	bm.scale_min = 0.05
	bm.scale_max = 0.25
	_bubbles.process_material = bm
	_bubbles.draw_pass_1 = _soft_quad(Vector2(0.4, 0.4), Color(0.7, 0.9, 0.95, 0.45))
	_bubbles.emitting = false
	_body.add_child(_bubbles)

	# Bow spray while running surfaced.
	_bow_spray = GPUParticles3D.new()
	_bow_spray.amount = 500
	_bow_spray.lifetime = 1.8
	_bow_spray.position = Vector3(0, 0.8, -SubmarineBuilder.L * 0.5 + 4.0)
	_bow_spray.local_coords = false
	_bow_spray.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(2.5, 0.3, 2.0)
	sp.direction = Vector3(0, 0.9, -0.3)
	sp.spread = 35.0
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 6.0
	sp.gravity = Vector3(0, -9.8, 0)
	sp.scale_min = 0.5
	sp.scale_max = 1.6
	sp.alpha_curve = curve
	_bow_spray.process_material = sp
	_bow_spray.draw_pass_1 = _soft_quad(Vector2(1.2, 1.2), Color(0.9, 0.94, 0.96, 0.4))
	_bow_spray.emitting = false
	_body.add_child(_bow_spray)


static func _soft_quad(size: Vector2, color: Color) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/soft_particle.gdshader")
	mat.set_shader_parameter("tint", color)
	q.material = mat
	return q


static func _caustic_tex() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.frequency = 0.05
	n.seed = 77
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	t.invert = true
	t.noise = n
	return t


static func _grime_tex() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 5
	n.seed = 12
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	return t
