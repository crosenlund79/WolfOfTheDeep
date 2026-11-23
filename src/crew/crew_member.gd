class_name CrewMember
extends RefCounted
## One person aboard. Game functions are bound to ROLES, not to people: if a
## role holder is asleep, absent or (one day) lost, another qualified person
## covers it, with their own skill.

var id := ""
var name := ""
var short := ""
var rank := ""
var role := ""                 # XO, COOK, SONAR, ENGINEER, NAVIGATOR, WATCH_SONAR, HELM, MACHINIST
var covers: Array[String] = []  # roles this person can stand in for
var nationality := ""
var color := Color.WHITE        # subtitle colour
var skills: Dictionary = {}     # role -> skill multiplier
var principal := false
## Daily routine: [start_hour, end_hour, location, activity]
var routine: Array = []
var location := "bunks"
var activity := "sleeping"
var awake := false
var available := true           # false if injured / lost (not used yet)
var fatigue := 0.0
var candy := {"liquorice": 12, "chocolate": 8, "toffee": 15}
var affinity: Dictionary = {}   # other id -> -1..1 (and "captain")
var history: Array[String] = []
## Poker temperament: tightness 0..1, aggression 0..1, bluff 0..1.
var poker := {"tight": 0.5, "aggro": 0.5, "bluff": 0.2}
## Independent judgement (see Conscience): loyalty to country, trust in the
## government and in command, trust in the captain, loyalty to shipmates,
## willingness to take risks, plus convictions that matter to this person.
var conscience := {"country": 0.75, "government": 0.6, "command": 0.65, "captain": 0.6, "shipmates": 0.75, "risk": 0.5, "convictions": []}
## Concerns this person has formed (and may raise): [{t, topic, text, raised}]
var opinions: Array = []


func skill(r: String) -> float:
	return float(skills.get(r, 0.6))


func can_fill(r: String) -> bool:
	return available and (role == r or r in covers)


func routine_at(hour: float) -> Array:
	for slot in routine:
		var a := float(slot[0])
		var b := float(slot[1])
		var inside := (hour >= a and hour < b) if a <= b else (hour >= a or hour < b)
		if inside:
			return slot
	return [0, 24, "bunks", "sleeping"]


## Sweets are staked one for one at the mess table.
func candy_count() -> int:
	return int(candy.get("toffee", 0)) + int(candy.get("chocolate", 0)) + int(candy.get("liquorice", 0))


func remember(entry: String) -> void:
	history.append(entry)
	if history.size() > 40:
		history.pop_front()


func to_dict() -> Dictionary:
	return {"candy": candy, "affinity": affinity, "history": history, "fatigue": fatigue, "available": available,
		"conscience": conscience.duplicate(true), "opinions": opinions.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	if d.has("candy"):
		candy = d["candy"]
	if d.has("affinity"):
		affinity = d["affinity"]
	if d.has("history"):
		history.clear()
		for h in d["history"]:
			history.append(String(h))
	fatigue = float(d.get("fatigue", fatigue))
	available = bool(d.get("available", available))
	if d.get("conscience") is Dictionary:
		for k in (d["conscience"] as Dictionary).keys():
			conscience[k] = d["conscience"][k]
	if d.get("opinions") is Array:
		opinions = d["opinions"]
