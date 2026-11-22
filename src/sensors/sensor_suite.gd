class_name SensorSuite
extends Node
## The boat's sensors: passive sonar (simplified sonar equation), lookouts /
## periscope, AIS when the masts are up, and the forward ice-avoidance sonar.
## Produces Contacts that hold only what the sensors support.

signal contact_new(c: Contact)
signal contact_classified(c: Contact)
signal contact_identified(c: Contact)
signal contact_lost(c: Contact)
signal ice_warning(c: Contact, dist: float, rel_bearing: float)

const TICK := 2.0
const LOST_AFTER := 200.0

var sub: Submarine
var area: ArcticArea
var weather: Weather
var vessels: Array[Node3D] = []
var clock: GameClock
## Skill of whoever is on the sonar (set by the crew system).
var sonar_skill := 1.0
var sonar_manned := true

var contacts: Array[Contact] = []
var _by_vessel: Dictionary = {}
var _by_berg: Dictionary = {}
var _next_id := 1
var _ice_id := 1
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _heading_log: Array[float] = []


func _ready() -> void:
	_rng.seed = 4040


func advance(dt: float) -> void:
	_t += dt
	while _t >= TICK:
		_t -= TICK
		_tick(TICK)


func _tick(dt: float) -> void:
	var now := clock.seconds
	_heading_log.append(sub.heading)
	if _heading_log.size() > 90:
		_heading_log.pop_front()
	var maneuver := 0.0
	if _heading_log.size() > 10:
		maneuver = absf(wrapf(_heading_log[-1] - _heading_log[0], -PI, PI))
	var vis := weather.visibility_m()
	var dark := weather.darkness()
	var scope_clear := sub.periscope_state() == Submarine.Scope.CLEAR or sub.is_surfaced()
	var masts := sub.masts_up and sub.mast_extension() > 0.9 and (sub.depth < 12.5)
	for n in vessels:
		var v := n as SurfaceShip
		if not v.visible or v.state == SurfaceShip.State.SUNK:
			continue
		var rel := v.global_position - sub.global_position
		var dist := Vector2(rel.x, rel.z).length()
		var true_brg := fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		var heard := false
		var snr := -99.0
		# Passive sonar.
		if not sub.is_surfaced() or sub.speed < 3.0:
			var sl := v.source_level + 10.0 * log(1.0 + v.speed) / log(10.0) * 2.0
			var tl := 20.0 * log(maxf(dist, 50.0)) / log(10.0) + dist * 0.00045
			var target_deep := v.submerged and v.run_depth > Submarine.LAYER_DEPTH
			if (sub.depth > Submarine.LAYER_DEPTH) != target_deep:
				tl += 7.0
			var own := 48.0 + 12.0 * log(1.0 + sub.speed / Submarine.KNOT) / log(10.0) * 1.6
			if sub.diesels_running:
				own += 12.0
			var sea := 50.0 + float(weather.current.get("hs", 1.5)) * 2.5
			var nl := maxf(own, sea)
			snr = sl - tl - nl + 16.0 - 12.0
			if not sonar_manned:
				snr -= 4.0
			var p := smoothstep(-6.0, 4.0, snr)
			heard = _rng.randf() < p
		# Lookouts / periscope.
		var seen := false
		if scope_clear and not v.submerged:
			var eye := vis * lerpf(1.0, 0.3, dark)
			if dark > 0.5:
				eye = maxf(eye, minf(vis, 9000.0) * 0.8)
			var bulk := clampf(v.length / 120.0, 0.4, 1.3)
			seen = dist < eye * bulk and not _occluded(sub.global_position, v.global_position)
		var got_ais := masts and v.ais_on and not v.submerged and dist < 40000.0
		if not (heard or seen or got_ais):
			continue
		var c: Contact = _by_vessel.get(v)
		if c == null:
			c = Contact.new()
			c.id = "S%d" % _next_id
			_next_id += 1
			c.vessel = v
			c.first_time = now
			c.bias_dir = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			c.range_err = 0.55
			contacts.append(c)
			_by_vessel[v] = c
		var was_lost := c.status == "LOST"
		c.status = "TRACKING"
		c.last_time = now
		if heard:
			c.sources["sonar"] = true
			c.snr = snr
			var noise := 1.2 + 3.0 * (1.0 - clampf(snr / 10.0, 0.0, 1.0))
			c.bearing = fposmod(true_brg + _rng.randfn(0.0, noise), 360.0)
			var k := (0.0025 + maneuver * 0.006) * dt * (1.2 if sonar_manned else 0.6)
			c.range_err = maxf(c.range_err * exp(-k * 10.0), 0.08)
			if sonar_manned:
				c.class_progress = minf(c.class_progress + dt / (200.0 / sonar_skill) * clampf(0.6 + snr / 12.0, 0.3, 1.6), 1.0)
		if seen:
			c.sources["visual"] = true
			c.bearing = true_brg
			c.range_err = minf(c.range_err, 0.1)
			c.class_progress = maxf(c.class_progress, 1.0)
		if got_ais:
			c.sources["ais"] = true
			c.ais = {"name": v.vessel_name, "type": _ais_type(v), "course": int(fposmod(rad_to_deg(v.heading), 360.0)), "speed": snappedf(v.speed / Submarine.KNOT, 0.1)}
			c.range_err = 0.02
			if not heard and not seen:
				c.bearing = true_brg
			if c.identified_name == "" and v.vessel_name != "":
				c.identified_name = v.vessel_name
				contact_identified.emit(c)
		# Estimated position: truth displaced by the (shrinking) error.
		var bias := Vector3(c.bias_dir.x, 0.0, c.bias_dir.y) * c.range_err * dist * 0.8
		c.est_pos = v.global_position + bias
		c.range_est = Vector2(c.est_pos.x - sub.global_position.x, c.est_pos.z - sub.global_position.z).length()
		var before := c.classification
		c.classification = _classify(v, c.class_progress)
		if not c.announced or was_lost:
			c.announced = true
			contact_new.emit(c)
		elif c.classification != before and c.class_progress >= 1.0 and not c.classify_announced:
			c.classify_announced = true
			contact_classified.emit(c)
	# Lose contacts that have faded.
	for c2 in contacts:
		if c2.kind == "VESSEL" and c2.status == "TRACKING" and now - c2.last_time > LOST_AFTER:
			c2.status = "LOST"
			c2.sources.clear()
			contact_lost.emit(c2)
	_tick_ice(now, vis, dark, scope_clear)


func _tick_ice(now: float, vis: float, dark: float, scope_clear: bool) -> void:
	var fwd := sub.forward()
	for item in area.ice_near(sub.global_position, maxf(1600.0, vis if scope_clear else 0.0)):
		var b: Dictionary = item["berg"]
		var dist := float(item["dist"])
		var rel: Vector3 = (b["pos"] as Vector3) - sub.global_position
		rel.y = 0.0
		var rel_brg := rad_to_deg(wrapf(atan2(rel.x, -rel.z) - sub.heading, -PI, PI))
		var sonar_sees := not sub.is_surfaced() and dist < 1600.0 and absf(rel_brg) < 55.0 and float(b["keel"]) > sub.depth - 25.0
		var eye_sees := scope_clear and dist < vis * lerpf(1.0, 0.25, dark)
		if not (sonar_sees or eye_sees):
			continue
		var c: Contact = _by_berg.get(b["id"])
		if c == null:
			c = Contact.new()
			c.kind = "ICE"
			c.id = "I%d" % _ice_id
			_ice_id += 1
			c.berg = b
			c.classification = "ICE"
			c.class_progress = 1.0
			c.first_time = now
			contacts.append(c)
			_by_berg[b["id"]] = c
		c.last_time = now
		c.status = "TRACKING"
		c.est_pos = b["pos"]
		c.range_est = dist
		c.bearing = fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		c.sources["ice"] = true
		if sonar_sees and dist < 900.0 and absf(rel_brg) < 35.0 and not sub.is_surfaced():
			ice_warning.emit(c, dist, rel_brg)
		elif eye_sees and dist < 500.0 and absf(rel_brg) < 30.0 and sub.speed > 1.0:
			ice_warning.emit(c, dist, rel_brg)


func _occluded(a: Vector3, b: Vector3) -> bool:
	for i in range(1, 12):
		var p := a.lerp(b, float(i) / 12.0)
		if area.coast_distance(p.x, p.z) < -200.0:
			return true
	return false


static func _classify(v: SurfaceShip, progress: float) -> String:
	if progress < 0.35:
		return "UNKNOWN"
	if progress < 1.0:
		return "SUBMERGED" if v.submerged else "SURFACE"
	match v.kind:
		SurfaceShip.Kind.MERCHANT:
			return "MERCHANT"
		SurfaceShip.Kind.TRAWLER:
			return "FISHING"
		SurfaceShip.Kind.RESEARCH:
			return "RESEARCH"
		SurfaceShip.Kind.SUBMARINE:
			return "SUBMARINE"
		_:
			return "WARSHIP"


static func _ais_type(v: SurfaceShip) -> String:
	match v.kind:
		SurfaceShip.Kind.MERCHANT:
			return "CARGO"
		SurfaceShip.Kind.TRAWLER:
			return "FISHING"
		SurfaceShip.Kind.RESEARCH:
			return "RESEARCH / SURVEY"
		_:
			return "LAW ENFORCEMENT"


## Called when the captain studies a ship through the periscope.
func identify_visual(v: SurfaceShip) -> void:
	var c: Contact = _by_vessel.get(v)
	if c == null:
		return
	c.class_progress = 1.0
	c.classification = _classify(v, 1.0)
	if c.identified_name == "":
		c.identified_name = v.vessel_name if v.vessel_name != "" else c.classification
		contact_identified.emit(c)


func contact_for(v: SurfaceShip) -> Contact:
	return _by_vessel.get(v)


func tracked_vessels() -> Array[Contact]:
	var out: Array[Contact] = []
	for c in contacts:
		if c.kind == "VESSEL" and c.status == "TRACKING":
			out.append(c)
	return out
