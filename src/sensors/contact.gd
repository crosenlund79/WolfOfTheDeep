class_name Contact
extends RefCounted
## What the boat believes about one contact. Never exposes the truth directly:
## positions are estimates with uncertainty, classification takes time.

var id := ""
var kind := "VESSEL"          # VESSEL, BIO, ICE
var vessel: SurfaceShip       # truth (internal use only: scoring, sensors)
var berg: Dictionary = {}
var status := "TRACKING"      # TRACKING, LOST
var first_time := 0.0
var last_time := 0.0
var bearing := 0.0            # degrees true, last measurement
var range_est := 0.0
var range_err := 0.55         # fraction of range
var est_pos := Vector3.ZERO
var classification := "UNKNOWN"
var class_progress := 0.0
var identified_name := ""
var ais := {}                 # name, type, course, speed when received
var sources := {}             # sonar / visual / ais / ice
var snr := 0.0
var bias_dir := Vector2.RIGHT
var announced := false
var classify_announced := false
## Target motion analysis: estimated positions over time -> course / speed.
var track: Array = []          # [t, x, z]
var est_course := -1.0         # degrees true, -1 = unknown
var est_speed := -1.0          # knots, -1 = unknown
var cs_conf := ""              # "", LOW, MED, HIGH (or AIS)
## Perceived affiliation: UNKNOWN, NEUTRAL, SUSPECT, HOSTILE, FRIENDLY (set by
## classification and intelligence, never from hidden truth).
var affiliation := "UNKNOWN"
var notes := ""


func label() -> String:
	if identified_name != "":
		return identified_name
	return classification


func certainty_text() -> String:
	if kind == "ICE":
		return "ICE"
	if identified_name != "":
		return "IDENTIFIED"
	if class_progress >= 1.0:
		return "CLASSIFIED"
	if class_progress >= 0.35:
		return "PROBABLE"
	return "UNCLASSIFIED"


func position_known() -> bool:
	return sources.has("visual") or sources.has("ais") or kind == "ICE" or range_err < 0.2


## Fold a new position estimate into the motion solution.
func add_fix(t: float, p: Vector3) -> void:
	if not track.is_empty() and t - float(track[-1][0]) < 60.0:
		return
	track.append([t, p.x, p.z])
	if track.size() > 14:
		track.pop_front()
	if ais.has("course"):
		return
	if track.size() < 3 or range_err > 0.3:
		est_course = -1.0
		est_speed = -1.0
		cs_conf = ""
		return
	var span := float(track[-1][0]) - float(track[0][0])
	if span < 240.0:
		return
	# Least-squares velocity over the stored fixes.
	var n := float(track.size())
	var mt := 0.0
	var mx := 0.0
	var mz := 0.0
	for f in track:
		mt += float(f[0])
		mx += float(f[1])
		mz += float(f[2])
	mt /= n
	mx /= n
	mz /= n
	var stt := 0.0
	var stx := 0.0
	var stz := 0.0
	for f in track:
		var dt := float(f[0]) - mt
		stt += dt * dt
		stx += dt * (float(f[1]) - mx)
		stz += dt * (float(f[2]) - mz)
	if stt <= 0.0:
		return
	var vx := stx / stt
	var vz := stz / stt
	est_speed = Vector2(vx, vz).length() / 0.5144
	est_course = fposmod(rad_to_deg(atan2(vx, -vz)), 360.0)
	if est_speed < 0.6:
		est_course = -1.0
	cs_conf = "HIGH" if range_err < 0.1 and span > 900.0 else ("MED" if range_err < 0.2 else "LOW")


## Course / speed as the crew would state it.
func motion_text() -> String:
	if ais.has("course"):
		return "%03d / %4.1f AIS" % [int(ais["course"]), float(ais["speed"])]
	if est_speed < 0.0:
		return "---  / --.-"
	if est_course < 0.0:
		return "STOPPED?"
	return "%03d / %4.1f %s" % [int(round(est_course)) % 360, est_speed, cs_conf]


func save_state() -> Dictionary:
	return {
		"id": id, "kind": kind, "vessel": vessel.uid if vessel else "", "berg": String(berg.get("id", "")),
		"status": status, "first": first_time, "last": last_time, "bearing": bearing, "range_est": range_est,
		"range_err": range_err, "est_pos": SaveSystem.v3(est_pos), "class": classification, "class_progress": class_progress,
		"name": identified_name, "ais": ais, "sources": sources, "snr": snr, "bias": SaveSystem.v2(bias_dir),
		"announced": announced, "classify_announced": classify_announced, "track": track, "course": est_course,
		"speed": est_speed, "cs_conf": cs_conf, "affiliation": affiliation, "notes": notes,
	}


func load_state(d: Dictionary) -> void:
	id = String(d.get("id", id))
	kind = String(d.get("kind", kind))
	status = String(d.get("status", status))
	first_time = float(d.get("first", 0.0))
	last_time = float(d.get("last", 0.0))
	bearing = float(d.get("bearing", 0.0))
	range_est = float(d.get("range_est", 0.0))
	range_err = float(d.get("range_err", 0.55))
	est_pos = SaveSystem.to_v3(d.get("est_pos"))
	classification = String(d.get("class", "UNKNOWN"))
	class_progress = float(d.get("class_progress", 0.0))
	identified_name = String(d.get("name", ""))
	ais = d.get("ais", {})
	sources = d.get("sources", {})
	snr = float(d.get("snr", 0.0))
	bias_dir = SaveSystem.to_v2(d.get("bias"), Vector2.RIGHT)
	announced = bool(d.get("announced", true))
	classify_announced = bool(d.get("classify_announced", false))
	track = d.get("track", [])
	est_course = float(d.get("course", -1.0))
	est_speed = float(d.get("speed", -1.0))
	cs_conf = String(d.get("cs_conf", ""))
	affiliation = String(d.get("affiliation", "UNKNOWN"))
	notes = String(d.get("notes", ""))
