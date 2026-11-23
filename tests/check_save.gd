extends SceneTree
## Practical check of campaign saves (no framework):
##   godot --headless --path . -s tests/check_save.gd
## Plays a little, changes the boat, the log, the route, the crew and the
## contacts, saves to a slot, loads into a fresh game and compares. Also checks
## the safe-write fallback (.bak) and that settings are stored separately.

var main: Node
var main2: Node
var frame := 0
var steps: Array[Callable] = []
var failures := 0
var _want := {}
const SLOT := "check_slot"


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			main.call("_begin_patrol")
			main.briefing_panel.dismiss(),
		func() -> void:
			# Make the state distinctive.
			main.clock.seconds += 3.0 * 3600.0
			main.sub.position = Vector3(1234.5, main.sub.position.y, -4321.25)
			main.sub.heading = 1.1
			main.sub.ordered_heading = 1.2
			main.sub.set_target_depth(120.0)
			main.sub.depth = 118.0
			main.sub.set_speed_step(2)
			main.sub.hull = 87.0
			main.sub.equipment["sonar"] = 0.6
			main.sub.battery = 55.0
			main.chart.route.clear()
			main.chart.route.append(Vector3(5000, 0, -9000))
			main.chart.route.append(Vector3(9000, 0, -15000))
			main.chart.planned_knots = 6.0
			var e: Dictionary = main.captain_log.add("NAVIGATION", "Check entry for the save test.", "assessment")
			main.captain_log.set_flag(int(e["id"]), true)
			main.captain_log.set_note(int(e["id"]), "follow up")
			main.captain_log.personal_note("A personal note.")
			(main.crew.members["basse"] as CrewMember).candy["toffee"] = 99
			(main.crew.members["freja"] as CrewMember).conscience["government"] = 0.31
			main.watch.orders["wake_on_contact"] = false
			main.patrol.flags["check_flag"] = true
			main.dev_weather("fog"),
		func() -> void:
			# Let the simulation produce contacts, then save.
			for _i in 240:
				main.call("_sim_step", 1.0)
			_want = {
				"seconds": main.clock.seconds, "x": main.sub.position.x, "z": main.sub.position.z, "heading": main.sub.heading,
				"ordered": main.sub.ordered_heading, "target_depth": main.sub.ordered_depth(), "speed_step": main.sub.speed_step,
				"hull": main.sub.hull, "sonar_eq": main.sub.equipment["sonar"], "route": main.chart.route.size(),
				"planned": main.chart.planned_knots, "log": main.captain_log.entries.size(), "flagged": main.captain_log.count_flagged(),
				"contacts": main.sensors.contacts.size(), "candy": 99, "gov": 0.31, "weather": "fog",
				"ships": _ship_positions(main),
			}
			var ok: bool = main.save_game(SLOT)
			_expect(ok, "save_game writes the slot")
			_expect(FileAccess.file_exists(SaveSystem.slot_path(SLOT)), "save file exists"),
		func() -> void:
			var listed := SaveSystem.list().filter(func(s: Dictionary) -> bool: return s["slot"] == SLOT)
			_expect(listed.size() == 1 and String((listed[0]["meta"] as Dictionary).get("game_time", "")) != "", "save appears in the list with metadata")
			# A fresh game loads it.
			main.queue_free()
			main2 = load("res://scenes/main.tscn").instantiate()
			root.add_child(main2),
		func() -> void:
			var ok: bool = main2.call("_load_game", SaveSystem.slot_path(SLOT))
			_expect(ok, "load succeeds")
			print("    pos want %.2f %.2f got %.2f %.2f" % [float(_want["x"]), float(_want["z"]), main2.sub.position.x, main2.sub.position.z])
			_expect(is_equal_approx(main2.clock.seconds, _want["seconds"]), "game clock restored")
			_expect(absf(main2.sub.position.x - float(_want["x"])) < 0.05 and absf(main2.sub.position.z - float(_want["z"])) < 0.05, "position restored")
			_expect(absf(main2.sub.heading - float(_want["heading"])) < 0.001 and absf(main2.sub.ordered_heading - float(_want["ordered"])) < 0.001, "heading and ordered heading restored")
			_expect(absf(main2.sub.ordered_depth() - float(_want["target_depth"])) < 0.01 and main2.sub.speed_step == int(_want["speed_step"]), "ordered depth and telegraph restored")
			_expect(is_equal_approx(main2.sub.hull, _want["hull"]) and is_equal_approx(float(main2.sub.equipment["sonar"]), _want["sonar_eq"]), "hull and equipment restored")
			_expect(main2.chart.route.size() == int(_want["route"]) and is_equal_approx(main2.chart.planned_knots, _want["planned"]), "route and planned speed restored")
			_expect(main2.captain_log.entries.size() == int(_want["log"]) and main2.captain_log.count_flagged() == int(_want["flagged"]), "captain's log restored with flags")
			var noted: Array = main2.captain_log.entries.filter(func(e: Dictionary) -> bool: return String(e.get("note", "")) == "follow up")
			_expect(noted.size() == 1, "entry note restored")
			_expect(main2.sensors.contacts.size() == int(_want["contacts"]), "contacts restored (%d)" % int(_want["contacts"]))
			_expect(int((main2.crew.members["basse"] as CrewMember).candy["toffee"]) == 99, "crew candy restored")
			_expect(is_equal_approx(float((main2.crew.members["freja"] as CrewMember).conscience["government"]), 0.31), "crew conscience restored")
			_expect(main2.watch.orders["wake_on_contact"] == false and main2.patrol.flags.has("check_flag"), "standing orders and campaign flags restored")
			_expect(main2.weather.condition == "fog", "weather restored")
			var same := true
			var now_ships := _ship_positions(main2)
			for uid in (_want["ships"] as Dictionary).keys():
				if not now_ships.has(uid) or (now_ships[uid] as Vector3).distance_to(_want["ships"][uid]) > 0.1:
					same = false
			_expect(same, "other vessels restored where they were (not regenerated)")
			# Loading does not regenerate events: no new log entries appear from the load itself.
			_expect(main2.captain_log.entries.size() == int(_want["log"]), "loading adds no log entries"),
		func() -> void:
			# Safe writes: a damaged main file falls back to the previous copy.
			main2.save_game(SLOT)
			var f := FileAccess.open(SaveSystem.slot_path(SLOT), FileAccess.WRITE)
			f.store_string("{ this is not json")
			f.close()
			var d := SaveSystem.read_path(SaveSystem.slot_path(SLOT))
			_expect(not d.is_empty() and int(d.get("version", 0)) == SaveSystem.VERSION, "damaged save falls back to the .bak copy")
			SaveSystem.delete(SLOT)
			_expect(not SaveSystem.exists(SLOT), "slot deleted")
			_expect(not FileAccess.file_exists(SaveSystem.slot_path(SLOT) + ".bak"), "backup deleted with the slot")
			Settings.set_v("vol_music", -7.0)
			var cf := ConfigFile.new()
			_expect(cf.load(Settings.PATH) == OK and is_equal_approx(float(cf.get_value("settings", "vol_music")), -7.0), "settings persist separately")
			Settings.set_v("vol_music", 0.0),
	]


func _ship_positions(m: Node) -> Dictionary:
	var out := {}
	for v in m.vessels:
		out[(v as SurfaceShip).uid] = (v as SurfaceShip).position
	return out


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 20 or frame % 10 != 0:
		return false
	if steps.is_empty():
		print("SAVE CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(1 if failures > 0 else 0)
		return false
	var s: Callable = steps.pop_front()
	s.call()
	return false


func _expect(cond: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		failures += 1
