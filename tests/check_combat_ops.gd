extends SceneTree
## Practical check of the Mission 006 playtest corrections (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_combat_ops.gd
## The reported poker case (two warships engaged and sunk, then back to
## ordinary operations) and the return to ordinary watch; weapons on the
## chart (own torpedoes live and estimated, stale and expired tracks, what
## may and may not be shown, time-step independence); damage assessment on
## request and its later update from intelligence; the reconnaissance drone
## (launch limits, observation, recovery, loss).

var main: Node
var frame := 0
var failures := 0
var _seen_states := {}          # weapon plot states seen for T1 during its run
var _uid := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		main.call("_begin_patrol")
		main.briefing_panel.dismiss()
	if frame < 6:
		return false
	seed(7)
	_poker_after_two_sinkings()
	_weapons_on_chart()
	_assessment_requests()
	_drone()
	print("COMBAT OPS CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	return true


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _logged(part: String) -> String:
	for i in range(main.captain_log.entries.size() - 1, -1, -1):
		var t := String(main.captain_log.entries[i]["text"])
		if t.contains(part):
			return t
	return ""


func _steps(n: int, dt: float = 1.0) -> void:
	for _i in n:
		main.call("_sim_step", dt)


func _ship(kind: SurfaceShip.Kind, rel: Vector3, heading: float, kts: float, ais: bool, vname: String = "") -> SurfaceShip:
	var s := SurfaceShip.new()
	s.kind = kind
	s.ocean = main.ocean
	_uid += 1
	s.uid = "chk_%d" % _uid
	s.recycle = false
	s.ais_on = ais
	s.vessel_name = vname
	main.add_child(s)
	var p: Vector3 = main.sub.position + rel
	s.place(Vector3(p.x, 0.0, p.z), heading, kts)
	if kts > 0.0:
		s.set_route([p + Vector3(sin(heading), 0.0, -cos(heading)) * 60000.0], false, kts)
	main.vessels.append(s)
	s.pinged.connect(Callable(main, "_on_pinged"))
	s.suspicion_changed.connect(Callable(main, "_on_suspicion"))
	main.call("_watch_ship", s)
	return s


## The captain's own attack: watch her through the periscope, then fire
## (Space twice). Returns the engagement record once the run is over.
func _attack(s: SurfaceShip) -> Dictionary:
	var enc: Encounter = main.encounter
	var sub: Submarine = main.sub
	if sub.depth_mode != 1 or not sub.masts_up:
		sub.set_depth_mode(1)
		sub.depth = 10.6
		sub.set_periscope(true)
		_steps(40, 0.25)
	main.call("set_view", 1)
	var cf := FireControl.conditions(main.weather)
	enc.fc.reset()
	for _i in 300:
		enc.fc.observe(s, main.sub.global_position, 0.25, cf, null)
	(main.rig as CameraRig).bearing = enc.fc.bearing
	enc.reload = 0.0
	var n0 := enc.engagements.size()
	main.set("_fire_confirm", 0.0)
	main.call("_fire")
	main.call("_fire")
	if enc.engagements.size() <= n0:
		return {}
	var rec: Dictionary = enc.engagements[n0]
	var key := "T%d" % int(rec["n"])
	var g := 0
	while g < 4000 and String(rec["state"]) not in ["hit", "miss_confirmed", "unknown"]:
		main.call("_sim_step", 0.25)
		var tr: Dictionary = main.weapon_plot.tracks.get(key, {})
		if not tr.is_empty():
			_seen_states[String(tr["state"])] = (tr["trail"] as Array).size()
		g += 1
	main.call("_sim_step", 0.25)
	var fin: Dictionary = main.weapon_plot.tracks.get(key, {})
	if not fin.is_empty():
		_seen_states["final_" + String(fin["state"])] = true
	return rec


func _poker_after_two_sinkings() -> void:
	print("poker after two warships engaged and sunk")
	var sub: Submarine = main.sub
	main.weather.set_condition("clear")
	main.weather.current = main.weather.call("_compose_arctic")
	main.clock.seconds = floorf(main.clock.seconds / 86400.0) * 86400.0 + 10.0 * 3600.0
	sub.position = Vector3(60000.0, -10.6, 150000.0)
	sub.set_depth_mode(1)
	sub.depth = 10.6
	sub.heading = 0.0
	sub.ordered_heading = 0.0
	sub.set_speed_step(1)
	sub.set_periscope(true)
	_steps(60)
	main.call("_order", "silent")
	main.call("_order", "battle")
	# Two foreign warships hove to (stopped, as for boarding or a transfer).
	var a := _ship(SurfaceShip.Kind.FRIGATE, Vector3(-1200.0, 0.0, -2200.0), PI * 0.5, 0.0, false)
	var b := _ship(SurfaceShip.Kind.PATROL, Vector3(1200.0, 0.0, -2200.0), PI * 0.5, 0.0, false)
	_steps(60)
	for s in [a, b]:
		var shots := 0
		while s.state == SurfaceShip.State.SAILING and shots < 4:
			s.behavior = "drift"
			s.suspicion = 0.0
			_attack(s)
			shots += 1
	# The engagement is over; wait for the plot to go quiet (any pursuit
	# evidence from the fight to age out).
	var w := 0
	while w < 90 and (main.pursuit.level >= 2 or a.state != SurfaceShip.State.SUNK or b.state != SurfaceShip.State.SUNK):
		_steps(60)
		w += 1
	_steps(900)
	for e in main.encounter.engagements:
		print("        T%d %s  %s" % [int(e["n"]), String(e["state"]), String(e.get("contact", ""))])
	print("        states: %s / %s; pursuit: %s" % [SurfaceShip.State.keys()[a.state], SurfaceShip.State.keys()[b.state], main.pursuit.text()])
	_ok(a.state == SurfaceShip.State.SUNK and b.state == SurfaceShip.State.SUNK, "both warships engaged and sunk")
	var why: String = main.cards_blocker()
	main.call("_open_cards")
	_ok(not main.poker.visible and why.contains("battle stations"), "still at battle stations: no cards, and the reason is given: " + why)
	_ok(String(main.hud.get("_toast").text).contains("BATTLE STATIONS"), "the refusal says why: " + String(main.hud.get("_toast").text))
	main.room_panel.open("mess")
	_ok(String(main.room_panel.get("_side").text).contains("No cards now"), "the mess shows why there are no cards")
	main.room_panel.visible = false
	_ok(_logged("recommended standing down") != "", "with the plot quiet the XO recommends standing down")
	main.call("_order", "battle")
	_ok(String(main.cards_blocker()).contains("silent running"), "stood down; silent running is still rigged: " + String(main.cards_blocker()))
	main.call("_order", "silent")
	_steps(4)
	for cc in main.sensors.tracked_vessels():
		if cc.range_est < 4000.0:
			print("        within 4 km: %s %s %s %.1f km  %s" % [cc.id, cc.label(), cc.affiliation, cc.range_est / 1000.0, SurfaceShip.State.keys()[cc.vessel.state] if cc.vessel else ""])
	_ok(main.crew.alert == 0, "back to ordinary watch (alert %d)" % main.crew.alert)
	_ok(main.cards_blocker() == "", "nothing left in the way of cards")
	main.call("_open_cards")
	_ok(main.poker.visible, "cards can be played again after the engagement")
	main.poker.interrupt("")
	main.clock.seconds = floorf(main.clock.seconds / 86400.0) * 86400.0 + 20.0 * 3600.0
	main.crew.advance(0.0)
	main.call("_open_cards", true)
	_ok(main.poker.visible and main.poker.game.players.size() == 4, "in the evening the four-player Mess Cup table fills (%d seats)" % (main.poker.game.players.size() if main.poker.game else 0))
	main.poker.interrupt("")
	main.clock.seconds = floorf(main.clock.seconds / 86400.0) * 86400.0 + 23.5 * 3600.0
	main.crew.advance(0.0)
	main.call("_open_cards")
	_ok(not main.poker.visible and String(main.hud.get("_toast").text).contains("NOBODY IS FREE"), "late at night nobody is free, and the captain is told who is where")
	main.clock.seconds = floorf(main.clock.seconds / 86400.0) * 86400.0 + 14.5 * 3600.0
	main.crew.advance(0.0)
	sub.flooding = 0.3
	_ok(String(main.cards_blocker()).contains("emergency"), "a genuine emergency still rules cards out")
	sub.flooding = 0.0
	var m := _ship(SurfaceShip.Kind.MERCHANT, Vector3(0.0, 0.0, -3000.0), PI * 0.5, 6.0, true, "NORDIC TRADER")
	_steps(40)
	var mc: Contact = main.sensors.contact_for(m)
	main.call("_update_alert")
	_ok(mc != null and mc.affiliation == "NEUTRAL" and main.crew.alert == 1 and main.cards_blocker() == "", "a merchant passing 3 km off keeps the watch alert but does not stop a game")
	main.call("_open_cards")
	_ok(main.poker.visible, "and the game goes ahead")
	main.poker.interrupt("")
	main.vessels.erase(m)
	m.queue_free()
	_steps(300)
	# With the XO on watch, he stands the boat down himself.
	main.call("_order", "conn")
	main.call("_order", "battle")
	_ok(main.get("_battle"), "battle stations again, the XO has the conn")
	_steps(700)
	_ok(not main.get("_battle") and _logged("XO stood the boat down") != "", "after a quiet ten minutes the XO stands the boat down himself")
	main.call("_order", "conn")
	main.call("set_view", 0)


func _weapons_on_chart() -> void:
	print("weapons on the chart")
	_ok(_seen_states.has("current") and int(_seen_states["current"]) >= 2, "an own torpedo was shown live from its telemetry, with a track")
	var plot: WeaponPlot = main.weapon_plot
	var ended := plot.list().filter(func(t: Dictionary) -> bool: return String(t["state"]) in WeaponPlot.STATES_ENDED)
	print("        tracks now: %s" % ", ".join(plot.list().map(func(t: Dictionary) -> String: return "%s %s" % [t["key"], t["state"]])))
	_ok(_seen_states.has("final_detonated"), "a run that hit is kept on the chart as a detonation (stale) when it ends")
	_steps(int(WeaponPlot.STALE_KEEP) + 30)
	_ok(plot.list().filter(func(t: Dictionary) -> bool: return String(t["kind"]) == "own_torpedo").is_empty(), "and dropped from the chart once stale")
	# A run whose wire parts: the plot dead-reckons and says so.
	var sub: Submarine = main.sub
	var far := _ship(SurfaceShip.Kind.MERCHANT, Vector3(0.0, 0.0, -16000.0), PI * 0.5, 0.0, false)
	main.call("_order", "battle")
	var enc: Encounter = main.encounter
	sub.set_depth_mode(1)
	sub.depth = 10.6
	sub.set_periscope(true)
	_steps(40, 0.25)
	main.call("set_view", 1)
	enc.fc.reset()
	for _i in 240:
		enc.fc.observe(far, sub.global_position, 0.25, FireControl.conditions(main.weather), null)
	(main.rig as CameraRig).bearing = enc.fc.bearing
	enc.reload = 0.0
	var n0 := enc.engagements.size()
	main.set("_fire_confirm", 0.0)
	main.call("_fire")
	main.call("_fire")
	var rec: Dictionary = enc.engagements[n0]
	var torp: Torpedo = rec["torp"]
	var key := "T%d" % int(rec["n"])
	_steps(80, 0.25)
	torp.cut_wire()
	_steps(120, 0.25)
	var tr: Dictionary = plot.tracks[key]
	var err := Vector2((tr["pos"] as Vector3).x - torp.global_position.x, (tr["pos"] as Vector3).z - torp.global_position.z).length()
	_ok(String(tr["state"]) == "estimated" and err <= float(tr["unc"]) + 1.0, "wire parted: shown as an estimate, true position within its circle (%.0f m off, ±%.0f m)" % [err, float(tr["unc"])])
	_steps(800)
	_ok(String(tr["state"]) == "ended" and String(tr["note"]).contains("estimated end"), "it is marked ended at its estimated end of run: " + String(tr["note"]))
	main.vessels.erase(far)
	far.queue_free()
	main.call("_order", "battle")
	main.call("set_view", 0)
	# Enemy weapons: only what is detected, and the same at any time step.
	var hidden := Torpedo.new()
	main.add_child(hidden)
	hidden.global_position = sub.global_position + Vector3(2000.0, -5.0, 0.0)
	_steps(10)
	_ok(plot.list().filter(func(t: Dictionary) -> bool: return String(t["kind"]) == "hostile_torpedo").is_empty(), "an enemy torpedo that has not been detected is not shown")
	hidden.queue_free()
	var p1 := WeaponPlot.new()
	var p2 := WeaponPlot.new()
	var start := Vector3(1000.0, 0.0, 0.0)
	p1.detect("W1", "hostile_torpedo", start, 1.0, 20.0, 0.0, true, "TORPEDO")
	p2.detect("W1", "hostile_torpedo", start, 1.0, 20.0, 0.0, true, "TORPEDO")
	var none: Array = []
	for i in 240:
		p1.advance(float(i + 1) * 0.25, none)
	for i in 60:
		p2.advance(float(i + 1) * 1.0, none)
	var dpos := ((p1.tracks["W1"] as Dictionary)["pos"] as Vector3).distance_to((p2.tracks["W1"] as Dictionary)["pos"])
	_ok(dpos < 0.5 and String((p1.tracks["W1"] as Dictionary)["state"]) == "estimated", "a detected torpedo no longer heard is dead-reckoned the same at fine and coarse steps (%.2f m apart)" % dpos)
	p1.advance(60.0 + WeaponPlot.HOSTILE_LOST + 1.0, none)
	_ok(String((p1.tracks["W1"] as Dictionary)["state"]) == "lost", "after %d s without a detection it is marked no longer tracked" % int(WeaponPlot.HOSTILE_LOST))
	p1.detect("C1", "charge", start, 0.0, 0.0, 200.0, false, "CHARGE")
	_ok(String((p1.tracks["C1"] as Dictionary)["state"]) == "estimated", "a charge heard but not placed exactly is shown as an estimate")
	p1.advance(200.0 + WeaponPlot.HOSTILE_LOST + WeaponPlot.STALE_KEEP + 5.0, none)
	_ok(not p1.tracks.has("W1") and not p1.tracks.has("C1"), "stale weapon tracks expire")
	var ch: ChartView = main.chart
	_ok(ch.weapons == plot, "the chart draws the boat's weapon plot")


func _assessment_requests() -> void:
	print("damage assessment on request")
	var ids: Array[String] = main.engaged_contacts()
	_ok(ids.size() >= 3, "ships engaged are listed for assessment: " + ", ".join(ids))
	var sunk_id := ""
	for uid in main.get("_bda").keys():
		var ev: Dictionary = main.get("_bda")[uid]
		if int(ev["hits"]) > 0:
			sunk_id = String(ev["contact"])
			break
	var v: Dictionary = main.request_assessment(sunk_id)
	_ok(String(v.get("verdict", "")) in ["CONFIRMED SUNK", "PROBABLE SINKING"], "a warship hit and seen to settle or go under: %s" % String(v.get("text", "")).substr(0, 140))
	_ok(_logged("Damage assessment requested, %s" % sunk_id) != "", "the answer is in the Captain's Log")
	# A ship hit once and then lost from sight and hearing: no more than probable.
	var sub: Submarine = main.sub
	var s := _ship(SurfaceShip.Kind.MERCHANT, Vector3(0.0, 0.0, -2500.0), PI * 0.5, 12.0, false)
	_steps(30)
	main.call("_order", "battle")
	var rec := _attack(s)
	main.call("_order", "battle")
	var c: Contact = main.sensors.contact_for(s)
	_ok(String(rec.get("state", "")) == "hit" and c != null, "a merchant hit once")
	sub.set_periscope(false)
	s.position += Vector3(0.0, 0.0, -150000.0)
	_steps(400)
	var v2: Dictionary = main.request_assessment(c.id)
	_ok(String(v2["verdict"]) in ["PROBABLE DAMAGE", "CONFIRMED DAMAGED", "PROBABLE SINKING"] and String(v2["text"]).contains("Contact not held"), "lost from the plot after the hit: %s" % String(v2["text"]).substr(0, 170))
	_ok(not String(v2["verdict"]).begins_with("CONFIRMED SUNK"), "no certainty is manufactured")
	var again: Dictionary = main.request_assessment(c.id)
	_ok(String(again["verdict"]) == String(v2["verdict"]) and _logged("unchanged since") != "", "asking again changes nothing without new evidence")
	# Later intelligence: a rescue report of her loss arrives with the broadcast.
	sub.set_periscope(true)
	sub.set_depth_mode(1)
	var now: float = main.clock.seconds
	main.clock.seconds = ceilf(now / 21600.0) * 21600.0 - 60.0
	main.reports.make("RESCUE", s.uid, main.clock.seconds - 1800.0, main.clock.seconds - 600.0, main.clock.seconds - 60.0,
		Vector2(s.position.x, s.position.z), 9000.0, "A merchant ship reported lost. 12 survivors recovered.", {}, {"status": "SUNK", "survivors": 12})
	_steps(240)
	var upd := _logged("Damage assessment updated, %s" % c.id)
	_ok(upd != "" and upd.contains("PROBABLE SINKING") and upd.contains("was "), "the rescue report updates it, and the earlier answer stays on record: " + upd.substr(0, 150))
	_ok(_logged("Damage assessment requested, %s: %s" % [c.id, String(v2["verdict"])]) != "", "the original assessment is still in the log")
	var none: Dictionary = main.request_assessment("S999")
	_ok(none.is_empty(), "a contact never engaged has nothing to assess")
	main.vessels.erase(s)
	s.queue_free()


func _drone() -> void:
	print("reconnaissance drone")
	var dr: ReconDrone = main.drone
	var sub: Submarine = main.sub
	sub.set_depth_mode(4)
	sub.depth = 60.0
	_ok(dr.launch_blocker(sub, main.weather).contains("surfaced"), "submerged: no launch (%s)" % dr.launch_blocker(sub, main.weather))
	sub.set_depth_mode(0)
	sub.depth = 2.05
	sub.set_speed_step(4)
	sub.speed = 13.0 * Submarine.KNOT
	_ok(dr.launch_blocker(sub, main.weather).contains("too fast"), "too fast for a hand launch")
	sub.set_speed_step(1)
	sub.speed = 3.0 * Submarine.KNOT
	main.weather.set_condition("gale")
	main.weather.current = main.weather.call("_compose_arctic")
	var gale := dr.launch_blocker(sub, main.weather)
	_ok(gale.contains("rough") or gale.contains("wind"), "in a gale: %s" % gale)
	main.weather.set_condition("clear")
	main.weather.current = main.weather.call("_compose_arctic")
	main.weather.current["hs"] = 1.2
	var stranger := _ship(SurfaceShip.Kind.TRAWLER, Vector3(4000.0, 0.0, -2500.0), 0.0, 3.0, false, "HAVBRIS")
	_steps(30)
	var before: Contact = main.sensors.contact_for(stranger)
	var name_before := before.identified_name if before else ""
	_ok(dr.launch_blocker(sub, main.weather) == "" and dr.launch(sub, main.weather), "surfaced, slow, moderate sea: launched (%d left)" % dr.left)
	dr.send_to(stranger.global_position, sub.global_position)
	var t := 0
	while t < 600 and Vector2(dr.pos.x - stranger.global_position.x, dr.pos.z - stranger.global_position.z).length() > 300.0:
		main.call("_sim_step", 1.0)
		t += 1
	_steps(20)
	var c: Contact = main.sensors.contact_for(stranger)
	_ok(c != null and c.sources.has("drone") and c.identified_name == "HAVBRIS", "it found the trawler 4.7 km off and read her name close to (sources: %s)" % (str(c.sources.keys()) if c else "none"))
	_ok(name_before == "", "which the boat could not do from where she was")
	var hid := SurfaceShip.new()
	hid.kind = SurfaceShip.Kind.SUBMARINE
	hid.ocean = main.ocean
	main.add_child(hid)
	hid.place(dr.pos + Vector3(200.0, 0.0, 0.0), 0.0, 4.0)
	hid.submerged = true
	hid.run_depth = 80.0
	main.vessels.append(hid)
	_steps(10)
	var hc: Contact = main.sensors.contact_for(hid)
	_ok(hc == null or not hc.sources.has("drone"), "a submerged submarine right under it is not seen")
	main.vessels.erase(hid)
	hid.queue_free()
	dr.send_to(sub.global_position + Vector3(0.0, 0.0, -20000.0), sub.global_position)
	_ok(dr.target.distance_to(Vector3(sub.global_position.x, 0.0, sub.global_position.z)) <= ReconDrone.LINK_RANGE * 0.9 + 1.0, "it cannot be sent beyond its link (%.1f km)" % (ReconDrone.LINK_RANGE * 0.9 / 1000.0))
	dr.recall()
	t = 0
	while t < 900 and dr.airborne():
		main.call("_sim_step", 1.0)
		t += 1
	_ok(not dr.airborne() and dr.left == ReconDrone.CARRIED and _logged("Drone recovered") != "", "recalled and recovered on the bridge")
	_ok(main.save_blocker() == "" or not main.save_blocker().contains("drone"), "saving is possible again once it is down")
	dr.launch(sub, main.weather)
	_ok(main.save_blocker().contains("drone"), "no saving with the drone up")
	sub.set_depth_mode(4)
	_steps(40)
	_ok(not dr.airborne() and dr.left == ReconDrone.CARRIED - 1 and _logged("dived with the drone") != "", "diving with it up loses it (%d left)" % dr.left)
	main.vessels.erase(stranger)
	stranger.queue_free()
