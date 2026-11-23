extends SceneTree
## Practical check of the Captains' Poker Club and GRUDGE (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_tub_rivals.gd
## Real candy at the table (no betting what you do not have, all-ins and side
## pots), the explicit persistence test (a rival loses to you at poker, can no
## longer afford what they could, the next battle shows it, save/load keeps
## it), grudges and tilt growing from events, and the table waiting for SPACE
## after each captain acts.

var failures := 0
var frame := 0
var main: Node
var _msg := ""
const DIR := "user://bathtub_check_rivals/"


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _card(rank: int, suit: int) -> int:
	return suit * 13 + (rank - 2)


func _career() -> TubCareer:
	var car := TubCareer.new()
	car.save_dir = DIR
	car.new_game(21)
	return car


## Everyone all in, as the order of play allows.
func _all_in(g: PokerGame) -> void:
	var guard := 0
	while not g.hand_over and guard < 50:
		guard += 1
		if g.current >= 0:
			g.act("raise", g.max_to(g.current))
		else:
			g.run_out()


func _initialize() -> void:
	_side_pots()
	_six_steps()
	_grudge()
	main = load("res://scenes/bathtub.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		main.career.save_dir = DIR
		main.career.new_game(8)
		main.open_poker()
		main.poker._sit(TubPokerSession.STAKES[0])
		var g: PokerGame = main.poker.session.game
		# Play until a captain is to act.
		var guard := 0
		while main.poker.phase == "human" and guard < 10:
			guard += 1
			main.poker._on_button("call")
		_msg = main.poker.message
	if frame == 30:
		print("pacing at the table")
		_ok(main.poker.phase == "ai", "after a captain's turn comes up, the game waits (phase %s)" % main.poker.phase)
		_ok(main.poker.message == _msg, "nothing happens without SPACE")
		main.poker.handle_key(KEY_SPACE)
		_ok(main.poker.message != _msg, "SPACE: the captain acts and it is shown: " + main.poker.message.strip_edges().split("\n")[0])
		var four: bool = main.poker.session.game.players.size() == 4
		_ok(four, "a proper four-player table: you and three captains")
		main.poker._finish("")
		_ok(not main.poker.visible and main.state == "harbour", "leaving returns to the harbour")
		for f in ["career.json", "prebattle.json"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
		print("TUB RIVALS CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		return true
	return false


func _side_pots() -> void:
	print("real candy at the table: all-ins and side pots")
	var car := _career()
	for c in car.roster():
		c.candy = 0
	car.player["candy"] = 50
	car.captain("quackworth").candy = 50
	car.captain("plunge").candy = 20
	car.captain("moss").candy = 5
	var who := TubPokerSession.seating(car, TubPokerSession.STAKES[0])
	_ok((who["away"] as Dictionary).has("moss") and String((who["away"] as Dictionary)["moss"]).contains("can't afford"), "a captain with 5 candy cannot sit at a 10-candy table")
	var s := TubPokerSession.new()
	_ok(s.start(car, TubPokerSession.STAKES[0], 99) == "", "three sit down")
	var g := s.game
	_ok(g.players.size() == 3 and String(s.seats[1]["id"]) == "quackworth" and String(s.seats[2]["id"]) == "plunge", "you, Quackworth and Plunge")
	_ok(g.max_to(2) == 20, "Plunge can bet at most the 20 candy he owns")
	s.deal()
	g.players[0]["hole"] = [_card(13, 0), _card(13, 1)]      # you: kings
	g.players[1]["hole"] = [_card(7, 3), _card(2, 2)]        # Quackworth: nothing
	g.players[2]["hole"] = [_card(14, 0), _card(14, 1)]      # Plunge: aces
	g.deck = [_card(4, 0), _card(11, 3), _card(3, 1), _card(5, 2), _card(9, 3)]
	var total := 0
	for i in 3:
		total += s.balance(i)
	_all_in(g)
	s.sync()
	print("        ", g.result_text.replace("\n", " | "))
	_ok(int(g.players[2]["stack"]) == 60, "Plunge, all in for 20 with the best hand, wins only the main pot: 60")
	_ok(int(g.players[0]["stack"]) == 60 and int(g.players[1]["stack"]) == 0, "you win the side pot of 60; Quackworth is out")
	var after := 0
	for i in 3:
		after += s.balance(i)
	_ok(after == total, "not a sweet created or lost (%d before, %d after)" % [total, after])
	_ok(int(car.player["candy"]) == 60 and car.captain("plunge").candy == 60 and car.captain("quackworth").candy == 0, "and every purse in the career shows it at once")
	_ok(s.deal() and bool(g.players[1]["folded"]) and (g.players[1]["hole"] as Array).is_empty() and int(g.players[1]["total"]) == 0, "next hand: the busted Admiral is dealt nothing and stakes nothing")


func _six_steps() -> void:
	print("the persistent economy, step by step")
	var car := _career()
	for c in car.roster():
		c.candy = 0
	var plunge := car.captain("plunge")
	plunge.candy = int(TubData.ROSTER["plunge"]["candy"])
	plunge.ship["hull"] = 60.0
	car.player["candy"] = 100
	# 1. A fixed starting balance.
	_ok(plunge.candy == 160, "1. Commodore Plunge starts with 160 candy")
	var budget := plunge.candy - TubEconomy.repair_hull(plunge.ship.duplicate(true), plunge.candy, 27) - plunge.reserve
	_ok(TubEconomy.buy_blocker(plunge.ship, "armour", budget) == "", "   with that, after repairs he could afford a Reinforced Hull (60)")
	# 2. He loses candy to the player at poker.
	var s := TubPokerSession.new()
	_ok(s.start(car, TubPokerSession.STAKES[1], 5) == "", "   heads-up at the Bubble Table")
	s.deal()
	var g := s.game
	g.players[0]["hole"] = [_card(14, 0), _card(14, 1)]
	g.players[1]["hole"] = [_card(13, 0), _card(13, 1)]
	g.deck = [_card(4, 0), _card(11, 3), _card(3, 1), _card(6, 2), _card(9, 3)]
	_all_in(g)
	var lines := s.finish()
	print("        ", g.result_text.replace("\n", " | "), "  ", lines)
	_ok(plunge.candy == 60, "2. he loses 100 at the table: 160 -> %d" % plunge.candy)
	# 3. The player gains exactly that.
	_ok(int(car.player["candy"]) == 200, "3. your purse grows by the same 100: 100 -> %d" % int(car.player["candy"]))
	# 4. He can no longer afford it.
	var budget2 := plunge.candy - TubEconomy.repair_hull(plunge.ship.duplicate(true), plunge.candy, 27) - plunge.reserve
	_ok(TubEconomy.buy_blocker(plunge.ship, "armour", budget2) != "", "4. now the Reinforced Hull is out of reach (%d to spare)" % budget2)
	# 5. The next battle shows it.
	car.refit_due = true
	car.last_opponents = []
	plunge.grudge = 100.0
	var b := car.start_battle()
	var ups: Array = plunge.ship["upgrades"]
	_ok(not ups.has("armour") and int(plunge.ship["max_hull"]) == 150 and float(plunge.ship["hull"]) < 150.0, "5. he refits on what he has: no armour, hull %d / %d" % [int(plunge.ship["hull"]), int(plunge.ship["max_hull"])])
	var in_battle: TubShip = null
	for sh in b.ships:
		if sh.id == "plunge":
			in_battle = sh
	if in_battle == null:
		b = TubBattle.new()
		b.setup(car.player["ship"], int(car.player["candy"]), [plunge], 3)
		in_battle = b.ships[1]
	_ok(in_battle.max_hull == 150 and is_equal_approx(in_battle.hull, float(plunge.ship["hull"])) and not in_battle.has("armour"), "   and his destroyer enters the battle that way")
	# 6. Save and load.
	_ok(car.save(), "6. saved")
	var car2 := TubCareer.new()
	car2.save_dir = DIR
	_ok(car2.load_file(), "   loaded into a fresh game")
	var p2 := car2.captain("plunge")
	_ok(p2.candy == plunge.candy and is_equal_approx(float(p2.ship["hull"]), float(plunge.ship["hull"])) and (p2.ship["upgrades"] as Array) == ups, "   his purse and ship are exactly as they were")
	_ok(int(car2.player["candy"]) == int(car.player["candy"]) and is_equal_approx(p2.grudge, plunge.grudge) and p2.memories.size() == plunge.memories.size(), "   your purse, his grudge and his memories too")
	_ok(int(p2.record["poker_net"]) == -100, "   and his record at the table (-100)")


func _grudge() -> void:
	print("GRUDGE")
	var car := _career()
	var duck := car.captain("quackworth")
	var base_style := duck.battle_style()
	# Sink him in a battle.
	var b := TubBattle.new()
	b.setup(car.player["ship"], int(car.player["candy"]), [duck], 4)
	var foe := b.ships[1]
	foe.pos = b.player.pos + Vector2(200, 0)
	foe.ai["cool"] = 99.0
	foe.ai["charge_cool"] = 99.0
	foe.ai["squeak"] = 99.0
	foe.style["retreat_at"] = 0.0
	foe.hull = 15.0
	b.player_fire()
	for _i in 60:
		b.step(1.0 / 60.0)
	b.over = true
	b.result = "victory"
	car.settle(b)
	_ok(duck.grudge > 25.0 and duck.attitude() in ["resentful", "furious"], "sunk by you, the Admiral holds a grudge (%.0f, %s)" % [duck.grudge, duck.attitude()])
	_ok(duck.memories.size() == 1 and String(duck.memories[0]["text"]).contains("Sunk by your submarine"), "and remembers why: " + String(duck.memories[0]["text"]))
	_ok(duck.battle_style()["aggression"] > base_style["aggression"], "it makes him fight harder (aggression %.2f -> %.2f)" % [base_style["aggression"], duck.battle_style()["aggression"]])
	var b2 := TubBattle.new()
	b2.setup(car.player["ship"], 100, [duck], 6)
	var says := b2.take_events().filter(func(e: Dictionary) -> bool: return String(e["type"]) == "say")
	_ok(not says.is_empty() and String(says[0]["key"]) == "grudge", "next time he opens with a grudge line")
	_ok(float((b2.relations["quackworth"] as Dictionary)["player"]) == duck.grudge, "and his grudge steers whom he hunts")
	# A furious captain seeks you out more often.
	var counts := {"with": 0, "without": 0}
	for trial in ["without", "with"]:
		var c2 := _career()
		c2.captain("inkwell").grudge = 100.0 if trial == "with" else 0.0
		for n in 300:
			c2.battle_no = n
			c2.last_opponents = []
			if c2.pick_opponents().any(func(c: TubCaptain) -> bool: return c.id == "inkwell"):
				counts[trial] = int(counts[trial]) + 1
	_ok(int(counts["with"]) > int(counts["without"]) + 20, "a furious captain turns up more often (%d vs %d of 300 battles)" % [int(counts["with"]), int(counts["without"])])
	# Repeated defeats teach caution.
	var moss := car.captain("moss")
	var c0 := float(moss.battle_style()["caution"])
	moss.record["times_sunk"] = 3
	_ok(float(moss.battle_style()["caution"]) > c0, "sunk three times, Mossy gets warier (caution %.2f -> %.2f)" % [c0, float(moss.battle_style()["caution"])])
	# Help is remembered.
	var ink := car.captain("inkwell")
	var b3 := TubBattle.new()
	b3.setup(car.player["ship"], 100, [ink], 2)
	b3.helped.append("inkwell")
	b3.over = true
	b3.result = "draw"
	car.settle(b3)
	_ok(ink.grudge < 0.0 and ink.memories.any(func(m: Dictionary) -> bool: return String(m["kind"]) == "helped"), "saved from an attacker, the Professor softens (%.0f)" % ink.grudge)
	# A bad night at cards.
	var hot := car.captain("soapbeard")
	var calm := car.captain("moss")
	var hot0: Dictionary = hot.poker_temper()
	var calm0: Dictionary = calm.poker_temper()
	car.settle_poker({"player": 70, "soapbeard": -40, "moss": -30})
	_ok(hot.tilt > 0.0 and float(hot.poker_temper()["aggro"]) > float(hot0["aggro"]), "the pirate loses 40 and gets reckless (aggro %.2f -> %.2f)" % [float(hot0["aggro"]), float(hot.poker_temper()["aggro"])])
	_ok(calm.tilt < 0.0 and float(calm.poker_temper()["tight"]) > float(calm0["tight"]), "Mossy loses 30 and gets shaken (tight %.2f -> %.2f)" % [float(calm0["tight"]), float(calm.poker_temper()["tight"])])
	_ok(hot.grudge > 0.0 and hot.memories.any(func(m: Dictionary) -> bool: return String(m["kind"]) == "poker_loss"), "losing to you at cards becomes a grudge too")
