class_name IntelDB
extends RefCounted
## Naval intelligence as the boat holds it: a reference library of classes
## (what Northern Command's analysts publish), the units and commanders the
## boat has met or been told about, the reports received, and how the
## captain's own conduct is being read. Nothing here comes from hidden truth:
## units and their details are created from observation and reports only, and
## carry their own confidence; reports can be wrong and can contradict each
## other, and both versions are kept.
##
## Intrinsic capability (what a class could do) is kept apart from tactical
## threat (what a contact is doing to us now).

const CONF := ["UNKNOWN", "LOW", "MEDIUM", "HIGH", "CONFIRMED"]

## Reference library. "capability" is 0..1 (intrinsic danger to a submarine).
const CLASSES := {
	"boreas": {"name": "BOREAS class", "type": "Frigate (anti-submarine)", "navy": "FOREIGN", "length": "134 m", "displacement": "about 4,500 t",
		"speed": "29 kt", "crew": "about 200", "sensors": "Bow sonar (medium frequency), towed array, air and surface search radar",
		"asw": "Hull and towed sonar; embarked helicopter with dipping sonar; ASW rockets; lightweight torpedoes",
		"weapons": "Anti-ship missiles, medium gun, air-defence missiles, close-in guns, torpedo tubes",
		"capability": 0.85, "notes": "Quiet at low speed. Most dangerous with her helicopter airborne and the towed array streamed.", "confidence": "MEDIUM"},
	"grim": {"name": "GRIM class", "type": "Corvette (patrol and anti-submarine)", "navy": "FOREIGN", "length": "about 94 m", "displacement": "about 2,000 t",
		"speed": "26 kt", "crew": "about 100", "sensors": "Hull sonar, surface search radar",
		"asw": "Hull sonar; ASW rocket launchers; torpedo tubes. No helicopter.",
		"weapons": "Medium gun, ASW rockets, torpedoes, short-range air defence",
		"capability": 0.6, "notes": "Works the ice edge in pairs or alone. Pings readily when she suspects something.", "confidence": "MEDIUM"},
	"vakt": {"name": "VAKT class", "type": "Offshore patrol vessel (coast guard)", "navy": "HOME", "length": "92 m", "displacement": "about 3,200 t",
		"speed": "21 kt", "crew": "about 50", "sensors": "Navigation and surface radar", "asw": "None",
		"weapons": "Light gun", "capability": 0.05, "notes": "Fishery protection, search and rescue, towing.", "confidence": "CONFIRMED"},
	"heron": {"name": "HERON (reporting name)", "type": "Maritime patrol aircraft", "navy": "FOREIGN", "length": "-", "displacement": "-",
		"speed": "about 330 kt, 200 kt on station", "crew": "about 10", "sensors": "Search radar, sonobuoys, magnetic anomaly detector, electronic support",
		"asw": "Sonobuoy fields; radar against masts and snorkels", "weapons": "Lightweight torpedoes, depth charges",
		"capability": 0.75, "notes": "Its radar is heard long before it can see a mast. Keep the masts down when it is near.", "confidence": "MEDIUM"},
	"skua": {"name": "Maritime patrol aircraft (Northern Command)", "type": "Maritime patrol aircraft", "navy": "HOME", "length": "-", "displacement": "-",
		"speed": "about 300 kt", "crew": "about 9", "sensors": "Search radar, sonobuoys, cameras, electronic support", "asw": "Yes",
		"weapons": "Torpedoes", "capability": 0.0, "notes": "Our own. Its sightings come to us as reports.", "confidence": "CONFIRMED"},
	"airliner": {"name": "Airliner", "type": "Civil aircraft on a polar route", "navy": "CIVIL", "length": "-", "displacement": "-",
		"speed": "about 480 kt", "crew": "-", "sensors": "Weather radar", "asw": "None", "weapons": "None",
		"capability": 0.0, "notes": "High and fast; its weather radar shows on the ESM.", "confidence": "CONFIRMED"},
	"merchant": {"name": "Merchant ship", "type": "Cargo / container", "navy": "CIVIL", "length": "100-200 m", "displacement": "-",
		"speed": "12-18 kt", "crew": "about 20", "sensors": "Navigation radar, AIS", "asw": "None", "weapons": "None",
		"capability": 0.0, "notes": "Crews do report periscopes and oil.", "confidence": "CONFIRMED"},
	"trawler": {"name": "Fishing vessel", "type": "Stern trawler", "navy": "CIVIL", "length": "40-70 m", "displacement": "-",
		"speed": "3-12 kt", "crew": "10-25", "sensors": "Radar, echo sounder", "asw": "None", "weapons": "None",
		"capability": 0.0, "notes": "Nets are a hazard near the bottom.", "confidence": "CONFIRMED"},
	"research": {"name": "Research vessel", "type": "Oceanographic research", "navy": "CIVIL", "length": "60-100 m", "displacement": "-",
		"speed": "6-14 kt", "crew": "30-60", "sensors": "Echo sounders, hydrophone arrays", "asw": "Listens, by trade", "weapons": "None",
		"capability": 0.05, "notes": "Her hydrophones may hear us.", "confidence": "HIGH"},
}

const CODENAMES := ["LYNX", "OSPREY", "MARTEN", "WOLVERINE", "HARRIER", "STOAT", "ERMINE", "GOSHAWK", "OTTER", "SABLE"]

var units: Dictionary = {}          # id -> unit record
var commanders: Dictionary = {}     # id -> commander record
var reports: Array = []             # received reports, oldest first
var captain := {"stealth": 0.0, "aggression": 0.0, "restraint": 0.0, "humanity": 0.0, "known": 0.0, "events": []}
var _next_unit := 1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 8128
	_make_commanders()


# --- commanders -------------------------------------------------------------------

func _make_commanders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6061
	var i := 0
	for cn in CODENAMES:
		var traits := {"aggr": snappedf(rng.randf_range(0.1, 0.95), 0.01), "patience": snappedf(rng.randf_range(0.1, 0.95), 0.01),
			"caution": snappedf(rng.randf_range(0.1, 0.95), 0.01), "pride": snappedf(rng.randf_range(0.1, 0.95), 0.01)}
		commanders["C-%02d" % (i + 1)] = {"id": "C-%02d" % (i + 1), "codename": String(cn), "rank": "Commander" if i % 3 else "Captain",
			"traits": traits, "alive": true, "ship": "", "unit": "", "memories": [], "known": false, "known_traits": "",
			"attitude": {"wary": 0.0, "grudge": 0.0, "aggr": traits["aggr"], "patience": traits["patience"]}, "intel_conf": "LOW", "history": []}
		i += 1


## A commander for a ship. Survivors who have met the boat come back first
## (if they are free); the dead never do.
func assign_commander(ship_uid: String, prefer_memory: bool = true) -> Dictionary:
	for c in commanders.values():
		if String(c["ship"]) == ship_uid and bool(c["alive"]):
			return c
	var free: Array = commanders.values().filter(func(c: Dictionary) -> bool: return bool(c["alive"]) and String(c["ship"]) == "")
	if free.is_empty():
		return {}
	var pick: Dictionary = free[0]
	if prefer_memory:
		var best := -1.0
		for c2 in free:
			var w := float(c2["attitude"]["grudge"]) + float(c2["attitude"]["wary"]) + _rng.randf() * 0.3
			if w > best:
				best = w
				pick = c2
	else:
		pick = free[_rng.randi() % free.size()]
	pick["ship"] = ship_uid
	return pick


func release_commander(ship_uid: String) -> void:
	for c in commanders.values():
		if String(c["ship"]) == ship_uid:
			c["ship"] = ""
			c["unit"] = ""


func commander_of(ship_uid: String) -> Dictionary:
	for c in commanders.values():
		if String(c["ship"]) == ship_uid:
			return c
	return {}


## A commander remembers something about the boat. Personality decides what
## it does to them: pride turns humiliation into a grudge, caution into
## wariness. No arcade revenge: only how they search and how readily they act.
func remember(cid: String, event: String, t: float, weight: float = 1.0) -> void:
	if not commanders.has(cid):
		return
	var c: Dictionary = commanders[cid]
	if not bool(c["alive"]):
		return
	(c["memories"] as Array).append({"t": t, "event": event, "w": weight})
	var tr: Dictionary = c["traits"]
	var att: Dictionary = c["attitude"]
	match event:
		"searched":
			att["wary"] = minf(float(att["wary"]) + 0.05 * weight, 1.0)
		"evaded":
			att["wary"] = minf(float(att["wary"]) + 0.2 * (0.5 + float(tr["caution"])) * weight, 1.0)
			att["grudge"] = minf(float(att["grudge"]) + 0.15 * float(tr["pride"]) * weight, 1.0)
		"detected":
			att["wary"] = minf(float(att["wary"]) + 0.12 * weight, 1.0)
		"attacked":
			att["grudge"] = minf(float(att["grudge"]) + 0.45 * (0.5 + float(tr["pride"])) * weight, 1.0)
			att["wary"] = minf(float(att["wary"]) + 0.3 * weight, 1.0)
		"lost_ship":
			att["grudge"] = minf(float(att["grudge"]) + 0.6 * (0.4 + float(tr["pride"])) * weight, 1.0)
			att["wary"] = minf(float(att["wary"]) + 0.4 * weight, 1.0)


func commander_died(cid: String, t: float) -> void:
	if commanders.has(cid):
		var c: Dictionary = commanders[cid]
		c["alive"] = false
		c["ship"] = ""
		(c["history"] as Array).append({"t": t, "text": "Did not survive the loss of the ship."})


# --- units -----------------------------------------------------------------------

## The unit record behind a contact or report subject; created on first need.
## `key` is internal (the ship's uid) and never shown.
func unit_for(key: String, t: float, seed_info: Dictionary = {}) -> Dictionary:
	for u in units.values():
		if String(u["key"]) == key:
			return u
	var id := "U-%02d" % _next_unit
	_next_unit += 1
	var u := {"id": id, "key": key, "designation": String(seed_info.get("designation", "Unidentified unit")), "name": "",
		"class": String(seed_info.get("class", "")), "class_conf": String(seed_info.get("class_conf", "LOW")),
		"navy": String(seed_info.get("navy", "UNKNOWN")), "commander": "", "commander_conf": "",
		"status": "ACTIVE", "status_conf": "", "confidence": String(seed_info.get("confidence", "LOW")),
		"last_update": t, "last_pos": [], "last_pos_t": -1.0, "last_pos_unc": 0.0, "history": [], "contacts": [], "reports": [],
		"threat_note": ""}
	units[id] = u
	return u


func unit_by_id(id: String) -> Dictionary:
	return units.get(id, {})


func note(u: Dictionary, t: float, text: String, source: String) -> void:
	(u["history"] as Array).append({"t": t, "text": text, "source": source})
	u["last_update"] = t


func set_position(u: Dictionary, t_obs: float, pos: Vector2, unc: float) -> void:
	if t_obs >= float(u["last_pos_t"]):
		u["last_pos"] = [snappedf(pos.x, 1.0), snappedf(pos.y, 1.0)]
		u["last_pos_t"] = t_obs
		u["last_pos_unc"] = unc


static func conf_rank(c: String) -> int:
	return maxi(CONF.find(c), 0)


func raise_conf(u: Dictionary, field: String, c: String) -> void:
	if conf_rank(c) > conf_rank(String(u.get(field, "UNKNOWN"))):
		u[field] = c


## Intrinsic capability of a unit as text (from its class, if known).
func capability_text(u: Dictionary) -> String:
	var cls: Dictionary = CLASSES.get(String(u["class"]), {})
	if cls.is_empty():
		return "Unknown"
	var cap := float(cls["capability"])
	var lvl := "NONE" if cap < 0.05 else ("LOW" if cap < 0.3 else ("MODERATE" if cap < 0.6 else ("HIGH" if cap < 0.8 else "VERY HIGH")))
	return "%s (class, %s confidence)" % [lvl, String(u["class_conf"]).to_lower()]


## Tactical threat now, from what a contact is doing (never from truth).
static func tactical_threat(c: Contact, own: Vector3, pinging: bool) -> String:
	if c == null or c.status != "TRACKING":
		return "NOT HELD"
	var cap := 0.0
	match c.classification:
		"WARSHIP":
			cap = 0.7
		"SUBMARINE", "SUBMERGED":
			cap = 0.7
		"UNKNOWN":
			cap = 0.3
		"RESEARCH":
			cap = 0.1
	if cap <= 0.05:
		return "NONE"
	var score := cap * clampf(1.4 - c.range_est / 15000.0, 0.1, 1.4)
	if c.est_course >= 0.0 and c.est_speed > 2.0:
		var to_us := fposmod(rad_to_deg(atan2(own.x - c.est_pos.x, -(own.z - c.est_pos.z))), 360.0)
		if absf(wrapf(c.est_course - to_us, -180.0, 180.0)) < 35.0:
			score *= 1.4
	if pinging:
		score *= 1.6
	return "LOW" if score < 0.35 else ("MODERATE" if score < 0.7 else ("HIGH" if score < 1.1 else "SEVERE"))


# --- reports ----------------------------------------------------------------------

## A report has been received. Updates (or creates) the unit it concerns and
## flags contradictions with earlier reports; both versions are kept.
func ingest(r: Dictionary, t_recv: float) -> Dictionary:
	r["t_recv"] = t_recv
	reports.append(r)
	var key := String(r.get("subject", ""))
	if key == "":
		return {}
	var u := unit_for(key, t_recv, r.get("seed", {}))
	(u["reports"] as Array).append(String(r["id"]))
	var p: Array = r.get("pos", [])
	if p.size() == 2:
		var pos := Vector2(float(p[0]), float(p[1]))
		# Contradiction: another report about the same unit, observed around
		# the same time, puts it somewhere it could not reach.
		for o in reports:
			if o == r or String(o.get("subject", "")) != key or (o.get("pos", []) as Array).size() != 2:
				continue
			var dt_h := absf(float(o["t_obs"]) - float(r["t_obs"])) / 3600.0
			var op := Vector2(float(o["pos"][0]), float(o["pos"][1]))
			var reach := dt_h * 30.0 * 1852.0 + float(o.get("unc", 0.0)) + float(r.get("unc", 0.0))
			if pos.distance_to(op) > reach:
				(r["conflicts"] as Array).append(String(o["id"]))
				(o["conflicts"] as Array).append(String(r["id"]))
		set_position(u, float(r["t_obs"]), pos, float(r.get("unc", 0.0)))
	if r.has("survivors"):
		for o2 in reports:
			if o2 != r and String(o2.get("subject", "")) == key and o2.has("survivors") and int(o2["survivors"]) != int(r["survivors"]):
				(r["conflicts"] as Array).append(String(o2["id"]))
				(o2["conflicts"] as Array).append(String(r["id"]))
	var seed: Dictionary = r.get("seed", {})
	if seed.has("class") and conf_rank(String(seed.get("class_conf", "LOW"))) >= conf_rank(String(u["class_conf"])):
		u["class"] = String(seed["class"])
		u["class_conf"] = String(seed.get("class_conf", "LOW"))
	if seed.has("designation") and String(u["designation"]).begins_with("Unidentified"):
		u["designation"] = String(seed["designation"])
	if seed.has("navy") and String(u["navy"]) == "UNKNOWN":
		u["navy"] = String(seed["navy"])
	if r.has("commander") and String(r["commander"]) != "":
		u["commander"] = String(r["commander"])
		u["commander_conf"] = String(r.get("conf", "LOW"))
		var cid := String(r["commander"])
		if commanders.has(cid):
			commanders[cid]["known"] = true
			raise_conf(commanders[cid], "intel_conf", String(r.get("conf", "LOW")))
	if r.has("status") and String(r["status"]) != "":
		u["status"] = String(r["status"])
		u["status_conf"] = String(r.get("conf", "LOW"))
	note(u, float(r["t_obs"]), String(r.get("summary", r.get("text", ""))), "%s (%s)" % [String(r["source"]), String(r["grade"])])
	return u


func report(id: String) -> Dictionary:
	for r in reports:
		if String(r["id"]) == id:
			return r
	return {}


# --- the captain's reputation ----------------------------------------------------

func captain_event(kind: String, t: float, text: String) -> void:
	match kind:
		"detected":
			captain["stealth"] = clampf(float(captain["stealth"]) - 0.15, -1.0, 1.0)
			captain["known"] = minf(float(captain["known"]) + 0.2, 1.0)
		"evaded":
			captain["stealth"] = clampf(float(captain["stealth"]) + 0.12, -1.0, 1.0)
			captain["known"] = minf(float(captain["known"]) + 0.05, 1.0)
		"attack":
			captain["aggression"] = minf(float(captain["aggression"]) + 0.35, 1.0)
			captain["known"] = minf(float(captain["known"]) + 0.4, 1.0)
		"restraint":
			captain["restraint"] = minf(float(captain["restraint"]) + 0.2, 1.0)
		"rescue":
			captain["humanity"] = minf(float(captain["humanity"]) + 0.3, 1.0)
	(captain["events"] as Array).append({"t": t, "kind": kind, "text": text})


func reputation_text() -> String:
	var parts: Array[String] = []
	var st := float(captain["stealth"])
	parts.append("Stealth: " + ("elusive" if st > 0.3 else ("careful" if st > 0.05 else ("compromised" if st < -0.2 else "unproven"))))
	var ag := float(captain["aggression"])
	if ag > 0.3:
		parts.append("Aggression: quick to use weapons")
	elif float(captain["restraint"]) > 0.2:
		parts.append("Restraint: holds fire under provocation")
	if float(captain["humanity"]) > 0.2:
		parts.append("Has stood by people in distress")
	var kn := float(captain["known"])
	parts.append("Foreign navies: " + ("probably unaware of us" if kn < 0.1 else ("suspect a submarine in the area" if kn < 0.4 else ("know of us, and are looking" if kn < 0.8 else "know VARG by reputation"))))
	return "\n".join(parts)


# --- persistence ------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"units": units.duplicate(true), "commanders": commanders.duplicate(true), "reports": reports.duplicate(true),
		"captain": captain.duplicate(true), "next_unit": _next_unit, "rng": _rng.state}


func load_state(d: Dictionary) -> void:
	var u: Variant = d.get("units")
	if u is Dictionary:
		units = u
	var c: Variant = d.get("commanders")
	if c is Dictionary:
		for k in (c as Dictionary):
			commanders[k] = c[k]
	var r: Variant = d.get("reports")
	if r is Array:
		reports = r
	var cp: Variant = d.get("captain")
	if cp is Dictionary:
		captain = cp
	_next_unit = int(d.get("next_unit", _next_unit))
	if d.has("rng"):
		_rng.state = int(d["rng"])
