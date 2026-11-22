class_name Dialogue
extends Node
## Spoken lines with priorities. Reports interrupt chatter; people are only
## overheard in the captain's compartment; important reports reach the captain
## by intercom. Recorded voice is used when a line has one.

signal line_shown(speaker: String, color: Color, text: String, channel: String)

enum P { AMBIENT, CONVERSATION, REPORT, CRITICAL }

var crew: Crew
var audio: AudioManager
var captain_location := "control"
var log_lines: Array[String] = []

var _queue: Array[Dictionary] = []
var _remaining := 0.0
var _current_priority := -1


func say(who: String, text: String, priority: int = P.REPORT, voice: String = "", intercom_ok: bool = true) -> void:
	if priority >= P.CRITICAL:
		_queue = _queue.filter(func(q: Dictionary) -> bool: return int(q["priority"]) >= P.REPORT)
		if _current_priority < P.CRITICAL:
			_remaining = minf(_remaining, 0.15)
	elif priority >= P.REPORT:
		_queue = _queue.filter(func(q: Dictionary) -> bool: return int(q["priority"]) >= P.CONVERSATION)
		if _current_priority <= P.AMBIENT:
			_remaining = minf(_remaining, 0.3)
	if priority <= P.CONVERSATION and _queue.size() > 3:
		return
	_queue.append({"who": who, "text": text, "priority": priority, "voice": voice, "intercom": intercom_ok})


## Queue a multi-line exchange (all-or-nothing, heard only where it happens).
func converse(lines: Array) -> void:
	if not _queue.is_empty() or _remaining > 0.0:
		return
	for l in lines:
		_queue.append({"who": String(l[0]), "text": String(l[1]), "priority": P.CONVERSATION, "voice": "", "intercom": false})


func busy() -> bool:
	return _remaining > 0.0 or not _queue.is_empty()


func _process(delta: float) -> void:
	if _remaining > 0.0:
		_remaining -= delta
		if _remaining > 0.0:
			return
		_current_priority = -1
	while not _queue.is_empty():
		var q: Dictionary = _queue.pop_front()
		if _present(q):
			return
	_current_priority = -1


## Show/play one line. Returns true if it was delivered (so the queue waits).
func _present(q: Dictionary) -> bool:
	var who := String(q["who"])
	var m: CrewMember = crew.members.get(who) if crew else null
	var loc := m.location if m else "control"
	var channel := ""
	var priority := int(q["priority"])
	if loc != captain_location:
		if priority >= P.REPORT and bool(q["intercom"]):
			channel = "INTERCOM"
		else:
			return false
	var text := String(q["text"])
	var dur := 1.8 + text.length() * 0.055
	var voice := String(q["voice"])
	if voice != "" and audio:
		var vlen := audio.play_voice(voice, crew.audio_loc(loc), channel == "INTERCOM")
		dur = maxf(dur, vlen + 0.4)
	var speaker := m.short if m else who.capitalize()
	var color := m.color if m else Color(0.8, 0.85, 0.9)
	line_shown.emit(speaker, color, text, channel)
	log_lines.append("%s: %s" % [speaker, text])
	if log_lines.size() > 60:
		log_lines.pop_front()
	_remaining = dur
	_current_priority = priority
	return true
