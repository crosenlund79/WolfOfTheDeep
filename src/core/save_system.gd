class_name SaveSystem
extends RefCounted
## Campaign saves: versioned JSON documents with safe writes (temp file,
## verified, previous copy kept as .bak). Manual slots, rotating autosaves and
## a quick save. Settings are stored elsewhere (Settings).

const DIR := "user://saves/"
const VERSION := 1
const MANUAL_SLOTS := 8
const AUTO_SLOTS := 3

## Set before reloading the scene: {"action": "new"} or {"action": "load", "path": ...}.
static var pending: Dictionary = {}


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


static func slot_path(slot: String) -> String:
	return DIR + slot + ".json"


## Write a save document safely. Returns OK or an error code.
static func write(slot: String, data: Dictionary) -> Error:
	ensure_dir()
	var path := slot_path(slot)
	# Metadata first (the load list reads only the head of each file).
	var ordered := {"meta": data.get("meta", {}), "version": VERSION}
	for k in data.keys():
		if not ordered.has(k):
			ordered[k] = data[k]
	var text := JSON.stringify(ordered, "", false, true)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	# Verify what reached the disk before replacing anything.
	var check: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if not (check is Dictionary) or int((check as Dictionary).get("version", -1)) != VERSION:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


## Read a save document (falls back to the .bak copy if the main file is damaged).
static func read_path(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if parsed is Dictionary:
			var d: Dictionary = parsed
			if int(d.get("version", 0)) > VERSION:
				return {"error": "This save was made by a newer version of the game."}
			return _migrate(d)
	return {}


static func _migrate(d: Dictionary) -> Dictionary:
	# Version 1 is the first campaign format; future versions upgrade here.
	return d


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func delete(slot: String) -> void:
	for suffix in ["", ".bak"]:
		var p: String = slot_path(slot) + String(suffix)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Metadata of every save, newest first: [{slot, path, meta}].
static func list() -> Array:
	ensure_dir()
	var out: Array = []
	var da := DirAccess.open(DIR)
	if da == null:
		return out
	for fn in da.get_files():
		if not fn.ends_with(".json"):
			continue
		var path := DIR + fn
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		# The metadata block is written first, so a short read is enough.
		var head := f.get_buffer(mini(f.get_length(), 4096)).get_string_from_utf8()
		var meta := _meta_from_head(head)
		if meta.is_empty():
			var full: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if full is Dictionary:
				meta = (full as Dictionary).get("meta", {})
		out.append({"slot": fn.get_basename(), "path": path, "meta": meta})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a["meta"] as Dictionary).get("unix", 0.0)) > float((b["meta"] as Dictionary).get("unix", 0.0)))
	return out


static func _meta_from_head(head: String) -> Dictionary:
	var i := head.find("\"meta\":")
	if i < 0:
		return {}
	var start := head.find("{", i)
	var depth := 0
	for j in range(start, head.length()):
		var ch := head[j]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				var parsed: Variant = JSON.parse_string(head.substr(start, j - start + 1))
				return parsed if parsed is Dictionary else {}
	return {}


static func latest() -> Dictionary:
	var all := list()
	return all[0] if not all.is_empty() else {}


## The next autosave slot (oldest of the rotation).
static func next_auto_slot() -> String:
	var best := "auto_1"
	var oldest := INF
	for i in range(1, AUTO_SLOTS + 1):
		var s := "auto_%d" % i
		if not exists(s):
			return s
		var f := FileAccess.open(slot_path(s), FileAccess.READ)
		var meta := _meta_from_head(f.get_buffer(mini(f.get_length(), 4096)).get_string_from_utf8()) if f else {}
		var t := float(meta.get("unix", 0.0))
		if t < oldest:
			oldest = t
			best = s
	return best


# --- small helpers for (de)serialising engine types --------------------------

static func v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func to_v3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func v2(v: Vector2) -> Array:
	return [v.x, v.y]


static func to_v2(a: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return fallback
