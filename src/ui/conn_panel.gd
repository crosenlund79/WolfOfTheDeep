class_name ConnPanel
extends PanelContainer
## Clickable conn orders (mirroring the keyboard) and a compact status readout
## for depth, periscope, tubes and any running torpedo.

signal command(cmd: String)

var main: Node
var _status: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.03, 0.045, 0.72)
	sb.border_color = UiStyle.LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	var title := UiStyle.label("CONN", 13, UiStyle.CYAN)
	v.add_child(title)
	_status = UiStyle.label("", 12, UiStyle.WHITE, UiStyle.mono())
	v.add_child(_status)
	v.add_child(HSeparator.new())
	for def in [
		["surface", "O   SURFACE"],
		["periscope_depth", "P   PERISCOPE DEPTH"],
		["dive", "Z   DIVE  (deeper)"],
		["scope", "M   RAISE PERISCOPE"],
		["view_scope", "2   PERISCOPE VIEW"],
		["fire", "SPACE   REQUEST FIRE"],
		["torpedo_cam", "9   FOLLOW TORPEDO"],
		["orders", "TAB   ORDERS"],
	]:
		var b := Button.new()
		b.text = String(def[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiStyle.display())
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", UiStyle.WHITE)
		b.add_theme_color_override("font_hover_color", UiStyle.CYAN)
		b.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.6, 0.5))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0.1, 0.2, 0.26, 0.55) if state == "hover" else (Color(0.2, 0.4, 0.5, 0.6) if state == "pressed" else Color(0.04, 0.07, 0.09, 0.6))
			bs.border_color = Color(0.3, 0.55, 0.65, 0.5 if state != "disabled" else 0.15)
			bs.set_border_width_all(1)
			bs.content_margin_left = 10
			bs.content_margin_right = 10
			bs.content_margin_top = 4
			bs.content_margin_bottom = 4
			b.add_theme_stylebox_override(state, bs)
		b.pressed.connect(func() -> void: command.emit(String(def[0])))
		v.add_child(b)
		_buttons[def[0]] = b
	custom_minimum_size = Vector2(250, 0)


func _process(_delta: float) -> void:
	if main == null:
		return
	var sub: Submarine = main.sub
	var enc: Encounter = main.encounter
	var scope_txt: String = ["HOUSED", "MOVING", "UNDER WATER", "CLEAR"][sub.periscope_state()]
	var lines := [
		"DEPTH   %5.1f M  %s" % [sub.depth, _arrow(sub)],
		"ORDER   %s" % sub.depth_label(),
		"HELM    %03d › %03d" % [int(round(fposmod(rad_to_deg(sub.heading), 360.0))) % 360, int(round(fposmod(rad_to_deg(sub.ordered_heading), 360.0))) % 360],
		"        %s" % sub.helm_text().to_lower(),
		"SCOPE   %s" % (("RAISED · " if sub.masts_up else "LOWERED · ") + scope_txt),
		"TUBES   %s" % ("READY" if enc.can_fire() else "RELOAD %d S" % ceili(enc.reload)),
	]
	var t := enc.torpedo_running()
	if t:
		lines.append("TORP    RUNNING %d S · %.1f KM" % [int(t.travelled / Torpedo.RUN_SPEED), t.travelled / 1000.0])
	if main.clock.level > 0:
		lines.append("TIME    x %d" % int(main.clock.scale()))
	_status.text = "\n".join(lines)
	(_buttons["scope"] as Button).text = "M   %s PERISCOPE" % ("LOWER" if sub.masts_up else "RAISE")
	var in_scope: bool = main.view == 1
	(_buttons["view_scope"] as Button).text = "3   EXTERIOR VIEW" if in_scope else "2   PERISCOPE VIEW"
	(_buttons["fire"] as Button).disabled = not in_scope or not enc.can_fire()
	(_buttons["torpedo_cam"] as Button).disabled = t == null
	(_buttons["surface"] as Button).disabled = sub.depth_mode == 0
	(_buttons["periscope_depth"] as Button).disabled = sub.depth_mode == 1


func _arrow(sub: Submarine) -> String:
	var target := float(Submarine.DEPTH_MODES[sub.depth_mode]["depth"])
	if sub.depth < target - 0.4:
		return "▼"
	if sub.depth > target + 0.4:
		return "▲"
	return ""
