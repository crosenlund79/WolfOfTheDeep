class_name CameraRig
extends Node3D
## One main camera with three behaviours: a free orbit around the boat, an
## automatic cinematic director, and the optronic mast (periscope) view.

enum Mode { ORBIT, CINEMATIC, PERISCOPE, FIXED, FOLLOW, WATCH }

signal shot_changed(shot_name: String)

var mode := Mode.CINEMATIC
var camera: Camera3D
var sub: Submarine
var ocean: Ocean

# Orbit
var yaw := 2.35
var pitch := 0.12
var distance := 120.0
var _yaw_s := 2.35
var _pitch_s := 0.12
var _dist_s := 120.0
var _dragging := false

# Periscope
var bearing := 0.0
var mouse_sensitivity := 1.0
var elevation := 0.0
var zoom_levels := [42.0, 18.0, 8.0, 3.6, 1.6]
var zoom_index := 1
var _fov_s := 42.0

# Cinematic
var _shot := 0
var _shot_t := 0.0
var _shot_len := 13.0
var _shake := 0.0
var _seed := 0.0
var _cuts_enabled := true

const SHOTS := ["wide_establish", "sail_close", "waterline_track", "high_orbit", "bow_on_low", "underwater_pass", "stern_quarter"]

var sun_dir := Vector3(0.0, 0.3, -1.0)

var _attrs: CameraAttributesPractical


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "MainCamera"
	camera.near = 0.15
	camera.far = 40000.0
	camera.fov = 52.0
	camera.cull_mask = 0xFFFFF & ~WakeTrail.LAYER & ~(1 << 1)
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	camera.attributes = _attrs
	add_child(camera)
	camera.make_current()


var follow_target: Node3D
var watch_target: Node3D
var _scope_init := false
var _watch_t := 0.0
var _watch_angle := 0.0
var _follow_pos := Vector3.ZERO


## Which side of the sea surface the exterior camera keeps to. It crosses
## only deliberately: by orbiting well through the surface, or with V.
var below_surface := false
const SURFACE_BAND := 4.0


## V in the exterior view: take the camera to the other side of the surface.
func toggle_surface_side() -> void:
	below_surface = not below_surface
	if not below_surface and sub and sub.depth > 6.0:
		# Above the surface with the boat deep: look down at where she is.
		pitch = maxf(pitch, 0.35)
	elif below_surface:
		pitch = minf(pitch, 0.15)


func set_mode(m: Mode) -> void:
	if m != Mode.PERISCOPE and _dragging and mode == Mode.PERISCOPE:
		_dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mode = m
	if m == Mode.PERISCOPE:
		# The scope keeps its last bearing between visits.
		if not _scope_init:
			bearing = sub.heading if sub else 0.0
			_scope_init = true
		elevation = 0.0
		_fov_s = float(zoom_levels[zoom_index])
	elif m == Mode.FOLLOW and follow_target:
		_follow_pos = follow_target.global_position - (-follow_target.global_transform.basis.z) * 12.0 + Vector3.UP * 2.0
	elif m == Mode.WATCH and watch_target:
		_watch_t = 0.0
		var rel := camera.global_position - watch_target.global_position
		_watch_angle = atan2(rel.x, rel.z)
	elif m == Mode.CINEMATIC:
		_shot_t = 0.0
		shot_changed.emit(String(SHOTS[_shot]))
	elif m == Mode.ORBIT:
		_dist_s = distance
		# Start on the boat's side of the surface.
		below_surface = sub != null and sub.depth > 12.0
	_attrs.dof_blur_far_enabled = false


func next_shot() -> void:
	_shot = (_shot + 1) % SHOTS.size()
	if SHOTS[_shot] == "underwater_pass" and sub and sub.depth > 60.0:
		_shot = (_shot + 1) % SHOTS.size()
	_shot_t = 0.0
	_seed = randf() * 100.0
	shot_changed.emit(String(SHOTS[_shot]))


func set_shot(index: int) -> void:
	_shot = posmod(index, SHOTS.size())
	_shot_t = 0.0
	shot_changed.emit(String(SHOTS[_shot]))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _shake_offset(dt: float) -> Vector3:
	_shake = maxf(_shake - dt * 0.6, 0.0)
	if _shake <= 0.0:
		return Vector3.ZERO
	var t := Time.get_ticks_msec() * 0.001
	return Vector3(sin(t * 37.0), sin(t * 29.0 + 1.0), sin(t * 41.0 + 2.0)) * _shake * _shake * 0.6


func set_cuts_enabled(v: bool) -> void:
	_cuts_enabled = v


func shot_progress() -> float:
	return _shot_t / _shot_len


func handle_input(event: InputEvent) -> bool:
	if mode == Mode.ORBIT:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
				_dragging = mb.pressed
				return true
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(distance * 0.88, 14.0)
				return true
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(distance * 1.14, 1400.0)
				return true
		if event is InputEventMouseMotion and _dragging:
			var mm := event as InputEventMouseMotion
			yaw -= mm.relative.x * 0.005 * mouse_sensitivity
			pitch = clampf(pitch + mm.relative.y * 0.004 * mouse_sensitivity, -0.75, 1.35)
			return true
	elif mode == Mode.PERISCOPE:
		if event is InputEventMouseMotion and _dragging:
			var mm2 := event as InputEventMouseMotion
			var k := camera.fov / 60.0 * mouse_sensitivity
			# The scope trains through 360° and beyond in either direction; the
			# bearing is kept in 0..2π only to stay numerically tidy.
			bearing = fposmod(bearing + mm2.relative.x * 0.0035 * k, TAU)
			elevation = clampf(elevation - mm2.relative.y * 0.0035 * k, -0.25, 0.5)
			return true
		if event is InputEventMouseButton:
			var mb2 := event as InputEventMouseButton
			if mb2.button_index == MOUSE_BUTTON_LEFT or mb2.button_index == MOUSE_BUTTON_RIGHT:
				_dragging = mb2.pressed
				# Capture the pointer while training so the screen edge never
				# stops the rotation.
				if DisplayServer.get_name() != "headless":
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb2.pressed else Input.MOUSE_MODE_VISIBLE
				return true
			if mb2.pressed and mb2.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_index = mini(zoom_index + 1, zoom_levels.size() - 1)
				return true
			if mb2.pressed and mb2.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_index = maxi(zoom_index - 1, 0)
				return true
	return false


func advance(dt: float) -> void:
	if sub == null:
		return
	match mode:
		Mode.ORBIT:
			_orbit(dt)
		Mode.CINEMATIC:
			_cinematic(dt)
		Mode.PERISCOPE:
			_periscope(dt)
		Mode.FOLLOW:
			_follow(dt)
		Mode.WATCH:
			_watch(dt)
		_:
			pass


func _orbit(dt: float) -> void:
	var k := 1.0 - exp(-dt * 6.0)
	_yaw_s = lerp_angle(_yaw_s, yaw, k)
	_pitch_s = lerpf(_pitch_s, pitch, k)
	_dist_s = lerpf(_dist_s, distance, 1.0 - exp(-dt * 4.0))
	var target := sub.global_position + Vector3(0, 4.0, 0)
	var off := Vector3(cos(_pitch_s) * sin(_yaw_s + sub.heading), sin(_pitch_s), cos(_pitch_s) * cos(_yaw_s + sub.heading)) * _dist_s
	var pos := target + off
	# The surface is a boundary: the camera keeps to its side and only crosses
	# when the orbit takes it clearly through (or on V). Near the surface it
	# hugs its own side of the waves, so it never flickers between the two.
	if ocean:
		var h := ocean.height_at(pos.x, pos.z)
		if below_surface and pos.y > h + SURFACE_BAND:
			below_surface = false
		elif not below_surface and pos.y < h - SURFACE_BAND:
			below_surface = true
		if below_surface:
			pos.y = minf(pos.y, h - 1.5)
		else:
			pos.y = maxf(pos.y, h + 1.2)
	pos += _shake_offset(dt)
	camera.global_transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)
	camera.fov = lerpf(camera.fov, 52.0, k)


func _follow(dt: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	var f := -follow_target.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var right := Vector3(-f.z, 0.0, f.x)
	var want := follow_target.global_position - f * 11.0 + Vector3.UP * 1.8 + right * 1.6
	_follow_pos = _follow_pos.lerp(want, 1.0 - exp(-dt * 4.0))
	var look := follow_target.global_position + f * 25.0
	camera.global_transform = Transform3D(Basis.looking_at(look - _follow_pos, Vector3.UP), _follow_pos + _shake_offset(dt))
	camera.fov = lerpf(camera.fov, 64.0, 1.0 - exp(-dt * 3.0))


## Slow, low orbit around a stricken ship.
func _watch(dt: float) -> void:
	if watch_target == null or not is_instance_valid(watch_target):
		return
	_watch_t += dt
	var ship := watch_target as SurfaceShip
	var r := (ship.length * 1.9 if ship else 320.0) + _watch_t * 1.5
	var a := _watch_angle + _watch_t * 0.035
	var centre := watch_target.global_position
	centre.y = 0.0
	var pos := centre + Vector3(sin(a), 0.0, cos(a)) * r
	pos.y = (ocean.height_at(pos.x, pos.z) if ocean else 0.0) + 9.0
	var look := centre + Vector3.UP * 10.0
	camera.global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos + _shake_offset(dt))
	camera.fov = lerpf(camera.fov, 40.0, 1.0 - exp(-dt * 2.0))


func _periscope(dt: float) -> void:
	# Q / E train the scope continuously.
	var train := 0.0
	if Input.is_key_pressed(KEY_Q):
		train -= 1.0
	if Input.is_key_pressed(KEY_E):
		train += 1.0
	bearing = fposmod(bearing + train * dt * deg_to_rad(20.0) * (camera.fov / 42.0), TAU)
	var head := sub.mast_head()
	var target_fov := float(zoom_levels[zoom_index])
	_fov_s = lerpf(_fov_s, target_fov, 1.0 - exp(-dt * 7.0))
	camera.fov = _fov_s
	var dir := Vector3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation))
	# The mast sways with the boat.
	var sway := sub.global_transform.basis.get_euler()
	var b := Basis.looking_at(dir, Vector3.UP)
	b = b * Basis(Vector3.FORWARD, sway.z * 0.6)
	camera.global_transform = Transform3D(b, head)


func _cinematic(dt: float) -> void:
	_shot_t += dt
	if _cuts_enabled and _shot_t > _shot_len:
		next_shot()
	var u := clampf(_shot_t / _shot_len, 0.0, 1.0)
	var s := sub.global_position
	var fwd := sub.forward()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var up := Vector3.UP
	var pos := Vector3.ZERO
	var look := s
	var fov := 50.0
	var dof := false
	var dof_dist := 100.0
	match String(SHOTS[_shot]):
		"waterline_track":
			pos = s + fwd * lerpf(30.0, -10.0, u) + right * 24.0
			var sea := ocean.waves.significant_height if ocean else 1.0
			pos.y = (ocean.height_at(pos.x, pos.z) if ocean else 0.0) + 1.1 + sea * 0.45
			look = s + fwd * lerpf(-6.0, -24.0, u) + up * 3.0
			fov = 46.0
		"high_orbit":
			var a := lerpf(-0.9, 0.5, u) + _seed
			pos = s + Vector3(cos(a), 0.0, sin(a)) * 170.0 + up * lerpf(95.0, 60.0, u)
			look = s + up * 2.0
			fov = 40.0
		"bow_on_low":
			pos = s + fwd * lerpf(120.0, 70.0, u) + right * 9.0
			pos.y = (ocean.height_at(pos.x, pos.z) if ocean else 0.0) + 2.0
			look = s + fwd * 10.0 + up * 3.5
			fov = 30.0
		"sail_close":
			var a2 := lerpf(0.35, -0.35, u)
			pos = s + fwd * (-12.0) + (right * cos(a2) + fwd * sin(a2)) * 22.0 + up * (SubmarineBuilder.SAIL_TOP + 2.0 - sub.depth)
			look = s + fwd * 16.0 + up * (SubmarineBuilder.SAIL_TOP - sub.depth)
			fov = 38.0
		"underwater_pass":
			# Below and beside the hull, looking up at its silhouette against the surface.
			var depth_y := minf(s.y - 14.0, -16.0)
			pos = s + fwd * lerpf(45.0, -35.0, u) + right * 20.0
			pos.y = depth_y
			look = s + up * 6.0 + fwd * lerpf(14.0, -14.0, u)
			fov = 62.0
		"wide_establish":
			# Long lens from down-sun: the boat sits in the sun's glitter path.
			var away := -Vector3(sun_dir.x, 0.0, sun_dir.z).normalized()
			var side := Vector3(-away.z, 0.0, away.x)
			pos = s + away * 560.0 + side * lerpf(-60.0, 60.0, u)
			pos.y = (ocean.height_at(pos.x, pos.z) if ocean else 0.0) + 7.0
			look = s + up * 6.0
			fov = 18.0
		"stern_quarter":
			pos = s - fwd * lerpf(70.0, 95.0, u) + right * lerpf(-30.0, 26.0, u)
			pos.y = (ocean.height_at(pos.x, pos.z) if ocean else 0.0) + lerpf(3.0, 9.0, u)
			look = s + fwd * 8.0 + up * 3.0
			fov = 44.0
	# Hand-held drift.
	var t := Time.get_ticks_msec() * 0.001
	var drift := Vector3(sin(t * 0.7 + _seed), sin(t * 0.53 + 1.3) * 0.6, cos(t * 0.61)) * 0.35
	pos += drift + _shake_offset(dt)
	camera.global_transform = Transform3D(Basis.looking_at((look - pos).normalized(), Vector3.UP), pos)
	camera.fov = fov
	_attrs.dof_blur_far_enabled = dof
	_attrs.dof_blur_far_distance = dof_dist
	_attrs.dof_blur_far_transition = 120.0
	_attrs.dof_blur_amount = 0.06
