class_name GameMenu
extends Control
## Main menu and in-game menu: continue, new campaign, load / save slots,
## settings and the (off by default) developer tools. Emits `action`; the
## game decides what each action means.

signal action(id: String, arg: Variant)

var mode := "main"          # main / pause
var has_campaign := false   # pause menu only: a campaign is running
var _root: VBoxContainer
var _panel: PanelContainer
var _screen := "root"
var _title: Label
var _subtitle: Label
var _shade: ColorRect
var _confirm_cb: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_title = UiStyle.label("W O L F   O F   T H E   D E E P", 54, Color(0.93, 0.96, 0.98), UiStyle.title())
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	UiStyle.place(_title, Vector2(0, 0), Vector2(110, 150), Vector2(1200, 70))
	add_child(_title)
	_subtitle = UiStyle.label("THE BATTLE FOR THE ARCTIC", 16, Color(0.7, 0.82, 0.9))
	UiStyle.place(_subtitle, Vector2(0, 0), Vector2(114, 222), Vector2(800, 24))
	add_child(_subtitle)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.86, 22))
	add_child(_panel)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_panel.add_child(_root)
	show_screen("root")


func open(p_mode: String) -> void:
	mode = p_mode
	visible = true
	show_screen("root")


func _clear() -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()


func _layout(width: float) -> void:
	var main_mode := mode == "main"
	_title.visible = main_mode
	_subtitle.visible = main_mode
	_shade.color = Color(0, 0, 0, 0.0) if main_mode else Color(0, 0, 0, 0.62)
	if main_mode:
		UiStyle.place(_panel, Vector2(0, 0), Vector2(110, 290), Vector2(width, 0))
	else:
		UiStyle.place(_panel, Vector2(0.5, 0.5), Vector2(-width * 0.5 - 22, -300), Vector2(width, 0))
	_panel.size = Vector2.ZERO


func _btn(text: String, cb: Callable, enabled: bool = true, w: float = 0.0) -> Button:
	var b := UiStyle.button(text, 17, w)
	b.disabled = not enabled
	b.pressed.connect(cb)
	_root.add_child(b)
	return b


func _heading(text: String) -> void:
	_root.add_child(UiStyle.label(text, 20, UiStyle.CYAN))


func _note(text: String, color: Color = UiStyle.DIM, size: int = 13) -> Label:
	var l := UiStyle.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	_root.add_child(l)
	return l


func handle_back() -> bool:
	if _screen != "root":
		show_screen("root")
		return true
	return false


func show_screen(s: String) -> void:
	_screen = s
	_clear()
	match s:
		"root":
			_screen_root()
		"load":
			_screen_load()
		"save":
			_screen_save()
		"settings":
			_screen_settings()
		"developer":
			_screen_developer()


func _screen_root() -> void:
	_layout(420.0)
	if mode == "main":
		var last := SaveSystem.latest()
		var cont := _btn("Continue", func() -> void: action.emit("load", last["path"]), not last.is_empty())
		if not last.is_empty():
			cont.tooltip_text = _describe(last["meta"])
		_btn("New Campaign", func() -> void: _confirm("Start a new campaign? Your existing saves are kept.", func() -> void: action.emit("new", null)))
		_btn("Load Game", func() -> void: show_screen("load"), not SaveSystem.list().is_empty())
		_btn("Settings", func() -> void: show_screen("settings"))
		_btn("Developer / Cheats", func() -> void: show_screen("developer"))
		_btn("Quit", func() -> void: action.emit("quit", null))
		if not last.is_empty():
			_note("Last save:  " + _describe(last["meta"]))
	else:
		_heading("PAUSED")
		_btn("Resume", func() -> void: action.emit("resume", null))
		_btn("Save Game", func() -> void: show_screen("save"), has_campaign)
		_btn("Load Game", func() -> void: show_screen("load"), not SaveSystem.list().is_empty())
		_btn("Settings", func() -> void: show_screen("settings"))
		if bool(Settings.get_v("developer")):
			_btn("Developer Panel  (F10)", func() -> void: action.emit("dev_panel", null))
		_btn("Main Menu", func() -> void: _confirm("Return to the main menu? Unsaved progress since the last save is lost.", func() -> void: action.emit("main_menu", null)))
		_btn("Quit to Desktop", func() -> void: _confirm("Quit the game? Unsaved progress since the last save is lost.", func() -> void: action.emit("quit", null)))
		_note("Esc  resume")


static func _describe(meta: Dictionary) -> String:
	if meta.is_empty():
		return ""
	return "%s  ·  %s  ·  %s" % [String(meta.get("label", "")), String(meta.get("game_time", "")), String(meta.get("saved", ""))]


func _screen_load() -> void:
	_layout(760.0)
	_heading("LOAD GAME")
	var saves := SaveSystem.list()
	if saves.is_empty():
		_note("No saves yet.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, mini(saves.size(), 8) * 62 + 8)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_root.add_child(scroll)
	for s in saves:
		var meta: Dictionary = s["meta"]
		var row := HBoxContainer.new()
		var b := UiStyle.button("%s\n%s" % [_slot_name(String(s["slot"])), _describe(meta)], 14, 560)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: action.emit("load", s["path"]))
		row.add_child(b)
		var del := UiStyle.button("Delete", 13)
		del.pressed.connect(func() -> void:
			_confirm("Delete %s?" % _slot_name(String(s["slot"])), func() -> void:
				SaveSystem.delete(String(s["slot"]))
				show_screen("load")))
		row.add_child(del)
		list.add_child(row)
	_btn("Back", func() -> void: show_screen("root"))


static func _slot_name(slot: String) -> String:
	if slot.begins_with("auto_"):
		return "Autosave " + slot.substr(5)
	if slot == "quick":
		return "Quick save"
	if slot.begins_with("slot_"):
		return "Save slot " + slot.substr(5)
	return slot


func _screen_save() -> void:
	_layout(760.0)
	_heading("SAVE GAME")
	var by_slot := {}
	for s in SaveSystem.list():
		by_slot[String(s["slot"])] = s["meta"]
	for i in range(1, SaveSystem.MANUAL_SLOTS + 1):
		var slot := "slot_%d" % i
		var used: bool = by_slot.has(slot)
		var text := "Slot %d    %s" % [i, _describe(by_slot[slot]) if used else "(empty)"]
		_btn(text, func() -> void:
			if used:
				_confirm("Overwrite slot %d?" % i, func() -> void: action.emit("save", slot))
			else:
				action.emit("save", slot), true, 700.0)
	_btn("Back", func() -> void: show_screen("root"))


func _slider(label_text: String, key: String, lo: float, hi: float, step: float, fmt: String) -> void:
	var row := HBoxContainer.new()
	var l := UiStyle.label(label_text, 15, UiStyle.WHITE)
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(260, 24)
	s.focus_mode = Control.FOCUS_NONE
	var val := UiStyle.label(fmt % s.value, 14, UiStyle.DIM, UiStyle.mono())
	val.custom_minimum_size = Vector2(80, 0)
	s.value_changed.connect(func(v: float) -> void:
		val.text = fmt % v
		Settings.set_v(key, v)
		action.emit("settings_changed", key))
	row.add_child(s)
	row.add_child(val)
	_root.add_child(row)


func _choice(label_text: String, key: String, options: Array, names: Array) -> void:
	var row := HBoxContainer.new()
	var l := UiStyle.label(label_text, 15, UiStyle.WHITE)
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var cur := options.find(Settings.get_v(key))
	for i in options.size():
		var b := UiStyle.toggle(String(names[i]), i == cur, 13)
		b.pressed.connect(func() -> void:
			Settings.set_v(key, options[i])
			action.emit("settings_changed", key)
			show_screen("settings"))
		row.add_child(b)
	_root.add_child(row)


func _screen_settings() -> void:
	_layout(820.0)
	_heading("SETTINGS")
	_root.add_child(UiStyle.label("AUDIO  (dB)", 12, UiStyle.DIM))
	_slider("Master", "vol_master", -30.0, 6.0, 1.0, "%+.0f")
	_slider("Voices and reports", "vol_voices", -30.0, 6.0, 1.0, "%+.0f")
	_slider("Effects", "vol_effects", -30.0, 6.0, 1.0, "%+.0f")
	_slider("Ambience", "vol_ambience", -30.0, 6.0, 1.0, "%+.0f")
	_slider("Music", "vol_music", -30.0, 6.0, 1.0, "%+.0f")
	_root.add_child(UiStyle.label("DISPLAY", 12, UiStyle.DIM))
	_choice("Contact colours", "contact_scheme", Settings.SCHEMES, Settings.SCHEMES.map(func(k: String) -> String: return String(Settings.SCHEME_NAMES[k])))
	_choice("Graphics", "graphics", ["high", "performance"], ["High quality", "Performance"])
	_choice("Window", "fullscreen", [true, false], ["Fullscreen", "Windowed"])
	_choice("Subtitles", "subtitles", [true, false], ["On", "Off"])
	_slider("Interface scale", "ui_scale", 0.8, 1.4, 0.05, "%.2f")
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.3, 2.5, 0.05, "%.2f")
	_root.add_child(UiStyle.label("CAMPAIGN", 12, UiStyle.DIM))
	_choice("Autosave", "autosave_minutes", [0, 15, 30, 60, 120], ["Off", "15 min", "30 min", "1 h", "2 h"])
	_note("Autosave intervals are in game time. The game also autosaves after resting and before leaving.")
	_btn("Back", func() -> void: show_screen("root"))


func _screen_developer() -> void:
	_layout(620.0)
	_heading("DEVELOPER / CHEATS")
	_note("Testing tools: set depth, speed and position, repair, restore the crew, time compression, test contacts, weather and sea, hazards, invulnerability and unlimited weapons, and quick access to every station. Off by default and separate from normal play. They never reveal campaign secrets.", UiStyle.WHITE, 14)
	var on := bool(Settings.get_v("developer"))
	_btn("Developer tools:  %s" % ("ENABLED  (F10 in game)" if on else "DISABLED"), func() -> void:
		Settings.set_v("developer", not on)
		action.emit("settings_changed", "developer")
		show_screen("developer"))
	_btn("Back", func() -> void: show_screen("root"))


func _confirm(text: String, cb: Callable) -> void:
	_screen = "confirm"
	_clear()
	_layout(560.0)
	_note(text, UiStyle.WHITE, 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var yes := UiStyle.button("Yes", 16, 120)
	yes.pressed.connect(func() -> void:
		show_screen("root")
		cb.call())
	var no := UiStyle.button("No", 16, 120)
	no.pressed.connect(func() -> void: show_screen("root"))
	row.add_child(yes)
	row.add_child(no)
	_root.add_child(row)
