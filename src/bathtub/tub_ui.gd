class_name TubUi
extends RefCounted
## The Bathtub Edition's interface style: cream "bath toy" panels with a
## soft ink outline, candy-coloured buttons and the rounded Fredoka type.

const INK := Color(0.18, 0.19, 0.26)
const CREAM := Color(1.0, 0.98, 0.93)
const PINK := Color(1.0, 0.45, 0.66)
const TEAL := Color(0.15, 0.65, 0.6)
const SKY := Color(0.42, 0.78, 0.95)
const SUN := Color(1.0, 0.8, 0.25)
const MINT := Color(0.45, 0.85, 0.55)
const RED := Color(0.95, 0.38, 0.32)
const DIM := Color(0.45, 0.47, 0.55)


static func panel(radius: int = 26, alpha: float = 0.97) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CREAM.r, CREAM.g, CREAM.b, alpha)
	sb.set_corner_radius_all(radius)
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0.1, 0.2, 0.25, 0.3)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(20)
	sb.anti_aliasing = true
	return sb


static func label(text: String, size: int = 20, color: Color = INK, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TubArt.font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size: int = 40, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", INK)
	return l


static func button(text: String, color: Color = SKY, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", TubArt.font(true))
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var c := color
		match st:
			"hover":
				c = color.lightened(0.18)
			"pressed":
				c = color.darkened(0.15)
			"disabled":
				c = Color(0.82, 0.82, 0.85)
		sb.bg_color = c
		sb.set_corner_radius_all(18)
		sb.border_color = INK
		sb.set_border_width_all(3)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.anti_aliasing = true
		if st == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(1, 1, 1, 0.9)
		else:
			sb.shadow_color = Color(0, 0, 0, 0.25)
			sb.shadow_size = 0 if st == "pressed" else 4
			sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	return b


## A rounded progress bar drawn on a Control's canvas.
static func bar(ci: CanvasItem, rect: Rect2, frac: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.18)
	sb.set_corner_radius_all(int(rect.size.y * 0.5))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)
	if frac > 0.0:
		var fb := StyleBoxFlat.new()
		fb.bg_color = col
		fb.set_corner_radius_all(int(rect.size.y * 0.5))
		fb.anti_aliasing = true
		ci.draw_style_box(fb, Rect2(rect.position, Vector2(maxf(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y), rect.size.y)))


static func health_color(f: float) -> Color:
	return MINT if f > 0.6 else (SUN if f > 0.3 else RED)


## A captain's portrait in a round frame.
static func portrait(ci: CanvasItem, id: String, center: Vector2, radius: float, ring: Color = Color.WHITE) -> void:
	ci.draw_circle(center + Vector2(0, 4), radius + 6.0, Color(0, 0, 0, 0.2))
	ci.draw_circle(center, radius + 5.0, INK)
	ci.draw_circle(center, radius + 2.0, ring)
	ci.draw_circle(center, radius, Color(0.86, 0.95, 0.97))
	var t := TubArt.texture("portrait_" + id)
	if t:
		var s := radius * 2.1 / t.get_size().x
		ci.draw_set_transform(center, 0.0, Vector2(s, s))
		ci.draw_texture(t, -t.get_size() * 0.5)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
