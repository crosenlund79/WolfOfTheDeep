extends SceneTree
## Practical check of the Mission 006 command refinements (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_command.gd
## Pursuit assessment from evidence only; the 4x tactical ceiling with a
## weapon running; Advance Until Event (runs the world, stops for what
## matters, not for trivia, can be cancelled, refuses unsafe states); chart
## search within what the boat knows; the legend; the briefing on a loaded
## campaign (old saves included, nothing pending disclosed); the watchbill.

var main: Node
var main2: Node
var frame := 0
var failures := 0
var _path := ""
var _saved := {}
const SLOT := "check_command_slot"
const SECRET := "QUOKKA-ZEBRA-77 PENDING LINE"


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		main.call("_begin_patrol")
		main.briefing_panel.dismiss()
	if frame == 6:
		_watchbill()
		_pursuit()
		_tactical_time()
		_advance()
		_chart_search()
		_briefing_save()
	if frame == 8:
		main.queue_free()
		main2 = load("res://scenes/main.tscn").instantiate()
		root.add_child(main2)
	if frame == 10:
		_briefing_load()
		SaveSystem.delete(SLOT)
		print("COMMAND CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		return true
	return false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _logged(prefix: String, m: Node = null) -> String:
	var mm: Node = main if m == null else m
	for i in range(mm.captain_log.entries.size() - 1, -1, -1):
		var e: Dictionary = mm.captain_log.entries[i]
		if String(e["text"]).begins_with(prefix):
			return String(e["text"])
	return ""


func _quiet() -> void:
	# A quiet, deep-water situation with nothing in hand.
	main._battle = false
	main.pursuit = PursuitAssessment.new()
	main.set("_alarm_t", 0.0)
	main.sub.flooding = 0.0
	main.sub.position = Vector3(60000.0, -60.0, 150000.0)
	main.sub.depth = 60.0
	main.sub.set_target_depth(60.0)
	main.sub.heading = 0.0
	main.sub.ordered_heading = 0.0
	main.sub.set_speed_step(3)
	main.sub.speed = 9.0 * Submarine.KNOT
	main.sub.battery = 80.0
	main.crew.alert = 0
	main._update_alert()
	main.clock.set_level(0)


func _watchbill() -> void:
	print("the watchbill")
	var crew: Crew = main.crew
	var wb: Array[Dictionary] = crew.watchbill()
	_ok(wb.size() == crew.members.size(), "everyone aboard is on it (%d of %d)" % [wb.size(), crew.members.size()])
	var basse := {}
	for w in wb:
		if String(w["id"]) == "basse":
			basse = w
	_ok(String(basse.get("group", "")) == "GALLEY", "Basse is listed under the galley, not a bridge watch")
	var b: CrewMember = crew.members["basse"]
	var seen := {}
	var keep: float = main.clock.seconds
	for hr in [2.0, 6.0, 10.0, 15.0, 20.5, 22.0]:
		main.clock.seconds = floorf(keep / 86400.0) * 86400.0 + hr * 3600.0
		crew.advance(0.0)
		seen[hr] = crew.duty_status(b)
	_ok(seen[10.0] == "ON DUTY" and seen[15.0] == "ON DUTY", "cooking in the day: galley ON DUTY")
	_ok(seen[2.0] == "RESTING" and seen[22.0] == "RESTING", "asleep at night: RESTING")
	_ok(not seen.values().has("ON WATCH"), "the cook never stands a bridge watch")
	main.clock.seconds = floorf(keep / 86400.0) * 86400.0 + 10.0 * 3600.0
	crew.poker_session = true
	crew.advance(0.0)
	_ok(crew.duty_status(b) == "OFF DUTY", "at the card table he is OFF DUTY")
	crew.poker_session = false
	b.available = false
	_ok(crew.duty_status(b) == "UNAVAILABLE", "and UNAVAILABLE if he cannot serve")
	b.available = true
	crew.advance(0.0)
	var m: CrewMember = crew.members["miller"]
	_ok(crew.duty_status(m) == "ON WATCH", "the XO in the control room is ON WATCH")
	main.call("set_view", 6)
	var txt := ""
	for ch in (main.room_panel.get("_people") as Control).get_children():
		if ch is Label:
			txt += (ch as Label).text + "\n"
	_ok(txt.contains("BASSE") and txt.contains("GALLEY") and txt.contains("ON DUTY") and txt.contains("RASK"), "the cabin's watchbill shows all hands, Basse in the galley")
	main.call("set_view", 0)
	main.clock.seconds = keep
	crew.advance(0.0)


func _pursuit() -> void:
	print("pursuit: the crew's assessment, from evidence")
	_quiet()
	var hunter := SurfaceShip.new()
	hunter.kind = SurfaceShip.Kind.FRIGATE
	main.add_child(hunter)
	hunter.place(main.sub.position + Vector3(0.0, 0.0, -5000.0), PI, 14.0)
	hunter.behavior = "investigate"
	var p := PursuitAssessment.new()
	var none: Array[Contact] = []
	_ok(p.update(100.0, 2.0, main.sub.global_position, none) == 0, "a warship hunting us unheard and unseen: NO PURSUIT INDICATION")
	main._update_alert()
	_ok(main.crew.alert < 2, "and no battle stations from what the other side intends")
	hunter.queue_free()
	p.note_ping(200.0, 22000.0)
	p.update(210.0, 2.0, main.sub.global_position, none)
	_ok(p.level == 1, "one distant ping: %s" % PursuitAssessment.SHORT[p.level])
	p.note_ping(400.0, 6000.0)
	p.note_ping(500.0, 5000.0)
	p.update(510.0, 2.0, main.sub.global_position, none)
	_ok(p.level == 2 and p.text().contains("active sonar"), "repeated close pings alone: %s" % p.text())
	# A warship held on sonar, closing on us from 4.5 km for over two minutes.
	var w := Contact.new()
	w.id = "S9"
	w.classification = "WARSHIP"
	w.range_est = 4500.0
	w.est_pos = main.sub.global_position + Vector3(0.0, 0.0, -4500.0)
	w.est_course = 180.0
	w.est_speed = 15.0
	var held: Array[Contact] = [w]
	for k in 70:
		p.update(512.0 + k * 2.0, 2.0, main.sub.global_position, held)
	_ok(p.level == 3 and p.text().contains("S9 closing"), "pings and a warship closing: %s" % p.text())
	w.est_course = 90.0
	p.update(670.0, 2.0, main.sub.global_position, held)
	_ok(p.level == 3, "she turns away: the crew stay wary for a while (%s)" % PursuitAssessment.SHORT[p.level])
	p.update(1600.0, 2.0, main.sub.global_position, held)
	_ok(p.level == 2, "a quarter of an hour on, with her opening: %s (they judge by what they see)" % PursuitAssessment.SHORT[p.level])
	_ok(p.update(510.0 + 2400.0, 2.0, main.sub.global_position, none) == 0, "with nothing new for 40 minutes it fades")
	var q := PursuitAssessment.new()
	q.note_aircraft(0.0)
	q.note_intel(0.0)
	q.note_exposure(0.0)
	_ok(q.update(60.0, 2.0, main.sub.global_position, none) == 2, "aircraft, a reported search and our own exposure: probable, never confirmed without contact")
	var d := q.save_state()
	var q2 := PursuitAssessment.new()
	q2.load_state(JSON.parse_string(JSON.stringify(d)))
	_ok(q2.update(61.0, 2.0, main.sub.global_position, none) == 2, "saved and restored")
	# Through the game: logged, reported, and it brings the boat to action stations.
	var n0: int = main.captain_log.entries.size()
	main.pursuit.note_ping(main.clock.seconds, 6000.0)
	main.pursuit.note_ping(main.clock.seconds, 5500.0)
	main.call("_assess_pursuit", 2.0)
	_ok(main.captain_log.entries.size() > n0 and _logged("Pursuit assessment") != "", "the change is in the Captain's Log: " + _logged("Pursuit assessment").substr(0, 90))
	_ok(String(main.status_flags()).contains("PURSUIT"), "and on the command bar: " + String(main.status_flags()))
	main._update_alert()
	_ok(main.crew.alert == 2, "probable pursuit brings battle stations")
	_quiet()


func _tactical_time() -> void:
	print("tactical time: x4")
	_quiet()
	main._battle = true
	main._update_alert()
	main.call("_set_time_level", 7)
	_ok(is_equal_approx(main.clock.scale(), 4.0), "at battle stations time goes to x%d, no further" % int(main.clock.scale()))
	main._battle = false
	main._update_alert()
	_ok(main.time_cap() == GameClock.LEVELS.size() - 1, "a quiet boat is not held back by contacts she isn't dealing with")
	# A torpedo run with the game's own loop at x4.
	var enc: Encounter = main.encounter
	var sub: Submarine = main.sub
	sub.position = Vector3(60000.0, -10.6, 150000.0)
	sub.depth = 10.6
	sub.set_target_depth(10.6)
	sub.set_speed_step(1)
	sub.speed = 3.0 * Submarine.KNOT
	var ship := SurfaceShip.new()
	ship.kind = SurfaceShip.Kind.MERCHANT
	ship.ocean = main.ocean
	ship.recycle = false
	main.add_child(ship)
	var tp := sub.position + Vector3(1800.0, 0.0, 0.0)
	ship.place(Vector3(tp.x, 0.0, tp.z), 0.0, 10.0)
	ship.set_route([Vector3(tp.x, 0.0, tp.z - 80000.0)], false, 10.0)
	ship.speed = 10.0 * 0.5144
	var keep: Array[Node3D] = enc.ships.duplicate()
	enc.ships.clear()
	enc.ships.append(ship)
	enc.reload = 0.0
	enc.fc.reset()
	enc.fc.rng.seed = 11
	seed(11)
	main.weather.set_condition("clear")
	main.weather.current = main.weather.call("_compose_arctic")
	var cf := FireControl.conditions(main.weather)
	for _i in 360:
		ship.advance(0.25, sub.position)
		enc.fc.observe(ship, sub.global_position, 0.25, cf, null)
	(main.rig as CameraRig).bearing = enc.fc.bearing
	var n0: int = enc.engagements.size()
	enc.call("fire")
	_ok(enc.engagements.size() > n0, "torpedo away")
	main._update_alert()
	main.call("_set_time_level", 7)
	_ok(is_equal_approx(main.clock.scale(), 4.0), "with a weapon running: x%d" % int(main.clock.scale()))
	var rec: Dictionary = enc.engagements[n0] if enc.engagements.size() > n0 else {}
	var t0: float = main.clock.seconds
	var guard := 0
	var at4 := 0
	var drops := 0
	while guard < 2400 and not rec.is_empty() and String(rec["state"]) not in ["hit", "miss_confirmed", "unknown"]:
		# The captain keeps time at x4; reports (a new contact) may drop it.
		if main.clock.level == 0:
			drops += 1
			main.call("_set_time_level", 7)
		if is_equal_approx(main.clock.scale(), 4.0):
			at4 += 1
		main.call("_process", 1.0 / 30.0)
		guard += 1
	var sim_t: float = main.clock.seconds - t0
	_ok(String(rec.get("state", "")) == "hit", "the run at x4 ends in a hit (%s after %.0f s sim, %d frames)" % [String(rec.get("state", "")), sim_t, guard])
	_ok(at4 > guard * 0.9, "%d of %d frames ran at x4 (time dropped %d times by reports)" % [at4, guard, drops])
	_ok(main.sensors.contact_for(ship) != null, "sonar held the target throughout")
	if String(rec.get("state", "")) != "hit":
		print("        solution %s · %s · events %s" % [String(rec.get("quality", "")), String(rec.get("summary", "")), str(rec.get("events", []))])
	# Whatever happened, nothing is left running for the checks that follow.
	for t in enc.torpedoes:
		if is_instance_valid(t):
			t.done = true
	_ok(_logged("Launch confirmed") != "", "the attack is reported in the log as at x1")
	enc.ships.clear()
	enc.ships.append_array(keep)
	ship.queue_free()
	sub.set_speed_step(3)
	_quiet()


func _fake_contact(id: String, src: String, rng: float) -> Contact:
	var c := Contact.new()
	c.id = id
	c.kind = "VESSEL"
	c.sources = {src: true}
	c.range_est = rng
	c.range_err = 0.2
	c.bearing = 45.0
	c.est_pos = main.sub.global_position + Vector3(rng * 0.7, 0.0, -rng * 0.7)
	return c


func _advance() -> void:
	print("advance until event")
	_quiet()
	main.call("_toggle_advance")
	_ok(main.get("_advance") and main.clock.scale() >= 25.0, "J: advancing at x%d" % int(main.clock.scale()))
	_ok(String(main.status_flags()).contains("ADVANCING UNTIL EVENT") and String(main.time_label()).contains("▸▸"), "the command bar says so: ×%s  %s" % [String(main.time_label()), String(main.status_flags())])
	var p0: Vector3 = main.sub.global_position
	var t0: float = main.clock.seconds
	for _i in 60:
		main.call("_process", 1.0 / 30.0)
	var dt: float = main.clock.seconds - t0
	var moved := Vector2(main.sub.global_position.x - p0.x, main.sub.global_position.z - p0.z).length()
	_ok(dt > 40.0 and absf(moved - main.sub.speed * dt) < 0.15 * main.sub.speed * dt + 30.0,
		"the world runs: %.0f s passed and she sailed %.0f m (no jump)" % [dt, moved])
	if main.get("_advance"):
		main.call("_on_contact_new", _fake_contact("TX1", "ais", 42000.0))
		_ok(main.get("_advance"), "a distant AIS report does not stop it")
		main.call("_on_contact_new", _fake_contact("TX2", "sonar", 9000.0))
	_ok(not main.get("_advance") and main.clock.level == 0, "a new sonar contact stops it, time x1")
	_ok(_logged("Advance until event stopped").contains("new contact"), "and says why: " + _logged("Advance until event stopped"))
	main.call("_toggle_advance")
	main.call("_toggle_advance")
	_ok(not main.get("_advance") and _logged("Advance until event stopped").contains("cancelled"), "J again cancels at once")
	main.call("_toggle_advance")
	main.call("_close_overlay")
	_ok(not main.get("_advance"), "so does Esc")
	main.call("_toggle_advance")
	main.sub.depth = Submarine.SAFE_DEPTH + 25.0
	main.call("_advance_watch")
	_ok(not main.get("_advance") and _logged("Advance until event stopped").contains("safe depth"), "below safe depth it stops")
	main.sub.depth = 60.0
	main.call("_toggle_advance")
	main.set("_advance_from", main.clock.seconds - 13.0 * 3600.0)
	main.call("_advance_watch")
	_ok(not main.get("_advance") and _logged("Advance until event stopped").contains("twelve hours"), "nobody runs unattended for ever: stops after twelve hours")
	main._battle = true
	main._update_alert()
	main.call("_toggle_advance")
	_ok(not main.get("_advance"), "refused at battle stations")
	_quiet()


func _chart_search() -> void:
	print("chart search")
	var ch: ChartView = main.chart
	var r: Array[Dictionary] = ch.search("storoya")
	_ok(not r.is_empty() and String(r[0]["label"]) == "STORØYA", "'storoya' finds STORØYA")
	if not r.is_empty():
		ch.select_result(r[0])
		var pos: Vector3 = r[0]["pos"]
		var c: Vector2 = ch.get("_center")
		_ok(c.distance_to(Vector2(pos.x, pos.z)) < 1.0 and String(ch.highlighted().get("label", "")) == "STORØYA", "selecting it centres and marks it")
	var labels := func(q: String) -> Array:
		return ch.search(q).map(func(e: Dictionary) -> String: return String(e["label"]))
	_ok((labels.call("harbour") as Array).has("LONGHAMN"), "harbours")
	var ports: Array = labels.call("port")
	_ok(ports.has("LONGHAMN") and ports.has("HALVMÅNEØYA ANCHORAGE"), "'port' finds harbours and the naval anchorage")
	_ok((labels.call("wreck") as Array).size() >= 4, "hazards: %d wrecks" % (labels.call("wreck") as Array).size())
	_ok((labels.call("kestrel") as Array).has("PATROL SECTOR KESTREL"), "navigation areas")
	_ok((labels.call("hvaltoppen") as Array).size() >= 1, "named shoals")
	ch.route.clear()
	ch.route.append(Vector3(1000, 0, -1000))
	ch.route.append(Vector3(3000, 0, -5000))
	_ok((labels.call("wp2") as Array).has("WP2"), "waypoints")
	ch.route.clear()
	var held := 0
	for c2 in main.sensors.contacts:
		if c2.kind == "VESSEL" and c2.range_err <= 0.3:
			held += 1
			_ok(ch.search(c2.id).size() >= 1, "a plotted contact: %s" % c2.id)
			break
	if held == 0:
		print("        (no plotted contact at this moment)")
	var leaks := 0
	for v in main.vessels:
		var s := v as SurfaceShip
		if s.vessel_name != "" and main.sensors.contact_for(s) == null and not ch.search(s.vessel_name).is_empty():
			leaks += 1
	_ok(leaks == 0, "ships the boat does not hold are not found by name")
	var ex: Array = ch.search("anchorage")
	_ok(not ex.is_empty() and (main.area.geo as Geography).coast_distance((ex[0]["pos"] as Vector3).x, (ex[0]["pos"] as Vector3).z) > 0.0, "charted places sit on the water's edge, not inland")
	_ok(ch.search("zzzqqq").is_empty(), "nothing invented for a nonsense query")
	ch.toggle_legend()
	_ok(ch.legend_open, "G opens the legend")
	ch.toggle_legend()
	_ok(not ch.legend_open, "and closes it")


func _briefing_save() -> void:
	print("the briefing")
	_quiet()
	main.patrol.queue_message("chk_pending", main.clock.seconds + 99999.0, "NORTHERN COMMAND", SECRET)
	var b: Dictionary = main.briefing(false)
	var heads: Array = (b["sections"] as Array).map(func(s: Array) -> String: return String(s[0]).split("  ")[0])
	_ok(heads.has("ORDERS") and heads.has("OBJECTIVES") and heads.has("LOCATION") and heads.has("KNOWN THREATS")
		and heads.has("RECENT DEVELOPMENTS") and heads.has("OUTSTANDING") and heads.has("THE BOAT"), "all its parts: " + ", ".join(heads))
	_ok(not JSON.stringify(b).contains(SECRET), "a message not yet received is not in it")
	_ok(main.save_game(SLOT), "saved")
	_path = SaveSystem.slot_path(SLOT)


func _briefing_load() -> void:
	var ok: bool = main2.call("_load_game", _path)
	_ok(ok and main2.briefing_panel.visible, "loading a campaign opens the briefing")
	var t: String = main2.briefing_panel.text()
	_ok(t.contains("OBJECTIVES") and t.contains("THE BOAT") and String(main2.briefing(true)["subtitle"]).contains("Welcome back"), "Miller introduces it")
	_ok(not t.contains(SECRET), "nothing pending is disclosed")
	main2.briefing_panel.dismiss()
	# An older save without this mission's state still briefs.
	var d := SaveSystem.read_path(_path)
	d.erase("pursuit")
	main2.apply_state(d)
	_ok(main2.briefing_panel.visible and main2.pursuit.level == 0, "an older save (no pursuit record) loads and is briefed")
	main2.briefing_panel.dismiss()
