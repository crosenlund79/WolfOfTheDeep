class_name ChartView
extends Control
## Navigation chart (Maya's station). Shows what the boat KNOWS: estimated
## contact positions with uncertainty, detected ice only, and our own dead-
## reckoning uncertainty. Click to order a course, Shift+click to lay a route.

signal course_ordered(heading_rad: float)
signal route_changed

var main: Node
var area: ArcticArea
var sub: Submarine
var sensors: SensorSuite
var route: Array[Vector3] = []
var marks: Array[Dictionary] = []   # {pos, label, color}
var sector_center := Vector3.ZERO
var sector_radius := 0.0
var rv_point := Vector3.ZERO
var dr_error := 20.0
var planned_knots := 9.0


func focus_on(p: Vector3) -> void:
	_follow = false
	_center = Vector2(p.x, p.z)

var _tex: ImageTexture
var _center := Vector2.ZERO
var _mpp := 40.0
var _panning := false
var _follow := true

const TEX_RES := 384


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func build_texture() -> void:
	var img := Image.create(TEX_RES, TEX_RES, false, Image.FORMAT_RGB8)
	var half := ArcticArea.HALF
	for j in TEX_RES:
		for i in TEX_RES:
			var x := -half + (float(i) + 0.5) / TEX_RES * half * 2.0
			var z := -half + (float(j) + 0.5) / TEX_RES * half * 2.0
			var d := area.seabed_depth(x, z)
			var c: Color
			if area.coast_distance(x, z) <= 0.0:
				var h := area.terrain_height(x, z)
				c = Color(0.62, 0.6, 0.55).lerp(Color(0.85, 0.86, 0.88), clampf(h / 500.0, 0.0, 1.0))
			else:
				var t := clampf(d / 400.0, 0.0, 1.0)
				c = Color(0.36, 0.58, 0.68).lerp(Color(0.05, 0.13, 0.22), pow(t, 0.55))
				for contour in [20.0, 50.0, 100.0, 200.0]:
					if absf(d - contour) < contour * 0.03 + 1.0:
						c = c.lerp(Color(0.75, 0.85, 0.9), 0.45)
			if z < area.ice_edge_z(x) + 1500.0 and area.coast_distance(x, z) > 0.0:
				var into := clampf((area.ice_edge_z(x) + 1500.0 - z) / 6000.0, 0.0, 1.0)
				if (i + j) % 6 == 0 or into > 0.7:
					c = c.lerp(Color(0.88, 0.92, 0.95), 0.35 + into * 0.4)
			img.set_pixel(i, j, c)
	_tex = ImageTexture.create_from_image(img)


func world_to_screen(p: Vector3) -> Vector2:
	return size * 0.5 + (Vector2(p.x, p.z) - _center) / _mpp


func screen_to_world(s: Vector2) -> Vector3:
	var w := _center + (s - size * 0.5) * _mpp
	return Vector3(w.x, 0.0, w.y)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_mpp = maxf(_mpp * 0.85, 4.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_mpp = minf(_mpp * 1.18, 160.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			if mb.pressed:
				_follow = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var w := screen_to_world(mb.position)
			if mb.shift_pressed:
				route.append(w)
				route_changed.emit()
			else:
				route.clear()
				route_changed.emit()
				var rel := w - sub.global_position
				course_ordered.emit(atan2(rel.x, -rel.z))
		accept_event()
	elif event is InputEventMouseMotion and _panning:
		_center -= (event as InputEventMouseMotion).relative * _mpp
		accept_event()


func handle_key(k: int) -> bool:
	if k == KEY_C:
		_follow = true
		return true
	if k == KEY_BACKSPACE or k == KEY_DELETE:
		route.clear()
		route_changed.emit()
		return true
	return false


func _process(_delta: float) -> void:
	if not visible:
		return
	if _follow and sub:
		_center = Vector2(sub.global_position.x, sub.global_position.z)
	queue_redraw()


static func latlon(p: Vector3) -> String:
	var lat := 76.5 - p.z / 111000.0
	var lon := 25.0 + p.x / (111000.0 * cos(deg_to_rad(lat)))
	return "%02d°%04.1f'N  %03d°%04.1f'E" % [int(lat), fposmod(lat * 60.0, 60.0), int(lon), fposmod(lon * 60.0, 60.0)]


func _draw() -> void:
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.05, 0.08))
	if _tex:
		var tl := world_to_screen(Vector3(-ArcticArea.HALF, 0, -ArcticArea.HALF))
		var br := world_to_screen(Vector3(ArcticArea.HALF, 0, ArcticArea.HALF))
		draw_texture_rect(_tex, Rect2(tl, br - tl), false)
	var f := UiStyle.mono()
	var fd := UiStyle.display()
	var ink := Color(0.88, 0.94, 1.0, 0.85)
	# Grid every 2 km.
	var step := 2000.0
	var x0 := floorf(screen_to_world(Vector2.ZERO).x / step) * step
	var x := x0
	while x < screen_to_world(vp).x:
		var sx := world_to_screen(Vector3(x, 0, 0)).x
		draw_line(Vector2(sx, 0), Vector2(sx, vp.y), Color(1, 1, 1, 0.06), 1.0)
		x += step
	var z := floorf(screen_to_world(Vector2.ZERO).z / step) * step
	while z < screen_to_world(vp).z:
		var sy := world_to_screen(Vector3(0, 0, z)).y
		draw_line(Vector2(0, sy), Vector2(vp.x, sy), Color(1, 1, 1, 0.06), 1.0)
		z += step
	# Patrol sector and rendezvous.
	if sector_radius > 0.0:
		var sc := world_to_screen(sector_center)
		draw_arc(sc, sector_radius / _mpp, 0.0, TAU, 96, Color(1.0, 0.75, 0.3, 0.7), 2.0)
		draw_string(fd, sc + Vector2(-60, -sector_radius / _mpp - 8), "PATROL SECTOR KESTREL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.75, 0.3))
	var rv := world_to_screen(rv_point)
	draw_arc(rv, 9.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.6), 2.0)
	draw_string(fd, rv + Vector2(12, 4), "RV  HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 1.0, 0.6))
	draw_string(fd, world_to_screen(Vector3(ArcticArea.ISLAND_C.x - 900, 0, ArcticArea.ISLAND_C.y)), "RAVNØYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.2, 0.2))
	draw_string(f, world_to_screen(Vector3(ArcticArea.BANK_C.x - 900, 0, ArcticArea.BANK_C.y)), "KESTREL BANK  38", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.95, 1.0, 0.7))
	draw_string(f, world_to_screen(Vector3(ArcticArea.ROCK_C.x + 80, 0, ArcticArea.ROCK_C.y)), "x ROCK 6 M", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.5, 0.4))
	draw_string(f, world_to_screen(Vector3(-4000, 0, area.ice_edge_z(-4000.0) - 600.0)), "MARGINAL ICE ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.97, 1.0, 0.85))
	for m in marks:
		var mp := world_to_screen(m["pos"])
		draw_circle(mp, 4.0, m["color"])
		draw_string(f, mp + Vector2(8, 4), String(m["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, m["color"])
	# Route.
	var prev := world_to_screen(sub.global_position)
	for wp in route:
		var sp := world_to_screen(wp)
		draw_dashed_line(prev, sp, Color(0.4, 0.9, 1.0, 0.8), 2.0, 8.0)
		draw_circle(sp, 4.0, Color(0.4, 0.9, 1.0))
		prev = sp
	# Contacts (estimates).
	if sensors:
		for c in sensors.contacts:
			_draw_contact(c, f)
	# Own ship with dead-reckoning uncertainty.
	var op := world_to_screen(sub.global_position)
	draw_arc(op, maxf(dr_error / _mpp, 3.0), 0.0, TAU, 32, Color(0.4, 0.9, 1.0, 0.45), 1.0)
	var hd := sub.heading
	var fw := Vector2(sin(hd), -cos(hd))
	var rt := Vector2(-fw.y, fw.x)
	draw_colored_polygon(PackedVector2Array([op + fw * 11.0, op - fw * 7.0 + rt * 5.0, op - fw * 7.0 - rt * 5.0]), Color(0.4, 0.9, 1.0))
	var oc := Vector2(sin(sub.ordered_heading), -cos(sub.ordered_heading))
	draw_dashed_line(op, op + oc * 160.0, Color(0.4, 0.9, 1.0, 0.6), 1.5, 6.0)
	# Scale bar.
	var bar_m := 2000.0 if _mpp > 15.0 else 500.0
	draw_line(Vector2(30, vp.y - 40), Vector2(30 + bar_m / _mpp, vp.y - 40), ink, 2.0)
	draw_string(f, Vector2(30, vp.y - 48), "%d M" % int(bar_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	_draw_panel(f, fd)


func _draw_contact(c: Contact, f: Font) -> void:
	var col := Color(1.0, 0.75, 0.3)
	if c.kind == "ICE":
		var p := world_to_screen(c.est_pos)
		var r := maxf(float(c.berg.get("r", 30.0)) * 1.3 / _mpp, 3.0)
		draw_circle(p, r, Color(0.92, 0.96, 1.0, 0.85))
		draw_string(f, p + Vector2(r + 3, 3), c.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.95, 1.0, 0.8))
		return
	if c.status == "LOST":
		col = Color(0.6, 0.6, 0.6, 0.6)
	elif c.classification == "WARSHIP" or c.classification == "SUBMARINE":
		col = Color(1.0, 0.4, 0.35)
	var own := world_to_screen(sub.global_position)
	if c.range_err > 0.3 and c.status != "LOST":
		# Bearing only: we know the direction, not the distance.
		var dir := Vector2(sin(deg_to_rad(c.bearing)), -cos(deg_to_rad(c.bearing)))
		draw_line(own, own + dir * 2200.0, Color(col.r, col.g, col.b, 0.35), 1.0)
		draw_string(f, own + dir * minf(220.0, size.x * 0.3), "%s  BRG %03d" % [c.id, int(c.bearing)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		return
	var p2 := world_to_screen(c.est_pos)
	var along := maxf(c.range_err * c.range_est / _mpp, 4.0)
	var across := maxf(along * 0.35, 3.0)
	var dir2 := (p2 - own).normalized() if p2.distance_to(own) > 1.0 else Vector2.UP
	var pts := PackedVector2Array()
	for k in 25:
		var a := TAU * float(k) / 24.0
		pts.append(p2 + dir2 * cos(a) * along + Vector2(-dir2.y, dir2.x) * sin(a) * across)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.7), 1.0)
	draw_rect(Rect2(p2 - Vector2(4, 4), Vector2(8, 8)), col, false, 1.5)
	var tag := "%s %s" % [c.id, c.label()]
	if c.status == "LOST":
		tag += "  (LOST)"
	draw_string(f, p2 + Vector2(8, -6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _draw_panel(f: Font, fd: Font) -> void:
	var x := size.x - 380.0
	draw_rect(Rect2(x - 16, 80, 380, 470), Color(0.01, 0.03, 0.05, 0.82))
	draw_string(fd, Vector2(x, 108), "NAVIGATION  ·  LT CHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.CYAN)
	var under := area.seabed_depth(sub.global_position.x, sub.global_position.z) - sub.depth - 4.0
	var lines := [
		"POSITION  %s" % latlon(sub.global_position),
		"DR ERROR  ±%d M  %s" % [int(dr_error), "(FIX NEEDED)" if dr_error > 400.0 else ""],
		"COURSE    %03d   ORDERED %03d" % [int(fposmod(rad_to_deg(sub.heading), 360.0)), int(fposmod(rad_to_deg(sub.ordered_heading), 360.0))],
		"SPEED     %4.1f KT  %s" % [sub.knots(), sub.speed_label()],
		"DEPTH     %5.1f M   UNDER KEEL %d M" % [sub.depth, int(under)],
		"SECTOR    %.1f KM" % (Vector2(sub.global_position.x - sector_center.x, sub.global_position.z - sector_center.z).length() / 1000.0),
		"RV        %.1f KM" % (Vector2(sub.global_position.x - rv_point.x, sub.global_position.z - rv_point.z).length() / 1000.0),
	]
	var y := 136.0
	for l in lines:
		draw_string(f, Vector2(x, y), String(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.WHITE if not String(l).contains("NEEDED") else UiStyle.AMBER)
		y += 20.0
	y += 10.0
	draw_string(fd, Vector2(x, y), "CONTACTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.CYAN)
	y += 20.0
	if sensors:
		var n := 0
		for c in sensors.contacts:
			if c.kind == "ICE" or n > 9:
				continue
			var rng_txt := "----" if c.range_err > 0.3 else "%4.1f" % (c.range_est / 1000.0)
			var t := "%-4s %-10s BRG %03d  RNG %s  %s" % [c.id, c.label().substr(0, 10), int(c.bearing), rng_txt, "LOST" if c.status == "LOST" else c.certainty_text()]
			draw_string(f, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, 370, 11, UiStyle.AMBER if c.status != "LOST" else UiStyle.DIM)
			y += 17.0
			n += 1
	draw_string(f, Vector2(x, 535), "CLICK  ORDER COURSE   SHIFT+CLICK  ROUTE   WHEEL  ZOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.DIM)
	draw_string(f, Vector2(x, 548), "RIGHT-DRAG  PAN   C  CENTRE   BACKSPACE  CLEAR ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.DIM)
