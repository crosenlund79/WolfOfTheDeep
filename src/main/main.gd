extends Node3D
## Wolf of the Deep — Mission 003 "A Living Submarine".
## Builds the world and the boat, runs the patrol clock (time compression,
## rest), routes events between systems (sensors, crew, patrol, story, audio)
## and owns views and controls. Systems stay in their own modules.

enum View { CONTROL, PERISCOPE, EXTERIOR, SONAR, CHART, MESS, CABIN, ENGINE, TORPEDO_CAM, CINEMATIC }

const VIEW_NAMES := ["CONTROL ROOM", "PERISCOPE", "EXTERIOR", "SONAR", "CHART", "MESS", "CAPTAIN'S CABIN", "ENGINE ROOM", "TORPEDO CAM", "CINEMATIC"]
const VIEW_LOC := ["control", "control", "control", "control", "control", "mess", "cabin", "engine", "control", "control"]
const SUBSTEP := 0.25
const START_POS := Vector3(-11000.0, 0.0, 17500.0)
const VOICE_TEXT := {
	"vo_miller_greeting_1": "Ah, Captain, good to have you back aboard. All systems are operational. The crew's at their stations and we're holding our current course. The Arctic's still freezing, the coffee's still dreadful, and thankfully nothing's tried to kill us today. Your orders, Captain?",
	"vo_miller_greeting_2": "There you are, Captain. I was beginning to think you'd found somewhere warmer to spend your time. Can't say I'd blame you. The crew's settled in, systems are behaving themselves, and we've had no unpleasant surprises. Which, as you know, usually means we're due one. Anyway, good to have you back, sir. The boat's yours.",
	"vo_miller_assumes_command": "Very well, Captain. I'll take the watch. We'll maintain course and speed unless circumstances require otherwise. Get some rest, sir. I'll make sure the Arctic is still here when you wake up.",
	"vo_miller_welcome_back": "Morning, Captain. I trust you managed some sleep. We've maintained our assigned course. Engineering reports all systems operational. Basse has been complaining about the coffee again, so nothing particularly unusual there. Shall I bring you up to date, sir?",
	"vo_miller_new_contact_085": "Captain, sonar reports a new contact. Bearing zero-eight-five, relative. Classification unknown. We're tracking it now, sir.",
	"vo_miller_patrol_contact_085": "Captain, sonar reports a new contact. Surface vessel, bearing zero-eight-five, relative. Propeller signature suggests something fairly substantial. Merchant traffic, possibly. No positive identification yet, sir. Shall we take a closer look?",
	"vo_miller_approaching_pd": "Captain, we're approaching periscope depth, slowing our ascent. All stations standing by.",
	"vo_miller_pd_reached": "Periscope depth, sir. Depth steady. We're ready when you are.",
	"vo_miller_contact_lost": "Captain, we've lost the contact. Sonar's searching, but we've nothing reliable at present. I don't particularly like that, sir.",
	"vo_miller_torpedo_away": "Torpedo away, Captain. Weapon running, standing by for impact.",
	"vo_miller_torpedo_impact": "Captain, sonar reports an underwater detonation consistent with torpedo impact, sir. Target status not yet confirmed.",
}
const WHY := {
	"MERCHANT": "Single shaft, slow blade rate. Big.",
	"FISHING": "Small diesel, irregular. Working gear, I think.",
	"RESEARCH": "Diesel-electric, a lot of machinery noise. Stops and starts.",
	"WARSHIP": "Twin shafts, high blade rate. Military, I'm fairly sure.",
}

var clock := GameClock.new()
var weather: Weather
var ocean: Ocean
var sub: Submarine
var rig: CameraRig
var wake_map: WakeMap
var area: ArcticArea
var sensors: SensorSuite
var crew: Crew
var dialogue: Dialogue
var patrol: Patrol
var story: StoryPatrol001
var watch: WatchOfficer
var encounter: Encounter
var audio: AudioManager
var vessels: Array[Node3D] = []
var ships: Array[Node3D] = []
var hud: Hud
var periscope_ui: PeriscopeOverlay
var sonar_ui: SonarConsole
var chart: ChartView
var room: CommandRoom
var mess: MessRoom
var cabin: CabinRoom
var engine_room: EngineRoom
var conn: ConnPanel
var menu: MenuPanel
var poker: PokerTable
## Interior presentation (experiment): an illustrated cutaway of the boat.
var boat: BoatView
var _boat_next := ""

var view := View.CINEMATIC
var started := false
var asleep := false
var _sleep_until := -1.0
var _rest_pending := -1.0
var _wake_reason := ""
var _fire_confirm := 0.0
var _slow_acc := 0.0
var _dr_error := 20.0
var _fix_warned := false
var _cooldowns: Dictionary = {}
var _real := 0.0
var _bio_t := 240.0
var _creak_t := 40.0
var _splash_t := 20.0
var _groan_t := 30.0
var _passed: Dictionary = {}
var _figures: Dictionary = {}
var _battery_warned := 0
var _deep_warned := false
var _was_diesel := false
var _had_leak := false
var _alarm_t := 0.0
var _last_condition := ""
var _aurora_night := -1
var _last_view_loc := "control"

var _sub_trail: WakeTrail
var _mast_trail: WakeTrail
var _ship_trails: Array[WakeTrail] = []
var _focus := Node3D.new()
var _lens: ColorRect
var _lens_mat: ShaderMaterial
var _snow: GPUParticles3D
var _lens_rain := 0.0
var _time := 0.0
var _performance := false
var _capture: Array = []
var _capture_frames := 0
var _capture_dir := ""
var _capture_index := 0
var _sim_hours := 0.0


func _ready() -> void:
	randomize()
	_focus.name = "ViewFocus"
	add_child(_focus)

	ocean = Ocean.new()
	ocean.name = "Ocean"
	add_child(ocean)

	weather = Weather.new()
	weather.name = "Weather"
	weather.ocean = ocean
	weather.clock = clock
	weather.arctic = true
	add_child(weather)

	area = ArcticArea.new()
	area.name = "ArcticArea"
	area.ocean = ocean
	add_child(area)

	sub = Submarine.new()
	sub.name = "Varg"
	sub.ocean = ocean
	add_child(sub)
	sub.position = START_POS
	var to_sector := Vector3(3500.0, 0.0, -12500.0) - START_POS
	sub.heading = atan2(to_sector.x, -to_sector.z)
	sub.ordered_heading = sub.heading
	ocean.register_material(sub.hull_material())

	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)

	dialogue = Dialogue.new()
	dialogue.name = "Dialogue"
	dialogue.audio = audio
	crew = Crew.new()
	crew.name = "Crew"
	crew.clock = clock
	crew.audio = audio
	crew.dialogue = dialogue
	dialogue.crew = crew
	add_child(crew)
	add_child(dialogue)

	story = StoryPatrol001.new()
	story.name = "Story"
	vessels = story.spawn_vessels(self, ocean)
	ships = vessels

	sensors = SensorSuite.new()
	sensors.name = "Sensors"
	sensors.sub = sub
	sensors.area = area
	sensors.weather = weather
	sensors.vessels = vessels
	sensors.clock = clock
	add_child(sensors)

	patrol = Patrol.new()
	patrol.name = "Patrol"
	patrol.clock = clock
	patrol.sub = sub
	patrol.sensors = sensors
	patrol.crew = crew
	patrol.dialogue = dialogue
	patrol.audio = audio
	patrol.area = area
	patrol.weather = weather
	patrol.vessels = vessels
	add_child(patrol)
	patrol.setup()

	story.patrol = patrol
	story.crew = crew
	story.dialogue = dialogue
	story.sensors = sensors
	story.weather = weather
	story.clock = clock
	story.sub = sub
	story.area = area
	story.audio = audio
	add_child(story)

	wake_map = WakeMap.new()
	wake_map.name = "WakeMap"
	wake_map.ocean = ocean
	wake_map.follow = _focus
	add_child(wake_map)
	_sub_trail = WakeTrail.new()
	_sub_trail.source = sub
	_sub_trail.beam = 7.6
	_sub_trail.length_ahead = 36.0
	wake_map.add_trail(_sub_trail)
	_mast_trail = WakeTrail.new()
	_mast_trail.beam = 0.8
	_mast_trail.length_ahead = 0.5
	_mast_trail.intensity = 0.7
	_mast_trail.spacing = 3.0
	wake_map.add_trail(_mast_trail)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.sub = sub
	rig.ocean = ocean
	add_child(rig)
	ocean.follow = rig.camera
	weather.follow = rig.camera

	room = CommandRoom.new()
	room.name = "CommandRoom"
	room.sub = sub
	room.weather = weather
	add_child(room)
	mess = MessRoom.new()
	cabin = CabinRoom.new()
	engine_room = EngineRoom.new()
	for r: InteriorRoom in [mess, cabin, engine_room]:
		r.sub = sub
		add_child(r)
		r.clicked.connect(_on_room_clicked)

	encounter = Encounter.new()
	encounter.name = "Encounter"
	encounter.sub = sub
	encounter.rig = rig
	encounter.ocean = ocean
	encounter.audio = audio
	encounter.wake_map = wake_map
	encounter.ships = ships
	add_child(encounter)
	encounter.setup(self, ships[0] as SurfaceShip)

	watch = WatchOfficer.new()
	watch.name = "Watch"
	watch.sub = sub
	watch.sensors = sensors
	watch.area = area
	watch.patrol = patrol
	watch.crew = crew
	watch.clock = clock
	add_child(watch)

	_build_ui()
	watch.chart = chart
	_build_crew_figures()
	_connect_signals()
	room.setup_screens(rig, ocean, ships)
	room.wire_sonar(sensors, crew)

	_parse_args()
	if _capture.is_empty() and _sim_hours <= 0.0:
		set_view(View.CINEMATIC)
		rig.set_shot(0)
		hud.play_title()
		audio.play_music("mus_main_theme", -6.0)
		get_tree().create_timer(14.0).timeout.connect(_begin_patrol)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_lens = ColorRect.new()
	_lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = load("res://src/fx/lens_fx.gdshader")
	_lens.material = _lens_mat
	ui.add_child(_lens)
	_snow = _make_marine_snow()
	add_child(_snow)
	var scope_post := ColorRect.new()
	scope_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(scope_post)
	periscope_ui = PeriscopeOverlay.new()
	periscope_ui.post_rect = scope_post
	periscope_ui.sub = sub
	periscope_ui.rig = rig
	periscope_ui.ocean = ocean
	periscope_ui.ships = ships
	periscope_ui.weather = weather
	periscope_ui.encounter = encounter
	ui.add_child(periscope_ui)
	sonar_ui = SonarConsole.new()
	sonar_ui.sub = sub
	sonar_ui.ships = ships
	sonar_ui.sensors = sensors
	sonar_ui.crew = crew
	ui.add_child(sonar_ui)
	chart = ChartView.new()
	chart.main = self
	chart.area = area
	chart.sub = sub
	chart.sensors = sensors
	chart.sector_center = patrol.sector_center
	chart.sector_radius = patrol.sector_radius
	chart.rv_point = patrol.rv
	ui.add_child(chart)
	chart.visible = false
	boat = BoatView.new()
	boat.sub = sub
	boat.crew = crew
	boat.weather = weather
	boat.clock = clock
	boat.audio = audio
	boat.encounter = encounter
	boat.area = area
	ui.add_child(boat)
	boat.visible = false
	poker = PokerTable.new()
	poker.crew = crew
	ui.add_child(poker)
	hud = Hud.new()
	hud.main = self
	ui.add_child(hud)
	conn = ConnPanel.new()
	conn.main = self
	conn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	conn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UiStyle.place(conn, Vector2(1, 1), Vector2(-280, -90), Vector2(250, 0))
	ui.add_child(conn)
	menu = MenuPanel.new()
	UiStyle.place(menu, Vector2(0.5, 0.5), Vector2(-330, -320), Vector2(660, 0))
	ui.add_child(menu)


func _connect_signals() -> void:
	weather.lightning_struck.connect(audio.thunder)
	sub.vents_opened.connect(_on_vents)
	sub.breached.connect(_on_breach)
	sub.surfacing.connect(func() -> void: audio.play("submarine_surface", -2.0, 1.0, view == View.EXTERIOR))
	sub.periscope_moved.connect(_on_periscope_moved)
	sub.depth_mode_changed.connect(func(l: String) -> void: hud.toast("DIVING OFFICER:  " + l))
	sub.pd_reached.connect(_on_pd_reached)
	sub.approaching_pd.connect(_on_approaching_pd)
	sub.damaged.connect(_on_damaged)
	dialogue.line_shown.connect(func(sp: String, col: Color, t: String, ch: String) -> void: hud.show_line(sp, col, t, ch))
	dialogue.line_shown.connect(boat.on_line)
	boat.compartment_chosen.connect(_on_boat_compartment)
	boat.hotspot.connect(_on_boat_hotspot)
	boat.talk.connect(_talk)
	crew.moved.connect(_place_crew)
	sensors.contact_new.connect(_on_contact_new)
	sensors.contact_classified.connect(_on_contact_classified)
	sensors.contact_identified.connect(_on_contact_identified)
	sensors.contact_lost.connect(_on_contact_lost)
	sensors.ice_warning.connect(_on_ice_warning)
	area.ice_calved.connect(_on_calving)
	patrol.message_received.connect(_on_message)
	patrol.objectives_changed.connect(func() -> void: hud.toast("OBJECTIVES UPDATED  ·  L  TO READ"))
	patrol.finished.connect(_on_patrol_finished)
	watch.wake_captain.connect(_wake)
	watch.acted.connect(func(t: String) -> void:
		if not asleep:
			hud.toast("XO:  " + t))
	encounter.message.connect(func(t: String) -> void: hud.event(t))
	encounter.torpedo_fired.connect(func(_t: Torpedo) -> void:
		periscope_ui.torpedo_away()
		dialogue.say("miller", VOICE_TEXT["vo_miller_torpedo_away"], Dialogue.P.CRITICAL, "vo_miller_torpedo_away"))
	encounter.target_hit.connect(_on_target_hit)
	chart.course_ordered.connect(_on_course_ordered)
	room.station_selected.connect(_on_station_selected)
	menu.chosen.connect(_on_menu)
	poker.finished.connect(_on_poker_finished)
	conn.command.connect(_on_command)
	for v in vessels:
		var s := v as SurfaceShip
		s.pinged.connect(_on_pinged)
		s.suspicion_changed.connect(_on_suspicion)


func _begin_patrol() -> void:
	if started:
		return
	started = true
	audio.stop_music()
	_boat_next = "_overview"
	set_view(View.CONTROL)
	sub.set_speed_step(3)
	var greet := "vo_miller_greeting_1" if randf() < 0.5 else "vo_miller_greeting_2"
	if sub.hull >= 99.0:
		dialogue.say("miller", VOICE_TEXT[greet], Dialogue.P.REPORT, greet)
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		var b: CrewMember = crew.members["basse"]
		if b.awake and audio.library.has_sound("vo_basse_mutter_danish"):
			audio.play_voice("vo_basse_mutter_danish", AudioManager.Loc.MESS)
			hud.show_line("BASSE", b.color, "(from the galley, something in Danish about the coffee)", "overheard"))
	hud.toast("ORDERS ARRIVE AT PERISCOPE DEPTH  ·  5  CHART  ·  TAB  ORDERS  ·  H  HELP")


# --- simulation ------------------------------------------------------------------

func _process(delta: float) -> void:
	var real_dt := minf(delta, 0.1)
	_real += real_dt
	_tick_rest(real_dt)
	var scale := 1.0
	if started or _sim_hours > 0.0:
		scale = GameClock.REST_SCALE if asleep else clock.scale()
	if patrol.done:
		scale = minf(scale, 1.0)
	var sim := real_dt * scale
	var steps := maxi(1, ceili(sim / SUBSTEP))
	var h := sim / float(steps)
	for _i in steps:
		_sim_step(h)
	ocean.advance(real_dt * minf(scale, 2.0))
	rig.sun_dir = weather.to_sun()
	rig.advance(real_dt)
	_update_focus()
	_update_wakes(real_dt)
	wake_map.advance()
	_update_underwater()
	room.advance(real_dt)
	for r: InteriorRoom in [mess, cabin, engine_room]:
		r.advance(real_dt)
	if started:
		crew.ambient(real_dt)
	_ambient_audio(real_dt)
	audio.update_mix(_audio_loc(), sub, weather, clampf(1.0 - area.coast_distance(sub.position.x, sub.position.z) / 3000.0, 0.0, 1.0), real_dt)
	_update_room_labels()
	_fire_confirm = maxf(_fire_confirm - real_dt, 0.0)
	_alarm_t = maxf(_alarm_t - real_dt, 0.0)
	hud.set_hover("")
	boat.captain_location = crew.captain_location
	boat.captain_asleep = asleep
	boat.poker_open = poker.visible
	if boat.visible:
		hud.set_view_name(boat.comp_name(boat.focus_id))
	if not _capture.is_empty():
		_capture_step()


func _sim_step(h: float) -> void:
	clock.advance(h)
	sub.advance(h)
	area.advance(h)
	var night := weather.darkness() > 0.5
	for v in vessels:
		(v as SurfaceShip).advance(h, sub.position)
		(v as SurfaceShip).set_night(night)
	encounter.advance(h, view == View.PERISCOPE)
	_collide()
	var operator := crew.role_holder("SONAR")
	sensors.sonar_manned = operator != null
	sensors.sonar_skill = operator.skill("SONAR") if operator else 0.5
	sensors.advance(h)
	crew.advance(h)
	watch.advance(h)
	story.advance(h)
	_slow_acc += h
	if _slow_acc >= 2.0:
		_slow_acc -= 2.0
		_slow_tick(2.0)


func _slow_tick(dt: float) -> void:
	patrol.advance(dt)
	var vis := weather.visibility_m()
	var dark := weather.darkness()
	for v in vessels:
		var s := v as SurfaceShip
		if s.visible:
			s.sense_submarine(sub, vis, dark, dt)
		var d := s.global_position.distance_to(sub.global_position)
		if d < 900.0 and s.speed > 1.0 and not sub.is_surfaced() and not _passed.has(s) and s.visible and not s.submerged:
			_passed[s] = true
			audio.play("sfx_ship_propeller_pass", lerpf(-2.0, -12.0, d / 900.0), 1.0, true)
		elif d > 2500.0:
			_passed.erase(s)
	_navigation(dt)
	_plant_reports()
	_update_alert()
	if weather.condition != _last_condition:
		if _last_condition != "" and started:
			hud.toast("WEATHER:  " + weather.condition_label())
		_last_condition = weather.condition
	if float(weather.current.get("aurora", 0.0)) > 0.35 and weather.darkness() > 0.7 and _aurora_night != clock.day() and not asleep and started:
		_aurora_night = clock.day()
		crew.react("aurora", {}, Dialogue.P.CONVERSATION)


func _collide() -> void:
	var info := area.hull_collision(sub.hull_points(), 3.6)
	if not info.is_empty():
		sub.resolve_collision(info)


func _navigation(dt: float) -> void:
	var fix := sub.is_surfaced() or (sub.masts_up and sub.mast_extension() > 0.9 and sub.depth < 12.5)
	if fix:
		if _dr_error > 250.0 and started:
			crew.react("fix_taken", {"err": int(round(_dr_error / 10.0) * 10.0)})
		_dr_error = 15.0
		_fix_warned = false
	else:
		_dr_error += sub.speed * dt * 0.012 + dt * 0.02
		if _dr_error > 900.0 and not _fix_warned:
			_fix_warned = true
			crew.react("fix_needed", {"err": int(round(_dr_error / 50.0) * 50.0)})
	chart.dr_error = _dr_error
	var look := maxf(sub.speed * 300.0, 500.0)
	var ahead := sub.global_position + sub.forward() * look
	var under := area.seabed_depth(ahead.x, ahead.z) - sub.depth
	if under < 25.0 and not watch.active and _cd("shoal", 240.0):
		crew.react("shoal_warning", {"depth": int(maxf(under, 0.0))})
		_drop_time()


func _plant_reports() -> void:
	var b := int(sub.battery)
	if b < 12 and _battery_warned < 2:
		_battery_warned = 2
		crew.react("battery_crit", {"pct": b})
		_drop_time()
	elif b < 30 and _battery_warned < 1:
		_battery_warned = 1
		crew.react("battery_low", {"pct": b})
		_drop_time()
	elif b > 45:
		_battery_warned = 0
	if sub.depth > 180.0 and not _deep_warned:
		_deep_warned = true
		crew.react("deep_creak")
	elif sub.depth < 150.0:
		_deep_warned = false
	var diesel := sub.diesels_running and not sub.is_surfaced()
	if diesel != _was_diesel and not sub.is_surfaced():
		crew.react("snorkel_on" if diesel else "snorkel_off")
	_was_diesel = diesel
	if _had_leak and sub.leak <= 0.0 and sub.flooding < 0.05:
		crew.react("leak_fixed")
	_had_leak = sub.leak > 0.0


func _update_alert() -> void:
	var level := 0
	if crew.silent_running:
		level = 1
	for c in sensors.tracked_vessels():
		if c.range_est < 4000.0:
			level = maxi(level, 1)
	for v in vessels:
		var s := v as SurfaceShip
		if s.behavior == "investigate" and s.global_position.distance_to(sub.global_position) < 8000.0:
			level = 2
	if _alarm_t > 0.0 or sub.flooding > 0.2 or encounter.torpedo_running() or _battle:
		level = 2
	if level >= 2 and crew.alert < 2:
		poker.interrupt("Battle stations. The cards are swept off the table.")
		crew.poker_session = false
		_drop_time()
	crew.alert = level


var _battle := false


func _cd(key: String, seconds: float) -> bool:
	if _real < float(_cooldowns.get(key, -1e9)):
		return false
	_cooldowns[key] = _real + seconds
	return true


func _drop_time() -> void:
	if clock.level > 0 and not asleep:
		clock.set_level(0)
		hud.toast("TIME x1")


# --- ambient world audio (real-time pacing, state-driven) -------------------------

func _ambient_audio(dt: float) -> void:
	if not started or asleep:
		return
	var inside := view != View.EXTERIOR and view != View.CINEMATIC and view != View.TORPEDO_CAM
	_creak_t -= dt
	if _creak_t <= 0.0:
		_creak_t = randf_range(25.0, 70.0)
		if sub.depth > 70.0:
			audio.play_in("sfx_hull_creak_deep" if sub.depth > 140.0 else "sfx_hull_creak", AudioManager.Loc.CONTROL, -8.0 if inside else -16.0)
	_splash_t -= dt
	if _splash_t <= 0.0:
		_splash_t = randf_range(10.0, 26.0)
		if sub.is_surfaced() and inside and float(weather.current.get("hs", 1.0)) > 1.5:
			audio.play_in("sfx_waves_splash_hull", AudioManager.Loc.CONTROL, -10.0)
	_groan_t -= dt
	if _groan_t <= 0.0:
		_groan_t = randf_range(20.0, 50.0)
		var near := area.ice_near(sub.global_position, 700.0)
		if not near.is_empty():
			var big := float((near[0]["berg"] as Dictionary)["r"]) > 50.0
			audio.play_in("sfx_ice_turning_large" if big else "sfx_ice_turning_small", AudioManager.Loc.UNDERWATER, -6.0 if not inside else -10.0)
	_bio_t -= dt * clock.scale()
	if _bio_t <= 0.0:
		_bio_t = randf_range(3000.0, 7000.0)
		if not sub.is_surfaced() and _cd("bio", 120.0):
			var orcas := randf() < 0.35
			audio.play_in("sfx_killer_whales" if orcas else "sfx_whale_song", AudioManager.Loc.UNDERWATER, -8.0)
			if crew.role_holder("SONAR"):
				crew.react("whales", {"brg": "%03d" % randi_range(0, 359)}, Dialogue.P.CONVERSATION)


func _on_calving(pos: Vector3, big: bool) -> void:
	var d := pos.distance_to(sub.global_position)
	if d > 9000.0 or not _cd("calve", 30.0):
		return
	audio.play_in("sfx_ice_calving", AudioManager.Loc.UNDERWATER, lerpf(-2.0, -16.0, d / 9000.0))
	if big and d < 6000.0 and crew.role_holder("SONAR") and started:
		var rel := rad_to_deg(wrapf(atan2(pos.x - sub.position.x, -(pos.z - sub.position.z)) - sub.heading, -PI, PI))
		crew.react("calving", {"side": "starboard" if rel > 0.0 else "port"}, Dialogue.P.CONVERSATION)


# --- sensor and world events ---------------------------------------------------------

func _brg(c: Contact) -> String:
	return "%03d" % (int(round(c.bearing)) % 360)


func _on_contact_new(c: Contact) -> void:
	if c.kind != "VESSEL" or not started:
		return
	var v := c.vessel as SurfaceShip
	var rel := fposmod(c.bearing - rad_to_deg(sub.heading), 360.0)
	if asleep:
		if watch.orders["wake_on_contact"]:
			_wake("New contact %s, bearing %s." % [c.id, _brg(c)])
		return
	if c.sources.has("sonar") and absf(rel - 85.0) < 4.0 and v and not v.submerged and _cd("vo085", 600.0):
		var voice := "vo_miller_patrol_contact_085" if (v.kind == SurfaceShip.Kind.MERCHANT and c.class_progress >= 0.35) else "vo_miller_new_contact_085"
		dialogue.say("miller", VOICE_TEXT[voice], Dialogue.P.REPORT, voice)
	elif c.sources.has("sonar"):
		crew.react("contact_new_vessel", {"id": c.id, "brg": _brg(c)})
	elif c.sources.has("visual"):
		crew.react("contact_new_visual", {"id": c.id, "brg": _brg(c)})
	elif c.sources.has("ais"):
		dialogue.say("maya", "AIS contact, Captain. %s, %s, bearing %s." % [c.ais.get("name", "unnamed"), String(c.ais.get("type", "")).to_lower(), _brg(c)], Dialogue.P.REPORT)
	audio.play("sfx_sonar_inactive_ping", -14.0)
	_drop_time()


func _on_contact_classified(c: Contact) -> void:
	if c.kind != "VESSEL" or asleep or not started or not WHY.has(c.classification):
		return
	var cls := {"MERCHANT": "a merchant", "FISHING": "a fishing vessel", "RESEARCH": "a research vessel", "WARSHIP": "a warship"}
	crew.react("contact_classified", {"id": c.id, "cls": cls[c.classification], "why": WHY[c.classification]})


func _on_contact_identified(c: Contact) -> void:
	if asleep or not started:
		return
	crew.react("contact_identified", {"id": c.id, "name": c.identified_name})


func _on_contact_lost(c: Contact) -> void:
	if c.kind != "VESSEL" or asleep or not started:
		return
	if c.classification in ["WARSHIP", "SUBMARINE", "UNKNOWN", "SUBMERGED"] and _cd("vo_lost", 900.0):
		dialogue.say("miller", VOICE_TEXT["vo_miller_contact_lost"], Dialogue.P.REPORT, "vo_miller_contact_lost")
	else:
		crew.react("contact_lost", {"id": c.id, "brg": _brg(c)})


func _on_ice_warning(c: Contact, dist: float, rel_bearing: float) -> void:
	if watch.active:
		watch.on_ice(c, dist, rel_bearing)
		return
	if not _cd("ice", 90.0):
		return
	crew.react("ice_warning", {"rel": "%03d" % int(fposmod(rel_bearing, 360.0)), "range": int(round(dist / 10.0) * 10.0), "side": "to starboard" if rel_bearing < 0.0 else "to port"}, Dialogue.P.CRITICAL if dist < 400.0 else Dialogue.P.REPORT)
	_drop_time()


func _on_damaged(amount: float, kind: String) -> void:
	if kind == "scrape":
		if _cd("scrape", 12.0):
			audio.play("sfx_ice_scrape", -4.0)
			crew.react("scrape", {}, Dialogue.P.REPORT)
		return
	audio.play("sfx_alarm", -8.0)
	audio.play("sfx_structural_failure" if amount > 12.0 else "sfx_ice_scrape", -2.0)
	rig.shake(clampf(amount / 20.0, 0.3, 1.2))
	_alarm_t = 90.0
	crew.react("collision_ice" if kind == "ice" else "grounding", {}, Dialogue.P.CRITICAL)
	var detail := "Minor. A few frames, some weeping seams." if amount < 8.0 else ("We're taking water forward." if amount < 20.0 else "Serious flooding forward. I need speed off her and an up angle.")
	get_tree().create_timer(5.0).timeout.connect(func() -> void: crew.react("damage_report", {"detail": detail}, Dialogue.P.CRITICAL))
	patrol.log_entry("Collision (%s). Hull integrity %d%%." % [kind, int(sub.hull)])
	_wake("Collision! The boat is damaged.")
	_drop_time()


func _on_pinged(ship: SurfaceShip) -> void:
	var d := ship.global_position.distance_to(sub.global_position)
	if d > 16000.0:
		return
	if not sub.is_surfaced():
		audio.play_in("sfx_sonar_ping", AudioManager.Loc.UNDERWATER, lerpf(-2.0, -18.0, d / 16000.0))
	var c := sensors.contact_for(ship)
	var brg := atan2(ship.position.x - sub.position.x, -(ship.position.z - sub.position.z))
	if not asleep and started and _cd("ping", 120.0):
		crew.react("active_ping", {"brg": "%03d" % int(fposmod(rad_to_deg(brg), 360.0))}, Dialogue.P.REPORT)
	if ship.ping_detects(sub) and not sub.is_surfaced():
		ship.suspicion = minf(ship.suspicion + 0.35, 1.2)
		_on_suspicion(ship, ship.suspicion)
	if c == null:
		patrol.log_entry("Active sonar transmissions heard, bearing %03d." % int(fposmod(rad_to_deg(brg), 360.0)))
	if d < 9000.0 and (ship.behavior == "investigate" or ship.ping_detects(sub)) and clock.seconds > float(_cooldowns.get("ping_wake", -1e9)):
		_cooldowns["ping_wake"] = clock.seconds + 5400.0
		_wake("Active sonar, close. They may have had a sniff of us.")
		_drop_time()


func _on_suspicion(ship: SurfaceShip, level: float) -> void:
	if level > 0.6 and ship.behavior != "investigate" and ship.state == SurfaceShip.State.SAILING and (ship.kind == SurfaceShip.Kind.PATROL or ship.kind == SurfaceShip.Kind.FRIGATE):
		ship.behavior = "investigate"
		ship.datum = sub.global_position + Vector3(randf_range(-900.0, 900.0), 0.0, randf_range(-900.0, 900.0))
		ship.set("_behavior_t", 2400.0)
		var c := sensors.contact_for(ship)
		if c and c.status == "TRACKING":
			crew.react("detected_risk", {"id": c.id}, Dialogue.P.CRITICAL)
		if ship.global_position.distance_to(sub.global_position) < 14000.0:
			_wake("A warship is searching near us.")
			_drop_time()
	if level >= 1.0:
		patrol.mark_detected("a patrol vessel")


func _on_message(msg: Dictionary) -> void:
	var from := String(msg["from"])
	hud.event("MESSAGE  ·  %s  ·  L TO READ" % from)
	if asleep:
		var urgent := String(msg["text"]).begins_with("PRIORITY") or String(msg["text"]).begins_with("MAYDAY")
		if urgent:
			_wake("Signal: %s." % from.to_lower())
		return
	if from == "NORTHERN COMMAND":
		dialogue.say("miller", "Signal from Northern Command, Captain. It's in the log.", Dialogue.P.REPORT)
	_drop_time()


func _on_patrol_finished(report: Dictionary) -> void:
	crew.remember_all("Patrol One ended (%s)." % String(report["how"]))
	crew.save_state()
	var notes := story.debrief_notes()
	var body := "[b]%s[/b]   ·   %s\n\n" % [{"rv": "Arrived at RV HOME.", "overdue": "Overdue. Northern Command has recalled the boat.", "lost": "The boat was lost."}.get(report["how"], ""), report["time"]]
	body += "\n".join(report["objectives"]) + "\n\n"
	for n in notes:
		body += n + "\n\n"
	body += "Hull integrity %d%%." % int(report["hull"])
	menu.open("debrief", "PATROL DEBRIEF", body, [["close", "Continue (free patrol)"], ["quit", "Quit to desktop"]], 720.0)


func _on_target_hit(ship: SurfaceShip) -> void:
	_drop_time()
	patrol.flags["sank_" + (ship.vessel_name if ship.vessel_name != "" else "contact")] = true
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		dialogue.say("miller", VOICE_TEXT["vo_miller_torpedo_impact"], Dialogue.P.CRITICAL, "vo_miller_torpedo_impact"))
	if view == View.TORPEDO_CAM:
		rig.watch_target = ship
		rig.set_mode(CameraRig.Mode.WATCH)


func _on_pd_reached() -> void:
	if started and not asleep and _cd("pd", 60.0):
		dialogue.say("miller", VOICE_TEXT["vo_miller_pd_reached"], Dialogue.P.REPORT, "vo_miller_pd_reached")


func _on_approaching_pd() -> void:
	if started and not asleep and _cd("apd", 120.0):
		dialogue.say("miller", VOICE_TEXT["vo_miller_approaching_pd"], Dialogue.P.REPORT, "vo_miller_approaching_pd")


func _on_vents() -> void:
	if sub.is_surfaced():
		audio.play("sfx_hatch_close", -6.0)
	audio.vents()


func _on_breach(strength: float) -> void:
	rig.shake(strength)
	audio.splash(strength)
	wake_map.add_foam_burst(sub.to_global(Vector3(0, 0, -20.0)), 90.0 * strength, 0.55, 35.0)


func _on_periscope_moved(up: bool) -> void:
	audio.play("periscope_raise" if up else "periscope_lower", -3.0)
	if started and not asleep:
		hud.toast("MASTS  " + ("RAISING" if up else "LOWERING"))


# --- crew in the rooms ---------------------------------------------------------------

func _build_crew_figures() -> void:
	for id in crew.members:
		var m: CrewMember = crew.members[id]
		var f := CrewFigure.new()
		f.setup(id, "%s  ·  %s" % [m.short, m.rank])
		room.root.add_child(f)
		_figures[id] = f
	room.figures.assign(_figures.values())
	_place_crew()


func _place_crew() -> void:
	var control_slots := {"miller": "conn", "rask": "helm", "maya": "nav", "freja": "sonar_1", "haugen": "sonar_2"}
	var spare_control := ["aft", "fire"]
	var used: Dictionary = {}
	var seats := ["seat_1", "seat_2", "seat_3", "seat_4", "seat_5", "seat_6", "seat_7"]
	if poker and poker.visible:
		seats = ["seat_2", "seat_3", "seat_4", "seat_1", "seat_5", "seat_6", "seat_7"]
	for r: InteriorRoom in [mess, cabin, engine_room]:
		r.clear_crew_interactables()
	for id in _figures:
		var f: CrewFigure = _figures[id]
		var m: CrewMember = crew.members[id]
		var target_root: Node3D = null
		var anchor: Array = []
		match m.location:
			"control":
				target_root = room.root
				var slot := String(control_slots.get(id, ""))
				if slot == "" or used.has("c_" + slot):
					slot = ""
					for s in spare_control:
						if not used.has("c_" + s):
							slot = s
							break
				if slot == "" and id == "haugen" and not used.has("c_sonar_1"):
					slot = "sonar_1"
				if slot != "":
					used["c_" + slot] = true
					anchor = room.anchors[slot]
			"mess":
				target_root = mess.root
				var slot2 := ""
				if id == "basse" and m.activity == "cooking":
					slot2 = "galley"
				else:
					for s2 in seats:
						if not used.has("m_" + s2):
							slot2 = s2
							break
				if slot2 != "":
					used["m_" + slot2] = true
					anchor = mess.anchors[slot2]
			"engine":
				target_root = engine_room.root
				var slot3 := "panel" if id == "erik" else "diesel"
				anchor = engine_room.anchors.get(slot3, [])
		if target_root == null or anchor.is_empty():
			f.visible = false
			continue
		f.visible = true
		if f.get_parent() != target_root:
			f.get_parent().remove_child(f)
			target_root.add_child(f)
		f.position = anchor[0]
		f.rotation.y = float(anchor[1])
		f.set_seated(bool(anchor[2]))
		if target_root != room.root:
			var r2: InteriorRoom = mess if target_root == mess.root else engine_room
			r2.add_interactable(f, "crew", id, "%s  ·  %s" % [m.short, m.activity])


func _update_room_labels() -> void:
	mess.clock_label.text = clock.short_time()
	cabin.clock_label.text = clock.short_time()
	cabin.depth_label.text = "%d M" % int(maxf(sub.depth - 2.0, 0.0))
	engine_room.battery_label.text = "BATT %d%%  %s" % [int(sub.battery), "CHARGING" if sub.diesels_running else ""]


func _on_room_clicked(kind: String, what: String) -> void:
	if kind == "crew":
		_talk(what)
		return
	match what:
		"coffee":
			hud.toast("You pour a coffee. Basse was right: it is terrible.")
			audio.play("ui_click", -14.0)
		"poker":
			_open_cards()
		"rest":
			_open_rest()
		"log":
			_open_log()


## Cutaway: a compartment was clicked. The captain goes there.
func _on_boat_compartment(id: String) -> void:
	var v: View = {"control": View.CONTROL, "sonar": View.CONTROL, "torpedo": View.CONTROL, "mess": View.MESS, "cabin": View.CABIN, "engine": View.ENGINE}.get(id, View.CONTROL)
	_boat_next = id
	set_view(v)


## Cutaway: a station or object was clicked.
func _on_boat_hotspot(id: String) -> void:
	match id:
		"periscope":
			set_view(View.PERISCOPE)
		"chart":
			set_view(View.CHART)
		"sonar_console":
			set_view(View.SONAR)
		"orders":
			_open_orders()
		"cards":
			_open_cards()
		"coffee":
			hud.toast("You pour a coffee. Basse was right: it is terrible.")
		"bunk":
			_open_rest()
		"logbook":
			_open_log()
		"engine_panel":
			hud.toast("BATTERY %d%%   ·   AIP %d H   ·   DIESELS %s   ·   HULL %d%%" % [int(sub.battery), int(sub.aip_hours), "RUNNING" if sub.diesels_running else "STOPPED", int(sub.hull)])
		"tubes":
			hud.toast("TUBES  ·  %s" % ("READY" if encounter.can_fire() else "RELOADING %d S" % ceili(encounter.reload)))
		"outside":
			set_view(View.EXTERIOR)
	audio.play("ui_click", -14.0)


func _on_station_selected(kind: String) -> void:
	if kind.begins_with("talk:"):
		_talk(kind.substr(5))
	elif kind == "feed":
		set_view(View.PERISCOPE)
	elif kind == "sonar":
		set_view(View.SONAR)
	else:
		set_view(View.CHART)


func _talk(id: String) -> void:
	var line := crew.talk_to(id)
	if line != "":
		dialogue.say(id, line, Dialogue.P.REPORT, "", false)


func location_text() -> String:
	var where := {"control": "IN THE CONTROL ROOM", "mess": "IN THE MESS", "cabin": "IN YOUR CABIN", "engine": "IN THE ENGINE ROOM"}
	var conn_txt := "  ·  MILLER HAS THE CONN" if watch.active else ""
	return "CAPTAIN %s%s" % [where.get(VIEW_LOC[view], ""), conn_txt]


# --- views -------------------------------------------------------------------------

func _audio_loc() -> AudioManager.Loc:
	match view:
		View.MESS:
			return AudioManager.Loc.MESS
		View.CABIN:
			return AudioManager.Loc.CABIN
		View.ENGINE:
			return AudioManager.Loc.ENGINE
		View.EXTERIOR, View.CINEMATIC, View.TORPEDO_CAM:
			return AudioManager.Loc.UNDERWATER if _camera_depth() > 0.3 else AudioManager.Loc.EXTERIOR
	return AudioManager.Loc.CONTROL


func set_view(v: View) -> void:
	if v == View.TORPEDO_CAM:
		var t := encounter.torpedo_running()
		if t == null:
			hud.toast("NO TORPEDO RUNNING")
			return
		rig.follow_target = t
	view = v
	var loc := String(VIEW_LOC[v])
	crew.captain_location = loc
	dialogue.captain_location = loc
	if loc != _last_view_loc:
		if loc != "mess" and poker.visible:
			poker.interrupt("You leave the table.")
		if loc == "mess" and started and crew.members["basse"].location == "mess" and _cd("enter_mess", 900.0):
			crew.react("enter_mess", {}, Dialogue.P.CONVERSATION)
		_last_view_loc = loc
	periscope_ui.visible = v == View.PERISCOPE
	sonar_ui.visible = v == View.SONAR
	chart.visible = v == View.CHART
	conn.visible = v == View.EXTERIOR or v == View.PERISCOPE or v == View.TORPEDO_CAM
	# Interiors are presented by the cutaway (the 3D rooms stay dormant).
	room.set_active(false)
	mess.set_active(false)
	cabin.set_active(false)
	engine_room.set_active(false)
	var inside := v == View.CONTROL or v == View.MESS or v == View.CABIN or v == View.ENGINE
	boat.visible = inside
	if inside:
		var want: String = {View.CONTROL: "control", View.MESS: "mess", View.CABIN: "cabin", View.ENGINE: "engine"}[v]
		if _boat_next == "_overview":
			want = ""
		elif _boat_next != "":
			want = _boat_next
		_boat_next = ""
		boat.focus_on(want)
	get_viewport().disable_3d = v == View.SONAR or v == View.CHART or inside or asleep
	RenderingServer.global_shader_parameter_set("thermal_mode", 0.0)
	match v:
		View.CINEMATIC:
			rig.set_mode(CameraRig.Mode.CINEMATIC)
			rig.camera.make_current()
		View.EXTERIOR:
			rig.set_mode(CameraRig.Mode.ORBIT)
			rig.camera.make_current()
		View.PERISCOPE:
			rig.set_mode(CameraRig.Mode.PERISCOPE)
			rig.camera.make_current()
			periscope_ui.on_enter()
		View.TORPEDO_CAM:
			rig.set_mode(CameraRig.Mode.FOLLOW)
			rig.camera.make_current()
		_:
			rig.set_mode(CameraRig.Mode.FIXED)
	_place_crew()
	if hud:
		hud.set_view_name(boat.comp_name(boat.focus_id) if inside else VIEW_NAMES[v])


func _update_focus() -> void:
	match view:
		View.EXTERIOR, View.CINEMATIC, View.TORPEDO_CAM:
			_focus.global_position = rig.camera.global_position.lerp(sub.global_position, 0.5)
			ocean.follow = rig.camera
			weather.follow = rig.camera
		View.PERISCOPE:
			_focus.global_position = rig.camera.global_position
			ocean.follow = rig.camera
			weather.follow = rig.camera
		_:
			_focus.global_position = sub.global_position
			ocean.follow = sub
			weather.follow = sub


func _update_wakes(dt: float) -> void:
	var surf := clampf(1.0 - (sub.depth - 2.05) / 5.0, 0.0, 1.0)
	_sub_trail.advance(dt, sub.speed, surf)
	var mast_surface := 0.0
	if sub.depth > 4.0 and sub.mast_extension() > 0.5:
		var head := sub.mast_head()
		mast_surface = clampf(head.y + 1.5, 0.0, 1.0) * clampf(1.0 - (sub.depth - 12.0) / 4.0, 0.0, 1.0)
	_mast_trail.source = sub.get_node("Body/Mast_photonics") as Node3D
	_mast_trail.advance(dt, sub.speed, mast_surface)
	for i in ships.size():
		var s := ships[i] as SurfaceShip
		if i >= _ship_trails.size():
			var t := WakeTrail.new()
			t.source = s
			t.beam = s.beam
			t.length_ahead = s.length * 0.5
			t.spacing = 10.0
			t.intensity = 1.0
			wake_map.add_trail(t)
			_ship_trails.append(t)
		_ship_trails[i].advance(dt, s.speed, 0.0 if s.submerged else 1.0)


func _camera_depth() -> float:
	if view != View.EXTERIOR and view != View.CINEMATIC and view != View.PERISCOPE and view != View.TORPEDO_CAM:
		return sub.depth
	var cp := rig.camera.global_position
	return ocean.height_at(cp.x, cp.z) - cp.y


func _update_underwater() -> void:
	var world_view := view == View.EXTERIOR or view == View.CINEMATIC or view == View.PERISCOPE or view == View.TORPEDO_CAM
	var d := _camera_depth()
	var below := d > 0.05 and world_view
	weather.set_underwater(below, maxf(d, 0.0))
	periscope_ui.mast_submerged = d
	var outside := view == View.EXTERIOR or view == View.CINEMATIC
	_time += get_process_delta_time()
	var want_rain := maxf(float(weather.current.get("rain", 0.0)), float(weather.current.get("snow", 0.0)) * 0.4) if (outside and not below) else 0.0
	_lens_rain = move_toward(_lens_rain, want_rain, get_process_delta_time() * (0.15 if want_rain > _lens_rain else 0.5))
	_lens.visible = outside
	_lens_mat.set_shader_parameter("rain", _lens_rain)
	_lens_mat.set_shader_parameter("underwater", 1.0 if below else 0.0)
	_lens_mat.set_shader_parameter("time", _time)
	_lens_mat.set_shader_parameter("resolution", get_viewport().get_visible_rect().size)
	_snow.emitting = below
	if below:
		_snow.global_position = rig.camera.global_position
		(_snow.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("light_level", 0.25 + float(weather.current.get("light_level", 1.0)) * 0.6)


func _apply_quality() -> void:
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED if _performance else Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _performance else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if _performance else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.75 if _performance else 1.0
	weather.env.ssao_enabled = not _performance
	weather.sun.directional_shadow_max_distance = 220.0 if _performance else 450.0


func _make_marine_snow() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "MarineSnow"
	p.amount = 2500
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 14, 22)
	pm.direction = Vector3(0.2, -0.3, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, -0.04, 0)
	pm.scale_min = 0.03
	pm.scale_max = 0.11
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/soft_particle.gdshader")
	mat.set_shader_parameter("tint", Color(0.75, 0.9, 0.9, 0.55))
	q.material = mat
	p.draw_pass_1 = q
	p.emitting = false
	return p


# --- input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo:
		var k := key_event.keycode
		if poker.visible and poker.handle_key(k):
			return
		if menu.visible and menu.handle_key(k):
			return
	if asleep:
		if key_event and key_event.pressed and not key_event.echo and key_event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			_wake("You wake on your own.", true)
		return
	if not started:
		if (key_event and key_event.pressed) or (event is InputEventMouseButton and event.pressed):
			_begin_patrol()
		return
	if view == View.PERISCOPE and periscope_ui.handle_input(event):
		return
	if view == View.SONAR and sonar_ui.handle_input(event):
		return
	if boat.visible and boat.handle_key(event):
		return
	if (view == View.EXTERIOR or view == View.CINEMATIC or view == View.TORPEDO_CAM or view == View.PERISCOPE) and rig.handle_input(event):
		if view == View.CINEMATIC and (event is InputEventMouseButton):
			set_view(View.EXTERIOR)
		return
	if key_event == null or not key_event.pressed:
		return
	var key := key_event.keycode
	if view == View.CHART and not key_event.echo and chart.handle_key(key):
		return
	if key_event.echo and key not in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
		return
	match key:
		KEY_1:
			set_view(View.CONTROL)
		KEY_2:
			set_view(View.PERISCOPE)
		KEY_3:
			set_view(View.EXTERIOR)
		KEY_4:
			set_view(View.SONAR)
		KEY_5:
			set_view(View.CHART)
		KEY_6:
			set_view(View.MESS)
		KEY_7:
			set_view(View.CABIN)
		KEY_8:
			set_view(View.ENGINE)
		KEY_9:
			set_view(View.TORPEDO_CAM)
		KEY_0:
			set_view(View.CINEMATIC)
		KEY_A, KEY_LEFT:
			_change_course(-1.0 if key_event.shift_pressed else -10.0)
		KEY_D, KEY_RIGHT:
			_change_course(1.0 if key_event.shift_pressed else 10.0)
		KEY_W, KEY_UP:
			_captain_order()
			sub.set_speed_step(sub.speed_step + 1)
			crew.react("speed_order", {"speed": sub.speed_label().capitalize()})
		KEY_S, KEY_DOWN:
			_captain_order()
			sub.set_speed_step(sub.speed_step - 1)
			crew.react("speed_order", {"speed": sub.speed_label().capitalize()})
		KEY_O:
			_on_command("surface")
		KEY_P:
			_on_command("periscope_depth")
		KEY_Z, KEY_PAGEDOWN:
			_on_command("dive")
		KEY_X, KEY_PAGEUP:
			_captain_order()
			_set_depth(sub.depth_mode - 1)
		KEY_M:
			_on_command("scope")
		KEY_B:
			_captain_order()
			if sub.emergency_blow():
				audio.play("sfx_alarm", -8.0)
				set_view(View.EXTERIOR)
				rig.yaw = PI * 0.62
				rig.pitch = 0.04
				rig.distance = 150.0
			else:
				hud.toast("EMERGENCY BLOW NEEDS DEPTH (40 M OR DEEPER)")
		KEY_SPACE:
			if view == View.CINEMATIC:
				rig.next_shot()
			else:
				_on_command("fire")
		KEY_TAB:
			_open_orders()
		KEY_L:
			_open_log()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_BRACKETRIGHT:
			_set_time_level(clock.level + 1)
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_BRACKETLEFT:
			_set_time_level(clock.level - 1)
		KEY_H:
			hud.toggle_help()
		KEY_U:
			hud.visible = not hud.visible
		KEY_F9:
			_performance = not _performance
			_apply_quality()
			hud.toast("GRAPHICS:  " + ("PERFORMANCE" if _performance else "HIGH QUALITY"))
		KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
		KEY_ESCAPE:
			hud.toggle_pause()
			# Consumed here so the pause screen's own Esc handler can't see the
			# same press and close the menu again straight away.
			get_viewport().set_input_as_handled()


func _set_time_level(l: int) -> void:
	var cap := GameClock.LEVELS.size() - 1 if crew.alert < 2 else 1
	var before := clock.level
	clock.set_level(mini(l, cap))
	if clock.level != before:
		hud.toast("TIME  x%d" % int(clock.scale()))
	elif l > cap:
		hud.toast("NOT WITH THE BOAT AT ACTION STATIONS")


## Any direct order from the captain takes back the conn.
func _captain_order() -> void:
	if watch.active and not asleep:
		watch.end()
		crew.miller_has_conn = false
		hud.toast("CAPTAIN HAS THE CONN")


func _change_course(deg: float) -> void:
	_captain_order()
	sub.ordered_heading = wrapf(sub.ordered_heading + deg_to_rad(deg), -PI, PI)
	sub.helm_auto = true
	if _cd("course_voice", 3.0):
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			crew.react("course_order", {"course": "%03d" % (int(round(fposmod(rad_to_deg(sub.ordered_heading), 360.0))) % 360)}))


func _on_course_ordered(heading: float) -> void:
	_captain_order()
	sub.ordered_heading = heading
	sub.helm_auto = true
	crew.react("course_order", {"course": "%03d" % (int(round(fposmod(rad_to_deg(heading), 360.0))) % 360)})


func _set_depth(mode: int) -> void:
	var before := sub.depth_mode
	sub.set_depth_mode(mode)
	if sub.depth_mode == before:
		return
	if before == 0 and sub.depth_mode > 0:
		crew.react("dive")
	elif sub.depth_mode == 0:
		crew.react("surface")
	else:
		crew.react("depth_order", {"depth": String(Submarine.DEPTH_MODES[sub.depth_mode]["label"]).to_lower()})


## Shared by keyboard shortcuts and the on-screen conn buttons.
func _on_command(cmd: String) -> void:
	match cmd:
		"surface":
			_captain_order()
			_set_depth(0)
		"periscope_depth":
			_captain_order()
			_set_depth(1)
		"dive":
			_captain_order()
			_set_depth(sub.depth_mode + 1)
		"scope":
			_captain_order()
			if not sub.masts_up and sub.depth > 25.0:
				hud.toast("TOO DEEP FOR THE MASTS  ·  COME TO PERISCOPE DEPTH (P)")
			else:
				sub.set_periscope(not sub.masts_up)
				crew.react("scope_up" if sub.masts_up else "scope_down")
		"view_scope":
			set_view(View.EXTERIOR if view == View.PERISCOPE else View.PERISCOPE)
		"fire":
			_fire()
		"torpedo_cam":
			set_view(View.TORPEDO_CAM)
		"orders":
			_open_orders()
	if cmd != "fire":
		audio.play("ui_click", -14.0)


## Weapons are real, and so are the rules: the XO challenges the order once.
func _fire() -> void:
	if view != View.PERISCOPE:
		hud.toast("FIRE FROM THE PERISCOPE VIEW  (2)")
		return
	if sub.periscope_state() != Submarine.Scope.CLEAR:
		hud.toast("PERISCOPE NOT CLEAR OF THE WATER  ·  RAISE IT (M) AT PERISCOPE DEPTH (P)")
		return
	if not encounter.can_fire():
		hud.toast("TUBES RELOADING")
		return
	if _fire_confirm <= 0.0:
		_fire_confirm = 7.0
		dialogue.say("miller", "Captain... we are not at war. If we fire, we start one, and everyone will know who did it. Are you certain, sir?", Dialogue.P.CRITICAL)
		hud.event("PRESS SPACE AGAIN TO CONFIRM FIRING")
		return
	_fire_confirm = 0.0
	_captain_order()
	if encounter.fire():
		patrol.flags["fired"] = true
		patrol.log_entry("Torpedo fired on the captain's order.")
		patrol.mark_detected("everyone within fifty miles")
		crew.remember_all("The captain fired a torpedo in peacetime.")
		_drop_time()


# --- orders, log, rest, cards ----------------------------------------------------------

func _open_orders() -> void:
	var items: Array = []
	items.append("SHIP")
	items.append(["silent", "Secure from silent running" if crew.silent_running else "Rig for silent running"])
	var can_snort := sub.depth_mode == 1 and sub.masts_up
	items.append(["snorkel", "Stop snorkelling" if sub.snorkel_ordered else "Snorkel and charge the battery (periscope depth, masts up)", sub.snorkel_ordered or can_snort])
	items.append(["battle", "Stand down from battle stations" if _battle else "Battle stations"])
	items.append("CREW")
	items.append(["sonar_report", "Sonar: report all contacts"])
	items.append(["fix", "Navigator: take a position fix"])
	items.append(["route_sector", "Navigator: lay a course to Sector KESTREL"])
	items.append(["route_rv", "Navigator: lay a course to RV HOME"])
	var radio_ok := patrol.can_copy_traffic()
	if story.stage.has("t_heard") and not patrol.flags.has("relayed"):
		items.append(["relay", "Radio: relay the distress call to Northern Command", radio_ok])
	else:
		items.append(["report", "Radio: transmit a contact report to Northern Command", radio_ok and not patrol.flags.has("reported")])
	items.append(["conn", "I have the conn" if watch.active else "XO: you have the conn (standing orders)"])
	items.append("CAPTAIN")
	items.append(["rest", "Go to my cabin and rest"])
	items.append(["cards", "Call a card game in the mess", crew.alert == 0])
	var body := "Battery %d%%  ·  hull %d%%  ·  position uncertainty about %d m  ·  sonar: %s" % [int(sub.battery), int(sub.hull), int(_dr_error), (crew.role_holder("SONAR").short if crew.role_holder("SONAR") else "unmanned")]
	menu.open("orders", "ORDERS", body, items)


func _on_menu(id: String) -> void:
	match menu.kind:
		"orders":
			menu.close()
			_order(id)
		"rest":
			_rest_choice(id)
		"debrief":
			menu.close()
			if id == "quit":
				get_tree().quit()
		_:
			menu.close()


func _order(id: String) -> void:
	match id:
		"silent":
			crew.silent_running = not crew.silent_running
			sub.silent_running = crew.silent_running
			crew.react("silent_on" if crew.silent_running else "silent_off")
			if crew.silent_running and sub.speed_step > 2:
				sub.set_speed_step(2)
		"snorkel":
			sub.snorkel_ordered = not sub.snorkel_ordered
			if not sub.snorkel_ordered:
				crew.react("snorkel_off")
		"battle":
			_battle = not _battle
			if _battle:
				audio.play("sfx_alarm", -8.0)
				dialogue.say("miller", "Battle stations! Battle stations!", Dialogue.P.CRITICAL)
			else:
				dialogue.say("miller", "Stand down from battle stations. Normal watch routine.", Dialogue.P.REPORT)
		"sonar_report":
			_sonar_report()
		"fix":
			if patrol.can_copy_traffic():
				_dr_error = 15.0
				crew.react("fix_taken", {"err": 0})
			else:
				dialogue.say("maya", "I need a mast above the water for a fix, Captain. Periscope depth, masts up.", Dialogue.P.REPORT)
		"route_sector":
			_lay_route(patrol.sector_center, "Sector KESTREL")
		"route_rv":
			_lay_route(patrol.rv, "RV HOME")
		"relay":
			if story.relay_distress():
				audio.play("sfx_encrypted_message", -6.0)
				patrol.log_entry("Relayed the distress call to Northern Command.")
				dialogue.say("miller", "Relay sent, Captain. Short and encrypted. Let's hope nobody was listening for us.", Dialogue.P.REPORT)
				_transmission_risk()
		"report":
			patrol.flags["reported"] = true
			audio.play("sfx_encrypted_message", -6.0)
			patrol.log_entry("Transmitted a contact report to Northern Command (%d contacts)." % patrol.classified_ids.size())
			dialogue.say("miller", "Report's away, Captain.", Dialogue.P.REPORT)
			_transmission_risk()
		"conn":
			if watch.active:
				_captain_order()
			else:
				watch.begin()
				crew.miller_has_conn = true
				dialogue.say("miller", "I have the conn, Captain.", Dialogue.P.REPORT)
		"rest":
			set_view(View.CABIN)
			_open_rest()
		"cards":
			set_view(View.MESS)
			_open_cards()


func _transmission_risk() -> void:
	for v in vessels:
		var s := v as SurfaceShip
		if s.kind == SurfaceShip.Kind.PATROL and s.global_position.distance_to(sub.global_position) < 30000.0:
			s.suspicion = minf(s.suspicion + 0.3, 1.2)
			_on_suspicion(s, s.suspicion)


func _sonar_report() -> void:
	var cs := sensors.tracked_vessels()
	var who := crew.role_holder("SONAR")
	var speaker := who.id if who else "miller"
	if cs.is_empty():
		dialogue.say(speaker, "Nothing on the array right now, Captain. Ice noise and biologics.", Dialogue.P.REPORT)
		return
	var parts: Array[String] = []
	for c in cs:
		var range_txt := "range about %.1f km" % (c.range_est / 1000.0) if c.range_err < 0.3 else "no range yet"
		parts.append("%s bearing %s, %s, %s" % [c.id, _brg(c), c.label().to_lower(), range_txt])
	dialogue.say(speaker, "Holding %d contacts. %s." % [cs.size(), "; ".join(parts)], Dialogue.P.REPORT)


func _lay_route(target: Vector3, name_txt: String) -> void:
	chart.route.clear()
	var from := sub.global_position
	# A simple dog-leg that keeps clear of the island.
	var mid := from.lerp(target, 0.5)
	if area.coast_distance(mid.x, mid.z) < 2500.0:
		var away := Vector3(mid.x - ArcticArea.ISLAND_C.x, 0.0, mid.z - ArcticArea.ISLAND_C.y).normalized()
		mid = Vector3(ArcticArea.ISLAND_C.x, 0.0, ArcticArea.ISLAND_C.y) + away * (ArcticArea.ISLAND_R + 4500.0)
		chart.route.append(mid)
	chart.route.append(Vector3(target.x, 0.0, target.z))
	chart.route_changed.emit()
	var first := chart.route[0] - from
	_on_course_ordered(atan2(first.x, -first.z))
	dialogue.say("maya", "Course laid to %s, Captain. %d leg%s, about %.0f kilometres." % [name_txt, chart.route.size(), "" if chart.route.size() == 1 else "s", _route_length() / 1000.0], Dialogue.P.REPORT)


func _route_length() -> float:
	var total := 0.0
	var p := sub.global_position
	for w in chart.route:
		total += Vector2(w.x - p.x, w.z - p.z).length()
		p = w
	return total


func _open_log() -> void:
	var body := "[b]OBJECTIVES[/b]\n"
	for o in patrol.objectives:
		var mark := "[color=#7ef0a8]DONE[/color]" if o["done"] else ("[color=#ff6a5a]FAILED[/color]" if o["failed"] else "[color=#9fb3c0]OPEN[/color]")
		body += "%s   %s\n" % [mark, o["text"]]
	body += "\n[b]MESSAGES[/b]\n"
	if patrol.received.is_empty():
		body += "None copied yet. Broadcasts are copied at periscope depth with the masts up.\n"
	for m in patrol.received:
		body += "[color=#ffd29a]%s[/color]\n%s\n\n" % [m["from"], m["text"]]
	if not watch.report.is_empty():
		body += "\n[b]WATCH REPORT (MILLER)[/b]\n" + "\n".join(watch.report.slice(maxi(watch.report.size() - 10, 0))) + "\n"
	body += "\n[b]PATROL LOG[/b]\n"
	for e in patrol.entries.slice(maxi(patrol.entries.size() - 16, 0)):
		body += "[color=#9fb3c0]%s[/color]  %s\n" % [e["t"], e["text"]]
	menu.open("log", "PATROL LOG  ·  %s" % clock.time_string(), body, [["close", "Close"]], 760.0)


func _open_rest() -> void:
	if crew.alert >= 2:
		dialogue.say("miller", "Not now, Captain. Not with the boat at action stations.", Dialogue.P.REPORT)
		return
	var on := func(k: String) -> String: return "[x]" if watch.orders[k] else "[  ]"
	var items: Array = [
		["sleep_2", "Sleep two hours"], ["sleep_4", "Sleep four hours"], ["sleep_8", "Sleep eight hours"], ["sleep_morning", "Sleep until 06:00"],
		"STANDING ORDERS FOR THE WATCH",
		["so_follow_route", "%s  Follow the planned route on the chart" % on.call("follow_route")],
		["so_avoid_contacts", "%s  Keep clear of contacts" % on.call("avoid_contacts")],
		["so_go_deep_on_threat", "%s  Go deep if a warship comes close" % on.call("go_deep_on_threat")],
		["so_charge_battery", "%s  Snorkel to charge when the battery is low and it is safe" % on.call("charge_battery")],
		["so_copy_traffic", "%s  Come up for the scheduled broadcasts" % on.call("copy_traffic")],
		["so_wake_on_contact", "%s  Wake me for every new contact" % on.call("wake_on_contact")],
		["cancel", "Not now"],
	]
	var body := "Miller takes the watch with these standing orders. He keeps your course, speed and depth (now %s, %s) unless the orders or circumstances require otherwise, and wakes you for anything important: collisions, damage, warships searching, urgent signals." % [Submarine.SPEED_NAMES[maxi(sub.speed_step, 1)].to_lower(), sub.depth_label().to_lower()]
	menu.open("rest", "REST  ·  %s" % clock.time_string(), body, items)


func _rest_choice(id: String) -> void:
	if id.begins_with("so_"):
		var k := id.substr(3)
		watch.orders[k] = not watch.orders[k]
		_open_rest()
		return
	menu.close()
	if id == "cancel":
		return
	var hours := 2.0
	match id:
		"sleep_4":
			hours = 4.0
		"sleep_8":
			hours = 8.0
		"sleep_morning":
			var now := clock.hours()
			hours = fposmod(6.0 - now, 24.0)
			if hours < 0.5:
				hours += 24.0
	_start_rest(hours)


func _start_rest(hours: float) -> void:
	set_view(View.CABIN)
	_sleep_until = clock.seconds + hours * 3600.0
	_rest_pending = 2.5
	if not watch.active:
		watch.begin()
	crew.miller_has_conn = true
	dialogue.say("miller", VOICE_TEXT["vo_miller_assumes_command"], Dialogue.P.REPORT, "vo_miller_assumes_command")


func _tick_rest(dt: float) -> void:
	if _rest_pending > 0.0:
		_rest_pending -= dt
		if _rest_pending <= 0.0:
			asleep = true
			crew.captain_asleep = true
			clock.set_level(0)
			hud.set_sleep(true, "Miller has the conn.")
			get_viewport().disable_3d = true
			poker.interrupt("")
			boat.focus_on("")
	if asleep:
		var recent := watch.report.slice(maxi(watch.report.size() - 6, 0))
		hud.set_sleep(true, "Miller has the conn.\n\n" + "\n".join(recent) + "\n\nSPACE  wake up")
		if clock.seconds >= _sleep_until:
			_wake("", true)


## Wake the captain. Planned wakes get the morning report; urgent ones a summons.
func _wake(reason: String, planned: bool = false) -> void:
	_wake_reason = reason
	if not asleep:
		if _rest_pending > 0.0:
			_rest_pending = -1.0
		return
	asleep = false
	crew.captain_asleep = false
	hud.set_sleep(false)
	clock.set_level(0)
	set_view(View.CABIN)
	if planned:
		var morning := clock.hours() > 4.5 and clock.hours() < 10.5
		if morning and watch.report.size() <= 4 and sub.hull >= 99.0:
			dialogue.say("miller", VOICE_TEXT["vo_miller_welcome_back"], Dialogue.P.REPORT, "vo_miller_welcome_back")
		else:
			dialogue.say("miller", "Captain. You're up. A short report when you're ready; it's in the log.", Dialogue.P.REPORT)
		_open_log()
	else:
		audio.play("sfx_alarm", -12.0)
		dialogue.say("miller", "Captain to the control room. %s" % reason, Dialogue.P.CRITICAL)
		hud.event("WOKEN BY THE XO  ·  1  CONTROL ROOM")
	watch.end()
	crew.miller_has_conn = false


func _open_cards() -> void:
	if crew.alert > 0:
		dialogue.say("basse", "Cards? Now? Ha. After, Captain. When nobody is chasing us.", Dialogue.P.REPORT, "", false)
		return
	if view != View.MESS:
		set_view(View.MESS)
	crew.poker_session = true
	crew.advance(0.0)
	_place_crew()
	var players: Array[CrewMember] = []
	for m in crew.present("mess"):
		if m.id in ["basse", "erik", "freja", "maya", "miller", "haugen", "dahl"] and m.activity != "on watch" and m.activity != "has the conn":
			players.append(m)
	var err := poker.open(players)
	if err != "":
		crew.poker_session = false
		hud.toast(err)
		return
	_place_crew()
	dialogue.say("basse", "Sit, sit. Liquorice is worth the same as chocolate here, I don't care what anyone says.", Dialogue.P.CONVERSATION, "", false)


func _on_poker_finished(summary: String) -> void:
	crew.poker_session = false
	if summary.strip_edges() != "":
		hud.event(summary.split("\n")[0])
		hud.toast(summary.split("\n")[-1])
	_place_crew()


# --- capture / headless simulation (development aids) ----------------------------------
# --capture=dir --shots=view:frames:tokens,...   tokens joined with '+':
#   h=HH.H (clock hour), cond=fog, pos=x;z, hdg=deg, depth=mode, scope, yaw=rad,
#   brg=deg (periscope), aim=vessel_role, poker, log, orders, rest, sleep
# --sim-hours=N  runs the patrol headless with Miller on watch and prints the log.

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_capture_dir = a.substr(10)
		elif a.begins_with("--shots="):
			for spec in a.substr(8).split(","):
				_capture.append(spec.split(":"))
		elif a.begins_with("--sim-hours="):
			_sim_hours = float(a.substr(12))
		elif a == "--audio-report":
			# Where every sound comes from (custom / recording / template / missing).
			print("Audio override root: ", audio.library.override_root)
			var names: Array = audio.library.registry.keys() + AudioLibrary.TEMPLATE_NAMES
			for n in names:
				print("AUDIO  %-28s %s" % [n, audio.library.source_of(String(n))])
			print("AUDIO  songs: %d" % audio.library.song_streams().size())
			get_tree().quit()
	if _sim_hours > 0.0:
		_run_simulation.call_deferred()
	elif not _capture.is_empty():
		started = true
		_begin_shot()


func _run_simulation() -> void:
	started = true
	set_view(View.CABIN)
	crew.miller_has_conn = true
	crew.captain_asleep = true
	asleep = true
	_sleep_until = 1e12
	sub.set_depth_mode(3)
	sub.set_speed_step(2)
	_lay_route(patrol.sector_center, "Sector KESTREL")
	watch.begin()
	var t0 := Time.get_ticks_msec()
	var end := clock.seconds + _sim_hours * 3600.0
	var wakes := 0
	while clock.seconds < end and not patrol.done:
		_sim_step(1.0)
		_real += 1.0
		if not asleep:
			wakes += 1
			print("WAKE  ", clock.time_string(), "  ", _wake_reason, "  @", sub.position.round(), " d", int(sub.depth))
			asleep = true
			crew.captain_asleep = true
			watch.begin()
			crew.miller_has_conn = true
	print("SIMULATED %.1f h in %d ms  ·  %s  ·  wakes %d" % [_sim_hours, Time.get_ticks_msec() - t0, clock.time_string(), wakes])
	print("SUB  pos %s  depth %.0f  battery %.0f  hull %.0f  dr %.0f" % [sub.position, sub.depth, sub.battery, sub.hull, _dr_error])
	for o in patrol.objectives:
		print("OBJ  ", "DONE " if o["done"] else ("FAIL " if o["failed"] else "open "), o["text"])
	for e in patrol.entries:
		print("LOG  ", e["t"], "  ", e["text"])
	for r in watch.report:
		print("XO   ", r)
	print("STAGES ", story.stage.keys())
	print("FLAGS ", patrol.flags.keys())
	print("CONTACTS ", sensors.contacts.map(func(c: Contact) -> String: return c.label() + "/" + c.status))
	get_tree().quit()


func _begin_shot() -> void:
	var spec: PackedStringArray = _capture[0]
	var v := int(spec[0])
	var tokens: PackedStringArray = spec[2].split("+") if spec.size() > 2 else PackedStringArray()
	var aim_role := ""
	for tok in tokens:
		var kv := tok.split("=")
		match kv[0]:
			"h":
				clock.seconds = float(int(clock.seconds / 86400.0)) * 86400.0 + float(kv[1]) * 3600.0
			"day":
				clock.seconds = (float(kv[1]) - 1.0) * 86400.0 + clock.hours() * 3600.0
			"cond":
				weather.set_condition(kv[1])
				weather.current = weather.call("_compose_arctic")
			"pos":
				var xz := kv[1].split(";")
				sub.position = Vector3(float(xz[0]), sub.position.y, float(xz[1]))
			"hdg":
				sub.heading = deg_to_rad(float(kv[1]))
				sub.ordered_heading = sub.heading
			"depth":
				sub.set_depth_mode(int(kv[1]))
				sub.depth = float(Submarine.DEPTH_MODES[int(kv[1])]["depth"])
			"scope":
				sub.set_periscope(true)
				for _i in 40:
					sub.advance(0.1)
			"yaw":
				rig.yaw = float(kv[1])
				rig.pitch = 0.08
			"brg":
				rig.bearing = deg_to_rad(float(kv[1]))
			"aim":
				aim_role = kv[1]
			"ship":
				var s: SurfaceShip = story.ships[kv[1]]
				var b := sub.heading + deg_to_rad(float(kv[2]) if kv.size() > 2 else 30.0)
				s.visible = true
				s.position = sub.position + Vector3(sin(b), 0.0, -cos(b)) * (float(kv[3]) if kv.size() > 3 else 1500.0)
				s.position.y = 0.0
			"sim":
				for _i in int(float(kv[1]) / 0.5):
					_sim_step(0.5)
	set_view(v as View)
	for tok in tokens:
		if tok.begins_with("focus="):
			boat.focus_on(tok.substr(6) if tok.substr(6) != "all" else "")
		match tok:
			"poker":
				clock.seconds = float(int(clock.seconds / 86400.0)) * 86400.0 + 20.0 * 3600.0
				crew.advance(0.0)
				_open_cards()
			"log":
				_open_log()
			"orders":
				_open_orders()
			"rest":
				_open_rest()
			"sleep":
				_start_rest(4.0)
				_rest_pending = 0.01
	if aim_role != "":
		var s2: SurfaceShip = story.ships[aim_role]
		var rel := s2.global_position - sub.global_position
		rig.bearing = atan2(rel.x, -rel.z)
		rig.zoom_index = 2
	if v == View.CINEMATIC:
		rig.set_cuts_enabled(false)
	_capture_frames = int(spec[1]) if spec.size() > 1 else 30


func _capture_step() -> void:
	_capture_frames -= 1
	if _capture_frames > 0:
		return
	var spec: PackedStringArray = _capture.pop_front()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_capture_index += 1
	var path := "%s/%02d_view%s.png" % [_capture_dir, _capture_index, spec[0]]
	img.save_png(path)
	print("CAPTURED ", path)
	if _capture.is_empty():
		get_tree().quit()
	else:
		_begin_shot()
