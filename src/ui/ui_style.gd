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
