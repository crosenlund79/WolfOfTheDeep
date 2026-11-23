class_name UiStyle
extends RefCounted
## Shared fonts and colours for the naval interface (system fonts only, so no
## font files ship with the prototype).

const CYAN := Color(0.42, 0.86, 1.0)
const AMBER := Color(1.0, 0.72, 0.32)
const GREEN := Color(0.45, 0.95, 0.66)
const RED := Color(1.0, 0.36, 0.32)
const DIM := Color(0.55, 0.66, 0.74, 0.75)
const WHITE := Color(0.92, 0.95, 0.97)
const PANEL := Color(0.02, 0.035, 0.05, 0.86)
const LINE := Color(0.25, 0.42, 0.52, 0.7)

static var _display: SystemFont
static var _mono: SystemFont
static var _title: SystemFont


static func display() -> Font:
	if _display == null:
		_display = SystemFont.new()
		_display.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "Liberation Sans Narrow", "sans-serif"])
		_display.font_weight = 400
		_display.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _display


static func title() -> Font:
	if _title == null:
		_title = SystemFont.new()
		_title.font_names = PackedStringArray(["Bahnschrift Light", "Bahnschrift", "Segoe UI Light", "Helvetica Neue", "DejaVu Sans", "sans-serif"])
		_title.font_weight = 300
		_title.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _title


static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		_mono.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _mono


static func label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else display())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Anchor a control to a point of its parent (0..1 on each axis) and place it
## with pixel offsets from that point (works for every screen size).
static func place(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


static func panel_style(alpha: float = 0.93, margin: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.028, 0.038, alpha)
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


## A flat naval-console button.
static func button(text: String, size: int = 15, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, 0)
	b.add_theme_font_override("font", display())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", CYAN)
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.6, 0.45))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.1, 0.2, 0.26, 0.65) if st == "hover" or st == "pressed" else Color(0.04, 0.07, 0.09, 0.6)
		bs.border_color = Color(0.3, 0.55, 0.65, 0.45 if st != "disabled" else 0.12)
		bs.set_border_width_all(1)
		bs.content_margin_left = 12
		bs.content_margin_right = 12
		bs.content_margin_top = 5
		bs.content_margin_bottom = 5
		if st == "focus":
			bs.draw_center = false
		b.add_theme_stylebox_override(st, bs)
	return b


## A toggle button used for filters and tabs (highlighted when on).
static func toggle(text: String, on: bool, size: int = 13) -> Button:
	var b := button(text, size)
	b.toggle_mode = true
	b.button_pressed = on
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var on_sb := StyleBoxFlat.new()
	on_sb.bg_color = Color(0.12, 0.3, 0.38, 0.85)
	on_sb.border_color = CYAN
	on_sb.set_border_width_all(1)
	on_sb.content_margin_left = 10
	on_sb.content_margin_right = 10
	on_sb.content_margin_top = 4
	on_sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("pressed", on_sb)
	b.add_theme_stylebox_override("hover_pressed", on_sb)
	return b
