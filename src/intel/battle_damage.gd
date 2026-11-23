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


## The answer when the captain asks for an assessment of a ship engaged.
## One of VERDICTS, from the evidence only, with what supports it and what
## is still uncertain. `held` is whether the boat holds her now; `engaged_t`
## when she was first fired on.
const VERDICTS := ["CONFIRMED SUNK", "PROBABLE SINKING", "CONFIRMED DAMAGED", "PROBABLE DAMAGE", "NO DAMAGE CONFIRMED", "STATUS UNKNOWN"]


static func verdict(ev: Dictionary, now: float, held: bool) -> Dictionary:
	var a := assess(ev)
	var support: Array[String] = a["evidence"]
	var doubt: Array[String] = []
	var hits := int(ev["hits"])
	var t0 := float(ev.get("engaged_t", ev["t_hit"]))
	var seen_since := float(ev["last_seen"]) >= t0
	var heard_since := float(ev["last_heard"]) >= t0
	var v := "STATUS UNKNOWN"
	var damage_seen := bool(ev["fire"]) or int(ev["list"]) >= 5 or String(ev["trim"]) != "" or int(ev["secondary"]) > 0
	if bool(ev["under"]) or (bool(ev["sunk_report"]) and bool(ev["breaking_up"])):
		v = "CONFIRMED SUNK"
	elif bool(ev["breaking_up"]) or bool(ev["sunk_report"]) or bool(ev["settling"]) or int(ev["list"]) >= 15:
		v = "PROBABLE SINKING"
	elif damage_seen:
		v = "CONFIRMED DAMAGED"
	elif hits > 0:
		v = "PROBABLE DAMAGE"
	elif seen_since or heard_since or held:
		v = "NO DAMAGE CONFIRMED"
	# What is still open, in the crew's words.
	match v:
		"CONFIRMED SUNK":
			if not bool(ev["sunk_report"]):
				doubt.append("No report of her loss has come in yet.")
		"PROBABLE SINKING":
			if not bool(ev["under"]):
				doubt.append("Nobody has seen her go under.")
			if bool(ev["sunk_report"]) and not bool(ev["breaking_up"]) and not seen_since:
				doubt.append("The loss is known only from a report, and reports can be wrong.")
			if not bool(ev["sunk_report"]):
				doubt.append("No report of her loss has come in.")
		"CONFIRMED DAMAGED":
			doubt.append("How badly is not known: she may be fighting it or may make port.")
		"PROBABLE DAMAGE":
			doubt.append("A detonation at the right time is most likely a hit, but nothing of its effect has been seen or heard.")
			if bool(ev["stopped"]):
				doubt.append("She has stopped; that may be damage, or a ship taking stock.")
		"NO DAMAGE CONFIRMED":
			doubt.append("No detonation was heard; she appears unharmed.")
		"STATUS UNKNOWN":
			doubt.append("No detonation heard, and she has not been seen or heard since the attack.")
	if not held and v != "CONFIRMED SUNK":
		var last := maxf(float(ev["last_seen"]), float(ev["last_heard"]))
		doubt.append("Contact not held now%s." % ("; last observed %d min ago" % int((now - last) / 60.0) if last > 0.0 else ""))
	if not seen_since and v in ["PROBABLE SINKING", "CONFIRMED DAMAGED", "PROBABLE DAMAGE"]:
		doubt.append("She has not been seen since the attack; a look through the periscope would tell more.")
	var text := "%s." % v
	if not support.is_empty():
		text += " Evidence: " + " ".join(support)
	if not doubt.is_empty():
		text += " Uncertain: " + " ".join(doubt)
	return {"verdict": v, "text": text, "evidence": support, "uncertain": doubt}
