class_name BriefingPanel
extends Control
## The mission briefing: where the boat stands, shown when a campaign begins
## or is loaded and reopened with F1 (or the command bar). It only shows what
## main hands it, which is built from what the captain already knows.
## Dismissed with Esc, Enter, Space or the button.

signal closed

var _box: PanelContainer
var _title: Label
var _sub: Label
var _body: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiStyle.panel_style(0.95, 22))
	UiStyle.place(_box, Vector2(0.5, 0.5), Vector2(-430, -400), Vector2(860, 0))
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_box.add_child(v)
	_title = UiStyle.label("MISSION BRIEFING", 24, UiStyle.CYAN, UiStyle.title())
	v.add_child(_title)
	_sub = UiStyle.label("", 13, UiStyle.DIM)
	v.add_child(_sub)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(816, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(800, 0)
	_body.add_theme_font_override("normal_font", UiStyle.display())
	_body.add_theme_font_override("bold_font", UiStyle.title())
	_body.add_theme_font_override("mono_font", UiStyle.mono())
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_font_size_override("bold_font_size", 14)
	_body.add_theme_font_size_override("mono_font_size", 14)
	_body.add_theme_color_override("default_color", UiStyle.WHITE)
	scroll.add_child(_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ok := UiStyle.button("Carry on  (Esc / Enter)", 14)
	ok.pressed.connect(dismiss)
	row.add_child(ok)
	row.add_child(UiStyle.label("F1, or Mission briefing in the orders (Tab), shows this again.", 12, UiStyle.DIM))
	v.add_child(row)
	visible = false


## b: {"title", "subtitle", "sections": [[heading, [line, ...]], ...]}
func show_briefing(b: Dictionary) -> void:
	_title.text = String(b.get("title", "MISSION BRIEFING"))
	_sub.text = String(b.get("subtitle", ""))
	var t := ""
	for s in b.get("sections", []):
		t += "[b][color=#6bdcff]%s[/color][/b]\n" % String(s[0])
		for line in s[1]:
			t += "  %s\n" % String(line)
		t += "\n"
	_body.text = t
	visible = true


func text() -> String:
	return _body.get_parsed_text()


func dismiss() -> void:
	if visible:
		visible = false
		closed.emit()


func _gui_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F1]:
		dismiss()
		get_viewport().set_input_as_handled()
