class_name PursuitAssessment
extends RefCounted
## The crew's judgement of whether the boat is being hunted, from evidence
## they actually have: active sonar heard (and how close it sounded),
## warships held on sonar or seen and closing toward us, foreign patrol
## aircraft about, intelligence of a search, and our own exposure (we fired).
## It never looks at what the other side intends: they may hunt the boat
## without the crew knowing, and the crew may suspect a hunt that isn't one.

const LEVELS := ["NONE", "POSSIBLE SEARCH", "PROBABLE PURSUIT", "CONFIRMED PURSUIT"]
const SHORT := ["NO PURSUIT INDICATION", "POSSIBLE SEARCH", "PROBABLE PURSUIT", "CONFIRMED PURSUIT"]
const HOLD := 900.0                 # once raised, an assessment stands at least this long

var level := 0
var reasons: Array[String] = []
var _pings: Array = []          # [t, estimated distance m]
var _closing := {}              # contact id -> seconds observed closing
var _air_t := -1e9
var _intel_t := -1e9
var _exposed_t := -1e9
var _changed_t := -1e9


func note_ping(t: float, est_dist: float) -> void:
	_pings.append([t, est_dist])


func note_aircraft(t: float) -> void:
	_air_t = t


func note_intel(t: float) -> void:
	_intel_t = t


func note_exposure(t: float) -> void:
	_exposed_t = t


## Re-assess; returns the new level (0..3).
func update(now: float, dt: float, own: Vector3, contacts: Array[Contact]) -> int:
	_pings = _pings.filter(func(p: Array) -> bool: return now - float(p[0]) < 1800.0)
	var score := 0.0
	reasons.clear()
	var near := _pings.filter(func(p: Array) -> bool: return float(p[1]) < 8000.0).size()
	if not _pings.is_empty():
		score += 1.0 + minf(float(_pings.size() - 1), 2.0) * 0.5
		reasons.append("active sonar heard %d time%s in the last half hour" % [_pings.size(), "" if _pings.size() == 1 else "s"])
	if near > 0:
		score += 1.5
		reasons.append("pinging close, within about 8 km")
	var closing_near := false
	for c in contacts:
		if c.kind != "VESSEL" or c.status != "TRACKING" or c.range_est > 12000.0:
			_closing.erase(c.id)
			continue
		if not (c.classification in ["WARSHIP", "UNKNOWN", "SUBMARINE", "SUBMERGED"]) or c.affiliation == "FRIENDLY":
			continue
		var closing := false
		if c.est_course >= 0.0 and c.est_speed > 4.0:
			var to_us := fposmod(rad_to_deg(atan2(own.x - c.est_pos.x, -(own.z - c.est_pos.z))), 360.0)
			closing = absf(wrapf(c.est_course - to_us, -180.0, 180.0)) < 30.0
		_closing[c.id] = float(_closing.get(c.id, 0.0)) + dt if closing else 0.0
		if float(_closing[c.id]) > 120.0:
			score += 1.5 if c.range_est < 6000.0 else 1.0
			reasons.append("%s closing on us%s" % [c.id, " at speed" if c.est_speed > 14.0 else ""])
			if c.range_est < 5000.0:
				closing_near = true
	if now - _air_t < 3600.0:
		score += 1.0
		reasons.append("a foreign patrol aircraft about")
	if now - _intel_t < 12.0 * 3600.0:
		score += 0.7
		reasons.append("intelligence reports a search")
	if now - _exposed_t < 6.0 * 3600.0:
		score += 0.8
		reasons.append("we have given our presence away")
	var l := 0
	if score >= 1.0:
		l = 1
	if score >= 2.5:
		l = 2
	if score >= 4.0 and (near >= 2 or (closing_near and not _pings.is_empty())):
		l = 3
	# A crew does not stand down the moment the evidence pauses.
	if l < level and now - _changed_t < HOLD:
		l = level
	if l != level:
		_changed_t = now
	level = l
	return l


func text() -> String:
	if level == 0:
		return "No pursuit indication."
	return "%s: %s." % [LEVELS[level].capitalize(), ", ".join(reasons)]


func save_state() -> Dictionary:
	return {"level": level, "pings": _pings.duplicate(true), "closing": _closing.duplicate(), "air": _air_t, "intel": _intel_t, "exposed": _exposed_t, "changed": _changed_t}


func load_state(d: Dictionary) -> void:
	level = int(d.get("level", 0))
	var p: Variant = d.get("pings")
	if p is Array:
		_pings = p
	var c: Variant = d.get("closing")
	if c is Dictionary:
		_closing = c
	_air_t = float(d.get("air", -1e9))
	_intel_t = float(d.get("intel", -1e9))
	_exposed_t = float(d.get("exposed", -1e9))
	_changed_t = float(d.get("changed", -1e9))
