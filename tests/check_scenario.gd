extends SceneTree
## Practical check of the test scenarios (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_scenario.gd
## Every preset starts with its parameters, far from the patrol area, with the
## story off, saving refused and diagnostics on; the restart path rebuilds
## the same set-up; and afterwards the save folder and settings are exactly
## as they were and a normal campaign starts as usual.

var main: Node
var frame := 0
var failures := 0
var _before := {}
var _queue: Array = []
var _cur := {}
var _phase := 0
const NO_SLOT := "check_scenario_must_not_exist"


func _initialize() -> void:
	_before = _snapshot()
	_queue = [
		{"preset": "torpedo_range", "opposing": 2, "targets": "static", "distance_km": 2.0, "depth": 1, "speed": 1, "weather": "clear", "light": "day"},
		{"preset": "torpedo_range", "opposing": 3, "targets": "zigzag", "difficulty": "hard", "distance_km": 5.0},
		{"preset": "sub_pursuit", "opposing": 3, "allied": 1, "distance_km": 8.0, "difficulty": "hard", "depth": 4, "speed": 2, "weather": "fog", "light": "night"},
		{"preset": "arctic_nav", "difficulty": "normal", "distance_km": 12.0, "weather": "snow"},
		{"preset": "naval_encounter", "opposing": 2, "allied": 2, "distance_km": 10.0},
		{"preset": "mixed_traffic", "opposing": 1, "allied": 1, "distance_km": 6.0, "weather": "overcast"},
		# The restart path: a pending scenario is rebuilt when the scene loads.
		{"preset": "sub_pursuit", "opposing": 2, "via_pending": true},
	]


func _snapshot() -> Dictionary:
	var d := {}
	SaveSystem.ensure_dir()
	for f in DirAccess.get_files_at(SaveSystem.DIR):
		var p := SaveSystem.DIR + f
		d[p] = [FileAccess.get_modified_time(p), FileAccess.get_file_as_bytes(p).size()]
	d["settings"] = FileAccess.get_modified_time(Settings.PATH) if FileAccess.file_exists(Settings.PATH) else -1
	return d


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _process(_d: float) -> bool:
	frame += 1
	match _phase:
		0:
			if _queue.is_empty():
				_phase = 2
				SaveSystem.pending = {"action": "new"}
				main = load("res://scenes/main.tscn").instantiate()
				root.add_child(main)
				return false
			_cur = _queue.pop_front()
			if bool(_cur.get("via_pending", false)):
				SaveSystem.pending = {"action": "scenario", "cfg": _cur}
			main = load("res://scenes/main.tscn").instantiate()
			root.add_child(main)
			_phase = 1
			frame = 0
		1:
			if frame < 3:
				return false
			if not bool(_cur.get("via_pending", false)):
				main.call("_begin_scenario", _cur)
			main.briefing_panel.dismiss()
			_check_one(_cur)
			main.queue_free()
			_phase = 0
		2:
			if frame < 3:
				return false
			_after_all()
			print("SCENARIO CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
			return true
	return false


func _check_one(c: Dictionary) -> void:
	var cfg := TestScenario.normalised(c)
	print("%s  %s" % [String(cfg["preset"]), JSON.stringify(c)])
	var sc: TestScenario = main.scenario
	_ok(sc != null and sc.preset == String(cfg["preset"]), "the scenario is running" + (" (started from a pending restart)" if bool(c.get("via_pending", false)) else ""))
	if sc == null:
		return
	var sub: Submarine = main.sub
	var patrol: Patrol = main.patrol
	var far := Vector2(sub.global_position.x - patrol.sector_center.x, sub.global_position.z - patrol.sector_center.z).length()
	_ok(far > 80000.0, "far from the patrol area (%.0f km)" % (far / 1000.0))
	_ok(patrol.objectives.size() == 1 and String(patrol.objectives[0]["id"]) == "scenario" and patrol.pending.is_empty(), "its own objective, no campaign orders: " + String(patrol.objectives[0]["text"]))
	_ok(is_equal_approx(sub.depth, float(Submarine.DEPTH_MODES[int(cfg["depth"])]["depth"])) and sub.speed_step == int(cfg["speed"]), "start depth %.0f m and speed step %d as set" % [sub.depth, sub.speed_step])
	_ok(main.weather.condition == String(cfg["weather"]), "weather %s" % main.weather.condition)
	var hr: float = main.clock.hours()
	_ok((String(cfg["light"]) == "day" and absf(hr - 12.0) < 0.1) or (String(cfg["light"]) == "night" and hr < 1.0), "light: %s (%.1f h)" % [String(cfg["light"]), hr])
	var n_opp := sc.ships.filter(func(s: SurfaceShip) -> bool: return sc.roles[s] in ["opposing", "target"]).size()
	var n_ally := sc.ships.filter(func(s: SurfaceShip) -> bool: return sc.roles[s] == "allied").size()
	var want_opp := int(cfg["opposing"]) if String(cfg["preset"]) != "torpedo_range" else maxi(int(cfg["opposing"]), 1)
	if String(cfg["preset"]) in ["sub_pursuit", "naval_encounter"]:
		want_opp = maxi(want_opp, 1)
	_ok(n_opp == want_opp and n_ally == int(cfg["allied"]) * (0 if String(cfg["preset"]) in ["torpedo_range", "arctic_nav"] else 1), "units: %d opposing/targets, %d allied" % [n_opp, n_ally])
	for s in sc.ships:
		_ok(main.vessels.has(s), "%s is part of the world (sensed, simulated, can be hit)" % s.uid)
		break
	_ok(main.encounter.dev_diag and sc.diagnostics(main).contains("[DEV]"), "developer diagnostics on")
	_ok(String(main.briefing(false)["title"]).contains("TEST SCENARIO"), "its own briefing")
	_ok(not main.save_game(NO_SLOT) and main.save_blocker().contains("not saved"), "saving is refused: " + main.save_blocker())
	main.call("_autosave", "leaving")
	_ok(not SaveSystem.exists(NO_SLOT) and _snapshot() == _before, "and nothing reaches the save folder (autosave on leaving too)")
	var stage_before: Dictionary = main.story.stage.duplicate(true)
	match String(cfg["preset"]):
		"torpedo_range":
			_range_shot(sc)
		"sub_pursuit":
			var peak := 0
			for _m in 40:
				for _i in 60:
					main.call("_sim_step", 1.0)
				peak = maxi(peak, main.pursuit.level)
			var hunting := sc.ships.filter(func(s: SurfaceShip) -> bool: return sc.roles[s] == "opposing" and s.behavior == "investigate").size()
			_ok(hunting >= 1, "the hunters are searching (%d still on it after 40 min)" % hunting)
			_ok(peak >= 2, "and the crew assess it from what they hear and see: %s at worst" % PursuitAssessment.SHORT[peak])
		"arctic_nav":
			_ok(sc.bergs_added == 8 and main.chart.route.size() == 1, "%d icebergs placed on the way, waypoint laid" % sc.bergs_added)
			var g: Vector3 = sc.goal
			_ok(g.z < (main.area.geo as Geography).ice_edge_z(g.x), "the waypoint is beyond the pack-ice limit")
			for _i in 600:
				main.call("_sim_step", 1.0)
			_ok(sub.hull > 99.0, "ten minutes on, no grounding or collision")
		_:
			for _i in 600:
				main.call("_sim_step", 1.0)
			_ok(main.sensors.contacts.size() >= 1, "ten minutes on: %d contacts on the plot" % main.sensors.contacts.size())
	_ok(main.story.stage == stage_before and patrol.received.is_empty(), "the story stayed switched off")


func _range_shot(sc: TestScenario) -> void:
	var enc: Encounter = main.encounter
	var target: SurfaceShip = sc.ships[0]
	var cf := FireControl.conditions(main.weather)
	enc.fc.reset()
	enc.fc.rng.seed = 5
	seed(5)
	for _i in 240:
		enc.fc.observe(target, main.sub.global_position, 0.25, cf, null)
	(main.rig as CameraRig).bearing = enc.fc.bearing
	enc.reload = 0.0
	var n0 := enc.engagements.size()
	enc.call("fire")
	var rec: Dictionary = enc.engagements[n0] if enc.engagements.size() > n0 else {}
	var g := 0
	while g < 1200 and not rec.is_empty() and String(rec["state"]) not in ["hit", "miss_confirmed", "unknown"]:
		main.call("_sim_step", 0.25)
		g += 1
	for _i in 20:
		main.call("_sim_step", 0.25)
	var st := String(rec.get("state", ""))
	if String(sc.cfg["targets"]) == "static":
		_ok(st == "hit", "a stopped target at 2 km: %s" % st)
	else:
		_ok(st in ["hit", "miss_confirmed", "unknown"], "a zig-zagging target: %s" % st)
		if st != "hit":
			var a := ""
			for i in range(main.captain_log.entries.size() - 1, -1, -1):
				if String(main.captain_log.entries[i]["text"]).begins_with("Post-attack assessment"):
					a = String(main.captain_log.entries[i]["text"])
					break
			_ok(a.contains("[DEV]"), "and the assessment gives the exact technical outcome: " + a.substr(a.find("[DEV]"), 90))


func _after_all() -> void:
	print("isolation")
	_ok(_snapshot() == _before, "save folder and settings exactly as before the scenarios")
	_ok(main.scenario == null and main.started, "a new campaign afterwards is the campaign")
	_ok(main.patrol.objectives.size() >= 5 and not main.patrol.pending.is_empty(), "with its own orders and objectives (%d)" % main.patrol.objectives.size())
	_ok(main.encounter.dev_diag == bool(Settings.get_v("developer")), "and normal-play diagnostics")
	main.briefing_panel.dismiss()
