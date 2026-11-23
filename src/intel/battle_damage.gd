class_name BattleDamage
extends RefCounted
## Battle damage assessment: what the boat can say about a ship it has hit,
## built only from what was heard and seen (and later reported), never from
## the ship's real condition. The assessment carries its evidence and its
## confidence and changes as evidence arrives.

const LEVELS := ["NO OBSERVED EFFECT", "HIT, EFFECT UNKNOWN", "DAMAGED", "SERIOUSLY DAMAGED", "PROBABLY SINKING", "PROBABLY SUNK", "SUNK"]


static func new_evidence(contact_id: String, t: float) -> Dictionary:
	return {"contact": contact_id, "t_hit": t, "hits": 0, "secondary": 0, "fire": false, "list": 0, "trim": "", "settling": false,
		"stopped": false, "under_way": false, "breaking_up": false, "under": false, "last_seen": -1.0, "last_heard": -1.0,
		"sunk_report": false, "survivors": -1, "level": "", "conf": ""}


## Update the evidence from one look (periscope or bridge) and / or one listen
## (sonar). `seen` is what a lookout could make out of the ship.
static func observe(ev: Dictionary, seen: Dictionary, eyes: bool, ears: bool, now: float) -> void:
	if eyes:
		ev["last_seen"] = now
		ev["fire"] = bool(seen.get("fire", false))
		ev["list"] = int(round(absf(float(seen.get("list", 0.0))) / 5.0) * 5.0)
		var trim := float(seen.get("trim", 0.0))
		ev["trim"] = "" if absf(trim) < 3.0 else ("by the bow" if trim > 0.0 else "by the stern")
		ev["settling"] = float(seen.get("settle", 0.0)) > 1.5
		ev["stopped"] = float(seen.get("speed", 0.0)) < 0.4
		ev["under_way"] = not bool(ev["stopped"])
		if bool(seen.get("under", false)):
			ev["under"] = true
	if ears:
		ev["last_heard"] = now
		var moving := float(seen.get("speed", 0.0)) > 0.5
		ev["stopped"] = not moving
		ev["under_way"] = moving
		if bool(seen.get("breaking", false)):
			ev["breaking_up"] = true


static func assess(ev: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var hits := int(ev["hits"])
	if hits > 0:
		lines.append("Detonation heard%s at the expected time." % ("" if hits == 1 else " %d times" % hits))
	if int(ev["secondary"]) > 0:
		lines.append("Secondary explosion%s heard." % ("" if int(ev["secondary"]) == 1 else "s"))
	if bool(ev["fire"]):
		lines.append("Fire and smoke seen.")
	if int(ev["list"]) >= 5:
		lines.append("Listing, about %d°." % int(ev["list"]))
	if String(ev["trim"]) != "":
		lines.append("Down %s." % String(ev["trim"]))
	if bool(ev["settling"]):
		lines.append("Settling in the water.")
	if bool(ev["stopped"]):
		lines.append("No way on her; screws stopped.")
	elif bool(ev["under_way"]):
		lines.append("Still under way.")
	if bool(ev["breaking_up"]):
		lines.append("Breaking-up noises on sonar.")
	if bool(ev["under"]):
		lines.append("Seen to go under.")
	if bool(ev["sunk_report"]):
		lines.append("Rescue coordination reports her lost%s." % ("" if int(ev["survivors"]) < 0 else ", %d survivors" % int(ev["survivors"])))
	var level := "NO OBSERVED EFFECT"
	var conf := "LOW"
	if bool(ev["under"]) or (bool(ev["sunk_report"]) and bool(ev["breaking_up"])):
		level = "SUNK"
		conf = "HIGH"
	elif bool(ev["sunk_report"]):
		level = "SUNK"
		conf = "MEDIUM"
	elif bool(ev["breaking_up"]):
		level = "PROBABLY SUNK"
		conf = "MEDIUM"
	elif bool(ev["settling"]) or int(ev["list"]) >= 15:
		level = "PROBABLY SINKING"
		conf = "MEDIUM" if (bool(ev["settling"]) and int(ev["list"]) >= 10) else "LOW"
	elif bool(ev["stopped"]) and (bool(ev["fire"]) or int(ev["list"]) >= 5):
		level = "SERIOUSLY DAMAGED"
		conf = "MEDIUM"
	elif bool(ev["fire"]) or int(ev["list"]) >= 5 or int(ev["secondary"]) > 0:
		level = "DAMAGED"
		conf = "MEDIUM" if float(ev["last_seen"]) > 0.0 else "LOW"
	elif hits > 0:
		level = "HIT, EFFECT UNKNOWN"
		conf = "LOW"
	var text := "%s (%s confidence)." % [level, conf.to_lower()]
	if not lines.is_empty():
		text += " " + " ".join(lines)
	return {"level": level, "conf": conf, "text": text, "evidence": lines}
