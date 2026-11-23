class_name FireControl
extends RefCounted
## The attack party's estimate of the target in the crosshair. Bearing comes
## from the periscope (accurate); range from the stadimeter; course (angle on
## the bow) and speed from watching her, tightened by the sonar's motion
## analysis. Errors shrink with observation and grow with distance, darkness,
## poor visibility and sea state; a turn is only noticed after a while. The
## torpedo's lead is computed from these ESTIMATES through a model of the
## torpedo's own run (its turn after launch included), never from the truth.
##
## "Solution quality" says how well her motion is known, as the expected
## spread of the aim point at the intercept. It is not a probability of a hit:
## a firm solution still misses if she turns after launch, if the seeker
## fails, or if she is out of reach.

const LEVELS := ["NONE", "POOR", "FAIR", "GOOD", "FIRM"]
const HOLD_TIME := 90.0             # an estimate is kept this long off the crosshair

var target: SurfaceShip
var obs_time := 0.0
var range_sd := 0.12                # fraction of range
var course_sd := 35.0               # degrees
var speed_sd := 5.0                 # knots
var est_range := 0.0
var est_course := 0.0               # degrees true
var est_speed := 0.0                # knots
var est_pos := Vector3.ZERO
var bearing := 0.0                  # radians, last periscope bearing
var held := 0.0                     # seconds since last observed
var rng := RandomNumberGenerator.new()
var _k := Vector3.ZERO              # standing errors (normalised) for this target
var _course_track := 0.0            # radians, lags behind a turn


func _init() -> void:
	rng.randomize()


func reset() -> void:
	target = null
	obs_time = 0.0
	held = 0.0


## Conditions factor: 1 in clear daylight and calm seas, larger otherwise.
static func conditions(weather: Weather) -> float:
	if weather == null:
		return 1.0
	var vis := clampf(weather.visibility_m() / 8000.0, 0.15, 1.0)
	var hs := float(weather.current.get("hs", 1.5))
	return 1.0 + 0.7 * (1.0 - vis) + 0.5 * weather.darkness() + 0.35 * clampf(hs / 4.0, 0.0, 1.5)


## One look through the periscope at `ship` (with the sonar's contact on her,
## if any, for its motion analysis).
func observe(ship: SurfaceShip, own: Vector3, dt: float, cond: float, contact: Contact) -> void:
	if ship != target:
		target = ship
		obs_time = 0.0
		_k = Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
		_course_track = ship.heading
	held = 0.0
	obs_time += dt
	var rel := ship.global_position - own
	var dist := Vector2(rel.x, rel.z).length()
	bearing = atan2(rel.x, -rel.z)
	range_sd = (0.10 * exp(-obs_time / 25.0) + 0.025) * (1.0 + dist / 7000.0) * cond
	course_sd = (32.0 * exp(-obs_time / 40.0) + 3.5) * cond
	speed_sd = (4.5 * exp(-obs_time / 60.0) + 0.7) * cond
	if contact and contact.status == "TRACKING":
		match contact.cs_conf:
			"HIGH", "AIS":
				course_sd = minf(course_sd, 6.0)
				speed_sd = minf(speed_sd, 1.2)
			"MED":
				course_sd = minf(course_sd, 14.0)
				speed_sd = minf(speed_sd, 2.5)
	# A turn takes a while to notice.
	_course_track = lerp_angle(_course_track, ship.heading, clampf(dt / 15.0, 0.0, 1.0))
	est_range = maxf(dist * (1.0 + range_sd * _k.x), 50.0)
	est_course = fposmod(rad_to_deg(_course_track) + course_sd * _k.y, 360.0)
	est_speed = maxf(ship.speed / 0.5144 + speed_sd * _k.z, 0.0)
	est_pos = own + Vector3(sin(bearing), 0.0, -cos(bearing)) * est_range


## Off the crosshair: the estimate ages (dead-reckoned, less certain).
func age(dt: float) -> void:
	if target == null:
		return
	held += dt
	obs_time = maxf(obs_time - dt * 0.5, 0.0)
	var v := Vector3(sin(deg_to_rad(est_course)), 0.0, -cos(deg_to_rad(est_course))) * est_speed * 0.5144
	est_pos += v * dt
	course_sd += dt * 0.05
	speed_sd += dt * 0.01
	if held > HOLD_TIME:
		reset()


func has_solution() -> bool:
	return target != null and obs_time > 2.0


## Expected spread (m, one sigma) of where she will be when the torpedo arrives.
func spread() -> float:
	if not has_solution():
		return INF
	var run_t := est_range / Torpedo.RUN_SPEED
	var sp := est_speed * 0.5144
	var e_r := est_range * range_sd * 0.5
	var e_c := sp * run_t * deg_to_rad(course_sd)
	var e_s := speed_sd * 0.5144 * run_t
	return sqrt(e_r * e_r + e_c * e_c + e_s * e_s)


func quality() -> String:
	var s := spread()
	if s == INF:
		return "NONE"
	if s < 25.0:
		return "FIRM"
	if s < 60.0:
		return "GOOD"
	if s < 150.0:
		return "FAIR"
	return "POOR"


## 0..1 for meters and bars (FIRM = 1).
func quality_value() -> float:
	return float(LEVELS.find(quality())) / 4.0


func summary() -> String:
	if not has_solution():
		return "NO SOLUTION"
	return "RNG %.1f KM ±%d%%  ·  CRS %03d ±%d°  ·  SPD %.0f KT ±%.0f" % [est_range / 1000.0, int(round(range_sd * 100.0)), int(est_course), int(round(course_sd)), est_speed, speed_sd]


## The gyro course to order, from the estimates, allowing for the torpedo's
## turn after launch (iterated through a model of its run).
func lead(from: Transform3D) -> Dictionary:
	if not has_solution():
		return {}
	var vel := Vector3(sin(deg_to_rad(est_course)), 0.0, -cos(deg_to_rad(est_course))) * est_speed * 0.5144
	var o := from.origin
	var c := atan2(est_pos.x - o.x, -(est_pos.z - o.z))
	var res := {}
	for _i in 8:
		res = Torpedo.predict(from, c, est_pos, vel)
		if res.is_empty():
			break
		var tp: Vector3 = est_pos + vel * float(res["t"])
		var a_t := atan2(tp.x - o.x, -(tp.z - o.z))
		var tq: Vector3 = res["pos"]
		var a_q := atan2(tq.x - o.x, -(tq.z - o.z))
		c += wrapf(a_t - a_q, -PI, PI)
	if res.is_empty():
		return {}
	res["course"] = c
	return res
