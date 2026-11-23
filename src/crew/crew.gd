class_name Crew
extends Node
## The people aboard: routines, where everyone is, who covers which role,
## sparse ambient talk, meals, Basse's singing, relationships and history.
## Critical functions ask for a ROLE (role_holder), never for a person.

signal meal_called(meal: String)
signal moved

const SAVE_PATH := "user://wolf_crew.json"

var members: Dictionary = {}
var dialogue: Dialogue
var audio: AudioManager
var clock: GameClock
## 0 calm, 1 alert (contacts close / silent running), 2 danger.
var alert := 0
var captain_location := "control"
var captain_asleep := false
var miller_has_conn := false
var poker_session := false
var silent_running := false
## The captain's own sweets for the mess table (persisted with the crew).
var captain_candy := {"liquorice": 4, "chocolate": 10, "toffee": 14}
## Mess Cup winners: [{t, winner}].
var mess_cup: Array = []

var _chatter_t := 40.0
var _song_t := 150.0
var _recent: Array[String] = []
var _meals_done: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_roster()


func _add(id: String, name_v: String, short_v: String, rank_v: String, role_v: String, nat: String, color: Color, principal_v: bool, routine_v: Array, skills_v: Dictionary, covers_v: Array[String], poker_v: Dictionary) -> CrewMember:
	var m := CrewMember.new()
	m.id = id
	m.name = name_v
	m.short = short_v
	m.rank = rank_v
	m.role = role_v
	m.nationality = nat
	m.color = color
	m.principal = principal_v
	m.routine = routine_v
	m.skills = skills_v
	m.covers = covers_v
	m.poker = poker_v
	members[id] = m
	return m


func _build_roster() -> void:
	var c: Array[String] = []
	_add("miller", "Lt Cdr James Miller", "MILLER", "Executive Officer", "XO", "British", Color(0.62, 0.82, 1.0), true,
		[[0, 6, "bunks", "sleeping"], [6, 7, "mess", "breakfast"], [7, 12, "control", "on watch"], [12, 13, "mess", "lunch"], [13, 18, "control", "on watch"], [18, 19, "mess", "dinner"], [19, 24, "control", "on watch"]],
		{"XO": 1.3, "OOW": 1.3, "SONAR": 0.8, "NAVIGATOR": 0.9}, ["OOW"] as Array[String], {"tight": 0.62, "aggro": 0.5, "bluff": 0.18})
	_add("basse", "Bjarne \"Basse\" Mikkelsen", "BASSE", "Chief Cook", "COOK", "Danish", Color(1.0, 0.72, 0.42), true,
		[[5, 21, "mess", "cooking"], [21, 24, "bunks", "sleeping"], [0, 5, "bunks", "sleeping"]],
		{"COOK": 1.5}, c.duplicate(), {"tight": 0.7, "aggro": 0.35, "bluff": 0.12})
	_add("freja", "Lt Freja Lind", "FREJA", "Sonar Officer", "SONAR", "Swedish", Color(0.62, 1.0, 0.78), true,
		[[0, 7, "bunks", "sleeping"], [7, 8, "mess", "breakfast"], [8, 14, "control", "on sonar"], [14, 15, "mess", "lunch"], [15, 19, "control", "on sonar"], [19, 22, "mess", "off duty"], [22, 24, "bunks", "sleeping"]],
		{"SONAR": 1.5}, c.duplicate(), {"tight": 0.55, "aggro": 0.45, "bluff": 0.3})
	_add("erik", "Chief Engineer Erik Solheim", "ERIK", "Chief Engineer", "ENGINEER", "Norwegian", Color(1.0, 0.86, 0.45), true,
		[[0, 6, "bunks", "sleeping"], [6, 7, "mess", "breakfast"], [7, 12, "engine", "in the engine room"], [12, 13, "mess", "lunch"], [13, 18, "engine", "in the engine room"], [18, 21, "mess", "off duty"], [21, 24, "bunks", "sleeping"]],
		{"ENGINEER": 1.4}, c.duplicate(), {"tight": 0.3, "aggro": 0.3, "bluff": 0.1})
	_add("maya", "Lt Maya Chen", "MAYA", "Navigation Officer", "NAVIGATOR", "Canadian", Color(0.92, 0.7, 1.0), true,
		[[0, 6, "bunks", "sleeping"], [6, 12, "control", "at the chart"], [12, 13, "mess", "lunch"], [13, 16, "mess", "studying"], [16, 22, "control", "at the chart"], [22, 24, "bunks", "sleeping"]],
		{"NAVIGATOR": 1.4, "OOW": 1.0}, ["OOW"] as Array[String], {"tight": 0.45, "aggro": 0.7, "bluff": 0.35})
	# Secondary crew: keep the boat running when principals are off watch.
	_add("haugen", "Petty Officer Haugen", "HAUGEN", "Sonar Operator", "WATCH_SONAR", "Norwegian", Color(0.7, 0.9, 0.8), false,
		[[0, 8, "control", "on sonar"], [8, 14, "bunks", "sleeping"], [14, 15, "mess", "eating"], [15, 24, "control", "on sonar"]],
		{"SONAR": 0.9}, ["SONAR"] as Array[String], {"tight": 0.5, "aggro": 0.4, "bluff": 0.2})
	_add("rask", "Able Seaman Rask", "RASK", "Helmsman", "HELM", "Danish", Color(0.8, 0.85, 0.9), false,
		[[0, 24, "control", "at the helm"]], {"HELM": 1.0}, c.duplicate(), {"tight": 0.5, "aggro": 0.5, "bluff": 0.2})
	_add("dahl", "Machinist Dahl", "DAHL", "Machinist", "MACHINIST", "Norwegian", Color(0.85, 0.8, 0.7), false,
		[[0, 24, "engine", "on watch"]], {"ENGINEER": 0.9}, ["ENGINEER"] as Array[String], {"tight": 0.5, "aggro": 0.5, "bluff": 0.2})
	for a in members.values():
		for b in members.values():
			if a != b:
				(a as CrewMember).affinity[(b as CrewMember).id] = 0.2
		(a as CrewMember).affinity["captain"] = 0.3
	# A few established relationships.
	_rel("basse", "erik", -0.05)
	_rel("freja", "maya", 0.55)
	_rel("miller", "maya", 0.45)
	_rel("miller", "erik", 0.5)
	_rel("basse", "freja", 0.4)


func _rel(a: String, b: String, v: float) -> void:
	(members[a] as CrewMember).affinity[b] = v
	(members[b] as CrewMember).affinity[a] = v


func principals() -> Array:
	return ["miller", "basse", "freja", "erik", "maya"].map(func(i: String) -> CrewMember: return members[i])


## Whoever is standing a role right now (principal first, then cover).
func role_holder(role: String) -> CrewMember:
	var best: CrewMember = null
	for m in members.values():
		var cm := m as CrewMember
		if not cm.can_fill(role) or not cm.awake:
			continue
		if cm.role == role and _on_station(cm, role):
			return cm
		if best == null and _on_station(cm, role):
			best = cm
	return best


func _on_station(m: CrewMember, role: String) -> bool:
	match role:
		"SONAR", "WATCH_SONAR", "XO", "OOW", "NAVIGATOR", "HELM":
			return m.location == "control"
		"ENGINEER", "MACHINIST":
			return m.location == "engine" or m.id == "erik"
		"COOK":
			return m.location == "mess"
	return true


func sonar_skill() -> float:
	var h := role_holder("SONAR")
	return h.skill("SONAR") if h else 0.5


func present(loc: String) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m in members.values():
		if (m as CrewMember).location == loc and (m as CrewMember).awake:
			out.append(m)
	return out


func audio_loc(loc: String) -> int:
	match loc:
		"mess":
			return AudioManager.Loc.MESS
		"engine":
			return AudioManager.Loc.ENGINE
		"cabin":
			return AudioManager.Loc.CABIN
	return AudioManager.Loc.CONTROL


## Speak a reaction line for an event, choosing someone who is actually there.
func react(event: String, params: Dictionary = {}, priority: int = Dialogue.P.REPORT) -> void:
	var options: Array = CrewLines.REACTIONS.get(event, [])
	if options.is_empty():
		return
	var usable: Array = []
	for o in options:
		var who := String(o[0])
		var m: CrewMember = members.get(who)
		if m and m.awake and (m.location == "control" or m.location == captain_location or event.begins_with("meal") or who == "erik"):
			usable.append(o)
	if usable.is_empty():
		usable = [options[0]]
	var pick: Array = usable[_rng.randi() % usable.size()]
	var text := String(pick[1]).format(params)
	var voice := String(pick[2]) if pick.size() > 2 else ""
	dialogue.say(String(pick[0]), text, priority, voice)


# --- simulation -------------------------------------------------------------------

func advance(dt: float) -> void:
	var hour := clock.hours()
	var changed := false
	for m in members.values():
		var cm := m as CrewMember
		var slot := cm.routine_at(hour)
		var loc := String(slot[2])
		var act := String(slot[3])
		if alert >= 2:
			# Action stations: everyone to their place.
			if cm.id == "basse":
				loc = "mess"
				act = "securing the galley"
			elif cm.id == "erik" or cm.id == "dahl":
				loc = "engine"
				act = "at action station"
			else:
				loc = "control"
				act = "at action station"
		if cm.id == "miller" and miller_has_conn:
			loc = "control"
			act = "has the conn"
		if poker_session and cm.id in ["basse", "erik", "freja", "maya"] and loc != "control" and loc != "bunks" and alert == 0:
			loc = "mess"
			act = "playing cards"
		cm.awake = loc != "bunks"
		if cm.location != loc:
			cm.location = loc
			changed = true
		cm.activity = act
	if changed:
		moved.emit()
	# Meals, announced once each.
	var key := "%d" % clock.day()
	for meal in [["breakfast", 7.0], ["lunch", 12.0], ["dinner", 18.0]]:
		var mk := key + String(meal[0])
		if hour >= float(meal[1]) and hour < float(meal[1]) + 0.5 and not _meals_done.has(mk):
			_meals_done[mk] = true
			if alert == 0 and not captain_asleep:
				react("meal_" + String(meal[0]), {}, Dialogue.P.REPORT)
			meal_called.emit(String(meal[0]))


## Real-time pacing for talk and song (called every frame).
func ambient(real_dt: float) -> void:
	if captain_asleep:
		return
	_chatter_t -= real_dt
	if _chatter_t <= 0.0:
		_chatter_t = _rng.randf_range(55.0, 150.0) * (2.0 if silent_running else 1.0)
		if alert == 0 and not dialogue.busy():
			_try_chatter()
	_song_t -= real_dt
	if _song_t <= 0.0:
		_song_t = _rng.randf_range(200.0, 520.0)
		_try_song()
	var b: CrewMember = members["basse"]
	if audio.singing() and (alert > 0 or silent_running or b.location != "mess" or not b.awake):
		audio.stop_singing(1.2)


func _try_chatter() -> void:
	var here := present(captain_location)
	if here.is_empty():
		return
	var ids := here.map(func(m: CrewMember) -> String: return m.id)
	var night := clock.is_night()
	var hour := clock.hours()
	# Conversations need everyone in the room.
	if _rng.randf() < 0.45:
		var convs: Array = []
		for cv in CrewLines.CONVERSATIONS:
			if _recent.has(cv["id"]):
				continue
			if String(cv.get("where", "any")) != "any" and String(cv["where"]) != captain_location:
				continue
			if cv.get("night", false) and not night:
				continue
			if cv.get("evening", false) and (hour < 18.0 or hour > 23.0):
				continue
			var ok := true
			for l in cv["lines"]:
				if not ids.has(String(l[0])):
					ok = false
			if ok:
				convs.append(cv)
		if not convs.is_empty():
			var pick: Dictionary = convs[_rng.randi() % convs.size()]
			_mark(pick["id"])
			dialogue.converse(pick["lines"])
			var speakers: Array = []
			for l in pick["lines"]:
				if not speakers.has(l[0]):
					speakers.append(l[0])
			if speakers.size() >= 2:
				var a: CrewMember = members[speakers[0]]
				a.affinity[speakers[1]] = clampf(float(a.affinity.get(speakers[1], 0.0)) + 0.01, -1.0, 1.0)
			return
	var lines: Array = []
	for l2 in CrewLines.AMBIENT:
		if _recent.has(l2["id"]) or not ids.has(String(l2["who"])):
			continue
		var w := String(l2["where"])
		if w != "any" and w != captain_location:
			continue
		if l2.get("night", false) and not night:
			continue
		lines.append(l2)
	if lines.is_empty():
		return
	var line: Dictionary = lines[_rng.randi() % lines.size()]
	_mark(line["id"])
	var voice := "line_" + String(line["id"])
	dialogue.say(String(line["who"]), String(line["text"]), Dialogue.P.AMBIENT, voice if audio.library.has_sound(voice) else "")


func _mark(id: String) -> void:
	_recent.append(id)
	if _recent.size() > 26:
		_recent.pop_front()


## Basse sings to himself, overheard from wherever the captain is.
func _try_song() -> void:
	var b: CrewMember = members["basse"]
	if alert > 0 or silent_running or b.location != "mess" or not b.awake or dialogue.busy():
		return
	var lengths := audio.song_lengths()
	if lengths.is_empty():
		if captain_location == "mess" and _rng.randf() < 0.35:
			react("basse_humming", {}, Dialogue.P.AMBIENT)
		return
	var song := _rng.randi() % lengths.size()
	var length := float(lengths[song])
	# A few words, half a verse, a verse, or (rarely) a verse and a half.
	var r := _rng.randf()
	var dur := _rng.randf_range(3.0, 6.0) if r < 0.38 else (_rng.randf_range(7.0, 12.0) if r < 0.7 else (_rng.randf_range(14.0, 21.0) if r < 0.92 else _rng.randf_range(22.0, 32.0)))
	var start := _rng.randf_range(0.0, maxf(length - dur - 1.0, 0.0))
	audio.sing_fragment(start, dur, AudioManager.Loc.MESS, song)


func talk_to(id: String) -> String:
	var m: CrewMember = members.get(id)
	if m == null:
		return ""
	var pool: Array = CrewLines.TALK.get(id, [])
	if pool.is_empty():
		return ""
	var line := String(pool[_rng.randi() % pool.size()])
	m.affinity["captain"] = clampf(float(m.affinity.get("captain", 0.0)) + 0.03, -1.0, 1.0)
	return line


func remember_all(entry: String) -> void:
	for id in ["miller", "basse", "freja", "erik", "maya"]:
		(members[id] as CrewMember).remember(entry)


# --- persistence (part of each campaign save) --------------------------------

func save_state() -> Dictionary:
	var d := {}
	for m in members.values():
		d[(m as CrewMember).id] = (m as CrewMember).to_dict()
	return {"members": d, "candy": captain_candy, "alert": alert, "silent": silent_running, "meals": _meals_done, "cup": mess_cup.duplicate(true),
		"miller_conn": miller_has_conn}


func load_state(d: Dictionary) -> void:
	var ms: Variant = d.get("members")
	if ms is Dictionary:
		for id in (ms as Dictionary).keys():
			if members.has(id):
				(members[id] as CrewMember).from_dict(ms[id])
	if d.get("candy") is Dictionary:
		captain_candy = d["candy"]
	if d.get("cup") is Array:
		mess_cup = d["cup"]
	alert = int(d.get("alert", 0))
	silent_running = bool(d.get("silent", false))
	_meals_done = d.get("meals", {})
	miller_has_conn = bool(d.get("miller_conn", false))
