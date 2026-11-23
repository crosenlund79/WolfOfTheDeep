class_name CommandStanding
extends Node
## The boat's standing with Northern Command. The captain is free to follow
## orders, bend them, ignore a recall, fire without authority, or take the
## boat where she should not go; nothing ends the game. The world answers:
## signals (copied only with a mast up), suspicion, relief from command, the
## crew's own judgement, and the other side's interest. Opportunities missed
## stay missed.

signal event(kind: String, text: String)

const FOREIGN_X := 255000.0        # east of this lies the other side's home waters
const STATES := ["UNDER ORDERS", "UNDER QUESTION", "OVERDUE", "RECALLED", "RELIEVED", "BELIEVED DEFECTING"]

var patrol: Patrol
var sub: Submarine
var clock: GameClock
var conscience: Conscience
var intel: IntelDB
var traffic: WorldTraffic

var state := "UNDER ORDERS"
var history: Array = []            # [{t, state, why}]
var _acc := 0.0
var _flags := {}
var _foreign_since := -1.0
var _overdue_t := -1.0


func _set_state(s: String, why: String) -> void:
	if s == state:
		return
	state = s
	history.append({"t": clock.seconds, "state": s, "why": why})
	event.emit("state", "Standing with Northern Command: %s. %s" % [s.to_lower(), why])


func _signal(id: String, text: String) -> void:
	if _flags.has(id):
		return
	_flags[id] = true
	patrol.queue_message("hq_" + id, clock.seconds + 60.0, "NORTHERN COMMAND", text)


func advance(dt: float) -> void:
	_acc += dt
	if _acc < 60.0:
		return
	_acc = 0.0
	var now := clock.seconds
	var p := sub.global_position
	var at_rv := Vector2(p.x - patrol.rv.x, p.z - patrol.rv.z).length() < 3000.0
	# Overdue at the rendezvous: questions, then a recall, then relief.
	if now > patrol.deadline + 3600.0 and not patrol.objective("return").get("done", false) and not at_rv:
		if _overdue_t < 0.0:
			_overdue_t = now
			_set_state("OVERDUE", "The boat missed the rendezvous.")
			_signal("overdue", "PRIORITY. VARG: YOU ARE OVERDUE AT RV HOME. REPORT POSITION AND INTENTIONS.")
			conscience.judge("orders_defied")
		elif now > _overdue_t + 12.0 * 3600.0 and state == "OVERDUE":
			_set_state("RECALLED", "Northern Command has recalled the boat.")
			_signal("recall", "PRIORITY. VARG: RETURN TO BASE IMMEDIATELY. ACKNOWLEDGE.")
		elif now > _overdue_t + 36.0 * 3600.0 and state == "RECALLED":
			_set_state("RELIEVED", "The recall was ignored; Northern Command has relieved the captain of command.")
			_signal("relieved", "PRIORITY. VARG: COMMANDING OFFICER IS RELIEVED OF COMMAND. EXECUTIVE OFFICER TO ASSUME COMMAND AND BRING THE BOAT HOME.")
			conscience.judge("recall_ignored")
			intel.captain_event("detected", now, "Relieved of command for ignoring a recall.")
			event.emit("xo", "Captain, that signal is addressed to me. I'm asking you, as plainly as I can: take her home.")
	elif _overdue_t >= 0.0 and at_rv and state in ["OVERDUE", "RECALLED", "RELIEVED"]:
		_set_state("UNDER QUESTION", "The boat has come back; there will be questions.")
		_signal("back_%d" % int(now), "VARG: ARRIVAL NOTED. COMMANDING OFFICER TO REPORT ON ARRIVAL.")
		conscience.judge("returned")
	# Foreign home waters.
	if p.x > FOREIGN_X:
		if _foreign_since < 0.0:
			_foreign_since = now
		var inside := now - _foreign_since
		if inside > 3600.0 and not _flags.has("foreign_warn_%d" % int(_foreign_since)):
			_flags["foreign_warn_%d" % int(_foreign_since)] = true
			patrol.queue_message("hq_foreign_%d" % int(now), now + 60.0, "NORTHERN COMMAND", "PRIORITY. VARG: YOU ARE ENTERING FOREIGN HOME WATERS WITHOUT ORDERS. REVERSE COURSE IMMEDIATELY.")
			var refused := conscience.judge("foreign_waters")
			event.emit("xo", "Captain, I have to ask what we are doing here. Northern Command will see it one way only." + ("" if refused.is_empty() else " Some of the crew will not stand their watches for it."))
		if inside > 6.0 * 3600.0 and state != "BELIEVED DEFECTING":
			_set_state("BELIEVED DEFECTING", "The boat has stayed in foreign waters without orders.")
			_signal("defect_%d" % int(_foreign_since), "PRIORITY. ALL UNITS: VARG IS NOT UNDER NORTHERN COMMAND CONTROL. REPORT ANY CONTACT.")
			traffic.incident(p, 0.5)
			intel.captain_event("attack", now, "Believed to be defecting.")
	elif _foreign_since >= 0.0:
		_foreign_since = -1.0
		if state == "BELIEVED DEFECTING":
			_set_state("UNDER QUESTION", "The boat has turned back from foreign waters.")
			_signal("turned_%d" % int(now), "VARG: RETURN NOTED. MAINTAIN COMMUNICATIONS SCHEDULE. COMMANDING OFFICER WILL ANSWER FOR THIS.")
			conscience.judge("returned")


## A torpedo has been fired without authority.
func weapons_released(civil: bool) -> void:
	var now := clock.seconds
	_signal("fired_%d" % int(now), "PRIORITY. VARG: REPORTS OF A WEAPON RELEASE IN YOUR AREA. YOU WERE NOT AUTHORISED. EXPLAIN IMMEDIATELY.")
	if state == "UNDER ORDERS":
		_set_state("UNDER QUESTION", "Weapons were used without authority%s." % (" against a civilian ship" if civil else ""))


func save_state() -> Dictionary:
	return {"state": state, "history": history.duplicate(true), "flags": _flags.duplicate(), "foreign": _foreign_since, "overdue": _overdue_t}


func load_state(d: Dictionary) -> void:
	state = String(d.get("state", state))
	var h: Variant = d.get("history")
	if h is Array:
		history = h
	var f: Variant = d.get("flags")
	if f is Dictionary:
		_flags = f
	_foreign_since = float(d.get("foreign", -1.0))
	_overdue_t = float(d.get("overdue", -1.0))
