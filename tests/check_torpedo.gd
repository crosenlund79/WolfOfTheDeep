extends SceneTree
## Practical check of the torpedo firing chain (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_torpedo.gd
## Controlled engagements through the game's own chain: the attack party
## watches the target (fire-control estimates with their errors), fires with
## the computed lead, and the run is simulated against the moving ship.
## Covers hits at large gyro angles and long range, reach, manoeuvring
## targets, evidence-based miss reports, telemetry loss, diagnostics kept out
## of normal play, large time steps and the meaning of solution quality.

var main: Node
var frame := 0
var failures := 0


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
	_run()
	print("TORPEDO CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	return true


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


## One engagement. Returns the engagement record (and leaves logs in main).
func _engage(kind: int, rng: float, aob: float, rel_brg: float, kts: float, opts: Dictionary = {}) -> Dictionary:
	var sub: Submarine = main.sub
	var enc: Encounter = main.encounter
	var cond := String(opts.get("cond", "clear"))
	main.weather.set_condition(cond)
	main.weather.current = main.weather.call("_compose_arctic")
	main.weather._process(0.016)
	sub.position = Vector3(60000.0, -10.6, 150000.0)
	sub.depth = 10.6
	sub.heading = 0.0
	sub.speed = 3.0 * Submarine.KNOT
	var ship := SurfaceShip.new()
	ship.kind = kind as SurfaceShip.Kind
	ship.ocean = main.ocean
	ship.recycle = false
	main.add_child(ship)
	var brg := deg_to_rad(rel_brg)
	var tp := sub.position + Vector3(sin(brg), 0.0, -cos(brg)) * rng
	var hdg := brg + PI + deg_to_rad(aob)
	ship.place(Vector3(tp.x, 0.0, tp.z), hdg, kts)
	ship.set_route([Vector3(tp.x, 0, tp.z) + Vector3(sin(hdg), 0, -cos(hdg)) * 80000.0], false, kts)
	ship.speed = kts * 0.5144
	var keep: Array[Node3D] = enc.ships.duplicate()
	enc.ships.clear()
	enc.ships.append(ship)
	enc.unlimited = true
	enc.reload = 0.0
	enc.dev_diag = bool(opts.get("dev", false))
	enc.fc.reset()
	enc.fc.rng.seed = int(opts.get("seed", 1))
	var dt := float(opts.get("dt", 0.25))
	# Watch her through the periscope for a while.
	var watch := float(opts.get("watch", 90.0))
	var t := 0.0
	var cf := FireControl.conditions(main.weather)
	while t < watch:
		ship.advance(dt, sub.position)
		enc.fc.observe(ship, sub.global_position, dt, cf, null)
		t += dt
	var main_rig: CameraRig = main.rig
	main_rig.bearing = enc.fc.bearing
	var n0 := enc.engagements.size()
	enc.call("fire")
	var rec: Dictionary = enc.engagements[n0] if enc.engagements.size() > n0 else {}
	var turn_at := float(opts.get("turn_at", -1.0))
	var turned := false
	t = 0.0
	while t < 700.0 and not rec.is_empty() and String(rec["state"]) not in ["hit", "miss_confirmed", "unknown"]:
		if turn_at >= 0.0 and t > turn_at and not turned:
			turned = true
			var nh := ship.heading + deg_to_rad(float(opts.get("turn", 60.0)))
			ship.set_route([ship.position + Vector3(sin(nh), 0, -cos(nh)) * 80000.0], false, kts)
		if bool(opts.get("hard_turn", false)) and t > 5.0 and t < 25.0:
			sub.heading += deg_to_rad(6.0) * dt
		main.ocean.advance(dt)
		ship.advance(dt, sub.position)
		enc.advance(dt, false)
		if bool(opts.get("keep_watching", false)):
			enc.fc.observe(ship, sub.global_position, dt, cf, null)
		t += dt
	# Let the assessment follow.
	for _i in 4:
		enc.advance(dt, false)
	rec["ship"] = ship
	enc.ships.clear()
	enc.ships.append_array(keep)
	ship.queue_free()
	return rec


func _logged(prefix: String) -> String:
	for i in range(main.captain_log.entries.size() - 1, -1, -1):
		var e: Dictionary = main.captain_log.entries[i]
		if String(e["text"]).begins_with(prefix):
			return String(e["text"])
	return ""


func _run() -> void:
	var K := SurfaceShip.Kind
	print("solution quality means what it says")
	var fc := FireControl.new()
	var ship := SurfaceShip.new()
	ship.kind = K.MERCHANT
	main.add_child(ship)
	ship.place(Vector3(1000.0, 0.0, -3000.0), 1.5, 12.0)
	fc.observe(ship, Vector3.ZERO, 3.0, 1.0, null)
	var s_early := fc.spread()
	for i in 30:
		fc.observe(ship, Vector3.ZERO, 3.0, 1.0, null)
	var s_late := fc.spread()
	_ok(s_late < s_early, "watching her tightens the solution (%.0f m → %.0f m spread)" % [s_early, s_late])
	var fc2 := FireControl.new()
	for i in 31:
		fc2.observe(ship, Vector3.ZERO, 3.0, 2.2, null)
	_ok(fc2.spread() > s_late, "in poor visibility the same watch gives a looser one (%.0f m)" % fc2.spread())
	_ok(fc.quality() in FireControl.LEVELS and not fc.summary().contains("%%"), "quality is %s, with its error bars: %s" % [fc.quality(), fc.summary()])
	ship.queue_free()

	print("hits on a steady target, whatever the geometry")
	var cases := [
		[K.MERCHANT, 1500.0, 90.0, 0.0, 12.0],
		[K.MERCHANT, 1500.0, 90.0, 120.0, 12.0],     # far abaft the beam: big turn after launch
		[K.MERCHANT, 2000.0, 45.0, -40.0, 15.0],
		[K.FRIGATE, 2500.0, 60.0, -30.0, 14.0],
		[K.PATROL, 2500.0, 70.0, 80.0, 11.0],
		[K.MERCHANT, 6000.0, 80.0, 30.0, 12.0],      # long range, within reach
		[K.TRAWLER, 1200.0, 90.0, 10.0, 3.5],
		[K.RESEARCH, 3500.0, 100.0, 45.0, 6.0],
	]
	var hits := 0
	var shots := 0
	for c in cases:
		for sd in [3, 11]:
			var r := _engage(c[0], c[1], c[2], c[3], c[4], {"seed": sd})
			shots += 1
			if String(r.get("state", "")) == "hit":
				hits += 1
			else:
				print("        miss: %s %.0f m aob %.0f brg %.0f %.0f kt (solution %s)" % [["MERCH", "FRIG", "TRAWL", "RSRCH", "PATROL", "SUB"][c[0]], c[1], c[2], c[3], c[4], String(r.get("quality", "?"))])
	_ok(float(hits) / float(shots) >= 0.85, "steady targets with a watched solution: %d of %d hit" % [hits, shots])

	print("a hurried solution in poor conditions")
	var hits_p := 0
	for sd2 in [21, 22, 23, 24, 25, 26, 27, 28]:
		var rp := _engage(K.MERCHANT, 3000.0, 60.0, 35.0, 18.0, {"seed": sd2, "watch": 4.0, "cond": "snow"})
		if String(rp.get("state", "")) == "hit":
			hits_p += 1
	_ok(hits_p < hits * 8 / shots, "a 4-second look in snow does worse than a watched solution: %d of 8 hit" % hits_p)

	print("only what can be seen can be tracked")
	var enc: Encounter = main.encounter
	var sub: Submarine = main.sub
	main.weather.set_condition("fog")
	main.weather.current = main.weather.call("_compose_arctic")
	sub.position = Vector3(60000.0, -10.6, 150000.0)
	sub.depth = 10.6
	sub.set_periscope(true)
	for _i in 60:
		sub.advance(0.1)
	var ghost := SurfaceShip.new()
	ghost.kind = K.MERCHANT
	main.add_child(ghost)
	ghost.place(sub.position + Vector3(0.0, 0.0, -3000.0), 1.5, 10.0)
	var keep2: Array[Node3D] = enc.ships.duplicate()
	enc.ships.clear()
	enc.ships.append(ghost)
	(main.rig as CameraRig).bearing = 0.0
	enc.advance(0.25, true)
	_ok(enc.locked == null, "in fog a ship 3 km off cannot be locked (visibility %.0f m)" % main.weather.visibility_m())
	main.weather.set_condition("clear")
	main.weather.current = main.weather.call("_compose_arctic")
	enc.advance(0.25, true)
	_ok(enc.locked == ghost or sub.periscope_state() != Submarine.Scope.CLEAR, "in clear weather she can")
	enc.ships.clear()
	enc.ships.append_array(keep2)
	ghost.queue_free()

	print("the same at high time compression (one-second steps)")
	var r2 := _engage(K.PATROL, 2000.0, 90.0, 20.0, 11.0, {"seed": 5, "dt": 1.0})
	_ok(String(r2.get("state", "")) == "hit", "one-second steps still hit (no tunnelling through the hull)")

	print("reach")
	var r3 := _engage(K.MERCHANT, 16000.0, 90.0, 0.0, 0.0, {"seed": 2, "watch": 60.0})
	_ok(_logged("Launch confirmed, T%d" % int(r3["n"])).contains("beyond the weapon's reach"), "firing beyond reach is called out at launch")
	_ok(String(r3.get("state", "")) == "miss_confirmed", "the run completes without detonating: a confirmed miss (telemetry)")
	_ok(_logged("Post-attack assessment, T%d" % int(r3["n"])).contains("beyond the weapon's reach"), "and the assessment says why, from the plot")

	print("a target that turns after launch")
	var r4 := _engage(K.MERCHANT, 3500.0, 90.0, 10.0, 14.0, {"seed": 4, "turn_at": 20.0, "turn": 70.0, "keep_watching": true})
	if String(r4.get("state", "")) != "hit":
		var a4 := _logged("Post-attack assessment, T%d" % int(r4["n"]))
		_ok(a4.contains("altered course") and a4.contains("observed"), "the assessment reports the course change we saw: " + a4.substr(0, 120))
	else:
		print("  ok    (the seeker caught her despite the turn)")
	_ok(_logged("T%d: seeker enabled" % int(r4["n"])) != "", "seeker telemetry is reported")

	print("no telemetry, no certainty")
	var r5 := _engage(K.MERCHANT, 16000.0, 90.0, 0.0, 0.0, {"seed": 6, "watch": 60.0, "hard_turn": true})
	_ok(String(r5.get("state", "")) == "unknown", "with the wire parted and nothing heard, the result is unknown (%s)" % String(r5.get("state", "")))
	_ok(_logged("T%d: guidance wire parted" % int(r5["n"])) != "", "the parted wire is reported")

	print("diagnostics stay out of normal play")
	var a3 := _logged("Post-attack assessment, T%d" % int(r3["n"]))
	_ok(not a3.contains("[DEV]") and not a3.contains("closest approach"), "normal play: no exact miss distance")
	var r6 := _engage(K.MERCHANT, 16000.0, 90.0, 0.0, 0.0, {"seed": 7, "watch": 60.0, "dev": true})
	_ok(_logged("Post-attack assessment, T%d" % int(r6["n"])).contains("[DEV] closest approach"), "developer mode: exact technical outcome")
	main.encounter.dev_diag = false
