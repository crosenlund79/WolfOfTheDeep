class_name CaptainsLog
extends RefCounted
## The operational Captain's Log. Records only what the boat legitimately
## knows: observations, assessments and open questions, with time, source and
## links to positions, contacts, dossiers and signals. Persists in saves.

signal added(entry: Dictionary)
signal changed

const CATEGORIES := ["CONTACTS", "NAVIGATION", "COMMUNICATIONS", "CREW", "ENGINEERING", "COMBAT", "DECISIONS", "WORLD", "INTEL", "NOTES"]
const KINDS := ["confirmed", "assessment", "unresolved", "personal"]

var clock: GameClock
var entries: Array[Dictionary] = []
var watch_active := false        # set by main while the XO has the conn
var _next := 1


## kind: confirmed / assessment / unresolved. opts: source, pos (Vector3),
## contact, dossier, message, flag.
func add(cat: String, text: String, kind: String = "confirmed", opts: Dictionary = {}) -> Dictionary:
	if cat not in CATEGORIES:
		cat = "WORLD"
	var e := {
		"id": _next,
		"t": clock.seconds if clock else 0.0,
		"time": clock.time_string() if clock else "",
		"cat": cat,
		"kind": kind,
		"text": text,
		"source": String(opts.get("source", "XO (watch)" if watch_active else "")),
		"flag": bool(opts.get("flag", kind == "unresolved")),
		"note": "",
		"watch": watch_active,
	}
	if opts.has("pos"):
		var p: Vector3 = opts["pos"]
		e["pos"] = [snappedf(p.x, 1.0), snappedf(p.z, 1.0)]
	for k in ["contact", "dossier", "message"]:
		if opts.has(k) and String(opts[k]) != "":
			e[k] = String(opts[k])
	_next += 1
	entries.append(e)
	added.emit(e)
	changed.emit()
	return e


func personal_note(text: String) -> Dictionary:
	return add("NOTES", text, "personal", {"source": "Captain"})


func find(id: int) -> Dictionary:
	for e in entries:
		if int(e["id"]) == id:
			return e
	return {}


func set_flag(id: int, on: bool) -> void:
	var e := find(id)
	if not e.is_empty():
		e["flag"] = on
		changed.emit()


func set_note(id: int, text: String) -> void:
	var e := find(id)
	if not e.is_empty():
		e["note"] = text
		changed.emit()


## Mark an open matter as settled (keeps the entry, adds a reference).
func resolve(id: int, by_text: String) -> void:
	var e := find(id)
	if e.is_empty():
		return
	e["kind"] = "assessment" if String(e["kind"]) == "unresolved" else e["kind"]
	e["flag"] = false
	e["resolved"] = by_text
	changed.emit()


func filtered(cats: Array, kinds: Array, flagged_only: bool, text_query: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var q := text_query.to_lower()
	for e in entries:
		if not cats.is_empty() and String(e["cat"]) not in cats:
			continue
		if not kinds.is_empty() and String(e["kind"]) not in kinds:
			continue
		if flagged_only and not bool(e["flag"]):
			continue
		if q != "" and not (String(e["text"]).to_lower().contains(q) or String(e.get("note", "")).to_lower().contains(q)):
			continue
		out.append(e)
	return out


func count_flagged() -> int:
	return entries.filter(func(e: Dictionary) -> bool: return bool(e["flag"])).size()


func save_state() -> Dictionary:
	return {"entries": entries, "next": _next}


func load_state(d: Dictionary) -> void:
	entries.clear()
	for e in d.get("entries", []):
		if e is Dictionary:
			var ed: Dictionary = e
			ed["id"] = int(ed.get("id", 0))
			entries.append(ed)
	_next = int(d.get("next", entries.size() + 1))
	changed.emit()
