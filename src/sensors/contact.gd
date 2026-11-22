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
