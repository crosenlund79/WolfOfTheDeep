class_name Torpedo
extends Node3D
## A simplified wire-guided heavyweight torpedo: ejected from the tube, it
## accelerates, turns onto its ordered (gyro) course and settles at its set
## running depth. After a safe run its seeker switches on; within its cone and
## range it may acquire a ship and home on her, and it may lose her again.
## It strikes a hull or runs out of fuel. Telemetry comes back up the wire
## (until the wire parts) and is what the boat knows of the run.

signal struck(ship: SurfaceShip, point: Vector3)
signal ran_out
signal telemetry(kind: String)

const RUN_SPEED := 26.0                 # ~50 kt
const TURN_RATE := deg_to_rad(9.0)
const RUN_DEPTH := 4.0
const MAX_RANGE := 12000.0              # fuel at this speed
const SEEKER_ENABLE := 400.0            # safe run before the seeker switches on
const SEEK_RANGE := 900.0
const SEEK_HALF := deg_to_rad(20.0)
const WIRE_LENGTH := 15000.0            # longer than the run: it parts only if the boat manoeuvres hard

var run_depth := RUN_DEPTH
var seeker_on := false
var acquired: SurfaceShip
var sea_factor := 1.0                   # 1 calm .. 0.5 rough (shorter seeker reach)
var wire_ok := true
var events: Array = []                  # [[age_s, kind], ...] as telemetered
var closest := INF                      # developer diagnostics only
var closest_ship: SurfaceShip
var _seek_t := 0.0
var _rng := RandomNumberGenerator.new()

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
	_rng.randomize()


func _event(kind: String) -> void:
	events.append([_age, kind])
	if wire_ok:
		telemetry.emit(kind)


## The wire parts (the boat manoeuvred hard, went deep, or ran it out).
func cut_wire() -> void:
	if wire_ok:
		wire_ok = false
		events.append([_age, "wire_cut"])
		telemetry.emit("wire_cut")


## The torpedo's own run, predicted (used by fire control for the lead):
## where it is when it passes closest to a point moving at `vel`.
static func predict(from: Transform3D, course: float, tgt: Vector3, vel: Vector3) -> Dictionary:
	var f := -from.basis.z
	var h := atan2(f.x, -f.z)
	var p := Vector3(from.origin.x, 0.0, from.origin.z)
	var sp := 7.0
	var age := 0.0
	var run := 0.0
	var dt := 0.25
	var best := INF
	var best_t := 0.0
	var best_p := p
	while run < MAX_RANGE:
		age += dt
		sp = move_toward(sp, RUN_SPEED if age > 0.8 else 9.0, dt * 9.0)
		if age > 0.6:
			h += clampf(wrapf(course - h, -PI, PI), -TURN_RATE * dt, TURN_RATE * dt)
		p += Vector3(sin(h), 0.0, -cos(h)) * sp * dt
		run += sp * dt
		var tp := tgt + vel * age
		var d := Vector2(tp.x - p.x, tp.z - p.z).length()
		if d < best:
			best = d
			best_t = age
			best_p = p
		elif d > best + 200.0:
			break
	return {"t": best_t, "pos": best_p, "miss": best, "in_reach": run < MAX_RANGE or best < 200.0, "run": run}


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, -cos(heading))


func advance(dt: float) -> void:
	if done:
		return
	_age += dt
	# Ejection, then the motor spins up.
	var want := RUN_SPEED if _age > 0.8 else 9.0
	speed = move_toward(speed, want, dt * 9.0)
	_seek(dt)
	if _age > 0.6:
		heading += clampf(wrapf(ordered_heading - heading, -PI, PI), -TURN_RATE * dt, TURN_RATE * dt)
	depth = move_toward(depth, run_depth, dt * 1.6)
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
	for t2 in targets:
		var sh := t2 as SurfaceShip
		if sh and sh.is_afloat():
			var dd := global_position.distance_to(sh.global_position)
			if dd < closest:
				closest = dd
				closest_ship = sh
	if wire_ok and travelled > WIRE_LENGTH:
		cut_wire()
	var dir := forward()
	global_transform.basis = Basis.looking_at(Vector3(dir.x, (depth - RUN_DEPTH) * -0.05, dir.z).normalized(), Vector3.UP)
	_prop.rotation.z += dt * speed * 3.0
	if travelled > MAX_RANGE:
		done = true
		_bubbles.emitting = false
		_event("run_complete")
		ran_out.emit()


## The seeker: switches on after the safe run; looks for a ship in its cone
## and reach (shorter in a heavy sea); homes on what it acquires; may lose it.
func _seek(dt: float) -> void:
	if not seeker_on:
		if travelled > SEEKER_ENABLE:
			seeker_on = true
			_event("seeker_on")
		return
	var reach := SEEK_RANGE * sea_factor
	if acquired:
		if not acquired.is_afloat():
			acquired = null
			return
		var rel := acquired.global_position - global_position
		var off := absf(wrapf(atan2(rel.x, -rel.z) - heading, -PI, PI))
		if Vector2(rel.x, rel.z).length() > reach * 1.6 or off > SEEK_HALF * 1.8:
			acquired = null
			_event("lost")
			return
		# Home with a little lead.
		var lead_t := Vector2(rel.x, rel.z).length() / maxf(speed, 1.0) * 0.6
		var aim := acquired.global_position + acquired.forward() * acquired.speed * lead_t
		ordered_heading = atan2(aim.x - global_position.x, -(aim.z - global_position.z))
		return
	_seek_t += dt
	if _seek_t < 1.0:
		return
	_seek_t = 0.0
	for t in targets:
		var ship := t as SurfaceShip
		if ship == null or not ship.is_afloat() or ship.submerged:
			continue
		var rel2 := ship.global_position - global_position
		var dist := Vector2(rel2.x, rel2.z).length()
		var off2 := absf(wrapf(atan2(rel2.x, -rel2.z) - heading, -PI, PI))
		if dist < reach and off2 < SEEK_HALF and _rng.randf() < 0.4 + 0.35 * sea_factor:
			acquired = ship
			_event("acquired")
			return


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
