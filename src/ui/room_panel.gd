class_name RoomPanel
extends Control
## The engine room, the mess and the captain's cabin as a working 2D
## interface (in place of the provisional 3D rooms): a live plant mimic and
## the engineer's view aft; who is in the mess and what is on; the captain's
## desk with the log, intelligence, rest and what the crew have brought to
## the captain. Shows only what someone standing there would know.

signal action(id: String, arg: String)

var main: Node
var room := ""                     # "engine", "mess", "cabin"
var sub: Submarine
var crew: Crew
var clock: GameClock
var conscience: Conscience
var _title: Label
var _sub_title: Label
var _side: RichTextLabel
var _buttons: HBoxContainer
var _people: VBoxContainer
var _t := 0.0

const BG := Color(0.035, 0.045, 0.055)
const INK := Color(0.78, 0.86, 0.9)
const DIM := Color(0.45, 0.52, 0.56)
const OK := Color(0.45, 0.85, 0.55)
const WARN := Color(0.95, 0.72, 0.25)
const BAD := Color(0.95, 0.32, 0.25)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = UiStyle.label("", 26, UiStyle.CYAN, UiStyle.title())
	_title.position = Vector2(60, 70)
	add_child(_title)
	_sub_title = UiStyle.label("", 14, DIM)
	_sub_title.position = Vector2(62, 108)
	add_child(_sub_title)
	_side = RichTextLabel.new()
	_side.bbcode_enabled = true
	_side.fit_content = true
	_side.add_theme_font_override("normal_font", UiStyle.display())
	_side.add_theme_font_override("mono_font", UiStyle.mono())
	_side.add_theme_font_override("bold_font", UiStyle.title())
	_side.add_theme_font_size_override("normal_font_size", 15)
	_side.add_theme_font_size_override("mono_font_size", 14)
	_side.add_theme_font_size_override("bold_font_size", 16)
	_side.add_theme_color_override("default_color", INK)
	add_child(_side)
	_people = VBoxContainer.new()
	_people.add_theme_constant_override("separation", 4)
	add_child(_people)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	add_child(_buttons)
	visible = false


func open(r: String) -> void:
	room = r
	visible = true
	_rebuild()


func _rebuild() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var acts: Array = []
	match room:
		"engine":
			_title.text = "ENGINE ROOM"
			_sub_title.text = "Machinery spaces aft  ·  plant status as the watch keeper sees it"
			acts = [["talk:erik", "Talk to the chief"], ["orders", "Engineering orders (Tab)"]]
		"mess":
			_title.text = "MESS"
			_sub_title.text = "Galley and mess deck  ·  meals at 07:00, 12:00 and 18:00"
			acts = [["poker", "Sit in on cards"], ["cup", "Play for the Mess Cup"], ["coffee", "Coffee"], ["talk:basse", "Talk to Basse"]]
		"cabin":
			_title.text = "CAPTAIN'S CABIN"
			_sub_title.text = "A bunk, a desk and a door that closes"
			acts = [["log", "Captain's Log (L)"], ["intel", "Naval intelligence (I)"], ["rest", "Rest  ·  hand over the watch"], ["coffee", "Coffee"]]
	for a in acts:
		var b := UiStyle.button(String(a[1]), 14)
		b.pressed.connect(func() -> void: action.emit(String(a[0]), ""))
		_buttons.add_child(b)
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if fmod(_t, 0.5) < delta:
		_refresh()
	queue_redraw()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var w := size.x
	var h := size.y
	_side.position = Vector2(w * 0.62, 150)
	_side.size = Vector2(w * 0.34, h - 300)
	_side.custom_minimum_size = Vector2(w * 0.34, 0)
	_people.position = Vector2(60, 150) if room != "engine" else Vector2(60, h * 0.62)
	_buttons.position = Vector2(60, h - 120)


func _refresh() -> void:
	_layout()
	for c in _people.get_children():
		c.queue_free()
	var t := ""
	match room:
		"engine":
			t = _engine_text()
		"mess":
			t = _mess_text()
		"cabin":
			t = _cabin_text()
	_side.text = t
	var loc: String = {"engine": "engine", "mess": "mess", "cabin": "cabin"}.get(room, "")
	if room == "cabin":
		_people.add_child(UiStyle.label("WATCH BILL  ·  NOW", 13, DIM))
		var group := ""
		var role_txt := {"XO": "XO", "NAVIGATOR": "navigator", "SONAR": "sonar officer", "WATCH_SONAR": "sonar", "HELM": "helm",
			"ENGINEER": "chief engineer", "MACHINIST": "machinist", "COOK": "cook"}
		for w in crew.watchbill():
			if String(w["group"]) != group:
				group = String(w["group"])
				var gl := {"CONTROL ROOM": "CONTROL ROOM  ·  bridge watch", "MACHINERY": "MACHINERY  ·  engineering watch",
					"GALLEY": "GALLEY  ·  galley duty, not a watch"}
				_people.add_child(UiStyle.label(String(gl.get(group, group)), 12, DIM))
			var st := String(w["status"])
			var col := INK if st in ["ON WATCH", "ON DUTY"] else (BAD if st == "UNAVAILABLE" else DIM)
			_people.add_child(UiStyle.label("  %-7s %-12s %-15s %s" % [String(w["short"]), st, String(role_txt.get(String(w["role"]), "")), String(w["activity"])], 13, col, UiStyle.mono()))
		var manned: Array[String] = []
		for r in [["XO", "XO"], ["NAVIGATOR", "NAV"], ["SONAR", "SONAR"], ["HELM", "HELM"], ["ENGINEER", "ENG"]]:
			var h: CrewMember = crew.role_holder(String(r[0]))
			manned.append("%s %s" % [String(r[1]), h.short if h else "(unmanned)"])
		var ml := UiStyle.label("STATIONS  " + "  ·  ".join(manned), 12, DIM, UiStyle.mono())
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD
		ml.custom_minimum_size = Vector2(size.x * 0.5, 0)
		_people.add_child(ml)
		_people.add_child(UiStyle.label(" ", 8, DIM))
		_people.add_child(UiStyle.label("PATROL ORDERS", 13, DIM))
		for o in main.patrol.objectives:
			var mark := "✓" if bool(o["done"]) else ("✗" if bool(o["failed"]) else "·")
			var lo := UiStyle.label("%s  %s" % [mark, String(o["text"])], 14, INK)
			lo.autowrap_mode = TextServer.AUTOWRAP_WORD
			lo.custom_minimum_size = Vector2(size.x * 0.5, 0)
			_people.add_child(lo)
	if room != "cabin":
		var here: Array = crew.present(loc)
		_people.add_child(UiStyle.label("HERE NOW" if not here.is_empty() else "NOBODY HERE JUST NOW", 13, DIM))
		for m in here:
			var cm := m as CrewMember
			var b := UiStyle.button("%s  ·  %s" % [cm.short, cm.activity], 13)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func() -> void: action.emit("talk:" + cm.id, ""))
			_people.add_child(b)


static func _bar(v: float) -> String:
	var n := clampi(int(round(v * 10.0)), 0, 10)
	return "■".repeat(n) + "□".repeat(10 - n)


func _engine_text() -> String:
	var t := "[b]PLANT[/b]\n[code]"
	t += "BATTERY     %s %3d%%\n" % [_bar(sub.battery / 100.0), int(sub.battery)]
	t += "AIP FUEL    %s %3d h\n" % [_bar(sub.aip_hours / 96.0), int(sub.aip_hours)]
	t += "DIESELS     %s\n" % ("RUNNING (snorkel)" if sub.diesels_running else "stopped")
	t += "PROPULSION  %s\n" % ("%s · %.1f kt" % [Submarine.SPEED_NAMES[sub.speed_step], sub.speed / Submarine.KNOT])
	t += "[/code]\n[b]EQUIPMENT[/b]\n[code]"
	for k in sub.equipment:
		var v := float(sub.equipment[k])
		t += "%-11s %s %s\n" % [String(k).to_upper(), _bar(v), "ok" if v > 0.8 else ("degraded" if v > 0.3 else "FAILED")]
	t += "[/code]\n[b]HULL[/b]\n[code]"
	t += "INTEGRITY   %s %3d%%\n" % [_bar(sub.hull / 100.0), int(sub.hull)]
	t += "FATIGUE     %s\n" % ("none to speak of" if sub.stress < 0.05 else ("some" if sub.stress < 0.3 else "serious"))
	t += "LEAKS       %s\n" % ("none" if sub.leak < 0.02 else ("weeping" if sub.leak < 0.2 else "taking water"))
	t += "FLOODING    %s\n" % ("none" if sub.flooding < 0.02 else "%d%%" % int(sub.flooding * 100.0))
	var pl := sub.pressure_load()
	t += "PRESSURE    %s[/code]\n" % ("within limits" if pl <= 0.0 else ("working hard" if pl < 0.5 else "DANGEROUS"))
	return t


func _mess_text() -> String:
	var h := clock.hours()
	var next := "breakfast at 07:00" if h < 7.0 or h >= 18.5 else ("lunch at 12:00" if h < 12.0 else "dinner at 18:00")
	var t := "[b]TODAY[/b]\nNext: %s.\n%s\n\n" % [next, "Cards on the table this evening." if h > 17.0 or h < 2.0 else "The table is clear."]
	t += "[b]THE SWEETS TALLY[/b]\n[code]"
	var rows: Array = []
	for m in crew.members.values():
		rows.append([(m as CrewMember).short, (m as CrewMember).candy_count()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	for r in rows:
		t += "%-8s %3d\n" % [String(r[0]), int(r[1])]
	t += "[/code]"
	if not crew.mess_cup.is_empty():
		var last: Dictionary = crew.mess_cup[-1]
		t += "\n[b]THE MESS CUP[/b]\nHeld by %s (%d contested).\n" % ["the Captain" if String(last["winner"]) == "CAPTAIN" else String(last["winner"]).capitalize(), crew.mess_cup.size()]
	return t


func _cabin_text() -> String:
	var t := "[b]ON THE DESK[/b]\n"
	t += "Day %d, %s.\n\n" % [clock.day(), clock.short_time()]
	var brought := ""
	for m in crew.members.values():
		var cm := m as CrewMember
		for o in cm.opinions:
			if bool(o["raised"]):
				brought += "· %s came to talk about %s.\n" % [cm.short.capitalize(), String(o["text"])]
		if not cm.available:
			brought += "· %s has stood down from duty for now.\n" % cm.short.capitalize()
	for id in conscience.reassignment_requests():
		brought += "· %s has asked to be reassigned.\n" % String(crew.members[id].short).capitalize()
	t += "[b]WHAT THE CREW HAVE BROUGHT YOU[/b]\n" + (brought if brought != "" else "Nothing. The door has stayed shut.\n")
	t += "\n[b]STANDING WITH NORTHERN COMMAND[/b]\n%s\n" % String(main.standing.state).capitalize()
	return t


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# Faint plating seams: this is still a steel boat.
	for i in range(0, int(w), 160):
		draw_line(Vector2(i, 0), Vector2(i, h), Color(1, 1, 1, 0.018), 1.0)
	draw_line(Vector2(0, 136), Vector2(w, 136), Color(0.4, 0.6, 0.7, 0.25), 1.0)
	if room == "engine":
		_draw_mimic(Rect2(60, 160, w * 0.55 - 60, h * 0.42))


## A plant mimic: diesel generators, battery, AIP, main motor and shaft,
## coloured by state, labelled (never colour alone).
func _draw_mimic(r: Rect2) -> void:
	var f := UiStyle.mono()
	var line := Color(0.35, 0.5, 0.58)
	var x0 := r.position.x
	var y0 := r.position.y
	var bw := r.size.x
	var on := sub.diesels_running
	var bat := sub.battery / 100.0
	var prop := float(sub.equipment["propulsion"])
	var boxes := [
		["DIESEL 1", Rect2(x0, y0, 150, 64), OK if on else DIM, "RUN" if on else "STOP"],
		["DIESEL 2", Rect2(x0, y0 + 90, 150, 64), OK if on else DIM, "RUN" if on else "STOP"],
		["AIP", Rect2(x0, y0 + 180, 150, 64), OK if sub.aip_hours > 1.0 else BAD, "%d h" % int(sub.aip_hours)],
		["BATTERY", Rect2(x0 + bw * 0.38, y0 + 60, 170, 120), OK if bat > 0.4 else (WARN if bat > 0.15 else BAD), "%d%%" % int(sub.battery)],
		["MAIN MOTOR", Rect2(x0 + bw * 0.72, y0 + 80, 150, 80), OK if prop > 0.8 else (WARN if prop > 0.3 else BAD), "%.0f kt" % (sub.speed / Submarine.KNOT)],
	]
	# Buses.
	var bus_x := x0 + bw * 0.38 - 30.0
	draw_line(Vector2(x0 + 150, y0 + 32), Vector2(bus_x, y0 + 32), line, 2.0)
	draw_line(Vector2(x0 + 150, y0 + 122), Vector2(bus_x, y0 + 122), line, 2.0)
	draw_line(Vector2(x0 + 150, y0 + 212), Vector2(bus_x, y0 + 212), line, 2.0)
	draw_line(Vector2(bus_x, y0 + 32), Vector2(bus_x, y0 + 212), line, 2.0)
	draw_line(Vector2(bus_x, y0 + 120), Vector2(x0 + bw * 0.38, y0 + 120), line, 2.0)
	draw_line(Vector2(x0 + bw * 0.38 + 170, y0 + 120), Vector2(x0 + bw * 0.72, y0 + 120), line, 2.0)
	# Shaft and screw.
	var sx := x0 + bw * 0.72 + 150
	draw_line(Vector2(sx, y0 + 120), Vector2(sx + 70, y0 + 120), line, 4.0)
	var spin := _t * (sub.speed * 0.6)
	for k in 3:
		var a := spin + TAU * k / 3.0
		draw_line(Vector2(sx + 78, y0 + 120), Vector2(sx + 78, y0 + 120) + Vector2(cos(a), sin(a)) * 22.0, line, 3.0)
	for bx in boxes:
		var rr: Rect2 = bx[1]
		var col: Color = bx[2]
		draw_rect(rr, Color(col.r, col.g, col.b, 0.12))
		draw_rect(rr, col, false, 1.5)
		draw_string(f, rr.position + Vector2(10, 22), String(bx[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		draw_string(f, rr.position + Vector2(10, rr.size.y - 12), String(bx[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	# Battery charge level.
	var br: Rect2 = boxes[3][1]
	draw_rect(Rect2(br.position + Vector2(10, 34), Vector2((br.size.x - 20) * bat, 14)), boxes[3][2])
	draw_rect(Rect2(br.position + Vector2(10, 34), Vector2(br.size.x - 20, 14)), DIM, false, 1.0)
