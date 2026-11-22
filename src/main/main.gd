extends Node3D
## Silent Sea — Prototype 002 "First Contact" (built on Visual Prototype 001).
## Builds the scene, owns view switching and controls. Apart from the simple
## torpedo engagement, everything is staged or cosmetic.

enum View { CINEMATIC, EXTERIOR, PERISCOPE, COMMAND_ROOM, SONAR, TORPEDO_CAM }

const VIEW_NAMES := ["CINEMATIC", "EXTERIOR", "PERISCOPE", "CONTROL ROOM", "SONAR / TACTICAL", "TORPEDO CAM"]
const TIME_LEVELS := [1.0, 2.0, 4.0, 8.0]

var weather: Weather
var ocean: Ocean
var sub: Submarine
var rig: CameraRig
var wake_map: WakeMap
var ships: Array[Node3D] = []
var hud: Hud
var periscope_ui: PeriscopeOverlay
var sonar_ui: SonarConsole
var room: CommandRoom
var audio: AudioManager
var encounter: Encounter
var conn: ConnPanel
var _time_level := 0

var view := View.CINEMATIC
var _sub_trail: WakeTrail
var _mast_trail: WakeTrail
var _ship_trails: Array[WakeTrail] = []
var _focus := Node3D.new()
var _capture: Array = []
var _capture_frames := 0
var _capture_dir := ""
var _capture_index := 0
var _lens: ColorRect
var _lens_mat: ShaderMaterial
var _snow: GPUParticles3D
var _lens_rain := 0.0
var _time := 0.0
var _performance := false


func _ready() -> void:
	randomize()
	_focus.name = "ViewFocus"
	add_child(_focus)

	ocean = Ocean.new()
	ocean.name = "Ocean"
	add_child(ocean)

	weather = Weather.new()
	weather.name = "Weather"
	weather.ocean = ocean
	add_child(weather)

	sub = Submarine.new()
	sub.name = "Varg"
	sub.ocean = ocean
	add_child(sub)
	sub.heading = deg_to_rad(28.0)
	ocean.register_material(sub.hull_material())

	_spawn_ships()

	wake_map = WakeMap.new()
	wake_map.name = "WakeMap"
	wake_map.ocean = ocean
	wake_map.follow = _focus
	add_child(wake_map)
	_sub_trail = WakeTrail.new()
	_sub_trail.source = sub
	_sub_trail.beam = 7.6
	_sub_trail.length_ahead = 36.0
	wake_map.add_trail(_sub_trail)
	_mast_trail = WakeTrail.new()
	_mast_trail.beam = 0.8
	_mast_trail.length_ahead = 0.5
	_mast_trail.intensity = 0.7
	_mast_trail.spacing = 3.0
	wake_map.add_trail(_mast_trail)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.sub = sub
	rig.ocean = ocean
	add_child(rig)

	ocean.follow = rig.camera
	weather.follow = rig.camera

	room = CommandRoom.new()
	room.name = "CommandRoom"
	room.sub = sub
	room.weather = weather
	add_child(room)

	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	weather.lightning_struck.connect(audio.thunder)
	sub.vents_opened.connect(audio.vents)
	sub.breached.connect(_on_breach)
	sub.surfacing.connect(func() -> void: audio.play("submarine_surface", -2.0, 1.0, true))
	sub.periscope_moved.connect(_on_periscope_moved)

	encounter = Encounter.new()
	encounter.name = "Encounter"
	encounter.sub = sub
	encounter.rig = rig
	encounter.ocean = ocean
	encounter.audio = audio
	encounter.wake_map = wake_map
	encounter.ships = ships
	add_child(encounter)
	encounter.setup(self, ships[0] as SurfaceShip)
	encounter.reset_target()

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_lens = ColorRect.new()
	_lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = load("res://src/fx/lens_fx.gdshader")
	_lens.material = _lens_mat
	ui.add_child(_lens)
	_snow = _make_marine_snow()
	add_child(_snow)
	# The mast-camera post effect sits directly on the UI layer (below the sight).
	var scope_post := ColorRect.new()
	scope_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(scope_post)
	periscope_ui = PeriscopeOverlay.new()
	periscope_ui.post_rect = scope_post
	periscope_ui.sub = sub
	periscope_ui.rig = rig
	periscope_ui.ocean = ocean
	periscope_ui.ships = ships
	periscope_ui.weather = weather
	ui.add_child(periscope_ui)
	sonar_ui = SonarConsole.new()
	sonar_ui.sub = sub
	sonar_ui.ships = ships
	ui.add_child(sonar_ui)
	hud = Hud.new()
	hud.main = self
	ui.add_child(hud)
	conn = ConnPanel.new()
	conn.main = self
	conn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	conn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UiStyle.place(conn, Vector2(1, 1), Vector2(-280, -90), Vector2(250, 0))
	conn.command.connect(_on_command)
	ui.add_child(conn)
	encounter.message.connect(func(t: String) -> void: hud.event(t))
	encounter.torpedo_fired.connect(func(_t: Torpedo) -> void: periscope_ui.torpedo_away())
	encounter.target_hit.connect(_on_target_hit)
	periscope_ui.encounter = encounter

	room.setup_screens(rig, ocean, ships)
	room.station_selected.connect(_on_station_selected)

	_parse_args()
	if _capture.is_empty():
		weather.set_preset("golden", true)
		set_view(View.CINEMATIC)
		rig.set_shot(0)
		hud.play_title()
	weather.preset_changed.connect(func(l: String) -> void: hud.toast(l))
	sub.depth_mode_changed.connect(func(l: String) -> void: hud.toast("DIVING OFFICER:  " + l))
	sonar_ui.prefill.call_deferred()
	room.prefill_sonar.call_deferred()


func _on_station_selected(kind: String) -> void:
	if kind == "feed":
		set_view(View.PERISCOPE)
	elif kind == "sonar":
		set_view(View.SONAR)
	else:
		set_view(View.EXTERIOR)


func _on_breach(strength: float) -> void:
	rig.shake(strength)
	audio.splash(strength)
	# A ring of churned white water left on the surface.
	wake_map.add_foam_burst(sub.to_global(Vector3(0, 0, -20.0)), 90.0 * strength, 0.55, 35.0)


func _spawn_ships() -> void:
	var merchant := SurfaceShip.new()
	merchant.kind = SurfaceShip.Kind.MERCHANT
	merchant.ocean = ocean
	merchant.name = "Merchant"
	add_child(merchant)
	merchant.place(sub.position + Vector3(-1600.0, 0.0, -2300.0), deg_to_rad(95.0), 13.0)
	ships.append(merchant)
	var frigate := SurfaceShip.new()
	frigate.kind = SurfaceShip.Kind.FRIGATE
	frigate.ocean = ocean
	frigate.name = "Frigate"
	add_child(frigate)
	frigate.place(sub.position + Vector3(5200.0, 0.0, -3600.0), deg_to_rad(250.0), 16.0)
	ships.append(frigate)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.25)
	ocean.advance(dt)
	sub.advance(dt)
	encounter.advance(dt, view == View.PERISCOPE)
	var night := float(weather.current.get("nav_lights", 0.0)) > 0.5
	for s in ships:
		(s as SurfaceShip).advance(dt, sub.position)
		(s as SurfaceShip).set_night(night)
	rig.sun_dir = weather.to_sun()
	rig.advance(dt)
	_update_focus()
	_update_wakes(dt)
	wake_map.advance()
	_update_underwater()
	room.advance(dt)
	audio.update_state(view, sub, weather, _camera_depth())
	if not _capture.is_empty():
		_capture_step()


func _update_focus() -> void:
	match view:
		View.COMMAND_ROOM, View.SONAR:
			_focus.global_position = sub.global_position
			ocean.follow = sub
			weather.follow = sub
		_:
			_focus.global_position = rig.camera.global_position.lerp(sub.global_position, 0.5) if view != View.PERISCOPE else rig.camera.global_position
			ocean.follow = rig.camera
			weather.follow = rig.camera


func _update_wakes(dt: float) -> void:
	var surf := clampf(1.0 - (sub.depth - 2.05) / 5.0, 0.0, 1.0)
	_sub_trail.advance(dt, sub.speed, surf)
	var mast_surface := 0.0
	if sub.depth > 4.0 and sub.mast_extension() > 0.5:
		var head := sub.mast_head()
		mast_surface = clampf(head.y + 1.5, 0.0, 1.0) * clampf(1.0 - (sub.depth - 12.0) / 4.0, 0.0, 1.0)
	_mast_trail.source = sub.get_node("Body/Mast_photonics") as Node3D
	_mast_trail.advance(dt, sub.speed, mast_surface)
	for i in ships.size():
		var s := ships[i] as SurfaceShip
		if i >= _ship_trails.size():
			var t := WakeTrail.new()
			t.source = s
			t.beam = s.beam
			t.length_ahead = s.length * 0.5
			t.spacing = 10.0
			t.intensity = 1.0
			wake_map.add_trail(t)
			_ship_trails.append(t)
		_ship_trails[i].advance(dt, s.speed, 1.0)


func _camera_depth() -> float:
	if view == View.COMMAND_ROOM or view == View.SONAR:
		return sub.depth
	var cp := rig.camera.global_position
	return ocean.height_at(cp.x, cp.z) - cp.y


func _update_underwater() -> void:
	var d := _camera_depth()
	var below := d > 0.05 and view != View.COMMAND_ROOM and view != View.SONAR
	weather.set_underwater(below, maxf(d, 0.0))
	periscope_ui.mast_submerged = d
	# Lens effects for the exterior cameras only.
	var outside := view == View.EXTERIOR or view == View.CINEMATIC
	_time += get_process_delta_time()
	var want_rain := float(weather.current.get("rain", 0.0)) if (outside and not below) else 0.0
	_lens_rain = move_toward(_lens_rain, want_rain, get_process_delta_time() * (0.15 if want_rain > _lens_rain else 0.5))
	_lens.visible = outside
	_lens_mat.set_shader_parameter("rain", _lens_rain)
	_lens_mat.set_shader_parameter("underwater", 1.0 if below else 0.0)
	_lens_mat.set_shader_parameter("time", _time)
	_lens_mat.set_shader_parameter("resolution", get_viewport().get_visible_rect().size)
	_snow.emitting = below
	if below:
		_snow.global_position = rig.camera.global_position
		(_snow.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("light_level", 0.25 + float(weather.current.get("light_level", 1.0)) * 0.6)


## F9: a lighter path for weaker GPUs (no MSAA / SSAO, FSR upscaling, shorter shadows).
func _apply_quality() -> void:
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED if _performance else Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _performance else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if _performance else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.75 if _performance else 1.0
	weather.env.ssao_enabled = not _performance
	weather.sun.directional_shadow_max_distance = 220.0 if _performance else 450.0


func _make_marine_snow() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "MarineSnow"
	p.amount = 2500
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 14, 22)
	pm.direction = Vector3(0.2, -0.3, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, -0.04, 0)
	pm.scale_min = 0.03
	pm.scale_max = 0.11
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/soft_particle.gdshader")
	mat.set_shader_parameter("tint", Color(0.75, 0.9, 0.9, 0.55))
	q.material = mat
	p.draw_pass_1 = q
	p.emitting = false
	return p


func set_view(v: View) -> void:
	view = v
	periscope_ui.visible = v == View.PERISCOPE
	sonar_ui.visible = v == View.SONAR
	conn.visible = v == View.EXTERIOR or v == View.PERISCOPE or v == View.TORPEDO_CAM
	room.set_active(v == View.COMMAND_ROOM)
	get_viewport().disable_3d = v == View.SONAR
	RenderingServer.global_shader_parameter_set("thermal_mode", 0.0)
	match v:
		View.CINEMATIC:
			rig.set_mode(CameraRig.Mode.CINEMATIC)
			rig.camera.make_current()
		View.EXTERIOR:
			rig.set_mode(CameraRig.Mode.ORBIT)
			rig.camera.make_current()
		View.PERISCOPE:
			rig.set_mode(CameraRig.Mode.PERISCOPE)
			rig.camera.make_current()
			periscope_ui.on_enter()
		View.COMMAND_ROOM:
			rig.set_mode(CameraRig.Mode.FIXED)
			room.camera.make_current()
		View.SONAR:
			rig.set_mode(CameraRig.Mode.FIXED)
		View.TORPEDO_CAM:
			rig.camera.make_current()
			var t := encounter.torpedo_running()
			if t:
				rig.follow_target = t
				rig.set_mode(CameraRig.Mode.FOLLOW)
			elif encounter.target.is_sinking():
				rig.watch_target = encounter.target
				rig.set_mode(CameraRig.Mode.WATCH)
			else:
				hud.toast("NO TORPEDO RUNNING  ·  FIRE FROM THE PERISCOPE FIRST")
				view = View.EXTERIOR
				rig.set_mode(CameraRig.Mode.ORBIT)
				conn.visible = true
				v = View.EXTERIOR
	if hud:
		hud.set_view_name(VIEW_NAMES[v])


func _unhandled_input(event: InputEvent) -> void:
	if view == View.PERISCOPE and periscope_ui.handle_input(event):
		return
	if view == View.SONAR and sonar_ui.handle_input(event):
		return
	if view == View.COMMAND_ROOM and room.handle_input(event):
		return
	if rig.handle_input(event):
		if view == View.CINEMATIC and (event is InputEventMouseButton):
			set_view(View.EXTERIOR)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_1:
			set_view(View.CINEMATIC)
		KEY_2:
			set_view(View.EXTERIOR)
		KEY_3:
			set_view(View.PERISCOPE)
		KEY_4:
			set_view(View.COMMAND_ROOM)
		KEY_5:
			set_view(View.SONAR)
		KEY_6:
			_on_command("torpedo_cam")
		KEY_TAB:
			set_view(((view + 1) % VIEW_NAMES.size()) as View)
		KEY_F1:
			weather.set_preset("dawn")
		KEY_F2:
			weather.set_preset("clear")
		KEY_F3:
			weather.set_preset("golden")
		KEY_F4:
			weather.set_preset("storm")
		KEY_F5:
			weather.set_preset("night")
		KEY_N:
			_on_command("new_target")
		KEY_O:
			_on_command("surface")
		KEY_P:
			_on_command("periscope_depth")
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_BRACKETRIGHT:
			_set_time_level(_time_level + 1)
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_BRACKETLEFT:
			_set_time_level(_time_level - 1)
		KEY_W, KEY_UP:
			sub.set_speed_step(sub.speed_step + 1)
			hud.toast("HELM:  " + sub.speed_label())
		KEY_S, KEY_DOWN:
			sub.set_speed_step(sub.speed_step - 1)
			hud.toast("HELM:  " + sub.speed_label())
		KEY_Z, KEY_PAGEDOWN:
			_on_command("dive")
		KEY_X, KEY_PAGEUP:
			sub.set_depth_mode(sub.depth_mode - 1)
		KEY_B:
			if sub.emergency_blow():
				if view != View.EXTERIOR and view != View.CINEMATIC:
					set_view(View.EXTERIOR)
				if view == View.EXTERIOR:
					rig.yaw = PI * 0.62
					rig.pitch = 0.04
					rig.distance = 150.0
			else:
				hud.toast("EMERGENCY BLOW NEEDS DEPTH  —  DIVE FIRST (Z)")
		KEY_M:
			_on_command("scope")
		KEY_SPACE:
			if view == View.CINEMATIC:
				rig.next_shot()
			else:
				_on_command("fire")
		KEY_H:
			hud.toggle_help()
		KEY_U:
			hud.visible = not hud.visible
		KEY_F9:
			_performance = not _performance
			_apply_quality()
			hud.toast("GRAPHICS:  " + ("PERFORMANCE" if _performance else "HIGH QUALITY"))
		KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
		KEY_ESCAPE:
			hud.toggle_pause()
		_:
			if view == View.CINEMATIC:
				set_view(View.EXTERIOR)


func _on_periscope_moved(up: bool) -> void:
	audio.play("periscope_raise" if up else "periscope_lower", -3.0)
	hud.toast("PERISCOPE  " + ("RAISING" if up else "LOWERING"))


## Shared by keyboard shortcuts and the on-screen conn buttons.
func _on_command(cmd: String) -> void:
	match cmd:
		"surface":
			sub.set_depth_mode(0)
		"periscope_depth":
			sub.set_depth_mode(1)
		"dive":
			sub.set_depth_mode(sub.depth_mode + 1)
		"scope":
			if not sub.masts_up and sub.depth > 25.0:
				hud.toast("TOO DEEP TO RAISE THE PERISCOPE  ·  COME TO PERISCOPE DEPTH (P)")
			else:
				sub.set_periscope(not sub.masts_up)
		"view_scope":
			set_view(View.EXTERIOR if view == View.PERISCOPE else View.PERISCOPE)
		"fire":
			if view != View.PERISCOPE:
				hud.toast("FIRE FROM THE PERISCOPE VIEW  (3)")
			elif sub.periscope_state() != Submarine.Scope.CLEAR:
				hud.toast("PERISCOPE NOT CLEAR OF THE WATER  ·  RAISE IT (M) AT PERISCOPE DEPTH (P)")
			else:
				encounter.fire()
		"torpedo_cam":
			set_view(View.TORPEDO_CAM)
		"new_target":
			encounter.reset_target()
			if view == View.TORPEDO_CAM:
				set_view(View.EXTERIOR)
	if cmd != "fire":
		audio.play("ui_click", -14.0)


func _on_target_hit(ship: SurfaceShip) -> void:
	_set_time_level(0)
	if view == View.TORPEDO_CAM:
		rig.watch_target = ship
		rig.set_mode(CameraRig.Mode.WATCH)


func _set_time_level(level: int) -> void:
	var before := _time_level
	_time_level = clampi(level, 0, TIME_LEVELS.size() - 1)
	Engine.time_scale = float(TIME_LEVELS[_time_level])
	if _time_level != before:
		hud.toast("TIME  × %d" % int(Engine.time_scale))


func _physics_process(_delta: float) -> void:
	var r := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		r -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		r += 1.0
	sub.rudder = move_toward(sub.rudder, r, 0.02)


# --- Screenshot capture (development aid): -- --capture=dir --shots=preset:view:shot:frames,...
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_capture_dir = a.substr(10)
		elif a.begins_with("--shots="):
			for spec in a.substr(8).split(","):
				_capture.append(spec.split(":"))
	if not _capture.is_empty():
		hud.visible = true
		_begin_shot()


func _begin_shot() -> void:
	var spec: PackedStringArray = _capture[0]
	if spec[0] == "cont":
		# Keep the running scenario; optionally switch view, then wait.
		if spec.size() > 2:
			set_view(int(spec[2]) as View)
		_capture_frames = int(spec[1])
		return
	weather.set_preset(spec[0], true)
	var v := int(spec[1])
	if spec.size() > 4:
		sub.set_depth_mode(int(spec[4]))
		sub.depth = float(Submarine.DEPTH_MODES[int(spec[4])]["depth"])
	var tokens: PackedStringArray = spec[5].split("+") if spec.size() > 5 else PackedStringArray()
	if "blow" in tokens:
		sub.emergency_blow()
	if "near" in tokens:
		var brg := sub.heading - deg_to_rad(30.0)
		encounter.target.reset_to(sub.global_position + Vector3(sin(brg), 0.0, -cos(brg)) * 700.0, sub.heading + deg_to_rad(90.0), 8.0)
	if "scope" in tokens:
		sub.set_periscope(true)
		for _i in 40:
			sub.advance(0.1)
	if "lower" in tokens:
		sub.set_periscope(false)
		for _i in 40:
			sub.advance(0.1)
	set_view(v as View)
	if v == View.CINEMATIC:
		rig.set_cuts_enabled(false)
		rig.set_shot(int(spec[2]))
	elif v == View.EXTERIOR:
		rig.yaw = float(spec[2])
		rig.pitch = 0.1
	elif v == View.PERISCOPE:
		var target := ships[int(spec[2]) % 10 % ships.size()].global_position - sub.global_position
		rig.bearing = atan2(target.x, -target.z)
		rig.zoom_index = 2
		periscope_ui.call("_set_mode", int(spec[2]) / 10)
	if "fire" in tokens:
		var rel := encounter.target.global_position - sub.global_position
		rig.bearing = atan2(rel.x, -rel.z)
		encounter.locked = encounter.target
		encounter.solution = 1.0
		encounter.fire()
	_capture_frames = int(spec[3]) if spec.size() > 3 else 30


func _capture_step() -> void:
	_capture_frames -= 1
	if _capture_frames > 0:
		return
	var spec: PackedStringArray = _capture.pop_front()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_capture_index += 1
	var path := "%s/%02d_%s.png" % [_capture_dir, _capture_index, "_".join(spec)]
	img.save_png(path)
	print("CAPTURED ", path)
	if _capture.is_empty():
		get_tree().quit()
	else:
		_begin_shot()
