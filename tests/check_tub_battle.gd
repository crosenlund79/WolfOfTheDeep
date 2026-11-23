extends SceneTree
## Practical check of the Bathtub Edition's battles (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_tub_battle.gd
## Movement and turning, depth states and their purposes, torpedo hits and
## obstacles, which weapons reach which depth, damage to parts, sinking and
## spilled candy (picked up, or lost down the drain), the rivals actually
## coming to fight, the ways a battle ends, and the tactical pause freezing
## everything in the real game scene.

var failures := 0
var frame := 0
var main: Node
var _t0 := 0.0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _cap(id: String) -> TubCaptain:
	return TubCaptain.from_roster(id)


## A bath with no clutter and the given rivals.
func _bath(rivals: Array, seed_v: int = 3) -> TubBattle:
	var b := TubBattle.new()
	b.setup(TubCaptain.new_ship("sub"), 100, rivals, seed_v)
	b.obstacles.clear()
	b.foam.clear()
	b.player.pos = Vector2(-500, 0)
	b.player.heading = 0.0
	return b


func _run(b: TubBattle, secs: float) -> void:
	for _i in int(secs * 60.0):
		b.step(1.0 / 60.0)


func _initialize() -> void:
	_movement()
	_depth()
	_torpedoes()
	_weapons_by_depth()
	_sinking_and_candy()
	_rivals_fight()
	_endings()
	main = load("res://scenes/bathtub.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		main.career.save_dir = "user://bathtub_check/"
		main.career.new_game(5)
		main.start_battle()
	if frame == 10:
		_t0 = main.battle.time
		main.open_manage("repairs")
	if frame == 40:
		_ok(is_equal_approx(main.battle.time, _t0), "TAB management freezes the battle (time %.2f -> %.2f)" % [_t0, main.battle.time])
		_ok(main.manage.visible and main.manage.tab == "repairs", "the repairs panel is open over the frozen battle")
		main.manage.visible = false
	if frame == 60:
		_ok(main.battle.time > _t0 + 0.2, "closing it resumes the battle")
		main.call("_open_pause")
		_t0 = main.battle.time
	if frame == 80:
		_ok(is_equal_approx(main.battle.time, _t0), "the pause menu freezes it too")
		main.call("_close_pause")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bathtub_check/career.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bathtub_check/prebattle.json"))
		print("TUB BATTLE CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		return true
	return false


func _movement() -> void:
	print("movement")
	var b := _bath([])
	b.sandbox = true
	var p := b.player
	p.throttle = 1.0
	_run(b, 1.5)
	_ok(p.speed > p.top_speed() * 0.95, "full ahead: %.0f px/s within 1.5 s (top %.0f)" % [p.speed, p.top_speed()])
	var x0 := p.pos.x
	_run(b, 0.5)
	_ok(p.pos.x - x0 > 100.0, "and it covers ground (%.0f px in half a second)" % (p.pos.x - x0))
	var h0 := p.heading
	p.rudder = 1.0
	_run(b, 1.0)
	var turned := absf(wrapf(p.heading - h0, -PI, PI))
	_ok(turned > 1.5 and turned < 3.2, "turns convincingly at speed: %.0f° in a second" % rad_to_deg(turned))
	p.rudder = 0.0
	p.throttle = 0.0
	_run(b, 2.0)
	_ok(absf(p.speed) < 30.0, "coasts to a stop when the throttle is released")
	p.pos = Vector2(0, 0)
	p.heading = 0.0
	p.throttle = 1.0
	var hull0 := p.hull
	_run(b, 8.0)
	_ok(TubBattle.tub_sdf(p.pos) <= -p.radius() + 1.0, "the tub wall keeps it in")
	_ok(p.hull < hull0 and p.hull >= hull0 - 2.0 * p.top_speed() / 60.0, "ramming the rim dents the hull once, not again and again while pushing (%.0f -> %.0f)" % [hull0, p.hull])
	p.hull = hull0
	p.pos = Vector2(-300, TubBattle.HALF.y - p.radius() - 0.5)
	p.heading = 0.0
	p.speed = p.top_speed()
	_run(b, 1.5)
	_ok(p.hull == hull0, "sliding along the rim at full speed costs nothing")


func _depth() -> void:
	print("depth")
	var b := _bath([])
	b.sandbox = true
	var p := b.player
	var top0 := p.top_speed()
	b.set_depth(p, 1)
	_ok(p.depth == 0 and p.depth_t > 0.0, "diving takes a moment")
	_ok(not p.can_fire(), "no firing while changing depth")
	_run(b, 0.8)
	_ok(p.depth == 1 and absf(p.top_speed() / top0 - 0.8) < 0.01, "periscope depth: 80%% speed")
	_ok(p.can_fire(), "and it can still fire")
	b.set_depth(p, 2)
	_run(b, 0.8)
	_ok(p.depth == 2 and absf(p.top_speed() / top0 - 0.6) < 0.01 and not p.can_fire(), "deep: 60% speed, cannot fire")
	_run(b, TubShip.AIR_TIME + 1.0)
	_ok(p.depth == 1 and p.depth_t <= 0.0, "out of air it rises by itself")
	b.set_depth(p, 2)
	_ok(p.depth_t <= 0.0, "and cannot dive again until the air refills")
	# Deep slips under the sponge, but not under the soap.
	var b2 := _bath([])
	b2.sandbox = true
	b2.obstacles.append({"kind": "sponge", "pos": Vector2(0, 0), "half": Vector2(95, 60), "corner": 20.0, "rot": 0.0})
	b2.player.pos = Vector2(-200, 0)
	b2.player.depth = 2
	b2.player.air = 1.0
	b2.player.throttle = 1.0
	_run(b2, 3.0)
	_ok(b2.player.pos.x > 120.0, "deep, it passes under the sponge (x %.0f)" % b2.player.pos.x)
	b2.player.pos = Vector2(-200, 0)
	b2.player.depth = 0
	_run(b2, 2.0)
	_ok(b2.player.pos.x < -60.0, "on the surface, the sponge stops it")


func _torpedoes() -> void:
	print("torpedoes")
	var b := _bath([_cap("moss")])
	var e := b.ships[1]
	e.pos = Vector2(-200, 0)
	e.heading = PI * 0.5
	e.ai["cool"] = 99.0
	e.style["retreat_at"] = 0.0
	var h0 := e.hull
	_ok(b.player_fire(), "SPACE: torpedo away")
	_ok(b.player.ammo == 7 and not b.player.can_fire(), "one torpedo used, tube reloading")
	_run(b, 1.0)
	_ok(e.hull < h0 - 20.0, "it hits a toy 300 px ahead: hull %.0f -> %.0f" % [h0, e.hull])
	var worn := 0
	for c in TubData.COMPONENTS:
		if e.c(c) < 1.0:
			worn += 1
	_ok(worn == 1, "and damages one of its parts")
	_ok(b.player.hits == 1 and float(b.dmg_by.get("player>moss", 0.0)) > 20.0, "the hit is credited to the player")
	var b2 := _bath([_cap("moss")])
	var e2 := b2.ships[1]
	e2.pos = Vector2(-150, 0)
	e2.ai["cool"] = 99.0
	b2.obstacles.append({"kind": "soap", "pos": Vector2(-330, 0), "half": Vector2(75, 45), "corner": 30.0, "rot": 0.0})
	b2.player_fire()
	_run(b2, 1.0)
	_ok(b2.player.hits == 0 and b2.torps.is_empty(), "a bar of soap in the way stops the torpedo")


func _weapons_by_depth() -> void:
	print("which weapons reach which depth")
	# Enemy torpedo spread: hits at periscope depth, passes over the deep.
	for d in [1, 2]:
		var b := _bath([_cap("plunge")])
		var e := b.ships[1]
		e.pos = Vector2(-120, 0)
		e.heading = PI
		e.ai["cool"] = 0.0
		e.ai["ping"] = 99.0
		e.ai["dc"] = 99.0
		b.player.depth = d
		b.player.revealed_t = 99.0
		b.player.air = 1.0
		var h := b.player.hull
		_run(b, 2.5)
		if d == 1:
			_ok(b.player.hull < h, "a destroyer's torpedoes hit the sub at periscope depth (%.0f -> %.0f)" % [h, b.player.hull])
		else:
			_ok(is_equal_approx(b.player.hull, h) or b.player.hull > h - 1.0, "and pass over it when deep")
	# Deck gun pellets only hit on the surface.
	for d2 in [0, 1]:
		var b2 := _bath([_cap("soapbeard")])
		var e2 := b2.ships[1]
		e2.pos = Vector2(-150, 0)
		e2.heading = PI
		e2.ai["dc"] = 99.0
		b2.player.depth = d2
		b2.player.revealed_t = 99.0
		var hp := b2.player.hull
		_run(b2, 3.0)
		var hurt := b2.player.hull < hp
		_ok(hurt if d2 == 0 else not hurt or b2.charges.size() > 0 or b2.player.hull > hp - 30.0, "deck gun: %s" % ("hits on the surface" if d2 == 0 else "cannot reach periscope depth"))
	# Depth charges reach the deep and not the surface.
	var b3 := _bath([])
	b3.sandbox = true
	b3.player.depth = 2
	b3.player.air = 1.0
	b3.charges.append({"pos": b3.player.pos, "fuse": 0.1, "owner": "x"})
	var h3 := b3.player.hull
	_run(b3, 0.3)
	_ok(b3.player.hull < h3 - 10.0, "a depth charge hurts the deep sub (%.0f -> %.0f)" % [h3, b3.player.hull])
	b3.player.depth = 0
	b3.charges.append({"pos": b3.player.pos, "fuse": 0.1, "owner": "x"})
	var h4 := b3.player.hull
	_run(b3, 0.3)
	_ok(is_equal_approx(b3.player.hull, h4), "but not a surfaced one")
	# The duck's squeak.
	var b4 := _bath([])
	b4.sandbox = true
	b4.waves.append({"pos": b4.player.pos + Vector2(120, 0), "r": 30.0, "owner": "quackworth", "done": {}})
	var h5 := b4.player.hull
	_run(b4, 0.5)
	_ok(b4.player.hull < h5, "a rubber duck's squeak hurts and pushes")


func _sinking_and_candy() -> void:
	print("sinking and spilled candy")
	var b := _bath([_cap("moss")])
	var e := b.ships[1]
	e.pos = Vector2(-250, 0)
	e.ai["cool"] = 99.0
	e.style["retreat_at"] = 0.0
	e.hull = 10.0
	b.player_fire()
	_run(b, 0.6)
	_ok(e.state == "sunk" and String(b.sunk_by.get("moss", "")) == "player", "a torpedo sinks a toy with little hull left")
	var spill := -int(b.ledger["moss"])
	_ok(spill == TubData.SPILL_BASE + int(round(120.0 * TubData.SPILL_SHARE)), "its captain's candy spills from their own purse: %d" % spill)
	_ok(b.pickups.size() > 0, "as pieces floating in the water")
	for pk in b.pickups.duplicate():
		b.player.pos = pk["pos"]
		b.step(1.0 / 60.0)
	_ok(int(b.ledger["player"]) == spill and b.player.candy_got == spill, "sailing over it picks it up (+%d)" % int(b.ledger["player"]))
	var b2 := _bath([])
	b2.sandbox = true
	b2.pickups.append({"pos": TubBattle.DRAIN + Vector2(-60, 0), "amount": 5, "t": 0.0})
	_run(b2, 4.0)
	_ok(b2.pickups.is_empty(), "candy left near the drain goes down it")


func _rivals_fight() -> void:
	print("the rivals come to fight")
	var b := TubBattle.new()
	b.setup(TubCaptain.new_ship("sub"), 100, [_cap("plunge"), _cap("quackworth"), _cap("soapbeard")], 11)
	var p := b.player
	var closest := {}
	for i in 45 * 60:
		b.step(1.0 / 60.0)
		for s in b.ships:
			if not s.is_player:
				closest[s.id] = minf(float(closest.get(s.id, 1e9)), s.pos.distance_to(p.pos))
		if b.over:
			break
	var near := 0
	for id in closest.keys():
		if float(closest[id]) < 600.0:
			near += 1
	print("        closest approach: %s; player hull %.0f" % [str(closest), p.hull])
	_ok(near >= 2, "within 45 s most rivals close in (%d of 3 came within 600 px)" % near)
	_ok(p.hull < 100.0, "and they hurt the idle sub (hull %.0f)" % p.hull)


func _endings() -> void:
	print("how a battle ends")
	var b := _bath([_cap("moss")])
	b.ships[1].hull = 1.0
	b.ships[1].pos = Vector2(-300, 0)
	b.ships[1].ai["cool"] = 99.0
	b.player_fire()
	_run(b, 3.0)
	_ok(not b.over and b.cleared_t > 0.0, "the last rival sunk: a few seconds to grab the spilled candy")
	_run(b, TubBattle.GRAB_TIME)
	_ok(b.over and b.result == "victory", "then: victory")
	var b2 := _bath([_cap("moss")])
	b2.player.hull = 1.0
	b2.charges.append({"pos": b2.player.pos, "fuse": 0.05, "owner": "moss"})
	b2.player.depth = 1
	_run(b2, 0.5)
	_ok(b2.over and b2.result == "defeat", "the sub sunk: defeat")
	var b3 := _bath([_cap("moss")])
	b3.limit = 3.0
	b3.ships[1].pos = Vector2(600, 300)
	_run(b3, 3.5)
	_ok(b3.over and b3.result in ["draw", "defeat", "victory"], "the bath goes cold: %s" % b3.result)
	var b4 := _bath([_cap("moss")])
	b4.ships[1].pos = Vector2(600, 300)
	b4.player.pos = Vector2(-TubBattle.HALF.x + 30.0, 0)
	for _i in 150:
		b4.player_retreat(1.0 / 60.0, true)
		b4.step(1.0 / 60.0)
	_ok(b4.over and b4.result == "withdrew", "holding X at the rim: lifted out (withdrew)")
	var earn := b4.earnings()
	_ok(int((earn["player"] as Dictionary)["survive"]) == TubData.REWARD["survive"] and int((earn["player"] as Dictionary)["victory"]) == 0, "a withdrawal pays the safe-return money, no victory")
