extends SceneTree
## Practical check of the living world (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_intel.gd
## Regional traffic (routes, materialising and parking), aircraft known only
## through the boat's own senses, delayed reports (times, comms, conflicts),
## the intelligence database (no hidden truth, commanders, reputation),
## location-dependent damage and battle damage assessment, and saving it all.

var main: Node
var frame := 0
var steps: Array[Callable] = []
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			main.call("_begin_patrol")
			main.briefing_panel.dismiss(),
		_check_routes,
		_check_materialise,
		_check_aircraft,
		_check_reports,
		_check_commanders,
		_check_damage,
		_check_bda,
		_check_save,
	]


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if steps.is_empty():
		print("INTEL CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		return true
	var s: Callable = steps.pop_front()
	s.call()
	return false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _check_routes() -> void:
	print("regional traffic routes")
	var tr: WorldTraffic = main.traffic
	var geo: Geography = main.area.geo
	var wet := true
	var clear := true
	var no_ice := true
	for v in tr.voyages:
		var pts: Array = []
		if String(v["behavior"]) == "fishing":
			var c := Vector2(float(v["center"][0]), float(v["center"][1]))
			for k in 16:
				pts.append(c + Vector2.from_angle(TAU * k / 16.0) * float(v["radius"]))
			pts.append(pts[0])
		else:
			for p in v["route"]:
				pts.append(Vector2(float(p[0]), float(p[1])))
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(1, int(a.distance_to(b) / 1000.0))
			for s in n + 1:
				var q := a.lerp(b, float(s) / n)
				if geo.depth(q.x, q.y) < 20.0:
					wet = false
				if q.length() < WorldTraffic.KEEP_CLEAR - 15000.0:
					clear = false
				if geo.ice_cover(q.x, q.y) > 0.3:
					no_ice = false
	_ok(tr.voyages.size() >= 10, "%d vessels on voyages across the region" % tr.voyages.size())
	_ok(wet, "every route and fishing ground is in navigable water")
	_ok(no_ice, "no route runs into the pack")
	_ok(clear, "traffic keeps well clear of the original patrol area")
	var held := 0
	for v2 in main.vessels:
		if tr.node_for((v2 as SurfaceShip).uid) != null:
			held += 1
	_ok(held == 0, "no regional ship is in the picture at the start of the patrol")


func _check_materialise() -> void:
	print("ships appear near the boat and leave the picture when far")
	var tr: WorldTraffic = main.traffic
	var sub: Submarine = main.sub
	var v: Dictionary = tr.voyage("T01")
	var p0 := Vector3(float(v["pos"][0]), -60.0, float(v["pos"][1]))
	var home := sub.position
	sub.position = p0 + Vector3(15000.0, 0.0, 0.0)
	tr.advance(WorldTraffic.TICK)
	var node := tr.node_for("T01")
	_ok(node != null and main.vessels.has(node), "within reach, the merchant becomes a ship in the picture")
	_ok(node != null and node.far == false, "within the horizon she is drawn")
	if node:
		var before := node.position
		for i in 60:
			main.call("_sim_step", 1.0)
		_ok(node.position.distance_to(before) > 300.0, "she sails on (%.0f m in a minute)" % node.position.distance_to(before))
	sub.position = home
	tr.advance(WorldTraffic.TICK)
	_ok(node != null and not main.vessels.has(node), "far away again, she leaves the picture")
	var pv := Vector2(float(v["pos"][0]), float(v["pos"][1]))
	_ok(node != null and pv.distance_to(Vector2(node.position.x, node.position.z)) < 50.0, "and her voyage carries on from where the ship was")
	for i in 30:
		tr.advance(WorldTraffic.TICK)
	_ok(Vector2(float(v["pos"][0]), float(v["pos"][1])).distance_to(pv) > 1000.0, "the voyage keeps moving while parked")


func _check_aircraft() -> void:
	print("aircraft: only what the boat can know")
	var tr: WorldTraffic = main.traffic
	var sub: Submarine = main.sub
	var f: Dictionary = tr.call("_flight", "heron", "FOREIGN", [Vector2(sub.position.x + 60000.0, sub.position.z), Vector2(sub.position.x - 200000.0, sub.position.z)], 450.0, 230.0, true)
	sub.depth = 60.0
	sub.position.y = -60.0
	sub.masts_up = false
	tr.call("_sense_air")
	var any := tr.marks.filter(func(m: Dictionary) -> bool: return String(m["label"]).contains("MPA"))
	_ok(any.is_empty(), "deep with the masts down: no aircraft on the chart")
	sub.depth = 10.6
	sub.position.y = -10.6
	sub.masts_up = true
	sub.set("_mast_ext", 1.0)
	var ext := sub.mast_extension()
	tr.call("_sense_air")
	var esm := tr.marks.filter(func(m: Dictionary) -> bool: return String(m["label"]).contains("ESM"))
	_ok(ext < 0.9 or not esm.is_empty(), "mast up: the patrol aircraft's radar on the ESM (%d marks, mast %.1f)" % [esm.size(), ext])
	if not esm.is_empty():
		_ok(String(esm[0]["kind"]) == "suspected" and float(esm[0]["unc"]) > 5000.0, "an ESM bearing is a suspicion with a wide circle of doubt")
	main.clock.seconds += 600.0
	sub.masts_up = false
	tr.call("_rebuild_marks")
	var lkp := tr.marks.filter(func(m: Dictionary) -> bool: return String(m["kind"]) == "lkp")
	_ok(not lkp.is_empty() or esm.is_empty(), "out of touch, it becomes a last known position")
	main.clock.seconds += 3000.0
	tr.call("_rebuild_marks")
	_ok(tr.marks.filter(func(m: Dictionary) -> bool: return String(m["label"]).contains("MPA")).is_empty(), "and is dropped when too old to mean anything")
	f["done"] = true
	main.clock.seconds -= 3600.0


func _check_reports() -> void:
	print("delayed reports")
	var rf: ReportFeed = main.reports
	var intel: IntelDB = main.intel
	var patrol: Patrol = main.patrol
	var sub: Submarine = main.sub
	_ok(intel.units.is_empty() or intel.units.values().all(func(u: Dictionary) -> bool: return not (u["contacts"] as Array).is_empty() or not (u["reports"] as Array).is_empty()),
		"units exist only from contacts or reports")
	var now: float = main.clock.seconds
	var r1 := rf.make("MPA", "T09", now - 7200.0, now - 7200.0, now - 3600.0, Vector2(150000.0, -15000.0), 2500.0, "Frigate sighted.",
		{"class": "boreas", "class_conf": "HIGH", "designation": "Frigate, BOREAS class", "navy": "FOREIGN"})
	var r2 := rf.make("SIGINT", "T09", now - 6000.0, now - 6000.0, now - 3000.0, Vector2(-60000.0, 120000.0), 25000.0, "Emissions.",
		{"navy": "FOREIGN", "designation": "Foreign warship (signals fix)"})
	_ok(float(r1["t_event"]) <= float(r1["t_obs"]) and float(r1["t_obs"]) <= float(r1["t_sent"]), "event, observation and sending times kept apart and in order")
	var pend: Array = patrol.pending.filter(func(m: Dictionary) -> bool: return m.has("report") and String(m["report"]["id"]) == String(r1["id"]))
	_ok(pend.size() == 1 and float(pend[0]["at"]) >= float(r1["t_sent"]) and fmod(float(pend[0]["at"]) - 30.0, 21600.0) < 1.0, "it goes out with the next six-hourly broadcast")
	main.clock.seconds = float(pend[0]["at"]) + 60.0 if pend.size() == 1 else now
	sub.depth = 60.0
	sub.position.y = -60.0
	sub.masts_up = false
	patrol.advance(2.0)
	_ok(intel.report(String(r1["id"])).is_empty(), "deep, the boat hears nothing")
	sub.depth = 10.6
	sub.position.y = -10.6
	sub.masts_up = true
	sub.set("_mast_ext", 1.0)
	patrol.advance(2.0)
	var got := intel.report(String(r1["id"]))
	_ok(not got.is_empty() or sub.mast_extension() < 0.9, "at periscope depth with a mast up the broadcast is copied")
	if not got.is_empty():
		_ok(float(got["t_recv"]) >= float(got["t_sent"]), "received after it was sent (%s, sent %s)" % [ReportFeed.stamp(float(got["t_recv"])), ReportFeed.stamp(float(got["t_sent"]))])
		var u: Dictionary = intel.units.values().filter(func(x: Dictionary) -> bool: return String(x["key"]) == "T09")[0]
		_ok(String(u["designation"]).contains("BOREAS") and String(u["class"]) == "boreas", "the dossier holds what the report said")
		var g2 := intel.report(String(r2["id"]))
		_ok(not g2.is_empty() and (g2["conflicts"] as Array).has(String(r1["id"])) and (got["conflicts"] as Array).has(String(r2["id"])), "contradicting reports are both kept and flagged")
		var log_found := false
		for e in main.captain_log.entries:
			if String(e["cat"]) == "INTEL" and String(e["text"]).begins_with(String(r1["id"])):
				log_found = true
		_ok(log_found, "the report is in the Captain's Log under intelligence")
	sub.masts_up = false


func _check_commanders() -> void:
	print("commanders and reputation")
	var intel: IntelDB = main.intel
	var s := SurfaceShip.new()
	s.kind = SurfaceShip.Kind.PATROL
	s.uid = "test_cmd"
	main.add_child(s)
	s.commander = intel.assign_commander("test_cmd", false)
	_ok(not s.commander.is_empty(), "a warship has a commander (%s)" % String(s.commander.get("codename", "?")))
	_ok(is_equal_approx(s.persistence(), 1.0 + float(s.commander["attitude"]["wary"]) * 0.3 + float(s.commander["attitude"]["grudge"]) * (0.5 + float(s.commander["attitude"]["patience"]))), "behaviour follows attitude")
	var fresh := float(s.commander["attitude"]["grudge"]) == 0.0 and float(s.commander["attitude"]["wary"]) == 0.0
	_ok(not fresh or (is_equal_approx(s.persistence(), 1.0) and is_equal_approx(s.ping_factor(), 1.0)), "with no memories of us, nothing changes")
	var cid := String(s.commander["id"])
	intel.remember(cid, "evaded", 100.0)
	intel.remember(cid, "attacked", 200.0)
	_ok(s.persistence() > 1.1 and s.ping_factor() < 1.0, "after being evaded and attacked: a longer hunt (x%.2f), quicker pings (x%.2f)" % [s.persistence(), s.ping_factor()])
	# She is lost; her commander survives and comes back on another ship.
	intel.remember(cid, "lost_ship", 300.0)
	intel.release_commander("test_cmd")
	var back := intel.assign_commander("test_other", true)
	_ok(String(back.get("id", "")) == cid, "a survivor with a grudge returns on another ship")
	intel.release_commander("test_other")
	intel.commander_died(cid, 400.0)
	var ids: Array = []
	for i in 12:
		var c := intel.assign_commander("test_x%d" % i, true)
		ids.append(String(c.get("id", "")))
	_ok(not ids.has(cid), "the dead never return")
	for i in 12:
		intel.release_commander("test_x%d" % i)
	s.queue_free()
	intel.captain_event("evaded", 500.0, "test")
	_ok(intel.reputation_text().contains("Stealth"), "the captain's reputation is kept: " + intel.reputation_text().split("\n")[0])


func _check_damage() -> void:
	print("where a torpedo hits matters")
	var big := SurfaceShip.new()
	big.kind = SurfaceShip.Kind.MERCHANT
	big.uid = "test_big"
	main.add_child(big)
	big.place(Vector3(150000.0, 0.0, 150000.0), 0.0, 0.0)
	var small := SurfaceShip.new()
	small.kind = SurfaceShip.Kind.PATROL
	small.uid = "test_small"
	main.add_child(small)
	small.place(Vector3(152000.0, 0.0, 150000.0), 0.0, 0.0)
	# Bow hit on the big merchant, near the surface.
	big.strike(big.to_global(Vector3(0.0, -3.0, -big.length * 0.45)))
	_ok(String(big.last_hit["section"]) == "bow" and big.state == SurfaceShip.State.SAILING, "a bow hit on a large merchant: holed but afloat (flooding %.2f)" % float(big.damage["flooding"]))
	_ok(float(big.damage["sensors"]) > 0.0 and float(big.damage["steering"]) == 0.0, "bow damage, not steering")
	# Under the keel, amidships, on the small warship.
	small.strike(small.to_global(Vector3(0.0, -small.draft - 1.5, 0.0)))
	_ok(bool(small.last_hit["under_keel"]) and small.state == SurfaceShip.State.STRICKEN, "under the keel amidships of a small warship: her back is broken")
	var stern := SurfaceShip.new()
	stern.kind = SurfaceShip.Kind.MERCHANT
	stern.uid = "test_stern"
	main.add_child(stern)
	stern.place(Vector3(154000.0, 0.0, 150000.0), 0.0, 10.0)
	stern.strike(stern.to_global(Vector3(0.0, -4.0, stern.length * 0.47)))
	_ok(float(stern.damage["steering"]) > 0.5 and float(stern.damage["propulsion"]) > 0.2, "a stern hit takes her steering and much of her power")
	_ok(not stern.apparent().has("flooding") and not stern.apparent().has("hull"), "an observer sees signs, never the damage figures")
	for s in [big, small, stern]:
		(s as Node).queue_free()
	# Classes look and measure differently.
	var specs := [[SurfaceShip.Kind.PATROL, "corvette", 94.0], [SurfaceShip.Kind.PATROL, "opv", 92.0], [SurfaceShip.Kind.MERCHANT, "bulk", 180.0], [SurfaceShip.Kind.FRIGATE, "", 134.0]]
	var names: Array = []
	for sp in specs:
		var sh := SurfaceShip.new()
		sh.kind = sp[0]
		sh.variant = String(sp[1])
		main.add_child(sh)
		_ok(is_equal_approx(sh.length, float(sp[2])), "%s builds as its own class (%.0f m, %s)" % [String(sp[1]) if String(sp[1]) != "" else "frigate", sh.length, sh.contact_name])
		names.append(sh.contact_name)
		sh.queue_free()
	_ok(names[0] != names[1], "a corvette and a coast guard cutter are told apart")


func _check_bda() -> void:
	print("battle damage assessment from evidence")
	var ev := BattleDamage.new_evidence("S9", 0.0)
	_ok(String(BattleDamage.assess(ev)["level"]) == "NO OBSERVED EFFECT", "nothing heard: no observed effect")
	ev["hits"] = 1
	var a1 := BattleDamage.assess(ev)
	_ok(String(a1["level"]) == "HIT, EFFECT UNKNOWN" and String(a1["conf"]) == "LOW", "a detonation alone: hit, effect unknown (low)")
	BattleDamage.observe(ev, {"fire": true, "list": 7.0, "speed": 3.0}, true, false, 100.0)
	_ok(String(BattleDamage.assess(ev)["level"]) == "DAMAGED", "fire and a list, still under way: damaged")
	BattleDamage.observe(ev, {"fire": true, "list": 8.0, "speed": 0.1}, true, false, 200.0)
	_ok(String(BattleDamage.assess(ev)["level"]) == "SERIOUSLY DAMAGED", "fire, list and no way on her: seriously damaged")
	BattleDamage.observe(ev, {"fire": true, "list": 17.0, "speed": 0.0, "settle": 3.0}, true, false, 300.0)
	_ok(String(BattleDamage.assess(ev)["level"]) == "PROBABLY SINKING", "settling with a heavy list: probably sinking")
	BattleDamage.observe(ev, {"speed": 0.0, "breaking": true}, false, true, 400.0)
	_ok(String(BattleDamage.assess(ev)["level"]) == "PROBABLY SUNK", "breaking-up noises: probably sunk")
	var ev2 := BattleDamage.new_evidence("S9", 0.0)
	ev2["hits"] = 1
	ev2["sunk_report"] = true
	var a2 := BattleDamage.assess(ev2)
	_ok(String(a2["level"]) == "SUNK" and String(a2["conf"]) == "MEDIUM", "a rescue report alone: sunk (medium)")
	BattleDamage.observe(ev2, {"under": true}, true, false, 500.0)
	_ok(String(BattleDamage.assess(ev2)["conf"]) == "HIGH", "seen to go under: sunk (high)")
	# In the game: a hit on a contact opens an assessment and a log entry.
	var ship: SurfaceShip = main.story.ships["merchant"]
	var n0: int = main.captain_log.entries.size()
	main.call("_on_target_hit", ship)
	var found := false
	for i in range(n0, main.captain_log.entries.size()):
		if String(main.captain_log.entries[i]["cat"]) == "COMBAT":
			found = true
	_ok(found and main._bda.has(ship.uid), "a hit opens a damage assessment in the log")
	_ok(float(main.intel.captain["aggression"]) > 0.0, "and the captain is now known to use weapons")
	main._bda.erase(ship.uid)


func _check_save() -> void:
	print("saving the living world")
	var tr: WorldTraffic = main.traffic
	var intel: IntelDB = main.intel
	var sub: Submarine = main.sub
	var v: Dictionary = tr.voyage("T02")
	sub.position = Vector3(float(v["pos"][0]) + 12000.0, -60.0, float(v["pos"][1]))
	tr.advance(WorldTraffic.TICK)
	var node := tr.node_for("T02")
	var d: Dictionary = main.gather_state("check")
	var js := JSON.stringify(d)
	var parsed: Variant = JSON.parse_string(js)
	_ok(parsed is Dictionary and (parsed as Dictionary).has("intel") and (parsed as Dictionary).has("traffic"), "intelligence and traffic go into the save as plain data")
	var units_n := intel.units.size()
	var reports_n := intel.reports.size()
	var t02 := Vector2(float(v["pos"][0]), float(v["pos"][1]))
	var cmd_mem := 0
	for c in intel.commanders.values():
		cmd_mem += (c["memories"] as Array).size()
	# Change things, then load.
	intel.units.clear()
	intel.reports.clear()
	v["pos"] = [0.0, 0.0]
	main.apply_state(parsed)
	var v2: Dictionary = tr.voyage("T02")
	var mem2 := 0
	for c2 in intel.commanders.values():
		mem2 += (c2["memories"] as Array).size()
	_ok(intel.units.size() == units_n and intel.reports.size() == reports_n, "units (%d) and reports (%d) restored" % [units_n, reports_n])
	_ok(mem2 == cmd_mem, "commanders' memories restored (%d)" % mem2)
	_ok(Vector2(float(v2["pos"][0]), float(v2["pos"][1])).distance_to(t02) < 100.0, "voyages restored")
	_ok(node != null and main.vessels.has(tr.node_for("T02")), "a ship that was in the picture is back in it")
