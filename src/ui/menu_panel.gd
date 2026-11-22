class_name MenuPanel
extends PanelContainer
## A simple command panel: title, optional text and a numbered list of choices
## (click, or press the number). Used for orders, rest, the log and debrief.

signal chosen(id: String)
signal closed

var kind := ""
var _title: Label
var _body: RichTextLabel
var _list: VBoxContainer
var _ids: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.028, 0.038, 0.93)
	sb.border_color = UiStyle.LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(20)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = UiStyle.label("", 18, UiStyle.CYAN)
	v.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_following = false
	_body.add_theme_font_override("normal_font", UiStyle.display())
	_body.add_theme_font_override("bold_font", UiStyle.display())
	_body.add_theme_font_override("mono_font", UiStyle.mono())
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_font_size_override("bold_font_size", 15)
	_body.add_theme_font_size_override("mono_font_size", 14)
	_body.add_theme_color_override("default_color", UiStyle.WHITE)
	v.add_child(_body)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	v.add_child(_list)
	visible = false


## items: Array of [id, text, enabled := true] or a String section header.
func open(p_kind: String, title: String, body: String, items: Array, width: float = 620.0) -> void:
	kind = p_kind
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	var lines := body.count("\n") + 1 + body.length() / 80
	_body.fit_content = lines <= 20
	_body.custom_minimum_size = Vector2(width, 0.0 if lines <= 20 else 440.0)
	_body.scroll_to_line(0)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_ids.clear()
	for it in items:
		if it is String:
			var h := UiStyle.label(String(it), 12, UiStyle.DIM)
			_list.add_child(h)
			continue
		var arr: Array = it
		var id := String(arr[0])
		var enabled := bool(arr[2]) if arr.size() > 2 else true
		_ids.append(id)
		var n := _ids.size()
		var key := str(n) if n <= 9 else ("0" if n == 10 else "")
		var b := Button.new()
		b.text = ("%s   %s" % [key, arr[1]]) if key != "" else "     " + String(arr[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not enabled
		b.add_theme_font_override("font", UiStyle.display())
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", UiStyle.WHITE)
		b.add_theme_color_override("font_hover_color", UiStyle.CYAN)
		b.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.6, 0.45))
		for st in ["normal", "hover", "pressed", "disabled"]:
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0.1, 0.2, 0.26, 0.6) if st == "hover" else Color(0.04, 0.07, 0.09, 0.6)
			bs.border_color = Color(0.3, 0.55, 0.65, 0.45 if st != "disabled" else 0.12)
			bs.set_border_width_all(1)
			bs.content_margin_left = 12
			bs.content_margin_top = 5
			bs.content_margin_bottom = 5
			b.add_theme_stylebox_override(st, bs)
		b.pressed.connect(func() -> void: chosen.emit(id))
		_list.add_child(b)
	custom_minimum_size = Vector2(width + 40.0, 0)
	size = Vector2.ZERO
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func handle_key(k: int) -> bool:
	if not visible:
		return false
	if k == KEY_ESCAPE:
		close()
		return true
	var n := -1
	if k >= KEY_1 and k <= KEY_9:
		n = k - KEY_1
	elif k == KEY_0:
		n = 9
	if n >= 0 and n < _ids.size():
		var b := _list.get_children().filter(func(c: Node) -> bool: return c is Button)[n] as Button
		if not b.disabled:
			chosen.emit(_ids[n])
		return true
	return false
