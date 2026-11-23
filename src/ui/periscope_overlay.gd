class_name PeriscopeOverlay
extends Control
## Optronic mast view: post-processed camera feed plus a modern stabilised
## sight with bearing tape, auto-tracking boxes and data blocks. Cosmetic.

const MODES := ["TV  DAY", "LLTV", "THERMAL  WH"]

var sub: Submarine
var rig: CameraRig
var ocean: Ocean
var ships: Array[Node3D] = []
var weather: Weather
var encounter: Encounter
## ColorRect provided by main (a sibling below this overlay) for the feed effect.
var post_rect: ColorRect
var mast_submerged := 0.0
var _away_t := 0.0
var _blackout := 0.0

var mode := 0
var _post: ColorRect
var _post_mat: ShaderMaterial
var _sheet := 0.0
var _drain := 1.0
var _drops := 0.0
var _wash := 0.0
var _flash := 0.0
var _rec_t := 0.0
var _marks: Array = []
var _time := 0.0
var _status := ""
var _status_t := 0.0
var _was_submerged := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = post_rect
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://src/ui/periscope_post.gdshader")
	_post.material = _post_mat
	_post.visible = visible
	visibility_changed.connect(_on_visibility)


func on_enter() -> void:
	_rec_t = 0.0
	_set_mode(mode)


func _on_visibility() -> void:
	_post.visible = visible
	if not visible:
		RenderingServer.global_shader_parameter_set("thermal_mode", 0.0)
		if weather:
			weather.thermal = false
	else:
		_set_mode(mode)


func _set_mode(m: int) -> void:
	mode = m
	RenderingServer.global_shader_parameter_set("thermal_mode", 1.0 if m == 2 else 0.0)
	if weather:
		weather.thermal = m == 2
	_post_mat.set_shader_parameter("mode", m)


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_T:
			_set_mode((mode + 1) % MODES.size())
			_say("SENSOR  " + String(MODES[mode]))
			return true
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_mark()
			return true
	return false


func torpedo_away() -> void:
	_away_t = 2.5
	_flash = 0.25


func _say(t: String) -> void:
	_status = t
	_status_t = 2.5


func _mark() -> void:
	_flash = 0.35
	var brg := fposmod(rad_to_deg(rig.bearing), 360.0)
	var best := ""
	for s in ships:
		var ship := s as SurfaceShip
		var rel := ship.global_position - sub.global_position
		if ship.submerged or not ship.visible or rel.length() > 14000.0:
			continue
		var sb := fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		if absf(wrapf(sb - brg, -180.0, 180.0)) < rig.camera.fov * 0.5:
			best = "  ·  %s  ·  EST RANGE %.1f KM" % [ship.contact_name, rel.length() / 1000.0 * randf_range(0.92, 1.08)]
	_marks.append(brg)
	if _marks.size() > 6:
		_marks.pop_front()
	_say("MARK  %03.1f°%s" % [brg, best])


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_rec_t += delta
	_flash = maxf(_flash - delta * 1.6, 0.0)
	_status_t -= delta
	# Water on the window: when the head breaks the surface a film drains from
	# the top and a few droplets run off. Calm sea: almost nothing. Rough sea:
	# more water and the occasional sheet of spray. Nothing stays on the glass.
	var sub_d := clampf(mast_submerged * 3.0, 0.0, 1.0)
	var hs := float(weather.current.get("hs", 1.0)) if weather else 1.0
	var sea := clampf((hs - 0.6) / 3.2, 0.0, 1.0)
	var under := mast_submerged > -0.05
	if under:
		_sheet = 1.0
		_drain = 0.0
		_drops = maxf(_drops, lerpf(0.04, 0.8, sea))
	else:
		_drain = minf(_drain + delta * lerpf(2.6, 0.8, sea), 1.2)
		if _drain >= 1.15:
			_sheet = 0.0
		_drops = maxf(_drops - delta * lerpf(0.5, 0.18, sea), 0.0)
		# Rough sea: spray over a low mast head now and then.
		if sea > 0.45 and mast_submerged > -1.2 and randf() < delta * 0.12 * sea * sea:
			_drops = minf(_drops + 0.35 * sea, 1.0)
			if randf() < 0.5:
				_sheet = 0.45 * sea
				_drain = 0.25
	if _was_submerged and mast_submerged < -0.2:
		_say("MAST CLEAR OF THE SURFACE")
	_was_submerged = mast_submerged > 0.0
	_post_mat.set_shader_parameter("sheet", _sheet if not under else 0.0)
	_post_mat.set_shader_parameter("drain", _drain)
	_post_mat.set_shader_parameter("drops", _drops if not under else 0.0)
	_post_mat.set_shader_parameter("submerged", sub_d)
	_post_mat.set_shader_parameter("time", _time)
	_post_mat.set_shader_parameter("flash", _flash)
	_post_mat.set_shader_parameter("resolution", get_viewport_rect().size)
	_away_t = maxf(_away_t - delta, 0.0)
	var scope := sub.periscope_state()
	var want_black := 1.0 if scope == Submarine.Scope.HOUSED else (0.85 if scope == Submarine.Scope.MOVING else 0.0)
	_blackout = move_toward(_blackout, want_black, delta * 2.5)
	_post_mat.set_shader_parameter("blackout", _blackout)
	queue_redraw()


func _draw() -> void:
	if sub == null or rig == null:
		return
	var vp := get_viewport_rect().size
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var col := Color(0.75, 1.0, 0.85, 0.9) if mode != 2 else Color(1.0, 0.75, 0.3, 0.9)
	var dim := Color(col.r, col.g, col.b, 0.45)
	var f := UiStyle.mono()
	var fd := UiStyle.display()

	# Reticle.
	var g := 26.0
	draw_line(Vector2(cx - 260, cy), Vector2(cx - g, cy), col, 1.2)
	draw_line(Vector2(cx + g, cy), Vector2(cx + 260, cy), col, 1.2)
	draw_line(Vector2(cx, cy - 170), Vector2(cx, cy - g), col, 1.2)
	draw_line(Vector2(cx, cy + g), Vector2(cx, cy + 170), col, 1.2)
	draw_arc(Vector2(cx, cy), 6.0, 0.0, TAU, 24, col, 1.2)
	for i in range(1, 6):
		var x := 260.0 * float(i) / 6.0 + g * 0.4
		var h := 7.0 if i % 2 == 0 else 4.0
		draw_line(Vector2(cx + x, cy - h), Vector2(cx + x, cy + h), dim, 1.0)
		draw_line(Vector2(cx - x, cy - h), Vector2(cx - x, cy + h), dim, 1.0)
	# Stadimeter-style brackets.
	for sgn: float in [-1.0, 1.0]:
		var bx := cx + sgn * 330.0
		draw_line(Vector2(bx, cy - 60), Vector2(bx, cy + 60), dim, 1.0)
		draw_line(Vector2(bx, cy - 60), Vector2(bx - sgn * 14.0, cy - 60), dim, 1.0)
		draw_line(Vector2(bx, cy + 60), Vector2(bx - sgn * 14.0, cy + 60), dim, 1.0)

	# Bearing tape.
	var brg := fposmod(rad_to_deg(rig.bearing), 360.0)
	var fov_h := rad_to_deg(2.0 * atan(tan(deg_to_rad(rig.camera.fov) * 0.5) * vp.x / vp.y))
	var px_per_deg := vp.x / fov_h
	var tape_y := 64.0
	draw_line(Vector2(cx - 520, tape_y), Vector2(cx + 520, tape_y), dim, 1.0)
	var step := 1.0 if fov_h < 12.0 else (5.0 if fov_h < 40.0 else 10.0)
	var start := floorf((brg - 520.0 / px_per_deg) / step) * step
	var d := start
	while d < brg + 520.0 / px_per_deg:
		var x2 := cx + (d - brg) * px_per_deg
		var major := is_zero_approx(fposmod(d, step * 2.0))
		draw_line(Vector2(x2, tape_y), Vector2(x2, tape_y - (12.0 if major else 6.0)), col if major else dim, 1.0)
		if major:
			draw_string(f, Vector2(x2 - 16, tape_y - 18), "%03d" % int(fposmod(d, 360.0)), HORIZONTAL_ALIGNMENT_CENTER, 32, 12, col)
		d += step
	draw_colored_polygon(PackedVector2Array([Vector2(cx, tape_y + 2), Vector2(cx - 7, tape_y + 12), Vector2(cx + 7, tape_y + 12)]), col)
	draw_string(fd, Vector2(cx - 60, tape_y + 34), "%05.1f° T" % brg, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, col)
	for m in _marks:
		var mx := cx + wrapf(float(m) - brg, -180.0, 180.0) * px_per_deg
		if absf(mx - cx) < 520.0:
			draw_colored_polygon(PackedVector2Array([Vector2(mx, tape_y - 2), Vector2(mx - 5, tape_y - 9), Vector2(mx + 5, tape_y - 9)]), Color(1.0, 0.6, 0.3))

	# Elevation scale.
	var ex := vp.x - 90.0
	draw_line(Vector2(ex, cy - 180), Vector2(ex, cy + 180), dim, 1.0)
	for e in range(-10, 11, 5):
		var ey := cy - float(e) * 18.0
		draw_line(Vector2(ex - 6, ey), Vector2(ex + 6, ey), dim, 1.0)
		draw_string(f, Vector2(ex + 10, ey + 4), "%+d" % e, HORIZONTAL_ALIGNMENT_LEFT, 40, 10, dim)
	var el := clampf(rad_to_deg(rig.elevation), -10.0, 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(ex - 8, cy - el * 18.0), Vector2(ex - 18, cy - el * 18.0 - 6), Vector2(ex - 18, cy - el * 18.0 + 6)]), col)

	# Tracking boxes on visible ships.
	var i := 1
	for s in ships:
		var ship := s as SurfaceShip
		var top := ship.global_position + Vector3(0, 22.0, 0)
		if rig.camera.is_position_behind(top):
			continue
		var p := rig.camera.unproject_position(ship.global_position + Vector3(0, 8.0, 0))
		var rel := ship.global_position - sub.global_position
		var dist := rel.length()
		if p.x < 0 or p.x > vp.x or p.y < 0 or p.y > vp.y or mast_submerged > 0.0 or not ship.visible or _blackout > 0.5:
			continue
		# Only what the eye could actually make out: no hulls below the sea,
		# nothing beyond the visibility or the horizon.
		if ship.submerged or dist > minf(weather.visibility_m() * (1.0 - weather.darkness() * 0.6) if weather and weather.arctic else 1e9, 14000.0):
			continue
		var half := clampf(ship.length / dist * px_per_deg * 57.3 * 0.55, 18.0, 400.0)
		var hh := half * 0.45
		var r := Rect2(p - Vector2(half, hh), Vector2(half * 2.0, hh * 2.0))
		var is_locked := encounter != null and encounter.locked == ship
		var bc := Color(1.0, 0.35, 0.25, 1.0) if is_locked else Color(1.0, 0.8, 0.35, 0.95)
		_brackets(r, bc)
		var sb := fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		var tag := "  ·  SINKING" if ship.is_sinking() else ("  ·  LOCKED" if is_locked else "")
		draw_string(f, r.position + Vector2(0, -8), "TRK %02d  ·  %s%s" % [i, ship.contact_name, tag], HORIZONTAL_ALIGNMENT_LEFT, 500, 12, bc)
		draw_string(f, r.position + Vector2(0, r.size.y + 16), "BRG %05.1f   RNG %.1f KM   AOB %s" % [sb, dist / 1000.0, _aob(ship, rel)], HORIZONTAL_ALIGNMENT_LEFT, 400, 11, Color(1.0, 0.8, 0.35, 0.8))
		i += 1

	# Data blocks.
	var zoom := float(rig.zoom_levels[0]) / rig.camera.fov
	_block(Vector2(40, 120), ["OPTRONIC MAST  OM-1", "SENSOR   " + String(MODES[mode]), "ZOOM     %4.1f×   FOV %4.1f°" % [zoom, fov_h], "STAB     GYRO  ON"], col)
	var head := sub.mast_head()
	var wave := ocean.height_at(head.x, head.z) if ocean else 0.0
	var ht := head.y - wave
	var mast_state := "MAST  %+.1f M" % ht if ht > 0.0 else "MAST  AWASH" if ht > -0.6 else "MAST  SUBMERGED"
	_block(Vector2(vp.x - 330, 120), [_clock(), mast_state, "EXPOSURE  %02d:%02d" % [int(_rec_t) / 60, int(_rec_t) % 60], "ESM       NO EMITTERS"], col, true)
	_block(Vector2(40, vp.y - 150), ["OWN SHIP", "DEPTH  %5.1f M" % sub.depth, "SPEED  %4.1f KT" % sub.knots(), "HDG    %03d" % int(fposmod(rad_to_deg(sub.heading), 360.0))], dim)
	draw_string(fd, Vector2(vp.x - 330, vp.y - 120), "●  REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.3, 0.3, 0.5 + 0.5 * sin(_time * 4.0)))
	draw_string(f, Vector2(vp.x - 330, vp.y - 96), "DRAG / Q E TRAIN · WHEEL ZOOM · T SENSOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dim)
	_draw_fire_control(vp, cx, cy, px_per_deg, brg, tape_y)
	var scope := sub.periscope_state()
	var notice := ""
	match scope:
		Submarine.Scope.HOUSED:
			notice = "PERISCOPE LOWERED  —  PRESS M TO RAISE" if sub.depth < 25.0 else "TOO DEEP FOR THE PERISCOPE  —  P  PERISCOPE DEPTH, THEN  M  RAISE"
		Submarine.Scope.MOVING:
			notice = "PERISCOPE " + ("RAISING" if sub.masts_up else "LOWERING") + " …"
		Submarine.Scope.UNDERWATER:
			notice = "PERISCOPE UNDER WATER  —  COME TO PERISCOPE DEPTH  (P)"
	if notice != "":
		draw_string(fd, Vector2(cx - 450, cy + 120), notice, HORIZONTAL_ALIGNMENT_CENTER, 900, 18, col)
	if _status_t > 0.0:
		draw_string(fd, Vector2(cx - 400, vp.y - 110), _status, HORIZONTAL_ALIGNMENT_CENTER, 800, 18, Color(col.r, col.g, col.b, clampf(_status_t, 0.0, 1.0)))


## Fire prompt, solution meter and running-torpedo markers.
func _draw_fire_control(vp: Vector2, cx: float, cy: float, px_per_deg: float, brg: float, tape_y: float) -> void:
	if encounter == null:
		return
	var fd := UiStyle.display()
	var f := UiStyle.mono()
	var amber := Color(1.0, 0.78, 0.35)
	var red := Color(1.0, 0.4, 0.3)
	var by := vp.y - 200.0
	var ready := encounter.can_fire()
	var clear := sub.periscope_state() == Submarine.Scope.CLEAR
	var fire_txt := "WEAPONS TIGHT   ·   SPACE  REQUEST FIRE" if ready else "TUBES RELOADING   %d S" % ceili(encounter.reload)
	draw_string(fd, Vector2(cx - 200, by), fire_txt, HORIZONTAL_ALIGNMENT_CENTER, 400, 20, (red if ready and clear else Color(amber.r, amber.g, amber.b, 0.6)))
	# Solution meter.
	var w := 260.0
	var x0 := cx - w * 0.5
	var y0 := by + 16.0
	draw_rect(Rect2(x0, y0, w, 8), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(x0, y0, w * encounter.solution, 8), amber if encounter.solution < 0.99 else Color(0.45, 1.0, 0.6))
	var sol_txt := "SOLUTION  %d%%" % int(encounter.solution * 100.0)
	if encounter.locked:
		sol_txt += "   ·   TRACKING  " + encounter.locked.contact_name.split("  ")[0]
	else:
		sol_txt += "   ·   PUT THE CROSSHAIR ON A SHIP"
	draw_string(f, Vector2(cx - 300, y0 + 28), sol_txt, HORIZONTAL_ALIGNMENT_CENTER, 600, 12, amber)
	# Running torpedoes on the bearing tape and in view.
	var n := 1
	for t in encounter.torpedoes:
		if not is_instance_valid(t) or t.done:
			continue
		var rel := t.global_position - sub.global_position
		var tb := fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		var tx := cx + wrapf(tb - brg, -180.0, 180.0) * px_per_deg
		if absf(tx - cx) < 520.0:
			draw_rect(Rect2(tx - 4, tape_y + 4, 8, 8), Color(0.5, 0.9, 1.0))
		var surf := Vector3(t.global_position.x, 0.0, t.global_position.z)
		if not rig.camera.is_position_behind(surf):
			var sp := rig.camera.unproject_position(surf)
			if sp.x > 0 and sp.x < vp.x and sp.y > 0 and sp.y < vp.y:
				draw_arc(sp, 7.0, 0.0, TAU, 16, Color(0.5, 0.9, 1.0, 0.9), 1.5)
				draw_string(f, sp + Vector2(10, -6), "T%d  %.1f KM" % [n, rel.length() / 1000.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.9, 1.0))
		n += 1
	if _away_t > 0.0:
		draw_string(fd, Vector2(cx - 300, cy - 110), "TORPEDO AWAY", HORIZONTAL_ALIGNMENT_CENTER, 600, 34, Color(1.0, 0.45, 0.35, clampf(_away_t, 0.0, 1.0)))


func _brackets(r: Rect2, c: Color) -> void:
	var l := minf(r.size.x, r.size.y) * 0.25
	var p := r.position
	var q := r.end
	for corner in [[p, Vector2(1, 0), Vector2(0, 1)], [Vector2(q.x, p.y), Vector2(-1, 0), Vector2(0, 1)], [Vector2(p.x, q.y), Vector2(1, 0), Vector2(0, -1)], [q, Vector2(-1, 0), Vector2(0, -1)]]:
		var o: Vector2 = corner[0]
		draw_line(o, o + corner[1] * l, c, 1.5)
		draw_line(o, o + corner[2] * l, c, 1.5)


func _aob(ship: SurfaceShip, rel: Vector3) -> String:
	var los := atan2(-rel.x, rel.z)
	var a := rad_to_deg(wrapf(los - ship.heading, -PI, PI))
	return "%s%03d" % ["S" if a >= 0.0 else "P", int(absf(a))]


func _block(pos: Vector2, lines: Array, c: Color, right: bool = false) -> void:
	var f := UiStyle.mono()
	var y := pos.y
	for l in lines:
		draw_string(f, Vector2(pos.x, y), String(l), HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, 290 if right else -1, 13, c)
		y += 20.0


func _clock() -> String:
	var base := {"dawn": 5.7, "clear": 12.2, "golden": 18.9, "storm": 14.3, "night": 1.5}
	var h := float(base.get(weather.preset_name if weather else "dawn", 6.0)) + _time / 3600.0
	if weather and weather.clock:
		h = weather.clock.hours()
	var hh := int(h) % 24
	var mm := int(fposmod(h * 60.0, 60.0))
	var ss := int(fposmod(h * 3600.0, 60.0))
	return "%02d:%02d:%02d Z" % [hh, mm, ss]
