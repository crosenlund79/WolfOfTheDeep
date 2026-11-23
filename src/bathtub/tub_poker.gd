class_name TubPoker
extends Control
## The Captains' Poker Club: choose a table, then four-player Texas Hold'em
## against the rival captains for real candy. After every captain's action
## the game waits for SPACE, so you always see who did what.

signal left(lines: Array)

var career: TubCareer
var session: TubPokerSession
var phase := "choose"               # choose, human, ai, hand_over, done
var message := ""
var quip := ""
var _choose: Control
var _buttons: HBoxContainer
var _btn := {}
var _last_action := {}              # seat -> text


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_buttons.position = Vector2(40, 990)
	add_child(_buttons)
	for b in [["fold", "Fold (F)", TubUi.RED], ["call", "Check / Call (C)", TubUi.MINT], ["min", "Raise (R)", TubUi.SUN],
			["pot", "Bet the pot (P)", TubUi.SUN], ["allin", "All in (A)", TubUi.PINK], ["leave", "Leave (ESC)", TubUi.SKY]]:
		var bt := TubUi.button(String(b[1]), b[2], 19)
		var id := String(b[0])
		bt.pressed.connect(func() -> void: _on_button(id))
		_buttons.add_child(bt)
		_btn[id] = bt
	visible = false


func open(car: TubCareer) -> void:
	career = car
	visible = true
	phase = "choose"
	message = ""
	quip = ""
	_buttons.visible = false
	_build_choose()


func _build_choose() -> void:
	if _choose:
		_choose.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TubUi.panel())
	panel.position = Vector2(400, 220)
	panel.size = Vector2(1120, 0)
	add_child(panel)
	_choose = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(TubUi.label("THE CAPTAINS' POKER CLUB", 34, TubUi.INK))
	v.add_child(TubUi.label("Four-player Texas Hold'em for real candy. You have %d. Lose it here and you have less for repairs - and so do they." % int(career.player["candy"]), 18, TubUi.DIM, false))
	for st in TubPokerSession.STAKES:
		var who := TubPokerSession.seating(career, st)
		var sit: Array[TubCaptain] = who["sit"]
		var away: Dictionary = who["away"]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		var b := TubUi.button("%s  ·  blinds %d/%d  ·  buy-in %d-%d" % [String(st["name"]), int(st["sb"]), int(st["bb"]), int(st["min"]), int(st["max"])], TubUi.SUN, 19)
		b.custom_minimum_size = Vector2(520, 0)
		b.disabled = int(career.player["candy"]) < int(st["min"]) or sit.is_empty()
		var stake: Dictionary = st
		b.pressed.connect(func() -> void: _sit(stake))
		h.add_child(b)
		var txt := "At the table: " + (", ".join(sit.map(func(c: TubCaptain) -> String: return c.short.capitalize())) if not sit.is_empty() else "nobody")
		for id in away.keys():
			txt += "\n%s: %s" % [String(career.captain(id).short).capitalize(), String(away[id])]
		var l := TubUi.label(txt, 15, TubUi.INK, false)
		l.custom_minimum_size = Vector2(520, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(l)
		v.add_child(h)
	var back := TubUi.button("Back to the harbour", TubUi.SKY, 20)
	back.pressed.connect(func() -> void:
		visible = false
		left.emit([]))
	v.add_child(back)


func _sit(st: Dictionary) -> void:
	session = TubPokerSession.new()
	var err := session.start(career, st)
	if err != "":
		message = err
		return
	_choose.queue_free()
	_choose = null
	_buttons.visible = true
	_deal()


func _deal() -> void:
	quip = ""
	_last_action.clear()
	if not session.deal():
		_finish("The game breaks up: %s." % ("you are out of chips" if int(session.game.players[0]["stack"]) <= 0 else "not enough players left"))
		return
	message = "Hand %d. %s deals. Blinds %d and %d candy." % [session.game.hand_number, session.game.players[session.game.dealer]["name"], session.game.small_blind, session.game.big_blind]
	_next()


func _next() -> void:
	var g := session.game
	if not g.hand_over and g.current < 0:
		message += g.run_out()
	if g.hand_over:
		phase = "hand_over"
		_hand_end_quips()
		session.sync()
		return
	phase = "human" if g.players[g.current]["human"] else "ai"


func _ai_step() -> void:
	var g := session.game
	var i := g.current
	var d := g.decide()
	var kind := String(d[0])
	message = g.act(kind, int(d[1]))
	_last_action[i] = String(g.players[i]["last"])
	quip = ""
	if kind == "raise":
		quip = session.quip(i, "poker_raise", 0.35)
	elif kind == "fold":
		quip = session.quip(i, "poker_fold", 0.2)
	_next()


func _hand_end_quips() -> void:
	var g := session.game
	if g.winners.is_empty():
		return
	var w := g.winners[0]
	if w != 0:
		quip = session.quip(w, "poker_win", 0.5)
	for i in g.players.size():
		if i != w and int(g.players[i]["stack"]) == 0 and not g.players[i]["human"]:
			quip = session.quip(i, "poker_lose", 1.0)


func _on_button(id: String) -> void:
	if phase == "choose" or session == null:
		return
	if id == "leave":
		_finish("")
		return
	if phase != "human":
		return
	var g := session.game
	match id:
		"fold":
			message = g.act("fold")
		"call":
			message = g.act("call")
		"min":
			message = g.act("raise", g.min_raise_to(0))
		"pot":
			message = g.act("raise", g.cur_bet + maxi(g.pot() + g.to_call(0), g.min_raise))
		"allin":
			message = g.act("raise", g.max_to(0))
	_last_action[0] = String(g.players[0]["last"])
	quip = ""
	_next()


func _finish(why: String) -> void:
	var lines := session.finish()
	if why != "":
		lines.push_front(why)
	phase = "done"
	visible = false
	left.emit(lines)


func handle_key(k: int) -> bool:
	if not visible:
		return false
	if phase == "choose":
		if k == KEY_ESCAPE:
			visible = false
			left.emit([])
			return true
		return false
	match k:
		KEY_SPACE, KEY_ENTER:
			if phase == "ai":
				_ai_step()
			elif phase == "hand_over":
				_deal()
		KEY_F:
			_on_button("fold")
		KEY_C:
			_on_button("call")
		KEY_R:
			_on_button("min")
		KEY_P:
			_on_button("pot")
		KEY_A:
			_on_button("allin")
		KEY_ESCAPE:
			_on_button("leave")
	return true


func _process(_d: float) -> void:
	if visible:
		if _buttons.visible and session:
			var human := phase == "human"
			for id in ["fold", "call", "min", "pot", "allin"]:
				(_btn[id] as Button).disabled = not human
			if human:
				var owe := session.game.to_call(0)
				(_btn["call"] as Button).text = ("Call %d (C)" % owe) if owe > 0 else "Check (C)"
		queue_redraw()


# --- drawing ----------------------------------------------------------------------

const SEAT_POS := [Vector2(960, 790), Vector2(330, 470), Vector2(960, 160), Vector2(1590, 470)]
const SUIT_COLORS := [Color(0.12, 0.12, 0.16), Color(0.85, 0.15, 0.2), Color(0.85, 0.15, 0.2), Color(0.12, 0.12, 0.16)]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.1, 0.14, 0.55))
	if phase == "choose" or session == null:
		return
	var f := TubArt.font(true)
	# The table: a teal bath mat with white stitching.
	var mat := StyleBoxFlat.new()
	mat.bg_color = Color(0.2, 0.62, 0.6)
	mat.set_corner_radius_all(220)
	mat.border_color = TubUi.INK
	mat.set_border_width_all(5)
	mat.shadow_color = Color(0, 0, 0, 0.35)
	mat.shadow_size = 24
	mat.anti_aliasing = true
	var table := Rect2(300, 220, 1320, 520)
	draw_style_box(mat, table)
	var stitch := StyleBoxFlat.new()
	stitch.bg_color = Color(0, 0, 0, 0)
	stitch.set_corner_radius_all(200)
	stitch.border_color = Color(1, 1, 1, 0.5)
	stitch.set_border_width_all(3)
	stitch.anti_aliasing = true
	draw_style_box(stitch, table.grow(-22))
	var g := session.game
	# Board and pot.
	for i in 5:
		var pos := Vector2(700 + i * 108, 410)
		if i < g.board.size():
			_card(pos, g.board[i], 96, 134)
		else:
			_slot(pos, 96, 134)
	var pot := g.pot()
	var ptxt := "POT  %d candy" % pot
	if g.hand_over and not g.winners.is_empty():
		ptxt = "POT WON BY " + " AND ".join(g.winners.map(func(w: int) -> String: return String(g.players[w]["name"]).to_upper()))
	var pw := f.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(f, Vector2(960 - pw * 0.5, 390), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	# Seats.
	for i in g.players.size():
		var p := g.players[i]
		var c: Vector2 = SEAT_POS[i]
		var cap := session.captain_at(i)
		var pid := "player" if cap == null else cap.id
		var acting := g.current == i and not g.hand_over
		TubUi.portrait(self, pid, c, 46.0, TubUi.SUN if acting else (cap.livery if cap else TubUi.TEAL))
		var nm := String(p["name"]) if cap == null else cap.short
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string_outline(f, c + Vector2(-nw * 0.5, 74), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color.WHITE)
		draw_string(f, c + Vector2(-nw * 0.5, 74), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TubUi.INK)
		var st := "%d on the table  ·  purse %d" % [int(p["stack"]), session.balance(i)]
		var sw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(TubUi.INK, 0.82)
		plate.set_corner_radius_all(11)
		plate.anti_aliasing = true
		draw_style_box(plate, Rect2(c + Vector2(-sw * 0.5 - 10, 80), Vector2(sw + 20, 24)))
		draw_string(f, c + Vector2(-sw * 0.5, 98), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TubUi.CREAM)
		var hole: Array = p["hole"]
		var cpos: Vector2 = c + (Vector2(60, -40) if i != 2 else Vector2(60, -30))
		if i == 0:
			cpos = c + Vector2(70, -60)
		var shown: bool = i == 0 or (g.showdown and not bool(p["folded"]) and g.hand_over)
		if not hole.is_empty() and not (p["folded"] and i != 0):
			for k in 2:
				if shown:
					_card(cpos + Vector2(k * 58, 0), int(hole[k]), 70, 98)
				else:
					_back(cpos + Vector2(k * 30, 0), 60, 84)
		var la := String(_last_action.get(i, ""))
		if p["folded"] and not g.hand_over and i != 0 and not hole.is_empty():
			la = "folded"
		if bool(p["allin"]):
			la = "ALL IN"
		if la != "":
			var lw := f.get_string_size(la.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			var r := Rect2(c + Vector2(-lw * 0.5 - 10, -88), Vector2(lw + 20, 28))
			var sb := StyleBoxFlat.new()
			sb.bg_color = TubUi.CREAM
			sb.set_corner_radius_all(12)
			sb.border_color = TubUi.INK
			sb.set_border_width_all(2)
			sb.anti_aliasing = true
			draw_style_box(sb, r)
			draw_string(f, r.position + Vector2(10, 21), la.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TubUi.INK)
		if g.dealer == i:
			draw_circle(c + Vector2(-56, 40), 13, Color.WHITE)
			draw_string(f, c + Vector2(-62, 46), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TubUi.INK)
	# Message log and prompts.
	var box := Rect2(1240, 800, 650, 250)
	draw_style_box(TubUi.panel(18, 0.95), box)
	var lines := message.strip_edges().split("\n")
	var y := box.position.y + 34
	for l in lines.slice(maxi(lines.size() - 6, 0)):
		draw_string(f, Vector2(box.position.x + 18, y), _you(l), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 17, TubUi.INK)
		y += 26
	if quip != "":
		draw_string(f, Vector2(box.position.x + 18, box.end.y - 22), quip, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 17, TubUi.PINK)
	var prompt := ""
	match phase:
		"ai":
			prompt = "SPACE: see what %s does" % String(g.players[g.current]["name"])
		"hand_over":
			prompt = "SPACE: next hand  ·  ESC: leave the table"
		"human":
			prompt = "Your turn"
	if prompt != "":
		var pw2 := f.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string_outline(f, Vector2(960 - pw2 * 0.5, 960), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 10, TubUi.INK)
		draw_string(f, Vector2(960 - pw2 * 0.5, 960), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, TubUi.SUN)


## The shared engine narrates in the third person ("YOU calls 4.");
## put the player's lines in the second person for the log.
static var _you_re := RegEx.create_from_string("\\bYOU (\\w+?)s\\b")
static func _you(l: String) -> String:
	if not l.contains("YOU "):
		return l
	var t := _you_re.sub(l, "YOU $1", true)
	return t.replace(" and is all in", " and are all in") if t.begins_with("YOU ") else t


func _card(pos: Vector2, card: int, w: float, h: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.96)
	sb.set_corner_radius_all(10)
	sb.border_color = TubUi.INK
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(pos, Vector2(w, h)))
	var s := PokerGame.card_suit(card)
	var col: Color = SUIT_COLORS[s]
	draw_string(TubArt.font(true), pos + Vector2(8, h * 0.26), PokerGame.RANKS[PokerGame.card_rank(card)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.24), col)
	_suit(pos + Vector2(w * 0.55, h * 0.64), s, w * 0.2, col)


func _back(pos: Vector2, w: float, h: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TubUi.PINK
	sb.set_corner_radius_all(9)
	sb.border_color = TubUi.INK
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(pos, Vector2(w, h)))
	for k in 3:
		draw_circle(pos + Vector2(w * 0.5, h * (0.3 + 0.2 * k)), w * 0.12, Color(1, 1, 1, 0.6))


func _slot(pos: Vector2, w: float, h: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(pos, Vector2(w, h)))


func _suit(c: Vector2, s: int, r: float, col: Color) -> void:
	match s:
		0:
			draw_circle(c + Vector2(-r * 0.5, r * 0.1), r * 0.55, col)
			draw_circle(c + Vector2(r * 0.5, r * 0.1), r * 0.55, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, 0.0), c + Vector2(0, -r * 1.2), c + Vector2(r * 1.02, 0.0)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(-r * 0.45, r * 1.05), c + Vector2(r * 0.45, r * 1.05)]), col)
		1:
			draw_circle(c + Vector2(-r * 0.5, -r * 0.3), r * 0.56, col)
			draw_circle(c + Vector2(r * 0.5, -r * 0.3), r * 0.56, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.04, -r * 0.15), c + Vector2(r * 1.04, -r * 0.15), c + Vector2(0, r * 1.05)]), col)
		2:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 0.8, 0), c + Vector2(0, r * 1.1), c + Vector2(-r * 0.8, 0)]), col)
		3:
			draw_circle(c + Vector2(0, -r * 0.55), r * 0.5, col)
			draw_circle(c + Vector2(-r * 0.55, r * 0.15), r * 0.5, col)
			draw_circle(c + Vector2(r * 0.55, r * 0.15), r * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(-r * 0.4, r * 1.05), c + Vector2(r * 0.4, r * 1.05)]), col)
