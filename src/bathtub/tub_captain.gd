class_name TubCaptain
extends RefCounted
## One rival captain: who they are, their purse, their ship as it stands, and
## what they remember of the player (GRUDGE). Everything here persists from
## battle to battle and through the poker club; nothing is reset or topped up.

var id := ""
var name := ""
var short := ""
var kind := "patrol"
var vessel := ""
var livery := Color.WHITE
var candy := 0
var reserve := 0                    # candy they like to keep in hand
var traits := {}                    # aggression, caution, temper, greed
var poker := {}                     # tight, aggro, bluff
var prefs: Array = []               # upgrades they want, in order
var ship := {}                      # kind, hull, max_hull, comp, upgrades
var grudge := 0.0                   # toward the player: -100 grateful .. +100 furious
var respect := 0.0                  # 0 .. 100
var relations := {}                 # other captain id -> grudge
var tilt := 0.0                     # after the cards: -1 shaken .. +1 reckless
var memories: Array = []            # [{battle, kind, text}]
var record := {"battles": 0, "sunk_by_player": 0, "sank_player": 0, "times_sunk": 0, "poker_net": 0, "hits_on_player": 0, "hits_from_player": 0}


static func new_ship(kind_v: String) -> Dictionary:
	var k: Dictionary = TubData.KINDS[kind_v]
	var comp := {}
	for c in TubData.COMPONENTS:
		comp[c] = 1.0
	return {"kind": kind_v, "hull": float(k["hull"]), "max_hull": int(k["hull"]), "comp": comp, "upgrades": []}


static func from_roster(id_v: String) -> TubCaptain:
	var r: Dictionary = TubData.ROSTER[id_v]
	var c := TubCaptain.new()
	c.id = id_v
	c.name = String(r["name"])
	c.short = String(r["short"])
	c.kind = String(r["kind"])
	c.vessel = String(r["vessel"])
	c.livery = r["livery"]
	c.candy = int(r["candy"])
	c.reserve = int(r["reserve"])
	c.traits = (r["traits"] as Dictionary).duplicate()
	c.poker = (r["poker"] as Dictionary).duplicate()
	c.prefs = (r["prefs"] as Array).duplicate()
	c.ship = new_ship(c.kind)
	return c


func trait_v(k: String) -> float:
	return float(traits.get(k, 0.5))


## Something happened between this captain and the player.
func remember(kind_v: String, text: String, d_grudge: float, d_respect: float, battle: int = 0) -> void:
	grudge = clampf(grudge + d_grudge * (0.5 + trait_v("temper")), -100.0, 100.0)
	respect = clampf(respect + d_respect, 0.0, 100.0)
	memories.append({"battle": battle, "kind": kind_v, "text": text})
	if memories.size() > 24:
		memories.pop_front()


func attitude() -> String:
	if grudge >= 60.0:
		return "furious"
	if grudge >= 25.0:
		return "resentful"
	if grudge <= -30.0:
		return "friendly"
	if respect >= 50.0:
		return "respectful"
	if respect >= 20.0 or grudge >= 10.0:
		return "wary"
	return "indifferent"


## How they fight next time, grown from what has happened.
func battle_style() -> Dictionary:
	var aggression := trait_v("aggression")
	var caution := trait_v("caution")
	# A grudge makes them push; how much depends on their temper.
	aggression += maxf(grudge, 0.0) / 200.0 * trait_v("temper")
	# Being sunk again and again teaches caution (unless the temper wins).
	var lessons := mini(int(record["times_sunk"]), 3)
	caution += 0.1 * float(lessons) * (1.0 - trait_v("temper") * 0.5)
	# Respect makes them careful around the player.
	caution += respect / 400.0
	# A badly damaged ship is sailed carefully.
	var hull_frac := float(ship["hull"]) / maxf(float(ship["max_hull"]), 1.0)
	if hull_frac < 0.6:
		caution += 0.15
	aggression = clampf(aggression, 0.05, 1.0)
	caution = clampf(caution, 0.0, 1.0)
	return {"aggression": aggression, "caution": caution, "retreat_at": 0.12 + 0.33 * caution}


## Their poker temperament tonight: the base style, bent by tilt and grudge.
func poker_temper() -> Dictionary:
	var t := poker.duplicate()
	var tight := float(t["tight"])
	var aggro := float(t["aggro"])
	var bluff := float(t["bluff"])
	if tilt > 0.0:
		aggro += 0.3 * tilt
		bluff += 0.25 * tilt
		tight -= 0.25 * tilt
	elif tilt < 0.0:
		tight += 0.3 * -tilt
		aggro -= 0.2 * -tilt
	var g := maxf(grudge, 0.0) / 100.0 * trait_v("temper")
	aggro += 0.2 * g
	bluff += 0.15 * g
	return {"tight": clampf(tight, 0.05, 0.95), "aggro": clampf(aggro, 0.05, 0.95), "bluff": clampf(bluff, 0.0, 0.8)}


func line(key: String, rng: RandomNumberGenerator) -> String:
	var all: Dictionary = TubData.LINES.get(id, {})
	var pool: Array = all.get(key, [])
	if pool.is_empty():
		return ""
	return String(pool[rng.randi() % pool.size()])


func to_dict() -> Dictionary:
	return {"id": id, "candy": candy, "ship": ship.duplicate(true), "grudge": grudge, "respect": respect,
		"relations": relations.duplicate(), "tilt": tilt, "memories": memories.duplicate(true), "record": record.duplicate(),
		"traits": traits.duplicate(), "prefs": prefs.duplicate()}


static func from_dict(d: Dictionary) -> TubCaptain:
	var c := from_roster(String(d["id"]))
	c.candy = int(d.get("candy", c.candy))
	var s: Variant = d.get("ship")
	if s is Dictionary:
		c.ship = (s as Dictionary).duplicate(true)
		c.ship["hull"] = float(c.ship["hull"])
		c.ship["max_hull"] = int(c.ship["max_hull"])
	c.grudge = float(d.get("grudge", 0.0))
	c.respect = float(d.get("respect", 0.0))
	var rel: Variant = d.get("relations")
	if rel is Dictionary:
		c.relations = (rel as Dictionary).duplicate()
	c.tilt = float(d.get("tilt", 0.0))
	var mem: Variant = d.get("memories")
	if mem is Array:
		c.memories = (mem as Array).duplicate(true)
	var rec: Variant = d.get("record")
	if rec is Dictionary:
		for k in (rec as Dictionary).keys():
			c.record[k] = int((rec as Dictionary)[k])
	var tr: Variant = d.get("traits")
	if tr is Dictionary:
		c.traits = (tr as Dictionary).duplicate()
	var pr: Variant = d.get("prefs")
	if pr is Array:
		c.prefs = (pr as Array).duplicate()
	return c
