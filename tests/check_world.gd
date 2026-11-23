extends SceneTree
## Practical check of the Arctic region and navigation (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_world.gd
## Chart / seabed agreement (tiles, contours, soundings, terrain tiles),
## coordinates and navigation arithmetic, collisions (grounding at high time
## compression, icebergs, the pack-ice lid), time compression coherence and
## caps, and the hull pressure model.

var main: Node
var frame := 0
var steps: Array[Callable] = []
var failures := 0
var _wait_until := -1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			main.call("_begin_patrol")
			main.briefing_panel.dismiss(),
		_check_seabed_agreement,
		_check_chart_tiles,
		_wait_soundings,
		_check_soundings,
		_check_coordinates,
		_check_collisions,
		_check_grounding_at_speed,
		_check_time,
		_check_pressure,
		_check_ice_advice,
	]


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if _wait_until > 0:
		if frame < _wait_until:
			return false
		_wait_until = -1
	if steps.is_empty():
		print("WORLD CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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


func _geo() -> Geography:
	return main.area.geo


# --- chart and physical seabed agree ----------------------------------------------

func _check_seabed_agreement() -> void:
	print("seabed / chart agreement")
	var geo := _geo()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var same := true
	for i in 400:
		var x := rng.randf_range(-299000.0, 299000.0)
		var z := rng.randf_range(-299000.0, 299000.0)
		if not is_equal_approx(main.area.seabed_depth(x, z), geo.depth(x, z)):
			same = false
	_ok(same, "physical seabed depth == chart geography at 400 points across the region")
	# Streamed seabed tiles carry exactly the charted depth at their vertices.
	var st: TerrainStreamer = main.area.streamer
	var origin := Vector2(120000.0, 56000.0)      # over the Hvalryggen seamount
	st._build("check_s", origin, 4000.0, 41, "s")
	var r := _take(st, "check_s")
	var worst := 0.0
	var hs: PackedFloat32Array = r["h"]
	var step := 4000.0 / 40.0
	for j in 41:
		for i in 41:
			var d := geo.depth(origin.x + i * step, origin.y + j * step)
			var want := -d if d > 0.0 else -1.5
			worst = maxf(worst, absf(hs[j * 41 + i] - want))
	_ok(worst < 0.01, "streamed seabed tile matches the chart depth (worst %.3f m)" % worst)
	# The seamount is where the chart says, and shoal.
	var crest := geo.depth(Geography.SEAMOUNT.x * 1000.0, Geography.SEAMOUNT.y * 1000.0)
	_ok(crest > 25.0 and crest < 55.0, "Hvaltoppen seamount crest about 38 m (got %.1f)" % crest)
	# Islands are land on the physical seabed too.
	var land := 0
	for isl in geo.islands:
		var c: Vector2 = isl["c"]
		if geo.depth(c.x, c.y) < 0.0 and main.area.seabed_depth(c.x, c.y) < 0.0:
			land += 1
	_ok(land == geo.islands.size(), "every charted island is land in the world (%d/%d)" % [land, geo.islands.size()])


func _take(obj: Object, k: String) -> Dictionary:
	var m: Mutex = obj.get("_mutex")
	var arr: Array = obj.get("_done")
	m.lock()
	var found := {}
	for r in arr:
		if String(r["key"]) == k:
			found = r
	arr.erase(found)
	m.unlock()
	return found


func _check_chart_tiles() -> void:
	print("chart tiles: contours and tints follow the seabed")
	var geo := _geo()
	var data: ChartData = main.chart.data
	# Detailed tiles (patrol area, seamount, island coasts) and overview tiles.
	var specs := [[8, 128, 128], [8, 179, 152], [8, 90, 77], [8, 74, 51], [6, 24, 16], [6, 32, 32], [4, 3, 3], [2, 0, 0]]
	var total := 0
	var good := 0
	var total_o := 0
	var good_o := 0
	var land_ok := 0
	var land_n := 0
	for sp in specs:
		var k := "check_%d_%d_%d" % [sp[0], sp[1], sp[2]]
		data._build(k, sp[0], sp[1], sp[2], false)
		var r := _take(data, k)
		var size := float(r["size"])
		var origin: Vector2 = r["origin"]
		var spacing := size / float(ChartData.N - 1)
		var lines: Dictionary = r["lines"]
		var detailed := int(sp[0]) >= 6
		for lv in lines.keys():
			var segs: PackedVector2Array = lines[lv]
			var n := 0
			while n < segs.size():
				var p := segs[n]
				# The true depth at the contour point is close to the contour value
				# (allowing for the slope across one grid cell).
				var e := spacing * 0.5
				var slope := absf(geo.depth(p.x + e, p.y) - geo.depth(p.x - e, p.y)) + absf(geo.depth(p.x, p.y + e) - geo.depth(p.x, p.y - e))
				var tol := maxf(1.0, slope * 1.5 + float(lv) * 0.02)
				var hit := absf(geo.depth(p.x, p.y) - float(lv)) <= tol
				if detailed:
					total += 1
					good += 1 if hit else 0
				else:
					total_o += 1
					good_o += 1 if hit else 0
				n += 2 if n < 400 else 23      # sample long lists sparsely
		# Land tint exactly where the seabed is land (away from the coastline itself).
		var img: Image = r["img"]
		for t in 300:
			var px := (t * 37) % ChartData.PX
			var py := (t * 53) % ChartData.PX
			var w := origin + Vector2(px, py) / float(ChartData.PX - 1) * size
			var d := geo.depth(w.x, w.y)
			if absf(d) < spacing * 0.15 + 3.0:
				continue
			land_n += 1
			var c := img.get_pixel(px, py)
			var is_land := c.is_equal_approx(ChartData.tint(-1.0, false))
			if is_land == (d < 0.0):
				land_ok += 1
	_ok(total > 500 and total_o > 500, "contour points sampled: %d detailed, %d overview" % [total, total_o])
	_ok(float(good) / float(maxi(total, 1)) > 0.98, "detailed charts: contour points on their depth %.1f%%" % (100.0 * good / maxf(total, 1)))
	_ok(float(good_o) / float(maxi(total_o, 1)) > 0.9, "overview charts (generalised): %.1f%%" % (100.0 * good_o / maxf(total_o, 1)))
	_ok(float(land_ok) / float(maxi(land_n, 1)) > 0.97, "land/sea tint agrees with the seabed: %d/%d" % [land_ok, land_n])


func _wait_soundings() -> void:
	_wait_until = frame + 2
	var data: ChartData = main.chart.data
	if not data._soundings_ready:
		steps.push_front(_wait_soundings)


func _check_soundings() -> void:
	print("soundings: stable, true to the seabed, dense where surveyed")
	var geo := _geo()
	var data: ChartData = main.chart.data
	var n := data.sounding_count()
	_ok(n > 5000, "soundings on the chart: %d" % n)
	var all := data.soundings_in(Rect2(-300000.0, -300000.0, 600000.0, 600000.0), 0.0, 1000000)
	var worst := 0.0
	var sum := 0.0
	for s in all:
		var d := geo.depth(float(s[0]), float(s[1]))
		worst = maxf(worst, absf(float(s[2]) - d))
		sum += float(s[0]) * 0.001 + float(s[2])
	_ok(worst <= 1.0, "every sounding equals the seabed below it (worst %.2f m)" % worst)
	# A second chart from a fresh geography is identical (not randomised per run).
	var other := ChartData.new(Geography.new())
	var t0 := Time.get_ticks_msec()
	while not other._soundings_ready and Time.get_ticks_msec() - t0 < 60000:
		OS.delay_msec(50)
	other.poll()
	var all2 := other.soundings_in(Rect2(-300000.0, -300000.0, 600000.0, 600000.0), 0.0, 1000000)
	var sum2 := 0.0
	for s in all2:
		sum2 += float(s[0]) * 0.001 + float(s[2])
	other.shutdown()
	_ok(all2.size() == all.size() and is_equal_approx(sum, sum2), "soundings identical between runs (%d, checksum %.1f)" % [all2.size(), sum2])
	# Density: coastal / surveyed water versus remote deep water.
	var coastal := 0
	var remote := 0
	for s in all:
		var x := float(s[0])
		var z := float(s[1])
		if maxf(absf(x), absf(z)) < 45000.0:
			continue
		var cd := geo.coast_distance(x, z)
		if cd < 10000.0:
			coastal += 1
		elif cd > 60000.0 and geo.survey_distance(x, z) > 15000.0:
			remote += 1
	# Compare per area: estimate both areas by sampling.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var a_coast := 0
	var a_remote := 0
	for i in 6000:
		var x2 := rng.randf_range(-300000.0, 300000.0)
		var z2 := rng.randf_range(-300000.0, 300000.0)
		if maxf(absf(x2), absf(z2)) < 45000.0 or geo.depth(x2, z2) <= 0.0:
			continue
		var cd2 := geo.coast_distance(x2, z2)
		if cd2 < 10000.0:
			a_coast += 1
		elif cd2 > 60000.0 and geo.survey_distance(x2, z2) > 15000.0:
			a_remote += 1
	var dens_c := float(coastal) / maxf(float(a_coast), 1.0)
	var dens_r := float(remote) / maxf(float(a_remote), 1.0)
	_ok(dens_c > dens_r * 5.0, "coastal soundings far denser than remote (%.2f vs %.2f per sample area)" % [dens_c, dens_r])
	_ok(remote > 0, "remote water still has scattered soundings (%d)" % remote)


# --- coordinates and navigation arithmetic ---------------------------------------

func _check_coordinates() -> void:
	print("coordinates and navigation arithmetic")
	var ll0 := Geography.latlon(0.0, 0.0)
	_ok(is_equal_approx(ll0.x, 76.5) and is_equal_approx(ll0.y, 25.0), "origin at 76°30'N 025°00'E")
	var lln := Geography.latlon(0.0, -1852.0)
	_ok(absf((lln.x - ll0.x) * 60.0 - 1.0) < 0.01, "one nautical mile north = one minute of latitude")
	var lle := Geography.latlon(1852.0, 0.0)
	_ok(absf((lle.y - ll0.y) * 60.0 * cos(deg_to_rad(76.5)) - 1.0) < 0.01, "one nautical mile east = sec(lat) minutes of longitude")
	_ok(_geo().in_region(299000.0, -299000.0) and not _geo().in_region(301000.0, 0.0), "region spans 600 × 600 km")
	var span := absf(Geography.latlon(0.0, -300000.0).x - Geography.latlon(0.0, 300000.0).x)
	_ok(absf(span - 600000.0 / 111000.0) < 0.01, "region spans %.2f° of latitude" % span)
	var a := Vector3(1000.0, 0.0, 2000.0)
	var l1 := ChartView.leg(a, a + Vector3(18520.0, 0.0, 0.0))
	var l2 := ChartView.leg(a, a + Vector3(0.0, 0.0, -9260.0))
	var l3 := ChartView.leg(a, a + Vector3(-5000.0, 0.0, 5000.0))
	_ok(absf(float(l1["brg"]) - 90.0) < 0.01 and absf(float(l1["dist"]) - 18520.0) < 0.01, "leg due east: 090°, 10.0 nm")
	_ok(absf(float(l2["brg"])) < 0.01 or absf(float(l2["brg"]) - 360.0) < 0.01, "leg due north: 000°")
	_ok(absf(float(l3["brg"]) - 225.0) < 0.01, "leg south-west: 225°")
	_ok(absf(ChartView.hours(18520.0, 10.0) - 1.0) < 0.001, "10 nm at 10 kt takes 1 h")
	var ch: ChartView = main.chart
	var saved: Array = ch.route.duplicate()
	ch.route.clear()
	var p0: Vector3 = main.sub.global_position
	ch.route.append(p0 + Vector3(0.0, 0.0, -3704.0))
	ch.route.append(p0 + Vector3(3704.0, 0.0, -3704.0))
	_ok(absf(ch.route_total() - 7408.0) < 1.0, "multi-waypoint route total 4.0 nm (got %.2f)" % (ch.route_total() / 1852.0))
	ch.route.clear()
	ch.route.append_array(saved)
	# Screen <-> world mapping round trip.
	var w := ch.screen_to_world(ch.w2s(12345.0, -6789.0))
	_ok(absf(w.x - 12345.0) < 0.01 and absf(w.z + 6789.0) < 0.01, "chart screen/world mapping round-trips")


# --- collisions ------------------------------------------------------------------

func _hull_at(pos: Vector3, depth: float, heading: float) -> Array:
	var sub: Submarine = main.sub
	sub.position = Vector3(pos.x, -depth, pos.z)
	sub.depth = depth
	sub.heading = heading
	sub.rotation.y = -heading
	return sub.hull_points()


func _check_collisions() -> void:
	print("collisions: seabed, icebergs, pack ice")
	var area: ArcticArea = main.area
	var sm := Geography.SEAMOUNT * 1000.0
	var info := area.hull_collision(_hull_at(Vector3(sm.x, 0.0, sm.y), 60.0, 0.0), 3.6)
	_ok(String(info.get("kind", "")) == "seabed", "hull at 60 m over the 38 m seamount hits the bottom")
	var info2 := area.hull_collision(_hull_at(Vector3(sm.x, 0.0, sm.y), 20.0, 0.0), 3.6)
	_ok(info2.is_empty(), "hull at 20 m clears the seamount")
	# On the seamount's flank the contact normal follows the slope.
	var flank := Vector3(sm.x + 1500.0, 0.0, sm.y)
	var fd := _geo().depth(flank.x, flank.z)
	var info3 := area.hull_collision(_hull_at(flank, fd + 2.0, 0.0), 3.6)
	var nrm: Vector3 = info3.get("normal", Vector3.UP)
	_ok(not info3.is_empty() and nrm.y < 0.999, "seabed contact normal follows the slope (%.3f, %.3f, %.3f)" % [nrm.x, nrm.y, nrm.z])
	# Iceberg: hit above the keel, clear below it.
	var bp := Vector3(60000.0, 0.0, 40000.0)
	var b := area.add_berg(bp, 70.0, 90.0)
	var hit := area.hull_collision(_hull_at(bp + Vector3(0.0, 0.0, 40.0), 40.0, 0.0), 3.6)
	_ok(String(hit.get("kind", "")) == "ice" and hit.has("berg"), "hull at 40 m under a 90 m keel berg hits ice")
	var clear := area.hull_collision(_hull_at(bp + Vector3(0.0, 0.0, 40.0), 120.0, 0.0), 3.6)
	_ok(clear.is_empty() or not clear.has("berg"), "hull at 120 m passes under the 90 m keel")
	# The berg's mesh follows the same profile the collisions use.
	var mesh: ArrayMesh = area.call("_berg_mesh", b)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var good := 0
	var n := 0
	for vtx in verts:
		if absf(vtx.y) < 2.0 or vtx.y > float(b["h"]) * 0.6 or -vtx.y > float(b["keel"]) * 0.85:
			continue
		var want := ArcticArea.berg_radius_at(b, vtx.y)
		if want < 5.0:
			continue
		n += 1
		var ratio := Vector2(vtx.x, vtx.z).length() / want
		if ratio > 0.6 and ratio < 1.5:
			good += 1
	_ok(n > 200 and float(good) / float(n) > 0.9, "the berg's shape follows its collision profile (%d/%d)" % [good, n])
	_ok(verts.size() > 0 and verts[verts.size() - 1].y < -float(b["keel"]) * 0.9, "and its keel reaches the depth the chart gives")
	area.bergs.erase(b)
	area.call("_rebuild_grid")
	# Pack ice: a lid at the surface, open water below it.
	var pz := _geo().ice_edge_z(0.0) - 14000.0
	var pk := Vector3(0.0, 0.0, pz)
	_ok(_geo().ice_cover(pk.x, pk.z) > 0.9, "close pack north of the ice edge (cover %.2f)" % _geo().ice_cover(pk.x, pk.z))
	var lid := area.hull_collision(_hull_at(pk, 2.05, 0.0), 3.6)
	_ok(bool(lid.get("pack", false)), "surfacing under close pack hits the ice")
	var below := area.hull_collision(_hull_at(pk, 60.0, 0.0), 3.6)
	_ok(not bool(below.get("pack", false)), "at 60 m under the pack there is no contact")
	# The boat is pushed back down under the pack.
	var sub: Submarine = main.sub
	_hull_at(pk, 2.05, 0.0)
	sub.set_target_depth(2.05)
	for i in 20:
		main.call("_sim_step", 0.25)
	_ok(sub.depth > 11.0, "under pack ice the boat cannot surface (depth %.1f m)" % sub.depth)
	_reset_sub()


func _reset_sub() -> void:
	var sub: Submarine = main.sub
	sub.position = Vector3(0.0, -60.0, 20000.0)
	sub.depth = 60.0
	sub.set_target_depth(60.0)
	sub.hull = 100.0
	sub.leak = 0.0
	sub.flooding = 0.0
	sub.stress = 0.0
	sub.speed = 0.0
	sub.set_speed_step(0)
	sub.invulnerable = false
	main.clock.set_level(0)


## Steer at full speed into the seamount at the highest compression: the
## crew warning drops time, and if the captain presses on regardless the boat
## strikes the bottom; it never passes through it.
func _check_grounding_at_speed() -> void:
	print("grounding at high time compression")
	var sub: Submarine = main.sub
	var sm := Geography.SEAMOUNT * 1000.0
	var start := Vector3(sm.x - 6000.0, 0.0, sm.y)
	_hull_at(start, 70.0, PI * 0.5)        # heading east towards the crest
	sub.ordered_heading = PI * 0.5
	sub.helm_auto = true
	sub.set_target_depth(70.0)
	sub.set_speed_step(5)
	sub.speed = float(Submarine.SPEED_STEPS[5]) * Submarine.KNOT
	main.clock.set_level(GameClock.LEVELS.size() - 1)
	var hull0 := sub.hull
	var dropped := false
	var worst := 0.0
	var hit := {"n": 0}      # lambdas capture by value: use a dictionary
	var on_dmg := func(_d: float, _k: String) -> void:
		hit["n"] = int(hit["n"]) + 1
	sub.damaged.connect(on_dmg)
	for i in 400:
		main.call("_process", 0.1)
		if main.clock.level == 0:
			dropped = true
			# The captain ignores the advice (and any other reason to slow down).
			main.clock.set_level(GameClock.LEVELS.size() - 1)
		for p in sub.hull_points():
			var pp: Vector3 = p
			worst = maxf(worst, -pp.y - main.area.seabed_depth(pp.x, pp.z))
		if int(hit["n"]) > 0:
			break
	sub.damaged.disconnect(on_dmg)
	_ok(dropped, "the shoaling warning dropped time compression")
	_ok(int(hit["n"]) > 0 and sub.hull < hull0 - 5.0, "at x%d the boat ran aground on the seamount (hull %.0f%%)" % [int(GameClock.LEVELS[GameClock.LEVELS.size() - 1]), sub.hull])
	_ok(sub.speed < 1.0, "and lost her way (%.1f kt)" % (sub.speed / Submarine.KNOT))
	_ok(worst < 3.0, "no hull point passed through the bottom (worst %.2f m below it)" % worst)
	_reset_sub()


# --- time compression ------------------------------------------------------------

func _check_time() -> void:
	print("time compression")
	var sub: Submarine = main.sub
	var clock: GameClock = main.clock
	sub.position = Vector3(0.0, -60.0, 20000.0)
	sub.heading = 0.0
	sub.ordered_heading = 0.0
	sub.set_speed_step(2)
	sub.speed = float(Submarine.SPEED_STEPS[2]) * Submarine.KNOT
	var coherent := true
	var rates := []
	for lvl in [0, 3, 6, GameClock.LEVELS.size() - 1]:
		clock.set_level(lvl)
		var t0 := clock.seconds
		var p0 := sub.position
		var calls := 0
		while clock.seconds - t0 < 120.0 and calls < 3000:
			main.call("_process", 0.1)
			calls += 1
			if clock.level != lvl:
				coherent = false
				break
		var dt := clock.seconds - t0
		var v := Vector2(sub.position.x - p0.x, sub.position.z - p0.z).length() / maxf(dt, 0.001)
		rates.append(v / Submarine.KNOT)
	var lo: float = rates.min()
	var hi: float = rates.max()
	_ok(coherent, "levels hold while nothing happens")
	_ok(hi - lo < 0.15, "same speed over the ground at x1, x10, x100 and x250: %s kt" % str(rates.map(func(r: float) -> String: return "%.2f" % r)))
	_ok(GameClock.LEVELS.has(100.0) and GameClock.LEVELS.max() >= 250.0, "levels %s" % str(GameClock.LEVELS))
	# The cap follows the situation.
	clock.set_level(GameClock.LEVELS.size() - 1)
	main.crew.silent_running = true
	for i in 30:
		main.call("_process", 0.1)
	_ok(clock.scale() <= 25.0, "at a raised alert compression falls to x%d" % int(clock.scale()))
	main.crew.silent_running = false
	main.call("_set_time_level", GameClock.LEVELS.size() - 1)
	sub.depth = 230.0
	sub.position.y = -230.0
	sub.set_target_depth(230.0)
	main.call("_set_time_level", GameClock.LEVELS.size() - 1)
	_ok(clock.scale() <= 25.0, "below the safe depth compression is limited to x%d" % int(clock.scale()))
	_reset_sub()


# --- pressure ---------------------------------------------------------------------

func _check_pressure() -> void:
	print("hull pressure")
	var sub: Submarine = main.sub
	_reset_sub()
	_ok(absf(sub.collapse_depth() - 380.0) < 0.01, "sound hull: limit about 380 m")
	sub.depth = 200.0
	_ok(sub.pressure_load() == 0.0, "no pressure load at the 200 m safe depth")
	sub.depth = 290.0
	var l_ok := sub.pressure_load()
	sub.hull = 60.0
	var l_dmg := sub.pressure_load()
	_ok(l_dmg > l_ok, "a damaged hull is under more load at the same depth (%.2f > %.2f)" % [l_dmg, l_ok])
	_ok(sub.collapse_depth() < 380.0 * 0.9, "damage lowers the collapse depth (%.0f m)" % sub.collapse_depth())
	# Just past the safe depth: an hour there is survivable.
	_reset_sub()
	seed(12345)
	var events: Array = []
	var on_ev := func(k: String, _d: String) -> void:
		events.append(k)
	sub.pressure_event.connect(on_ev)
	sub.depth = 215.0
	for i in 3600:
		sub.call("_advance_pressure", 1.0)
	_ok(not events.has("collapse") and sub.hull > 80.0, "an hour at 215 m: no collapse (hull %.0f%%, %d failures)" % [sub.hull, events.size()])
	_ok(sub.stress > 0.0, "time below the safe depth builds fatigue (%.4f)" % sub.stress)
	# Deep overdepth for an hour: failures appear.
	_reset_sub()
	events.clear()
	seed(777)
	sub.depth = 340.0
	for i in 3600:
		sub.call("_advance_pressure", 1.0)
		if events.has("collapse"):
			break
	_ok(events.size() >= 2, "an hour at 340 m brings failures (%s)" % str(events))
	# Beyond the limit the hull fails; developer invulnerability prevents it.
	_reset_sub()
	events.clear()
	sub.invulnerable = true
	sub.depth = 400.0
	sub.call("_advance_pressure", 1.0)
	_ok(sub.hull == 100.0 and not events.has("collapse"), "invulnerable: no collapse at 400 m")
	sub.invulnerable = false
	sub.call("_advance_pressure", 1.0)
	_ok(events.has("collapse") and sub.hull == 0.0, "beyond the collapse depth the hull fails")
	sub.pressure_event.disconnect(on_ev)
	_reset_sub()


# --- ice advice ---------------------------------------------------------------------

func _check_ice_advice() -> void:
	print("ice on the track")
	var sub: Submarine = main.sub
	_reset_sub()
	sub.position = Vector3(-150000.0, -60.0, 100000.0)
	sub.heading = 0.0
	sub.rotation.y = 0.0
	sub.speed = float(Submarine.SPEED_STEPS[3]) * Submarine.KNOT
	var ahead := sub.global_position + sub.forward() * 2500.0
	var ch: ChartView = main.chart
	ch.reported_ice.append({"pos": Vector3(ahead.x, 0.0, ahead.z), "r": 80.0, "keel": 70.0, "id": "ICE-CHK", "t": main.clock.seconds})
	var n0: int = main.captain_log.entries.size()
	main.clock.set_level(4)
	main.call("_ice_advice")
	var found := false
	for i in range(n0, main.captain_log.entries.size()):
		var e: Dictionary = main.captain_log.entries[i]
		if String(e["text"]).begins_with("Ice on the track"):
			found = true
	_ok(found, "the navigator reports reported ice on the track with clearance advice")
	_ok(main.clock.level == 0, "the ice warning drops time compression")
	ch.reported_ice.pop_back()
	_reset_sub()
