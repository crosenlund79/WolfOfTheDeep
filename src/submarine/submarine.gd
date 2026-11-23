class_name Submarine
extends Node3D
## Cosmetic submarine: rides the swell when surfaced, glides at depth, turns,
## dives, raises masts and shows navigation lights. Staged behaviour only.

signal depth_mode_changed(label: String)
signal vents_opened
signal surfacing
signal breached(strength: float)
signal periscope_moved(raising: bool)

enum Scope { HOUSED, MOVING, UNDERWATER, CLEAR }

const KNOT := 0.5144
const SPEED_STEPS := [0.0, 3.0, 6.0, 9.0, 13.0, 18.0]
const SPEED_NAMES := ["ALL STOP", "AHEAD 1/3", "AHEAD 2/3", "AHEAD STANDARD", "AHEAD FULL", "AHEAD FLANK"]
const DEPTH_MODES := [
	{"label": "SURFACED", "depth": 2.05},
	{"label": "PERISCOPE DEPTH", "depth": 10.6},
	{"label": "20 M", "depth": 20.0},
	{"label": "40 M", "depth": 40.0},
	{"label": "60 M", "depth": 60.0},
	{"label": "100 M", "depth": 100.0},
	{"label": "150 M", "depth": 150.0},
	{"label": "200 M  (SAFE LIMIT)", "depth": 200.0},
	{"label": "250 M  (BEYOND SAFE DEPTH)", "depth": 250.0},
	{"label": "300 M  (DANGEROUS)", "depth": 300.0},
	{"label": "350 M  (EXTREME)", "depth": 350.0},
]
## Normal operating limit. Below it the hull works harder; nothing stops the
## boat going deeper except physics.
const SAFE_DEPTH := 200.0
const TEST_DEPTH := 250.0
const COLLAPSE_DEPTH := 380.0
const CRUSH_DEPTH := COLLAPSE_DEPTH
const LAYER_DEPTH := 55.0

signal pd_reached
signal approaching_pd
signal damaged(amount: float, kind: String)
## Pressure events below the safe depth: kind = leak / equipment / frames / collapse.
signal pressure_event(kind: String, detail: String)

## Helm: the helmsman steers to the ordered course with a real rudder (it
## takes time to put over) and the boat's own inertia (the swing builds and
## must be checked). Full rudder turns her on about three boat lengths.
const RUDDER_MAX := 35.0             # degrees
const RUDDER_RATE := 6.0             # degrees per second
const HELM_RUDDER := 30.0            # the most the helmsman applies on his own
const TURN_RADIUS := 160.0           # metres at full rudder
const YAW_TAU := 4.0                 # seconds for the swing to build or die away
var ordered_heading := 0.0
var helm_auto := true
var rudder_order := 0.0              # degrees, + = right
var rudder_angle := 0.0              # degrees, + = right
var yaw_rate := 0.0                  # rad/s, + = turning right
## Electrical plant (percent) and air-independent propulsion fuel (hours).
var battery := 82.0
var aip_hours := 96.0
var snorkel_ordered := false
var diesels_running := false
var silent_running := false
## Hull state.
var hull := 100.0
## Condition of major equipment, 0 (failed) .. 1 (working).
var equipment := {"propulsion": 1.0, "sonar": 1.0, "masts": 1.0, "radio": 1.0, "hydraulics": 1.0, "ballast": 1.0, "tubes": 1.0}
## Accumulated structural fatigue from deep excursions (0..1); raises later risk.
var stress := 0.0
var torpedoes := 12
var invulnerable := false        # developer / testing only
var leak := 0.0
var flooding := 0.0
var transient := 0.0
var _pd_announced := false
var _approach_announced := false

var ocean: Ocean
var heading := 0.0
var speed := 9.0 * KNOT
var speed_step := 3
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
var _blow := false
var _recover := false
var _breach_spray: GPUParticles3D
var _slam_armed := false
var _cascade: GPUParticles3D
var _cascade_t := 0.0
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


## Emergency main ballast blow: a staged, spectacular bow-first breach.
func emergency_blow() -> bool:
	if depth < 18.0 or _blow or _recover:
		return false
	_blow = true
	depth_mode = 0
	_target_depth = float(DEPTH_MODES[0]["depth"])
	vents_opened.emit()
	depth_mode_changed.emit("EMERGENCY BLOW  —  ALL MAIN BALLAST")
	return true


func is_blowing() -> bool:
	return _blow or _recover


func set_depth_mode(mode: int) -> void:
	mode = clampi(mode, 0, DEPTH_MODES.size() - 1)
	if mode == depth_mode or _blow:
		return
	_pd_announced = false
	_approach_announced = false
	if depth_mode == 0 and mode > 0:
		vents_opened.emit()
		_vent_spray.restart()
		_vent_spray.emitting = true
	elif mode == 0 and depth > 3.0:
		surfacing.emit()
	# Masts are housed for a deep dive; raise them again at periscope depth.
	if mode >= 3 and masts_up:
		set_periscope(false)
	if mode != 1:
		snorkel_ordered = false
	depth_mode = mode
	_target_depth = float(DEPTH_MODES[mode]["depth"])
	depth_mode_changed.emit(String(DEPTH_MODES[mode]["label"]))


## Order an exact depth (metres). The depth mode follows for labels and crew.
func set_target_depth(d: float) -> void:
	if _blow:
		return
	d = maxf(d, 2.05)
	var best := 0
	for i in DEPTH_MODES.size():
		if float(DEPTH_MODES[i]["depth"]) <= d + 0.5:
			best = i
	if depth_mode == 0 and d > 3.0:
		vents_opened.emit()
	depth_mode = best
	_target_depth = d
	_pd_announced = false
	_approach_announced = false


func ordered_depth() -> float:
	return _target_depth


func set_periscope(up: bool) -> void:
	if up == masts_up:
		return
	masts_up = up
	periscope_moved.emit(up)


## What the optronic mast can see right now.
func periscope_state() -> Scope:
	if _mast_ext < 0.05:
		return Scope.HOUSED
	if _mast_ext < 0.97:
		return Scope.MOVING
	var head := mast_head()
	var sea := ocean.height_at(head.x, head.z) if ocean else 0.0
	return Scope.UNDERWATER if head.y < sea + 0.15 else Scope.CLEAR


## World transform of the bow torpedo tube (forward = -Z).
func tube_transform(tube: int) -> Transform3D:
	var side := -1.0 if tube % 2 == 0 else 1.0
	var local := Transform3D(Basis.IDENTITY, Vector3(side * 1.0, -1.7, -SubmarineBuilder.L * 0.5 + 6.0))
	return global_transform * local


## Helm state for the displays: rudder and whether a turn is under way.
func helm_text() -> String:
	var r := int(round(absf(rudder_angle)))
	var rud := "RUDDER MIDSHIPS" if r < 1 else "RUDDER %d° %s" % [r, "RIGHT" if rudder_angle > 0.0 else "LEFT"]
	var rate := rad_to_deg(yaw_rate)
	if absf(rate) < 0.05:
		return rud + "  ·  STEADY"
	return rud + "  ·  TURNING %s %.1f°/S" % ["RIGHT" if rate > 0.0 else "LEFT", absf(rate)]


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
	# The attitude springs are explicit; keep each step small for stability
	# under time compression.
	if dt > 0.2:
		var n := ceili(dt / 0.2)
		for _i in n:
			_advance_step(dt / float(n))
		return
	_advance_step(dt)


func _advance_step(dt: float) -> void:
	var target_speed := float(SPEED_STEPS[speed_step]) * KNOT
	if battery <= 0.5 and not diesels_running:
		target_speed = minf(target_speed, 4.0 * KNOT)
	if flooding > 0.6:
		target_speed = minf(target_speed, 5.0 * KNOT)
	speed = move_toward(speed, target_speed, dt * 0.09)
	if helm_auto:
		# The helmsman: rudder toward the ordered course, eased and then
		# reversed to meet her as she swings onto it.
		var err := rad_to_deg(wrapf(ordered_heading - heading, -PI, PI))
		rudder_order = clampf(err * 3.4 - rad_to_deg(yaw_rate) * 6.5, -HELM_RUDDER, HELM_RUDDER)
		if absf(err) < 0.25 and absf(rad_to_deg(yaw_rate)) < 0.05:
			rudder_order = 0.0
	rudder_angle = move_toward(rudder_angle, rudder_order, RUDDER_RATE * dt)
	rudder = rudder_angle / RUDDER_MAX
	_advance_plant(dt)
	_advance_pressure(dt)
	# Little steerage way at very low speed.
	var eff := smoothstep(0.4, 1.6, speed)
	var want_yaw := speed / TURN_RADIUS * rudder * eff
	yaw_rate += (want_yaw - yaw_rate) * clampf(dt / YAW_TAU, 0.0, 1.0)
	heading = wrapf(heading + yaw_rate * dt, -PI, PI)
	var fwd := forward()
	position += fwd * speed * dt

	# Depth change with a believable bow-down / bow-up angle.
	var dd := _target_depth - depth
	var max_rate := lerpf(1.3, 2.4, clampf(speed / 6.0, 0.0, 1.0))
	var want_rate := clampf(dd * 0.2, -max_rate, max_rate)
	var dive_pitch: float
	if _blow:
		# Accelerate upward hard, bow high.
		_depth_rate = move_toward(_depth_rate, -6.5, dt * 0.9)
		depth += _depth_rate * dt
		dive_pitch = clampf(-_depth_rate / 9.0, 0.0, 0.5)
		if depth < 5.0:
			_blow = false
			_recover = true
			_slam_armed = true
			_breach_spray.global_position = to_global(Vector3(0, 2.0, -24.0))
			_breach_spray.restart()
			_breach_spray.emitting = true
			_cascade_t = 5.0
			breached.emit(1.0)
	elif _recover:
		# Momentum carries the bow out of the water, then the boat falls back and settles.
		var acc := (_target_depth - depth) * 0.9 - _depth_rate * 0.9
		_depth_rate += acc * dt
		depth += _depth_rate * dt
		dive_pitch = clampf(-_depth_rate / 9.0, -0.12, 0.5)
		if _slam_armed and _depth_rate > 1.2:
			_slam_armed = false
			_breach_spray.global_position = to_global(Vector3(0, 0.5, -28.0))
			_breach_spray.restart()
			_breach_spray.emitting = true
			breached.emit(0.7)
		if absf(_target_depth - depth) < 0.25 and absf(_depth_rate) < 0.2:
			_recover = false
	else:
		_depth_rate = move_toward(_depth_rate, want_rate, dt * 0.45)
		depth += _depth_rate * dt
		dive_pitch = clampf(-_depth_rate / maxf(speed * 1.6, 2.5), -0.2, 0.2)

	# Wave response fades out with depth.
	var surf := clampf(1.0 - (depth - 2.05) / 7.0, 0.0, 1.0) * (0.0 if _recover else 1.0)
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
	var pk := 6.0 if (_blow or _recover) else 2.6
	_pitch_v += ((want_pitch * (0.3 if _recover else 1.0) + dive_pitch - _pitch) * pk - _pitch_v * 2.0) * dt
	_pitch += _pitch_v * dt
	_roll_v += ((want_roll - _roll) * 2.2 - _roll_v * 1.1) * dt
	_roll += _roll_v * dt

	# Flooding makes the boat heavy: she sinks below her ordered depth.
	if flooding > 0.25 and not is_surfaced():
		depth += flooding * flooding * 0.6 * dt
	# Depth reports for the officer of the watch.
	if depth_mode == 1:
		if not _approach_announced and depth > 13.0 and depth < 19.0 and _depth_rate < -0.1:
			_approach_announced = true
			approaching_pd.emit()
		if not _pd_announced and absf(depth - 10.6) < 0.6:
			_pd_announced = true
			pd_reached.emit()
	position.y = -depth + _heave
	basis = Basis(Vector3.UP, -heading) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)

	# Masts.
	var want_mast := 1.0 if masts_up and depth < 30.0 else 0.0
	_mast_ext = move_toward(_mast_ext, want_mast, dt * 0.45)
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

	_cascade_t = maxf(_cascade_t - dt, 0.0)
	_cascade.emitting = _cascade_t > 0.0
	_bubbles.emitting = depth > 6.0 and speed > 1.0
	_bubbles.amount_ratio = clampf(speed / 6.0, 0.2, 1.0)
	_bow_spray.emitting = is_surfaced() and speed > 2.0
	_bow_spray.amount_ratio = clampf(speed / 9.0, 0.1, 1.0)


func _advance_plant(dt: float) -> void:
	var kn := speed / KNOT
	var submerged := depth > 3.5
	var head_clear := depth < 12.5 and _mast_ext > 0.9 and masts_up
	diesels_running = (not submerged) or (snorkel_ordered and head_clear)
	# Percent per hour: hotel load plus propulsion, which rises steeply with speed.
	var drain := 0.6 + 0.09 * pow(kn, 2.2)
	var charge := 0.0
	if submerged and aip_hours > 0.0 and not diesels_running:
		charge += 4.5
		aip_hours = maxf(aip_hours - dt / 3600.0, 0.0)
	if diesels_running:
		charge += 28.0 if not submerged else 32.0
	battery = clampf(battery + (charge - drain) * dt / 3600.0, 0.0, 100.0)
	# Damage control slowly stems leaks; pumps clear flooding.
	if leak > 0.0:
		leak = maxf(leak - dt * 0.0016, 0.0)
	flooding = clampf(flooding + leak * dt * 0.004 - dt * 0.0009, 0.0, 1.0)
	transient = maxf(transient - dt * 0.2, 0.0)


## Depth at which the hull would fail now: lower with damage and fatigue.
func collapse_depth() -> float:
	return COLLAPSE_DEPTH * (0.6 + 0.4 * clampf(hull / 100.0, 0.0, 1.0)) * (1.0 - 0.22 * stress)


## 0 at the safe depth, 1 at the collapse depth (can exceed 1 briefly).
func pressure_load() -> float:
	if depth <= SAFE_DEPTH:
		return 0.0
	return (depth - SAFE_DEPTH) / maxf(collapse_depth() - SAFE_DEPTH, 1.0)


func _advance_pressure(dt: float) -> void:
	var x := pressure_load()
	if x <= 0.0 or hull <= 0.0:
		return
	# Fatigue builds with depth and time spent there.
	stress = minf(stress + x * x * 0.12 * dt / 3600.0, 1.0)
	if depth >= collapse_depth():
		if invulnerable:
			return
		hull = 0.0
		flooding = 1.0
		leak = 1.0
		pressure_event.emit("collapse", "")
		return
	# Failures: rare just below the safe depth, frequent near the limit, more
	# likely in a damaged hull.
	var rate := pow(x, 3.0) * 5.0 * (1.0 + (100.0 - hull) / 40.0) * (1.0 + stress)
	if randf() < rate * dt / 3600.0 and not invulnerable:
		var roll := randf()
		if roll < 0.45:
			leak = clampf(leak + randf_range(0.08, 0.3) * (0.5 + x), 0.0, 1.0)
			pressure_event.emit("leak", "A seawater joint is weeping aft under the pressure.")
		elif roll < 0.75:
			var keys := equipment.keys()
			var k: String = keys[randi() % keys.size()]
			equipment[k] = maxf(float(equipment[k]) - randf_range(0.2, 0.5), 0.0)
			pressure_event.emit("equipment", "%s took damage from the pressure." % k.capitalize())
		else:
			var d := randf_range(2.0, 7.0) * (0.5 + x)
			hull = maxf(hull - d, 0.0)
			pressure_event.emit("frames", "Frames groaning: hull integrity down to %d%%." % int(hull))


## Radiated noise (arbitrary dB-like scale) for other ships' sonar.
func noise_level() -> float:
	var kn := speed / KNOT
	var n := 98.0 + 17.0 * log(1.0 + kn) / log(10.0)
	if kn > cavitation_speed():
		n += 14.0
	if diesels_running:
		n += 22.0
	if silent_running:
		n -= 4.0
	return n + transient * 18.0


func cavitation_speed() -> float:
	return 7.0 + depth / 12.0


func save_state() -> Dictionary:
	return {
		"pos": SaveSystem.v3(position), "heading": heading, "ordered_heading": ordered_heading, "helm_auto": helm_auto,
		"rudder": rudder_angle, "rudder_order": rudder_order, "yaw_rate": yaw_rate,
		"speed": speed, "speed_step": speed_step, "depth": depth, "target_depth": _target_depth, "depth_mode": depth_mode,
		"masts_up": masts_up, "mast_ext": _mast_ext, "battery": battery, "aip_hours": aip_hours, "snorkel": snorkel_ordered,
		"silent": silent_running, "hull": hull, "leak": leak, "flooding": flooding, "nav_lights": nav_lights,
		"equipment": equipment.duplicate(), "stress": stress, "torpedoes": torpedoes,
	}


func load_state(d: Dictionary) -> void:
	position = SaveSystem.to_v3(d.get("pos"), position)
	heading = float(d.get("heading", heading))
	ordered_heading = float(d.get("ordered_heading", heading))
	helm_auto = bool(d.get("helm_auto", true))
	rudder_angle = float(d.get("rudder", 0.0))
	rudder_order = float(d.get("rudder_order", 0.0))
	yaw_rate = float(d.get("yaw_rate", 0.0))
	rudder = rudder_angle / RUDDER_MAX
	speed = float(d.get("speed", speed))
	speed_step = int(d.get("speed_step", speed_step))
	depth = float(d.get("depth", depth))
	depth_mode = int(d.get("depth_mode", depth_mode))
	_target_depth = float(d.get("target_depth", depth))
	masts_up = bool(d.get("masts_up", masts_up))
	_mast_ext = float(d.get("mast_ext", 1.0 if masts_up else 0.0))
	battery = float(d.get("battery", battery))
	aip_hours = float(d.get("aip_hours", aip_hours))
	snorkel_ordered = bool(d.get("snorkel", false))
	silent_running = bool(d.get("silent", false))
	hull = float(d.get("hull", hull))
	leak = float(d.get("leak", 0.0))
	flooding = float(d.get("flooding", 0.0))
	nav_lights = float(d.get("nav_lights", nav_lights))
	stress = float(d.get("stress", 0.0))
	torpedoes = int(d.get("torpedoes", torpedoes))
	var eq: Variant = d.get("equipment")
	if eq is Dictionary:
		for k in (eq as Dictionary).keys():
			equipment[k] = float(eq[k])
	_pd_announced = true
	_approach_announced = true
	position.y = -depth
	basis = Basis(Vector3.UP, -heading)


## Points along the hull for collision tests (world space).
func hull_points() -> Array:
	return [to_global(Vector3(0, -0.5, -34.0)), to_global(Vector3(0, 0, -14.0)), to_global(Vector3(0, 0, 8.0)), to_global(Vector3(0, -0.5, 30.0)), to_global(Vector3(0, 8.5, -15.0))]


## Resolve a collision reported by the world: push clear, stop, take damage.
func resolve_collision(info: Dictionary) -> float:
	var nrm: Vector3 = info["normal"]
	var vel := forward() * speed + Vector3(0.0, -_depth_rate, 0.0)
	var impact := maxf(-vel.dot(nrm), 0.0)
	if String(info.get("kind", "")) in ["seabed", "land"]:
		# Running onto the bottom: the hull ploughs in, even on a gentle slope.
		impact = maxf(impact, absf(speed) * 0.3)
	var push := float(info["depth"]) + 0.3
	if nrm.y < -0.5:
		# Ice overhead (pack ice): forced back down; the impact is the rate of rise.
		impact = maxf(-_depth_rate, 0.0)
		depth = depth + push
		_depth_rate = maxf(_depth_rate, 0.0)
		_target_depth = maxf(_target_depth, depth + 2.0)
	elif nrm.y > 0.5:
		var room := depth - 2.05
		depth = maxf(depth - push, 2.05)
		_depth_rate = minf(_depth_rate, 0.0)
		_target_depth = minf(_target_depth, depth)
		# Already as high as she can go: hard aground, pushed back off the slope.
		var hz := Vector3(nrm.x, 0.0, nrm.z)
		if push > room and hz.length() > 0.01:
			position += hz.normalized() * (push - room)
	else:
		position += Vector3(nrm.x, 0.0, nrm.z) * push
	var dmg := 0.0
	if invulnerable:
		impact = minf(impact, 0.3)
	if impact > 0.35:
		dmg = clampf(impact * impact * 3.2, 1.0, 45.0)
		hull = maxf(hull - dmg, 0.0)
		leak = clampf(leak + dmg / 60.0, 0.0, 1.0)
		speed = speed * 0.15
		set_speed_step(0)
		transient = 1.0
		damaged.emit(dmg, String(info["kind"]))
	elif impact > 0.05:
		hull = maxf(hull - 0.2, 0.0)
		speed *= 0.6
		damaged.emit(0.2, "scrape")
	return dmg


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
	# Breach: a huge burst of white water.
	_breach_spray = GPUParticles3D.new()
	_breach_spray.amount = 3800
	_breach_spray.lifetime = 4.5
	_breach_spray.one_shot = true
	_breach_spray.explosiveness = 0.85
	_breach_spray.emitting = false
	_breach_spray.local_coords = false
	_breach_spray.visibility_aabb = AABB(Vector3(-80, -20, -80), Vector3(160, 90, 160))
	var bp := ParticleProcessMaterial.new()
	bp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	bp.emission_box_extents = Vector3(6.0, 1.0, 16.0)
	bp.direction = Vector3(0, 1, 0)
	bp.spread = 55.0
	bp.initial_velocity_min = 4.0
	bp.initial_velocity_max = 17.0
	bp.gravity = Vector3(0, -9.8, 0)
	bp.damping_min = 0.4
	bp.damping_max = 1.2
	bp.scale_min = 0.5
	bp.scale_max = 2.6
	var bc := Curve.new()
	bc.add_point(Vector2(0.0, 0.9))
	bc.add_point(Vector2(0.5, 0.7))
	bc.add_point(Vector2(1.0, 0.0))
	var bct := CurveTexture.new()
	bct.curve = bc
	bp.alpha_curve = bct
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	bp.scale_curve = sct
	_breach_spray.process_material = bp
	_breach_spray.draw_pass_1 = _soft_quad(Vector2(1.8, 1.8), Color(0.93, 0.96, 0.98, 0.5))
	add_child(_breach_spray)
	# Sheets of water pouring off the casing after a breach.
	_cascade = GPUParticles3D.new()
	_cascade.amount = 1800
	_cascade.lifetime = 1.6
	_cascade.emitting = false
	_cascade.local_coords = false
	_cascade.position = Vector3(0, SubmarineBuilder.DECK_Y, -16.0)
	_cascade.visibility_aabb = AABB(Vector3(-40, -30, -60), Vector3(80, 60, 120))
	var cp := ParticleProcessMaterial.new()
	cp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	cp.emission_box_extents = Vector3(3.6, 0.6, 20.0)
	cp.direction = Vector3(0, -1, 0)
	cp.spread = 30.0
	cp.initial_velocity_min = 0.5
	cp.initial_velocity_max = 3.0
	cp.gravity = Vector3(0, -9.8, 0)
	cp.scale_min = 0.3
	cp.scale_max = 1.1
	cp.alpha_curve = bct
	_cascade.process_material = cp
	_cascade.draw_pass_1 = _soft_quad(Vector2(0.9, 0.9), Color(0.85, 0.92, 0.95, 0.45))
	_body.add_child(_cascade)

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
