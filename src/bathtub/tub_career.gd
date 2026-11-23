class_name TubCareer
extends RefCounted
## The persistent Bathtub Edition: the player's purse and submarine, every
## rival captain's purse, ship, upgrades and GRUDGE, the battle count and a
## chronicle of what happened. Battle -> (poker) -> repairs and upgrades ->
## next battle. Saved under user://bathtub/, apart from any other game.

const SAVE_DIR := "user://bathtub/"
const SAVE_FILE := "career.json"
const PREBATTLE_FILE := "prebattle.json"
const VERSION := 1

var player := {}                    # candy, ship, stats
var captains := {}                  # id -> TubCaptain
var battle_no := 0
var chronicle: Array = []           # [{battle, text}]
var seed := 1
var refit_due := false              # rivals refit before the next battle
var last_opponents: Array = []
var save_dir := SAVE_DIR            # tests point this elsewhere


func new_game(seed_v: int = 0) -> void:
	seed = seed_v if seed_v != 0 else int(Time.get_unix_time_from_system()) % 100000 + 1
	player = {"candy": TubData.START_CANDY, "ship": TubCaptain.new_ship("sub"),
		"stats": {"battles": 0, "wins": 0, "sinks": 0, "sunk": 0, "poker_net": 0, "hands": 0}}
	captains.clear()
	for id in TubData.ROSTER_ORDER:
		captains[id] = TubCaptain.from_roster(id)
	battle_no = 0
	chronicle.clear()
	refit_due = false
	last_opponents.clear()
	note("A new bath is drawn. Five rival captains are waiting.")


func note(text: String) -> void:
	chronicle.append({"battle": battle_no, "text": text})
	if chronicle.size() > 80:
		chronicle.pop_front()


func captain(id: String) -> TubCaptain:
	return captains.get(id)


func roster() -> Array[TubCaptain]:
	var out: Array[TubCaptain] = []
	for id in TubData.ROSTER_ORDER:
		out.append(captains[id])
	return out


## Who comes to the next battle: grudges bring captains looking for you, and
## the cast rotates so everyone turns up.
func pick_opponents() -> Array[TubCaptain]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + battle_no
	var n := 2 if battle_no < 2 else 3
	var pool := roster()
	var picked: Array[TubCaptain] = []
	while picked.size() < n and not pool.is_empty():
		var weights: Array[float] = []
		var total := 0.0
		for c in pool:
			var w := 1.0 + maxf(c.grudge, 0.0) / 30.0 + (0.0 if last_opponents.has(c.id) else 0.8)
			weights.append(w)
			total += w
		var r := rng.randf() * total
		var idx := 0
		for i in weights.size():
			r -= weights[i]
			if r <= 0.0:
				idx = i
				break
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked


## Between battles the rivals spend their own candy on their own boats.
func rivals_refit() -> Array[String]:
	var out: Array[String] = []
	for c in roster():
		out.append_array(TubEconomy.plan_rival(c))
	refit_due = false
	for t in out:
		note(t)
	return out


## The next battle: rivals refit first (after any poker), the player's sub is
## patched if it is in no state to sail, then the opponents are chosen.
func start_battle() -> TubBattle:
	if refit_due:
		rivals_refit()
	var ship: Dictionary = player["ship"]
	if TubEconomy.harbour_patch(ship):
		note("Your submarine was patched up for free at the harbour, just enough to float.")
	save(PREBATTLE_FILE)
	var opp := pick_opponents()
	last_opponents = opp.map(func(c: TubCaptain) -> String: return c.id)
	var b := TubBattle.new()
	b.setup(ship, int(player["candy"]), opp, seed * 1000 + battle_no * 17 + 3)
	return b


## After a battle: candy, ship damage, records and grudges. Returns a report.
func settle(b: TubBattle) -> Dictionary:
	var earn := b.earnings()
	var lines: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + battle_no * 31
	var stats: Dictionary = player["stats"]
	stats["battles"] = int(stats["battles"]) + 1
	for s in b.ships:
		var e: Dictionary = earn[s.id]
		var state := s.state_dict()
		if s.is_player:
			player["ship"] = state
			player["candy"] = maxi(int(player["candy"]) + int(e["total"]), 0)
			stats["sinks"] = int(stats["sinks"]) + s.sinks
			if b.result == "victory":
				stats["wins"] = int(stats["wins"]) + 1
			if s.state == "sunk":
				stats["sunk"] = int(stats["sunk"]) + 1
			continue
		var c: TubCaptain = captains[s.id]
		c.ship = state
		c.candy = maxi(c.candy + int(e["total"]), 0)
		c.record["battles"] = int(c.record["battles"]) + 1
		var by_player := float(b.dmg_by.get("player>" + s.id, 0.0))
		var on_player := float(b.dmg_by.get(s.id + ">player", 0.0))
		c.record["hits_from_player"] = int(c.record["hits_from_player"]) + int(by_player)
		c.record["hits_on_player"] = int(c.record["hits_on_player"]) + int(on_player)
		var sinker := String(b.sunk_by.get(s.id, ""))
		if s.state == "sunk":
			c.record["times_sunk"] = int(c.record["times_sunk"]) + 1
		if sinker == "player":
			c.record["sunk_by_player"] = int(c.record["sunk_by_player"]) + 1
			var again := int(c.record["sunk_by_player"]) >= 2
			c.remember("sunk", "Sunk by your submarine in battle %d." % (battle_no + 1), 30.0, 12.0 if again else 6.0, battle_no + 1)
			lines.append("%s was sunk by you%s." % [c.short.capitalize(), " - again" if again else ""])
		elif by_player > 0.0:
			c.remember("attacked", "Took %d damage from your torpedoes in battle %d." % [int(by_player), battle_no + 1], by_player / 5.0, 3.0, battle_no + 1)
		if String(b.sunk_by.get("player", "")) == s.id:
			c.record["sank_player"] = int(c.record["sank_player"]) + 1
			c.remember("sank_player", "Sank your submarine in battle %d." % (battle_no + 1), -15.0, 0.0, battle_no + 1)
			lines.append("%s sank you and will not let you forget it." % c.short.capitalize())
		if b.helped.has(s.id):
			c.remember("helped", "You sank the ship that was attacking them in battle %d." % (battle_no + 1), -25.0, 10.0, battle_no + 1)
			lines.append("%s noticed you sank their attacker. They owe you one." % c.short.capitalize())
		if s.state == "retreated":
			lines.append("%s retreated, lifted out of the bath." % c.short.capitalize())
		# Rivals remember each other too.
		for o in b.ships:
			if o == s or o.is_player:
				continue
			var d := float(b.dmg_by.get(o.id + ">" + s.id, 0.0))
			if d > 0.0:
				c.relations[o.id] = clampf(float(c.relations.get(o.id, 0.0)) + d / 4.0, -100.0, 100.0)
	var mine: Dictionary = earn["player"]
	lines.push_front("You earned %d candy: hits %d, sinkings %d, candy from the water %d, %s %d%s." % [int(mine["total"]),
		int(mine["hits"]), int(mine["sinks"]), int(mine["candy_water"]), "safe return" if int(mine["survive"]) > 0 else "salvage",
		int(mine["survive"]) + int(mine["salvage"]), (", victory %d" % int(mine["victory"])) if int(mine["victory"]) > 0 else ""])
	battle_no += 1
	refit_due = true
	note("Battle %d: %s. %s" % [battle_no, {"victory": "victory", "defeat": "you were sunk", "withdrew": "you withdrew", "draw": "the bath went cold"}[b.result], lines[0]])
	for l in lines.slice(1):
		note(l)
	return {"result": b.result, "earnings": earn, "lines": lines}


## The poker club's outcome: real candy has already moved; this records what
## it meant. results: id -> net candy (player included).
func settle_poker(results: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var pnet := int(results.get("player", 0))
	var stats: Dictionary = player["stats"]
	stats["poker_net"] = int(stats["poker_net"]) + pnet
	for id in results.keys():
		if id == "player":
			continue
		var c: TubCaptain = captains[id]
		var net := int(results[id])
		c.record["poker_net"] = int(c.record["poker_net"]) + net
		if net <= -20:
			# A bad night: hot-headed captains get reckless, careful ones shaken.
			c.tilt = clampf(c.tilt + (0.5 if c.trait_v("temper") >= 0.6 else -0.5), -1.0, 1.0)
			if pnet > 0:
				c.remember("poker_loss", "Lost %d candy at the table while you won %d." % [-net, pnet], absf(float(net)) / 3.0, 2.0, battle_no + 1)
			out.append("%s lost %d candy at the table%s." % [c.short.capitalize(), -net, " and is fuming" if c.tilt > 0.0 else " and is shaken"])
		elif net >= 20:
			c.tilt = c.tilt * 0.5
			c.remember("poker_win", "Won %d candy at the table." % net, -5.0 if pnet < 0 else 0.0, 0.0, battle_no + 1)
			out.append("%s won %d candy at the table." % [c.short.capitalize(), net])
		else:
			c.tilt *= 0.7
	for t in out:
		note(t)
	return out


# --- saving -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var caps := {}
	for id in captains.keys():
		caps[id] = (captains[id] as TubCaptain).to_dict()
	return {"version": VERSION, "player": player.duplicate(true), "captains": caps, "battle_no": battle_no,
		"chronicle": chronicle.duplicate(true), "seed": seed, "refit_due": refit_due, "last_opponents": last_opponents.duplicate(),
		"saved": Time.get_datetime_string_from_system(false, true)}


func from_dict(d: Dictionary) -> void:
	player = (d["player"] as Dictionary).duplicate(true)
	var ship: Dictionary = player["ship"]
	ship["hull"] = float(ship["hull"])
	ship["max_hull"] = int(ship["max_hull"])
	player["candy"] = int(player["candy"])
	var stats: Dictionary = player["stats"]
	for k in stats.keys():
		stats[k] = int(stats[k])
	captains.clear()
	var caps: Dictionary = d["captains"]
	for id in TubData.ROSTER_ORDER:
		captains[id] = TubCaptain.from_dict(caps[id]) if caps.has(id) else TubCaptain.from_roster(id)
	battle_no = int(d.get("battle_no", 0))
	chronicle = (d.get("chronicle", []) as Array).duplicate(true)
	for e in chronicle:
		e["battle"] = int(e.get("battle", 0))
	seed = int(d.get("seed", 1))
	refit_due = bool(d.get("refit_due", false))
	last_opponents = (d.get("last_opponents", []) as Array).duplicate()


func save(file: String = SAVE_FILE) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var path := save_dir.path_join(file)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


func load_file(file: String = SAVE_FILE) -> bool:
	var path := save_dir.path_join(file)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("player"):
		return false
	from_dict(parsed)
	return true


func has_save(file: String = SAVE_FILE) -> bool:
	return FileAccess.file_exists(save_dir.path_join(file))
