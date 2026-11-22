class_name Torpedo
extends Node3D
## One simplified heavyweight torpedo: ejected from the tube, it accelerates,
## turns onto its ordered course, settles at a shallow running depth and runs
## straight until it strikes a hull or runs out of fuel. It can miss.

signal struck(ship: SurfaceShip, point: Vector3)
signal ran_out

const RUN_SPEED := 26.0
const TURN_RATE := deg_to_rad(9.0)
const RUN_DEPTH := 4.0
const MAX_RANGE := 6000.0

var ordered_heading := 0.0
var heading := 0.0
var speed := 7.0
var depth := 6.0
var travelled := 0.0
var targets: Array[Node3D] = []
var done := false

var _prop: Node3D
var _bubbles: GPUParticles3D
var _age := 0.0


func _ready() -> void:
	var body := ShaderMaterial.new()
	body.shader = load("res://src/ships/ship.gdshader")
	body.set_shader_parameter("albedo", Color(0.14, 0.16, 0.14))
	body.set_shader_parameter("roughness", 0.35)
	body.set_shader_parameter("thermal_heat", 0.6)
	_part(_cylinder(0.27, 5.0), Vector3(0, 0, 0.3), body, Vector3(PI * 0.5, 0, 0))
	var nose := SphereMesh.new()
	nose.radius = 0.27
	nose.height = 1.1
	var nm := _part(nose, Vector3(0, 0, -2.2), body)
	nm.scale = Vector3(1.0, 1.0, 1.25)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.27
	tail.bottom_radius = 0.1
	tail.height = 1.0
	_part(tail, Vector3(0, 0, 3.3), body, Vector3(PI * 0.5, 0, 0))
	for k in 4:
		var fin := BoxMesh.new()
		fin.size = Vector3(0.03, 0.42, 0.5)
		var f := _part(fin, Vector3(0, 0, 3.45), body)
		f.rotation.z = PI * 0.25 + k * PI * 0.5
		f.position += Vector3(cos(f.rotation.z + PI * 0.5), sin(f.rotation.z + PI * 0.5), 0) * 0.2
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.26
	_part(ring, Vector3(0, 0, 3.75), body, Vector3(PI * 0.5, 0, 0))
	_prop = Node3D.new()
	_prop.position = Vector3(0, 0, 3.8)
	add_child(_prop)
	for k in 3:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.04, 0.36, 0.08)
		var b := MeshInstance3D.new()
		b.mesh = blade
		b.material_override = body
		b.rotation.z = k * TAU / 3.0
		b.rotation.y = 0.5
		_prop.add_child(b)

	_bubbles = GPUParticles3D.new()
	_bubbles.amount = 900
	_bubbles.lifetime = 7.0
	_bubbles.local_coords = false
	_bubbles.position = Vector3(0, 0, 4.0)
	_bubbles.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0, 0.4, 1)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.04
	pm.scale_max = 0.18
	_bubbles.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var qm := ShaderMaterial.new()
	qm.shader = load("res://src/fx/soft_particle.gdshader")
	qm.set_shader_parameter("tint", Color(0.8, 0.95, 1.0, 0.5))
	q.material = qm
	_bubbles.draw_pass_1 = q
	add_child(_bubbles)


func launch(from: Transform3D, p_ordered_heading: float) -> void:
	global_transform = from
	var f := -from.basis.z
	heading = atan2(f.x, -f.z)
	ordered_heading = p_ordered_heading
	depth = -from.origin.y


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, -cos(heading))


func advance(dt: float) -> void:
	if done:
		return
	_age += dt
	# Ejection, then the motor spins up.
	var want := RUN_SPEED if _age > 0.8 else 9.0
	speed = move_toward(speed, want, dt * 9.0)
	if _age > 0.6:
		heading += clampf(wrapf(ordered_heading - heading, -PI, PI), -TURN_RATE * dt, TURN_RATE * dt)
	depth = move_toward(depth, RUN_DEPTH, dt * 1.6)
	var start := global_position
	var target_pos := start + forward() * speed * dt
	target_pos.y = -depth
	# Swept hit test so a fast step can't tunnel through a hull.
	for i in range(1, 5):
		var p := start.lerp(target_pos, float(i) / 4.0)
		for t in targets:
			var ship := t as SurfaceShip
			if ship and ship.is_afloat() and ship.contains_point(p):
				global_position = p
				done = true
				_bubbles.emitting = false
				struck.emit(ship, p)
				return
	global_position = target_pos
	travelled += speed * dt
	var dir := forward()
	global_transform.basis = Basis.looking_at(Vector3(dir.x, (depth - RUN_DEPTH) * -0.05, dir.z).normalized(), Vector3.UP)
	_prop.rotation.z += dt * speed * 3.0
	if travelled > MAX_RANGE:
		done = true
		_bubbles.emitting = false
		ran_out.emit()


func _cylinder(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 20
	return c


func _part(mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi
