class_name GameClock
extends RefCounted
## Patrol time and the Arctic sun. Late September at ~76.5° N: the sun skims
## the horizon (about 12° at noon) and nights are long enough for aurora.

const LATITUDE := 76.5
const DECLINATION := -1.5
const START_SECONDS := 5.0 * 3600.0 + 35.0 * 60.0
## Awake time compression levels; sleeping uses REST_SCALE.
const LEVELS := [1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0]
const REST_SCALE := 150.0

var seconds := START_SECONDS
var level := 0
## Developer override (0 = use the selected level).
var custom_scale := 0.0


func advance(dt: float) -> void:
	seconds += dt


func scale() -> float:
	if custom_scale > 0.0:
		return custom_scale
	return float(LEVELS[level])


func set_level(l: int) -> void:
	custom_scale = 0.0
	level = clampi(l, 0, LEVELS.size() - 1)


func day() -> int:
	return 1 + int(seconds / 86400.0)


func hours() -> float:
	return fposmod(seconds / 3600.0, 24.0)


func time_string() -> String:
	var h := hours()
	return "DAY %d  %02d:%02d" % [day(), int(h), int(fposmod(h * 60.0, 60.0))]


func short_time() -> String:
	var h := hours()
	return "%02d:%02d" % [int(h), int(fposmod(h * 60.0, 60.0))]


## Sun elevation and azimuth in degrees for local solar time.
func sun() -> Vector2:
	var lat := deg_to_rad(LATITUDE)
	var dec := deg_to_rad(DECLINATION)
	var ha := deg_to_rad((hours() - 12.0) * 15.0)
	var sin_el := sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)
	var el := asin(clampf(sin_el, -1.0, 1.0))
	var cos_az := (sin(dec) - sin(el) * sin(lat)) / maxf(cos(el) * cos(lat), 1e-5)
	var az := acos(clampf(cos_az, -1.0, 1.0))
	if sin(ha) > 0.0:
		az = TAU - az
	return Vector2(rad_to_deg(el), rad_to_deg(az))


func is_night() -> bool:
	return sun().x < -6.0


func save_state() -> Dictionary:
	return {"seconds": seconds}


func load_state(d: Dictionary) -> void:
	seconds = float(d.get("seconds", START_SECONDS))
