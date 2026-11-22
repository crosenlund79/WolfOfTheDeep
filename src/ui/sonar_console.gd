class_name SonarConsole
extends Control
## Sonar and tactical console: broadband waterfall, narrowband display,
## geographic plot with uncertainty ellipses and a contact list. Contacts are
## staged from the visible ships plus two ambient tracks; nothing is simulated.

const ROWS := 240
const ROW_TIME := 0.5

var sub: Submarine
var ships: Array[Node3D] = []
var sensors: SensorSuite
var crew: Crew

var selected := 0
var _hist_img: Image
var _hist_tex: ImageTexture
var _head := 0
var _total := 0.0
var _row_t := 0.0
var _time := 0.0
var _water: ColorRect
var _water_mat: ShaderMaterial
var _lofar: ColorRect
var _lofar_mat: ShaderMaterial
var _plot: Control
var _contacts: Array = []
var _scroll := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hist_img = Image.create(8, ROWS, false, Image.FORMAT_RGBAF)
	_hist_img.fill(Color(0, 0, 0, 0))
	_hist_tex = ImageTexture.create_from_image(_hist_img)

	_water = ColorRect.new()
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://src/ui/waterfall.gdshader")
	_water_mat.set_shader_parameter("history", _hist_tex)
	_water_mat.set_shader_parameter("rows", ROWS)
	_water.material = _water_mat
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_water)

	_lofar = ColorRect.new()
	_lofar_mat = ShaderMaterial.new()
	_lofar_mat.shader = load("res://src/ui/lofar.gdshader")
	_lofar.material = _lofar_mat
	_lofar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lofar)

	_plot = Control.new()
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot.draw.connect(_draw_plot)
	add_child(_plot)

	visibility_changed.connect(func() -> void: set_process(true))


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		var n := maxi(_contacts.size(), 1)
		if k == KEY_Q or k == KEY_PAGEUP:
			selected = posmod(selected - 1, n)
			return true
		if k == KEY_E or k == KEY_PAGEDOWN:
			selected = posmod(selected + 1, n)
			return true
	return false

func contact_bearing(c: Contact) -> float:
	return c.bearing

func _bearing_at(c: Contact, _t_back: float) -> float:
	return c.bearing

func contact_range(c: Contact) -> float:
	return c.range_est

func _process(delta: float) -> void:
	_time += delta
	_contacts.clear()
	if sensors:
		for c in sensors.contacts:
			if c.kind == "VESSEL" and _contacts.size() < 8:
				_contacts.append(c)
	_row_t += delta
	_scroll += delta * 2.0
	if _row_t >= ROW_TIME:
		_row_t -= ROW_TIME
		_push_row()
	if not visible:
		return
	_layout()
	selected = clampi(selected, 0, maxi(_contacts.size() - 1, 0))
	_water_mat.set_shader_parameter("frac", _row_t / ROW_TIME)
	_water_mat.set_shader_parameter("heading_deg", fposmod(rad_to_deg(sub.heading), 360.0))
	_water_mat.set_shader_parameter("self_noise", clampf(sub.knots() / 15.0, 0.0, 1.0))
	var tonals := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var levels := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if not _contacts.is_empty():
		var c: Contact = _contacts[selected]
		_water_mat.set_shader_parameter("selected_bearing", c.bearing)
		if c.status == "TRACKING" and c.sources.has("sonar") and c.vessel:
			var sig := _signature(c.vessel)
			tonals = sig[0]
			levels = sig[1]
	else:
		_water_mat.set_shader_parameter("selected_bearing", -1.0)
	_lofar_mat.set_shader_parameter("tonals_a", Vector4(tonals[0], tonals[1], tonals[2], tonals[3]))
	_lofar_mat.set_shader_parameter("tonals_b", Vector4(tonals[4], tonals[5], tonals[6], tonals[7]))
	_lofar_mat.set_shader_parameter("levels_a", Vector4(levels[0], levels[1], levels[2], levels[3]))
	_lofar_mat.set_shader_parameter("levels_b", Vector4(levels[4], levels[5], levels[6], levels[7]))
	_lofar_mat.set_shader_parameter("scroll", _scroll)
	_lofar_mat.set_shader_parameter("strength", 1.0)
	queue_redraw()
	_plot.queue_redraw()


static func _signature(v: SurfaceShip) -> Array:
	match v.kind:
		SurfaceShip.Kind.MERCHANT:
			return [[7.8, 15.6, 23.4, 50.0, 100.0, 150.0, 0.0, 0.0], [0.9, 0.6, 0.4, 0.8, 0.5, 0.3, 0.0, 0.0]]
		SurfaceShip.Kind.TRAWLER:
			return [[12.5, 25.0, 37.5, 60.0, 180.0, 245.0, 0.0, 0.0], [0.7, 0.5, 0.3, 0.7, 0.4, 0.5, 0.0, 0.0]]
		SurfaceShip.Kind.RESEARCH:
			return [[9.0, 18.0, 50.0, 133.0, 266.0, 312.0, 0.0, 0.0], [0.6, 0.4, 0.8, 0.5, 0.3, 0.6, 0.0, 0.0]]
		_:
			return [[11.0, 22.0, 60.0, 120.0, 333.0, 0.0, 0.0, 0.0], [0.4, 0.3, 0.6, 0.4, 0.3, 0.0, 0.0, 0.0]]


func _push_row(_t_back: float = 0.0, upload: bool = true) -> void:
	_head = (_head + 1) % ROWS
	_total += 1.0
	for i in 8:
		var col := Color(0, 0, 0, 0)
		if i < _contacts.size():
			var c: Contact = _contacts[i]
			if c.status == "TRACKING" and c.sources.has("sonar"):
				var lvl := clampf(0.35 + c.snr / 14.0, 0.15, 1.2)
				col = Color(c.bearing / 360.0, lvl, 0.3, 1.0)
		_hist_img.set_pixel(i, _head, col)
	if upload:
		_hist_tex.update(_hist_img)
	_water_mat.set_shader_parameter("head", _head)
	_water_mat.set_shader_parameter("total", _total)

func _layout() -> void:
	var vp := get_viewport_rect().size
	var m := 36.0
	var top := 96.0
	var wf_w := vp.x * 0.56
	var wf_h := vp.y - top - 260.0
	_water.position = Vector2(m + 46.0, top + 34.0)
	_water.size = Vector2(wf_w - 46.0, wf_h - 34.0)
	var rx := m + wf_w + 28.0
	var rw := vp.x - rx - m
	_plot.position = Vector2(rx, top)
	_plot.size = Vector2(rw, rw * 0.78)
	_lofar.position = Vector2(rx, top + rw * 0.78 + 46.0)
	_lofar.size = Vector2(rw, vp.y - (top + rw * 0.78 + 46.0) - 230.0)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.012, 0.02, 0.028))
	# Subtle vertical gradient and panel frames.
	for i in 12:
		draw_rect(Rect2(0, vp.y * i / 12.0, vp.x, vp.y / 12.0), Color(0.03, 0.05, 0.07, 0.04 * (12 - i) / 12.0))
	var f := UiStyle.mono()
	var fd := UiStyle.display()
	var cyan := UiStyle.CYAN
	var dim := UiStyle.DIM
	# Title bar.
	draw_rect(Rect2(0, 0, vp.x, 70), Color(0.02, 0.04, 0.055))
	draw_line(Vector2(0, 70), Vector2(vp.x, 70), UiStyle.LINE, 1.0)
	draw_string(fd, Vector2(36, 44), "SONAR  ·  TMA  ·  TACTICAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.WHITE)
	draw_string(f, Vector2(420, 44), "VARG  S-31     BOW ARRAY: ACTIVE     FLANK: ACTIVE     SELF NOISE: %s     LAYER: %s" % ["LOW" if sub.knots() < 7.0 else "ELEVATED", "BELOW" if sub.depth > Submarine.LAYER_DEPTH else "ABOVE"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, dim)
	draw_string(f, Vector2(vp.x - 330, 44), "DEPTH %5.1f M   SPD %4.1f KT" % [sub.depth, sub.knots()], HORIZONTAL_ALIGNMENT_RIGHT, 300, 13, cyan)

	# Waterfall frame + bearing scale.
	var wr := Rect2(_water.position, _water.size)
	draw_string(fd, Vector2(wr.position.x - 46, wr.position.y - 14), "BROADBAND  ·  BEARING / TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cyan)
	draw_rect(wr.grow(1), UiStyle.LINE, false, 1.0)
	for b in range(0, 361, 30):
		var x := wr.position.x + wr.size.x * b / 360.0
		draw_line(Vector2(x, wr.end.y), Vector2(x, wr.end.y + 8), dim, 1.0)
		draw_string(f, Vector2(x - 14, wr.end.y + 24), "%03d" % (b % 360), HORIZONTAL_ALIGNMENT_CENTER, 28, 11, dim)
	for tmin in range(0, 3):
		var y := wr.position.y + wr.size.y * float(tmin) / 2.0
		draw_string(f, Vector2(wr.position.x - 44, y + 4), "-%d:00" % (tmin), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	# Contact tags along the top of the waterfall.
	for i in _contacts.size():
		var c: Contact = _contacts[i]
		if c.status != "TRACKING":
			continue
		var bx := wr.position.x + wr.size.x * contact_bearing(c) / 360.0
		var colr := UiStyle.AMBER if i == selected else UiStyle.GREEN
		draw_colored_polygon(PackedVector2Array([Vector2(bx, wr.position.y - 2), Vector2(bx - 5, wr.position.y - 10), Vector2(bx + 5, wr.position.y - 10)]), colr)
		draw_string(f, Vector2(bx - 20, wr.position.y - 14), c.id, HORIZONTAL_ALIGNMENT_CENTER, 40, 11, colr)

	# Narrowband frame.
	var lr := Rect2(_lofar.position, _lofar.size)
	draw_string(fd, Vector2(lr.position.x, lr.position.y - 12), "NARROWBAND  ·  %s  ·  0–400 HZ" % ((_contacts[selected] as Contact).id if not _contacts.is_empty() else "NO CONTACT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.AMBER)
	draw_rect(lr.grow(1), UiStyle.LINE, false, 1.0)
	for hz in range(0, 401, 50):
		var x2 := lr.position.x + lr.size.x * hz / 400.0
		draw_string(f, Vector2(x2 - 14, lr.end.y + 16), str(hz), HORIZONTAL_ALIGNMENT_CENTER, 28, 10, dim)

	# Contact list.
	var ly := vp.y - 200.0
	draw_line(Vector2(36, ly - 26), Vector2(vp.x - 36, ly - 26), UiStyle.LINE, 1.0)
	draw_string(fd, Vector2(36, ly - 36), "CONTACTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cyan)
	var hdr := "TRACK   BRG     SOURCES         CLASSIFICATION       CERTAINTY      RANGE EST     STATUS"
	draw_string(f, Vector2(36, ly), hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	for i in _contacts.size():
		var c2: Contact = _contacts[i]
		var y2 := ly + 24.0 + i * 20.0
		if i == selected:
			draw_rect(Rect2(30, y2 - 15, vp.x - 60, 20), Color(1.0, 0.7, 0.3, 0.1))
		var rng_txt := "  ----   " if c2.range_err > 0.3 else "%5.1f KM ±%d%%" % [c2.range_est / 1000.0, int(c2.range_err * 100.0)]
		var src := " ".join(c2.sources.keys()).to_upper()
		var line := "%-6s  %05.1f   %-14s  %-19s  %-13s  %-13s %s" % [c2.id, c2.bearing, src, c2.label().substr(0, 19), c2.certainty_text(), rng_txt, c2.status]
		draw_string(f, Vector2(36, y2), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.DIM if c2.status == "LOST" else (UiStyle.AMBER if i == selected else UiStyle.WHITE))
	var op := crew.role_holder("SONAR") if crew else null
	var who := "%s  (%s)" % [op.short, op.rank] if op else "UNMANNED  —  AUTOMATIC DETECTION ONLY"
	draw_string(f, Vector2(36, vp.y - 30), "Q / E  SELECT CONTACT      ·      ON SONAR:  " + who, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)


func _draw_plot() -> void:
	var s := _plot.size
	var c := s * 0.5
	var f := UiStyle.mono()
	_plot.draw_rect(Rect2(Vector2.ZERO, s), Color(0.015, 0.03, 0.04))
	_plot.draw_rect(Rect2(Vector2.ZERO, s), UiStyle.LINE, false, 1.0)
	_plot.draw_string(UiStyle.display(), Vector2(10, 22), "GEOGRAPHIC PLOT  ·  10 KM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.CYAN)
	var scale := minf(s.x, s.y) * 0.46 / 10000.0
	for r in [2500.0, 5000.0, 7500.0, 10000.0]:
		_plot.draw_arc(c, r * scale, 0.0, TAU, 96, Color(0.25, 0.45, 0.55, 0.35), 1.0)
		_plot.draw_string(f, c + Vector2(4, -r * scale - 3), "%d" % int(r / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.DIM)
	_plot.draw_line(Vector2(c.x, 30), Vector2(c.x, s.y - 6), Color(0.25, 0.45, 0.55, 0.25), 1.0)
	_plot.draw_line(Vector2(6, c.y), Vector2(s.x - 6, c.y), Color(0.25, 0.45, 0.55, 0.25), 1.0)
	_plot.draw_string(f, Vector2(c.x - 4, 42), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
	# Own ship.
	var hd := sub.heading
	var fwd := Vector2(sin(hd), -cos(hd))
	var rt := Vector2(-fwd.y, fwd.x)
	_plot.draw_colored_polygon(PackedVector2Array([c + fwd * 10.0, c - fwd * 6.0 + rt * 5.0, c - fwd * 6.0 - rt * 5.0]), UiStyle.CYAN)
	_plot.draw_line(c, c + fwd * 60.0, Color(0.42, 0.86, 1.0, 0.6), 1.0)
	# Contacts: bearing lines, then position estimates with uncertainty.
	for i in _contacts.size():
		var ct: Contact = _contacts[i]
		if ct.status != "TRACKING":
			continue
		var brg := deg_to_rad(contact_bearing(ct))
		var dir := Vector2(sin(brg), -cos(brg))
		var colr := UiStyle.AMBER if i == selected else UiStyle.GREEN
		_plot.draw_line(c, c + dir * minf(s.x, s.y) * 0.46, Color(colr.r, colr.g, colr.b, 0.22), 1.0)
		if ct.range_err > 0.3:
			continue
		var rng := contact_range(ct)
		var p := c + dir * rng * scale
		var along := ct.range_err * rng * scale + 4.0
		var across := along * 0.3 + 3.0
		var pts := PackedVector2Array()
		for k in 33:
			var a := TAU * k / 32.0
			pts.append(p + dir * cos(a) * along + Vector2(-dir.y, dir.x) * sin(a) * across)
		_plot.draw_polyline(pts, Color(colr.r, colr.g, colr.b, 0.7), 1.0)
		_plot.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), colr, false, 1.5)
		_plot.draw_string(f, p + Vector2(8, -6), ct.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, colr)
