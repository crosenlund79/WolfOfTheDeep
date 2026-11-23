class_name ContactList
extends PanelContainer
## Structured contact table: one row per contact, fixed columns, restrained
## colour plus shape and text (never colour alone). Shows only what the boat
## knows: ranges and identities appear when the crew actually has them.

signal show_on_chart(world_pos: Vector3)
signal log_for(contact_id: String)

const SYMBOL := {"HOSTILE": "◆", "SUSPECT": "◇", "UNKNOWN": "?", "NEUTRAL": "■", "FRIENDLY": "●"}

var main: Node
var sensors: SensorSuite
var sub: Submarine
var clock: GameClock
var selected := ""
var show_ice := false
var show_lost := true
var _rows: VBoxContainer
var _detail: RichTextLabel
var _header: Label
var _refresh_t := 0.0
var _buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel_style(0.94, 14))
	UiStyle.place(self, Vector2(1, 0), Vector2(-1000, 84), Vector2(970, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_child(UiStyle.label("CONTACTS", 18, UiStyle.CYAN))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var ice := UiStyle.toggle("ICE", show_ice, 12)
	ice.toggled.connect(func(on: bool) -> void:
		show_ice = on
		refresh())
	top.add_child(ice)
	var lost := UiStyle.toggle("LOST", show_lost, 12)
	lost.toggled.connect(func(on: bool) -> void:
		show_lost = on
		refresh())
	top.add_child(lost)
	var close := UiStyle.button("✕  K", 12)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	v.add_child(top)
	_header = UiStyle.label("", 12, UiStyle.DIM, UiStyle.mono())
	_header.text = _fmt_row("", "ID", "CLASSIFICATION", "BRG", "RANGE", "CRS / SPD", "LAST", "CONFIDENCE", "STATUS")
	v.add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	v.add_child(scroll)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(940, 0)
	_detail.add_theme_font_override("normal_font", UiStyle.display())
	_detail.add_theme_font_override("mono_font", UiStyle.mono())
	_detail.add_theme_font_size_override("normal_font_size", 14)
	_detail.add_theme_font_size_override("mono_font_size", 13)
	_detail.add_theme_color_override("default_color", UiStyle.WHITE)
	v.add_child(_detail)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var chart_b := UiStyle.button("Show on chart", 13)
	chart_b.pressed.connect(func() -> void:
		var c := _find(selected)
		if c:
			show_on_chart.emit(c.est_pos))
	actions.add_child(chart_b)
	var log_b := UiStyle.button("Log entries", 13)
	log_b.pressed.connect(func() -> void:
		if selected != "":
			log_for.emit(selected))
	actions.add_child(log_b)
	v.add_child(actions)
	visible = false


static func _fmt_row(sym: String, id: String, cls: String, brg: String, rng: String, cs: String, last: String, conf: String, status: String) -> String:
	return "%-2s%-5s %-22s %-4s %-13s %-15s %-7s %-14s %s" % [sym, id, cls.substr(0, 22), brg, rng, cs, last, conf, status]


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func _find(id: String) -> Contact:
	if sensors == null:
		return null
	for c in sensors.contacts:
		if c.id == id:
			return c
	return null


static func ago(seconds: float) -> String:
	if seconds < 90.0:
		return "now"
	if seconds < 3600.0:
		return "%d min" % int(seconds / 60.0)
	return "%dh%02d" % [int(seconds / 3600.0), int(fposmod(seconds / 60.0, 60.0))]


static func range_text(c: Contact) -> String:
	if c.range_err > 0.3 and c.kind != "ICE":
		return "----"
	var nm := c.range_est / 1852.0
	var err := c.range_err * nm
	if c.kind == "ICE" or err < 0.05:
		return "%5.1f nm" % nm
	return "%4.1f±%.1f" % [nm, err]


static func confidence(c: Contact) -> String:
	var src := ""
	if c.sources.has("sonar"):
		src += "S"
	if c.sources.has("visual"):
		src += "V"
	if c.sources.has("ais"):
		src += "A"
	if c.sources.has("report"):
		src += "R"
	var level: String = {"UNCLASSIFIED": "LOW", "PROBABLE": "FAIR", "CLASSIFIED": "GOOD", "IDENTIFIED": "ID", "ICE": "VISUAL/SON"}.get(c.certainty_text(), "")
	return "%s %s" % [level, src]


func refresh() -> void:
	if sensors == null:
		return
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_buttons.clear()
	var now := clock.seconds if clock else 0.0
	var list: Array = sensors.contacts.duplicate()
	list.sort_custom(func(a: Contact, b: Contact) -> bool:
		if (a.status == "LOST") != (b.status == "LOST"):
			return a.status != "LOST"
		return a.range_est < b.range_est)
	for c: Contact in list:
		if c.kind == "ICE" and not show_ice:
			continue
		if c.status == "LOST" and not show_lost:
			continue
		var aff := "UNKNOWN" if c.kind != "ICE" else "NEUTRAL"
		if c.kind == "VESSEL":
			aff = c.affiliation
		var col := Settings.contact_color("lost" if c.status == "LOST" else ("ice" if c.kind == "ICE" else aff.to_lower()))
		var sym := "◌" if c.kind == "ICE" else String(SYMBOL.get(aff, "?"))
		var name := c.label() if c.kind != "ICE" else "ICE  keel est. %d m" % int(round(float(c.berg.get("keel", 0.0)) / 10.0) * 10)
		var status := c.status
		if c.status == "TRACKING" and now - c.last_time > 90.0:
			status = "FADING"
		var t := _fmt_row(sym, c.id, name, "%03d" % (int(round(c.bearing)) % 360), range_text(c), c.motion_text() if c.kind == "VESSEL" else "drifting", ago(now - c.last_time), confidence(c), status)
		var b := UiStyle.button(t, 13)
		b.add_theme_font_override("font", UiStyle.mono())
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", col.lightened(0.3))
		if c.id == selected:
			var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
			sb.bg_color = Color(0.12, 0.3, 0.38, 0.8)
			sb.border_color = UiStyle.CYAN
		var cid := c.id
		b.pressed.connect(func() -> void:
			selected = cid
			refresh())
		_rows.add_child(b)
		_buttons[c.id] = b
	_detail.text = _details(_find(selected), now)


func _details(c: Contact, now: float) -> String:
	if c == null:
		return "[color=#8fa6b4]Select a contact for the details the boat holds on it.[/color]"
	var lines: Array[String] = []
	lines.append("[b]%s[/b]   %s   ·   %s" % [c.id, c.label(), c.certainty_text()])
	var srcs: Array[String] = []
	for k in c.sources.keys():
		srcs.append({"sonar": "passive sonar", "visual": "visual (periscope)", "ais": "AIS broadcast", "report": "intelligence report", "ice": "sonar / visual"}.get(k, k))
	lines.append("Sources: %s.   First held %s ago, last observation %s." % [", ".join(srcs) if not srcs.is_empty() else "none current", ago(now - c.first_time), ago(now - c.last_time)])
	lines.append("Bearing %03d true.   Range %s.   Course / speed %s." % [int(round(c.bearing)) % 360, range_text(c) if range_text(c) != "----" else "not yet known (bearing only)", c.motion_text() if c.kind == "VESSEL" else "drifting with the ice"])
	if c.kind == "VESSEL":
		lines.append("Affiliation (assessed): %s.%s" % [c.affiliation.to_lower(), "  AIS: %s, %s." % [c.ais.get("name", "unnamed"), String(c.ais.get("type", "")).to_lower()] if not c.ais.is_empty() else ""])
		if c.cs_conf == "LOW":
			lines.append("[color=#ffb85a]Motion solution is rough: more bearings and a manoeuvre would firm it up.[/color]")
	if c.kind == "ICE":
		lines.append("Estimated keel %d m (sonar and visual estimate; real draught may differ)." % int(round(float(c.berg.get("keel", 0.0)) / 10.0) * 10))
	if c.notes != "":
		lines.append(c.notes)
	return "\n".join(lines)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 1.0
		refresh()
