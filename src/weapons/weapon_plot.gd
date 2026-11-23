class_name WeaponPlot
extends RefCounted
## Weapons on the plot, as the boat knows them:
##  - its own torpedoes, from their telemetry while the guidance wire holds,
##    and by dead reckoning from the last report once it has parted;
##  - detonations heard;
##  - enemy weapons, only once detected (`detect`), never from the
##    simulation's knowledge that they exist.
## A track that ends (detonation, run complete, an estimated end of run, a
## detected weapon no longer heard) is kept a while marked stale, then dropped.
## Positions are worked out from times, not frame by frame, so time
## compression changes nothing.

const STALE_KEEP := 600.0          # seconds an ended track stays on the chart
const TRAIL_EVERY := 5.0           # seconds between trail points
const TRAIL_MAX := 48
const HOSTILE_LOST := 90.0         # a detected weapon not heard for this long is stale
const STATES_ENDED := ["ended", "detonated", "lost"]

## key -> {key, kind ("own_torpedo" / "hostile_torpedo" / "charge" / "detonation"),
## label, pos (Vector3, y = 0), heading (rad), speed (m/s), fix_pos, fix_t,
## run_left (m at the fix), state ("current" / "estimated" / ENDED states),
## unc (m), trail ([Vector2]), trail_t, ended_t, note}
var tracks := {}


## Every simulation step: follow the boat's own torpedoes.
func advance(now: float, engagements: Array) -> void:
	for rec in engagements:
		var key := "T%d" % int(rec["n"])
		var torp: Torpedo = rec["torp"] if is_instance_valid(rec["torp"]) else null
		var tr: Dictionary = tracks.get(key, {})
		if tr.is_empty():
			if torp == null or torp.done:
				continue
			tr = _new(key, "own_torpedo", key, torp.global_position, torp.heading, torp.speed, now)
			tr["run_left"] = Torpedo.MAX_RANGE - torp.travelled
			tracks[key] = tr
		if String(tr["state"]) in STATES_ENDED:
			continue
		var st := String(rec["state"])
		if torp and not torp.done and torp.wire_ok:
			# Telemetry: the torpedo reports where it is.
			_fix(tr, torp.global_position, torp.heading, torp.speed, now)
			tr["run_left"] = Torpedo.MAX_RANGE - torp.travelled
			tr["state"] = "current"
			tr["unc"] = 0.0
		else:
			_dead_reckon(tr, now)
			if st == "hit":
				var exact := String(tr["state"]) == "current"
				_end(tr, "detonated", now, "detonation heard" + ("" if exact else ", position estimated"))
				if exact:
					tr["unc"] = 0.0
			elif st == "miss_confirmed":
				_end(tr, "ended", now, "run complete (telemetry)")
			elif float(tr["dr_run"]) >= float(tr["run_left"]):
				# Stamped with when it should have ended, not when we noticed.
				_end(tr, "ended", float(tr["fix_t"]) + float(tr["run_left"]) / maxf(float(tr["speed"]), 1.0), "estimated end of run")
			else:
				tr["state"] = "estimated"
		_trail(tr, now)
	for key in tracks.keys():
		var t: Dictionary = tracks[key]
		var kind := String(t["kind"])
		if kind in ["hostile_torpedo", "charge"] and String(t["state"]) not in STATES_ENDED:
			_dead_reckon(t, now)
			if now - float(t["fix_t"]) > HOSTILE_LOST:
				_end(t, "lost", float(t["fix_t"]) + HOSTILE_LOST, "no longer detected")
			elif now - float(t["fix_t"]) > 10.0:
				t["state"] = "estimated"
			_trail(t, now)
		if String(t["state"]) in STATES_ENDED and now - float(t["ended_t"]) > STALE_KEEP:
			tracks.erase(key)


## A detonation the boat heard, placed where it is believed to have been.
func heard_detonation(key: String, pos: Vector3, now: float, note: String) -> void:
	var t := _new(key, "detonation", note, pos, 0.0, 0.0, now)
	_end(t, "detonated", now, note)
	tracks[key] = t


## An enemy weapon (torpedo or charge) the boat has detected: by sonar or by
## sight. Only a detection calls this; an undetected weapon never reaches the
## plot. A position from a bearing and a guessed range is "estimated".
func detect(key: String, kind: String, pos: Vector3, heading: float, speed: float, now: float, precise: bool, label: String) -> void:
	var t: Dictionary = tracks.get(key, {})
	if t.is_empty() or String(t["state"]) in STATES_ENDED:
		t = _new(key, kind, label, pos, heading, speed, now)
		t["run_left"] = INF
		tracks[key] = t
	_fix(t, pos, heading, speed, now)
	t["state"] = "current" if precise else "estimated"
	t["unc"] = 0.0 if precise else 300.0


## A detected weapon is known to have gone off or ended.
func ended(key: String, now: float, detonated: bool) -> void:
	if tracks.has(key):
		_end(tracks[key], "detonated" if detonated else "ended", now, "detonation heard" if detonated else "run ended")


func list() -> Array:
	return tracks.values()


func _new(key: String, kind: String, label: String, pos: Vector3, heading: float, speed: float, now: float) -> Dictionary:
	var p := Vector3(pos.x, 0.0, pos.z)
	return {"key": key, "kind": kind, "label": label, "pos": p, "heading": heading, "speed": speed, "fix_pos": p, "fix_t": now,
		"run_left": INF, "dr_run": 0.0, "state": "current", "unc": 0.0, "trail": [Vector2(p.x, p.z)], "trail_t": now, "ended_t": 0.0, "note": ""}


func _fix(t: Dictionary, pos: Vector3, heading: float, speed: float, now: float) -> void:
	t["fix_pos"] = Vector3(pos.x, 0.0, pos.z)
	t["pos"] = t["fix_pos"]
	t["heading"] = heading
	t["speed"] = speed
	t["fix_t"] = now
	t["dr_run"] = 0.0


## Where it should be by now from its last known position, course and speed
## (never further than its remaining run), and how uncertain that is: a
## torpedo off the wire may have turned to home.
func _dead_reckon(t: Dictionary, now: float) -> void:
	var d := minf(float(t["speed"]) * maxf(now - float(t["fix_t"]), 0.0), float(t["run_left"]))
	var h := float(t["heading"])
	t["pos"] = (t["fix_pos"] as Vector3) + Vector3(sin(h), 0.0, -cos(h)) * d
	t["dr_run"] = d
	t["unc"] = maxf(float(t["unc"]), 60.0 + 0.2 * d) if d > 0.0 else float(t["unc"])


func _end(t: Dictionary, state: String, now: float, note: String) -> void:
	t["state"] = state
	t["ended_t"] = now
	t["note"] = note


func _trail(t: Dictionary, now: float) -> void:
	if now - float(t["trail_t"]) < TRAIL_EVERY:
		return
	t["trail_t"] = now
	var tr: Array = t["trail"]
	tr.append(Vector2((t["pos"] as Vector3).x, (t["pos"] as Vector3).z))
	if tr.size() > TRAIL_MAX:
		tr.pop_front()
