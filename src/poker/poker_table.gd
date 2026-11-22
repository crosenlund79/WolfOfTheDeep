class_name PokerTable
extends Control
## The mess table: a Texas Hold'em view over the mess. Each AI action is shown
## and waits for SPACE; the captain acts with buttons or keys. Sweets are the
## stakes and are settled back into everyone's own supply when the game ends.

signal finished(summary: String)

const QUIPS := {
	"basse": {"win": ["Ha! The liquorice stays in Denmark.", "You see? Patience. Like a good stew.", "Thank you, thank you. I will eat these in front of you."], "fold": ["Bah. Rubbish cards. Rubbish dealer.", "For helvede... no.", "I fold. But I am watching you."], "raise": ["Ja, ja. I raise. Don't look at me like that.", "More. Let's see who is hungry."]},
	"erik": {"win": ["Mathematics.", "Thank you."], "fold": ["No.", "Not worth it."], "raise": ["Raise.", "I'll go up."]},
	"freja": {"win": ["I was fairly sure.", "I could hear it coming."], "fold": ["Not this one.", "I'll listen to the next one."], "raise": ["I'll raise.", "Let's see."]},
	"maya": {"win": ["Read you like a chart, Captain.", "Calculated. Mostly."], "fold": ["Fine. Fine.", "I'll get you next hand."], "raise": ["Let's make it interesting.", "Raise. Keep up."]},
	"miller": {"win": ["Rank has its privileges. So does luck.", "Most kind of you all."], "fold": ["Discretion, valour, et cetera.", "I'll sit this one out."], "raise": ["I think I'll make it a little more expensive.", "Shall we?"]},
}
const SUIT_COLORS := [Color(0.08, 0.08, 0.1), Color(0.78, 0.1, 0.1), Color(0.78, 0.1, 0.1), Color(0.08, 0.08, 0.1)]

var game := PokerGame.new()
var crew: Crew
var phase := "idle"          # await_human, await_continue, hand_over, idle
var message := ""
var quip := ""
var _members: Dictionary = {}  # player index -> CrewMember (or null for the captain)
var _buttons: HBoxContainer
var _btn: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	game.rng.randomize()
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	UiStyle.place(_buttons, Vector2(0.5, 1), Vector2(-430, -96), Vector2(860, 40))
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_buttons)
	for def in [["fold", "F  FOLD"], ["call", "C  CHECK"], ["min", "R  RAISE"], ["pot", "P  BET POT"], ["allin", "A  ALL IN"], ["leave", "ESC  LEAVE TABLE"]]:
		var b := Button.new()
		b.text = String(def[1])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiStyle.display())
		b.add_theme_font_size_override("font_size", 15)
		for st in ["normal", "hover", "pressed", "disabled"]:
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0.12, 0.22, 0.16, 0.92) if st == "hover" else Color(0.05, 0.08, 0.07, 0.9)
			bs.border_color = Color(0.5, 0.75, 0.55, 0.6 if st != "disabled" else 0.15)
			bs.set_border_width_all(1)
			bs.set_content_margin_all(8)
			b.add_theme_stylebox_override(st, bs)
		b.pressed.connect(_on_button.bind(String(def[0])))
		_buttons.add_child(b)
		_btn[def[0]] = b
	visible = false


## Sit down with whoever is free in the mess. Returns "" or a reason it can't start.
func open(players: Array[CrewMember]) -> String:
	var defs: Array = []
	_members.clear()
	var cap := crew.captain_candy
	var cap_total := _count(cap)
	if cap_total < PokerGame.BIG_BLIND:
		return "You have no sweets left to play with."
	defs.append({"id": "captain", "name": "CAPTAIN", "stack": cap_total, "human": true})
	_members[0] = null
	for m in players:
		var total := _count(m.candy)
		if total < PokerGame.BIG_BLIND:
			continue
		_members[defs.size()] = m
		defs.append({"id": m.id, "name": m.short, "stack": total, "temper": m.poker})
	if defs.size() < 2:
		return "Nobody in the mess is free for cards right now."
	game = PokerGame.new()
	game.rng.randomize()
	game.setup(defs)
	visible = true
	_leaving = false
	_deal()
	return ""


func _deal() -> void:
	quip = ""
	if not game.new_hand():
		_end("Not enough players with sweets left to continue.")
		return
	message = "Hand %d. %s deals. Blinds %d and %d sweets." % [game.hand_number, game.players[game.dealer]["name"], PokerGame.SMALL_BLIND, PokerGame.BIG_BLIND]
	_next()


func _next() -> void:
	if not game.hand_over and game.current < 0:
		message += game.run_out()
	if game.hand_over:
		phase = "hand_over"
		_hand_quip()
		_refresh()
		return
	var p := game.players[game.current]
	if p["human"]:
		phase = "await_human"
		if _leaving:
			message = game.act("fold")
			_auto_finish()
			return
	else:
		phase = "await_continue"
	_refresh()


## The captain's seat is folded or left: let the AI finish the hand quickly.
func _auto_finish() -> void:
	var guard := 0
	while not game.hand_over and guard < 200:
		guard += 1
		if game.current < 0:
			message += game.run_out()
			continue
		if game.players[game.current]["human"]:
			message = game.act("fold")
			continue
		var d := game.decide()
		message = game.act(String(d[0]), int(d[1]))
	phase = "hand_over"
	_refresh()


func _ai_step() -> void:
	var i := game.current
	var d := game.decide()
	var kind := String(d[0])
	message = game.act(kind, int(d[1]))
	quip = ""
	var m: CrewMember = _members.get(i)
	if m and QUIPS.has(m.id) and _rng.randf() < 0.3:
		var key := "raise" if kind == "raise" else ("fold" if kind == "fold" else "")
		if key != "":
			var pool: Array = QUIPS[m.id][key]
			quip = "%s: \"%s\"" % [m.short, pool[_rng.randi() % pool.size()]]
	_next()


func _hand_quip() -> void:
	if game.winners.is_empty():
		return
	var m: CrewMember = _members.get(game.winners[0])
	if m and QUIPS.has(m.id) and _rng.randf() < 0.6:
		var pool: Array = QUIPS[m.id]["win"]
		quip = "%s: \"%s\"" % [m.short, pool[_rng.randi() % pool.size()]]


func _on_button(id: String) -> void:
	match id:
		"fold":
			_human("fold", 0)
		"call":
			_human("call", 0)
		"min":
			_human("raise", game.min_raise_to(0))
		"pot":
			_human("raise", game.cur_bet + maxi(game.pot() + game.to_call(0), game.min_raise))
		"allin":
			_human("raise", game.max_to(0))
		"leave":
			leave()


func _human(kind: String, amount: int) -> void:
	if phase != "await_human":
		return
	quip = ""
	message = game.act(kind, amount)
	_next()


func handle_key(k: int) -> bool:
	if not visible:
		return false
	match k:
		KEY_SPACE, KEY_ENTER:
			if phase == "await_continue":
				_ai_step()
			elif phase == "hand_over":
				if _leaving:
					_end("")
				else:
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
			leave()
	return true


func leave() -> void:
	if game.hand_over:
		_end("")
	else:
		_leaving = true
		if phase == "await_human":
			message = game.act("fold")
			_auto_finish()
		else:
			_auto_finish()
		message += "\nYou leave the table after this hand. SPACE to stand up."


## Emergency or duty: sweep the cards aside and return everyone's stake.
func interrupt(reason: String) -> void:
	if not visible:
		return
	game.abandon()
	_end(reason)


func _end(reason: String) -> void:
	var summary := _settle()
	visible = false
	phase = "idle"
	finished.emit((reason + "\n" if reason != "" else "") + summary)


## Turn stacks back into actual sweets: losers pay from what they value least.
func _settle() -> String:
	var pool := {"liquorice": 0, "chocolate": 0, "toffee": 0}
	var gains: Array = []
	var lines: Array[String] = []
	for i in game.players.size():
		var p := game.players[i]
		var delta := int(p["stack"]) - int(p["start"])
		var candy: Dictionary = crew.captain_candy if i == 0 else (_members[i] as CrewMember).candy
		if delta < 0:
			var order := ["toffee", "chocolate", "liquorice"]
			var owe := -delta
			for kind in order:
				var take := mini(owe, int(candy.get(kind, 0)))
				candy[kind] = int(candy.get(kind, 0)) - take
				pool[kind] = int(pool[kind]) + take
				owe -= take
		elif delta > 0:
			gains.append([candy, delta])
		if delta != 0:
			lines.append("%s %s%d" % [p["name"], "+" if delta > 0 else "", delta])
	for g in gains:
		var candy2: Dictionary = g[0]
		var need := int(g[1])
		while need > 0:
			var kinds := pool.keys().filter(func(k: String) -> bool: return int(pool[k]) > 0)
			if kinds.is_empty():
				break
			var k2: String = kinds[_rng.randi() % kinds.size()]
			pool[k2] = int(pool[k2]) - 1
			candy2[k2] = int(candy2.get(k2, 0)) + 1
			need -= 1
	crew.save_state()
	if lines.is_empty():
		return "Everyone leaves the table with what they brought."
	return "Sweets changed hands: " + ", ".join(lines) + "."


static func _count(c: Dictionary) -> int:
	return int(c.get("liquorice", 0)) + int(c.get("chocolate", 0)) + int(c.get("toffee", 0))


func _refresh() -> void:
	var mine := phase == "await_human"
	for k in ["fold", "call", "min", "pot", "allin"]:
		(_btn[k] as Button).disabled = not mine
	if mine:
		var owe := game.to_call(0)
		(_btn["call"] as Button).text = "C  CHECK" if owe == 0 else "C  CALL %d" % owe
		(_btn["min"] as Button).text = ("R  BET %d" if game.cur_bet == 0 else "R  RAISE TO %d") % game.min_raise_to(0)
		(_btn["allin"] as Button).text = "A  ALL IN (%d)" % int(game.players[0]["stack"])
	queue_redraw()


func _draw() -> void:
	var vp := size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	var c := vp * Vector2(0.5, 0.46)
	var rx := minf(vp.x * 0.32, 580.0)
	var ry := minf(vp.y * 0.19, 200.0)
	_ellipse(c, rx + 18.0, ry + 18.0, Color(0.24, 0.15, 0.09))
	_ellipse(c, rx, ry, Color(0.07, 0.3, 0.18))
	_ellipse(c, rx * 0.86, ry * 0.8, Color(0.08, 0.33, 0.2))
	var f := UiStyle.display()
	var fm := UiStyle.mono()
	draw_string(f, Vector2(40, 52), "MESS TABLE  ·  TEXAS HOLD'EM FOR SWEETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.6))
	draw_string(f, Vector2(40, 78), "Blinds %d / %d sweets  ·  hand %d" % [PokerGame.SMALL_BLIND, PokerGame.BIG_BLIND, game.hand_number], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.DIM)
	# Board and pot.
	var cw := 58.0
	var chh := 82.0
	for k in 5:
		var pos := c + Vector2((k - 2) * (cw + 10.0) - cw * 0.5, -chh * 0.5 - 8.0)
		if k < game.board.size():
			_card(pos, game.board[k], cw, chh)
		else:
			draw_rect(Rect2(pos, Vector2(cw, chh)), Color(1, 1, 1, 0.06), false, 1.5)
	var pot_text := "POT  %d" % (game.pot() if not game.hand_over else 0)
	draw_string(f, c + Vector2(-160, chh * 0.5 + 30.0), pot_text, HORIZONTAL_ALIGNMENT_CENTER, 320, 18, Color(1.0, 0.92, 0.7))
	# Seats: the captain at the bottom, crew around the far side.
	var n := game.players.size()
	for i in n:
		var p := game.players[i]
		var ang := PI * 0.5 + TAU * float(i) / float(n)
		var sp := c + Vector2(cos(ang) * (rx + 120.0), sin(ang) * (ry + 64.0))
		var m: CrewMember = _members.get(i)
		var col := m.color if m else UiStyle.CYAN
		var active := i == game.current and not game.hand_over
		var box := Rect2(sp - Vector2(110, 34), Vector2(220, 68))
		draw_rect(box, Color(0.02, 0.03, 0.03, 0.85))
		draw_rect(box, col if active else Color(1, 1, 1, 0.15), false, 2.0 if active else 1.0)
		var name_txt := String(p["name"]) + ("   (D)" if i == game.dealer else "")
		draw_string(f, box.position + Vector2(10, 22), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		var status := "%d sweets" % int(p["stack"])
		if p["folded"] and not game.hand_over:
			status += "  ·  folded"
		elif p["allin"]:
			status += "  ·  ALL IN"
		draw_string(fm, box.position + Vector2(10, 44), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.WHITE)
		var last := String(p["last"])
		if last != "" and not game.hand_over:
			draw_string(fm, box.position + Vector2(10, 61), last.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.86, 0.5))
		if m:
			var cand := m.candy
			draw_string(fm, box.position + Vector2(10, 82), "L%d  C%d  T%d" % [int(cand.get("liquorice", 0)), int(cand.get("chocolate", 0)), int(cand.get("toffee", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		# Cards: the captain's face up; others only at showdown.
		var hole: Array = p["hole"]
		if hole.size() == 2 and (not p["folded"] or i == 0):
			var reveal: bool = i == 0 or (game.showdown and not p["folded"])
			var cp := sp.lerp(c, 0.4) - Vector2(cw * 0.7, chh * 0.4)
			if i == 0:
				cp = sp + Vector2(130, -chh * 0.5)
			for k in 2:
				var at := cp + Vector2(k * (cw * 0.62), 0)
				if reveal:
					_card(at, int(hole[k]), cw * 0.8, chh * 0.8)
				else:
					_back(at, cw * 0.8, chh * 0.8)
	# Message and quip: a column on the left; the prompt above the buttons.
	var lines := message.strip_edges().split("\n")
	var box_h := 34.0 + lines.size() * 24.0 + (26.0 if quip != "" else 0.0)
	draw_rect(Rect2(Vector2(28, 108), Vector2(minf(vp.x * 0.27, 520.0), box_h)), Color(0.0, 0.0, 0.0, 0.55))
	var y := 136.0
	for line in lines:
		draw_string(f, Vector2(42, y), line, HORIZONTAL_ALIGNMENT_LEFT, minf(vp.x * 0.27, 520.0) - 24.0, 16, UiStyle.WHITE)
		y += 24.0
	if quip != "":
		draw_string(f, Vector2(42, y + 2.0), quip, HORIZONTAL_ALIGNMENT_LEFT, minf(vp.x * 0.27, 520.0) - 24.0, 15, Color(1.0, 0.8, 0.55))
	var prompt := ""
	match phase:
		"await_continue":
			prompt = "SPACE  —  continue  (%s to act)" % game.players[game.current]["name"] if game.current >= 0 else "SPACE  —  continue"
		"hand_over":
			prompt = "SPACE  —  stand up" if _leaving else "SPACE  —  next hand     ·     ESC  —  leave the table"
		"await_human":
			var owe := game.to_call(0)
			prompt = "YOUR ACTION  —  %s" % ("check or bet" if owe == 0 else "%d to call" % owe)
			if game.players[0]["hole"].size() == 2:
				var sc := PokerGame.evaluate((game.players[0]["hole"] as Array) + game.board) if game.board.size() >= 3 else -1
				if sc >= 0:
					prompt += "   ·   you have %s" % PokerGame.hand_name(sc)
	draw_string(f, Vector2(vp.x * 0.5 - 600, vp.y - 112.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, 1200, 16, UiStyle.CYAN)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 64:
		var a := TAU * float(k) / 64.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _card(pos: Vector2, card: int, w: float, h: float) -> void:
	draw_rect(Rect2(pos + Vector2(2, 3), Vector2(w, h)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.96, 0.95, 0.9))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.3, 0.3, 0.3), false, 1.0)
	var s := PokerGame.card_suit(card)
	var col: Color = SUIT_COLORS[s]
	draw_string(UiStyle.display(), pos + Vector2(5, 20 * h / 82.0), PokerGame.RANKS[PokerGame.card_rank(card)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * h / 82.0), col)
	_suit(pos + Vector2(w * 0.5, h * 0.6), s, w * 0.2, col)


func _back(pos: Vector2, w: float, h: float) -> void:
	draw_rect(Rect2(pos + Vector2(2, 3), Vector2(w, h)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.12, 0.2, 0.4))
	draw_rect(Rect2(pos + Vector2(4, 4), Vector2(w - 8, h - 8)), Color(0.75, 0.8, 0.9, 0.5), false, 1.0)


## Suits drawn as shapes (no reliance on font glyphs).
func _suit(c: Vector2, s: int, r: float, col: Color) -> void:
	match s:
		0:  # spade
			draw_circle(c + Vector2(-r * 0.5, r * 0.1), r * 0.55, col)
			draw_circle(c + Vector2(r * 0.5, r * 0.1), r * 0.55, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, 0.0), c + Vector2(0, -r * 1.2), c + Vector2(r * 1.02, 0.0)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(-r * 0.45, r * 1.05), c + Vector2(r * 0.45, r * 1.05)]), col)
		1:  # heart
			draw_circle(c + Vector2(-r * 0.5, -r * 0.3), r * 0.56, col)
			draw_circle(c + Vector2(r * 0.5, -r * 0.3), r * 0.56, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.04, -r * 0.15), c + Vector2(r * 1.04, -r * 0.15), c + Vector2(0, r * 1.05)]), col)
		2:  # diamond
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 0.8, 0), c + Vector2(0, r * 1.1), c + Vector2(-r * 0.8, 0)]), col)
		3:  # club
			draw_circle(c + Vector2(0, -r * 0.5), r * 0.48, col)
			draw_circle(c + Vector2(-r * 0.55, r * 0.15), r * 0.48, col)
			draw_circle(c + Vector2(r * 0.55, r * 0.15), r * 0.48, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(-r * 0.4, r * 1.05), c + Vector2(r * 0.4, r * 1.05)]), col)
