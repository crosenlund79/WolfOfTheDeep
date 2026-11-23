class_name ControlRoomPilot
extends Control
## Mission 004C visual pilot: the control room as path-traced plates
## (rendered offline in Blender/Cycles from a modelled room) with live layers:
## working displays warped onto their screens, indicator lamps, red night
## lighting, gentle head movement and the boat's roll. Fixed viewpoints with
## push-in transitions replace free walking.

signal request(action: String)

const DIR := "res://assets/interior/control_room/"
const ORDER := ["command", "sonar", "nav", "wide"]
const NAMES := {"command": "CONTROL ROOM  ·  COMMAND POSITION", "sonar": "CONTROL ROOM  ·  SONAR CONSOLE", "nav": "CONTROL ROOM  ·  NAVIGATION TABLE", "wide": "CONTROL ROOM"}
const BAR := [["command", "COMMAND"], ["sonar", "SONAR"], ["nav", "NAVIGATION"], ["wide", "OVERVIEW"], ["periscope", "PERISCOPE  ›"], ["exterior", "EXTERIOR  ›"]]
const HOT_LABELS := {"sonar": "SONAR CONSOLE", "nav": "NAVIGATION TABLE", "periscope": "ATTACK PERISCOPE", "ship_control": "SHIP CONTROL  ·  ORDERS", "ballast": "BALLAST CONTROL  ·  ORDERS"}
## Which part of each live source appears on which screen.
const SOURCES := {
	"periscope_monitor": ["feed", Rect2(0, 0, 1, 1)],
	"sonar_console_upper_s": ["sonar", Rect2(0.0, 0.04, 0.6, 0.74)],
	"sonar_console_lower": ["sonar", Rect2(0.59, 0.04, 0.41, 0.74)],
	"nav_table": ["chart", Rect2(1, 1, -1, -1)],  # turned to face the navigator's side of the table
	"ship_ctrl_l": ["ctrl", Rect2(0, 0, 0.5, 1)],
	"ship_ctrl_r": ["ctrl", Rect2(0.5, 0, 0.5, 1)],
}

var sub: Submarine
var chart_main: ChartView
var crew: Crew
var clock: GameClock
var sensors: SensorSuite
var area: ArcticArea
var ships: Array[Node3D] = []
var rig: CameraRig
var weather: Weather
var sector_center := Vector3.ZERO
var sector_radius := 0.0
var rv_point := Vector3.ZERO
var rig_for_red := false
## Development aid for clean screenshots (no hover highlight).
var show_hover := true

var view := "command"
var meta: Dictionary = {}
var plate := Vector2(1920, 1080)
var _prev := ""
var _fade := 1.0
var _plates: Dictionary = {}
var _red := 0.0
var _look := Vector2.ZERO
var _xf := Transform2D.IDENTITY
var _xf_prev := Transform2D.IDENTITY
var _screens: Dictionary = {}
var _fx: Node2D
var _hover := ""
var _t := 0.0
var _bar: HBoxContainer
var _buttons: Dictionary = {}
var _sources: Dictionary = {}
var _feed_cam: Camera3D
var _feed_info: Label
var _feed_cover: ColorRect
var _ready_ok := false


class ShipControlDisplay:
	extends Control
	var sub: Submarine

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if sub == null:
			return
		var fm := UiStyle.mono()
		var w := size.x * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.05))
		for page in 2:
			var x0 := page * w
			draw_rect(Rect2(x0, 0, w, 34), Color(0.05, 0.1, 0.12))
			draw_string(fm, Vector2(x0 + 14, 24), "SHIP CONTROL  ·  HELM" if page == 0 else "SHIP CONTROL  ·  PLANES / TRIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 0.8, 0.9))
			draw_line(Vector2(x0 + w - 1, 0), Vector2(x0 + w - 1, size.y), Color(0.1, 0.2, 0.22), 2)
		var hdg := fposmod(rad_to_deg(sub.heading), 360.0)
		var ord := fposmod(rad_to_deg(sub.ordered_heading), 360.0)
		var rows := [["HEADING", "%03d" % (int(round(hdg)) % 360)], ["ORDERED", "%03d" % (int(round(ord)) % 360)], ["SPEED", "%4.1f KT" % sub.knots()], ["TELEGRAPH", sub.speed_label()]]
		for i in rows.size():
			var y := 70 + (i % 2) * 110 + (i / 2) * 0
			var x := 20 + (i / 2) * 250
			draw_string(fm, Vector2(x, y), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.55, 0.6))
			draw_string(fm, Vector2(x, y + 46), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40 if i < 3 else 22, Color(0.85, 0.92, 0.95))
		var depth := maxf(sub.depth - 2.05, 0.0) + (0.0 if sub.depth < 3.0 else 2.05)
		var drows := [["DEPTH", "%5.1f M" % depth], ["ORDERED", sub.depth_label()], ["BATTERY", "%d %%" % int(sub.battery)], ["MASTS", "RAISED" if sub.masts_up else "HOUSED"]]
		for i in drows.size():
			var y2 := 70 + (i % 2) * 110
			var x2 := w + 20 + (i / 2) * 250
			draw_string(fm, Vector2(x2, y2), String(drows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.55, 0.6))
			draw_string(fm, Vector2(x2, y2 + 46), String(drows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40 if i == 0 else 22, Color(1.0, 0.75, 0.35) if i == 0 else Color(0.85, 0.92, 0.95))
		# Depth bar.
		var bx := w * 2 - 60
		draw_rect(Rect2(bx, 50, 24, size.y - 80), Color(0.06, 0.12, 0.14))
		var f := clampf(depth / 250.0, 0.0, 1.0)
		draw_rect(Rect2(bx, 50, 24, (size.y - 80) * f), Color(0.2, 0.55, 0.65))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var parsed: Variant = null
	if FileAccess.file_exists(DIR + "views.json"):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + "views.json"))
	if parsed is Dictionary:
		meta = parsed
		plate = Vector2(float(meta["resolution"][0]), float(meta["resolution"][1]))
	for v in ORDER:
		var entry := {}
		for k in ["normal", "red"]:
			if ResourceLoader.exists(DIR + "%s_%s.jpg" % [v, k]):
				entry[k] = load(DIR + "%s_%s.jpg" % [v, k])
		for k in ["maskA", "maskB"]:
			if ResourceLoader.exists(DIR + "%s_%s.png" % [v, k]):
				entry[k] = load(DIR + "%s_%s.png" % [v, k])
		_plates[v] = entry
	_ready_ok = not meta.is_empty() and (_plates["command"] as Dictionary).has("normal")
	_build_sources()
	_build_screens()
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_bar()
	visible = false


func _build_sources() -> void:
	# Periscope / optronic mast video.
	var fvp := SubViewport.new()
	fvp.size = Vector2i(768, 432)
	fvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(fvp)
	fvp.world_3d = get_viewport().find_world_3d()
	_feed_cam = Camera3D.new()
	_feed_cam.fov = 24.0
	_feed_cam.far = 30000.0
	_feed_cam.cull_mask = 1
	fvp.add_child(_feed_cam)
	_feed_cover = ColorRect.new()
	_feed_cover.color = Color(0.02, 0.025, 0.03)
	_feed_cover.size = Vector2(768, 432)
	fvp.add_child(_feed_cover)
	_feed_info = UiStyle.label("", 18, Color(0.75, 0.95, 0.85), UiStyle.mono())
	_feed_info.position = Vector2(14, 10)
	fvp.add_child(_feed_info)
	_sources["feed"] = fvp
	# Sonar console (the game's own display).
	var svp := SubViewport.new()
	svp.size = Vector2i(1280, 720)
	svp.disable_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(svp)
	var sonar := SonarConsole.new()
	sonar.sub = sub
	sonar.ships = ships
	sonar.sensors = sensors
	sonar.crew = crew
	svp.add_child(sonar)
	_sources["sonar"] = svp
	# Navigation plot (the game's chart, with its seabed shading).
	var cvp := SubViewport.new()
	cvp.size = Vector2i(1280, 800)
	cvp.disable_3d = true
	cvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(cvp)
	var chart := ChartView.new()
	chart.area = area
	chart.sub = sub
	chart.sensors = sensors
	if chart_main:
		chart.data = chart_main.data
		chart.clock = chart_main.clock
		chart.main = chart_main.main
		chart.route = chart_main.route
		chart.track = chart_main.track
		chart.reported_ice = chart_main.reported_ice
		chart.aircraft_marks = chart_main.aircraft_marks
		chart.intel_marks = chart_main.intel_marks
		chart.weapons = chart_main.weapons
		chart.drone = chart_main.drone
		chart.set_chart_scale(26.0)
	chart.sector_center = sector_center
	chart.sector_radius = sector_radius
	chart.rv_point = rv_point
	cvp.add_child(chart)
	chart.build_texture()
	_sources["chart"] = cvp
	# Ship control readouts.
	var kvp := SubViewport.new()
	kvp.size = Vector2i(1200, 330)
	kvp.disable_3d = true
	kvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(kvp)
	var sc := ShipControlDisplay.new()
	sc.sub = sub
	sc.size = Vector2(1200, 330)
	kvp.add_child(sc)
	_sources["ctrl"] = kvp


func _build_screens() -> void:
	if not _ready_ok:
		return
	var order: Array = meta.get("live_order", [])
	for v in ORDER:
		var list: Array = []
		var vm: Dictionary = meta["views"].get(v, {})
		var live: Dictionary = vm.get("live", {})
		for name in live:
			var idx := order.find(name)
			if idx < 0 or not SOURCES.has(name):
				continue
			var grid: Array = live[name]
			if not _grid_on_plate(grid):
				continue
			var mask: Texture2D = _plates[v].get("maskA" if idx < 3 else "maskB")
			if mask == null:
				continue
			var src: Array = SOURCES[name]
			var ls := LiveScreen.new()
			ls.setup(grid, plate, mask, idx % 3, (_sources[src[0]] as SubViewport).get_texture(), src[1])
			ls.visible = false
			add_child(ls)
			list.append(ls)
		_screens[v] = list


func _grid_on_plate(grid: Array) -> bool:
	for row in grid:
		for p in row:
			var x := float(p[0])
			var y := float(p[1])
			if x < -plate.x or x > plate.x * 2.0 or y < -plate.y or y > plate.y * 2.0:
				return false
	return true


func _build_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	UiStyle.place(_bar, Vector2(0.5, 1), Vector2(-430, -96), Vector2(860, 30))
	add_child(_bar)
	for def in BAR:
		var b := Button.new()
		b.text = String(def[1])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiStyle.display())
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color(0.8, 0.86, 0.9, 0.85))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.55))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.55))
		for st in ["normal", "hover", "pressed"]:
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0.02, 0.03, 0.035, 0.55 if st == "normal" else 0.8)
			bs.border_color = Color(0.6, 0.66, 0.68, 0.18 if st == "normal" else 0.45)
			bs.set_border_width_all(1)
			bs.content_margin_left = 12
			bs.content_margin_right = 12
			bs.content_margin_top = 4
			bs.content_margin_bottom = 4
			b.add_theme_stylebox_override(st, bs)
		var id := String(def[0])
		b.pressed.connect(func() -> void: _action(id))
		_bar.add_child(b)
		_buttons[id] = b


# --- public -------------------------------------------------------------------

func enter(v: String = "command") -> void:
	view = v
	_prev = ""
	_fade = 1.0
	_update_visibility()


func view_name() -> String:
	return String(NAMES.get(view, "CONTROL ROOM"))


func go(v: String) -> void:
	if v == view or not _plates.has(v):
		return
	_prev = view
	_xf_prev = _xf
	view = v
	_fade = 0.0
	_update_visibility()


func handle_key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return false
	match k.keycode:
		KEY_Q:
			go(ORDER[(ORDER.find(view) + ORDER.size() - 1) % ORDER.size()])
			return true
		KEY_E:
			go(ORDER[(ORDER.find(view) + 1) % ORDER.size()])
			return true
		KEY_BACKSPACE:
			go("command")
			return true
		KEY_R:
			rig_for_red = not rig_for_red
			return true
	return false


func _action(id: String) -> void:
	match id:
		"periscope", "exterior", "orders", "sonar_full", "chart_full":
			request.emit(id)
		_:
			go(id)


# --- update ---------------------------------------------------------------------

func _update_visibility() -> void:
	for v in _screens:
		for ls: LiveScreen in _screens[v]:
			ls.visible = visible and v == view
	var need := {"feed": view in ["command", "wide"], "sonar": view in ["command", "wide", "sonar"], "chart": view in ["nav", "wide"], "ctrl": view in ["command", "wide"]}
	for k in _sources:
		(_sources[k] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if (visible and need[k]) else SubViewport.UPDATE_DISABLED
	for id in _buttons:
		(_buttons[id] as Button).add_theme_color_override("font_color", Color(1.0, 0.86, 0.55) if id == view else Color(0.8, 0.86, 0.9, 0.85))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _ready_ok:
		_update_visibility()


func _process(delta: float) -> void:
	if not visible or not _ready_ok:
		return
	var dt := minf(delta, 0.1)
	_t += dt
	_fade = move_toward(_fade, 1.0, dt / 0.75)
	var want_red := 1.0 if (rig_for_red or (clock and clock.is_night()) or (crew and crew.alert >= 2)) else 0.0
	_red = move_toward(_red, want_red, dt * 0.8)
	# Gentle head movement following the mouse, slow breathing, the boat's roll.
	var m := get_local_mouse_position() / size - Vector2(0.5, 0.5)
	_look = _look.lerp(Vector2(clampf(m.x, -0.5, 0.5), clampf(m.y, -0.5, 0.5)), 1.0 - exp(-dt * 2.0))
	var off := -_look * Vector2(26.0, 14.0) + Vector2(sin(_t * 0.27) * 2.0, sin(_t * 0.41) * 1.5)
	var roll := clampf((sub.basis.get_euler().z if sub else 0.0) * 0.22, -0.012, 0.012)
	var s := maxf(size.x / plate.x, size.y / plate.y) * 1.04
	var ease := smoothstep(0.0, 1.0, _fade)
	var zoom_in := 1.0 + 0.035 * (1.0 - ease)
	_xf = Transform2D(roll, size * 0.5 + off) * Transform2D(0.0, Vector2(s * zoom_in, s * zoom_in), 0.0, Vector2.ZERO) * Transform2D(0.0, -plate * 0.5)
	if _prev != "":
		_xf_prev = Transform2D(roll, size * 0.5 + off) * Transform2D(0.0, Vector2(s * (1.0 + 0.08 * ease), s * (1.0 + 0.08 * ease)), 0.0, Vector2.ZERO) * Transform2D(0.0, -plate * 0.5)
	if _fade >= 1.0:
		_prev = ""
	# Live layers follow the plate.
	var bright := lerpf(1.0, 0.6, _red)
	for ls: LiveScreen in _screens.get(view, []):
		ls.transform = _xf
		ls.modulate.a = ease
		ls.set_look(bright, Color(1.0, lerpf(1.0, 0.86, _red), lerpf(1.0, 0.82, _red)))
		ls.queue_redraw()
	_fx.transform = _xf
	_fx.modulate.a = ease
	_fx.queue_redraw()
	_update_feed()
	_update_hover()
	queue_redraw()


func _update_feed() -> void:
	if sub == null or _feed_cam == null:
		return
	var head := sub.mast_head()
	var b := rig.bearing if rig else sub.heading
	var dir := Vector3(sin(b), 0.0, -cos(b))
	_feed_cam.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), head)
	var st := sub.periscope_state()
	_feed_cover.visible = st == Submarine.Scope.HOUSED or st == Submarine.Scope.MOVING
	var state: String = ["MAST HOUSED", "MAST MOVING", "UNDER WATER", "CLEAR"][st]
	_feed_info.text = "OM-1   TV   BRG %03d T   %s" % [int(fposmod(rad_to_deg(b), 360.0)), state]


func _update_hover() -> void:
	_hover = _hot_at(get_local_mouse_position()) if show_hover else ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover != "" else Control.CURSOR_ARROW


## The clickable station under a point in this control's coordinates ("" = none).
func _hot_at(local: Vector2) -> String:
	var p := _xf.affine_inverse() * local
	var vm: Dictionary = meta["views"].get(view, {})
	var hot: Dictionary = vm.get("hot", {})
	var found := ""
	for name in hot:
		if not _hot_action(String(name)):
			continue
		var r: Array = hot[name]
		if Rect2(Vector2(r[0], r[1]), Vector2(r[2] - r[0], r[3] - r[1])).has_point(p):
			found = String(name)
	return found


## What clicking a station does from the current viewpoint ("" = nothing).
func _hot_action(name: String) -> String:
	match name:
		"sonar":
			return "sonar_full" if view == "sonar" else "sonar"
		"nav":
			return "chart_full" if view == "nav" else "nav"
		"periscope":
			return "periscope"
		"ship_control", "ballast":
			return "orders"
	return ""


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var hit := _hot_at(mb.position) if mb.button_index == MOUSE_BUTTON_LEFT and _ready_ok else ""
	if hit != "":
		_action(_hot_action(hit))
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		go("command" if view != "command" else "wide")
		accept_event()


# --- drawing -----------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if not _ready_ok:
		draw_string(UiStyle.display(), Vector2(40, 60), "Control room plates missing (run tools/interior/control_room.py).", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		return
	var ease := smoothstep(0.0, 1.0, _fade)
	if _prev != "":
		_draw_plate(_prev, _xf_prev, 1.0)
	_draw_plate(view, _xf, ease if _prev != "" else 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_plate(v: String, xf: Transform2D, alpha: float) -> void:
	var e: Dictionary = _plates.get(v, {})
	draw_set_transform_matrix(xf)
	var r := Rect2(Vector2.ZERO, plate)
	if e.has("normal"):
		draw_texture_rect(e["normal"], r, false, Color(1, 1, 1, alpha))
	if e.has("red") and _red > 0.001:
		draw_texture_rect(e["red"], r, false, Color(1, 1, 1, alpha * _red))
	if crew and crew.alert >= 2:
		var pulse := 0.06 + 0.05 * (0.5 + 0.5 * sin(_t * 3.0))
		draw_rect(r, Color(0.6, 0.0, 0.0, pulse * alpha))


func _draw_fx() -> void:
	var vm: Dictionary = meta["views"].get(view, {})
	# Indicator lamps: steady ones breathe a little, others blink.
	for led in vm.get("leds", []):
		var p := Vector2(float(led[0]), float(led[1]))
		var c: Array = led[2]
		var col := Color(float(c[0]), float(c[1]), float(c[2]))
		var on := 1.0
		match String(led[3]):
			"blink":
				on = 1.0 if fposmod(_t + p.x * 0.013, 1.2) < 0.6 else 0.12
			"slow":
				on = 0.25 + 0.75 * maxf(sin(_t * 1.1 + p.y), 0.0)
			_:
				on = 0.85 + 0.15 * sin(_t * 0.7 + p.x)
		var sc := clampf(float(led[4]) * 2.2, 1.0, 5.0)
		_fx.draw_circle(p, sc * 3.2, Color(col.r, col.g, col.b, 0.07 * on), true, -1.0, true)
		_fx.draw_circle(p, sc * 1.5, Color(col.r, col.g, col.b, 0.3 * on), true, -1.0, true)
		_fx.draw_circle(p, sc * 0.7, Color(col.r, col.g, col.b, 0.3 + 0.7 * on).lightened(0.35 * on), true, -1.0, true)
	# The station under the pointer.
	if _hover != "":
		var r: Array = vm["hot"][_hover]
		var rect := Rect2(Vector2(r[0], r[1]), Vector2(r[2] - r[0], r[3] - r[1]))
		_fx.draw_rect(rect, Color(1.0, 0.85, 0.55, 0.35), false, 1.5)
		var tag := String(HOT_LABELS.get(_hover, _hover.to_upper()))
		var f := UiStyle.display()
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0
		var tp := Vector2(rect.get_center().x - tw * 0.5, maxf(rect.position.y - 34.0, 70.0))
		_fx.draw_rect(Rect2(tp, Vector2(tw, 26)), Color(0.02, 0.03, 0.035, 0.78))
		_fx.draw_string(f, tp + Vector2(10, 19), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.88, 0.6))
