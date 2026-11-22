class_name SonarConsole
extends Control
## Sonar and tactical console: broadband waterfall, narrowband display,
## geographic plot with uncertainty ellipses and a contact list. Contacts are
## staged from the visible ships plus two ambient tracks; nothing is simulated.

const ROWS := 240
const ROW_TIME := 0.5

var sub: Submarine
var ships: Array[Node3D] = []

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
var _contacts: Array[Dictionary] = []
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

	_contacts = [
		{"id": "S-01", "class": "MERCHANT", "detail": "1 SHAFT · 5 BLADE · SLOW DIESEL", "tonals": [7.8, 15.6, 23.4, 50.0, 100.0, 150.0, 0.0, 0.0], "lv": [0.9, 0.6, 0.4, 0.8, 0.5, 0.3, 0.0, 0.0], "level": 0.95, "q": 0.25, "src": 0},
		{"id": "S-02", "class": "WARSHIP", "detail": "FRIGATE · GAS TURBINE · CPP", "tonals": [11.0, 22.0, 60.0, 120.0, 180.0, 333.0, 0.0, 0.0], "lv": [0.6, 0.5, 0.9, 0.6, 0.35, 0.5, 0.0, 0.0], "level": 0.7, "q": 0.1, "src": 1},
		{"id": "S-03", "class": "BIOLOGIC", "detail": "WHALE SONG · INTERMITTENT", "tonals": [18.0, 36.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "lv": [0.5, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "level": 0.35, "q": 0.0, "src": -1, "brg": 212.0},
		{"id": "S-04", "class": "UNKNOWN", "detail": "FAINT · SUBMERGED?  · 1 TONAL", "tonals": [43.7, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "lv": [0.45, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "level": 0.22, "q": 0.0, "src": -1, "brg": 74.0},
	]
	visibility_changed.connect(func() -> void: set_process(true))


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_Q or k == KEY_PAGEUP:
			selected = posmod(selected - 1, _contacts.size())
			return true
		if k == KEY_E or k == KEY_PAGEDOWN:
			selected = posmod(selected + 1, _contacts.size())
			return true
	return false


func contact_bearing(c: Dictionary) -> float:
	var src := int(c["src"])
	if src >= 0 and src < ships.size():
		var rel := ships[src].global_position - sub.global_position
		return fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
	return fposmod(float(c["brg"]) + sin(_time * 0.01 + float(c["level"]) * 10.0) * 4.0, 360.0)


func _bearing_at(c: Dictionary, t_back: float) -> float:
	if t_back <= 0.0:
		return contact_bearing(c)
	var src := int(c["src"])
	if src >= 0 and src < ships.size():
		var ship := ships[src] as SurfaceShip
		var sp := ship.global_position - ship.forward() * ship.speed * t_back
		var op := sub.global_position - sub.forward() * sub.speed * t_back
		var rel := sp - op
		return fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
	return fposmod(float(c["brg"]) + sin((_time - t_back) * 0.01 + float(c["level"]) * 10.0) * 4.0 - t_back * 0.02, 360.0)


func contact_range(c: Dictionary) -> float:
	var src := int(c["src"])
	if src >= 0 and src < ships.size():
		return (ships[src].global_position - sub.global_position).length()
	return 9000.0 if String(c["class"]) == "BIOLOGIC" else 14000.0


func _process(delta: float) -> void:
	_time += delta
	for c in _contacts:
		c["q"] = minf(float(c["q"]) + delta * (0.012 if int(c["src"]) >= 0 else 0.003), 0.97)
	_row_t += delta
	_scroll += delta * 2.0
	if _row_t >= ROW_TIME:
		_row_t -= ROW_TIME
		_push_row()
	if not visible:
		return
	_layout()
	_water_mat.set_shader_parameter("frac", _row_t / ROW_TIME)
	_water_mat.set_shader_parameter("heading_deg", fposmod(rad_to_deg(sub.heading), 360.0))
	_water_mat.set_shader_parameter("selected_bearing", contact_bearing(_contacts[selected]))
	_water_mat.set_shader_parameter("self_noise", clampf(sub.knots() / 15.0, 0.0, 1.0))
	var c := _contacts[selected]
	var t: Array = c["tonals"]
	var lv: Array = c["lv"]
	_lofar_mat.set_shader_parameter("tonals_a", Vector4(t[0], t[1], t[2], t[3]))
	_lofar_mat.set_shader_parameter("tonals_b", Vector4(t[4], t[5], t[6], t[7]))
	_lofar_mat.set_shader_parameter("levels_a", Vector4(lv[0], lv[1], lv[2], lv[3]))
	_lofar_mat.set_shader_parameter("levels_b", Vector4(lv[4], lv[5], lv[6], lv[7]))
	_lofar_mat.set_shader_parameter("scroll", _scroll)
	_lofar_mat.set_shader_parameter("strength", 0.6 + 0.4 * float(c["level"]))
	queue_redraw()
	_plot.queue_redraw()


## Fill the waterfall with plausible past bearings so it opens full of history.
func prefill() -> void:
	if sub == null:
		return
	for r in range(ROWS - 1, -1, -1):
		_push_row(float(r) * ROW_TIME, false)
	_hist_tex.update(_hist_img)


func _push_row(t_back: float = 0.0, upload: bool = true) -> void:
	_head = (_head + 1) % ROWS
	_total += 1.0
	for i in 8:
		var col := Color(0, 0, 0, 0)
		if i < _contacts.size():
			var c := _contacts[i]
			var lvl := float(c["level"])
			if String(c["class"]) == "BIOLOGIC":
				lvl *= 0.5 + 0.5 * sin(_total * 0.07)
			var rng := contact_range(c)
			lvl *= clampf(6000.0 / maxf(rng, 500.0), 0.35, 1.2)
			col = Color(_bearing_at(c, t_back) / 360.0, lvl, 0.15 if String(c["class"]) == "UNKNOWN" else 0.3, 1.0)
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
	draw_string(f, Vector2(420, 44), "VARG  S-31     BOW ARRAY: ACTIVE     FLANK: ACTIVE     TOWED: STOWED     SELF NOISE: %s" % ("LOW" if sub.knots() < 7.0 else "ELEVATED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, dim)
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
		var c := _contacts[i]
		var bx := wr.position.x + wr.size.x * contact_bearing(c) / 360.0
		var colr := UiStyle.AMBER if i == selected else UiStyle.GREEN
		draw_colored_polygon(PackedVector2Array([Vector2(bx, wr.position.y - 2), Vector2(bx - 5, wr.position.y - 10), Vector2(bx + 5, wr.position.y - 10)]), colr)
		draw_string(f, Vector2(bx - 20, wr.position.y - 14), String(c["id"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, colr)

	# Narrowband frame.
	var lr := Rect2(_lofar.position, _lofar.size)
	draw_string(fd, Vector2(lr.position.x, lr.position.y - 12), "NARROWBAND  ·  %s  ·  0–400 HZ" % String(_contacts[selected]["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.AMBER)
	draw_rect(lr.grow(1), UiStyle.LINE, false, 1.0)
	for hz in range(0, 401, 50):
		var x2 := lr.position.x + lr.size.x * hz / 400.0
		draw_string(f, Vector2(x2 - 14, lr.end.y + 16), str(hz), HORIZONTAL_ALIGNMENT_CENTER, 28, 10, dim)

	# Contact list.
	var ly := vp.y - 200.0
	draw_line(Vector2(36, ly - 26), Vector2(vp.x - 36, ly - 26), UiStyle.LINE, 1.0)
	draw_string(fd, Vector2(36, ly - 36), "CONTACTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cyan)
	var hdr := "TRACK   BRG     B-RATE    CLASSIFICATION                 RANGE EST      SOLUTION    NOTES"
	draw_string(f, Vector2(36, ly), hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	for i in _contacts.size():
		var c2 := _contacts[i]
		var y2 := ly + 28.0 + i * 26.0
		if i == selected:
			draw_rect(Rect2(30, y2 - 18, vp.x - 60, 24), Color(1.0, 0.7, 0.3, 0.1))
		var q := float(c2["q"])
		var rng_txt := "  ----   " if q < 0.3 else "%5.1f KM " % (contact_range(c2) / 1000.0 * (1.0 + (1.0 - q) * 0.4))
		var rate := sin(_time * 0.02 + i) * 0.4
		var line := "%-6s  %05.1f   %+4.1f°/M   %-28s   %s      %3d%%       %s" % [String(c2["id"]), contact_bearing(c2), rate, String(c2["class"]), rng_txt, int(q * 100.0), String(c2["detail"])]
		draw_string(f, Vector2(36, y2), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.AMBER if i == selected else UiStyle.WHITE)
	draw_string(f, Vector2(36, vp.y - 30), "Q / E  SELECT CONTACT      ·      STAGED DISPLAY: NO ACOUSTIC SIMULATION IN THIS PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)


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
		var ct := _contacts[i]
		var brg := deg_to_rad(contact_bearing(ct))
		var dir := Vector2(sin(brg), -cos(brg))
		var colr := UiStyle.AMBER if i == selected else UiStyle.GREEN
		_plot.draw_line(c, c + dir * minf(s.x, s.y) * 0.46, Color(colr.r, colr.g, colr.b, 0.22), 1.0)
		var q := float(ct["q"])
		if q < 0.25:
			continue
		var rng := contact_range(ct) * (1.0 + (1.0 - q) * 0.35)
		var p := c + dir * rng * scale
		var along := (1.0 - q) * 2600.0 * scale + 4.0
		var across := (1.0 - q) * 500.0 * scale + 3.0
		var pts := PackedVector2Array()
		for k in 33:
			var a := TAU * k / 32.0
			pts.append(p + dir * cos(a) * along + Vector2(-dir.y, dir.x) * sin(a) * across)
		_plot.draw_polyline(pts, Color(colr.r, colr.g, colr.b, 0.7), 1.0)
		_plot.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), colr, false, 1.5)
		_plot.draw_string(f, p + Vector2(8, -6), String(ct["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, colr)
