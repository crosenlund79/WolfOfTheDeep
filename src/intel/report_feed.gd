class_name ReportFeed
extends Node
## Reports about the world reach the boat late and incomplete: an aircraft's
## sighting is written up after it lands, an analyst's summary is hours old,
## an intercept gives an area, the media get things wrong. Every report keeps
## its event time, observation time, time sent and time received apart, and
## carries its source grade (reliability A-F, credibility 1-6) and
## confidence. They travel with Northern Command's six-hourly broadcasts and
## are copied only with a mast up, so a boat that stays deep hears nothing.

const SOURCES := {
	"MPA": ["B", "2", "HIGH", "MARITIME PATROL AIRCRAFT"],
	"SHIP": ["C", "3", "MEDIUM", "SHIP REPORT"],
	"ANALYST": ["B", "3", "MEDIUM", "ANALYST ASSESSMENT"],
	"SIGINT": ["B", "3", "MEDIUM", "SIGNALS INTERCEPT"],
	"MEDIA": ["E", "4", "LOW", "OPEN SOURCE / MEDIA"],
	"RESCUE": ["A", "2", "HIGH", "RESCUE COORDINATION"],
}
const FROM := "N.C. INTELLIGENCE"

var clock: GameClock
var patrol: Patrol
var intel: IntelDB
var traffic: WorldTraffic

var _next := 1
var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _next_summary := 0.0
var _next_sigint := 0.0
var _mpa_seen := {}            # flight id -> {voyage id: true}


func setup() -> void:
	_rng.seed = 3301
	_next_summary = clock.seconds + 9.0 * 3600.0
	_next_sigint = clock.seconds + 20.0 * 3600.0


func advance(dt: float) -> void:
	_acc += dt
	if _acc < 60.0:
		return
	_acc = 0.0
	var now := clock.seconds
	if now >= _next_summary:
		_next_summary = now + _rng.randf_range(11.0, 13.0) * 3600.0
		_summary()
	if now >= _next_sigint:
		_next_sigint = now + _rng.randf_range(14.0, 26.0) * 3600.0
		_sigint()
	_mpa_pass()


static func stamp(t: float) -> String:
	var h := fposmod(t / 3600.0, 24.0)
	return "DAY %d %02d%02d" % [1 + int(t / 86400.0), int(h), int(fposmod(h * 60.0, 60.0))]


func _broadcast_after(t: float) -> float:
	return ceilf(t / 21600.0) * 21600.0 + 30.0


## Create a report and put it on the broadcast after it is sent.
func make(source: String, subject: String, t_event: float, t_obs: float, t_sent: float, pos: Variant, unc: float, summary: String,
		seed: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var src: Array = SOURCES[source]
	var id := "INTREP %03d" % _next
	_next += 1
	var r := {"id": id, "source": source, "grade": String(src[0]) + String(src[1]), "conf": String(src[2]),
		"t_event": t_event, "t_obs": t_obs, "t_sent": t_sent, "t_recv": -1.0, "subject": subject,
		"pos": [] if pos == null else [snappedf((pos as Vector2).x, 1.0), snappedf((pos as Vector2).y, 1.0)], "unc": unc,
		"summary": summary, "seed": seed, "conflicts": []}
	r.merge(extra, true)
	r["text"] = format(r)
	patrol.queue_message("intrep_%d" % (_next - 1), _broadcast_after(t_sent), FROM, String(r["text"]), {"report": r})
	return r


static func format(r: Dictionary) -> String:
	var src: Array = SOURCES[String(r["source"])]
	var t := "%s  ·  SOURCE %s (%s)" % [String(r["id"]), String(src[3]), String(r["grade"])]
	t += "  ·  EVENT %s  ·  OBSERVED %s  ·  SENT %s." % [stamp(float(r["t_event"])), stamp(float(r["t_obs"])), stamp(float(r["t_sent"]))]
	t += "  " + String(r["summary"]).to_upper()
	var p: Array = r["pos"]
	if p.size() == 2:
		t += "  POSITION %s ±%d NM." % [Geography.latlon_text(float(p[0]), float(p[1])), maxi(1, int(round(float(r["unc"]) / 1852.0)))]
	t += "  CONFIDENCE %s." % String(r["conf"])
	return t


func _class_seed(v: Dictionary, correct_p: float, conf: String) -> Dictionary:
	var cls := String(v["class"])
	var c_conf := conf
	if _rng.randf() > correct_p:
		# Misidentified: the other foreign class of similar size.
		cls = "grim" if cls == "boreas" else ("boreas" if cls == "grim" else cls)
		c_conf = "LOW"
	var cname: String = IntelDB.CLASSES.get(cls, {}).get("name", "unknown class")
	var typ: String = IntelDB.CLASSES.get(cls, {}).get("type", "vessel")
	var desig := "%s, %s" % [typ.split(" (")[0], cname]
	if String(v["name"]) != "":
		desig = String(v["name"]) + " (" + typ.split(" (")[0].to_lower() + ")"
	return {"class": cls, "class_conf": c_conf, "designation": desig, "navy": String(v["navy"])}


## Where a voyage was `age` seconds ago, roughly (dead-reckoned back).
static func _back(v: Dictionary, age: float) -> Vector2:
	var p := Vector2(float(v["pos"][0]), float(v["pos"][1]))
	var h := float(v["heading"])
	return p - Vector2(sin(h), -cos(h)) * float(v["knots"]) * 0.5144 * age * 0.8


func _summary() -> void:
	var now := clock.seconds
	for v in traffic.voyages:
		if String(v["navy"]) != "FOREIGN" or String(v["state"]) != "afloat":
			continue
		if not bool(v["active"]):
			if _rng.randf() < 0.6:
				make("ANALYST", String(v["id"]), now - 8.0 * 3600.0, now - 6.0 * 3600.0, now - 2.0 * 3600.0, null, 0.0,
					"Foreign unit previously reported in the region assessed to have left the area.", {}, {"status": "LEFT AREA"})
			continue
		if _rng.randf() > 0.75:
			continue
		var age := _rng.randf_range(4.0, 11.0) * 3600.0
		var err := _rng.randf_range(8000.0, 30000.0)
		var pos := _back(v, age) + Vector2.from_angle(_rng.randf() * TAU) * err * _rng.randf()
		var seed := _class_seed(v, 0.8, "MEDIUM")
		var extra := {}
		var text := "%s operating in the region, course about %03d." % [String(seed["designation"]), int(fposmod(rad_to_deg(float(v["heading"])), 360.0) / 10.0) * 10]
		if String(v["cid"]) != "" and _rng.randf() < 0.5:
			var cmd: Dictionary = intel.commanders.get(String(v["cid"]), {})
			extra["commander"] = String(v["cid"])
			text += " Commanding officer assessed to be the officer known as %s." % String(cmd.get("codename", "?"))
		make("ANALYST", String(v["id"]), now - age, now - age, now - _rng.randf_range(1.0, 3.0) * 3600.0, pos, err * 1.2, text, seed, extra)
	var level := traffic.foreign_alert
	if level > 0.25:
		make("ANALYST", "", now - 4.0 * 3600.0, now - 4.0 * 3600.0, now - 1.0 * 3600.0, null, 0.0,
			"Foreign naval and air activity in the region assessed as %s." % ("increased" if level < 0.6 else "high, consistent with a search for a submarine"))


func _sigint() -> void:
	var now := clock.seconds
	var cands: Array = traffic.voyages.filter(func(v: Dictionary) -> bool: return String(v["navy"]) == "FOREIGN" and bool(v["active"]) and String(v["state"]) == "afloat")
	if cands.is_empty():
		return
	var v: Dictionary = cands[_rng.randi() % cands.size()]
	var age := _rng.randf_range(1.0, 5.0) * 3600.0
	var pos := _back(v, age) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 15000.0)
	var text := "Radar and communications emissions consistent with a foreign warship."
	if _rng.randf() < 0.3:
		# Deception, or a bad fix: far from where the unit really is.
		pos += Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(80000.0, 130000.0)
	make("SIGINT", String(v["id"]), now - age, now - age, now - age + _rng.randf_range(1.0, 3.0) * 3600.0, pos, 25000.0, text,
		{"navy": "FOREIGN", "designation": "Foreign warship (signals fix)"})


## Our own patrol aircraft reports what it flew over (after it lands).
func _mpa_pass() -> void:
	var now := clock.seconds
	for f in traffic.flights:
		if String(f["class"]) != "skua" or bool(f["done"]):
			continue
		var fp := Vector2(float(f["pos"][0]), float(f["pos"][1]))
		var seen: Dictionary = _mpa_seen.get(f["id"], {})
		for v in traffic.voyages:
			if String(v["state"]) != "afloat" or not bool(v["active"]) or seen.has(v["id"]):
				continue
			if not (String(v["navy"]) == "FOREIGN" or String(v["class"]) == "research"):
				continue
			var vp := Vector2(float(v["pos"][0]), float(v["pos"][1]))
			if vp.distance_to(fp) > 45000.0:
				continue
			seen[v["id"]] = true
			var seed := _class_seed(v, 0.95, "HIGH")
			var text := "%s sighted, course %03d speed %d." % [String(seed["designation"]), int(fposmod(rad_to_deg(float(v["heading"])), 360.0)), int(round(float(v["knots"])))]
			make("MPA", String(v["id"]), now, now, now + _rng.randf_range(2.5, 4.5) * 3600.0, vp + Vector2(_rng.randf_range(-1500, 1500), _rng.randf_range(-1500, 1500)), 2500.0, text, seed)
		_mpa_seen[f["id"]] = seen


## A ship has gone down (or been badly hurt) where others will hear of it.
func on_loss(v_key: String, desig: String, pos: Vector3, t: float, navy: String, cid: String, co_survived: bool) -> void:
	var p := Vector2(pos.x, pos.z)
	var crew_n := 18 if navy == "CIVIL" else (180 if desig.contains("rigate") else 95)
	var saved := int(crew_n * _rng.randf_range(0.2, 0.85))
	var rescue_t := t + _rng.randf_range(1.5, 6.0) * 3600.0
	make("RESCUE", v_key, t, rescue_t, rescue_t + 1800.0, p + Vector2(_rng.randf_range(-3000, 3000), _rng.randf_range(-3000, 3000)), 9000.0,
		"%s reported lost. %d survivors recovered so far; search continuing." % [desig, saved], {}, {"status": "SUNK", "survivors": saved})
	var media_t := t + _rng.randf_range(10.0, 30.0) * 3600.0
	var said := maxi(0, saved + _rng.randi_range(-int(saved * 0.6), int(saved * 0.4)))
	var cause: String = ["an explosion of unknown cause", "a collision with ice", "an onboard fire"][_rng.randi() % 3]
	make("MEDIA", v_key, t, media_t, media_t, null, 0.0, "Media report the loss of a vessel in the Arctic after %s; %d said to be rescued." % [cause, said], {}, {"survivors": said})
	if cid != "":
		var cmd: Dictionary = intel.commanders.get(cid, {})
		var at := t + _rng.randf_range(20.0, 44.0) * 3600.0
		var txt := "Commanding officer (%s) reported among the survivors." % String(cmd.get("codename", "?")) if co_survived else "Commanding officer (%s) not reported among the survivors." % String(cmd.get("codename", "?"))
		make("ANALYST", v_key, t, at, at + 3600.0, null, 0.0, txt, {}, {"commander": cid})


# --- persistence ------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"next": _next, "summary": _next_summary, "sigint": _next_sigint, "mpa_seen": _mpa_seen.duplicate(true), "rng": _rng.state}


func load_state(d: Dictionary) -> void:
	_next = int(d.get("next", _next))
	_next_summary = float(d.get("summary", _next_summary))
	_next_sigint = float(d.get("sigint", _next_sigint))
	var m: Variant = d.get("mpa_seen")
	if m is Dictionary:
		_mpa_seen = m
	if d.has("rng"):
		_rng.state = int(d["rng"])
