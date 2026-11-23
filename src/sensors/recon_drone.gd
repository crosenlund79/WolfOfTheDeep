class_name ReconDrone
extends RefCounted
## A small battery quadcopter carried as trial equipment (two aboard). It is
## launched and recovered by hand from the bridge, so only with the boat
## surfaced, slow and in a moderate sea. It flies low, sees what its camera
## can see in the weather and light (ships and ice; nothing under water),
## and answers to a radio link that reaches a few kilometres and that others
## may notice. It can be lost: to the wind or icing, a flat battery, a lost
## link, or a boat that dives without it.

signal event(kind: String, text: String)

const CARRIED := 2
const SPEED := 14.0                  # m/s
const ENDURANCE := 22.0 * 60.0       # s, mild conditions
const LINK_RANGE := 6000.0           # m from the boat
const RECOVER_R := 40.0
const MAX_LAUNCH_KT := 6.0
const MAX_HS := 2.5                  # m, launch and recovery from the bridge
const MAX_WIND := 12.0               # m/s
const NOTICE_R := 6000.0             # a warship may notice it within this

var left := CARRIED
var state := "stowed"                # stowed / airborne / returning
var pos := Vector3.ZERO
var target := Vector3.ZERO
var battery := 1.0
var endurance := ENDURANCE
var _risk_t := 0.0
var _warned_low := false
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func airborne() -> bool:
	return state == "airborne" or state == "returning"


## Wind estimated from the sea state (fully developed sea): a rough guide.
static func wind(weather: Weather) -> float:
	return sqrt(maxf(float(weather.current.get("hs", 1.5)), 0.0) * 46.7)


static func _icing(weather: Weather) -> bool:
	return weather.condition in ["snow", "fog"]


## Why it cannot go up now ("" if it can).
func launch_blocker(sub: Submarine, weather: Weather) -> String:
	if airborne():
		return "the drone is already up"
	if left <= 0:
		return "no drones left aboard"
	if not sub.is_surfaced():
		return "the boat must be surfaced: it is launched by hand from the bridge"
	if sub.knots() > MAX_LAUNCH_KT + 0.5:
		return "too fast for a hand launch; slow to %d kt or less" % int(MAX_LAUNCH_KT)
	if float(weather.current.get("hs", 1.5)) > MAX_HS:
		return "the sea is too rough to launch or recover from the bridge"
	if wind(weather) > MAX_WIND:
		return "too much wind for the drone"
	return ""


func launch(sub: Submarine, weather: Weather) -> bool:
	if launch_blocker(sub, weather) != "":
		return false
	left -= 1
	state = "airborne"
	pos = Vector3(sub.global_position.x, 0.0, sub.global_position.z)
	target = pos
	battery = 1.0
	_warned_low = false
	# Cold, icing and wind all shorten its flight.
	var w := wind(weather)
	endurance = ENDURANCE * 0.85 * (0.7 if _icing(weather) else 1.0) * clampf(1.0 - (w - 6.0) / 20.0, 0.6, 1.0)
	event.emit("launched", "Reconnaissance drone launched from the bridge; about %d minutes in the air in these conditions. %d left aboard." % [int(endurance / 60.0), left])
	return true


## Send it to a point (held within the link's reach of the boat).
func send_to(p: Vector3, boat: Vector3) -> void:
	if not airborne():
		return
	var rel := Vector3(p.x - boat.x, 0.0, p.z - boat.z)
	if rel.length() > LINK_RANGE * 0.9:
		rel = rel.normalized() * LINK_RANGE * 0.9
	target = Vector3(boat.x, 0.0, boat.z) + rel
	state = "airborne"


func recall() -> void:
	if airborne():
		state = "returning"


func range_from(boat: Vector3) -> float:
	return Vector2(pos.x - boat.x, pos.z - boat.z).length()


## How far its camera makes out a ship in this light and weather.
func eye(vis: float, dark: float) -> float:
	return minf(vis * lerpf(1.0, 0.3, dark), 6000.0)


func advance(dt: float, sub: Submarine, weather: Weather, vessels: Array[Node3D]) -> void:
	if not airborne():
		return
	var boat := Vector3(sub.global_position.x, 0.0, sub.global_position.z)
	if not sub.is_surfaced():
		_lose("The boat dived with the drone still up; it could not be recovered and came down in the sea.")
		return
	var goal := boat if state == "returning" else target
	var to := Vector3(goal.x - pos.x, 0.0, goal.z - pos.z)
	var step := SPEED * dt
	pos = goal if to.length() <= step else pos + to.normalized() * step
	battery -= dt / endurance
	var home := range_from(boat)
	if state == "returning" and home < RECOVER_R:
		if sub.knots() <= MAX_LAUNCH_KT + 0.5 and float(weather.current.get("hs", 1.5)) <= MAX_HS:
			state = "stowed"
			left += 1
			event.emit("recovered", "Drone recovered on the bridge with %d%% battery left." % int(battery * 100.0))
			return
	if home > LINK_RANGE * 1.15:
		_lose("Link lost beyond range; the drone did not come back.")
		return
	if battery <= 0.0:
		_lose("Drone battery exhausted before it could be recovered; it came down in the sea.")
		return
	# Turn for home with enough charge to get there.
	if state == "airborne" and battery * endurance < home / SPEED * 1.3 + 90.0:
		state = "returning"
		if not _warned_low:
			_warned_low = true
			event.emit("returning", "Drone turning back on its battery.")
	_risk_t += dt
	if _risk_t >= 60.0:
		_risk_t -= 60.0
		var p := clampf((wind(weather) - 8.0) / 40.0, 0.0, 0.15) + (0.02 if _icing(weather) else 0.0)
		if rng.randf() < p:
			_lose("Drone lost: %s." % ("icing" if _icing(weather) and rng.randf() < 0.5 else "a gust put it into the sea"))
			return
	# Foreign warships near it may notice it (radar, lookouts, its radio
	# link): a drone over the sea means a launcher not far away.
	for n in vessels:
		var s := n as SurfaceShip
		if s == null or s.state != SurfaceShip.State.SAILING or s.ais_on:
			continue
		if s.kind != SurfaceShip.Kind.FRIGATE and s.kind != SurfaceShip.Kind.PATROL:
			continue
		if Vector2(s.global_position.x - pos.x, s.global_position.z - pos.z).length() < NOTICE_R:
			s.suspicion = minf(s.suspicion + dt / 900.0, 1.2)
			s.suspicion_changed.emit(s, s.suspicion)


func _lose(why: String) -> void:
	state = "stowed"
	event.emit("lost", why)


func save_state() -> Dictionary:
	return {"left": left}


func load_state(d: Dictionary) -> void:
	left = int(d.get("left", CARRIED))
	state = "stowed"
