extends Node3D
## Silent Sea — Visual Prototype 001.
## Builds the scene, owns view switching and keyboard controls. Everything is
## staged or cosmetic: there is no simulation model behind what you see.

enum View { CINEMATIC, EXTERIOR, PERISCOPE, COMMAND_ROOM, SONAR }

const VIEW_NAMES := ["CINEMATIC", "EXTERIOR", "OPTRONIC MAST", "CONTROL ROOM", "SONAR / TACTICAL"]

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
var audio: Ambience

var view := View.CINEMATIC
var _sub_trail: WakeTrail
var _mast_trail: WakeTrail
var _ship_trails: Array[WakeTrail] = []
var _focus := Node3D.new()
var _capture: Array = []
var _capture_frames := 0
var _capture_dir := ""


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

	audio = Ambience.new()
	audio.name = "Ambience"
	add_child(audio)
	weather.lightning_struck.connect(audio.thunder)
	sub.vents_opened.connect(audio.vents)
	sub.breached.connect(_on_breach)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	periscope_ui = PeriscopeOverlay.new()
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

	room.setup_screens(rig, ocean, ships)

	weather.preset_changed.connect(func(l: String) -> void: hud.toast(l))
	sub.depth_mode_changed.connect(func(l: String) -> void: hud.toast("DIVING OFFICER:  " + l))

	_parse_args()
	if _capture.is_empty():
		set_view(View.CINEMATIC)
		hud.play_title()
	sonar_ui.prefill.call_deferred()
	room.prefill_sonar.call_deferred()


func _on_breach(strength: float) -> void:
	rig.shake(strength)
	audio.splash(strength)
	# A ring of churned white water left on the surface.
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 30.0 * strength
	cm.bottom_radius = 30.0 * strength
	cm.height = 0.1
	disc.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 1.0, 0.0)
	mat.no_depth_test = true
	disc.material_override = mat
	disc.layers = WakeTrail.LAYER
	disc.top_level = true
	wake_map.add_child(disc)
	var bow := sub.to_global(Vector3(0, 0, -20.0))
	disc.global_position = Vector3(bow.x, 0.0, bow.z)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color", Color(0.0, 0.0, 0.0), 30.0)
	tw.tween_callback(disc.queue_free)


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
	frigate.place(sub.position + Vector3(2600.0, 0.0, -2900.0), deg_to_rad(250.0), 17.0)
	ships.append(frigate)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	ocean.advance(dt)
	sub.advance(dt)
	var night := float(weather.current.get("nav_lights", 0.0)) > 0.5
	for s in ships:
		(s as SurfaceShip).advance(dt, sub.position)
		(s as SurfaceShip).set_night(night)
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


func set_view(v: View) -> void:
	view = v
	periscope_ui.visible = v == View.PERISCOPE
	sonar_ui.visible = v == View.SONAR
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
			if sub.depth_mode >= 2:
				sub.set_depth_mode(1)
			sub.masts_up = true
			rig.set_mode(CameraRig.Mode.PERISCOPE)
			rig.camera.make_current()
			periscope_ui.on_enter()
		View.COMMAND_ROOM:
			rig.set_mode(CameraRig.Mode.FIXED)
			room.camera.make_current()
		View.SONAR:
			rig.set_mode(CameraRig.Mode.FIXED)
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
			weather.next_preset()
		KEY_W, KEY_UP:
			sub.set_speed_step(sub.speed_step + 1)
			hud.toast("HELM:  " + sub.speed_label())
		KEY_S, KEY_DOWN:
			sub.set_speed_step(sub.speed_step - 1)
			hud.toast("HELM:  " + sub.speed_label())
		KEY_Z, KEY_PAGEDOWN:
			sub.set_depth_mode(sub.depth_mode + 1)
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
			sub.masts_up = not sub.masts_up
			hud.toast("MASTS " + ("RAISED" if sub.masts_up else "HOUSED"))
		KEY_SPACE:
			if view == View.CINEMATIC:
				rig.next_shot()
		KEY_H:
			hud.toggle_help()
		KEY_U:
			hud.visible = not hud.visible
		KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
		KEY_ESCAPE:
			hud.toggle_pause()
		_:
			if view == View.CINEMATIC:
				set_view(View.EXTERIOR)


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
	weather.set_preset(spec[0], true)
	var v := int(spec[1])
	if spec.size() > 4:
		sub.set_depth_mode(int(spec[4]))
		sub.depth = float(Submarine.DEPTH_MODES[int(spec[4])]["depth"])
	if spec.size() > 5 and spec[5] == "blow":
		sub.emergency_blow()
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
	_capture_frames = int(spec[3]) if spec.size() > 3 else 30


func _capture_step() -> void:
	_capture_frames -= 1
	if _capture_frames > 0:
		return
	var spec: PackedStringArray = _capture.pop_front()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_capture_dir, "_".join(spec)]
	img.save_png(path)
	print("CAPTURED ", path)
	if _capture.is_empty():
		get_tree().quit()
	else:
		_begin_shot()
