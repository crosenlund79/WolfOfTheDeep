class_name StoryPatrol001
extends Node
## ############################################################################
## ##  SPOILERS — STORY CONTENT FOR PATROL 001.                              ##
## ##  If you want to play the patrol without knowing what happens, do not   ##
## ##  read this file (or docs/internal/SPOILERS_PATROL_001.md).             ##
## ############################################################################
##
## Grounded situations that unfold on their own schedule, whether or not the
## captain is watching. Choices are made through ordinary command actions.

var patrol: Patrol
var crew: Crew
var dialogue: Dialogue
var sensors: SensorSuite
var weather: Weather
var clock: GameClock
var sub: Submarine
var area: ArcticArea
var audio: AudioManager
var ships: Dictionary = {}   # role -> SurfaceShip

var stage: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _acc := 0.0
const TICK := 2.0


## Create the area's vessels with their identities and independent routines.
func spawn_vessels(world: Node3D, ocean: Ocean) -> Array[Node3D]:
	_rng.seed = 2031
	var out: Array[Node3D] = []
	var merchant := _ship(world, ocean, SurfaceShip.Kind.MERCHANT, "ARKTIS BRIDGE", "merchant")
	merchant.place(Vector3(19000.0, 0.0, -2000.0), deg_to_rad(250.0), 12.0)
	merchant.set_route([Vector3(9000.0, 0, 3500.0), Vector3(-6000.0, 0, 9000.0), Vector3(-24000.0, 0, 14000.0)], false, 12.0)
	out.append(merchant)
	var trawler := _ship(world, ocean, SurfaceShip.Kind.TRAWLER, "HAVTIND", "trawler")
	trawler.place(Vector3(ArcticArea.BANK_C.x + 900.0, 0.0, ArcticArea.BANK_C.y + 600.0), 1.2, 3.5)
	trawler.behavior = "fishing"
	trawler.fishing_center = Vector3(ArcticArea.BANK_C.x, 0.0, ArcticArea.BANK_C.y)
	trawler.fishing_radius = 1800.0
	out.append(trawler)
	var research := _ship(world, ocean, SurfaceShip.Kind.RESEARCH, "POLAR MERIDIAN", "research")
	research.place(Vector3(-2000.0, 0.0, -14200.0), deg_to_rad(80.0), 6.0)
	research.set_route([Vector3(2500.0, 0, -14500.0), Vector3(7500.0, 0, -15200.0), Vector3(11000.0, 0, -14000.0), Vector3(6000.0, 0, -13600.0), Vector3(1000.0, 0, -14100.0), Vector3(-3500.0, 0, -14300.0)], true, 6.0)
	out.append(research)
	var patrol_ship := _ship(world, ocean, SurfaceShip.Kind.PATROL, "", "patrol")
	patrol_ship.ais_on = false
	patrol_ship.place(Vector3(21000.0, 0.0, -9000.0), deg_to_rad(270.0), 11.0)
	patrol_ship.set_route([Vector3(14000.0, 0, -4000.0), Vector3(15000.0, 0, -13000.0), Vector3(6000.0, 0, -11000.0), Vector3(16000.0, 0, 2000.0)], true, 11.0)
	patrol_ship.behavior = "patrol"
	out.append(patrol_ship)
	var other_sub := _ship(world, ocean, SurfaceShip.Kind.SUBMARINE, "", "visitor")
	other_sub.place(Vector3(24000.0, 0.0, -20000.0), deg_to_rad(250.0), 0.0)
	other_sub.behavior = "drift"
	other_sub.visible = false
	out.append(other_sub)
	return out


func _ship(world: Node3D, ocean: Ocean, kind: SurfaceShip.Kind, vname: String, role: String) -> SurfaceShip:
	var s := SurfaceShip.new()
	s.kind = kind
	s.vessel_name = vname
	s.ocean = ocean
	s.name = role.capitalize()
	s.uid = role
	s.recycle = false
	world.add_child(s)
	ships[role] = s
	return s


func advance(dt: float) -> void:
	_acc += dt
	while _acc >= TICK:
		_acc -= TICK
		_tick()


func _tick() -> void:
	var t := clock.seconds
	var day := clock.day()
	var h := clock.hours()
	# --- Weather: settled first day, deteriorating the second evening. ---
	if day == 1 and h > 14.0 and not stage.has("w_overcast1"):
		stage["w_overcast1"] = true
		weather.set_condition("overcast")
	if day == 1 and h > 20.5 and not stage.has("w_clear_night"):
		stage["w_clear_night"] = true
		weather.set_condition("clear")
	if day == 2 and h > 5.0 and not stage.has("w_fog"):
		stage["w_fog"] = true
		weather.set_condition("fog")
	if day == 2 and h > 10.0 and not stage.has("w_overcast2"):
		stage["w_overcast2"] = true
		weather.set_condition("overcast")
	if day == 2 and h > 15.5 and not stage.has("w_snow"):
		stage["w_snow"] = true
		weather.set_condition("snow")
	if day == 2 and h > 18.5 and not stage.has("w_gale"):
		stage["w_gale"] = true
		weather.set_condition("gale")
	if day == 3 and h > 6.0 and not stage.has("w_after"):
		stage["w_after"] = true
		weather.set_condition("overcast")
	if day == 3 and h > 13.0 and not stage.has("w_clear3"):
		stage["w_clear3"] = true
		weather.set_condition("clear")
	_thread_visitor(t, day, h)
	_thread_trawler(t, day, h)
	_birthday(day, h)


# --- The visitor: something quiet near the research vessel. --------------------

func _thread_visitor(t: float, day: int, h: float) -> void:
	var v: SurfaceShip = ships["visitor"]
	var rs: SurfaceShip = ships["research"]
	if not stage.has("v_msg"):
		stage["v_msg"] = true
		patrol.queue_message("visitor_1", 86400.0 * 0.0 + 18.0 * 3600.0, "NORTHERN COMMAND", "PRIORITY. VARG: RESEARCH VESSEL POLAR MERIDIAN REPORTS UNEXPLAINED NOISE ON ITS HYDROPHONE ARRAY NEAR ICE EDGE. POSSIBLE SUBMERGED ACTIVITY. IF OPPORTUNITY, ATTEMPT CLASSIFICATION. DO NOT INTERFERE. DO NOT BE DETECTED.")
	if not stage.has("v_objective") and patrol.received.any(func(m: Dictionary) -> bool: return m["id"] == "visitor_1"):
		stage["v_objective"] = true
		patrol.add_objective("visitor", "Optional: investigate reported submerged activity near POLAR MERIDIAN.")
	# Arrives in the evening of day 1 and shadows the research vessel overnight.
	if day == 1 and h > 21.0 and not stage.has("v_arrive"):
		stage["v_arrive"] = true
		v.visible = true
		v.position = rs.global_position + Vector3(4500.0, 0.0, -2500.0)
		v.behavior = "route"
		v.set_route([rs.global_position + Vector3(900.0, 0, -500.0)], false, 4.0)
	if stage.has("v_arrive") and not stage.has("v_gone"):
		if v.behavior == "drift" or v.route.size() == 1:
			# Keep station about a kilometre off the research vessel.
			var off := rs.global_position + Vector3(cos(t * 0.0003) * 1100.0, 0.0, sin(t * 0.0003) * 900.0)
			v.set_route([off], false, 3.5)
		var c := sensors.contact_for(v)
		if c and c.status == "TRACKING" and c.class_progress >= 1.0:
			stage["v_tracked_t"] = float(stage.get("v_tracked_t", 0.0)) + 2.0
			if not stage.has("v_classified"):
				stage["v_classified"] = true
				crew.react("contact_classified", {"id": c.id, "cls": "a submarine", "why": "Not one of ours. Very quiet. Single shaft."}, Dialogue.P.REPORT)
				patrol.log_entry("Contact %s classified as a submarine of unknown nationality, near POLAR MERIDIAN." % c.id)
				crew.remember_all("Tracked a foreign submarine near the ice edge.")
			if float(stage["v_tracked_t"]) > 900.0 and not stage.has("v_done"):
				stage["v_done"] = true
				patrol.complete("visitor")
				patrol.flags["visitor_tracked"] = true
				dialogue.say("freja", "I have enough on %s now, Captain. Signature recorded. Whoever they are, they'll be in the report." % c.id, Dialogue.P.REPORT)
		# If we get too close or noisy, it notices us and leaves under the ice.
		var d := v.global_position.distance_to(sub.global_position)
		var noisy := sub.noise_level() > 128.0
		if d < 1500.0 or (d < 4000.0 and noisy):
			stage["v_alarm"] = float(stage.get("v_alarm", 0.0)) + 2.0
		if float(stage.get("v_alarm", 0.0)) > 120.0 or (day == 2 and h > 4.5):
			stage["v_gone"] = true
			if float(stage.get("v_alarm", 0.0)) > 120.0:
				patrol.flags["visitor_alerted"] = true
				patrol.mark_detected("the submerged contact")
			v.set_route([Vector3(v.global_position.x + 3000.0, 0, -26000.0)], false, 14.0)
	if stage.has("v_gone") and v.global_position.z < -24000.0 and v.visible:
		v.visible = false


# --- The trawler: an ordinary boat in an ordinary gale. ---------------------------

func _thread_trawler(t: float, day: int, h: float) -> void:
	var tr: SurfaceShip = ships["trawler"]
	var pv: SurfaceShip = ships["patrol"]
	# Day 2 evening: she stays on the bank too long, then runs east for home in the gale.
	if day == 2 and h > 18.75 and not stage.has("t_run"):
		stage["t_run"] = true
		tr.set_route([Vector3(-2500.0, 0, -2000.0), Vector3(6000.0, 0, 3500.0), Vector3(22000.0, 0, 9000.0)], false, 5.0)
	# Evening, in the gale: engine failure. She drifts toward the rock.
	if day == 2 and h > 19.25 and not stage.has("t_fail") and tr.state == SurfaceShip.State.SAILING:
		stage["t_fail"] = true
		stage["t_fail_time"] = t
		tr.behavior = "drift"
		tr.speed = 0.0
		var to_rock := Vector3(ArcticArea.ROCK_C.x, 0.0, ArcticArea.ROCK_C.y) - tr.global_position
		to_rock.y = 0.0
		var hours := 7.5
		tr.drift_velocity = to_rock / (hours * 3600.0)
		patrol.flags["trawler_failed"] = true
		patrol.log_entry("HAVTIND's propulsion noise stopped in the gale.")
		var c := sensors.contact_for(tr)
		if c and c.status == "TRACKING" and c.sources.has("sonar"):
			dialogue.say("freja", "Conn, sonar. %s's engines have stopped. Shaft noise gone. In this sea, she'll be going wherever the wind takes her." % c.id, Dialogue.P.REPORT)
			dialogue.say("miller", "If she's in trouble she'll be calling on sixteen, Captain. We'd only hear it with a mast up.", Dialogue.P.REPORT)
		patrol.queue_message("mayday", t, "VHF CH 16  (OVERHEARD)", "MAYDAY MAYDAY MAYDAY. THIS IS FISHING VESSEL HAVTIND. ENGINE FAILURE. DRIFTING IN HEAVY WEATHER WEST OF RAVNØYA. NINE PERSONS ON BOARD. REQUEST IMMEDIATE ASSISTANCE.")
	if not stage.has("t_fail"):
		return
	# The captain hears the mayday only with masts up.
	if not stage.has("t_heard") and patrol.received.any(func(m: Dictionary) -> bool: return m["id"] == "mayday"):
		stage["t_heard"] = true
		patrol.add_objective("havtind", "HAVTIND is drifting toward the rocks. Decide what, if anything, we do.")
		_crew_on_mayday()
	# Assistance by the patrol vessel once the distress is relayed through HQ.
	if patrol.flags.has("relayed") and not stage.has("t_pv_sent"):
		stage["t_pv_sent"] = true
		pv.behavior = "route"
		pv.set_route([tr.global_position + Vector3(400.0, 0, 300.0)], false, 17.0)
		patrol.log_entry("HQ relayed the distress call. Coast guard responding.")
	if stage.has("t_pv_sent") and not stage.has("t_pv_arrived") and pv.global_position.distance_to(tr.global_position) < 900.0:
		stage["t_pv_arrived"] = true
		tr.drift_velocity = Vector3.ZERO
		patrol.flags["crew_saved_by_coastguard"] = true
		patrol.log_entry("Coast guard vessel on scene with HAVTIND. She has her under tow.")
		pv.behavior = "station"
	# Our own rescue: surfaced, close aboard, stopped long enough to take them off.
	if not patrol.flags.has("we_rescued") and tr.state == SurfaceShip.State.SAILING:
		var close := sub.is_surfaced() and sub.global_position.distance_to(tr.global_position) < 600.0 and sub.speed < 2.6
		if close:
			stage["t_rescue_t"] = float(stage.get("t_rescue_t", 0.0)) + 2.0
			if float(stage["t_rescue_t"]) > 1500.0:
				patrol.flags["we_rescued"] = true
				patrol.mark_detected("the fishermen we took aboard")
				patrol.log_entry("Took nine fishermen aboard from HAVTIND in the gale. Patrol compromised.")
				dialogue.say("miller", "That's the last of them, Captain. Nine aboard. Cold, frightened, and alive.", Dialogue.P.REPORT)
				crew.remember_all("Took HAVTIND's crew aboard in the gale.")
				patrol.complete("havtind")
		elif stage.has("t_rescue_t") and float(stage["t_rescue_t"]) > 0.0 and not close:
			stage["t_rescue_t"] = maxf(float(stage["t_rescue_t"]) - 4.0, 0.0)
	# The rock.
	var rock := Vector3(ArcticArea.ROCK_C.x, tr.global_position.y, ArcticArea.ROCK_C.y)
	if tr.state == SurfaceShip.State.SAILING and tr.global_position.distance_to(rock) < 260.0 and not stage.has("t_aground"):
		stage["t_aground"] = true
		tr.drift_velocity = Vector3.ZERO
		if patrol.flags.has("we_rescued"):
			patrol.flags["trawler_lost_empty"] = true
			patrol.log_entry("HAVTIND went aground on the rock. Nobody aboard.")
		else:
			patrol.flags["trawler_lost"] = true
			patrol.log_entry("HAVTIND went aground on the rock off Ravnøya.")
		patrol.flags["oil"] = true
		tr.founder()
		var c2 := sensors.contact_for(tr)
		if c2 and c2.status == "TRACKING":
			dialogue.say("freja", "Breaking-up noises from %s. She's on the rock." % c2.id, Dialogue.P.REPORT)
		if not patrol.flags.has("we_rescued") and not patrol.flags.has("crew_saved_by_coastguard"):
			patrol.complete("havtind", true)
	if (patrol.flags.has("crew_saved_by_coastguard")) and not patrol.objective("havtind").is_empty():
		patrol.complete("havtind")


func _crew_on_mayday() -> void:
	dialogue.say("miller", "Captain, that's HAVTIND. The trawler from the bank. Nine aboard. Our orders say covert, sir. They don't say anything about this.", Dialogue.P.REPORT)
	dialogue.say("maya", "With this wind she's setting east, toward the rock off Ravnøya. A few hours, no more.", Dialogue.P.REPORT)
	var b: CrewMember = crew.members["basse"]
	if b.awake:
		dialogue.say("basse", "Nine men in that sea... I did twenty years on ships like that, Captain. Nobody comes, out here. Nobody.", Dialogue.P.REPORT)
	dialogue.say("miller", "We could pass it to Northern Command and let the coast guard deal with it. Or we go ourselves. Your call, Captain.", Dialogue.P.REPORT)


## Called by the command layer when the captain sends a signal to HQ.
func relay_distress() -> bool:
	if not stage.has("t_heard") or patrol.flags.has("relayed"):
		return false
	patrol.flags["relayed"] = true
	patrol.flags["relayed_at"] = clock.seconds
	patrol.queue_message("relay_ack", clock.seconds + 1800.0, "NORTHERN COMMAND", "VARG: YOUR RELAY RECEIVED. COAST GUARD ASSETS NOTIFIED. SOURCE OF REPORT WITHHELD. MAINTAIN COVERT POSTURE.")
	return true


# --- A small, ordinary day. -------------------------------------------------------

func _birthday(day: int, h: float) -> void:
	if day == 2 and h > 12.05 and h < 12.6 and not stage.has("cake") and crew.alert == 0:
		stage["cake"] = true
		dialogue.say("maya", "Basse! Somebody told me it's your birthday.", Dialogue.P.CONVERSATION, "", false)
		dialogue.say("basse", "Who told you that? ...Miller. Of course Miller. Fine. Fifty-eight. There is cake. Don't sing.", Dialogue.P.CONVERSATION, "", false)
		crew.remember_all("Basse's fifty-eighth birthday, with cake.")


## Debrief text: what the world made of our choices.
func debrief_notes() -> Array[String]:
	var out: Array[String] = []
	var f := patrol.flags
	if f.has("visitor_tracked"):
		out.append("The submerged contact near POLAR MERIDIAN was classified and its signature recorded. Analysts are grateful; nobody will say whose it was.")
	elif f.has("visitor_alerted"):
		out.append("The submerged contact withdrew under the ice. It may have heard us. Somewhere, another crew is writing a report about Varg.")
	if f.has("we_rescued"):
		out.append("Nine fishermen from HAVTIND came home aboard a submarine that was not supposed to be there. The patrol was compromised. There will be questions in two capitals. Nine families will not care.")
	elif f.has("crew_saved_by_coastguard"):
		out.append("HAVTIND was taken in tow by a coast guard cutter after a relayed distress call. Nobody knows where the relay came from.")
	elif f.has("trawler_lost"):
		out.append("HAVTIND went aground on the rock off Ravnøya. The coast guard recovered three survivors the next morning. Fuel oil has reached the bird cliffs.")
	elif f.has("trawler_failed") and not f.has("trawler_lost"):
		out.append("HAVTIND's fate was still undecided when we left the area.")
	if f.has("oil"):
		out.append("An oil sheen spreads along Ravnøya's shore.")
	if f.has("fired"):
		out.append("We fired a weapon in peacetime. Whatever else happened on this patrol, that is what it will be remembered for.")
	return out


func save_state() -> Dictionary:
	return {"stage": stage, "acc": _acc, "rng": _rng.state}


func load_state(d: Dictionary) -> void:
	stage = d.get("stage", {})
	_acc = float(d.get("acc", 0.0))
	if d.has("rng"):
		_rng.state = int(d["rng"])
