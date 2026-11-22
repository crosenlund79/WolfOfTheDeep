class_name CommandRoom
extends Node3D
## A small, atmospheric control room built from primitives. Its screens show
## live feeds: the optronic mast camera and the sonar console render into
## SubViewports. The room lives on render layer 2, far below the ocean.

const LAYER := 1 << 1
const ORIGIN := Vector3(0.0, -5000.0, 0.0)

var sub: Submarine
var weather: Weather
var camera: Camera3D
var active := false
var rig_for_red := false

var _env: Environment
var _feed_vp: SubViewport
var _feed_cam: Camera3D
var _sonar_vp: SubViewport
var _sonar: SonarConsole
var _ctrl_vp: SubViewport
var _ctrl: Control
var _rig: CameraRig
var _room: Node3D
var _lights: Array[Light3D] = []
var _strip_mats: Array[StandardMaterial3D] = []
var _yaw := 0.0
var _pitch := -0.05
var _look := Vector2.ZERO
var _time := 0.0
var _screens: Array = []
var _lamp: Node3D


func _ready() -> void:
	_room = Node3D.new()
	_room.name = "Room"
	_room.position = ORIGIN
	add_child(_room)
	camera = Camera3D.new()
	camera.name = "RoomCamera"
	camera.fov = 68.0
	camera.near = 0.05
	camera.far = 60.0
	camera.cull_mask = LAYER
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.0, 0.0, 0.0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.25, 0.32, 0.4)
	_env.ambient_light_energy = 0.12
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = 1.15
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 0.9
	_env.ssao_enabled = true
	_env.ssao_intensity = 2.0
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.035
	_env.volumetric_fog_albedo = Color(0.8, 0.85, 0.9)
	_env.volumetric_fog_length = 24.0
	_env.volumetric_fog_anisotropy = 0.4
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 0.9
	camera.environment = _env
	_room.add_child(camera)
	camera.position = Vector3(0.0, 1.68, 3.6)
	_build_room()


func setup_screens(rig: CameraRig, ocean: Ocean, ships: Array[Node3D]) -> void:
	_rig = rig
	# Optronic mast feed (shares the main world).
	_feed_vp = SubViewport.new()
	_feed_vp.size = Vector2i(960, 540)
	_feed_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_feed_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_feed_vp)
	_feed_vp.world_3d = get_viewport().find_world_3d()
	_feed_cam = Camera3D.new()
	_feed_cam.fov = 22.0
	_feed_cam.far = 30000.0
	_feed_cam.cull_mask = 1
	_feed_vp.add_child(_feed_cam)
	# Sonar console (2D) rendered to a texture.
	_sonar_vp = SubViewport.new()
	_sonar_vp.size = Vector2i(1600, 900)
	_sonar_vp.disable_3d = true
	_sonar_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sonar_vp)
	_sonar = SonarConsole.new()
	_sonar.sub = sub
	_sonar.ships = ships
	_sonar_vp.add_child(_sonar)
	# Ship control display.
	_ctrl_vp = SubViewport.new()
	_ctrl_vp.size = Vector2i(960, 540)
	_ctrl_vp.disable_3d = true
	_ctrl_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ctrl_vp)
	_ctrl = Control.new()
	_ctrl.size = Vector2(960, 540)
	_ctrl.draw.connect(_draw_ship_control)
	_ctrl_vp.add_child(_ctrl)
	for s in _screens:
		var mat: ShaderMaterial = s[0]
		match String(s[1]):
			"feed":
				mat.set_shader_parameter("tex", _feed_vp.get_texture())
			"sonar":
				mat.set_shader_parameter("tex", _sonar_vp.get_texture())
			"ctrl":
				mat.set_shader_parameter("tex", _ctrl_vp.get_texture())


func prefill_sonar() -> void:
	if _sonar:
		_sonar.prefill()


func set_active(v: bool) -> void:
	active = v
	_room.visible = v
	var mode := SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED
	if _feed_vp:
		_feed_vp.render_target_update_mode = mode
		_sonar_vp.render_target_update_mode = mode
		_ctrl_vp.render_target_update_mode = mode
		_sonar.visible = v


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		rig_for_red = not rig_for_red
		return true
	return false


func advance(dt: float) -> void:
	_time += dt
	if not active:
		return
	var vp := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var target := Vector2((m.x / vp.x - 0.5) * -2.4, (m.y / vp.y - 0.5) * -0.9)
	_look = _look.lerp(target, 1.0 - exp(-dt * 3.0))
	var roll := sub.basis.get_euler().z * 0.35
	var pitch := sub.basis.get_euler().x * 0.35
	camera.rotation = Vector3(_look.y + pitch, _look.x, roll)
	camera.position = Vector3(sin(_time * 0.4) * 0.015, 1.68 + sin(_time * 0.9) * 0.008, 3.6)
	if _lamp:
		_lamp.rotation.z = -roll * 2.2 + sin(_time * 0.8) * 0.02
		_lamp.rotation.x = -pitch * 2.0
	var red := rig_for_red or (weather and weather.is_night())
	for l in _lights:
		var base: Color = l.get_meta("base")
		l.light_color = Color(1.0, 0.12, 0.06) if red and l.get_meta("strip") else base
		l.light_energy = float(l.get_meta("energy")) * (0.55 if red and l.get_meta("strip") else 1.0)
	for sm in _strip_mats:
		sm.emission = Color(1.0, 0.1, 0.05) if red else Color(0.8, 0.9, 1.0)
		sm.emission_energy_multiplier = 2.0 if red else 3.5
	_env.ambient_light_color = Color(0.35, 0.05, 0.03) if red else Color(0.25, 0.32, 0.4)
	# Mast feed camera mirrors the optronic mast.
	if _feed_cam:
		var head := sub.mast_head()
		var b := _rig.bearing if _rig else sub.heading
		var dir := Vector3(sin(b), 0.0, -cos(b))
		_feed_cam.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), head)
	if _ctrl:
		_ctrl.queue_redraw()


# --- construction -----------------------------------------------------------

func _mat(color: Color, rough: float = 0.6, metal: float = 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = LAYER
	_room.add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = LAYER
	(parent if parent else _room).add_child(mi)
	return mi


func _screen(size: Vector2, pos: Vector3, rot: Vector3, kind: String, tint: Color = Color(1, 1, 1)) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/command_room/screen.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("kind", 0 if kind in ["feed", "sonar", "ctrl"] else 1)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room.add_child(mi)
	_screens.append([mat, kind])
	# Screen glow onto the surroundings.
	var l := OmniLight3D.new()
	l.light_color = tint.lerp(Color(0.5, 0.8, 1.0), 0.5)
	l.light_energy = 0.35
	l.omni_range = 2.6
	l.position = pos + Basis.from_euler(rot) * Vector3(0, 0, 0.5)
	l.layers = LAYER
	l.light_cull_mask = LAYER
	l.set_meta("base", l.light_color)
	l.set_meta("energy", l.light_energy)
	l.set_meta("strip", false)
	_room.add_child(l)
	_lights.append(l)


func _console(pos: Vector3, rot_y: float, kind: String, tint: Color) -> void:
	var dark := _mat(Color(0.06, 0.065, 0.07), 0.45, 0.4)
	var panel := _mat(Color(0.2, 0.22, 0.24), 0.55, 0.3)
	var b := Basis(Vector3.UP, rot_y)
	var node_pos := func(local: Vector3) -> Vector3: return pos + b * local
	_box(Vector3(1.1, 0.75, 0.75), node_pos.call(Vector3(0, 0.375, 0)), panel, Vector3(0, rot_y, 0))
	_box(Vector3(1.1, 0.06, 0.55), node_pos.call(Vector3(0, 0.78, 0.08)), dark, Vector3(deg_to_rad(-12.0), rot_y, 0))
	_box(Vector3(1.1, 1.25, 0.18), node_pos.call(Vector3(0, 1.4, -0.3)), dark, Vector3(deg_to_rad(8.0), rot_y, 0))
	_screen(Vector2(0.98, 0.58), node_pos.call(Vector3(0, 1.48, -0.2)), Vector3(deg_to_rad(8.0), rot_y, 0), kind, tint)
	_screen(Vector2(0.98, 0.32), node_pos.call(Vector3(0, 0.97, -0.08)), Vector3(deg_to_rad(8.0), rot_y, 0), "aux", tint * 0.7)
	# Keyboard/trackball shelf glow.
	var kb := _box(Vector3(0.6, 0.02, 0.2), node_pos.call(Vector3(0, 0.82, 0.22)), _emissive(tint * 0.25, 0.6), Vector3(deg_to_rad(-12.0), rot_y, 0))
	kb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _build_room() -> void:
	var wall := _mat(Color(0.42, 0.45, 0.47), 0.7, 0.15)
	var floor_m := _mat(Color(0.08, 0.085, 0.09), 0.5, 0.6)
	var ceiling := _mat(Color(0.3, 0.32, 0.34), 0.75, 0.1)
	var pipe_m := _mat(Color(0.55, 0.57, 0.58), 0.4, 0.6)
	var red_m := _mat(Color(0.5, 0.06, 0.04), 0.5, 0.2)
	var blue_m := _mat(Color(0.06, 0.18, 0.42), 0.5, 0.2)
	var yellow := _mat(Color(0.7, 0.55, 0.08), 0.5, 0.2)
	# Shell: floor, ceiling, walls.
	_box(Vector3(7.6, 0.1, 13.0), Vector3(0, -0.05, 0), floor_m)
	_box(Vector3(7.6, 0.1, 13.0), Vector3(0, 2.55, 0), ceiling)
	_box(Vector3(0.1, 2.6, 13.0), Vector3(-3.8, 1.25, 0), wall)
	_box(Vector3(0.1, 2.6, 13.0), Vector3(3.8, 1.25, 0), wall)
	_box(Vector3(7.6, 2.6, 0.1), Vector3(0, 1.25, -6.5), wall)
	_box(Vector3(7.6, 2.6, 0.1), Vector3(0, 1.25, 6.5), wall)
	# Deck grating stripes.
	for i in 26:
		_box(Vector3(7.4, 0.02, 0.04), Vector3(0, 0.01, -6.3 + i * 0.5), _mat(Color(0.14, 0.15, 0.16), 0.4, 0.7))
	# Forward bulkhead: watertight door.
	_box(Vector3(0.9, 1.7, 0.08), Vector3(2.6, 1.0, -6.42), _mat(Color(0.32, 0.34, 0.35), 0.5, 0.4))
	_cyl(0.18, 0.06, Vector3(2.6, 1.0, -6.36), red_m, Vector3(PI * 0.5, 0, 0))
	# Overhead pipe runs and cable trays.
	for x in [-3.2, -2.6, 2.7, 3.3]:
		_cyl(0.07, 12.8, Vector3(x, 2.32, 0), pipe_m, Vector3(PI * 0.5, 0, 0))
	_cyl(0.11, 12.8, Vector3(-1.1, 2.4, 0), blue_m, Vector3(PI * 0.5, 0, 0))
	_cyl(0.05, 12.8, Vector3(1.2, 2.42, 0), yellow, Vector3(PI * 0.5, 0, 0))
	_box(Vector3(0.5, 0.08, 12.8), Vector3(0.0, 2.38, 0), _mat(Color(0.2, 0.21, 0.22), 0.6, 0.5))
	for z in range(-6, 7, 2):
		_box(Vector3(7.4, 0.08, 0.12), Vector3(0, 2.45, float(z)), _mat(Color(0.36, 0.38, 0.4), 0.6, 0.3))
	# Valve wheels.
	for p in [Vector3(-3.7, 1.9, -4.0), Vector3(-3.7, 1.9, 4.5), Vector3(3.7, 2.0, 5.0)]:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.12
		tm.outer_radius = 0.16
		t.mesh = tm
		t.material_override = red_m
		t.position = p
		t.rotation = Vector3(0, 0, PI * 0.5)
		t.layers = LAYER
		_room.add_child(t)
	# Ceiling light strips.
	for z in [-4.5, -1.5, 1.5, 4.5]:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color.BLACK
		sm.emission_enabled = true
		sm.emission = Color(0.8, 0.9, 1.0)
		sm.emission_energy_multiplier = 3.5
		_strip_mats.append(sm)
		_box(Vector3(1.8, 0.04, 0.16), Vector3(0, 2.49, z), sm)
		var sl := SpotLight3D.new()
		sl.position = Vector3(0, 2.44, z)
		sl.rotation = Vector3(-PI * 0.5, 0, 0)
		sl.spot_range = 4.5
		sl.spot_angle = 62.0
		sl.light_energy = 1.4
		sl.light_color = Color(0.82, 0.9, 1.0)
		sl.shadow_enabled = true
		sl.light_volumetric_fog_energy = 1.6
		sl.layers = LAYER
		sl.light_cull_mask = LAYER
		sl.set_meta("base", sl.light_color)
		sl.set_meta("energy", sl.light_energy)
		sl.set_meta("strip", true)
		_room.add_child(sl)
		_lights.append(sl)
	# Forward consoles: ship control, mast feed, tactical.
	_console(Vector3(-1.4, 0, -5.6), 0.0, "ctrl", Color(0.55, 0.85, 1.0))
	_console(Vector3(0.0, 0, -5.6), 0.0, "feed", Color(1.0, 1.0, 1.0))
	_console(Vector3(1.4, 0, -5.6), 0.0, "sonar", Color(0.7, 1.0, 0.8))
	# Port side: sonar stack.
	for i in 3:
		_console(Vector3(-3.15, 0, -2.8 + i * 1.3), PI * 0.5, "sonar" if i == 1 else "data", Color(0.45, 1.0, 0.65))
	# Starboard side: fire control.
	for i in 3:
		_console(Vector3(3.15, 0, -2.8 + i * 1.3), -PI * 0.5, "data", Color(1.0, 0.7, 0.35))
	# Central conn pedestal with overhead display.
	var ped := _mat(Color(0.16, 0.17, 0.18), 0.5, 0.5)
	_cyl(0.45, 1.0, Vector3(0, 0.5, 0.6), ped)
	_box(Vector3(0.9, 0.05, 0.6), Vector3(0, 1.02, 0.6), ped, Vector3(deg_to_rad(-15.0), 0, 0))
	_screen(Vector2(0.8, 0.45), Vector3(0, 1.05, 0.6), Vector3(deg_to_rad(-75.0), 0, 0), "ctrl", Color(0.55, 0.85, 1.0))
	_cyl(0.03, 0.8, Vector3(0, 2.15, 0.2), pipe_m)
	_screen(Vector2(1.3, 0.72), Vector3(0, 1.85, 0.2), Vector3(deg_to_rad(10.0), PI, 0), "feed")
	_screen(Vector2(1.3, 0.72), Vector3(0, 1.85, 0.2), Vector3(deg_to_rad(10.0), 0, 0), "feed")
	# Handrails around the conn.
	var rail := _mat(Color(0.7, 0.72, 0.74), 0.3, 0.8)
	for side in [-1.0, 1.0]:
		_cyl(0.025, 2.2, Vector3(side * 1.0, 1.0, 1.4), rail, Vector3(PI * 0.5, 0, 0))
		_cyl(0.025, 1.0, Vector3(side * 1.0, 0.5, 0.3), rail)
		_cyl(0.025, 1.0, Vector3(side * 1.0, 0.5, 2.5), rail)
	# Hanging lamp that swings with the boat's roll.
	_lamp = Node3D.new()
	_lamp.position = Vector3(-0.9, 2.5, 2.6)
	_room.add_child(_lamp)
	_cyl(0.008, 0.6, Vector3(0, -0.3, 0), pipe_m, Vector3.ZERO, _lamp)
	var bulb := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.06
	sm2.height = 0.12
	bulb.mesh = sm2
	bulb.material_override = _emissive(Color(1.0, 0.75, 0.45), 4.0)
	bulb.position = Vector3(0, -0.64, 0)
	bulb.layers = LAYER
	_lamp.add_child(bulb)
	var lamp_light := OmniLight3D.new()
	lamp_light.position = Vector3(0, -0.66, 0)
	lamp_light.light_color = Color(1.0, 0.72, 0.42)
	lamp_light.light_energy = 0.6
	lamp_light.omni_range = 3.5
	lamp_light.shadow_enabled = true
	lamp_light.layers = LAYER
	lamp_light.light_cull_mask = LAYER
	lamp_light.set_meta("base", lamp_light.light_color)
	lamp_light.set_meta("energy", lamp_light.light_energy)
	lamp_light.set_meta("strip", false)
	_lamp.add_child(lamp_light)
	_lights.append(lamp_light)
	# Station labels.
	for d in [["SHIP CONTROL", Vector3(-1.4, 2.2, -6.35)], ["OPTRONIC MAST", Vector3(0, 2.2, -6.35)], ["TACTICAL", Vector3(1.4, 2.2, -6.35)]]:
		var lbl := Label3D.new()
		lbl.text = String(d[0])
		lbl.font = UiStyle.display()
		lbl.font_size = 48
		lbl.pixel_size = 0.0025
		lbl.modulate = Color(0.85, 0.9, 0.95, 0.85)
		lbl.position = d[1]
		lbl.layers = LAYER
		lbl.shaded = false
		_room.add_child(lbl)
	for d2 in [["SONAR", Vector3(-3.7, 2.2, -1.5), PI * 0.5], ["FIRE CONTROL", Vector3(3.7, 2.2, -1.5), -PI * 0.5]]:
		var lbl2 := Label3D.new()
		lbl2.text = String(d2[0])
		lbl2.font = UiStyle.display()
		lbl2.font_size = 48
		lbl2.pixel_size = 0.0025
		lbl2.modulate = Color(0.85, 0.9, 0.95, 0.85)
		lbl2.position = d2[1]
		lbl2.rotation.y = float(d2[2])
		lbl2.layers = LAYER
		lbl2.shaded = false
		_room.add_child(lbl2)
	_room.visible = false


func _draw_ship_control() -> void:
	var c := _ctrl
	var s := c.size
	var f := UiStyle.mono()
	var fd := UiStyle.display()
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.02, 0.03))
	c.draw_string(fd, Vector2(24, 40), "SHIP CONTROL  ·  VARG", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.CYAN)
	# Attitude indicator.
	var ctr := Vector2(220, 290)
	var e := sub.basis.get_euler()
	c.draw_arc(ctr, 150, 0, TAU, 64, UiStyle.LINE, 2.0)
	var horizon_y := e.x * 300.0
	var roll := -e.z
	var dir := Vector2(cos(roll), sin(roll))
	c.draw_line(ctr + Vector2(0, horizon_y) - dir * 140, ctr + Vector2(0, horizon_y) + dir * 140, UiStyle.GREEN, 3.0)
	c.draw_line(ctr - Vector2(60, 0), ctr - Vector2(20, 0), UiStyle.AMBER, 4.0)
	c.draw_line(ctr + Vector2(20, 0), ctr + Vector2(60, 0), UiStyle.AMBER, 4.0)
	c.draw_string(f, ctr + Vector2(-90, 190), "PITCH %+5.1f°   ROLL %+5.1f°" % [rad_to_deg(e.x), rad_to_deg(e.z)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.WHITE)
	# Depth tape.
	var x := 470.0
	c.draw_rect(Rect2(x, 90, 60, 400), Color(0.03, 0.06, 0.08))
	for dm in range(0, 161, 10):
		var y := 90.0 + float(dm) / 160.0 * 400.0
		c.draw_line(Vector2(x, y), Vector2(x + 14, y), UiStyle.DIM, 1.0)
		if dm % 40 == 0:
			c.draw_string(f, Vector2(x + 18, y + 5), str(dm), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.DIM)
	var yd := 90.0 + clampf(sub.depth / 160.0, 0.0, 1.0) * 400.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 2, yd), Vector2(x - 18, yd - 8), Vector2(x - 18, yd + 8)]), UiStyle.AMBER)
	# Data block.
	var lines := [
		"DEPTH      %6.1f M" % sub.depth,
		"ORDERED    %s" % sub.depth_label(),
		"SPEED      %5.1f KT" % sub.knots(),
		"TELEGRAPH  %s" % sub.speed_label(),
		"HEADING    %03d°" % int(fposmod(rad_to_deg(sub.heading), 360.0)),
		"RUDDER     %+4.0f°" % (sub.rudder * 25.0),
		"PROPULSION AIP  ·  BATTERY 86%",
		"MASTS      %s" % ("RAISED" if sub.masts_up else "HOUSED"),
	]
	var y2 := 120.0
	for l in lines:
		c.draw_string(f, Vector2(580, y2), String(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.WHITE)
		y2 += 34.0
