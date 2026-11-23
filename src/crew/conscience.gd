class_name Conscience
extends Node
## Independent judgement aboard. Each person weighs what the captain does
## against their loyalty to country, trust in government, command and the
## captain, loyalty to shipmates, tolerance for risk and their own
## convictions. On their own initiative and within what is realistic aboard a
## warship they may challenge an order, ask to speak privately, refuse to take
## part in a specific act (another qualified person covers their station), or
## ask to be reassigned. No morality meter: trust moves, people act on it.

signal acted(member_id: String, kind: String, text: String)

## Convictions that matter to each person (who they are, not a score).
const CONVICTIONS := {
	"miller": ["duty", "crew"],
	"freja": ["civilians", "rescue"],
	"maya": ["law", "civilians"],
	"erik": ["crew", "boat"],
	"basse": ["crew", "rescue"],
	"haugen": ["duty"],
	"rask": ["crew"],
	"dahl": ["boat"],
}
const REFUSAL_HOURS := 6.0

var crew: Crew
var clock: GameClock
var dialogue: Dialogue
var _raise_t := 0.0
var _refusals := {}          # member id -> until (seconds)
var _reassign := {}          # member id -> true once asked
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.seed = 1949
	for id in CONVICTIONS:
		var m: CrewMember = crew.members.get(id)
		if m and (m.conscience["convictions"] as Array).is_empty():
			m.conscience["convictions"] = (CONVICTIONS[id] as Array).duplicate()


func _has(m: CrewMember, c: String) -> bool:
	return (m.conscience["convictions"] as Array).has(c)


func trust(id: String) -> float:
	var m: CrewMember = crew.members.get(id)
	return float(m.conscience["captain"]) if m else 0.5


func _shift(m: CrewMember, d: float) -> void:
	m.conscience["captain"] = clampf(float(m.conscience["captain"]) + d, 0.0, 1.0)


func _concern(m: CrewMember, topic: String, text: String) -> void:
	for o in m.opinions:
		if String(o["topic"]) == topic and not bool(o["raised"]):
			return
	m.opinions.append({"t": clock.seconds, "topic": topic, "text": text, "raised": false})


## What the XO says before a torpedo is fired, given what is in the sights.
## ctx: {civil: bool, warship: bool, authorised: bool, threatened: bool}
func objection(ctx: Dictionary) -> String:
	if bool(ctx.get("authorised", false)):
		return "Weapons are released for this, Captain. Firing point procedures?"
	if bool(ctx.get("civil", false)):
		return "Captain, that is a civilian ship. I must formally object, and I will log that I did. Are you ordering me to fire on her?"
	if bool(ctx.get("threatened", false)):
		return "Captain... she is hunting us, but we are not at war and nobody has fired. If we shoot first, that is on us. Are you certain?"
	return "Captain... we are not at war. If we fire, we start one, and everyone will know who did it. Are you certain, sir?"


## The captain has done something the crew will judge. Returns the ids of
## anyone who refuses to take part in it.
func judge(event: String, ctx: Dictionary = {}) -> Array:
	var refused: Array = []
	for m in crew.members.values():
		var cm := m as CrewMember
		var c := cm.conscience
		var d := 0.0
		match event:
			"fire":
				var civil := bool(ctx.get("civil", false))
				d = -0.08 - (0.22 if civil else 0.0) - (0.12 if civil and _has(cm, "civilians") else 0.0) - (0.06 if _has(cm, "law") else 0.0)
				if bool(ctx.get("threatened", false)) and not civil:
					d *= 0.4
				if _has(cm, "duty") and float(c["command"]) > 0.6:
					d -= 0.04
				# Some will not be part of it at all.
				if civil and (_has(cm, "civilians") or _has(cm, "law")) and float(c["captain"]) + d < 0.55 and cm.role != "XO":
					refused.append(cm.id)
				_concern(cm, "fire", "the torpedo we fired" + (" on a civilian ship" if civil else ""))
			"overdepth":
				d = -0.05 * (1.0 - float(c["risk"])) - (0.04 if _has(cm, "boat") else 0.0)
				_concern(cm, "depth", "how deep we took her")
			"reckless":
				d = -0.08 - (0.05 if _has(cm, "boat") or _has(cm, "crew") else 0.0)
				_concern(cm, "reckless", "the damage to the boat")
			"distress_ignored":
				d = -0.04 - (0.12 if _has(cm, "rescue") else 0.0)
				_concern(cm, "distress", "the people we left to it")
			"distress_answered":
				d = 0.05 + (0.08 if _has(cm, "rescue") else 0.0)
			"orders_defied":
				d = -0.04 * float(c["command"]) - (0.05 if _has(cm, "duty") else 0.0)
				_concern(cm, "orders", "where Northern Command thinks we are")
			"recall_ignored":
				d = -0.1 * float(c["command"]) - (0.08 if _has(cm, "duty") or _has(cm, "law") else 0.0)
				_concern(cm, "recall", "the recall order")
			"foreign_waters":
				d = -0.12 * float(c["country"]) - (0.1 if _has(cm, "duty") else 0.0)
				if float(c["country"]) > 0.7 and float(c["captain"]) + d < 0.6 and cm.role != "XO":
					refused.append(cm.id)
				_concern(cm, "defect", "where you are taking us")
			"returned":
				d = 0.05
			"success":
				d = 0.03 * (0.5 + float(c["risk"]))
			"care":
				d = 0.02 + (0.03 if _has(cm, "crew") else 0.0)
		_shift(cm, d)
	for id in refused:
		_refuse(String(id), event)
	return refused


func _refuse(id: String, event: String) -> void:
	var m: CrewMember = crew.members.get(id)
	if m == null or not m.available:
		return
	m.available = false
	_refusals[id] = clock.seconds + REFUSAL_HOURS * 3600.0
	var what: String = {"fire": "will not take part in firing on a civilian ship", "foreign_waters": "will not take the boat into foreign waters"}.get(event, "will not take part in this")
	var text := "%s %s and has asked to be relieved of her station." % [m.name, what] if m.id in ["freja", "maya"] else "%s %s and has asked to be relieved of his station." % [m.name, what]
	m.remember("Refused an order: " + what + ".")
	acted.emit(id, "refused", text)


## Called often: refusals end; concerns are raised when it is quiet; trust
## that has worn thin becomes a request for reassignment.
func advance(dt: float) -> void:
	for id in _refusals.keys():
		if clock.seconds > float(_refusals[id]):
			var m: CrewMember = crew.members.get(id)
			if m:
				m.available = true
				acted.emit(id, "returned", "%s has returned to duty." % m.name)
			_refusals.erase(id)
	_raise_t -= dt
	if _raise_t > 0.0 or crew.alert > 0 or crew.captain_asleep:
		return
	_raise_t = 3.0 * 3600.0
	for m in crew.members.values():
		var cm := m as CrewMember
		if not cm.awake or not cm.available:
			continue
		var tr := float(cm.conscience["captain"])
		if tr < 0.3 and not _reassign.has(cm.id):
			_reassign[cm.id] = true
			cm.remember("Asked to be reassigned after this patrol.")
			acted.emit(cm.id, "reassign", "%s has asked, formally, to be reassigned when the boat is back in port." % cm.name)
			return
		for o in cm.opinions:
			if not bool(o["raised"]) and tr < 0.5:
				o["raised"] = true
				acted.emit(cm.id, "concern", "%s asked for a word in private, about %s." % [cm.name, String(o["text"])])
				return


func reassignment_requests() -> Array:
	return _reassign.keys()


func save_state() -> Dictionary:
	return {"refusals": _refusals.duplicate(), "reassign": _reassign.duplicate(), "raise_t": _raise_t}


func load_state(d: Dictionary) -> void:
	var r: Variant = d.get("refusals")
	if r is Dictionary:
		_refusals = r
	var a: Variant = d.get("reassign")
	if a is Dictionary:
		_reassign = a
	_raise_t = float(d.get("raise_t", 0.0))
	for id in _refusals:
		var m: CrewMember = crew.members.get(id)
		if m:
			m.available = false
