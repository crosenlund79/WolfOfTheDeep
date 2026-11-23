class_name TubManage
extends Control
## Submarine management: SUBMARINE, REPAIRS, UPGRADES and CAPTAINS. Opened
## with TAB in battle (the battle is frozen while it is open) or from the
## harbour. In battle only an emergency patch can be bought; full repairs and
## upgrades happen at the harbour between battles.

signal closed
signal spent(what: String)

const PATCH_HULL := 20.0
const PATCH_PRICE := 15

var career: TubCareer
var battle: TubBattle               # set while fighting
var tab := "sub"
var _content: VBoxContainer
var _tabs := {}
var _title: Label
var _candy: Label
var patched := false


class Bar extends Control:
	var frac := 1.0
	var col := Color.WHITE
	func _init(f: float, c: Color, w: float = 220.0) -> void:
		frac = f
		col = c
		custom_minimum_size = Vector2(w, 18)
	func _draw() -> void:
		TubUi.bar(self, Rect2(Vector2(0, 2), Vector2(size.x, 14)), frac, col)


class Portrait extends Control:
	var id := ""
	var ring := Color.WHITE
	func _init(i: String, r: Color) -> void:
		id = i
		ring = r
		custom_minimum_size = Vector2(84, 84)
	func _draw() -> void:
		TubUi.portrait(self, id, size * 0.5, 34.0, ring)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.12, 0.16, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TubUi.panel())
	panel.position = Vector2(260, 110)
	panel.size = Vector2(1400, 860)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_title = TubUi.label("", 30, TubUi.INK)
	_title.custom_minimum_size = Vector2(520, 0)
	head.add_child(_title)
	for t in [["sub", "Submarine"], ["repairs", "Repairs"], ["upgrades", "Upgrades"], ["captains", "Captains"]]:
		var b := TubUi.button(String(t[1]), TubUi.SKY, 18)
		var id := String(t[0])
		b.pressed.connect(func() -> void: show_tab(id))
		head.add_child(b)
		_tabs[id] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_candy = TubUi.label("", 26, TubUi.PINK)
	head.add_child(_candy)
	var close := TubUi.button("Close  (TAB)", TubUi.SUN, 18)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1360, 740)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	visible = false


func open(t: String = "") -> void:
	if t != "":
		tab = t
	visible = true
	show_tab(tab)


func _ship() -> Dictionary:
	# In battle, the live state; at the harbour, the career's.
	if battle:
		return battle.player.state_dict()
	return career.player["ship"]


func _candy_now() -> int:
	return int(career.player["candy"])


func show_tab(t: String) -> void:
	tab = t
	for id in _tabs.keys():
		(_tabs[id] as Button).modulate = Color(1, 1, 1) if id == t else Color(0.85, 0.85, 0.9)
	for ch in _content.get_children():
		ch.queue_free()
	_candy.text = "%d candy" % _candy_now()
	_title.text = ("PAUSED  ·  " if battle else "THE SOAP DISH  ·  ") + {"sub": "SUBMARINE", "repairs": "REPAIRS", "upgrades": "UPGRADES", "captains": "CAPTAINS"}[t]
	match t:
		"sub":
			_tab_sub()
		"repairs":
			_tab_repairs()
		"upgrades":
			_tab_upgrades()
		"captains":
			_tab_captains()


func _row(parts: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	for p in parts:
		h.add_child(p)
	_content.add_child(h)
	return h


func _lab(text: String, size: int = 18, col: Color = TubUi.INK, w: float = 0.0) -> Label:
	var l := TubUi.label(text, size, col, size >= 20)
	if w > 0.0:
		l.custom_minimum_size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _tab_sub() -> void:
	var ship := _ship()
	var hf := float(ship["hull"]) / float(ship["max_hull"])
	_row([_lab("LITTLE WOLF  ·  Toy Submarine", 24, TubUi.TEAL)])
	_row([_lab("Hull", 18, TubUi.INK, 220.0), Bar.new(hf, TubUi.health_color(hf), 360.0), _lab("%d / %d" % [int(ship["hull"]), int(ship["max_hull"])])])
	for c in TubData.COMPONENTS:
		var v := float((ship["comp"] as Dictionary)[c])
		_row([_lab(String(TubData.COMPONENT_NAMES[c]), 18, TubUi.INK, 220.0), Bar.new(v, TubUi.health_color(v), 360.0),
			_lab("%d%%%s" % [int(v * 100.0), ("  ·  " + String(TubData.COMPONENT_EFFECT[c])) if v < 0.95 else ""], 16, TubUi.DIM)])
	var ups: Array = ship["upgrades"]
	_row([_lab("Equipment", 18, TubUi.INK, 220.0), _lab(", ".join(ups.map(func(u: String) -> String: return String(TubData.SHOP[u]["name"]))) if not ups.is_empty() else "basic fit: 8 torpedoes, standard propeller and rudder", 16, TubUi.DIM, 900.0)])
	_content.add_child(_lab("\nDEPTH", 20, TubUi.TEAL))
	_content.add_child(_lab("SURFACE: fastest, sees furthest, but deck guns can hit you.   PERISCOPE: a little slower and much harder to spot; you can still fire.   DEEP: slow and almost invisible, passes under sponges, washcloths and enemy torpedoes - but you cannot fire, your air runs out, and depth charges reach you.", 16, TubUi.INK, 1300.0))


func _tab_repairs() -> void:
	var ship := _ship()
	if battle:
		_content.add_child(_lab("Full repairs need the harbour. Out here you can only slap on an emergency patch.", 18, TubUi.DIM, 1300.0))
		var can := not patched and _candy_now() >= PATCH_PRICE and battle.player.hull < battle.player.max_hull
		var b := TubUi.button("Emergency patch: +%d hull for %d candy (once per battle)" % [int(PATCH_HULL), PATCH_PRICE], TubUi.PINK, 18)
		b.disabled = not can
		b.pressed.connect(func() -> void:
			patched = true
			career.player["candy"] = _candy_now() - PATCH_PRICE
			battle.player.hull = minf(battle.player.hull + PATCH_HULL, float(battle.player.max_hull))
			spent.emit("patch")
			show_tab("repairs"))
		_content.add_child(b)
	var hc := TubEconomy.hull_cost(ship)
	var hf := float(ship["hull"]) / float(ship["max_hull"])
	var hb := TubUi.button("Repair hull: %d candy" % hc if hc > 0 else "Hull is sound", TubUi.MINT, 18)
	hb.disabled = battle != null or hc <= 0 or _candy_now() <= 0
	hb.pressed.connect(func() -> void:
		var s := TubEconomy.repair_hull(ship, _candy_now())
		career.player["candy"] = _candy_now() - s
		spent.emit("hull")
		show_tab("repairs"))
	_row([_lab("Hull", 18, TubUi.INK, 200.0), Bar.new(hf, TubUi.health_color(hf), 280.0), _lab("%d / %d" % [int(ship["hull"]), int(ship["max_hull"])], 16, TubUi.INK, 120.0), hb,
		_lab("Later: fewer hits before you sink." if hf < 0.95 else "", 15, TubUi.DIM)])
	for c in TubData.COMPONENTS:
		var v := float((ship["comp"] as Dictionary)[c])
		var cost := TubEconomy.comp_cost(ship, c)
		var cb := TubUi.button("Fix: %d candy" % cost if cost > 0 else "In good order", TubUi.MINT, 18)
		cb.disabled = battle != null or cost <= 0 or _candy_now() <= 0
		var comp_id := String(c)
		cb.pressed.connect(func() -> void:
			var s2 := TubEconomy.repair_comp(ship, comp_id, _candy_now())
			career.player["candy"] = _candy_now() - s2
			spent.emit(comp_id)
			show_tab("repairs"))
		_row([_lab(String(TubData.COMPONENT_NAMES[c]), 18, TubUi.INK, 200.0), Bar.new(v, TubUi.health_color(v), 280.0), _lab("%d%%" % int(v * 100.0), 16, TubUi.INK, 120.0), cb,
			_lab(("Postponed: " + String(TubData.COMPONENT_EFFECT[c])) if v < 0.95 else "", 15, TubUi.DIM)])
	var total := TubEconomy.full_repair_cost(ship)
	_content.add_child(_lab("\nEverything mended: %d candy. You have %d. Short of candy? The harbour patches any boat up to %d%% hull for free, so you can always sail." % [total, _candy_now(), int(TubData.PATCH_HULL * 100.0)], 16, TubUi.DIM, 1300.0))


func _tab_upgrades() -> void:
	var ship := _ship()
	if battle:
		_content.add_child(_lab("Upgrades are fitted at the harbour, between battles.", 18, TubUi.DIM, 1300.0))
	for id in TubData.SHOP_ORDER:
		var it: Dictionary = TubData.SHOP[id]
		if not (it["for"] as Array).has("sub"):
			continue
		var why := TubEconomy.buy_blocker(ship, id, _candy_now())
		var owned := (ship["upgrades"] as Array).has(id)
		var b := TubUi.button("Fitted" if owned else "Buy: %d candy" % int(it["price"]), TubUi.SUN, 18)
		b.disabled = battle != null or why != ""
		var item := String(id)
		b.pressed.connect(func() -> void:
			career.player["candy"] = _candy_now() - TubEconomy.buy(ship, item)
			spent.emit(item)
			show_tab("upgrades"))
		_row([_lab(String(it["name"]), 20, TubUi.INK, 300.0), _lab(String(it["desc"]), 17, TubUi.DIM, 520.0), b])


func _tab_captains() -> void:
	for c in career.roster():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		h.add_child(Portrait.new(c.id, c.livery))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.add_child(_lab("%s  ·  %s, a %s" % [c.name, c.vessel, String(TubData.KINDS[c.kind]["name"]).to_lower()], 20, TubUi.INK))
		var hf := float(c.ship["hull"]) / float(c.ship["max_hull"])
		var ups: Array = c.ship["upgrades"]
		col.add_child(_lab("Purse: %d candy   ·   Ship: %d%% hull   ·   Equipment: %s" % [c.candy, int(hf * 100.0),
			", ".join(ups.map(func(u: String) -> String: return String(TubData.SHOP[u]["name"]))) if not ups.is_empty() else "standard"], 16, TubUi.INK))
		col.add_child(_lab("Mood: %s   ·   Battles with you: %d   ·   Sunk by you: %d   ·   Sank you: %d   ·   At the table: %+d candy" % [c.attitude(),
			int(c.record["battles"]), int(c.record["sunk_by_player"]), int(c.record["sank_player"]), int(c.record["poker_net"])], 16, TubHud._mood_col(c.attitude())))
		col.add_child(_lab(String(TubData.ROSTER[c.id]["style"]), 15, TubUi.DIM, 1150.0))
		if not c.memories.is_empty():
			var last: Dictionary = c.memories[-1]
			col.add_child(_lab("Remembers: " + String(last["text"]), 15, TubUi.DIM, 1150.0))
		h.add_child(col)
		_content.add_child(h)
