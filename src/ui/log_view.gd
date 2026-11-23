class_name LogView
extends PanelContainer
## The Captain's Log viewer: filter by category / kind / flag, search, browse
## chronologically, flag entries for follow-up, add notes and personal
## entries, and jump to linked positions. Tabs for orders and signals.

signal show_on_chart(world_pos: Vector3)
signal show_contact(contact_id: String)

var main: Node
var clog: CaptainsLog
var patrol: Patrol
var _tab := "log"
var _cats: Array = []
var _kinds: Array = []
var _flagged := false
var _newest_first := true
var _query := ""
var _selected := -1
var _list: VBoxContainer
var _detail: RichTextLabel
var _note_edit: TextEdit
var _flag_btn: Button
var _chart_btn: Button
var _contact_btn: Button
var _new_note: LineEdit
var _body: HBoxContainer
var _other: RichTextLabel
var _tab_btns: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel_style(0.96, 16))
	UiStyle.place(self, Vector2(0.5, 0.5), Vector2(-700, -440), Vector2(1400, 820))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(UiStyle.label("CAPTAIN'S LOG", 20, UiStyle.CYAN))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(30, 0)
	top.add_child(gap)
	for t in [["log", "LOG"], ["orders", "ORDERS & OBJECTIVES"], ["signals", "SIGNALS"], ["watch", "WATCH REPORT"]]:
		var b := UiStyle.toggle(String(t[1]), _tab == t[0], 13)
		var id := String(t[0])
		b.pressed.connect(func() -> void:
			_tab = id
			refresh())
		top.add_child(b)
		_tab_btns[id] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var close := UiStyle.button("Close  (L)", 13)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	v.add_child(top)

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	# Filters.
	var filt := VBoxContainer.new()
	filt.custom_minimum_size = Vector2(200, 0)
	filt.add_theme_constant_override("separation", 3)
	filt.add_child(UiStyle.label("CATEGORY", 11, UiStyle.DIM))
	for cat in CaptainsLog.CATEGORIES:
		var b := UiStyle.toggle(String(cat), false, 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cc := String(cat)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_cats.append(cc)
			else:
				_cats.erase(cc)
			refresh())
		filt.add_child(b)
	filt.add_child(UiStyle.label("KIND", 11, UiStyle.DIM))
	for k in [["confirmed", "CONFIRMED"], ["assessment", "ASSESSMENT"], ["unresolved", "UNRESOLVED"], ["personal", "PERSONAL"]]:
		var b := UiStyle.toggle(String(k[1]), false, 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var kk := String(k[0])
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_kinds.append(kk)
			else:
				_kinds.erase(kk)
			refresh())
		filt.add_child(b)
	var fl := UiStyle.toggle("⚑ FLAGGED ONLY", false, 12)
	fl.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fl.toggled.connect(func(on: bool) -> void:
		_flagged = on
		refresh())
	filt.add_child(fl)
	var order := UiStyle.toggle("NEWEST FIRST", true, 12)
	order.alignment = HORIZONTAL_ALIGNMENT_LEFT
	order.toggled.connect(func(on: bool) -> void:
		_newest_first = on
		refresh())
	filt.add_child(order)
	var search := LineEdit.new()
	search.placeholder_text = "search…"
	search.add_theme_font_override("font", UiStyle.display())
	search.text_changed.connect(func(t: String) -> void:
		_query = t
		refresh())
	filt.add_child(search)
	_body.add_child(filt)
	# Entry list.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_body.add_child(scroll)
	# Detail.
	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(430, 0)
	det.add_theme_constant_override("separation", 6)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(430, 0)
	_detail.add_theme_font_override("normal_font", UiStyle.display())
	_detail.add_theme_font_override("bold_font", UiStyle.display())
	_detail.add_theme_font_size_override("normal_font_size", 15)
	_detail.add_theme_font_size_override("bold_font_size", 15)
	_detail.add_theme_color_override("default_color", UiStyle.WHITE)
	det.add_child(_detail)
	var brow := HBoxContainer.new()
	_flag_btn = UiStyle.button("⚑ Flag for follow-up", 13)
	_flag_btn.pressed.connect(func() -> void:
		var e := clog.find(_selected)
		if not e.is_empty():
			clog.set_flag(_selected, not bool(e["flag"]))
			refresh())
	brow.add_child(_flag_btn)
	_chart_btn = UiStyle.button("Chart", 13)
	_chart_btn.pressed.connect(func() -> void:
		var e := clog.find(_selected)
		if e.has("pos"):
			show_on_chart.emit(Vector3(float(e["pos"][0]), 0.0, float(e["pos"][1]))))
	brow.add_child(_chart_btn)
	_contact_btn = UiStyle.button("Contact", 13)
	_contact_btn.pressed.connect(func() -> void:
		var e := clog.find(_selected)
		if e.has("contact"):
			show_contact.emit(String(e["contact"])))
	brow.add_child(_contact_btn)
	det.add_child(brow)
	det.add_child(UiStyle.label("NOTE ON THIS ENTRY", 11, UiStyle.DIM))
	_note_edit = TextEdit.new()
	_note_edit.custom_minimum_size = Vector2(430, 90)
	_note_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note_edit.add_theme_font_override("font", UiStyle.display())
	_note_edit.text_changed.connect(func() -> void:
		if _selected >= 0:
			clog.set_note(_selected, _note_edit.text))
	det.add_child(_note_edit)
	det.add_child(UiStyle.label("PERSONAL ENTRY", 11, UiStyle.DIM))
	var nrow := HBoxContainer.new()
	_new_note = LineEdit.new()
	_new_note.custom_minimum_size = Vector2(330, 0)
	_new_note.placeholder_text = "Write a short note…"
	_new_note.add_theme_font_override("font", UiStyle.display())
	_new_note.text_submitted.connect(func(_t: String) -> void: _add_note())
	nrow.add_child(_new_note)
	var add := UiStyle.button("Add", 13)
	add.pressed.connect(_add_note)
	nrow.add_child(add)
	det.add_child(nrow)
	_body.add_child(det)

	_other = RichTextLabel.new()
	_other.bbcode_enabled = true
	_other.custom_minimum_size = Vector2(1360, 640)
	_other.add_theme_font_override("normal_font", UiStyle.display())
	_other.add_theme_font_override("bold_font", UiStyle.display())
	_other.add_theme_font_size_override("normal_font_size", 15)
	_other.add_theme_font_size_override("bold_font_size", 15)
	_other.add_theme_color_override("default_color", UiStyle.WHITE)
	v.add_child(_other)
	visible = false


func _add_note() -> void:
	var t := _new_note.text.strip_edges()
	if t == "":
		return
	var e := clog.personal_note(t)
	_new_note.text = ""
	_selected = int(e["id"])
	refresh()


func open(tab: String = "log", contact_filter: String = "") -> void:
	_tab = tab
	visible = true
	if contact_filter != "":
		_query = contact_filter
	refresh()


func refresh() -> void:
	for id in _tab_btns.keys():
		(_tab_btns[id] as Button).button_pressed = id == _tab
	_body.visible = _tab == "log"
	_other.visible = _tab != "log"
	if _tab != "log":
		_other.text = _other_text()
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var es := clog.filtered(_cats, _kinds, _flagged, _query)
	if _newest_first:
		es.reverse()
	var kind_mark := {"confirmed": "●", "assessment": "◐", "unresolved": "○", "personal": "✎"}
	for e in es.slice(0, 400):
		var t := "%s %s  %-13s %-15s %s" % ["⚑" if bool(e["flag"]) else " ", kind_mark.get(String(e["kind"]), " "), String(e["time"]), String(e["cat"]), String(e["text"])]
		var b := UiStyle.button(t, 13)
		b.add_theme_font_override("font", UiStyle.mono())
		b.clip_text = true
		b.custom_minimum_size = Vector2(680, 0)
		var col := UiStyle.WHITE
		match String(e["kind"]):
			"assessment":
				col = Color(0.8, 0.88, 0.95)
			"unresolved":
				col = UiStyle.AMBER
			"personal":
				col = Color(0.75, 0.9, 0.75)
		if bool(e.get("watch", false)):
			col = col.darkened(0.08)
		b.add_theme_color_override("font_color", col)
		if int(e["id"]) == _selected:
			var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
			sb.bg_color = Color(0.12, 0.3, 0.38, 0.8)
			sb.border_color = UiStyle.CYAN
		var eid := int(e["id"])
		b.pressed.connect(func() -> void:
			_selected = eid
			var se := clog.find(eid)
			_note_edit.text = String(se.get("note", ""))
			refresh())
		_list.add_child(b)
	var sel := clog.find(_selected)
	if sel.is_empty():
		_detail.text = "[color=#8fa6b4]%d entries.  Select one for details.\n\n● confirmed   ◐ assessment   ○ unresolved   ✎ personal\n⚑ flagged for follow-up[/color]" % clog.entries.size()
	else:
		var kind_txt: String = {"confirmed": "Confirmed", "assessment": "Assessment", "unresolved": "Unresolved", "personal": "Personal note"}.get(String(sel["kind"]), "")
		var src := String(sel.get("source", ""))
		_detail.text = "[b]%s[/b]   ·   %s   ·   %s%s\n\n%s%s" % [String(sel["time"]), String(sel["cat"]), kind_txt,
			("   ·   " + src) if src != "" else "", String(sel["text"]),
			("\n\n[color=#9fdcb0]Resolved: %s[/color]" % String(sel["resolved"])) if sel.has("resolved") else ""]
	_flag_btn.text = "⚑ Clear flag" if bool(sel.get("flag", false)) else "⚑ Flag for follow-up"
	_flag_btn.disabled = sel.is_empty()
	_chart_btn.disabled = not sel.has("pos")
	_contact_btn.disabled = not sel.has("contact")
	_note_edit.editable = not sel.is_empty()


func _other_text() -> String:
	var body := ""
	match _tab:
		"orders":
			body += "[b]ORDERS AND OBJECTIVES[/b]\n\n"
			for o in patrol.objectives:
				var mark := "[color=#7ef0a8]DONE[/color]" if o["done"] else ("[color=#ff6a5a]FAILED[/color]" if o["failed"] else "[color=#9fb3c0]OPEN[/color]")
				body += "%s   %s\n" % [mark, o["text"]]
			if main and main.has_method("command_status_text"):
				body += "\n" + String(main.command_status_text())
		"signals":
			body += "[b]SIGNALS RECEIVED[/b]\n\n"
			if patrol.received.is_empty():
				body += "None copied yet. Broadcasts are copied at periscope depth with the masts up.\n"
			for m in patrol.received:
				body += "[color=#ffd29a]%s[/color]  %s\n%s\n\n" % [m["from"], String(m.get("received_time", "")), m["text"]]
		"watch":
			body += "[b]WATCH REPORT[/b]\n\n"
			if main and main.watch and not main.watch.report.is_empty():
				body += "\n".join(main.watch.report.slice(maxi(main.watch.report.size() - 40, 0)))
			else:
				body += "Nothing reported."
	return body
