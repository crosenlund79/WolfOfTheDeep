class_name Hud
extends Control
## Title sequence, cinematic letterbox, toasts, subtitles, controls help, the
## status strip, location bar and the rest overlay.

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
var _pause: Control
var pause_menu: GameMenu
var _title_t := -1.0
var _bars := 0.0
var _hint_t := 14.0
var _event: Label
var _event_t := 0.0
var _subs: Array[Dictionary] = []
var _sub_box: VBoxContainer
var _hover: Label
var _sleep: ColorRect
var _sleep_text: Label
var _sleep_clock: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.place(_weather_label, Vector2(1, 0), Vector2(-540, 28), Vector2(506, 20))
	add_child(_weather_label)

	_status = UiStyle.label("", 14, UiStyle.WHITE, UiStyle.mono())
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.place(_status, Vector2(1, 1), Vector2(-1060, -50), Vector2(1026, 20))
	add_child(_status)

	_keys = UiStyle.label("", 12, UiStyle.DIM)
	UiStyle.place(_keys, Vector2(0, 1), Vector2(34, -26), Vector2(1500, 20))
	add_child(_keys)

	_toast = UiStyle.label("", 18, UiStyle.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_toast, Vector2(0.5, 1), Vector2(-600, -150), Vector2(1200, 30))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_toast.modulate.a = 0.0
	add_child(_toast)

	_event = UiStyle.label("", 24, Color(1.0, 0.86, 0.6), UiStyle.display())
	_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_event, Vector2(0.5, 0), Vector2(-800, 150), Vector2(1600, 40))
	_event.add_theme_constant_override("outline_size", 8)
	_event.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_event.modulate.a = 0.0
	add_child(_event)

	_sub_box = VBoxContainer.new()
	_sub_box.alignment = BoxContainer.ALIGNMENT_END
	_sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.place(_sub_box, Vector2(0.5, 1), Vector2(-620, -330), Vector2(1240, 170))
	add_child(_sub_box)

	_hover = UiStyle.label("", 15, Color(1.0, 0.9, 0.7))
	_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_hover, Vector2(0.5, 0.5), Vector2(-300, 30), Vector2(600, 24))
	_hover.add_theme_constant_override("outline_size", 6)
	_hover.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(_hover)

	_sleep = ColorRect.new()
	_sleep.color = Color(0.0, 0.0, 0.0, 1.0)
	_sleep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sleep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep.visible = false
	add_child(_sleep)
	_sleep_clock = UiStyle.label("", 40, Color(0.85, 0.5, 0.3), UiStyle.title())
	_sleep_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_sleep_clock, Vector2(0.5, 0.5), Vector2(-400, -120), Vector2(800, 60))
	_sleep.add_child(_sleep_clock)
	_sleep_text = UiStyle.label("", 15, UiStyle.DIM, UiStyle.mono())
	_sleep_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_sleep_text, Vector2(0.5, 0.5), Vector2(-500, -40), Vector2(1000, 300))
	_sleep.add_child(_sleep_text)

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
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_root)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(_fade)
	_title = UiStyle.label("W O L F   O F   T H E   D E E P", 72, Color(0.93, 0.96, 0.98), UiStyle.title())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_title, Vector2(0.5, 0.5), Vector2(-900, -90), Vector2(1800, 100))
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	_title_root.add_child(_title)
	_subtitle = UiStyle.label("THE BATTLE FOR THE ARCTIC   ·   PATROL ONE", 16, Color(0.7, 0.82, 0.9))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_subtitle, Vector2(0.5, 0.5), Vector2(-600, 22), Vector2(1200, 30))
	_title_root.add_child(_subtitle)
	_prompt = UiStyle.label("PRESS ANY KEY TO TAKE THE CONN", 13, Color(0.8, 0.88, 0.95))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.place(_prompt, Vector2(0.5, 1), Vector2(-400, -120), Vector2(800, 24))
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
	UiStyle.place(_help, Vector2(0, 0.5), Vector2(34, -300), Vector2(0, 0))
	var txt := """CONTROLS  ·  PATROL ONE

VIEWS      1 control room  2 periscope  3 exterior  4 sonar  5 chart
           6 mess  7 cabin  8 engine room  9 torpedo cam  0 cinematic
CONTROL    Q / E viewpoint (command, sonar, navigation, overview)
ROOM       click a station  ·  right-click back  ·  R red lighting
HELM       A / D  course -10 / +10 (Shift: 1)   W / S  telegraph
DEPTH      O  surface  P  periscope depth  Z  deeper  X  shallower
           M  raise / lower masts   B  emergency blow (40 m or deeper)
CHART      click: select  ·  Enter / double-click: steer for it  ·  Shift+click: waypoint
           F find  ·  G legend  ·  right-drag pan  ·  wheel zoom  ·  C centre
ORDERS     Tab  orders to the crew (silent running, snorkel, fix, radio, battle
           stations, the conn, rest, cards, damage assessment, drone)  ·  F1  briefing
TIME       + / -  compression x1 to x250 (x4 in action; drops to x1 on events)
           J  advance until something needs you (J or Esc stops)  ·  N  next waypoint
CREW       click a person to talk  ·  click things in the rooms
           rest in your cabin (click the bunk)  ·  L  log, orders, messages
PERISCOPE  drag or Q / E train  ·  wheel zoom  ·  T sensor  ·  Enter mark
           SPACE  fire (asks for confirmation)
DISPLAY    U hide interface  F9 performance mode  F11 fullscreen
           Esc  pause / quit   ·   H  this help"""
	var l := UiStyle.label(txt, 14, UiStyle.WHITE, UiStyle.mono())
	_help.add_child(l)
	_help.visible = false
	add_child(_help)


func _build_pause() -> void:
	# The in-game menu (resume, save, load, settings, main menu, quit).
	pause_menu = GameMenu.new()
	pause_menu.mode = "pause"
	_pause = pause_menu
	_pause.visible = false
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	# Its own layer, so it always sits above the log, contacts and panels.
	var top := CanvasLayer.new()
	top.layer = 20
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	top.add_child(_pause)
	# The HUD pauses with the game, so a small listener that keeps running
	# while paused handles Esc (resume) and Q (quit) on the pause screen.
	var keys := PauseKeys.new()
	keys.hud = self
	keys.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.add_child(keys)


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


## A spoken line as a subtitle (speaker in their colour).
func show_line(speaker: String, color: Color, text: String, channel: String) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1240, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("normal_font", UiStyle.display())
	l.add_theme_font_size_override("normal_font_size", 19)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	var tag := ("[color=#%s](%s)[/color] " % [UiStyle.DIM.to_html(false), channel.to_lower()]) if channel != "" else ""
	l.text = "[center]%s[color=#%s]%s:[/color]  %s[/center]" % [tag, color.to_html(false), speaker, text.replace("[", "(").replace("]", ")")]
	_sub_box.add_child(l)
	_subs.append({"node": l, "t": 3.5 + text.length() * 0.06})
	while _subs.size() > 3:
		var old: Dictionary = _subs.pop_front()
		(old["node"] as Node).queue_free()


func set_hover(t: String) -> void:
	_hover.text = t


func set_sleep(on: bool, text: String = "") -> void:
	_sleep.visible = on
	_sleep_text.text = text


func toggle_help() -> void:
	_help.visible = not _help.visible


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pause.visible:
		pause_menu.has_campaign = main != null and bool(main.started) and main.get("scenario") == null
		pause_menu.scenario_mode = main != null and main.get("scenario") != null
		pause_menu.open("pause")
	get_tree().paused = _pause.visible


func is_paused() -> bool:
	return _pause.visible


## Keys on the pause screen. Runs while the tree is paused.
class PauseKeys extends Node:
	var hud: Hud

	func _unhandled_input(event: InputEvent) -> void:
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo or not hud.is_paused():
			return
		if k.keycode == KEY_ESCAPE:
			if not hud.pause_menu.handle_back():
				hud.toggle_pause()
			get_viewport().set_input_as_handled()


func _hint_line(v: int) -> String:
	match v:
		1:
			return "DRAG or Q/E  TRAIN   ·   WHEEL  ZOOM   ·   T  SENSOR   ·   M  MASTS   ·   P  PERISCOPE DEPTH   ·   TAB  ORDERS   ·   H  HELP"
		4:
			return "CLICK  STEER FOR   ·   SHIFT+CLICK  WAYPOINT   ·   RIGHT-DRAG  PAN   ·   WHEEL  ZOOM   ·   C  CENTRE   ·   TAB  ORDERS   ·   H  HELP"
		0:
			return "Q / E  VIEWPOINT   ·   CLICK A STATION   ·   RIGHT-CLICK  BACK   ·   R  RED LIGHTING   ·   2  PERISCOPE   ·   3  EXTERIOR   ·   TAB  ORDERS   ·   H  HELP"
		5, 6, 7:
			return "CLICK PEOPLE TO TALK   ·   CLICK THINGS TO USE THEM   ·   1  CONTROL ROOM   ·   TAB  ORDERS   ·   L  LOG   ·   H  HELP"
		_:
			return "A / D  COURSE   ·   W / S  SPEED   ·   P / O / Z / X  DEPTH   ·   M  MASTS   ·   + / -  TIME   ·   TAB  ORDERS   ·   L  LOG   ·   H  HELP"


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
	var menu_up: bool = main != null and bool(main.in_main_menu)
	var cinematic: bool = main != null and main.view == 9 and not menu_up
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
	var own_ui: bool = main != null and (main.view == 1 or main.view == 3 or main.view == 4)
	_status.visible = false
	_keys.visible = false
	for c in [_view_label, _weather_label]:
		(c as Control).visible = not title_busy and not menu_up
	_view_label.visible = not title_busy and not own_ui and not menu_up
	_ident.visible = _view_label.visible
	if main != null and main.view == 3:
		_keys.visible = false
		_weather_label.visible = false
	var cards: bool = main != null and main.poker != null and main.poker.visible
	if cards:
		for c2 in [_view_label, _ident, _status, _keys, _weather_label, _toast]:
			(c2 as Control).visible = false
	else:
		_toast.visible = true
	for i in range(_subs.size() - 1, -1, -1):
		var e: Dictionary = _subs[i]
		e["t"] = float(e["t"]) - delta
		var n: Control = e["node"]
		n.modulate.a = clampf(float(e["t"]) * 1.5, 0.0, 1.0)
		if float(e["t"]) <= 0.0:
			n.queue_free()
			_subs.remove_at(i)

	if main:
		var sub: Submarine = main.sub
		var hdg := fposmod(rad_to_deg(sub.heading), 360.0)
		var ordered := fposmod(rad_to_deg(sub.ordered_heading), 360.0)
		var depth_now := maxf(sub.depth - 2.05, 0.0) + (0.0 if sub.depth < 3.0 else 2.05)
		_status.text = "HDG %03d > %03d   ·   %s %4.1f KT   ·   DEPTH %5.1f M  (%s)   ·   BATT %d%%%s" % [int(hdg) % 360, int(round(ordered)) % 360, sub.speed_label(), sub.knots(), depth_now, sub.depth_label(), int(sub.battery), "  ·  SNORT" if sub.diesels_running and not sub.is_surfaced() else ""]
		var clock: GameClock = main.clock
		var scale_txt := "" if clock.level == 0 else "   ·   TIME x%d" % int(clock.scale())
		_weather_label.text = "%s   ·   %s%s" % [clock.time_string(), main.weather.condition_label(), scale_txt]
		_ident.text = main.location_text()
		if _sleep.visible:
			_sleep_clock.text = clock.time_string()
