class_name TestScenario
extends RefCounted
## Test scenarios: short, self-contained set-ups for trying the boat, the
## weapons and the opposition, chosen from the main menu. They run in open
## water far from the patrol area, with the story switched off, saving
## disabled and the developer diagnostics on. Nothing here touches a
## campaign: no save slot is written and no campaign state is read.

const PRESETS := {
	"torpedo_range": {"name": "Torpedo Range",
		"about": "Targets laid out on a range in open water. Stopped hulks, ships steaming steadily, or ships zig-zagging: practise the attack from watching to the hit.",
		"objective": "Sink the targets",
		"site": Vector2(150000.0, 150000.0),
		"defaults": {"allied": 0, "opposing": 3, "difficulty": "normal", "distance_km": 3.0, "weather": "clear", "light": "day", "depth": 1, "speed": 1, "targets": "steady"}},
	"sub_pursuit": {"name": "Submarine Pursuit",
		"about": "Anti-submarine ships have a rough position on you and come looking, pinging. Evade: go deep and quiet, use the layer, open the range.",
		"objective": "Break contact: an hour with no pursuit indication",
		"site": Vector2(-150000.0, 60000.0),
		"defaults": {"allied": 0, "opposing": 2, "difficulty": "normal", "distance_km": 8.0, "weather": "overcast", "light": "day", "depth": 4, "speed": 2, "targets": "steady"}},
	"arctic_nav": {"name": "Arctic Navigation",
		"about": "Take the boat north through drifting icebergs to a waypoint at the edge of the pack, where she cannot surface. Watch the sonar for ice, the keel depths and the chart.",
		"objective": "Reach the waypoint at the ice edge without grounding or collision",
		"site": Vector2(128000.0, 75000.0),
		"defaults": {"allied": 0, "opposing": 0, "difficulty": "normal", "distance_km": 12.0, "weather": "snow", "light": "day", "depth": 4, "speed": 3, "targets": "steady"}},
	"naval_encounter": {"name": "Naval Encounter",
		"about": "Foreign warships on patrol across your track, perhaps with a ship of your own side about. Observe, classify, avoid, or attack.",
		"objective": "Classify the warships",
		"site": Vector2(0.0, 220000.0),
		"defaults": {"allied": 1, "opposing": 2, "difficulty": "normal", "distance_km": 10.0, "weather": "clear", "light": "day", "depth": 1, "speed": 2, "targets": "steady"}},
	"mixed_traffic": {"name": "Mixed Traffic",
		"about": "A busy stretch of water: cargo ships, trawlers, a research vessel and a warship or two. Sort out the picture on sonar and through the periscope.",
		"objective": "Classify the contacts around you",
		"site": Vector2(-60000.0, 200000.0),
		"defaults": {"allied": 1, "opposing": 1, "difficulty": "normal", "distance_km": 6.0, "weather": "overcast", "light": "day", "depth": 1, "speed": 2, "targets": "steady"}},
}
const ORDER := ["torpedo_range", "sub_pursuit", "arctic_nav", "naval_encounter", "mixed_traffic"]

## Parameter choices offered in the menu: key, label, values, names.
const PARAMS := [
	["opposing", "Opposing units", [0, 1, 2, 3, 4, 6], ["None", "1", "2", "3", "4", "6"]],
	["allied", "Allied units", [0, 1, 2, 3], ["None", "1", "2", "3"]],
	["difficulty", "Difficulty", ["easy", "normal", "hard"], ["Easy", "Normal", "Hard"]],
	["distance_km", "Start distance", [2.0, 3.0, 5.0, 8.0, 12.0, 20.0], ["2 km", "3 km", "5 km", "8 km", "12 km", "20 km"]],
	["weather", "Weather", ["clear", "overcast", "fog", "snow", "gale"], ["Clear", "Overcast", "Sea fog", "Snow", "Gale"]],
	["light", "Light", ["day", "night"], ["Daylight", "Darkness"]],
	["depth", "Start depth", [0, 1, 4, 5, 6], ["Surfaced", "Periscope depth", "60 m", "100 m", "150 m"]],
	["speed", "Start speed", [0, 1, 2, 3, 4], ["Stopped", "3 kt", "6 kt", "9 kt", "13 kt"]],
	["targets", "Targets (range)", ["static", "steady", "zigzag"], ["Stopped", "Steady course", "Zig-zagging"]],
]

const ATTITUDE := {
	"easy": {"wary": 0.0, "grudge": 0.0, "aggr": 0.2, "patience": 0.2},
	"normal": {"wary": 0.3, "grudge": 0.3, "aggr": 0.5, "patience": 0.5},
	"hard": {"wary": 0.8, "grudge": 0.8, "aggr": 0.9, "patience": 0.9},
}

var cfg := {}
var preset := ""
var ships: Array[SurfaceShip] = []      # the scenario's own units
var roles := {}                          # ship -> "target" / "opposing" / "allied" / "traffic"
var goal := Vector3.ZERO                 # arctic navigation waypoint
var bergs_added := 0
var started_t := 0.0
var _quiet_since := 0.0
var _zig_t := {}
var _rng := RandomNumberGenerator.new()


static func defaults(id: String) -> Dictionary:
	var d: Dictionary = (PRESETS[id]["defaults"] as Dictionary).duplicate()
	d["preset"] = id
	return d


## A complete configuration: the preset's defaults overlaid with what was chosen.
static func normalised(c: Dictionary) -> Dictionary:
	var id := String(c.get("preset", "torpedo_range"))
	if not PRESETS.has(id):
		id = "torpedo_range"
	var d := defaults(id)
	for k in d.keys():
		if c.has(k):
			d[k] = c[k]
	d["preset"] = id
	return d


func title() -> String:
	return String(PRESETS[preset]["name"])


func site() -> Vector3:
	var s: Vector2 = PRESETS[preset]["site"]
	return Vector3(s.x, 0.0, s.y)


## Set the scenario up in a freshly loaded game (main). Returns the boat's
## starting position.
func build(main: Node, c: Dictionary) -> void:
	cfg = normalised(c)
	preset = String(cfg["preset"])
	_rng.seed = hash(JSON.stringify(cfg))
	var sub: Submarine = main.sub
	var clock: GameClock = main.clock
	var weather: Weather = main.weather
	# Time, weather and light.
	clock.seconds = 12.0 * 3600.0 if String(cfg["light"]) == "day" else 24.0 * 3600.0 + 0.5 * 3600.0
	weather.set_condition(String(cfg["weather"]))
	weather.current = weather.call("_compose_arctic")
	# The boat.
	var here := site()
	var hdg := 0.0
	sub.position = Vector3(here.x, -float(Submarine.DEPTH_MODES[int(cfg["depth"])]["depth"]), here.z)
	sub.set_depth_mode(int(cfg["depth"]))
	sub.depth = float(Submarine.DEPTH_MODES[int(cfg["depth"])]["depth"])
	sub.heading = hdg
	sub.ordered_heading = hdg
	sub.set_speed_step(int(cfg["speed"]))
	sub.speed = float(Submarine.SPEED_STEPS[int(cfg["speed"])]) * Submarine.KNOT
	var dist := float(cfg["distance_km"]) * 1000.0
	var opp := int(cfg["opposing"])
	var ally := int(cfg["allied"])
	var diff := String(cfg["difficulty"])
	match preset:
		"torpedo_range":
			var spd := {"easy": 6.0, "normal": 10.0, "hard": 16.0}[diff] as float
			var mode := String(cfg["targets"])
			for i in maxi(opp, 1):
				var brg := deg_to_rad(-40.0 + 80.0 * (float(i) / maxf(float(maxi(opp, 1) - 1), 1.0)))
				var s := _ship(main, SurfaceShip.Kind.MERCHANT, "TARGET %d" % (i + 1), here + _dir(brg) * (dist + i * 400.0),
					brg + PI * 0.5, 0.0 if mode == "static" else spd, "target")
				if mode == "static":
					s.behavior = "drift"
					s.speed = 0.0
		"sub_pursuit":
			var err := {"easy": 3000.0, "normal": 1500.0, "hard": 600.0}[diff] as float
			for i in maxi(opp, 1):
				var brg2 := deg_to_rad(_rng.randf_range(-60.0, 60.0) + 360.0 * float(i) / float(maxi(opp, 1)))
				var s2 := _ship(main, SurfaceShip.Kind.FRIGATE if i % 2 == 0 else SurfaceShip.Kind.PATROL, "", here + _dir(brg2) * dist, brg2 + PI, 14.0, "opposing")
				s2.behavior = "investigate"
				s2.datum = here + Vector3(_rng.randf_range(-err, err), 0.0, _rng.randf_range(-err, err))
				s2.set("_behavior_t", 7200.0)
				s2.suspicion = 0.5 if diff == "hard" else 0.3
			for j in ally:
				_ship(main, SurfaceShip.Kind.PATROL, "KV NORDKAPP %d" % (j + 1), here + _dir(PI + j) * (dist * 2.0), 0.0, 10.0, "allied")
		"arctic_nav":
			# North to the ice edge, past a seamount and icebergs.
			var edge: float = (main.area.geo as Geography).ice_edge_z(here.x)
			goal = Vector3(here.x, 0.0, edge - 1500.0)
			sub.position.z = goal.z + maxf(dist, 4000.0)
			var n := {"easy": 4, "normal": 8, "hard": 14}[diff] as int
			for k in n:
				var t := float(k + 1) / float(n + 1)
				var p := Vector3(here.x + _rng.randf_range(-2500.0, 2500.0), 0.0, lerpf(sub.position.z - 1500.0, goal.z + 800.0, t))
				main.area.add_berg(p, _rng.randf_range(40.0, 90.0), _rng.randf_range(60.0, 160.0))
				bergs_added += 1
			main.chart.route.clear()
			main.chart.route.append(goal)
			for i3 in opp:
				_ship(main, SurfaceShip.Kind.PATROL, "", goal + Vector3(_rng.randf_range(-6000.0, 6000.0), 0.0, 6000.0), PI * 0.5, 8.0, "opposing").behavior = "patrol"
		"naval_encounter":
			for i4 in maxi(opp, 1):
				var a := deg_to_rad(-30.0 + 25.0 * i4)
				var start := here + _dir(a) * dist + Vector3(-12000.0, 0.0, 0.0)
				var s4 := _ship(main, SurfaceShip.Kind.FRIGATE if i4 % 2 == 0 else SurfaceShip.Kind.PATROL, "", start, PI * 0.5, 12.0, "opposing")
				s4.behavior = "patrol"
				s4.set_route([start + Vector3(30000.0, 0.0, 0.0), start], true, 12.0)
				s4.behavior = "patrol"
			for j4 in ally:
				_ship(main, SurfaceShip.Kind.PATROL, "KV SENJA %d" % (j4 + 1), here + _dir(PI * 0.8 + j4) * (dist * 0.8), PI, 9.0, "allied")
		"mixed_traffic":
			var kinds: Array[int] = [SurfaceShip.Kind.MERCHANT, SurfaceShip.Kind.TRAWLER, SurfaceShip.Kind.MERCHANT, SurfaceShip.Kind.RESEARCH, SurfaceShip.Kind.TRAWLER, SurfaceShip.Kind.MERCHANT]
			var names := ["NORDIC TRADER", "HAVBRIS", "POLAR STAR", "OCEAN SURVEYOR", "SKARVEN", "BALTIC WAY"]
			for k2 in kinds.size():
				var b := _rng.randf() * TAU
				var s5 := _ship(main, kinds[k2], names[k2], here + _dir(b) * dist * _rng.randf_range(0.6, 1.6), _rng.randf() * TAU, 4.0 if kinds[k2] == SurfaceShip.Kind.TRAWLER else 11.0, "traffic")
				if kinds[k2] == SurfaceShip.Kind.TRAWLER:
					s5.behavior = "fishing"
					s5.fishing_center = s5.position
			for i5 in opp:
				var b2 := _rng.randf() * TAU
				var s6 := _ship(main, SurfaceShip.Kind.PATROL, "", here + _dir(b2) * dist * 1.5, b2 + PI * 0.5, 10.0, "opposing")
				s6.behavior = "patrol"
			for j5 in ally:
				_ship(main, SurfaceShip.Kind.PATROL, "KV ANDENES %d" % (j5 + 1), here + _dir(PI + j5) * dist, 0.0, 9.0, "allied")
	for s7 in ships:
		if roles[s7] == "opposing":
			s7.commander = {"id": "", "attitude": ATTITUDE[diff]}
	started_t = clock.seconds
	_quiet_since = clock.seconds


func _dir(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, -cos(a))


func _ship(main: Node, kind: int, vname: String, pos: Vector3, heading: float, knots: float, role: String) -> SurfaceShip:
	var s := SurfaceShip.new()
	s.kind = kind as SurfaceShip.Kind
	s.vessel_name = vname
	s.ocean = main.ocean
	s.uid = "scn_%d" % (ships.size() + 1)
	s.name = "Scenario%d" % (ships.size() + 1)
	s.recycle = false
	# Your own side and civilians show AIS; foreign warships run dark.
	s.ais_on = role != "opposing"
	main.add_child(s)
	s.place(Vector3(pos.x, 0.0, pos.z), heading, knots)
	if knots > 0.0:
		s.set_route([pos + _dir(heading) * 60000.0], false, knots)
	s.speed = knots * 0.5144
	main.vessels.append(s)
	s.pinged.connect(Callable(main, "_on_pinged"))
	s.suspicion_changed.connect(Callable(main, "_on_suspicion"))
	main.call("_watch_ship", s)
	ships.append(s)
	roles[s] = role
	return s


## Zig-zagging targets, the scenario's objective. Called every couple of seconds.
func advance(main: Node, dt: float) -> void:
	var diff := String(cfg.get("difficulty", "normal"))
	if preset == "torpedo_range" and String(cfg.get("targets", "")) == "zigzag":
		var every := {"easy": 900.0, "normal": 480.0, "hard": 240.0}[diff] as float
		var swing := deg_to_rad({"easy": 30.0, "normal": 45.0, "hard": 60.0}[diff] as float)
		for s in ships:
			if not s.is_afloat() or s.state != SurfaceShip.State.SAILING:
				continue
			var t := float(_zig_t.get(s, every * _rng.randf_range(0.3, 1.0))) - dt
			if t <= 0.0:
				t = every
				var nh := s.heading + swing * (1.0 if _rng.randf() < 0.5 else -1.0)
				s.set_route([s.position + _dir(nh) * 60000.0], false, s.cruise_knots)
			_zig_t[s] = t
	var p: Patrol = main.patrol
	if p.objectives.is_empty():
		return
	var o: Dictionary = p.objectives[0]
	match preset:
		"torpedo_range":
			var sunk := ships.filter(func(s: SurfaceShip) -> bool: return s.state != SurfaceShip.State.SAILING).size()
			o["text"] = "%s (%d / %d)." % [PRESETS[preset]["objective"], sunk, ships.size()]
			if sunk >= ships.size() and not bool(o["done"]):
				p.complete("scenario")
		"sub_pursuit":
			var pa: PursuitAssessment = main.pursuit
			if pa.level > 0:
				_quiet_since = main.clock.seconds
			var q: float = (float(main.clock.seconds) - _quiet_since) / 60.0
			o["text"] = "%s (%d of 60 min)." % [PRESETS[preset]["objective"], int(minf(q, 60.0))]
			if q >= 60.0 and main.clock.seconds - started_t > 600.0 and not bool(o["done"]):
				p.complete("scenario")
		"arctic_nav":
			var d := Vector2(main.sub.global_position.x - goal.x, main.sub.global_position.z - goal.z).length()
			o["text"] = "%s (%.1f km to go)." % [PRESETS[preset]["objective"], d / 1000.0]
			if d < 1000.0 and not bool(o["done"]):
				p.complete("scenario")
		"naval_encounter", "mixed_traffic":
			var want := ships.filter(func(s: SurfaceShip) -> bool: return roles[s] == "opposing" or preset == "mixed_traffic")
			var got := 0
			for s2 in want:
				var c: Contact = main.sensors.contact_for(s2)
				if c and c.class_progress >= 1.0:
					got += 1
			o["text"] = "%s (%d / %d)." % [PRESETS[preset]["objective"], got, want.size()]
			if got >= want.size() and want.size() > 0 and not bool(o["done"]):
				p.complete("scenario")


func objective_text() -> String:
	return String(PRESETS[preset]["objective"]) + "."


## The set-up in words, for the briefing.
func setup_lines() -> Array[String]:
	var out: Array[String] = []
	for prm in PARAMS:
		var k := String(prm[0])
		if k == "targets" and preset != "torpedo_range":
			continue
		var i := (prm[2] as Array).find(cfg.get(k))
		out.append("%-16s %s" % [String(prm[1]), String((prm[3] as Array)[i]) if i >= 0 else str(cfg.get(k))])
	return out


## Developer diagnostics: the truth about the scenario's units (never shown
## in normal play).
func diagnostics(main: Node) -> String:
	var own: Vector3 = main.sub.global_position
	var t := "[DEV] SCENARIO TRUTH  ·  %s\n" % title().to_upper()
	for s in ships:
		var rel := s.global_position - own
		var brg := fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		var st := "SUNK" if s.state == SurfaceShip.State.SUNK else ("STRICKEN" if s.state == SurfaceShip.State.STRICKEN else s.behavior.to_upper())
		t += "%-8s %-9s %-9s %03d° %5.1f km %4.1f kt  susp %.2f\n" % [s.uid, String(roles[s]).to_upper(), st, int(brg), Vector2(rel.x, rel.z).length() / 1000.0, s.speed / 0.5144, s.suspicion]
	if preset == "arctic_nav":
		t += "goal %.1f km  ·  under keel %d m\n" % [Vector2(own.x - goal.x, own.z - goal.z).length() / 1000.0, int(main.under_keel())]
	return t
