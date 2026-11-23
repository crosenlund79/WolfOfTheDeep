class_name PokerGame
extends RefCounted
## Texas Hold'em for sweets (one sweet = one unit). Real deck, blinds, betting
## rounds, all-ins with side pots, showdown with a 7-card evaluator, and AI
## players whose play follows their temperament (tight / aggressive / bluff).
## No UI here: the table calls step()/act() and shows the returned text.

const RANKS := ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_WORDS := ["", "", "twos", "threes", "fours", "fives", "sixes", "sevens", "eights", "nines", "tens", "jacks", "queens", "kings", "aces"]
const RANK_WORD := ["", "", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "jack", "queen", "king", "ace"]
const CATEGORY := ["high card", "pair", "two pair", "three of a kind", "straight", "flush", "full house", "four of a kind", "straight flush"]
const SMALL_BLIND := 1
const BIG_BLIND := 2

var players: Array[Dictionary] = []
var dealer := -1
var board: Array[int] = []
var deck: Array[int] = []
var street := 0           # 0 preflop, 1 flop, 2 turn, 3 river
var current := -1
var cur_bet := 0
var min_raise := 2
var hand_over := true
var hand_number := 0
var result_text := ""
var winners: Array[int] = []
var showdown := false
var rng := RandomNumberGenerator.new()
var small_blind := SMALL_BLIND      # per table (the Bathtub club has several stakes)
var big_blind := BIG_BLIND
var unit := "sweets"


## defs: [{id, name, stack, human, temper}]
func setup(defs: Array) -> void:
	players.clear()
	for d in defs:
		players.append({"id": d["id"], "name": d["name"], "stack": int(d["stack"]), "start": int(d["stack"]),
			"human": bool(d.get("human", false)), "temper": d.get("temper", {"tight": 0.5, "aggro": 0.5, "bluff": 0.2}),
			"hole": [], "folded": true, "allin": false, "bet": 0, "total": 0, "acted": false, "out": false, "last": ""})
	dealer = rng.randi() % maxi(players.size(), 1)


func seated() -> Array[int]:
	var out: Array[int] = []
	for i in players.size():
		if not players[i]["out"] and int(players[i]["stack"]) > 0:
			out.append(i)
	return out


func pot() -> int:
	var s := 0
	for p in players:
		s += int(p["total"])
	return s


func new_hand() -> bool:
	for p in players:
		p["hole"] = []
		p["folded"] = true
		p["allin"] = false
		p["bet"] = 0
		p["total"] = 0
		p["acted"] = false
		p["last"] = ""
	var live := seated()
	if live.size() < 2:
		hand_over = true
		return false
	hand_number += 1
	hand_over = false
	showdown = false
	winners.clear()
	result_text = ""
	board.clear()
	deck.clear()
	for c in 52:
		deck.append(c)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := deck[i]
		deck[i] = deck[j]
		deck[j] = t
	for i in live:
		players[i]["folded"] = false
	dealer = _next_from(dealer, live)
	var sb := dealer if live.size() == 2 else _next_from(dealer, live)
	var bb := _next_from(sb, live)
	for _round in 2:
		for i in live:
			(players[i]["hole"] as Array).append(deck.pop_back())
	street = 0
	cur_bet = 0
	min_raise = big_blind
	_post(sb, small_blind, "small blind")
	_post(bb, big_blind, "big blind")
	cur_bet = big_blind
	current = _next_actor(bb)
	return true


func _next_from(i: int, live: Array[int]) -> int:
	for k in range(1, players.size() + 1):
		var j := (i + k) % players.size()
		if j in live:
			return j
	return i


func _post(i: int, amount: int, what: String) -> void:
	var p := players[i]
	var a := mini(amount, int(p["stack"]))
	p["stack"] = int(p["stack"]) - a
	p["bet"] = int(p["bet"]) + a
	p["total"] = int(p["total"]) + a
	if int(p["stack"]) == 0:
		p["allin"] = true
	p["last"] = "%s %d" % [what, a]


func _can_act(i: int) -> bool:
	var p := players[i]
	return not p["folded"] and not p["allin"] and not p["out"]


func _next_actor(from: int) -> int:
	for k in range(1, players.size() + 1):
		var j := (from + k) % players.size()
		if _can_act(j):
			return j
	return -1


func _in_hand() -> Array[int]:
	var out: Array[int] = []
	for i in players.size():
		if not players[i]["folded"] and not players[i]["out"]:
			out.append(i)
	return out


func to_call(i: int) -> int:
	return mini(cur_bet - int(players[i]["bet"]), int(players[i]["stack"]))


## The smallest legal raise target (total bet this street).
func min_raise_to(i: int) -> int:
	return mini(cur_bet + min_raise, int(players[i]["bet"]) + int(players[i]["stack"]))


func max_to(i: int) -> int:
	return int(players[i]["bet"]) + int(players[i]["stack"])


## kind: fold, check, call, raise (amount_to = new total bet this street).
func act(kind: String, amount_to: int = 0) -> String:
	if hand_over or current < 0:
		return ""
	var i := current
	var p := players[i]
	var n := String(p["name"])
	var text := ""
	var owe := to_call(i)
	if kind == "check" and owe > 0:
		kind = "call"
	if kind == "call" and owe == 0:
		kind = "check"
	match kind:
		"fold":
			p["folded"] = true
			text = "%s folds." % n
			p["last"] = "fold"
		"check":
			text = "%s checks." % n
			p["last"] = "check"
		"call":
			_put(i, owe)
			text = "%s calls %d%s." % [n, owe, " and is all in" if p["allin"] else ""]
			p["last"] = "call %d" % owe
		"raise":
			var target := clampi(amount_to, mini(min_raise_to(i), max_to(i)), max_to(i))
			var add := target - int(p["bet"])
			var raise_by := target - cur_bet
			_put(i, add)
			if raise_by > 0:
				if raise_by >= min_raise:
					min_raise = raise_by
				var opened := cur_bet == 0
				cur_bet = target
				for j in players.size():
					if j != i and _can_act(j):
						players[j]["acted"] = false
				text = "%s %s %d%s." % [n, "bets" if opened else "raises to", target, ", all in" if p["allin"] else ""]
				p["last"] = ("bet %d" if opened else "raise %d") % target
			else:
				text = "%s calls %d and is all in." % [n, add]
				p["last"] = "call %d" % add
	p["acted"] = true
	return text + _advance()


func _put(i: int, amount: int) -> void:
	var p := players[i]
	var a := mini(amount, int(p["stack"]))
	p["stack"] = int(p["stack"]) - a
	p["bet"] = int(p["bet"]) + a
	p["total"] = int(p["total"]) + a
	if int(p["stack"]) == 0:
		p["allin"] = true


func _advance() -> String:
	var live := _in_hand()
	if live.size() == 1:
		return _award_uncontested(live[0])
	var round_done := true
	for j in players.size():
		if _can_act(j) and (not players[j]["acted"] or int(players[j]["bet"]) != cur_bet):
			round_done = false
	if not round_done:
		current = _next_actor(current)
		if current >= 0:
			return ""
	# Next street (or run the board out when nobody can bet any more).
	var extra := ""
	while true:
		if street == 3:
			return extra + _showdown()
		for p in players:
			p["bet"] = 0
			p["acted"] = false
		cur_bet = 0
		min_raise = big_blind
		street += 1
		var deal := 3 if street == 1 else 1
		for _k in deal:
			board.append(deck.pop_back())
		extra += "\n%s: %s" % [["", "FLOP", "TURN", "RIVER"][street], " ".join(board.map(card_text))]
		var actors := 0
		for j in players.size():
			if _can_act(j):
				actors += 1
		if actors >= 2:
			current = _next_actor(dealer)
			return extra
	return extra


func _award_uncontested(w: int) -> String:
	var total := pot()
	players[w]["stack"] = int(players[w]["stack"]) + total
	winners = [w]
	hand_over = true
	current = -1
	result_text = "%s takes the pot of %d %s." % [players[w]["name"], total, unit]
	_clear_bets()
	return "\n" + result_text


func _clear_bets() -> void:
	for p in players:
		p["bet"] = 0
		p["total"] = 0


func _showdown() -> String:
	showdown = true
	hand_over = true
	current = -1
	var live := _in_hand()
	var scores := {}
	for i in live:
		var cards: Array = (players[i]["hole"] as Array) + board
		scores[i] = evaluate(cards)
	# Side pots, level by level.
	var levels: Array[int] = []
	for p in players:
		var t := int(p["total"])
		if t > 0 and not levels.has(t):
			levels.append(t)
	levels.sort()
	var prev := 0
	var won := {}
	for level in levels:
		var amount := 0
		for p in players:
			amount += mini(int(p["total"]), level) - mini(int(p["total"]), prev)
		var eligible: Array[int] = []
		for i in live:
			if int(players[i]["total"]) >= level:
				eligible.append(i)
		if eligible.is_empty():
			eligible = live
		var best := -1
		for i in eligible:
			best = maxi(best, int(scores[i]))
		var split: Array[int] = []
		for i in eligible:
			if int(scores[i]) == best:
				split.append(i)
		var share := amount / split.size()
		var rem := amount - share * split.size()
		for k in split.size():
			var i2 := split[k]
			won[i2] = int(won.get(i2, 0)) + share + (rem if k == 0 else 0)
		prev = level
	var lines: Array[String] = []
	for i in live:
		lines.append("%s shows %s  -  %s" % [players[i]["name"], " ".join((players[i]["hole"] as Array).map(card_text)), hand_name(int(scores[i]))])
	for i in won:
		players[i]["stack"] = int(players[i]["stack"]) + int(won[i])
		winners.append(i)
		lines.append("%s wins %d %s." % [players[i]["name"], int(won[i]), unit])
	result_text = "\n".join(lines)
	_clear_bets()
	return "\n" + result_text


## Nobody left who can bet: deal out the remaining board and settle.
func run_out() -> String:
	if hand_over or current >= 0:
		return ""
	return _advance()


## Emergency: abandon the hand and give everyone their sweets back.
func abandon() -> void:
	if hand_over:
		return
	for p in players:
		p["stack"] = int(p["stack"]) + int(p["total"])
	_clear_bets()
	hand_over = true
	current = -1
	result_text = "Hand abandoned. Everyone takes their %s back." % unit


# --- AI -----------------------------------------------------------------------

## Let the AI player to act decide. Returns [kind, amount_to].
func decide() -> Array:
	var i := current
	var p := players[i]
	var tp: Dictionary = p["temper"]
	var tight := float(tp.get("tight", 0.5))
	var aggro := float(tp.get("aggro", 0.5))
	var bluff := float(tp.get("bluff", 0.2))
	var opp := _in_hand().size() - 1
	var e := equity(p["hole"], board, opp, 140 if street == 0 else 220)
	var rel := e * float(opp + 1)
	var owe := to_call(i)
	var total := pot()
	var r := rng.randf()
	var raise_to := func(frac: float) -> int:
		return clampi(cur_bet + maxi(min_raise, int(round(total * frac))), min_raise_to(i), max_to(i))
	if owe == 0:
		var strong: bool = (rel > 1.55 - aggro * 0.45) if street == 0 else (e > 0.66 - aggro * 0.18)
		if strong and r < 0.55 + aggro * 0.4:
			return ["raise", raise_to.call(lerpf(0.4, 0.9, rng.randf() * aggro + 0.2))]
		if street > 0 and r < bluff * 0.4:
			return ["raise", raise_to.call(0.5)]
		return ["check", 0]
	var odds := float(owe) / float(total + owe)
	if street == 0:
		if rel > (1.7 - aggro * 0.5) and r < 0.3 + aggro * 0.6:
			return ["raise", raise_to.call(0.8 + aggro * 0.6)]
		var cheap := owe <= big_blind and r < 0.75 - tight * 0.5
		if rel > 0.8 + tight * 0.45 or cheap:
			return ["call", 0]
		if r < bluff * 0.15:
			return ["call", 0]
		return ["fold", 0]
	if e > 0.74 - aggro * 0.12 and r < 0.35 + aggro * 0.5:
		return ["raise", raise_to.call(0.7)]
	if e > odds - 0.04 + tight * 0.1:
		return ["call", 0]
	if street < 3 and r < bluff * 0.22:
		return ["raise", raise_to.call(0.75)]
	if owe <= 1 and r < 0.6:
		return ["call", 0]
	return ["fold", 0]


## Monte-Carlo equity of a hand against `opp` random hands.
func equity(hole: Array, known_board: Array, opp: int, iters: int) -> float:
	if opp <= 0:
		return 1.0
	var used := {}
	for c in hole + known_board:
		used[c] = true
	var rest: Array[int] = []
	for c in 52:
		if not used.has(c):
			rest.append(c)
	var need := 5 - known_board.size()
	var score := 0.0
	for _it in iters:
		# Partial Fisher-Yates for the cards we need.
		var take := need + opp * 2
		for k in take:
			var j := rng.randi_range(k, rest.size() - 1)
			var t := rest[k]
			rest[k] = rest[j]
			rest[j] = t
		var b: Array = known_board.duplicate()
		for k in need:
			b.append(rest[k])
		var mine := evaluate(hole + b)
		var best_opp := -1
		var ties := 0
		for o in opp:
			var s := evaluate([rest[need + o * 2], rest[need + o * 2 + 1]] + b)
			if s > best_opp:
				best_opp = s
		if mine > best_opp:
			score += 1.0
		elif mine == best_opp:
			ties += 1
			score += 0.5
	return score / float(iters)


# --- evaluation --------------------------------------------------------------

static func card_rank(c: int) -> int:
	return c % 13 + 2


static func card_suit(c: int) -> int:
	return c / 13


static func card_text(c: int) -> String:
	return RANKS[card_rank(c)] + ["s", "h", "d", "c"][card_suit(c)]


static func _score(cat: int, ranks: Array) -> int:
	var s := cat
	for k in 5:
		s = s * 15 + (int(ranks[k]) if k < ranks.size() else 0)
	return s


static func _straight_high(bits: int) -> int:
	if bits & (1 << 14):
		bits |= 1 << 1
	for h in range(14, 4, -1):
		var m := 0b11111 << (h - 4)
		if bits & m == m:
			return h
	return 0


static func _top(bits: int, n: int, exclude: Array = []) -> Array:
	var out: Array = []
	for r in range(14, 1, -1):
		if bits & (1 << r) and not exclude.has(r):
			out.append(r)
			if out.size() == n:
				break
	return out


## Score of the best five-card hand among 5–7 cards (higher is better).
static func evaluate(cards: Array) -> int:
	var cnt := PackedInt32Array()
	cnt.resize(15)
	var suit_cnt := [0, 0, 0, 0]
	var suit_bits := [0, 0, 0, 0]
	var bits := 0
	for c in cards:
		var r := int(c) % 13 + 2
		var s := int(c) / 13
		cnt[r] += 1
		suit_cnt[s] += 1
		suit_bits[s] |= 1 << r
		bits |= 1 << r
	var flush_suit := -1
	for s in 4:
		if suit_cnt[s] >= 5:
			flush_suit = s
			var sh := _straight_high(suit_bits[s])
			if sh > 0:
				return _score(8, [sh])
	var quads: Array = []
	var trips: Array = []
	var pairs: Array = []
	for r in range(14, 1, -1):
		match cnt[r]:
			4:
				quads.append(r)
			3:
				trips.append(r)
			2:
				pairs.append(r)
	if not quads.is_empty():
		return _score(7, [quads[0]] + _top(bits, 1, [quads[0]]))
	if not trips.is_empty() and (trips.size() >= 2 or not pairs.is_empty()):
		var second := 0
		if trips.size() >= 2:
			second = trips[1]
		if not pairs.is_empty():
			second = maxi(second, pairs[0])
		return _score(6, [trips[0], second])
	if flush_suit >= 0:
		return _score(5, _top(suit_bits[flush_suit], 5))
	var st := _straight_high(bits)
	if st > 0:
		return _score(4, [st])
	if not trips.is_empty():
		return _score(3, [trips[0]] + _top(bits, 2, [trips[0]]))
	if pairs.size() >= 2:
		return _score(2, [pairs[0], pairs[1]] + _top(bits, 1, [pairs[0], pairs[1]]))
	if pairs.size() == 1:
		return _score(1, [pairs[0]] + _top(bits, 3, [pairs[0]]))
	return _score(0, _top(bits, 5))


static func hand_name(score: int) -> String:
	var cat := score / (15 * 15 * 15 * 15 * 15)
	var r1 := (score / (15 * 15 * 15 * 15)) % 15
	var r2 := (score / (15 * 15 * 15)) % 15
	match cat:
		0:
			return "%s high" % RANK_WORD[r1]
		1:
			return "a pair of %s" % RANK_WORDS[r1]
		2:
			return "two pair, %s and %s" % [RANK_WORDS[r1], RANK_WORDS[r2]]
		3:
			return "three %s" % RANK_WORDS[r1]
		4:
			return "a straight, %s high" % RANK_WORD[r1]
		5:
			return "a flush, %s high" % RANK_WORD[r1]
		6:
			return "a full house, %s over %s" % [RANK_WORDS[r1], RANK_WORDS[r2]]
		7:
			return "four %s" % RANK_WORDS[r1]
		8:
			return "a royal flush" if r1 == 14 else "a straight flush, %s high" % RANK_WORD[r1]
	return CATEGORY[clampi(cat, 0, 8)]
