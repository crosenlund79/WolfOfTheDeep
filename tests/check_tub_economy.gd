extends SceneTree
## Practical check of the Bathtub Edition's candy economy (no framework):
##   godot --headless --path . -s tests/check_tub_economy.gd
## Repairs and their costs, upgrades and their effects, the free harbour
## patch (nobody is ever stranded, nobody gets more than a floating boat),
## battle settlement, the rivals' refits from their own purses, and that a
## rival who cannot pay really does fight damaged next time.

var failures := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _initialize() -> void:
	_repairs()
	_upgrades()
	_patch()
	_refits()
	_settlement()
	print("TUB ECONOMY CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit()


func _repairs() -> void:
	print("repairs")
	var ship := TubCaptain.new_ship("sub")
	ship["hull"] = 60.0
	(ship["comp"] as Dictionary)["propulsion"] = 0.5
	_ok(TubEconomy.hull_cost(ship) == 20, "40 hull to mend costs 20 candy (2 hull per candy)")
	_ok(TubEconomy.comp_cost(ship, "propulsion") == 15, "a half-wrecked propeller costs 15 to fix")
	_ok(TubEconomy.full_repair_cost(ship) == 35, "everything: 35")
	var spent := TubEconomy.repair_hull(ship, 12)
	_ok(spent == 12 and is_equal_approx(float(ship["hull"]), 84.0), "with only 12 candy: 12 spent, hull 84")
	var spent2 := TubEconomy.repair_comp(ship, "propulsion", 5)
	_ok(spent2 == 5 and absf(float((ship["comp"] as Dictionary)["propulsion"]) - (0.5 + 5.0 / 30.0)) < 0.001, "a part is mended as far as the candy goes")
	_ok(TubEconomy.repair_hull(ship, 0) == 0, "no candy, no repair")


func _upgrades() -> void:
	print("upgrades")
	var ship := TubCaptain.new_ship("sub")
	_ok(TubEconomy.buy_blocker(ship, "shield", 50) == "needs 70 candy", "too dear: says how much is needed")
	_ok(TubEconomy.buy_blocker(ship, "shield", 70) == "", "affordable")
	var price := TubEconomy.buy(ship, "armour")
	_ok(price == 60 and int(ship["max_hull"]) == 130 and is_equal_approx(float(ship["hull"]), 130.0), "Reinforced Hull: +30 maximum hull")
	_ok(TubEconomy.buy_blocker(ship, "armour", 999) == "already fitted", "cannot be bought twice")
	var duck := TubCaptain.new_ship("duck")
	_ok(TubEconomy.buy_blocker(duck, "racks", 999) == "does not fit this vessel", "torpedo racks do not fit a rubber duck")
	# Effects in battle.
	var s := TubShip.new()
	var base := TubCaptain.new_ship("sub")
	s.setup(base, "player", "x", true)
	var plain := [s.top_speed(), s.turn_rate(), s.reload_time(), s.sight(), s.ammo]
	for up in ["propeller", "rudder", "launcher", "periscope", "racks", "shield", "decoy"]:
		TubEconomy.buy(base, up)
	var s2 := TubShip.new()
	s2.setup(base, "player", "x", true)
	_ok(absf(s2.top_speed() / float(plain[0]) - 1.15) < 0.01 and absf(s2.turn_rate() / float(plain[1]) - 1.25) < 0.01, "propeller +15% speed, rudder +25% turning")
	_ok(absf(s2.reload_time() / float(plain[2]) - 0.6) < 0.01 and absf(s2.sight() / float(plain[3]) - 1.4) < 0.01, "launcher reloads 40% faster, periscope sees 40% further")
	_ok(s2.ammo == 12 and s2.shield and s2.decoys == 2, "racks: 12 torpedoes; a bubble shield; two decoys")
	# Damage takes effect too.
	(base["comp"] as Dictionary)["propulsion"] = 0.0
	var s3 := TubShip.new()
	s3.setup(base, "player", "x", true)
	_ok(absf(s3.top_speed() / s2.top_speed() - 0.45) < 0.01, "a wrecked propeller: 45% speed")


func _patch() -> void:
	print("no permanent bankruptcy")
	var ship := TubCaptain.new_ship("patrol")
	ship["hull"] = 0.0
	(ship["comp"] as Dictionary)["weapons"] = 0.0
	_ok(TubEconomy.harbour_patch(ship), "a sunk boat with nothing left is patched for free")
	_ok(is_equal_approx(float(ship["hull"]), 70.0 * TubData.PATCH_HULL) and is_equal_approx(float((ship["comp"] as Dictionary)["weapons"]), TubData.PATCH_COMPONENT), "but only to a floating minimum (40% hull, 30% parts)")
	_ok(not TubEconomy.harbour_patch(ship), "and never beyond it")


func _refits() -> void:
	print("rivals refit from their own purses")
	var moss := TubCaptain.from_roster("moss")       # cautious
	moss.ship["hull"] = 20.0
	moss.candy = 100
	var acts := TubEconomy.plan_rival(moss)
	_ok(is_equal_approx(float(moss.ship["hull"]), 70.0) and moss.candy == 100 - 25, "the cautious lieutenant mends the hull fully first (25 candy)")
	print("        ", acts)
	var pirate := TubCaptain.from_roster("soapbeard") # reckless
	pirate.ship["hull"] = 20.0
	pirate.candy = 120
	TubEconomy.plan_rival(pirate)
	_ok(float(pirate.ship["hull"]) < 40.0 and (pirate.ship["upgrades"] as Array).size() >= 1, "the reckless pirate patches a little and buys guns (%d%% hull, %s)" % [int(float(pirate.ship["hull"]) / 70.0 * 100.0), str(pirate.ship["upgrades"])])
	var poor := TubCaptain.from_roster("plunge")
	poor.ship["hull"] = 30.0
	poor.candy = 12
	var acts2 := TubEconomy.plan_rival(poor)
	_ok(poor.candy == 0 and float(poor.ship["hull"]) < 150.0 * 0.75 and (poor.ship["upgrades"] as Array).is_empty(), "short of candy: spends what there is, buys nothing")
	_ok(acts2.any(func(t: String) -> bool: return t.contains("could not afford")), "and the harbour gossip says so")
	_ok(float(poor.ship["hull"]) >= 150.0 * TubData.PATCH_HULL, "never below the free floating minimum")
	# The next battle uses that ship as it stands.
	var b := TubBattle.new()
	b.setup(TubCaptain.new_ship("sub"), 100, [poor], 1)
	_ok(is_equal_approx(b.ships[1].hull, float(poor.ship["hull"])), "and the next battle starts with that damage (%.0f / %d hull)" % [b.ships[1].hull, b.ships[1].max_hull])
	var rich := TubCaptain.from_roster("inkwell")
	rich.candy = 500
	TubEconomy.plan_rival(rich)
	_ok((rich.ship["upgrades"] as Array).size() == 1 and rich.candy == 500 - 35, "a careful captain buys one upgrade at a time and keeps a reserve")


func _settlement() -> void:
	print("battle settlement")
	var car := TubCareer.new()
	car.save_dir = "user://bathtub_check_econ/"
	car.new_game(9)
	var total_before := int(car.player["candy"])
	for c in car.roster():
		total_before += c.candy
	var b := car.start_battle()
	# Script a little battle: the player sinks the first rival.
	var foe := b.ships[1]
	foe.pos = b.player.pos + Vector2(220, 0)
	foe.heading = PI * 0.5
	foe.ai["cool"] = 99.0
	foe.style["retreat_at"] = 0.0
	foe.hull = 20.0
	b.player_fire()
	for _i in 60:
		b.step(1.0 / 60.0)
	_ok(foe.state == "sunk", "the player sinks %s" % foe.name)
	b.over = true
	b.result = "draw"
	var cand_before := int(car.player["candy"])
	var foe_before := car.captain(foe.id).candy
	var rep := car.settle(b)
	var earn: Dictionary = rep["earnings"]
	var mine: Dictionary = earn["player"]
	_ok(int(car.player["candy"]) == cand_before + int(mine["total"]), "the player's purse grows by exactly what was earned (%+d)" % int(mine["total"]))
	_ok(int(mine["sinks"]) == TubData.REWARD["sink"] and int(mine["hits"]) == TubData.REWARD["hit"], "a sinking and a hit paid at the posted rates")
	var foe_e: Dictionary = earn[foe.id]
	_ok(car.captain(foe.id).candy == foe_before + int(foe_e["total"]), "the sunk captain's purse changes by their own earnings (%+d, including the spill)" % int(foe_e["total"]))
	_ok(is_equal_approx(float(car.captain(foe.id).ship["hull"]), 0.0), "their ship stays sunk until they pay for it")
	_ok(car.battle_no == 1 and car.refit_due, "battle counted; rivals will refit before the next")
	var b2 := car.start_battle()
	_ok(float(car.captain(foe.id).ship["hull"]) > 0.0, "they refit (or get the free patch) before the next battle")
	_ok(b2 != null and not car.refit_due, "and the next battle begins")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bathtub_check_econ/prebattle.json"))
