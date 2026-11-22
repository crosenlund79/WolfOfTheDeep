class_name Patrol
extends Node
## Patrol orders, objectives, the patrol log, HQ broadcasts (copied only at
## periscope depth with masts up), counter-detection and the debrief. Story
## content lives in a separate, spoiler-marked module.

signal message_received(msg: Dictionary)
signal objectives_changed
signal finished(report: Dictionary)
signal logged(text: String)

var clock: GameClock
var sub: Submarine
var sensors: SensorSuite
var crew: Crew
var dialogue: Dialogue
var audio: AudioManager
var area: ArcticArea
var weather: Weather
var vessels: Array[Node3D] = []

var objectives: Array[Dictionary] = []
var entries: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var received: Array[Dictionary] = []
var flags: Dictionary = {}
var sector_center := Vector3(3500.0, 0.0, -12500.0)
var sector_radius := 7000.0
var rv := Vector3(-13000.0, 0.0, 19500.0)
var deadline := 2.0 * 86400.0 + 20.0 * 3600.0
var counter_detected := false
var done := false
var classified_ids: Dictionary = {}
var _broadcast_hour := -1


func setup() -> void:
	objectives = [
		{"id": "transit", "text": "Transit to Patrol Sector KESTREL, north of Ravnøya toward the ice edge.", "done": false, "failed": false},
		{"id": "survey", "text": "Covert surveillance: classify or identify surface traffic in the sector (0 / 3).", "done": false, "failed": false},
		{"id": "covert", "text": "Remain undetected.", "done": false, "failed": false},
		{"id": "traffic", "text": "Copy HQ traffic at periscope depth (broadcasts every six hours).", "done": false, "failed": false},
		{"id": "return", "text": "Return to RV HOME by Day 3, 20:00.", "done": false, "failed": false},
	]
	log_entry("Patrol began. Orders: covert surveillance of Sector KESTREL. Boat ready in all respects.")
	queue_message("orders_1", clock.seconds + 60.0, "NORTHERN COMMAND", "ROUTINE. VARG: PROCEED SECTOR KESTREL. OBSERVE AND REPORT SURFACE TRAFFIC NEAR ICE EDGE. REMAIN COVERT. RV HOME DAY 3 2000. FISHING ACTIVITY REPORTED ON KESTREL BANK. ICE CONDITIONS VARIABLE.")


func log_entry(text: String) -> void:
	entries.append({"t": clock.time_string(), "text": text})
	logged.emit(text)


func queue_message(id: String, at: float, from: String, text: String) -> void:
	pending.append({"id": id, "at": at, "from": from, "text": text})


func objective(id: String) -> Dictionary:
	for o in objectives:
		if o["id"] == id:
			return o
	return {}


func add_objective(id: String, text: String) -> void:
	if not objective(id).is_empty():
		return
	objectives.insert(objectives.size() - 1, {"id": id, "text": text, "done": false, "failed": false})
	objectives_changed.emit()


func complete(id: String, failed: bool = false) -> void:
	var o := objective(id)
	if o.is_empty() or o["done"] or o["failed"]:
		return
	o["done"] = not failed
	o["failed"] = failed
	objectives_changed.emit()


func can_copy_traffic() -> bool:
	return sub.is_surfaced() or (sub.masts_up and sub.mast_extension() > 0.9 and sub.depth < 12.5)


func in_sector(p: Vector3) -> bool:
	return Vector2(p.x - sector_center.x, p.z - sector_center.z).length() < sector_radius


func advance(_dt: float) -> void:
	if done:
		return
	# Scheduled broadcasts carry whatever is pending.
	var hour := int(clock.hours())
	if hour % 6 == 0 and hour != _broadcast_hour:
		_broadcast_hour = hour
		flags["broadcast_" + str(clock.day()) + "_" + str(hour)] = true
	if can_copy_traffic():
		for m in pending.duplicate():
			if clock.seconds >= float(m["at"]):
				pending.erase(m)
				received.append(m)
				audio.play("sfx_encrypted_message", -4.0)
				message_received.emit(m)
				log_entry("Message received from %s." % m["from"])
				if received.filter(func(r: Dictionary) -> bool: return String(r["from"]) == "NORTHERN COMMAND").size() >= 2:
					complete("traffic")
	# Objectives.
	if not objective("transit")["done"] and in_sector(sub.global_position):
		complete("transit")
		log_entry("Arrived in Sector KESTREL.")
	for c in sensors.contacts:
		if c.kind == "VESSEL" and c.status == "TRACKING" and c.class_progress >= 1.0 and not classified_ids.has(c.id) and in_sector(sub.global_position) and c.range_est < 20000.0:
			classified_ids[c.id] = c.label()
			log_entry("Contact %s classified: %s." % [c.id, c.label()])
	var survey := objective("survey")
	survey["text"] = "Covert surveillance: classify or identify surface traffic in the sector (%d / 3)." % mini(classified_ids.size(), 3)
	if classified_ids.size() >= 3 and not survey["done"]:
		complete("survey")
		log_entry("Surveillance task complete.")
	if counter_detected and not objective("covert")["failed"]:
		complete("covert", true)
	if Vector2(sub.global_position.x - rv.x, sub.global_position.z - rv.z).length() < 1200.0 and objective("transit")["done"]:
		finish("rv")
	elif clock.seconds > deadline + 6.0 * 3600.0:
		finish("overdue")
	elif sub.hull <= 0.0 or sub.flooding >= 0.99:
		finish("lost")


func mark_detected(by: String) -> void:
	if counter_detected:
		return
	counter_detected = true
	log_entry("We believe %s detected us." % by)
	flags["detected_by"] = by


func finish(how: String) -> void:
	if done:
		return
	done = true
	complete("return", how != "rv" or clock.seconds > deadline)
	if how == "rv" and not objective("covert")["failed"]:
		complete("covert")
	finished.emit(evaluate(how))


func evaluate(how: String) -> Dictionary:
	var lines: Array[String] = []
	var grade := 0
	for o in objectives:
		var mark := "COMPLETE" if o["done"] else ("FAILED" if o["failed"] else "NOT COMPLETED")
		lines.append("%s  —  %s" % [mark, o["text"]])
		if o["done"]:
			grade += 1
	return {"how": how, "objectives": lines, "grade": grade, "flags": flags, "log": entries, "time": clock.time_string(), "hull": sub.hull}
