class_name Encounter
extends Node
## Prototype 002 "First Contact": one target on a fixed crossing course, a
## simple assisted firing solution, torpedoes, hits and the scripted sinking.
## No detection, enemy AI or fire-control model.

signal message(text: String)
signal torpedo_fired(torpedo: Torpedo)
signal target_hit(ship: SurfaceShip)
## Stages of an attack as the boat knows them: launch, seeker telemetry,
## suspected / confirmed miss, impact, result unknown, post-attack assessment.
signal engagement(kind: String, text: String)

const RELOAD_TIME := 6.0
const TUBES := 4

var sub: Submarine
var rig: CameraRig
var ocean: Ocean
var audio: AudioManager
var wake_map: WakeMap
var world: Node3D
var target: SurfaceShip
var ships: Array[Node3D] = []

var torpedoes: Array[Torpedo] = []
var weather: Weather
var sensors: SensorSuite
## The attack party's estimate of the target (see FireControl).
var fc := FireControl.new()
## One record per torpedo fired: what was known and what came back.
var engagements: Array = []
## Developer / test scenarios only: exact technical outcome of each run.
var dev_diag := false
var _last_heading := 0.0
## 0..1 solution quality (kept for meters): FIRM = 1.
var solution := 0.0
var locked: SurfaceShip
var reload := 0.0
var tube := 0
var fired := 0
var hits := 0
var _trails: Dictionary = {}
var last_contact := ""


func setup(p_world: Node3D, p_target: SurfaceShip) -> void:
	world = p_world
	target = p_target
	for s in ships:
		var ship := s as SurfaceShip
		ship.sinking_started.connect(_on_sinking_started)
		ship.secondary_blast.connect(_on_secondary)
		ship.went_under.connect(_on_went_under)
		ship.sunk.connect(_on_sunk)


## A ship that joined the picture later (regional traffic): sinking effects.
func watch_ship(ship: SurfaceShip) -> void:
	if not ship.sinking_started.is_connected(_on_sinking_started):
		ship.sinking_started.connect(_on_sinking_started)
		ship.secondary_blast.connect(_on_secondary)
		ship.went_under.connect(_on_went_under)
		ship.sunk.connect(_on_sunk)


## Place the target on a crossing course ahead of the boat (also used to replay).
func reset_target() -> void:
	var brg := sub.heading - deg_to_rad(48.0)
	var rng := 1700.0
	var pos := sub.global_position + Vector3(sin(brg), 0.0, -cos(brg)) * rng
	target.reset_to(pos, sub.heading + deg_to_rad(88.0), 9.0)
	solution = 0.0
	last_contact = "NEW CONTACT  ·  MERCHANT BEARING %03d  ·  1.7 KM  ·  CROSSING LEFT TO RIGHT" % int(fposmod(rad_to_deg(brg), 360.0))
	message.emit(last_contact)


func torpedo_running() -> Torpedo:
	for t in torpedoes:
		if is_instance_valid(t) and not t.done:
			return t
	return null


## Called every frame; the scope builds a solution while held on a ship.
func advance(dt: float, scope_active: bool) -> void:
	reload = maxf(reload - dt, 0.0)
	locked = null
	if scope_active and sub.periscope_state() == Submarine.Scope.CLEAR:
		var best := 1e9
		for s in ships:
			var ship := s as SurfaceShip
			if not ship.is_afloat() or not ship.visible or ship.submerged:
				continue
			var rel := ship.global_position - sub.global_position
			var dist := Vector2(rel.x, rel.z).length()
			# Only what can be seen can be tracked through the periscope.
			var eye := 14000.0
			if weather and weather.arctic:
				eye = minf(weather.visibility_m() * (1.0 - weather.darkness() * 0.6), 14000.0)
			if dist > minf(7000.0, eye):
				continue
			var brg := atan2(rel.x, -rel.z)
			var off := absf(wrapf(brg - rig.bearing, -PI, PI))
			var half := atan2(ship.length * 0.5, dist) + deg_to_rad(0.4)
			if off < half and off < best:
				best = off
				locked = ship
	if locked:
		fc.observe(locked, sub.global_position, dt, FireControl.conditions(weather), sensors.contact_for(locked) if sensors else null)
	else:
		fc.age(dt)
	solution = fc.quality_value()
	# A hard turn or a deep dive parts the guidance wires.
	var turn_rate := absf(wrapf(sub.heading - _last_heading, -PI, PI)) / maxf(dt, 0.001)
	_last_heading = sub.heading
	if turn_rate > deg_to_rad(3.0) or sub.depth > 150.0:
		for t0 in torpedoes:
			if is_instance_valid(t0) and not t0.done:
				t0.cut_wire()
	_track_engagements(dt)
	for t in torpedoes.duplicate():
		if not is_instance_valid(t):
			torpedoes.erase(t)
			continue
		t.advance(dt)
		if _trails.has(t):
			(_trails[t] as WakeTrail).advance(dt, t.speed, 0.55 if t.depth < 6.0 else 0.0)


## Testing only: no reload and no limit on torpedoes.
var unlimited := false


func can_fire() -> bool:
	if not unlimited and sub.torpedoes <= 0:
		return false
	return reload <= 0.0 or unlimited


## Fire along the scope bearing; a solution on a ship adds the lead.
func fire() -> bool:
	if not can_fire():
		message.emit("NO TORPEDOES REMAINING" if sub.torpedoes <= 0 else "TUBES RELOADING  ·  %d S" % ceili(reload))
		return false
	var from := sub.tube_transform(tube)
	var course := rig.bearing
	var res := {}
	if fc.has_solution():
		res = fc.lead(from)
		if not res.is_empty():
			course = float(res["course"])
	# Gyro setting error.
	course += deg_to_rad(randfn(0.0, 0.25))
	var torp := Torpedo.new()
	torp.name = "Torpedo%d" % (fired + 1)
	torp.targets = ships
	if fc.target:
		torp.run_depth = clampf(fc.target.draft * 0.6 + 1.0, 2.5, 6.0)
	var hs := float(weather.current.get("hs", 1.5)) if weather else 1.5
	torp.sea_factor = clampf(1.15 - hs / 6.0, 0.5, 1.0)
	world.add_child(torp)
	torp.launch(from, course)
	var c := sensors.contact_for(fc.target) if sensors and fc.target else null
	var rec := {"n": fired + 1, "tube": tube + 1, "age": 0.0, "contact": c.id if c else "", "quality": fc.quality(), "summary": fc.summary(),
		"est_course": fc.est_course, "est_speed": fc.est_speed, "est_range": fc.est_range, "expected": float(res.get("t", -1.0)),
		"in_reach": bool(res.get("in_reach", true)), "state": "running", "events": [], "torp": torp, "target": fc.target,
		"true_heading": fc.target.heading if fc.target else 0.0, "gyro": fposmod(rad_to_deg(course), 360.0)}
	engagements.append(rec)
	torp.telemetry.connect(_on_telemetry.bind(rec))
	torp.struck.connect(_on_struck.bind(torp))
	torp.ran_out.connect(_on_ran_out.bind(torp))
	torpedoes.append(torp)
	audio.play("torpedo_launch", 0.0)
	audio.attach_loop("torpedo_running", torp, -4.0)
	var trail := WakeTrail.new()
	trail.source = torp
	trail.beam = 0.6
	trail.length_ahead = 0.0
	trail.intensity = 0.45
	trail.spacing = 4.0
	wake_map.add_trail(trail)
	_trails[torp] = trail
	_launch_bubbles(from.origin)
	tube = (tube + 1) % TUBES
	reload = 0.0 if unlimited else RELOAD_TIME
	fired += 1
	if not unlimited:
		sub.torpedoes = maxi(sub.torpedoes - 1, 0)
	var aim := "SOLUTION %s" % String(rec["quality"]) if fc.has_solution() else "NO SOLUTION  ·  STRAIGHT RUN"
	message.emit("TORPEDO AWAY  ·  TUBE %d  ·  %s" % [(tube + TUBES - 1) % TUBES + 1, aim])
	var exp_txt := ""
	if float(rec["expected"]) > 0.0:
		exp_txt = ", run to the expected intercept about %d:%02d" % [int(float(rec["expected"])) / 60, int(float(rec["expected"])) % 60]
	var launch := "Launch confirmed, T%d from tube %d, gyro %03d%s. Solution %s (%s)." % [int(rec["n"]), int(rec["tube"]), int(rec["gyro"]), exp_txt, String(rec["quality"]).to_lower(), String(rec["summary"]).to_lower()]
	if not bool(rec["in_reach"]):
		launch += " The target is estimated to be beyond the weapon's reach."
	engagement.emit("launch", launch)
	torpedo_fired.emit(torp)
	return true


func _on_telemetry(kind: String, rec: Dictionary) -> void:
	(rec["events"] as Array).append(kind)
	match kind:
		"seeker_on":
			engagement.emit("telemetry", "T%d: seeker enabled (telemetry)." % int(rec["n"]))
		"acquired":
			engagement.emit("telemetry", "T%d: seeker has acquired a target (telemetry)." % int(rec["n"]))
		"lost":
			engagement.emit("telemetry", "T%d: seeker has lost its target (telemetry)." % int(rec["n"]))
		"wire_cut":
			engagement.emit("telemetry", "T%d: guidance wire parted; no more telemetry." % int(rec["n"]))


## Watch each run against what was expected: a suspected miss when the time
## is up and nothing has gone off; confirmed only with evidence.
func _track_engagements(dt: float) -> void:
	for rec in engagements:
		if String(rec["state"]) in ["hit", "miss_confirmed", "unknown", "assessed"]:
			continue
		rec["age"] = float(rec["age"]) + dt
		var torp: Torpedo = rec["torp"] if is_instance_valid(rec["torp"]) else null
		var exp_t := float(rec["expected"])
		if String(rec["state"]) == "running" and exp_t > 0.0 and float(rec["age"]) > exp_t + 20.0:
			rec["state"] = "suspected_miss"
			engagement.emit("suspected", "T%d: the expected intercept time has passed with no detonation. Suspected miss." % int(rec["n"]))
		if torp == null or torp.done:
			if String(rec["state"]) in ["running", "suspected_miss"]:
				if (rec["events"] as Array).has("run_complete"):
					rec["state"] = "miss_confirmed"
					engagement.emit("miss", "T%d ran out its fuel without detonating (telemetry). Confirmed miss." % int(rec["n"]))
				else:
					rec["state"] = "unknown"
					engagement.emit("unknown", "T%d: run over; no telemetry and nothing heard. Result unknown." % int(rec["n"]))
				_assess(rec)


## What the attack party can say about why it missed: only what telemetry or
## their own observation supports is called confirmed or observed.
func _assess(rec: Dictionary) -> void:
	var lines: Array[String] = []
	var ev: Array = rec["events"]
	if not bool(rec["in_reach"]):
		lines.append("she was beyond the weapon's reach when we fired (confirmed by the fire-control plot)")
	if ev.has("run_complete") and ev.has("seeker_on") and not ev.has("acquired"):
		lines.append("the seeker never acquired a target (confirmed by telemetry)")
	if ev.has("acquired") and ev.has("lost"):
		lines.append("the seeker acquired and then lost its target (confirmed by telemetry)")
	if fc.target == rec["target"] and fc.target != null and fc.obs_time > 20.0:
		var dc := absf(wrapf(fc.est_course - float(rec["est_course"]), -180.0, 180.0))
		var ds := fc.est_speed - float(rec["est_speed"])
		if dc > 20.0:
			lines.append("she has altered course by about %d° since we fired (observed at the periscope)" % int(round(dc / 5.0) * 5.0))
		if absf(ds) > 2.5:
			lines.append("our speed estimate was about %d kt %s (assessment from later observation)" % [int(round(absf(ds))), "low" if ds > 0.0 else "high"])
	if lines.is_empty():
		lines.append("no cause established; the solution was %s, she may have manoeuvred unseen, or the weapon may have misbehaved (possible causes only)" % String(rec["quality"]).to_lower())
	var text := "Post-attack assessment, T%d: %s." % [int(rec["n"]), "; ".join(lines)]
	if dev_diag:
		var tgt: SurfaceShip = rec["target"] if is_instance_valid(rec["target"]) else null
		var turned := absf(rad_to_deg(wrapf(tgt.heading - float(rec["true_heading"]), -PI, PI))) if tgt else 0.0
		text += "  [DEV] closest approach %d m; seeker %s; target turned %d° during the run; telemetry %s." % [
			int(float(rec.get("closest", -1.0))), "acquired" if ev.has("acquired") else "never acquired", int(turned), ", ".join(ev)]
	engagement.emit("assessment", text)


func _on_struck(ship: SurfaceShip, point: Vector3, torp: Torpedo) -> void:
	hits += 1
	_keep_closest(torp)
	for rec in engagements:
		if rec["torp"] == torp:
			rec["state"] = "hit"
			engagement.emit("impact", "T%d: detonation at %d:%02d into the run. Impact detected." % [int(rec["n"]), int(float(rec["age"])) / 60, int(float(rec["age"])) % 60])
	var boom := Explosion.new()
	world.add_child(boom)
	boom.global_position = Vector3(point.x, 0.0, point.z)
	wake_map.add_foam_burst(point, 150.0, 0.8, 45.0)
	var dist := _listener_distance(point)
	var through_water := _listener_underwater()
	var delay := dist / (1500.0 if through_water else 343.0)
	audio.play_delayed("torpedo_impact", delay, lerpf(0.0, -10.0, clampf(dist / 5000.0, 0.0, 1.0)), 1.0, true)
	rig.shake(clampf(1.2 - dist / 2000.0, 0.15, 1.0))
	ship.strike(point)
	_retire(torp)
	message.emit("HIT  ·  %s STRUCK AFTER %d S RUN" % [ship.contact_name.split("  ")[0], int(torp.travelled / Torpedo.RUN_SPEED)])
	target_hit.emit(ship)


func _on_ran_out(torp: Torpedo) -> void:
	_keep_closest(torp)
	if torp.wire_ok:
		message.emit("TORPEDO RUN COMPLETE  ·  NO DETONATION")
	_retire(torp)


func _keep_closest(torp: Torpedo) -> void:
	for rec in engagements:
		if rec["torp"] == torp:
			rec["closest"] = torp.closest


func _retire(torp: Torpedo) -> void:
	torpedoes.erase(torp)
	_trails.erase(torp)
	torp.queue_free()


func _on_sinking_started(ship: SurfaceShip) -> void:
	var dist := _listener_distance(ship.global_position)
	audio.play_delayed("ship_sinking", 2.5, lerpf(-2.0, -12.0, clampf(dist / 5000.0, 0.0, 1.0)), 1.0, true)


func _on_secondary(ship: SurfaceShip, pos: Vector3) -> void:
	var boom := Explosion.new()
	boom.scale_factor = 0.35
	world.add_child(boom)
	boom.global_position = pos
	var dist := _listener_distance(pos)
	audio.play_delayed("torpedo_impact", dist / 343.0, lerpf(-6.0, -16.0, clampf(dist / 5000.0, 0.0, 1.0)), 1.35, true)
	message.emit("SECONDARY EXPLOSION  ·  %s IS LISTING" % ship.contact_name.split("  ")[0])


func _on_went_under(ship: SurfaceShip) -> void:
	wake_map.add_foam_burst(ship.global_position, ship.length * 1.3, 0.7, 50.0)
	message.emit("SHE'S GOING UNDER")


func _on_sunk(ship: SurfaceShip) -> void:
	message.emit("%s HAS SUNK" % (ship.vessel_name if ship.vessel_name != "" else "THE CONTACT"))


func _listener_distance(p: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position if cam and cam.global_position.y > -1000.0 else sub.global_position
	return from.distance_to(p)


func _listener_underwater() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.y < -1000.0:
		return true
	return ocean.height_at(cam.global_position.x, cam.global_position.z) > cam.global_position.y


func _launch_bubbles(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 500
	p.lifetime = 5.0
	p.one_shot = true
	p.explosiveness = 0.7
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.1
	pm.scale_max = 0.5
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	var qm := ShaderMaterial.new()
	qm.shader = load("res://src/fx/soft_particle.gdshader")
	qm.set_shader_parameter("tint", Color(0.85, 0.95, 1.0, 0.6))
	q.material = qm
	p.draw_pass_1 = q
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(6.0).timeout.connect(p.queue_free)


func save_state() -> Dictionary:
	return {"fired": fired, "hits": hits, "reload": reload, "tube": tube, "solution": solution, "last_contact": last_contact}


func load_state(d: Dictionary) -> void:
	fired = int(d.get("fired", 0))
	hits = int(d.get("hits", 0))
	reload = float(d.get("reload", 0.0))
	tube = int(d.get("tube", 0))
	solution = float(d.get("solution", 0.0))
	last_contact = String(d.get("last_contact", ""))
