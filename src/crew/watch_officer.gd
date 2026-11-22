class_name WatchOfficer
extends Node
## The officer of the watch (normally Miller) runs the boat while the captain
## rests, following the captain's standing orders. Everything it does is
## logged for the morning report; important events wake the captain.

signal wake_captain(reason: String)
signal acted(text: String)

const TICK := 5.0

var sub: Submarine
var sensors: SensorSuite
var area: ArcticArea
var patrol: Patrol
var crew: Crew
var clock: GameClock
var chart: ChartView

var active := false
## Standing orders (toggled in the rest panel).
var orders := {
	"follow_route": true,
	"avoid_contacts": true,
	"go_deep_on_threat": true,
	"charge_battery": true,
	"copy_traffic": true,
	"wake_on_contact": false,
}
var cruise_depth_mode := 3
var cruise_speed := 2
var report: Array[String] = []

var _acc := 0.0
var _evading := 0.0
var _traffic_until := -1.0
var _last_broadcast := ""
var _ice_turn := 0.0
var _ice_t := 0.0
var _shoal_t := 0.0
var _charging := false
var _woken: Dictionary = {}
var _loiter: Array[Vector3] = []
var _loiter_i := 0


func begin() -> void:
	active = true
	report.clear()
	_charging = sub.diesels_running
	_loiter.clear()
	# "We'll maintain course and speed": the captain's settings become the watch's.
	cruise_speed = maxi(sub.speed_step, 1)
	cruise_depth_mode = sub.depth_mode
	note("Assumed the watch. Course %03d, %s, %s." % [_deg(sub.ordered_heading), sub.speed_label().to_lower(), sub.depth_label().to_lower()])


func end() -> void:
	active = false


func note(text: String) -> void:
	report.append("%s  %s" % [clock.short_time(), text])
	acted.emit(text)


static func _deg(rad: float) -> int:
	return int(round(fposmod(rad_to_deg(rad), 360.0))) % 360


func advance(dt: float) -> void:
	if not active:
		return
	_acc += dt
	while _acc >= TICK:
		_acc -= TICK
		_tick()


func _tick() -> void:
	var now := clock.seconds
	_evading = maxf(_evading - TICK, 0.0)
	_ice_t = maxf(_ice_t - TICK, 0.0)
	_shoal_t = maxf(_shoal_t - TICK, 0.0)
	var near := _nearest_vessel()
	var near_range := float(near.get("range", 1e9))
	# 1. Safety of the boat comes first: shoal water and land.
	if _shoal_check():
		return
	if _ice_t > 0.0:
		return
	# 2. Threats: a warship close by or active sonar.
	if orders["go_deep_on_threat"] and near.has("c"):
		var c: Contact = near["c"]
		var threat := c.classification == "WARSHIP" or c.classification == "SUBMARINE" or c.classification == "UNKNOWN" and near_range < 3000.0
		if threat and near_range < 7000.0 and _evading <= 0.0:
			_evade(c, near_range, true)
			return
	if orders["avoid_contacts"] and near.has("c") and near_range < 3500.0 and _evading <= 0.0:
		_evade(near["c"], near_range, false)
		return
	if _evading > 0.0:
		return
	# 3. Copy the scheduled broadcast.
	var h := clock.hours()
	var slot := "%d_%d" % [clock.day(), int(h)]
	var at_broadcast := int(h) % 6 == 0 and fposmod(h, 1.0) < 0.6
	if orders["copy_traffic"] and at_broadcast and slot != _last_broadcast and near_range > 5000.0:
		_last_broadcast = slot
		_traffic_until = now + 1800.0
		_set_depth(1)
		sub.set_periscope(true)
		note("Came to periscope depth to copy the %02d00 broadcast." % int(h))
	if _traffic_until > 0.0:
		if now > _traffic_until:
			_traffic_until = -1.0
			if not _charging:
				sub.set_periscope(false)
				_set_depth(cruise_depth_mode)
				note("Broadcast copied. Returned to patrol depth.")
		else:
			sub.set_periscope(true)
	# 4. Battery.
	if orders["charge_battery"]:
		var safe := near_range > 9000.0
		if not _charging and sub.battery < 40.0 and safe:
			_charging = true
			_set_depth(1)
			sub.snorkel_ordered = true
			note("Battery at %d%%. Snorkelling to charge." % int(sub.battery))
		elif _charging and (sub.battery > 92.0 or not safe):
			_charging = false
			sub.snorkel_ordered = false
			if _traffic_until < 0.0:
				_set_depth(cruise_depth_mode)
			note("Stopped charging at %d%%%s." % [int(sub.battery), "" if safe else ", contact too close"])
	# 5. Navigation: the route, then a slow box patrol where the route ended.
	if orders["follow_route"] and chart and chart.route.is_empty() and not _loiter.is_empty():
		var lp := _loiter[_loiter_i % _loiter.size()]
		var lrel := lp - sub.global_position
		lrel.y = 0.0
		if lrel.length() < 500.0:
			_loiter_i += 1
		else:
			sub.ordered_heading = atan2(lrel.x, -lrel.z)
			sub.helm_auto = true
	elif orders["follow_route"] and chart and not chart.route.is_empty():
		var wp: Vector3 = chart.route[0]
		var rel := wp - sub.global_position
		rel.y = 0.0
		if rel.length() < 500.0:
			chart.route.pop_front()
			chart.route_changed.emit()
			note("Reached waypoint. %d remaining." % chart.route.size())
			if chart.route.is_empty():
				_start_loiter(sub.global_position)
				note("End of the route. Patrolling the area slowly.")
		else:
			var want := atan2(rel.x, -rel.z)
			if absf(wrapf(want - sub.ordered_heading, -PI, PI)) > deg_to_rad(2.0):
				sub.ordered_heading = want
				sub.helm_auto = true
	if not _charging and _traffic_until < 0.0 and sub.depth_mode != cruise_depth_mode and sub.depth_mode != 0:
		_set_depth(cruise_depth_mode)
	var want_speed := 1 if not _loiter.is_empty() and chart and chart.route.is_empty() else cruise_speed
	if sub.speed_step != want_speed and _evading <= 0.0:
		sub.set_speed_step(want_speed)


func _start_loiter(center: Vector3) -> void:
	_loiter.clear()
	_loiter_i = 0
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		_loiter.append(center + Vector3(cos(a), 0.0, sin(a)) * 2500.0)


## Wake the captain once per contact (again only after a couple of hours).
func _wake_for(key: String, text: String) -> void:
	if clock.seconds < float(_woken.get(key, -1e9)) + 7200.0:
		return
	_woken[key] = clock.seconds
	wake_captain.emit(text)


func _set_depth(mode: int) -> void:
	mode = _safe_mode(mode)
	if sub.depth_mode != mode:
		sub.set_depth_mode(mode)


## The deepest ordered depth that keeps 30 m under the keel here and ahead.
func _safe_mode(want: int) -> int:
	var f := sub.forward()
	var water := area.seabed_depth(sub.global_position.x, sub.global_position.z)
	for k: float in [600.0, 1200.0]:
		var p := sub.global_position + f * k
		water = minf(water, area.seabed_depth(p.x, p.z))
	var m := want
	while m > 1 and float(Submarine.DEPTH_MODES[m]["depth"]) > water - 30.0:
		m -= 1
	return m


func _nearest_vessel() -> Dictionary:
	var best := {}
	var best_r := 1e9
	for c in sensors.tracked_vessels():
		var r := c.range_est
		if r < best_r:
			best_r = r
			best = {"c": c, "range": r}
	return best


func _evade(c: Contact, rng: float, deep: bool) -> void:
	_evading = 900.0
	var rel := c.est_pos - sub.global_position
	var brg := atan2(rel.x, -rel.z)
	# Turn away, beam-on or opening, whichever is the smaller turn.
	var away := brg + PI
	var opt_a := brg + PI * 0.5
	var opt_b := brg - PI * 0.5
	var best := away
	for o: float in [opt_a, opt_b]:
		if absf(wrapf(o - sub.heading, -PI, PI)) < absf(wrapf(best - sub.heading, -PI, PI)):
			best = o
	sub.ordered_heading = best
	sub.helm_auto = true
	sub.set_speed_step(1)
	_traffic_until = -1.0
	if _charging:
		_charging = false
		sub.snorkel_ordered = false
	if deep:
		_set_depth(5)
		sub.set_periscope(false)
		note("%s (%s) at about %.1f km. Went deep below the layer, slow, and turned away to %03d." % [c.id, c.label(), rng / 1000.0, _deg(best)])
		if rng < 5000.0:
			_wake_for(c.id, "%s, %s, at about %.1f km. I've taken her deep." % [c.id, c.label().to_lower(), rng / 1000.0])
	else:
		if sub.depth_mode < 3:
			_set_depth(3)
			sub.set_periscope(false)
		note("%s (%s) closing, about %.1f km. Turned away to %03d at slow speed." % [c.id, c.label(), rng / 1000.0, _deg(best)])
		if orders["wake_on_contact"]:
			_wake_for(c.id, "%s at about %.1f km." % [c.id, rng / 1000.0])


## Sensors report ice ahead: turn toward the clearer side.
func on_ice(c: Contact, dist: float, rel_bearing: float) -> void:
	if not active or _ice_t > 0.0:
		return
	_ice_t = 240.0
	var turn := deg_to_rad(40.0) * (-1.0 if rel_bearing > 0.0 else 1.0)
	sub.ordered_heading = sub.heading + turn
	sub.helm_auto = true
	if sub.speed_step > 2:
		sub.set_speed_step(2)
	note("Ice (%s) ahead at %d m. Altered course to %03d." % [c.id, int(dist), _deg(sub.ordered_heading)])
	if dist < 400.0:
		_wake_for("ice", "Ice close aboard. I've altered course.")


func _shoal_check() -> bool:
	if sub.speed_step == 0:
		sub.set_speed_step(1)
	if _shoal_t > 0.0:
		return true
	var f := sub.forward()
	var ahead := sub.global_position + f * 1400.0
	var under := area.seabed_depth(ahead.x, ahead.z)
	var need := sub.depth + 30.0
	var land := area.coast_distance(ahead.x, ahead.z) < 0.0
	var outside := not area.in_area(ahead * 1.0 + f * 1600.0) or ahead.z < area.ice_edge_z(ahead.x) - 400.0
	if outside:
		var home := (patrol.sector_center if patrol else Vector3.ZERO) - sub.global_position
		sub.ordered_heading = atan2(home.x, -home.z)
		sub.helm_auto = true
		_shoal_t = 300.0
		note("Edge of the patrol area (or the pack ice). Turned back to %03d." % _deg(sub.ordered_heading))
		return true
	if not land and under > need:
		return false
	# Pick the side with more water.
	var best_turn := 0.0
	var best_water := -1e9
	for deg: float in [-60.0, 60.0, -110.0, 110.0, 180.0]:
		var hdg := sub.heading + deg_to_rad(deg)
		var p := sub.global_position + Vector3(sin(hdg), 0.0, -cos(hdg)) * 1400.0
		var w := area.seabed_depth(p.x, p.z) - (5000.0 if area.coast_distance(p.x, p.z) < 0.0 else 0.0)
		if w > best_water:
			best_water = w
			best_turn = deg
	sub.ordered_heading = sub.heading + deg_to_rad(best_turn)
	sub.helm_auto = true
	if under < sub.depth + 25.0:
		sub.set_depth_mode(maxi(_safe_mode(sub.depth_mode), 1) if sub.depth_mode > 0 else 0)
	_shoal_t = 300.0
	note("Shoal water ahead. Altered course to %03d." % _deg(sub.ordered_heading))
	return true


## Text Miller reads when the captain wakes.
func morning_report() -> String:
	if report.size() <= 1:
		return "A quiet watch. Nothing to report."
	var lines := report.slice(maxi(report.size() - 8, 1))
	return "\n".join(lines)
