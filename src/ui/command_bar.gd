class_name CommandBar
extends Control
## The persistent command bar along the bottom edge: stations (active one
## highlighted), essential readouts, time compression and quick access to the
## major interfaces, with the current view's shortcuts in a slim row above.
## Opaque so it stays legible over the sea, the sky, the chart and interiors.

signal request(id: String)

const HEIGHT := 34.0
const HINT_H := 22.0
const VIEWS := [["1", "CONTROL", 0], ["2", "PERISCOPE", 1], ["3", "EXTERIOR", 2], ["4", "SONAR", 3], ["5", "CHART", 4], ["6", "MESS", 5], ["7", "CABIN", 6], ["8", "ENGINE", 7]]

var main: Node
var _tabs: Array[Button] = []
var _values: Label
var _time: Label
var _hint: Label
var _flags: Label
var _quick: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -(HEIGHT + HINT_H)
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_bg := ColorRect.new()
	hint_bg.color = Color(0.0, 0.012, 0.02, 0.72)
	hint_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_bg.anchor_right = 1.0
	hint_bg.offset_bottom = HINT_H
	add_child(hint_bg)
	_hint = UiStyle.label("", 12, Color(0.72, 0.8, 0.86))
	_hint.position = Vector2(16, 3)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_bg.add_child(_hint)
	_flags = UiStyle.label("", 12, UiStyle.AMBER)
	_flags.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_flags.anchor_left = 1.0
	_flags.anchor_right = 1.0
	_flags.offset_left = -900
	_flags.offset_right = -16
	_flags.offset_top = 3
	hint_bg.add_child(_flags)

	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.008, 0.018, 0.026, 0.96)
	sb.border_color = Color(0.25, 0.42, 0.52, 0.8)
	sb.border_width_top = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	bar.add_theme_stylebox_override("panel", sb)
	bar.anchor_right = 1.0
	bar.offset_top = HINT_H
	bar.offset_bottom = HINT_H + HEIGHT
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	bar.add_child(row)
	for v in VIEWS:
		var b := _small_toggle("%s %s" % [v[0], v[1]])
		var idx := int(v[2])
		b.pressed.connect(func() -> void: request.emit("view_%d" % idx))
		row.add_child(b)
		_tabs.append(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(14, 0)
	row.add_child(spacer)
	_values = UiStyle.label("", 14, UiStyle.WHITE, UiStyle.mono())
	_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_values.clip_text = true
	_values.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_values)
	var slower := _small_button("−")
	slower.tooltip_text = "Slower time  ( - )"
	slower.pressed.connect(func() -> void: request.emit("time_down"))
	row.add_child(slower)
	_time = UiStyle.label("", 14, UiStyle.CYAN, UiStyle.mono())
	_time.custom_minimum_size = Vector2(168, 0)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_time)
	var faster := _small_button("+")
	faster.tooltip_text = "Faster time  ( + )"
	faster.pressed.connect(func() -> void: request.emit("time_up"))
	row.add_child(faster)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(10, 0)
	row.add_child(spacer2)
	for q in [["orders", "TAB ORDERS"], ["contacts", "K CONTACTS"], ["log", "L LOG"], ["intel", "I INTEL"], ["menu", "ESC MENU"]]:
		var b := _small_button(String(q[1]))
		var id := String(q[0])
		b.pressed.connect(func() -> void: request.emit(id))
		row.add_child(b)
		_quick[id] = b


func _small_button(text: String) -> Button:
	var b := UiStyle.button(text, 12)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := b.get_theme_stylebox(st) as StyleBoxFlat
		if s:
			s.content_margin_left = 8
			s.content_margin_right = 8
			s.content_margin_top = 3
			s.content_margin_bottom = 3
	return b


func _small_toggle(text: String) -> Button:
	var b := UiStyle.toggle(text, false, 12)
	b.toggle_mode = false
	return b


func _process(_delta: float) -> void:
	if main == null or not visible:
		return
	var view := int(main.view)
	for i in _tabs.size():
		var on := int(VIEWS[i][2]) == view
		var b := _tabs[i]
		b.add_theme_color_override("font_color", UiStyle.CYAN if on else UiStyle.WHITE)
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		if sb:
			sb.bg_color = Color(0.12, 0.3, 0.38, 0.9) if on else Color(0.04, 0.07, 0.09, 0.6)
			sb.border_color = UiStyle.CYAN if on else Color(0.3, 0.55, 0.65, 0.45)
	var sub: Submarine = main.sub
	var hdg := fposmod(rad_to_deg(sub.heading), 360.0)
	var ordered := fposmod(rad_to_deg(sub.ordered_heading), 360.0)
	var depth_now := sub.depth if sub.depth >= 3.0 else 0.0
	var keel: float = main.under_keel() if main.has_method("under_keel") else -1.0
	var keel_txt := "  KEEL %3dM" % int(keel) if keel >= 0.0 and not sub.is_surfaced() else ""
	var r := int(round(absf(sub.rudder_angle)))
	var turn := rad_to_deg(sub.yaw_rate)
	var helm := ""
	if r >= 1:
		helm += " RUD %d%s" % [r, "R" if sub.rudder_angle > 0.0 else "L"]
	if absf(turn) >= 0.05:
		helm += " %s" % ("↻" if turn > 0.0 else "↺")
	_values.text = "HDG %03d›%03d%s   %4.1f KT   DEPTH %5.1f M%s   BATT %d%%   HULL %d%%" % [int(hdg) % 360, int(round(ordered)) % 360, helm, sub.knots(), depth_now, keel_txt, int(sub.battery), int(sub.hull)]
	_values.add_theme_color_override("font_color", UiStyle.AMBER if sub.depth > Submarine.SAFE_DEPTH or sub.hull < 60.0 else UiStyle.WHITE)
	var clock: GameClock = main.clock
	_time.text = "%s  ×%s" % [clock.time_string(), main.time_label() if main.has_method("time_label") else str(int(clock.scale()))]
	_hint.text = main.hint_text() if main.has_method("hint_text") else ""
	_flags.text = main.status_flags() if main.has_method("status_flags") else ""
	(_quick["intel"] as Button).visible = main.has_method("open_intel")
	var flagged: int = main.captain_log.count_flagged() if main.get("captain_log") else 0
	(_quick["log"] as Button).text = "L LOG" + (" (%d)" % flagged if flagged > 0 else "")
