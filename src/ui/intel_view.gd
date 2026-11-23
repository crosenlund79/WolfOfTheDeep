class_name IntelView
extends PanelContainer
## Naval intelligence (I): units the boat has met or been told about, the
## commanders known to intelligence, the class library, the reports received
## (conflicts kept side by side) and how the captain's conduct is read.
## Shows only what the database holds; nothing from hidden truth.

signal show_on_chart(world_pos: Vector3)

const TABS := ["units", "commanders", "classes", "reports"]
const TAB_NAMES := {"units": "UNITS", "commanders": "COMMANDERS", "classes": "CLASS LIBRARY", "reports": "REPORTS"}

var intel: IntelDB
var clock: GameClock
var sensors: SensorSuite
var sub: Submarine
var tab := "units"
var selected := ""
var _list: VBoxContainer
var _detail: RichTextLabel
var _tab_buttons := {}
var _chart_b: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel_style(0.95, 14))
	UiStyle.place(self, Vector2(0.5, 0), Vector2(-560, 70), Vector2(1120, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(UiStyle.label("NAVAL INTELLIGENCE", 18, UiStyle.CYAN))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	for t in TABS:
		var b := UiStyle.toggle(String(TAB_NAMES[t]), t == tab, 12)
		b.custom_minimum_size = Vector2(128, 0)
		b.pressed.connect(func() -> void:
			tab = String(t)
			selected = ""
			refresh())
		_tab_buttons[t] = b
		top.add_child(b)
	var close := UiStyle.button("✕  I", 12)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	v.add_child(top)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	body.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dscroll := ScrollContainer.new()
	dscroll.custom_minimum_size = Vector2(680, 520)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(660, 0)
	_detail.add_theme_font_override("normal_font", UiStyle.display())
	_detail.add_theme_font_override("mono_font", UiStyle.mono())
	_detail.add_theme_font_override("bold_font", UiStyle.title())
	_detail.add_theme_font_size_override("normal_font_size", 14)
	_detail.add_theme_font_size_override("mono_font_size", 13)
	_detail.add_theme_font_size_override("bold_font_size", 15)
	_detail.add_theme_color_override("default_color", UiStyle.WHITE)
	dscroll.add_child(_detail)
	right.add_child(dscroll)
	_chart_b = UiStyle.button("Show last known position on the chart", 13)
	_chart_b.pressed.connect(_show_on_chart)
	right.add_child(_chart_b)
	body.add_child(right)
	v.add_child(body)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func open_unit(id: String) -> void:
	tab = "units"
	selected = id
	visible = true
	refresh()


static func _age(now: float, t: float) -> String:
	if t < 0.0:
		return "-"
	var h := (now - t) / 3600.0
	return "%d min" % int(h * 60.0) if h < 1.0 else ("%.0f h" % h if h < 48.0 else "%.0f d" % (h / 24.0))


func refresh() -> void:
	if intel == null:
		return
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).button_pressed = t == tab
	for c in _list.get_children():
		c.queue_free()
	var now := clock.seconds
	var rows: Array = []       # [id, text]
	match tab:
		"units":
			var us: Array = intel.units.values()
			us.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["last_update"]) > float(b["last_update"]))
			for u in us:
				rows.append([String(u["id"]), "%s  %s\n   %s · %s · upd. %s" % [String(u["id"]), String(u["designation"]).substr(0, 34),
					String(u["navy"]).to_lower(), String(u["status"]).to_lower(), _age(now, float(u["last_update"]))]])
		"commanders":
			for c in intel.commanders.values():
				if not bool(c["known"]):
					continue
				rows.append([String(c["id"]), "%s  %s\n   %s · %s" % [String(c["codename"]), String(c["rank"]),
					"confidence " + String(c["intel_conf"]).to_lower(), "alive" if bool(c["alive"]) else "reported dead"]])
			rows.append(["captain", "VARG  (your own reputation)\n   as Northern Command reads it"])
		"classes":
			for k in IntelDB.CLASSES:
				var cl: Dictionary = IntelDB.CLASSES[k]
				rows.append([String(k), "%s\n   %s · %s" % [String(cl["name"]), String(cl["type"]), String(cl["navy"]).to_lower()]])
		"reports":
			var rs: Array = intel.reports.duplicate()
			rs.reverse()
			for r in rs:
				var flag := "  ⚠ CONFLICT" if not (r["conflicts"] as Array).is_empty() else ""
				rows.append([String(r["id"]), "%s  %s (%s)%s\n   observed %s ago · received %s ago" % [String(r["id"]), String(r["source"]),
					String(r["grade"]), flag, _age(now, float(r["t_obs"])), _age(now, float(r["t_recv"]))]])
	if rows.is_empty():
		var empty := UiStyle.label({"units": "No units on file yet.", "commanders": "No commanders identified yet.", "reports": "No reports received. Reports arrive with the broadcast; a mast must be up to copy them.", "classes": ""}[tab], 13, UiStyle.DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty.custom_minimum_size = Vector2(380, 0)
		_list.add_child(empty)
	for row in rows:
		var b := UiStyle.button(String(row[1]), 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiStyle.mono())
		b.toggle_mode = true
		b.button_pressed = String(row[0]) == selected
		b.pressed.connect(func() -> void:
			selected = String(row[0])
			refresh())
		_list.add_child(b)
	if selected == "" and not rows.is_empty():
		selected = String(rows[0][0])
	_detail.text = _detail_text()
	_chart_b.visible = tab == "units" and not (intel.unit_by_id(selected).get("last_pos", []) as Array).is_empty()


func _detail_text() -> String:
	var now := clock.seconds
	match tab:
		"units":
			var u := intel.unit_by_id(selected)
			if u.is_empty():
				return ""
			var cl: Dictionary = IntelDB.CLASSES.get(String(u["class"]), {})
			var t := "[b]%s  ·  %s[/b]\n\n" % [String(u["id"]), String(u["designation"])]
			t += "[code]NAVY            %s\n" % String(u["navy"])
			t += "CLASS           %s\n" % ("unknown" if cl.is_empty() else "%s (%s)" % [String(cl["name"]), String(u["class_conf"]).to_lower()])
			t += "STATUS          %s%s\n" % [String(u["status"]), "" if String(u["status_conf"]) == "" else " (" + String(u["status_conf"]).to_lower() + ")"]
			var cmd: Dictionary = intel.commanders.get(String(u["commander"]), {})
			t += "COMMANDER       %s\n" % ("unknown" if cmd.is_empty() else "%s (%s)" % [String(cmd["codename"]), String(u["commander_conf"]).to_lower()])
			t += "CONFIDENCE      %s\n" % String(u["confidence"])
			t += "LAST UPDATE     %s ago\n" % _age(now, float(u["last_update"]))
			var lp: Array = u["last_pos"]
			if lp.size() == 2:
				t += "LAST POSITION   %s ±%.0f nm, %s ago\n" % [Geography.latlon_text(float(lp[0]), float(lp[1])), float(u["last_pos_unc"]) / 1852.0, _age(now, float(u["last_pos_t"]))]
			t += "CAPABILITY      %s\n" % intel.capability_text(u)
			var threat := "NOT HELD"
			for cid in u["contacts"]:
				for c in sensors.contacts:
					if c.id == String(cid) and c.status == "TRACKING":
						threat = IntelDB.tactical_threat(c, sub.global_position, false)
			t += "TACTICAL THREAT %s (now, from what the contact is doing)[/code]\n" % threat
			if not cl.is_empty():
				t += "\n[b]Class characteristics[/b] (library, %s confidence)\n" % String(cl["confidence"]).to_lower()
				t += "[code]SENSORS  %s\nASW      %s\nWEAPONS  %s\nSPEED    %s[/code]\n%s\n" % [String(cl["sensors"]), String(cl["asw"]), String(cl["weapons"]), String(cl["speed"]), String(cl["notes"])]
			t += "\n[b]History[/b]\n"
			var hist: Array = (u["history"] as Array).duplicate()
			hist.reverse()
			for h in hist:
				t += "[code]%s[/code]  %s  [i](%s)[/i]\n" % [ReportFeed.stamp(float(h["t"])), String(h["text"]), String(h["source"])]
			return t
		"commanders":
			if selected == "captain":
				var t2 := "[b]VARG  ·  how the boat's conduct is being read[/b]\n\n"
				t2 += intel.reputation_text() + "\n\n[b]On record[/b]\n"
				for e in intel.captain["events"]:
					t2 += "[code]%s[/code]  %s\n" % [ReportFeed.stamp(float(e["t"])), String(e["text"])]
				return t2
			var c2: Dictionary = intel.commanders.get(selected, {})
			if c2.is_empty():
				return ""
			var t3 := "[b]%s  ·  %s[/b]  (%s confidence)\n\n" % [String(c2["codename"]), String(c2["rank"]), String(c2["intel_conf"]).to_lower()]
			t3 += "Status: %s\n" % ("alive" if bool(c2["alive"]) else "reported not to have survived")
			var ship := ""
			for u2 in intel.units.values():
				if String(u2["commander"]) == selected:
					ship = String(u2["designation"])
			t3 += "Last associated with: %s\n" % (ship if ship != "" else "unknown")
			var tr: Dictionary = c2["traits"]
			# Intelligence gives a reading of character, not numbers.
			t3 += "\n[b]Assessed character[/b]\n"
			t3 += "%s; %s; %s.\n" % ["Aggressive" if float(tr["aggr"]) > 0.6 else ("Measured" if float(tr["aggr"]) > 0.3 else "Restrained"),
				"patient in a search" if float(tr["patience"]) > 0.6 else "impatient", "proud" if float(tr["pride"]) > 0.6 else "pragmatic"]
			t3 += "[i]Assessments of character are based on limited reporting and may be wrong.[/i]\n"
			for h2 in c2["history"]:
				t3 += "[code]%s[/code]  %s\n" % [ReportFeed.stamp(float(h2["t"])), String(h2["text"])]
			return t3
		"classes":
			var cl2: Dictionary = IntelDB.CLASSES.get(selected, {})
			if cl2.is_empty():
				return ""
			var t4 := "[b]%s[/b]  ·  %s\n\n[code]" % [String(cl2["name"]), String(cl2["type"])]
			for k in ["navy", "length", "displacement", "speed", "crew"]:
				t4 += "%-13s %s\n" % [k.to_upper(), String(cl2[k])]
			t4 += "[/code]\n[b]Sensors[/b]  %s\n[b]Anti-submarine[/b]  %s\n[b]Weapons[/b]  %s\n\n%s\n\n[i]Intrinsic capability against a submarine: %s. Library confidence %s.[/i]" % [
				String(cl2["sensors"]), String(cl2["asw"]), String(cl2["weapons"]), String(cl2["notes"]),
				["none", "low", "moderate", "high", "very high"][clampi(int(float(cl2["capability"]) * 5.0), 0, 4)], String(cl2["confidence"]).to_lower()]
			return t4
		"reports":
			var r := intel.report(selected)
			if r.is_empty():
				return ""
			var t5 := "[b]%s[/b]  ·  %s, grade %s  ·  confidence %s\n\n" % [String(r["id"]), String(ReportFeed.SOURCES[String(r["source"])][3]).to_lower(), String(r["grade"]), String(r["conf"]).to_lower()]
			t5 += "[code]EVENT      %s\nOBSERVED   %s\nSENT       %s\nRECEIVED   %s[/code]\n\n" % [ReportFeed.stamp(float(r["t_event"])), ReportFeed.stamp(float(r["t_obs"])), ReportFeed.stamp(float(r["t_sent"])), ReportFeed.stamp(float(r["t_recv"]))]
			t5 += String(r["summary"]) + "\n"
			var p: Array = r["pos"]
			if p.size() == 2:
				t5 += "Position %s ±%.0f nm.\n" % [Geography.latlon_text(float(p[0]), float(p[1])), float(r["unc"]) / 1852.0]
			if not (r["conflicts"] as Array).is_empty():
				t5 += "\n[color=#e0a040]⚠ Conflicts with %s. Both are kept; neither is assumed right.[/color]\n" % ", ".join(r["conflicts"])
			return t5
	return ""


func _show_on_chart() -> void:
	var u := intel.unit_by_id(selected)
	var lp: Array = u.get("last_pos", [])
	if lp.size() == 2:
		show_on_chart.emit(Vector3(float(lp[0]), 0.0, float(lp[1])))
