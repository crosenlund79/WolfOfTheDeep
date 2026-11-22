extends SceneTree
## Practical check of the Hold'em engine (no framework):
##   godot --headless --path . -s tests/check_poker.gd
## Hand ranking on known hands, then many AI-only hands: sweets are conserved,
## every hand ends, nobody's stack goes negative.

var failures := 0


func _init() -> void:
	_rank_checks()
	_play_checks()
	print("POKER CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _c(text: String) -> int:
	var ranks := "23456789TJQKA"
	var suits := "shdc"
	return suits.find(text[1]) * 13 + ranks.find(text[0])


func _hand(cards: String) -> Array:
	var out: Array = []
	for t in cards.split(" "):
		out.append(_c(t))
	return out


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("  FAILED: ", what)


func _rank_checks() -> void:
	var e := func(s: String) -> int: return PokerGame.evaluate(_hand(s))
	var royal: int = e.call("As Ks Qs Js Ts 2d 3c")
	var quads: int = e.call("9s 9h 9d 9c Ks 2d 3c")
	var house: int = e.call("9s 9h 9d Kc Ks 2d 3c")
	var flush: int = e.call("2h 7h 9h Jh Kh 2d 3c")
	var straight: int = e.call("5s 6h 7d 8c 9s Kd 2c")
	var wheel: int = e.call("As 2h 3d 4c 5s Kd 9c")
	var trips: int = e.call("7s 7h 7d Kc 2s 4d 9c")
	var two_pair: int = e.call("7s 7h Kd Kc 2s 4d 9c")
	var pair: int = e.call("7s 7h Kd Qc 2s 4d 9c")
	var high: int = e.call("7s 3h Kd Qc 2s 4d 9c")
	var order := [high, pair, two_pair, trips, wheel, straight, flush, house, quads, royal]
	for i in order.size() - 1:
		_expect(int(order[i]) < int(order[i + 1]), "category order at %d" % i)
	_expect(PokerGame.hand_name(royal) == "a royal flush", "royal name: " + PokerGame.hand_name(royal))
	_expect(PokerGame.hand_name(wheel) == "a straight, five high", "wheel name: " + PokerGame.hand_name(wheel))
	_expect(PokerGame.hand_name(house) == "a full house, nines over kings", "house name: " + PokerGame.hand_name(house))
	# Kickers and splits.
	_expect(e.call("As Ah Kd 7c 5s 3d 2c") > e.call("Ac Ad Qd 7h 5h 3s 2d"), "pair kicker")
	_expect(e.call("As Kh Qd Jc 9s 3d 2c") == e.call("Ac Kd Qh Js 9d 3h 2s"), "identical high cards tie")
	_expect(e.call("Ks Kh 5d 5c 9s 9d 2c") == e.call("Kd Kc 9h 9c 5s 3d 2d"), "two pair uses the best two pairs")
	print("  rankings checked")


func _play_checks() -> void:
	var g := PokerGame.new()
	g.rng.seed = 12345
	g.setup([
		{"id": "a", "name": "A", "stack": 40, "temper": {"tight": 0.7, "aggro": 0.3, "bluff": 0.1}},
		{"id": "b", "name": "B", "stack": 25, "temper": {"tight": 0.3, "aggro": 0.8, "bluff": 0.4}},
		{"id": "c", "name": "C", "stack": 30, "temper": {"tight": 0.5, "aggro": 0.5, "bluff": 0.2}},
		{"id": "d", "name": "D", "stack": 12, "temper": {"tight": 0.4, "aggro": 0.7, "bluff": 0.35}},
	])
	var total := 40 + 25 + 30 + 12
	var hands := 0
	var showdowns := 0
	for _h in 150:
		if not g.new_hand():
			break
		hands += 1
		var guard := 0
		while not g.hand_over and guard < 400:
			guard += 1
			if g.current < 0:
				g.run_out()
				continue
			var d := g.decide()
			g.act(String(d[0]), int(d[1]))
		_expect(g.hand_over, "hand %d finished" % hands)
		if g.showdown:
			showdowns += 1
		var sum := 0
		for p in g.players:
			_expect(int(p["stack"]) >= 0, "non-negative stack")
			sum += int(p["stack"])
		_expect(sum == total, "sweets conserved after hand %d (%d != %d)" % [hands, sum, total])
		if sum != total:
			break
	print("  played %d hands, %d showdowns, stacks %s" % [hands, showdowns, g.players.map(func(p: Dictionary) -> int: return int(p["stack"]))])
	_expect(hands >= 5, "several hands played")
	# Abandon returns every stake.
	var g2 := PokerGame.new()
	g2.setup([{"id": "x", "name": "X", "stack": 20}, {"id": "y", "name": "Y", "stack": 20}])
	g2.new_hand()
	g2.abandon()
	_expect(int(g2.players[0]["stack"]) + int(g2.players[1]["stack"]) == 40, "abandon returns stakes")
