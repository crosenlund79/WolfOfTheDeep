class_name ChartView
extends Control
## Nautical chart (Maya's station): a hydrographic chart of the operating
## region built from the real seabed: tints, depth contours, historical
## soundings, names, hazards, charted ice limits and known icebergs, plus the
## boat, the planned route with legs and ETAs, and contacts as the boat knows
## them (estimates with uncertainty). Select a point or contact for distance,
## bearing, time and intercept estimates; Shift+click to lay waypoints.

signal course_ordered(heading_rad: float)
signal route_changed
signal request(action: String)

const NM := 1852.0

var main: Node
var area: ArcticArea
var sub: Submarine
var sensors: SensorSuite
var clock: GameClock
var data: ChartData
var route: Array[Vector3] = []
var marks: Array[Dictionary] = []   # {pos, label, color}
var sector_center := Vector3.ZERO
var sector_radius := 0.0
var rv_point := Vector3.ZERO
var dr_error := 20.0
var planned_knots := 9.0
var track: Array = []               # own track history: [x, z]
var reported_ice: Array = []        # [{pos, keel, r, t, id}] from ice reports
var aircraft_marks: Array = []      # aircraft as the boat knows them (ESM, sightings, last known)
var intel_marks: Array = []         # units known only from reports: {pos, unc, label, color}
var weapons: WeaponPlot             # torpedoes and charges, as the boat knows them
var drone: ReconDrone               # the reconnaissance drone, while it is up

var _center := Vector2(0.0, 0.0)
var _mpp := 60.0
var _panning := false
var _follow := true
var _selected := {}                 # {"kind": "point"/"contact", "pos": Vector3, "id": String}
var _hover_world := Vector2.ZERO
var _panel: PanelContainer
var _panel_text: RichTextLabel
var _speed_label: Label
var _follow_btn: Button
var _night := false
var _search: LineEdit
var _results: VBoxContainer
var _found: Array[Dictionary] = []
var _highlight := {}                # {pos, label, until_ms}
var _legend_btn: Button
var legend_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_panel()
	_legend_btn = UiStyle.button("LEGEND  ▸  (G)", 12)
	UiStyle.place(_legend_btn, Vector2(0, 0), Vector2(16, 90), Vector2(150, 0))
	_legend_btn.pressed.connect(toggle_legend)
	add_child(_legend_btn)


func toggle_legend() -> void:
	legend_open = not legend_open
	_legend_btn.text = "LEGEND  ▾  (G)" if legend_open else "LEGEND  ▸  (G)"
	queue_redraw()


func build_texture() -> void:
	pass   # kept for compatibility: the chart builds its own tiles now


func focus_on(p: Vector3) -> void:
	_follow = false
	_center = Vector2(p.x, p.z)
	_mpp = minf(_mpp, 40.0)
	_selected = {"kind": "point", "pos": Vector3(p.x, 0, p.z)}


func world_to_screen(p: Vector3) -> Vector2:
	return size * 0.5 + (Vector2(p.x, p.z) - _center) / _mpp


func w2s(x: float, z: float) -> Vector2:
	return size * 0.5 + (Vector2(x, z) - _center) / _mpp


func screen_to_world(s: Vector2) -> Vector3:
	var w := _center + (s - size * 0.5) * _mpp
	return Vector3(w.x, 0.0, w.y)


static func latlon(p: Vector3) -> String:
	return Geography.latlon_text(p.x, p.z)


# --- panel -----------------------------------------------------------------------------

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.9, 12))
	UiStyle.place(_panel, Vector2(1, 0), Vector2(-420, 84), Vector2(400, 0))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	v.add_child(UiStyle.label("NAVIGATION  ·  LT CHEN", 16, UiStyle.CYAN))
	_search = LineEdit.new()
	_search.placeholder_text = "Find on the chart (F): place, hazard, contact, WP…"
	_search.clear_button_enabled = true
	_search.add_theme_font_override("font", UiStyle.mono())
	_search.add_theme_font_size_override("font_size", 12)
	_search.text_changed.connect(func(t: String) -> void: _show_results(search(t)))
	_search.text_submitted.connect(func(_t: String) -> void:
		if not _found.is_empty():
			select_result(_found[0]))
	_search.gui_input.connect(func(e: InputEvent) -> void:
		var k := e as InputEventKey
		if k and k.pressed and k.keycode == KEY_ESCAPE:
			_search.text = ""
			_show_results([])
			_search.release_focus()
			_search.accept_event())
	v.add_child(_search)
	_results = VBoxContainer.new()
	_results.add_theme_constant_override("separation", 2)
	v.add_child(_results)
	_panel_text = RichTextLabel.new()
	_panel_text.bbcode_enabled = true
	_panel_text.fit_content = true
	_panel_text.custom_minimum_size = Vector2(376, 0)
	_panel_text.add_theme_font_override("normal_font", UiStyle.mono())
	_panel_text.add_theme_font_override("bold_font", UiStyle.display())
	_panel_text.add_theme_font_size_override("normal_font_size", 12)
	_panel_text.add_theme_font_size_override("bold_font_size", 13)
	_panel_text.add_theme_color_override("default_color", UiStyle.WHITE)
	v.add_child(_panel_text)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 4)
	sp.add_child(UiStyle.label("PLANNED SPEED", 12, UiStyle.DIM))
	var minus := UiStyle.button("−", 13)
	minus.pressed.connect(func() -> void: _set_planned(planned_knots - 1.0))
	sp.add_child(minus)
	_speed_label = UiStyle.label("", 14, UiStyle.CYAN, UiStyle.mono())
	_speed_label.custom_minimum_size = Vector2(70, 0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp.add_child(_speed_label)
	var plus := UiStyle.button("+", 13)
	plus.pressed.connect(func() -> void: _set_planned(planned_knots + 1.0))
	sp.add_child(plus)
	var now_b := UiStyle.button("= current", 12)
	now_b.pressed.connect(func() -> void: _set_planned(snappedf(maxf(sub.knots(), 1.0), 1.0)))
	sp.add_child(now_b)
	v.add_child(sp)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	_follow_btn = _pbtn(g, "Steer the route", func() -> void: request.emit("follow_route"))
	_pbtn(g, "Steer for selection", func() -> void: steer_selected())
	_pbtn(g, "Fast to next waypoint  (N)", func() -> void: request.emit("next_waypoint"))
	_pbtn(g, "Add selection as waypoint", func() -> void:
		if not _selected.is_empty():
			route.append(Vector3((_selected["pos"] as Vector3).x, 0.0, (_selected["pos"] as Vector3).z))
			route_changed.emit())
	_pbtn(g, "Remove last waypoint", func() -> void:
		if not route.is_empty():
			route.pop_back()
			route_changed.emit())
	_pbtn(g, "Clear route", func() -> void:
		route.clear()
		route_changed.emit())
	v.add_child(g)


func _pbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := UiStyle.button(text, 12)
	b.custom_minimum_size = Vector2(186, 0)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _set_planned(k: float) -> void:
	planned_knots = clampf(k, 1.0, 20.0)


func steer_selected() -> void:
	if _selected.is_empty():
		return
	var p: Vector3 = _selected["pos"]
	if _selected.get("kind") == "contact":
		var sol := intercept_for(String(_selected["id"]))
		if sol.has("aim"):
			p = sol["aim"]
	var rel := p - sub.global_position
	course_ordered.emit(atan2(rel.x, -rel.z))


# --- input -----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before := screen_to_world(mb.position)
			_mpp = clampf(_mpp * (0.82 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.22), 3.0, 1400.0)
			var after := screen_to_world(mb.position)
			_center += Vector2(before.x - after.x, before.z - after.z)
			_follow = false
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
				_select_at(mb.position, w)
				if mb.double_click:
					steer_selected()
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var w2 := screen_to_world(mm.position)
		_hover_world = Vector2(w2.x, w2.z)
		if _panning:
			_center -= mm.relative * _mpp
		accept_event()


func _select_at(sp: Vector2, w: Vector3) -> void:
	_highlight = {}
	if sensors:
		for c in sensors.contacts:
			if c.kind == "VESSEL" and c.range_err <= 0.3 and world_to_screen(c.est_pos).distance_to(sp) < 12.0:
				_selected = {"kind": "contact", "pos": c.est_pos, "id": c.id}
				return
	_selected = {"kind": "point", "pos": w}


func select_contact(id: String) -> void:
	for c in sensors.contacts:
		if c.id == id:
			_selected = {"kind": "contact", "pos": c.est_pos, "id": c.id}


func handle_key(k: int) -> bool:
	match k:
		KEY_F:
			_search.grab_focus()
			_search.select_all()
			return true
		KEY_G:
			toggle_legend()
			return true
		KEY_C:
			_follow = true
			return true
		KEY_BACKSPACE, KEY_DELETE:
			if not route.is_empty():
				route.pop_back()
				route_changed.emit()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			steer_selected()
			return true
		KEY_PAGEUP:
			_mpp = maxf(_mpp * 0.6, 3.0)
			return true
		KEY_PAGEDOWN:
			_mpp = minf(_mpp * 1.6, 1400.0)
			return true
	return false


func set_chart_scale(mpp: float) -> void:
	_mpp = clampf(mpp, 3.0, 1400.0)


func hint_text() -> String:
	return "F  FIND   ·   G  LEGEND   ·   CLICK  SELECT   ·   DOUBLE-CLICK / ENTER  STEER FOR IT   ·   SHIFT+CLICK  WAYPOINT   ·   BACKSPACE  REMOVE LAST   ·   WHEEL  ZOOM   ·   RIGHT-DRAG  PAN   ·   C  CENTRE   ·   N  FAST TO NEXT WAYPOINT"


# --- search --------------------------------------------------------------------------

## Folds case and the Nordic letters, so "storoya" finds STORØYA.
static func fold(t: String) -> String:
	return t.to_lower().replace("ø", "o").replace("å", "a").replace("æ", "ae").replace("ö", "o").replace("ä", "a").replace("é", "e")


## Everything on the chart that can be searched for: only what the chart
## already shows (charted features, the boat's own plot and reports). Nothing
## the boat does not know is ever listed.
func searchable() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var geo := area.geo
	var kind_txt := {"island": "island", "trough": "trough", "bank": "bank", "ridge": "ridge", "shoal": "shoal",
		"basin": "basin", "slope": "slope", "strait": "strait"}
	for n in geo.names:
		var nm := String(n["text"])
		out.append({"label": nm, "kind": String(kind_txt.get(String(n["kind"]), "feature")),
			"pos": Vector3((n["pos"] as Vector2).x, 0.0, (n["pos"] as Vector2).y), "zoom": 120.0 if String(n["kind"]) == "island" else 150.0})
	for pl in geo.places:
		var kt := {"harbour": "harbour, port", "station": "station", "naval": "naval anchorage, naval facility, port"}
		out.append({"label": String(pl["text"]), "kind": String(kt.get(String(pl["kind"]), "place")), "detail": String(pl["note"]),
			"pos": Vector3((pl["pos"] as Vector2).x, 0.0, (pl["pos"] as Vector2).y), "zoom": 30.0})
	for h in geo.hazards:
		var hk := String(h["kind"])
		var nm2 := String(h.get("name", ""))
		var lab := "%s %d m" % [{"rock": "Rock", "shoal": "Shoal", "wreck": "Wreck", "obstruction": "Obstruction"}.get(hk, "Hazard"), int(float(h["depth"]))]
		if nm2 != "" and nm2 not in ["Wk", "Obstn"]:
			lab = "%s (%s)" % [nm2, lab.to_lower()]
		var hp := Vector3((h["pos"] as Vector2).x, 0.0, (h["pos"] as Vector2).y)
		out.append({"label": lab, "kind": "hazard, danger", "detail": Geography.latlon_text(hp.x, hp.z), "pos": hp, "zoom": 25.0})
	if sector_radius > 0.0:
		out.append({"label": "PATROL SECTOR KESTREL", "kind": "navigation area, sector, patrol", "pos": sector_center, "zoom": 60.0})
	out.append({"label": "RV HOME", "kind": "rendezvous, navigation area", "pos": rv_point, "zoom": 40.0})
	var ice_x := sub.global_position.x if sub else 0.0
	out.append({"label": "PACK ICE LIMIT (nearest)", "kind": "ice, navigation area, restricted", "pos": Vector3(ice_x, 0.0, area.geo.ice_edge_z(ice_x)), "zoom": 150.0})
	for i in route.size():
		out.append({"label": "WP%d" % (i + 1), "kind": "waypoint, route", "pos": route[i], "zoom": 40.0})
	for m in marks:
		out.append({"label": String(m["label"]), "kind": "mark", "pos": m["pos"], "zoom": 40.0})
	if sensors:
		for c in sensors.contacts:
			if c.kind == "ICE":
				out.append({"label": "%s iceberg" % c.id, "kind": "ice, iceberg, contact", "pos": c.est_pos, "zoom": 10.0})
			elif c.kind == "VESSEL" and c.range_err <= 0.3:
				out.append({"label": "%s %s" % [c.id, c.label()], "kind": "contact, " + c.affiliation.to_lower() + (", lost" if c.status == "LOST" else ""),
					"pos": c.est_pos, "id": c.id, "zoom": 30.0})
	for m2 in intel_marks:
		out.append({"label": String(m2.get("label", "")), "kind": "reported unit, intelligence", "pos": m2["pos"], "zoom": 300.0})
	for a in aircraft_marks:
		if not a.has("from"):
			out.append({"label": String(a.get("label", "aircraft")), "kind": "aircraft", "pos": a["pos"], "zoom": 200.0})
	for r in reported_ice:
		out.append({"label": "%s reported iceberg" % String(r["id"]), "kind": "ice, iceberg, report", "pos": r["pos"], "zoom": 25.0})
	return out


## Matches for a query, best first (the exact name, a name starting with
## it, containing it, then by kind), nearest first within each.
func search(q: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var f := fold(q.strip_edges())
	if f.length() < 2:
		return res
	var own := sub.global_position if sub else Vector3.ZERO
	for e in searchable():
		var lab := fold(String(e["label"]))
		var rank := -1
		if lab == f:
			rank = 0
		elif lab.begins_with(f):
			rank = 1
		elif lab.contains(f):
			rank = 2
		elif fold(String(e["kind"])).contains(f) or fold(String(e.get("detail", ""))).contains(f):
			rank = 3
		if rank < 0:
			continue
		var r := e.duplicate()
		r["rank"] = rank
		r["dist"] = Vector2((e["pos"] as Vector3).x - own.x, (e["pos"] as Vector3).z - own.z).length()
		res.append(r)
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["rank"]) != int(b["rank"]):
			return int(a["rank"]) < int(b["rank"])
		return float(a["dist"]) < float(b["dist"]))
	return res


func _show_results(list: Array[Dictionary]) -> void:
	_found = list
	for ch in _results.get_children():
		ch.queue_free()
	if _search.text.strip_edges().length() >= 2 and list.is_empty():
		_results.add_child(UiStyle.label("Nothing charted or plotted by that name.", 12, UiStyle.DIM))
	for i in mini(list.size(), 8):
		var r: Dictionary = list[i]
		var own := sub.global_position
		var rel := (r["pos"] as Vector3) - own
		var brg := fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		var b := UiStyle.button("%s   ·   %s   %03d°  %.0f nm" % [String(r["label"]), String(r["kind"]).split(",")[0], int(brg), float(r["dist"]) / NM], 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(376, 0)
		b.pressed.connect(func() -> void: select_result(r))
		_results.add_child(b)
	if list.size() > 8:
		_results.add_child(UiStyle.label("… and %d more: type more of the name" % (list.size() - 8), 11, UiStyle.DIM))


## Centre the chart on a result and mark it.
func select_result(r: Dictionary) -> void:
	var p: Vector3 = r["pos"]
	_follow = false
	_center = Vector2(p.x, p.z)
	_mpp = clampf(float(r.get("zoom", 40.0)), 3.0, 1400.0)
	if r.has("id"):
		_selected = {"kind": "contact", "pos": p, "id": String(r["id"])}
	else:
		_selected = {"kind": "point", "pos": Vector3(p.x, 0.0, p.z)}
	_highlight = {"pos": p, "label": String(r["label"]), "until": Time.get_ticks_msec() + 8000}
	if _search.has_focus():
		_search.release_focus()
	queue_redraw()


func highlighted() -> Dictionary:
	return _highlight


func _exit_tree() -> void:
	# Both chart views share one data source; stopping it twice is harmless.
	if data:
		data.shutdown()


func _process(_delta: float) -> void:
	if not visible:
		return
	var want_night := String(Settings.get_v("contact_scheme")) == "low_light"
	if want_night != _night:
		_night = want_night
		data.set_night(_night)
	data.poll()
	if _follow and sub:
		_center = Vector2(sub.global_position.x, sub.global_position.z)
	_speed_label.text = "%4.1f KT" % planned_knots
	_follow_btn.text = "Stop steering the route" if main and bool(main.get("route_follow")) else "Steer the route"
	_panel_text.text = _panel_bbcode()
	queue_redraw()


# --- navigation calculations (also used by reports) -------------------------------

static func leg(a: Vector3, b: Vector3) -> Dictionary:
	var d := Vector2(b.x - a.x, b.z - a.z)
	return {"dist": d.length(), "brg": fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)}


static func hours(dist_m: float, knots: float) -> float:
	return dist_m / (maxf(knots, 0.1) * NM)


static func dur_text(h: float) -> String:
	if h > 99.0:
		return "%dd%02dh" % [int(h / 24.0), int(fposmod(h, 24.0))]
	return "%dh%02d" % [int(h), int(fposmod(h * 60.0, 60.0))]


func arrival_text(h: float) -> String:
	var t := clock.seconds + h * 3600.0
	var hh := fposmod(t / 3600.0, 24.0)
	return "DAY %d %02d:%02d" % [1 + int(t / 86400.0), int(hh), int(fposmod(hh * 60.0, 60.0))]


func route_total() -> float:
	var total := 0.0
	var p := sub.global_position
	for w in route:
		total += Vector2(w.x - p.x, w.z - p.z).length()
		p = w
	return total


## Intercept on a contact from what we know of it. {} if not found.
## Returns aim point, time (h), and a spread when the motion is uncertain.
func intercept_for(id: String) -> Dictionary:
	var c: Contact = null
	for cc in sensors.contacts:
		if cc.id == id:
			c = cc
	if c == null:
		return {}
	if c.range_err > 0.3:
		return {"none": "Bearing only: no range yet, so no intercept solution."}
	var crs := float(c.ais["course"]) if c.ais.has("course") else c.est_course
	var spd := float(c.ais["speed"]) if c.ais.has("speed") else c.est_speed
	if spd < 0.0 or crs < 0.0:
		var dist := Vector2(c.est_pos.x - sub.global_position.x, c.est_pos.z - sub.global_position.z).length()
		return {"none": "No motion solution yet: steering for its estimated position.", "aim": c.est_pos, "t": hours(dist, planned_knots)}
	var base := _solve(c.est_pos, crs, spd)
	if base.is_empty():
		return {"none": "Cannot intercept at %.0f knots on this geometry." % planned_knots}
	var spread := 0.0
	if c.ais.is_empty() and c.cs_conf != "HIGH":
		var k := 0.35 if c.cs_conf == "LOW" else 0.18
		var lo := INF
		var hi := 0.0
		for dv in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
			var s2 := _solve(c.est_pos, crs + dv.x * k * 60.0, spd * (1.0 + dv.y * k))
			if not s2.is_empty():
				lo = minf(lo, float(s2["t"]))
				hi = maxf(hi, float(s2["t"]))
		if hi > 0.0:
			spread = hi - lo
			base["lo"] = lo
			base["hi"] = hi
	base["spread"] = spread
	base["conf"] = "AIS" if not c.ais.is_empty() else c.cs_conf
	return base


func _solve(tp: Vector3, crs_deg: float, spd_kn: float) -> Dictionary:
	var own := sub.global_position
	var v := Vector2(sin(deg_to_rad(crs_deg)), -cos(deg_to_rad(crs_deg))) * spd_kn * 0.5144
	var r := Vector2(tp.x - own.x, tp.z - own.z)
	var s := planned_knots * 0.5144
	var a := v.dot(v) - s * s
	var b := 2.0 * r.dot(v)
	var c := r.dot(r)
	var t := -1.0
	if absf(a) < 1e-6:
		t = -c / b if absf(b) > 1e-6 else -1.0
	else:
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return {}
		var t1 := (-b - sqrt(disc)) / (2.0 * a)
		var t2 := (-b + sqrt(disc)) / (2.0 * a)
		t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if t <= 0.0:
		return {}
	var aim := Vector2(tp.x, tp.z) + v * t
	return {"aim": Vector3(aim.x, 0.0, aim.y), "t": t / 3600.0, "brg": fposmod(rad_to_deg(atan2(aim.x - own.x, -(aim.y - own.z))), 360.0)}


func _panel_bbcode() -> String:
	var p := sub.global_position
	var under := area.seabed_depth(p.x, p.z) - sub.depth - 4.0
	var t := ""
	t += "POSITION  %s\n" % latlon(p)
	t += "DR ERROR  ±%d m%s\n" % [int(dr_error), "   [color=#ffb85a]FIX NEEDED[/color]" if dr_error > 400.0 else ""]
	t += "COURSE    %03d°  ORDERED %03d°\n" % [int(fposmod(rad_to_deg(sub.heading), 360.0)), int(fposmod(rad_to_deg(sub.ordered_heading), 360.0))]
	t += "SPEED     %4.1f kt  %s\n" % [sub.knots(), sub.speed_label()]
	t += "DEPTH     %5.1f m   UNDER KEEL %d m\n" % [sub.depth, int(under)]
	var cover := area.geo.ice_cover(p.x, p.z)
	if cover > 0.05:
		t += "[color=#bfe3ff]ICE COVER  %d%%   %s[/color]\n" % [int(cover * 100.0), "NO SURFACING" if cover > 0.6 else "LOOSE ICE"]
	if not route.is_empty():
		var total := route_total()
		var h := hours(total, planned_knots)
		var first := leg(p, route[0])
		t += "\n[b]ROUTE[/b]  %d waypoint%s\n" % [route.size(), "" if route.size() == 1 else "s"]
		t += "NEXT WP   %03d°  %5.1f nm  %s\n" % [int(first["brg"]), float(first["dist"]) / NM, dur_text(hours(float(first["dist"]), planned_knots))]
		t += "TOTAL     %5.1f nm  %s at %.0f kt\n" % [total / NM, dur_text(h), planned_knots]
		t += "ARRIVE    %s\n" % arrival_text(h)
	if not _selected.is_empty():
		var sp: Vector3 = _selected["pos"]
		var l := leg(p, sp)
		t += "\n[b]SELECTED[/b]  %s\n" % ("CONTACT " + String(_selected["id"]) if _selected["kind"] == "contact" else latlon(sp))
		var d_here := area.seabed_depth(sp.x, sp.z)
		t += "DEPTH     %s\n" % ("land" if d_here < 0.0 else "%d m (charted)" % int(d_here))
		t += "BRG/DIST  %03d°  %5.1f nm\n" % [int(l["brg"]), float(l["dist"]) / NM]
		var hh := hours(float(l["dist"]), planned_knots)
		t += "TIME      %s at %.0f kt  →  %s\n" % [dur_text(hh), planned_knots, arrival_text(hh)]
		if _selected["kind"] == "contact":
			var sol := intercept_for(String(_selected["id"]))
			if sol.has("none"):
				t += "[color=#ffb85a]%s[/color]\n" % String(sol["none"])
			elif not sol.is_empty():
				t += "INTERCEPT steer %03d°, %s at %.0f kt" % [int(sol["brg"]), dur_text(float(sol["t"])), planned_knots]
				if float(sol.get("spread", 0.0)) > 0.05:
					t += "\n[color=#ffb85a]  uncertain: %s to %s (motion %s)[/color]" % [dur_text(float(sol["lo"])), dur_text(float(sol["hi"])), String(sol.get("conf", "")).to_lower()]
				t += "\n"
	return t


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	var vp := size
	var night := _night
	var ink := Color(0.12, 0.16, 0.22) if not night else Color(0.85, 0.62, 0.5)
	var sea := Color(0.985, 0.99, 1.0) if not night else Color(0.0, 0.015, 0.03)
	draw_rect(Rect2(Vector2.ZERO, vp), sea)
	if data == null:
		return
	var f := UiStyle.mono()
	var fd := UiStyle.display()
	var tl := screen_to_world(Vector2.ZERO)
	var br := screen_to_world(vp)
	var view := Rect2(Vector2(tl.x, tl.z), Vector2(br.x - tl.x, br.z - tl.z))
	var level := clampi(int(round(log(Geography.REGION_HALF * 2.0 / (150.0 * _mpp)) / log(2.0))), 0, ChartData.LEVELS - 1)
	var ts := ChartData.tile_size(level)
	var i0 := maxi(int(floorf((view.position.x + Geography.REGION_HALF) / ts)), 0)
	var i1 := mini(int(floorf((view.end.x + Geography.REGION_HALF) / ts)), (1 << level) - 1)
	var j0 := maxi(int(floorf((view.position.y + Geography.REGION_HALF) / ts)), 0)
	var j1 := mini(int(floorf((view.end.y + Geography.REGION_HALF) / ts)), (1 << level) - 1)
	var ready: Array = []
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var t := data.tile(level, i, j)
			if t.is_empty():
				# Meanwhile show the nearest coarser tile that is ready; one
				# coarse level is requested so a fallback arrives quickly.
				var coarse := maxi(level - 3, 0)
				data.tile(coarse, i >> (level - coarse), j >> (level - coarse))
				for up in range(1, level + 1):
					var pt := data.peek(level - up, i >> up, j >> up)
					if not pt.is_empty():
						var o: Vector2 = pt["origin"]
						var s := float(pt["size"])
						var sub_o := Vector2(-Geography.REGION_HALF + i * ts, -Geography.REGION_HALF + j * ts)
						var src := Rect2((sub_o - o) / s * ChartData.PX, Vector2.ONE * ts / s * ChartData.PX)
						draw_texture_rect_region(pt["tex"], Rect2(w2s(sub_o.x, sub_o.y), Vector2.ONE * ts / _mpp), src)
						break
				continue
			var o2: Vector2 = t["origin"]
			draw_texture_rect(t["tex"], Rect2(w2s(o2.x, o2.y), Vector2.ONE * ts / _mpp), false)
			ready.append(t)
	# Contours (world coordinates, hairlines).
	draw_set_transform(size * 0.5 - _center / _mpp, 0.0, Vector2.ONE / _mpp)
	for t in ready:
		var lines: Dictionary = t["lines"]
		for lv in lines.keys():
			var lvf := float(lv)
			if _mpp > 250.0 and lvf in [10.0, 30.0]:
				continue
			var col := ink
			col.a = 0.85 if lvf == 0.0 else (0.38 if lvf in [10.0, 20.0, 30.0] else 0.5)
			if lvf in [20.0, 50.0]:
				col = Color(0.15, 0.4, 0.7, 0.6) if not night else Color(0.4, 0.55, 0.75, 0.55)
			draw_multiline(lines[lv], col, -1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ice(view, night)
	# Beyond the limits of the chart.
	var rh := Geography.REGION_HALF
	var r0 := w2s(-rh, -rh)
	var r1 := w2s(rh, rh)
	var beyond := Color(0.82, 0.83, 0.82) if not night else Color(0.05, 0.05, 0.06)
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, maxf(r0.y, 0.0))), beyond)
	draw_rect(Rect2(Vector2(0.0, r1.y), Vector2(vp.x, maxf(vp.y - r1.y, 0.0))), beyond)
	draw_rect(Rect2(Vector2(0.0, r0.y), Vector2(maxf(r0.x, 0.0), r1.y - r0.y)), beyond)
	draw_rect(Rect2(Vector2(r1.x, r0.y), Vector2(maxf(vp.x - r1.x, 0.0), r1.y - r0.y)), beyond)
	draw_rect(Rect2(r0, r1 - r0), ink, false, 1.5)
	_draw_soundings(view, f, night)
	_draw_graticule(view, f, ink)
	_draw_names(fd, ink, night)
	_draw_hazards(f, ink, night)
	_draw_places(fd, ink, night)
	_draw_patrol(fd)
	_draw_track_and_route(f, night)
	if sensors:
		for c in sensors.contacts:
			_draw_contact(c, f)
	for m in intel_marks:
		_draw_intel_mark(m, f)
	for a in aircraft_marks:
		_draw_aircraft(a, f)
	if weapons:
		for w in weapons.list():
			_draw_weapon(w, f)
	if drone and drone.airborne():
		_draw_drone(f)
	_draw_ownship()
	_draw_selection()
	_draw_highlight(fd)
	_draw_scale(f, ink)
	_draw_cursor(f, ink)
	if legend_open:
		_draw_legend(f, ink, night)
	if data.busy():
		draw_string(f, Vector2(24, 100), "LOADING CHART DETAIL…", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink.r, ink.g, ink.b, 0.6))


func _draw_soundings(view: Rect2, f: Font, night: bool) -> void:
	if _mpp > 900.0:
		return
	var col := Color(0.22, 0.28, 0.36) if not night else Color(0.62, 0.5, 0.42)
	var list: Array = []
	for pri in [0.97, 0.9, 0.75, 0.5, 0.0]:
		list = data.soundings_in(view, pri, 2500)
		if list.size() >= 900 or pri == 0.0:
			break
	# Thinned on a grid fixed to the chart (figures don't jump about while
	# panning); in each cell the shoalest-leaning sounding is shown, as a
	# cartographer would choose for safety.
	var cw := 58.0 * _mpp
	var chh := 24.0 * _mpp
	var best := {}
	for s in list:
		var k := Vector2i(int(floorf(float(s[0]) / cw)), int(floorf(float(s[1]) / chh)))
		var score := float(s[3]) - float(s[2]) * 0.002
		if not best.has(k) or score > float(best[k][4]):
			best[k] = [s[0], s[1], s[2], s[3], score]
	for s in best.values():
		var p := w2s(float(s[0]), float(s[1]))
		var d := float(s[2])
		var txt := "%d" % int(d)
		var w := 9.0 if d < 100.0 else 14.0
		draw_string(f, p + Vector2(-w * 0.5, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		if d < 31.0:
			var dec := int(round(fposmod(d, 1.0) * 10.0)) % 10
			if dec > 0:
				draw_string(f, p + Vector2(w * 0.5 + 1, 7), str(dec), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_graticule(view: Rect2, f: Font, ink: Color) -> void:
	# Latitude / longitude lines with labels at the chart edges.
	var top_ll := Geography.latlon(view.position.x, view.position.y)
	var bot_ll := Geography.latlon(view.position.x, view.end.y)
	var span_min := (top_ll.x - bot_ll.x) * 60.0
	var step_min := 60.0
	for s in [1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 60.0]:
		if span_min / s < 9.0:
			step_min = s
			break
	var col := Color(ink.r, ink.g, ink.b, 0.16)
	var lab := Color(ink.r, ink.g, ink.b, 0.7)
	var lat := floorf(bot_ll.x * 60.0 / step_min) * step_min / 60.0
	while lat <= top_ll.x + 0.01:
		var z := (76.5 - lat) * 111000.0
		var y := w2s(0.0, z).y
		if y > 0.0 and y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
			draw_string(f, Vector2(6, y - 3), "%02d°%02d'N" % [int(lat), int(round(fposmod(lat * 60.0, 60.0))) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		lat += step_min / 60.0
	var mid_lat := (top_ll.x + bot_ll.x) * 0.5
	var lon_l := Geography.latlon(view.position.x, (76.5 - mid_lat) * 111000.0).y
	var lon_r := Geography.latlon(view.end.x, (76.5 - mid_lat) * 111000.0).y
	var lon_step := step_min * 3.0
	var lon := floorf(lon_l * 60.0 / lon_step) * lon_step / 60.0
	var guard := 0
	while lon <= lon_r + 0.01 and guard < 80:
		guard += 1
		var pts := PackedVector2Array()
		for k in 9:
			var lt := lerpf(bot_ll.x, top_ll.x, float(k) / 8.0)
			var z2 := (76.5 - lt) * 111000.0
			var x2 := (lon - 25.0) * 111000.0 * cos(deg_to_rad(lt))
			pts.append(w2s(x2, z2))
		draw_polyline(pts, col, 1.0)
		var bp := pts[0]
		if bp.x > 0.0 and bp.x < size.x:
			draw_string(f, Vector2(bp.x + 3, size.y - 64), "%03d°%02d'E" % [int(lon), int(round(fposmod(lon * 60.0, 60.0))) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		lon += lon_step / 60.0


func _draw_names(fd: Font, ink: Color, night: bool) -> void:
	for n in area.geo.names:
		if _mpp < float(n["min_mpp"]) or _mpp > float(n["max_mpp"]):
			continue
		var p := w2s((n["pos"] as Vector2).x, (n["pos"] as Vector2).y)
		if p.x < -300.0 or p.x > size.x + 300.0 or p.y < -40.0 or p.y > size.y + 40.0:
			continue
		var kind := String(n["kind"])
		var txt := String(n["text"])
		var col := ink
		var fs := 13
		if kind == "island":
			fs = 15 if txt.length() > 8 else 14
			col = Color(0.32, 0.24, 0.12) if not night else Color(0.85, 0.7, 0.5)
		else:
			txt = " ".join(txt.split(""))
			col = Color(0.2, 0.36, 0.6, 0.8) if not night else Color(0.55, 0.62, 0.75, 0.8)
			fs = 12
		var w := fd.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(fd, p - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_hazards(f: Font, ink: Color, night: bool) -> void:
	var danger := Color(0.75, 0.1, 0.45) if not night else Color(1.0, 0.45, 0.5)
	for h in area.geo.hazards:
		var p := w2s((h["pos"] as Vector2).x, (h["pos"] as Vector2).y)
		if p.x < -20.0 or p.x > size.x + 20.0 or p.y < -20.0 or p.y > size.y + 20.0:
			continue
		var kind := String(h["kind"])
		var d := float(h["depth"])
		match kind:
			"rock":
				_hazard_glyph(p, kind, ink, danger, _mpp < 200.0)
				if _mpp < 200.0:
					draw_string(f, p + Vector2(8, -6), "%d" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, danger)
			"shoal":
				_hazard_glyph(p, kind, ink, danger)
				if _mpp < 400.0:
					draw_string(f, p + Vector2(9, 4), "%d" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, danger)
			"wreck":
				if _mpp < 300.0:
					_hazard_glyph(p, kind, ink, danger)
					draw_string(f, p + Vector2(10, 4), "Wk %d" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
			"obstruction":
				if _mpp < 300.0:
					_hazard_glyph(p, kind, ink, danger)
					draw_string(f, p + Vector2(9, 4), "Obstn %d" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)


func _hazard_glyph(p: Vector2, kind: String, ink: Color, danger: Color, ring: bool = true) -> void:
	match kind:
		"rock":
			draw_line(p - Vector2(5, 0), p + Vector2(5, 0), danger, 1.5)
			draw_line(p - Vector2(0, 5), p + Vector2(0, 5), danger, 1.5)
			if ring:
				draw_arc(p, 9.0, 0.0, TAU, 20, Color(danger.r, danger.g, danger.b, 0.5), 1.0)
		"shoal":
			draw_arc(p, 7.0, 0.0, TAU, 16, danger, 1.2)
		"wreck":
			draw_line(p - Vector2(7, 0), p + Vector2(7, 0), ink, 1.2)
			draw_line(p - Vector2(3, 4), p + Vector2(-3, -4), ink, 1.0)
			draw_line(p - Vector2(-3, 4), p + Vector2(3, -4), ink, 1.0)
		"obstruction":
			draw_arc(p, 6.0, 0.0, TAU, 14, ink, 1.0)


func _place_colors(night: bool) -> Color:
	return Color(0.42, 0.22, 0.05) if not night else Color(0.95, 0.72, 0.45)


## Harbour: an anchor. Station: a mast (circle and dot). Naval anchorage:
## an anchor in a square.
func _place_glyph(p: Vector2, kind: String, col: Color) -> void:
	match kind:
		"harbour", "naval":
			draw_line(p + Vector2(0, -6), p + Vector2(0, 5), col, 1.5)
			draw_line(p + Vector2(-4, -3), p + Vector2(4, -3), col, 1.5)
			draw_arc(p + Vector2(0, 1), 5.0, 0.15, PI - 0.15, 10, col, 1.5)
			draw_arc(p + Vector2(0, -7.5), 1.6, 0.0, TAU, 8, col, 1.2)
			if kind == "naval":
				draw_rect(Rect2(p - Vector2(9, 11), Vector2(18, 20)), col, false, 1.2)
		_:
			draw_arc(p, 5.5, 0.0, TAU, 16, col, 1.5)
			draw_circle(p, 1.8, col)


func _draw_places(fd: Font, _ink: Color, night: bool) -> void:
	var col := _place_colors(night)
	for pl in area.geo.places:
		var p := w2s((pl["pos"] as Vector2).x, (pl["pos"] as Vector2).y)
		if p.x < -40.0 or p.x > size.x + 40.0 or p.y < -40.0 or p.y > size.y + 40.0:
			continue
		_place_glyph(p, String(pl["kind"]), col)
		if _mpp < 400.0:
			draw_string(fd, p + Vector2(12, 4), String(pl["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## A search result: a ring (pulsing for the first few seconds) and its name,
## kept until something else is selected.
func _draw_highlight(fd: Font) -> void:
	if _highlight.is_empty():
		return
	var p := world_to_screen(_highlight["pos"])
	var col := Color(0.95, 0.5, 0.0) if not _night else Color(1.0, 0.55, 0.35)
	if Time.get_ticks_msec() < int(_highlight["until"]):
		var ph := fposmod(float(Time.get_ticks_msec()) / 700.0, 1.0)
		draw_arc(p, 14.0 + ph * 22.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, 1.0 - ph), 2.5)
	draw_arc(p, 18.0, 0.0, TAU, 32, col, 2.0)
	var txt := "▸ " + String(_highlight["label"])
	var w := fd.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var bg := Color(1, 1, 1, 0.85) if not _night else Color(0, 0, 0, 0.8)
	draw_rect(Rect2(p + Vector2(22, -40), Vector2(w + 12, 22)), bg)
	draw_string(fd, p + Vector2(28, -24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


## The legend: every symbol drawn by the same code as on the chart, each with
## words (never colour alone), in the chart's day or low-light colours.
func _draw_legend(f: Font, ink: Color, night: bool) -> void:
	var danger := Color(0.75, 0.1, 0.45) if not night else Color(1.0, 0.45, 0.5)
	var own_col := Color(0.0, 0.45, 0.75) if not night else Color(0.45, 0.85, 1.0)
	var route_col := Color(0.8, 0.15, 0.55) if not night else Color(1.0, 0.5, 0.75)
	var ice_col := Color(0.25, 0.45, 0.8, 0.85) if not night else Color(0.55, 0.7, 0.95, 0.8)
	var contour := Color(0.15, 0.4, 0.7, 0.6) if not night else Color(0.4, 0.55, 0.75, 0.55)
	var rows := [
		["own", "Own boat, heading; circle: position uncertainty"],
		["ordered", "Ordered course"],
		["route", "Planned route and waypoint"],
		["head", "OWN BOAT'S CONTACTS (shape = assessment)"],
		["hostile", "Hostile (filled diamond)"],
		["suspect", "Suspect (open diamond)"],
		["neutral", "Neutral (square)"],
		["friendly", "Friendly (circle)"],
		["unknown", "Unknown (four rings)"],
		["ellipse", "Area she is probably in; line: her course"],
		["bearing", "Bearing only, no range yet"],
		["intel", "Unit known only from a report; ring: doubt"],
		["air", "Aircraft (filled: seen; open: estimated)"],
		["head", "WEAPONS (known or estimated; grey with a cross: ended)"],
		["own_torp", "Own torpedo, live by wire; line: its track"],
		["own_torp_est", "Own torpedo, estimated (wire parted)"],
		["hostile_torp", "Enemy torpedo (only once detected)"],
		["charge", "Charge or ASW weapon (only once detected)"],
		["burst", "Detonation heard"],
		["stale_weapon", "Ended, expired or no longer tracked"],
		["drone", "Reconnaissance drone; ring: its radio reach"],
		["head", "ICE"],
		["berg", "Iceberg held on sonar or seen"],
		["berg_rep", "Iceberg from an ice report (older)"],
		["ice", "Pack ice limit: no surfacing beyond"],
		["head", "CHART"],
		["rock", "Rock, depth over it in metres"],
		["shoal", "Shoal"],
		["wreck", "Wreck"],
		["obstruction", "Obstruction"],
		["contour", "20 and 50 m depth contours"],
		["sounding", "Sounding (depth in metres)"],
		["harbour", "Harbour"],
		["station", "Station"],
		["naval", "Naval anchorage"],
		["sector", "Patrol sector"],
		["rv", "Rendezvous"],
		["select", "Selection / search result"],
	]
	var o := Vector2(16, 126)
	var h := 18.0
	var box := Rect2(o, Vector2(380, rows.size() * h + 16))
	draw_rect(box, Color(1, 1, 1, 0.92) if not night else Color(0.0, 0.0, 0.0, 0.88))
	draw_rect(box, Color(ink.r, ink.g, ink.b, 0.5), false, 1.0)
	var y := o.y + 16.0
	for r in rows:
		var id := String(r[0])
		var p := Vector2(o.x + 26, y - 4)
		var ccol := Settings.contact_color(id)
		if not night:
			ccol = ccol.darkened(0.25)
		match id:
			"head":
				draw_string(UiStyle.display(), Vector2(o.x + 10, y), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink.r, ink.g, ink.b, 0.7))
				y += h
				continue
			"own":
				draw_arc(p, 8.0, 0.0, TAU, 20, Color(own_col.r, own_col.g, own_col.b, 0.5), 1.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(5, 5), p + Vector2(-5, 5)]), own_col)
			"ordered":
				draw_dashed_line(p - Vector2(12, 0), p + Vector2(12, 0), Color(own_col.r, own_col.g, own_col.b, 0.55), 1.5, 5.0)
			"route":
				draw_dashed_line(p - Vector2(14, 0), p + Vector2(6, 0), route_col, 2.0, 5.0)
				draw_arc(p + Vector2(8, 0), 5.0, 0.0, TAU, 14, route_col, 2.0)
			"hostile", "suspect", "neutral", "friendly", "unknown":
				_shape(p, id, ccol)
			"ellipse":
				var uc := Settings.contact_color("unknown")
				if not night:
					uc = uc.darkened(0.25)
				var pts := PackedVector2Array()
				for k in 25:
					var a := TAU * float(k) / 24.0
					pts.append(p + Vector2(cos(a) * 11.0, sin(a) * 4.5))
				draw_polyline(pts, Color(uc.r, uc.g, uc.b, 0.6), 1.0)
				draw_line(p, p + Vector2(12, -6), uc, 1.5)
			"bearing":
				var uc2 := Settings.contact_color("unknown")
				draw_line(p - Vector2(14, 4), p + Vector2(14, -4), Color(uc2.r, uc2.g, uc2.b, 0.6), 1.0)
			"intel":
				var ic := Color(0.5, 0.5, 0.5) if not night else Color(0.75, 0.55, 0.5)
				draw_arc(p, 9.0, 0.0, TAU, 20, Color(ic.r, ic.g, ic.b, 0.4), 1.0)
				draw_polyline(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0), p + Vector2(0, -6)]), ic, 1.5)
			"air":
				var ac := Color(0.6, 0.3, 0.1) if not night else Color(1.0, 0.6, 0.4)
				_air_glyph(p + Vector2(-8, 0), ac, true)
				_air_glyph(p + Vector2(10, 0), ac, false)
			"own_torp":
				var oc := _weapon_colors("own_torpedo", "current")
				draw_line(p - Vector2(16, 0), p - Vector2(4, 0), Color(oc.r, oc.g, oc.b, 0.55), 1.2)
				_torpedo_glyph(p + Vector2(4, 0), PI * 0.5, oc, true)
			"own_torp_est":
				var oe := _weapon_colors("own_torpedo", "estimated")
				draw_arc(p + Vector2(4, 0), 9.0, 0.0, TAU, 20, Color(oe.r, oe.g, oe.b, 0.3), 1.0)
				_torpedo_glyph(p + Vector2(4, 0), PI * 0.5, oe, false)
			"hostile_torp":
				_torpedo_glyph(p, PI * 0.5, _weapon_colors("hostile_torpedo", "current"), true)
			"charge":
				_charge_glyph(p, _weapon_colors("charge", "current"))
			"burst":
				_burst_glyph(p, _weapon_colors("detonation", "detonated"))
			"drone":
				var dc := Color(0.1, 0.55, 0.35) if not night else Color(0.55, 0.9, 0.65)
				_drone_glyph(p, dc)
			"stale_weapon":
				var sc2 := _weapon_colors("own_torpedo", "ended")
				_torpedo_glyph(p, PI * 0.5, sc2, false)
				draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), sc2, 1.5)
				draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), sc2, 1.5)
			"berg":
				_berg_glyph(p, Color(0.2, 0.4, 0.75) if not night else Color(0.55, 0.7, 0.95))
			"berg_rep":
				draw_arc(p, 9.0, 0.0, TAU, 20, Color(ice_col.r, ice_col.g, ice_col.b, 0.35), 1.0)
				_berg_glyph(p, Color(ice_col.r, ice_col.g, ice_col.b, 0.65))
			"ice":
				draw_line(p - Vector2(14, 0), p - Vector2(4, 0), ice_col, 1.6)
				draw_line(p + Vector2(2, 0), p + Vector2(12, 0), ice_col, 1.6)
				draw_line(p + Vector2(-6, -2), p + Vector2(0, -8), Color(ice_col.r, ice_col.g, ice_col.b, 0.35), 1.0)
			"rock", "shoal", "wreck", "obstruction":
				_hazard_glyph(p, id, ink, danger, false)
			"contour":
				draw_line(p - Vector2(14, -2), p + Vector2(14, 2), contour, 1.0)
			"sounding":
				draw_string(f, p + Vector2(-8, 4), "37", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.22, 0.28, 0.36) if not night else Color(0.62, 0.5, 0.42))
			"harbour", "station", "naval":
				_place_glyph(p, id, _place_colors(night))
			"sector":
				draw_arc(p + Vector2(0, 14), 16.0, deg_to_rad(235), deg_to_rad(305), 12, Color(0.95, 0.55, 0.1, 0.8), 2.0)
			"rv":
				draw_arc(p, 6.0, 0.0, TAU, 16, Color(0.1, 0.6, 0.3), 2.0)
			"select":
				var sc := Color(0.9, 0.4, 0.0)
				draw_arc(p, 7.0, 0.0, TAU, 18, sc, 1.5)
				for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					draw_line(p + d * 6.0, p + d * 11.0, sc, 1.5)
		draw_string(f, Vector2(o.x + 50, y), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
		y += h


func _draw_ice(view: Rect2, night: bool) -> void:
	# Charted limit of the pack ice, hatched to the north.
	var ice_col := Color(0.25, 0.45, 0.8, 0.85) if not night else Color(0.55, 0.7, 0.95, 0.8)
	var pts := PackedVector2Array()
	var n := 64
	for k in n + 1:
		var x := lerpf(view.position.x, view.end.x, float(k) / float(n))
		pts.append(w2s(x, area.geo.ice_edge_z(x)))
	var fill := PackedVector2Array(pts)
	fill.append(Vector2(size.x + 10, minf(-10.0, pts[pts.size() - 1].y)))
	fill.append(Vector2(-10, minf(-10.0, pts[0].y)))
	if pts[0].y > 0.0 or pts[pts.size() - 1].y > 0.0:
		var poly_ok := true
		for q in pts:
			if is_nan(q.x) or is_nan(q.y):
				poly_ok = false
		if poly_ok:
			var tri := Geometry2D.triangulate_polygon(fill)
			if not tri.is_empty():
				draw_colored_polygon(fill, Color(0.75, 0.85, 1.0, 0.18) if not night else Color(0.3, 0.4, 0.55, 0.18))
	for i in pts.size() - 1:
		if i % 2 == 0:
			draw_line(pts[i], pts[i + 1], ice_col, 1.6)
	# Hatch strokes inside the pack.
	var step := 34.0
	var y := fmod(w2s(0, 0).y, step)
	while y < size.y:
		var x2 := fmod(w2s(0, 0).x, step)
		while x2 < size.x:
			var w := screen_to_world(Vector2(x2, y))
			if w.z < area.geo.ice_edge_z(w.x) - 2000.0:
				draw_line(Vector2(x2, y), Vector2(x2 + 9, y - 9), Color(ice_col.r, ice_col.g, ice_col.b, 0.35), 1.0)
			x2 += step
		y += step
	if _mpp < 900.0:
		var mid := view.position.x + view.size.x * 0.3
		var lp := w2s(mid, area.geo.ice_edge_z(mid))
		if lp.y > 30.0 and lp.y < size.y - 60.0:
			draw_string(UiStyle.display(), lp + Vector2(0, -8), "PACK ICE LIMIT (as charted)  ·  NO SURFACING NORTH OF IT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ice_col)
	# Icebergs from ice reports (older, uncertain positions).
	var f := UiStyle.mono()
	for r in reported_ice:
		var p := world_to_screen(r["pos"])
		if p.x < -20.0 or p.x > size.x + 20.0 or p.y < -20.0 or p.y > size.y + 20.0:
			continue
		var age_h := (clock.seconds - float(r["t"])) / 3600.0
		var unc := maxf((300.0 + age_h * 400.0) / _mpp, 3.0)
		draw_arc(p, unc, 0.0, TAU, 24, Color(ice_col.r, ice_col.g, ice_col.b, 0.35), 1.0)
		_berg_glyph(p, Color(ice_col.r, ice_col.g, ice_col.b, 0.65))
		if _mpp < 120.0:
			draw_string(f, p + Vector2(8, 4), "Berg rep. keel ~%d m (%dh old)" % [int(round(float(r["keel"]) / 10.0) * 10), int(age_h)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ice_col)


func _berg_glyph(p: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 3), p + Vector2(-2, -4), p + Vector2(1, -2), p + Vector2(4, -5), p + Vector2(6, 3)]), col)


func _draw_patrol(fd: Font) -> void:
	if sector_radius > 0.0:
		var sc := world_to_screen(sector_center)
		draw_arc(sc, sector_radius / _mpp, 0.0, TAU, 96, Color(0.95, 0.55, 0.1, 0.8), 2.0)
		draw_string(fd, sc + Vector2(-80, -sector_radius / _mpp - 8), "PATROL SECTOR KESTREL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.45, 0.05))
	var rv := world_to_screen(rv_point)
	draw_arc(rv, 9.0, 0.0, TAU, 24, Color(0.1, 0.6, 0.3), 2.0)
	draw_string(fd, rv + Vector2(12, 4), "RV  HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.55, 0.3))
	for m in marks:
		var mp := world_to_screen(m["pos"])
		draw_circle(mp, 4.0, m["color"])
		draw_string(fd, mp + Vector2(8, 4), String(m["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, m["color"])


func _draw_track_and_route(f: Font, night: bool) -> void:
	var own_col := Color(0.0, 0.45, 0.75) if not night else Color(0.45, 0.85, 1.0)
	if track.size() > 1:
		var pts := PackedVector2Array()
		for t in track:
			pts.append(w2s(float(t[0]), float(t[1])))
		pts.append(world_to_screen(sub.global_position))
		draw_polyline(pts, Color(own_col.r, own_col.g, own_col.b, 0.45), 1.0)
	var route_col := Color(0.8, 0.15, 0.55) if not night else Color(1.0, 0.5, 0.75)
	var prev := sub.global_position
	for i in route.size():
		var wp := route[i]
		var a := world_to_screen(prev)
		var b := world_to_screen(wp)
		draw_dashed_line(a, b, route_col, 2.0, 10.0)
		draw_arc(b, 6.0, 0.0, TAU, 16, route_col, 2.0)
		draw_string(f, b + Vector2(9, -8), "WP%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, route_col)
		if a.distance_to(b) > 120.0:
			var l := leg(prev, wp)
			var mid := (a + b) * 0.5
			var txt := "%03d°  %.1f nm  %s" % [int(l["brg"]), float(l["dist"]) / NM, dur_text(hours(float(l["dist"]), planned_knots))]
			draw_string(f, mid + Vector2(8, -6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, route_col)
		prev = wp


func _draw_contact(c: Contact, f: Font) -> void:
	if c.kind == "ICE":
		var p := world_to_screen(c.est_pos)
		var r := maxf(float(c.berg.get("r", 30.0)) * 1.3 / _mpp, 4.0)
		draw_circle(p, r, Color(0.5, 0.7, 0.95, 0.5))
		_berg_glyph(p, Color(0.2, 0.4, 0.75))
		if _mpp < 80.0:
			draw_string(f, p + Vector2(r + 4, 4), "%s keel ~%d m" % [c.id, int(round(float(c.berg.get("keel", 0.0)) / 10.0) * 10)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.2, 0.4, 0.75))
		return
	var aff := c.affiliation.to_lower()
	var col := Settings.contact_color("lost" if c.status == "LOST" else aff)
	if not _night:
		col = col.darkened(0.25)
	var own := world_to_screen(sub.global_position)
	if c.range_err > 0.3 and c.status != "LOST":
		var dir := Vector2(sin(deg_to_rad(c.bearing)), -cos(deg_to_rad(c.bearing)))
		draw_line(own, own + dir * 2400.0, Color(col.r, col.g, col.b, 0.45), 1.0)
		draw_string(f, own + dir * minf(240.0, size.x * 0.3), "%s  BRG %03d  (no range)" % [c.id, int(c.bearing)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		return
	var p2 := world_to_screen(c.est_pos)
	var along := maxf(c.range_err * c.range_est / _mpp, 4.0)
	var across := maxf(along * 0.35, 3.0)
	var dir2 := (p2 - own).normalized() if p2.distance_to(own) > 1.0 else Vector2.UP
	var pts := PackedVector2Array()
	for k in 25:
		var a := TAU * float(k) / 24.0
		pts.append(p2 + dir2 * cos(a) * along + Vector2(-dir2.y, dir2.x) * sin(a) * across)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.6), 1.0)
	_shape(p2, aff, col)
	var crs := float(c.ais["course"]) if c.ais.has("course") else c.est_course
	var spd := float(c.ais["speed"]) if c.ais.has("speed") else c.est_speed
	if crs >= 0.0 and spd > 0.5:
		var v := Vector2(sin(deg_to_rad(crs)), -cos(deg_to_rad(crs))) * spd * 0.5144 * 900.0 / _mpp
		draw_line(p2, p2 + v, col, 1.5)
	var tag := "%s %s" % [c.id, c.label()]
	if c.status == "LOST":
		tag += "  (lost, last pos)"
	draw_string(f, p2 + Vector2(10, -8), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _shape(p: Vector2, aff: String, col: Color) -> void:
	match aff:
		"hostile":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), col)
		"suspect":
			draw_polyline(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0), p + Vector2(0, -7)]), col, 2.0)
		"friendly":
			draw_arc(p, 6.0, 0.0, TAU, 18, col, 2.0)
		"neutral":
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col, false, 2.0)
		_:
			for o in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
				draw_arc(p + o, 3.5, 0.0, TAU, 10, col, 1.5)


func _draw_aircraft(a: Dictionary, f: Font) -> void:
	var p := world_to_screen(a["pos"])
	var col: Color = a.get("color", Color(0.6, 0.3, 0.1))
	var kind := String(a.get("kind", "confirmed"))
	if a.has("from"):
		# ESM: a bearing line from where it was heard; the range is a guess.
		var o := world_to_screen(a["from"])
		var dir := Vector2(sin(deg_to_rad(float(a["brg"]))), -cos(deg_to_rad(float(a["brg"]))))
		var far := o + dir * maxf(o.distance_to(p) * 1.6, 60.0)
		draw_dashed_line(o, far, Color(col.r, col.g, col.b, 0.55), 1.0, 6.0)
	elif kind == "lkp" or kind == "suspected":
		draw_arc(p, clampf(float(a.get("unc", 2000.0)) / _mpp, 6.0, 260.0), 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.4), 1.0)
	_air_glyph(p, col, kind == "confirmed")
	draw_string(f, p + Vector2(10, -6), String(a.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _weapon_colors(kind: String, state: String) -> Color:
	if state in WeaponPlot.STATES_ENDED and kind != "detonation":
		return Color(0.45, 0.47, 0.5, 0.8) if not _night else Color(0.55, 0.45, 0.42, 0.8)
	match kind:
		"own_torpedo":
			return Color(0.0, 0.45, 0.75) if not _night else Color(0.45, 0.85, 1.0)
		"detonation":
			var c := Color(0.95, 0.42, 0.0) if not _night else Color(1.0, 0.6, 0.35)
			if state in WeaponPlot.STATES_ENDED:
				c.a = 0.75
			return c
	var h := Settings.contact_color("hostile")
	return h.darkened(0.2) if not _night else h


## A torpedo: a narrow dart along its heading; filled when its position is
## current (telemetry, or a firm detection), open when estimated.
func _torpedo_glyph(p: Vector2, heading: float, col: Color, filled: bool) -> void:
	var fw := Vector2(sin(heading), -cos(heading))
	var rt := Vector2(-fw.y, fw.x)
	var pts := PackedVector2Array([p + fw * 9.0, p + rt * 3.0 - fw * 5.0, p - fw * 7.0, p - rt * 3.0 - fw * 5.0, p + fw * 9.0])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		draw_polyline(pts, col, 1.5)


## A charge (depth charge, ASW rocket salvo): a ring with a cross.
func _charge_glyph(p: Vector2, col: Color) -> void:
	draw_arc(p, 7.0, 0.0, TAU, 18, col, 1.6)
	draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), col, 1.4)
	draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), col, 1.4)


## A detonation heard: a burst.
func _burst_glyph(p: Vector2, col: Color) -> void:
	for k in 8:
		var a := TAU * float(k) / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_line(p + d * 3.0, p + d * (9.0 if k % 2 == 0 else 6.0), col, 1.6)


func _draw_weapon(w: Dictionary, f: Font) -> void:
	var kind := String(w["kind"])
	var state := String(w["state"])
	var col := _weapon_colors(kind, state)
	var p := world_to_screen(w["pos"])
	if p.x < -60.0 or p.x > size.x + 60.0 or p.y < -60.0 or p.y > size.y + 60.0:
		return
	var stale := state in WeaponPlot.STATES_ENDED
	# Short track behind it.
	var tr: Array = w["trail"]
	if tr.size() > 1 and kind != "detonation":
		var pts := PackedVector2Array()
		for q in tr:
			pts.append(w2s((q as Vector2).x, (q as Vector2).y))
		if not stale:
			pts.append(p)
		if state == "current":
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.55), 1.2)
		else:
			for i in pts.size() - 1:
				draw_dashed_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, 0.45), 1.0, 4.0)
	# How far off an estimate may be.
	var unc := float(w["unc"]) / _mpp
	if unc > 5.0 and not stale:
		draw_arc(p, minf(unc, 400.0), 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.3), 1.0)
	match kind:
		"own_torpedo", "hostile_torpedo":
			_torpedo_glyph(p, float(w["heading"]), col, state == "current")
		"charge":
			_charge_glyph(p, col)
		"detonation":
			_burst_glyph(p, col)
	if stale and kind != "detonation":
		draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), col, 1.5)
		draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), col, 1.5)
	var tag := String(w["label"])
	match state:
		"current":
			tag += "  WIRE" if kind == "own_torpedo" else "  DETECTED"
		"estimated":
			tag += "  EST."
		_:
			tag += "  %s %s" % [String(w["note"]).to_upper(), ChartView.clock_text(float(w["ended_t"]))]
	draw_string(f, p + Vector2(11, -7), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## The drone: a small quad cross, its leg to where it is going, and the
## reach of its radio link around the boat.
func _drone_glyph(p: Vector2, col: Color) -> void:
	draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), col, 1.5)
	draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), col, 1.5)
	for d in [Vector2(-6, -6), Vector2(6, 6), Vector2(-6, 6), Vector2(6, -6)]:
		draw_arc(p + d, 3.0, 0.0, TAU, 10, col, 1.2)


func _draw_drone(f: Font) -> void:
	var col := Color(0.1, 0.55, 0.35) if not _night else Color(0.55, 0.9, 0.65)
	var own := world_to_screen(sub.global_position)
	draw_arc(own, ReconDrone.LINK_RANGE / _mpp, 0.0, TAU, 96, Color(col.r, col.g, col.b, 0.35), 1.0)
	var p := world_to_screen(drone.pos)
	var goal := world_to_screen(sub.global_position if drone.state == "returning" else drone.target)
	if p.distance_to(goal) > 4.0:
		draw_dashed_line(p, goal, Color(col.r, col.g, col.b, 0.6), 1.2, 5.0)
	_drone_glyph(p, col)
	draw_string(f, p + Vector2(11, -7), "DRONE  %d%%%s" % [int(drone.battery * 100.0), "  RETURNING" if drone.state == "returning" else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


static func clock_text(t: float) -> String:
	var h := fposmod(t / 3600.0, 24.0)
	return "%02d:%02d" % [int(h), int(fposmod(h * 60.0, 60.0))]


func _air_glyph(p: Vector2, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, 4), p + Vector2(0, 1), p + Vector2(-7, 4), p + Vector2(0, -8)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		draw_polyline(pts, col, 1.5)


## A unit known only from a report: hollow diamond, a circle of doubt that
## grows with the report's age, and its designation.
func _draw_intel_mark(m: Dictionary, f: Font) -> void:
	var p := world_to_screen(m["pos"])
	var col: Color = m.get("color", Color(0.5, 0.5, 0.5))
	# The circle of doubt grows with the report's age; past a point it says
	# little more than "somewhere around here", so it is capped.
	var r := minf(float(m.get("unc", 0.0)), 50000.0) / _mpp
	if r > 4.0:
		draw_arc(p, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.3), 1.0)
	var pts := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0), p + Vector2(0, -7)])
	draw_polyline(pts, col, 1.5)
	draw_string(f, p + Vector2(10, 4), String(m.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _draw_ownship() -> void:
	var col := Color(0.0, 0.45, 0.75) if not _night else Color(0.45, 0.85, 1.0)
	var op := world_to_screen(sub.global_position)
	draw_arc(op, maxf(dr_error / _mpp, 4.0), 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.5), 1.0)
	var hd := sub.heading
	var fw := Vector2(sin(hd), -cos(hd))
	var rt := Vector2(-fw.y, fw.x)
	draw_colored_polygon(PackedVector2Array([op + fw * 12.0, op - fw * 7.0 + rt * 6.0, op - fw * 7.0 - rt * 6.0]), col)
	var oc := Vector2(sin(sub.ordered_heading), -cos(sub.ordered_heading))
	var ahead := sub.speed * 900.0 / _mpp
	draw_line(op, op + fw * maxf(ahead, 30.0), col, 2.0)
	draw_dashed_line(op, op + oc * 160.0, Color(col.r, col.g, col.b, 0.55), 1.5, 6.0)


func _draw_selection() -> void:
	if _selected.is_empty():
		return
	var p := world_to_screen(_selected["pos"])
	var col := Color(0.9, 0.4, 0.0)
	draw_arc(p, 11.0, 0.0, TAU, 24, col, 1.5)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_line(p + d * 8.0, p + d * 16.0, col, 1.5)
	if _selected.get("kind") == "contact" and sensors:
		var sol := intercept_for(String(_selected["id"]))
		if sol.has("aim") and not sol.has("none"):
			var ap := world_to_screen(sol["aim"])
			draw_dashed_line(world_to_screen(sub.global_position), ap, col, 1.5, 6.0)
			draw_arc(ap, 6.0, 0.0, TAU, 16, col, 1.5)


func _draw_scale(f: Font, ink: Color) -> void:
	var target := 160.0 * _mpp
	var nm := 0.1
	for n in [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0]:
		if float(n) * NM <= target:
			nm = float(n)
	var px := nm * NM / _mpp
	var base := Vector2(30, size.y - 96)
	draw_rect(Rect2(base - Vector2(8, 22), Vector2(px + 16, 34)), Color(1, 1, 1, 0.6) if not _night else Color(0, 0, 0, 0.6))
	draw_line(base, base + Vector2(px, 0), ink, 2.0)
	for k in 3:
		var x := base.x + px * float(k) / 2.0
		draw_line(Vector2(x, base.y - 4), Vector2(x, base.y + 4), ink, 1.5)
	draw_string(f, base + Vector2(0, -8), "%s nm   (%.1f km)" % [str(nm), nm * NM / 1000.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	var na := Vector2(size.x - 470, size.y - 120)
	draw_line(na + Vector2(0, 22), na + Vector2(0, -22), ink, 1.5)
	draw_colored_polygon(PackedVector2Array([na + Vector2(0, -26), na + Vector2(-6, -12), na + Vector2(6, -12)]), ink)
	draw_string(UiStyle.display(), na + Vector2(-5, -32), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)


func _draw_cursor(f: Font, ink: Color) -> void:
	var d := area.seabed_depth(_hover_world.x, _hover_world.y)
	var txt := "%s   %s" % [Geography.latlon_text(_hover_world.x, _hover_world.y), ("depth %d m" % int(d)) if d > 0.0 else "land"]
	var p := Vector2(24, size.y - 70)
	draw_rect(Rect2(p - Vector2(6, 14), Vector2(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12, 20)), Color(1, 1, 1, 0.6) if not _night else Color(0, 0, 0, 0.6))
	draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
