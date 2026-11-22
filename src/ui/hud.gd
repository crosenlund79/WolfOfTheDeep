class_name Hud
extends Control
## Title sequence, cinematic letterbox, toasts, controls help and a compact
## status strip.

var main: Node

var _title_root: Control
var _title: Label
var _subtitle: Label
var _prompt: Label
var _fade: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _toast: Label
var _toast_t := 0.0
var _view_label: Label
var _ident: Label
var _status: Label
var _weather_label: Label
var _keys: Label
var _help: PanelContainer
var _pause: PanelContainer
var _title_t := -1.0
var _bars := 0.0
var _hint_t := 14.0
var _event: Label
var _event_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bar_top = _bar()
	_bar_bottom = _bar()

	_view_label = UiStyle.label("", 15, UiStyle.CYAN)
	_view_label.position = Vector2(34, 26)
	add_child(_view_label)
	_ident = UiStyle.label("VARG  ·  S-31  ·  AIP ATTACK SUBMARINE", 12, UiStyle.DIM)
	_ident.position = Vector2(34, 48)
	add_child(_ident)

	_weather_label = UiStyle.label("", 13, UiStyle.DIM)
	_weather_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weather_label.position = Vector2(-540, 28)
	_weather_label.size = Vector2(506, 20)
	add_child(_weather_label)

	_status = UiStyle.label("", 14, UiStyle.WHITE, UiStyle.mono())
	_status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.position = Vector2(-760, -50)
	_status.size = Vector2(726, 20)
	add_child(_status)

	_keys = UiStyle.label("", 12, UiStyle.DIM)
	_keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.position = Vector2(34, -48)
	add_child(_keys)

	_toast = UiStyle.label("", 18, UiStyle.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(-500, -150)
	_toast.size = Vector2(1000, 30)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_toast.modulate.a = 0.0
	add_child(_toast)

	_event = UiStyle.label("", 24, Color(1.0, 0.86, 0.6), UiStyle.display())
	_event.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event.position = Vector2(-700, 150)
	_event.size = Vector2(1400, 40)
	_event.add_theme_constant_override("outline_size", 8)
	_event.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_event.modulate.a = 0.0
	add_child(_event)

	_build_title()
	_build_help()
	_build_pause()


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _build_title() -> void:
	_title_root = Control.new()
	_title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_root)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(_fade)
	_title = UiStyle.label("S I L E N T    S E A", 82, Color(0.93, 0.96, 0.98), UiStyle.title())
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(-900, -90)
	_title.size = Vector2(1800, 100)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	_title_root.add_child(_title)
	_subtitle = UiStyle.label("WOLF OF THE DEEP   ·   PROTOTYPE 002   ·   FIRST CONTACT", 16, Color(0.7, 0.82, 0.9))
	_subtitle.set_anchors_preset(Control.PRESET_CENTER)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(-600, 22)
	_subtitle.size = Vector2(1200, 30)
	_title_root.add_child(_subtitle)
	_prompt = UiStyle.label("PRESS ANY KEY TO TAKE THE CONN", 13, Color(0.8, 0.88, 0.95))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-400, -120)
	_prompt.size = Vector2(800, 24)
	_title_root.add_child(_prompt)
	_title_root.modulate.a = 0.0


func _build_help() -> void:
	_help = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiStyle.PANEL
	sb.border_color = UiStyle.LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(22)
	_help.add_theme_stylebox_override("panel", sb)
	_help.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_help.position = Vector2(34, -250)
	var txt := """CONTROLS  ·  PROTOTYPE 002  FIRST CONTACT

THE ATTACK   P  periscope depth  ·  M  raise periscope  ·  3  periscope view
             find the merchant (drag mouse or Q / E to train, wheel to zoom)
             hold the crosshair on her to build a solution  ·  SPACE  fire
             6  follow the torpedo  ·  + / -  time ×1–×8  ·  N  new target
DEPTH        O  surface   P  periscope depth   Z  dive deeper   X  rise
             B  emergency blow (from 40 m or deeper)
BOAT         W / S  telegraph     A / D  rudder
VIEWS        1 cinematic  2 exterior  3 periscope  4 control room
             5 sonar  6 torpedo cam  ·  drag to orbit, wheel to zoom
PERISCOPE    T  sensor (TV / low light / thermal)  ·  Enter  mark bearing
WEATHER      F1 dawn  F2 clear  F3 golden hour  F4 gale  F5 night
DISPLAY      U  hide interface   F9  performance mode   F11  fullscreen
             Esc  pause / quit

Only the torpedo engagement is simulated (simply); the rest is staged."""
	var l := UiStyle.label(txt, 14, UiStyle.WHITE, UiStyle.mono())
	_help.add_child(l)
	_help.visible = false
	add_child(_help)


func _build_pause() -> void:
	_pause = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	sb.set_content_margin_all(40)
	_pause.add_theme_stylebox_override("panel", sb)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause.add_child(v)
	var t := UiStyle.label("PAUSED", 40, UiStyle.WHITE, UiStyle.title())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := UiStyle.label("Esc  resume        Q  quit to desktop", 16, UiStyle.DIM)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	_pause.visible = false
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause)


func play_title() -> void:
	_title_t = 0.0
	_title_root.modulate.a = 1.0


## Engagement events: a larger banner that stays up a little longer.
func event(text: String) -> void:
	_event.text = text
	_event_t = 5.5


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.2


func set_view_name(n: String) -> void:
	if _view_label:
		_view_label.text = n


func toggle_help() -> void:
	_help.visible = not _help.visible


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible


func _unhandled_key_input(event: InputEvent) -> void:
	if _pause.visible and event.pressed and (event as InputEventKey).keycode == KEY_Q:
		get_tree().quit()


func _hint_line(v: int) -> String:
	match v:
		2:
			return "DRAG or Q/E  TRAIN   ·   WHEEL  ZOOM   ·   SPACE  FIRE   ·   M  PERISCOPE   ·   P / O / Z  DEPTH   ·   6  TORPEDO CAM   ·   2  EXTERIOR   ·   H  ALL CONTROLS"
		5:
			return "TORPEDO CAM   ·   + / -  TIME   ·   2  EXTERIOR   ·   3  PERISCOPE   ·   N  NEW TARGET   ·   H  ALL CONTROLS"
		_:
			return "P  PERISCOPE DEPTH   ·   M  RAISE PERISCOPE   ·   3  PERISCOPE VIEW   ·   O  SURFACE   ·   Z  DIVE   ·   F1–F5  WEATHER   ·   H  ALL CONTROLS"


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	# Title sequence.
	if _title_t >= 0.0:
		_title_t += delta
		_fade.color.a = 1.0 - smoothstep(1.0, 5.5, _title_t)
		_title.modulate.a = smoothstep(2.0, 4.5, _title_t) * (1.0 - smoothstep(11.0, 14.0, _title_t))
		_subtitle.modulate.a = smoothstep(3.5, 5.5, _title_t) * (1.0 - smoothstep(11.0, 14.0, _title_t))
		_title.add_theme_constant_override("outline_size", 10)
		_prompt.modulate.a = smoothstep(6.0, 7.0, _title_t) * (0.55 + 0.45 * sin(_title_t * 2.6)) * (1.0 - smoothstep(11.0, 14.0, _title_t))
		if _title_t > 14.0:
			_title_t = -1.0
			_title_root.modulate.a = 0.0
	var cinematic: bool = main != null and main.view == 0
	_bars = move_toward(_bars, 1.0 if cinematic else 0.0, delta * 1.2)
	var bar_h := vp.y * 0.11 * smoothstep(0.0, 1.0, _bars)
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(vp.x, bar_h)
	_bar_bottom.position = Vector2(0, vp.y - bar_h)
	_bar_bottom.size = Vector2(vp.x, bar_h)

	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)

	if _event_t > 0.0:
		_event_t -= delta
		_event.modulate.a = clampf(_event_t * 1.5, 0.0, 1.0)
	_hint_t -= delta
	_keys.modulate.a = 1.0 if _hint_t > 0.0 else 0.6
	if main:
		_keys.text = _hint_line(int(main.view))
	var title_busy := _title_t >= 0.0 and _title_t < 12.0
	var own_ui: bool = main != null and (main.view == 2 or main.view == 4)
	for c in [_view_label, _status, _keys, _weather_label]:
		(c as Control).visible = not title_busy
	_view_label.visible = not title_busy and not own_ui
	_ident.visible = _view_label.visible
	_status.visible = not title_busy and not own_ui

	if main:
		var sub: Submarine = main.sub
		var hdg := fposmod(rad_to_deg(sub.heading), 360.0)
		_status.text = "%s   ·   %4.1f KT   ·   HDG %03d   ·   DEPTH %5.1f M   ·   %s" % [sub.speed_label(), sub.knots(), int(hdg), maxf(sub.depth - 2.05, 0.0) + (0.0 if sub.depth < 3.0 else 2.05), sub.depth_label()]
		_weather_label.text = main.weather.label()
