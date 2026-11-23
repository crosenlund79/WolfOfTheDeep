class_name TubPokerSession
extends RefCounted
## A night at the Captains' Poker Club with real candy. Each player brings
## what they own (up to the table's cap); nobody can bet candy they do not
## have; after every hand each purse is the candy left at home plus what is
## on the table, written straight back to the career. A player whose stack
## is gone is out for the night.

const STAKES := [
	{"name": "Penny Table", "sb": 1, "bb": 2, "min": 10, "max": 80},
	{"name": "Bubble Table", "sb": 2, "bb": 4, "min": 30, "max": 160},
	{"name": "High Tide Table", "sb": 5, "bb": 10, "min": 80, "max": 400},
]

var career: TubCareer
var stake := {}
var game := PokerGame.new()
var seats: Array[Dictionary] = []   # {id, outside, start}  (player first)
var hands := 0
var _rng := RandomNumberGenerator.new()


## Who would sit at this table, and who will not (and why).
static func seating(car: TubCareer, st: Dictionary) -> Dictionary:
	var sit: Array[TubCaptain] = []
	var away := {}
	var pool := car.roster()
	pool.sort_custom(func(a: TubCaptain, b: TubCaptain) -> bool:
		if absf(a.grudge - b.grudge) > 5.0:
			return a.grudge > b.grudge
		return a.candy > b.candy)
	for c in pool:
		if c.candy < int(st["min"]):
			away[c.id] = "can't afford a seat (%d candy)" % c.candy
			continue
		# The careful keep their repair money.
		var repairs := TubEconomy.full_repair_cost(c.ship)
		if c.trait_v("caution") >= 0.6 and c.candy - int(st["min"]) < c.reserve + repairs / 2:
			away[c.id] = "needs the candy for repairs"
			continue
		if sit.size() < 3:
			sit.append(c)
		else:
			away[c.id] = "no seat left tonight"
	return {"sit": sit, "away": away}


## Sit down. Returns "" or why the player cannot.
func start(car: TubCareer, st: Dictionary, seed_v: int = 0) -> String:
	career = car
	stake = st
	var pc := int(career.player["candy"])
	if pc < int(st["min"]):
		return "You need %d candy to sit at the %s." % [int(st["min"]), String(st["name"])]
	var who := seating(career, st)
	var sit: Array[TubCaptain] = who["sit"]
	if sit.is_empty():
		return "No captain can afford a seat at the %s tonight." % String(st["name"])
	game = PokerGame.new()
	game.small_blind = int(st["sb"])
	game.big_blind = int(st["bb"])
	game.unit = "candy"
	if seed_v != 0:
		game.rng.seed = seed_v
	else:
		game.rng.randomize()
	_rng.seed = game.rng.seed + 1
	var defs: Array = []
	var stack := mini(pc, int(st["max"]))
	defs.append({"id": "player", "name": "YOU", "stack": stack, "human": true})
	seats = [{"id": "player", "outside": pc - stack, "start": pc}]
	for c in sit:
		var s := mini(c.candy, int(st["max"]))
		defs.append({"id": c.id, "name": c.short, "stack": s, "temper": c.poker_temper()})
		seats.append({"id": c.id, "outside": c.candy - s, "start": c.candy})
	game.setup(defs)
	return ""


## After each hand: every purse is home candy plus table stack.
func sync() -> void:
	for i in seats.size():
		var bal := int(seats[i]["outside"]) + int(game.players[i]["stack"]) + int(game.players[i]["total"])
		var id := String(seats[i]["id"])
		if id == "player":
			career.player["candy"] = bal
		else:
			(career.captain(id) as TubCaptain).candy = bal


func balance(i: int) -> int:
	return int(seats[i]["outside"]) + int(game.players[i]["stack"]) + int(game.players[i]["total"])


## Next hand. False if fewer than two can play (or the player is out).
func deal() -> bool:
	sync()
	if int(game.players[0]["stack"]) <= 0:
		return false
	if not game.new_hand():
		return false
	hands += 1
	return true


## Net candy for each seat since sitting down.
func results() -> Dictionary:
	sync()
	var out := {}
	for i in seats.size():
		out[String(seats[i]["id"])] = balance(i) - int(seats[i]["start"])
	return out


## Stand up: abandon any hand in play (stakes return), record what it meant.
func finish() -> Array[String]:
	if not game.hand_over:
		game.abandon()
	var r := results()
	career.player["stats"]["hands"] = int(career.player["stats"]["hands"]) + hands
	return career.settle_poker(r)


func captain_at(i: int) -> TubCaptain:
	var id := String(seats[i]["id"])
	return null if id == "player" else career.captain(id)


## A line from the captain in seat i, now and then.
func quip(i: int, key: String, chance: float) -> String:
	var c := captain_at(i)
	if c == null or _rng.randf() > chance:
		return ""
	var t := c.line(key, _rng)
	return "" if t == "" else "%s: \"%s\"" % [c.short.capitalize(), t]
