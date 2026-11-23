class_name SurfaceShip
extends Node3D
## Surface traffic built from simple procedural shapes, riding the swell on
## straight courses. A torpedo hit starts a scripted (non-physical) sinking:
## settle and list, secondary blast, bow- or stern-first plunge, gone.

signal sinking_started(ship: SurfaceShip)
signal secondary_blast(ship: SurfaceShip, world_pos: Vector3)
signal went_under(ship: SurfaceShip)
signal sunk(ship: SurfaceShip)

enum Kind { MERCHANT, FRIGATE, TRAWLER, RESEARCH, PATROL, SUBMARINE }

signal pinged(ship: SurfaceShip)
signal suspicion_changed(ship: SurfaceShip, level: float)
enum State { SAILING, STRICKEN, SUNK }

var kind := Kind.MERCHANT
var ocean: Ocean
var heading := 0.0
var speed := 6.0
var length := 180.0
var beam := 28.0
var draft := 8.0
var contact_name := "MERCHANT"
## Independent behaviour: "route", "fishing", "station", "patrol", "investigate", "drift".
var behavior := "route"
var route: Array[Vector3] = []
var route_index := 0
var route_loop := true
var cruise_knots := 12.0
var vessel_name := ""
## Stable identity across saves (story role or world-traffic id).
var uid := ""
var ais_on := true
var source_level := 172.0
var submerged := false
var run_depth := 0.0
var drift_velocity := Vector3.ZERO
var _foundering := false
var fishing_center := Vector3.ZERO
var fishing_radius := 2000.0
var suspicion := 0.0
## Physical damage state (simulation truth; the crew only ever sees assessments).
var damage := {"hull": 0.0, "propulsion": 0.0, "steering": 0.0, "flooding": 0.0, "fire": 0.0, "list": 0.0, "sensors": 0.0, "weapons": 0.0}
## Where the last hit landed (truth; the boat only learns it from evidence).
var last_hit := {}
## Sinking speed (1 = the full sequence in about a minute; 0 = not sinking).
var sink_rate := 1.0
## The commander's record (intelligence database) and attitudes towards the
## boat, built from memories: {"wary", "grudge", "aggr", "patience"}. Empty
## or zero attitudes change nothing.
var commander: Dictionary = {}
## Intelligence unit id and regional traffic id (empty for staged ships).
var unit_id := ""
## Far away: no wave motion or meshes, only the voyage (distant traffic).
var far := false
## Class within the kind: "corvette" / "opv" (patrol), "bulk" (merchant).
var variant := ""
var datum := Vector3.ZERO
var _behavior_t := 0.0
var _ping_t := 300.0
var _brain_rng := RandomNumberGenerator.new()
var state := State.SAILING
var recycle := true
var top_height := 40.0
var bow_length := 34.0

var _sink_t := 0.0
var _sink_depth := 0.0
var _list := 0.0
var _trim := 0.0
var _list_side := 1.0
var _trim_sign := 1.0
var _hits := 0
var _secondary_done := false
var _under_done := false
var _fires: Array[Node3D] = []
var _churn: GPUParticles3D

var _pitch := 0.0
var _roll := 0.0
var _heave := 0.0
var _body: Node3D
var _lights: Array[Node3D] = []
var _windows_mat: StandardMaterial3D
var _hull_mat: ShaderMaterial
var _super_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242 if kind == Kind.MERCHANT else 9191
	_body = Node3D.new()
	add_child(_body)
	_brain_rng.seed = hash(name) + 17
	if kind == Kind.TRAWLER:
		length = 58.0
		beam = 13.0
		draft = 6.0
		contact_name = "FISHING VESSEL"
		source_level = 166.0
		_build_trawler()
		_churn = _make_churn()
		return
	if kind == Kind.RESEARCH:
		length = 96.0
		beam = 20.0
		draft = 7.5
		contact_name = "RESEARCH VESSEL"
		source_level = 168.0
		_build_research()
		_churn = _make_churn()
		return
	if kind == Kind.PATROL:
		length = 94.0
		beam = 12.3
		draft = 3.8
		contact_name = "WARSHIP  ·  PATROL"
		source_level = 160.0
		top_height = 27.0
		bow_length = 28.0
		if variant == "opv":
			length = 92.0
			beam = 16.0
			draft = 6.0
			contact_name = "PATROL VESSEL  ·  COAST GUARD"
			source_level = 164.0
			top_height = 24.0
			_build_opv()
		else:
			_build_corvette()
		_churn = _make_churn()
		return
	if kind == Kind.SUBMARINE:
		length = 80.0
		beam = 8.0
		draft = 0.0
		contact_name = "SUBMERGED CONTACT"
		source_level = 141.0
		submerged = true
		ais_on = false
		run_depth = 75.0
		var mat := ShaderMaterial.new()
		mat.shader = load("res://src/submarine/hull.gdshader")
		mat.set_shader_parameter("base_color", Color(0.03, 0.035, 0.035))
		var mi := MeshInstance3D.new()
		mi.mesh = SubmarineBuilder.build_hull_mesh(mat)
		mi.scale = Vector3(1.05, 1.05, 1.05)
		_body.add_child(mi)
		_churn = _make_churn()
		return
	if kind == Kind.MERCHANT and variant == "bulk":
		length = 180.0
		beam = 30.0
		draft = 10.0
		contact_name = "MERCHANT  ·  BULK"
		top_height = 9.0 + 26.0
		bow_length = 30.0
		source_level = 177.0
		_build_bulk()
		_churn = _make_churn()
		return
	if kind == Kind.MERCHANT:
		length = 182.0
		beam = 30.0
		draft = 9.0
		contact_name = "MERCHANT  ·  CONTAINER"
		top_height = 13.0 + 34.0
		bow_length = 34.0
		source_level = 176.0
		_build_merchant()
	else:
		length = 134.0
		beam = 17.5
		draft = 5.2
		contact_name = "WARSHIP  ·  FRIGATE"
		top_height = 39.0
		bow_length = 40.0
		_build_frigate()
	_churn = _make_churn()


## What an observer could make out of the ship (for damage assessment):
## never the damage figures themselves.
func apparent() -> Dictionary:
	var burning := false
	if state == State.STRICKEN:
		burning = not _fires.is_empty() and _sink_depth < draft + 2.0
	elif _hits > 0:
		burning = float(damage["fire"]) > 0.08
	return {"list": rad_to_deg(_list), "trim": rad_to_deg(_trim) * _trim_sign, "settle": _sink_depth, "fire": burning,
		"under": state == State.SUNK or _sink_depth > draft + top_height * 0.75, "speed": speed,
		"breaking": state == State.STRICKEN and _sink_t > 20.0}


## Distant traffic: no meshes, lights or wave motion; the voyage goes on.
func set_far(on: bool) -> void:
	far = on
	_body.visible = not on
	if _churn:
		_churn.emitting = false if on else _churn.emitting


func place(pos: Vector3, p_heading: float, knots: float) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	heading = p_heading
	speed = knots * 0.5144


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, -cos(heading))


func save_state() -> Dictionary:
	var rt: Array = []
	for p in route:
		rt.append(SaveSystem.v3(p))
	return {
		"uid": uid, "pos": SaveSystem.v3(position), "heading": heading, "speed": speed, "behavior": behavior,
		"route": rt, "route_index": route_index, "route_loop": route_loop, "cruise_knots": cruise_knots,
		"suspicion": suspicion, "datum": SaveSystem.v3(datum), "behavior_t": _behavior_t, "ping_t": _ping_t,
		"state": int(state), "visible": visible, "submerged": submerged, "run_depth": run_depth,
		"drift": SaveSystem.v3(drift_velocity), "fishing_center": SaveSystem.v3(fishing_center), "fishing_radius": fishing_radius,
		"ais_on": ais_on, "recycle": recycle, "sink_t": _sink_t, "sink_depth": _sink_depth, "list": _list, "trim": _trim,
		"list_side": _list_side, "trim_sign": _trim_sign, "hits": _hits, "damage": damage.duplicate(true),
		"last_hit": last_hit.duplicate(), "sink_rate": sink_rate, "unit_id": unit_id,
	}


func load_state(d: Dictionary) -> void:
	position = SaveSystem.to_v3(d.get("pos"), position)
	heading = float(d.get("heading", heading))
	speed = float(d.get("speed", speed))
	behavior = String(d.get("behavior", behavior))
	route.clear()
	for p in d.get("route", []):
		route.append(SaveSystem.to_v3(p))
	route_index = int(d.get("route_index", 0))
	route_loop = bool(d.get("route_loop", route_loop))
	cruise_knots = float(d.get("cruise_knots", cruise_knots))
	suspicion = float(d.get("suspicion", 0.0))
	datum = SaveSystem.to_v3(d.get("datum"), datum)
	_behavior_t = float(d.get("behavior_t", 0.0))
	_ping_t = float(d.get("ping_t", _ping_t))
	state = int(d.get("state", 0)) as State
	visible = bool(d.get("visible", visible))
	submerged = bool(d.get("submerged", submerged))
	run_depth = float(d.get("run_depth", run_depth))
	drift_velocity = SaveSystem.to_v3(d.get("drift"), drift_velocity)
	fishing_center = SaveSystem.to_v3(d.get("fishing_center"), fishing_center)
	fishing_radius = float(d.get("fishing_radius", fishing_radius))
	ais_on = bool(d.get("ais_on", ais_on))
	recycle = bool(d.get("recycle", recycle))
	_sink_t = float(d.get("sink_t", 0.0))
	_sink_depth = float(d.get("sink_depth", 0.0))
	_list = float(d.get("list", 0.0))
	_trim = float(d.get("trim", 0.0))
	_list_side = float(d.get("list_side", 1.0))
	_trim_sign = float(d.get("trim_sign", 1.0))
	_hits = int(d.get("hits", 0))
	var dm: Variant = d.get("damage")
	if dm is Dictionary:
		for k in (dm as Dictionary):
			damage[k] = float(dm[k])
	var lh: Variant = d.get("last_hit")
	if lh is Dictionary:
		last_hit = lh
	sink_rate = float(d.get("sink_rate", 1.0))
	unit_id = String(d.get("unit_id", unit_id))
	if state == State.SUNK:
		visible = false
	elif state == State.STRICKEN:
		for light in _lights:
			light.visible = false


func is_afloat() -> bool:
	return state != State.SUNK and _sink_depth < draft + 6.0


func is_sinking() -> bool:
	return state == State.STRICKEN


## True if a world point lies inside the underwater part of the hull.
func contains_point(world_pos: Vector3) -> bool:
	var l := to_local(world_pos)
	if absf(l.z) > length * 0.5:
		return false
	var s := l.z + length * 0.5
	var wf := 1.0
	if s < bow_length:
		wf = pow(sin(PI * 0.5 * s / bow_length), 0.75)
	if absf(l.x) > beam * 0.5 * wf + 0.8:
		return false
	return l.y > -draft - 1.0 and l.y < 4.0


## A torpedo has struck at world_pos. What it does depends on where it hit,
## how deep, and how big the ship is: a hit under the keel or amidships can
## break a small ship's back; a bow hit on a large one may leave her afloat.
func strike(world_pos: Vector3) -> void:
	var l := to_local(world_pos)
	_hits += 1
	_add_fire(Vector3(clampf(l.x, -beam * 0.45, beam * 0.45), 1.5, l.z))
	_apply_hit(l)
	_scorch(l)
	var rate := sink_rate_from_damage()
	if state == State.STRICKEN:
		sink_rate = maxf(sink_rate, rate)
		_sink_t += 6.0
		return
	_list_side = 1.0 if l.x >= 0.0 else -1.0
	_trim_sign = 1.0 if l.z < 0.0 else -1.0
	recycle = false
	if rate <= 0.0:
		# Hurt but afloat: listing, perhaps without way or steering.
		_list = deg_to_rad(float(damage["list"]))
		_trim = deg_to_rad(float(damage["flooding"]) * 3.0)
		return
	_begin_sinking(rate)


## A blackened, torn patch on the hull where the warhead went off.
func _scorch(l: Vector3) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.02, 0.95))
	g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var dcl := Decal.new()
	dcl.texture_albedo = tex
	dcl.size = Vector3(beam * 0.9, 12.0, 14.0)
	dcl.position = Vector3(signf(l.x) * beam * 0.45 if absf(l.x) > 0.1 else beam * 0.45, 0.5, l.z)
	dcl.rotation.z = -signf(l.x) * PI * 0.5 if absf(l.x) > 0.1 else -PI * 0.5
	_body.add_child(dcl)


## Damage from a hit at local position l (accumulates over hits).
func _apply_hit(l: Vector3) -> void:
	var sfrac := clampf((l.z + length * 0.5) / length, 0.0, 1.0)     # 0 bow .. 1 stern
	var k := clampf(150.0 / length, 0.45, 2.6)
	var under := l.y < -draft * 0.85
	var section := "midships"
	var add := {}
	if sfrac < 0.15:
		section = "bow"
		add = {"flooding": 0.3, "hull": 0.25, "sensors": 0.6}
	elif sfrac < 0.38:
		section = "forward"
		add = {"flooding": 0.45, "hull": 0.4, "weapons": 0.5, "fire": 0.5}
	elif sfrac < 0.62:
		add = {"flooding": 0.6, "hull": 0.65, "propulsion": 0.4, "fire": 0.6}
	elif sfrac < 0.85:
		section = "aft"
		add = {"flooding": 0.45, "hull": 0.4, "propulsion": 0.9, "fire": 0.5}
	else:
		section = "stern"
		add = {"flooding": 0.3, "hull": 0.25, "propulsion": 0.6, "steering": 1.0}
	var mult := k * (1.6 if under else 1.0) * _rng.randf_range(0.85, 1.15)
	for key in add:
		var m := mult if key in ["flooding", "hull"] else minf(mult, 1.3)
		damage[key] = clampf(float(damage[key]) + float(add[key]) * m, 0.0, 1.0)
	damage["list"] = clampf(float(damage["flooding"]) * 14.0 * (0.6 if under else 1.0), 0.0, 25.0)   # degrees
	last_hit = {"section": section, "under_keel": under, "side": "starboard" if l.x >= 0.0 else "port"}


## 0 if she stays afloat (for now), else how fast she goes.
func sink_rate_from_damage() -> float:
	var w := float(damage["flooding"]) * (1.0 + float(damage["hull"]))
	if w < 0.75:
		return 0.0
	return clampf((w - 0.6) * 1.2, 0.03, 1.0)


func _begin_sinking(rate: float) -> void:
	sink_rate = rate
	state = State.STRICKEN
	_sink_t = 0.0
	recycle = false
	for light in _lights:
		light.visible = false
	if _windows_mat:
		_windows_mat.emission_energy_multiplier = 0.0
	sinking_started.emit(self)


## Put the ship back afloat at a new position (replay).
func reset_to(pos: Vector3, p_heading: float, knots: float) -> void:
	state = State.SAILING
	_sink_t = 0.0
	_sink_depth = 0.0
	_list = 0.0
	_trim = 0.0
	_hits = 0
	_secondary_done = false
	_under_done = false
	for f in _fires:
		f.queue_free()
	_fires.clear()
	_churn.emitting = false
	visible = true
	place(pos, p_heading, knots)
	var was := _night
	_night = not was
	set_night(was)


func advance(dt: float, around: Vector3) -> void:
	if state == State.SUNK:
		return
	if state == State.STRICKEN:
		speed = move_toward(speed, 0.0, dt * 0.15)
		_advance_sinking(dt)
	else:
		_think(dt)
		if _hits > 0:
			_advance_damage(dt)
	position += forward() * speed * dt
	if far:
		position += drift_velocity * dt
		position.y = -run_depth
		return
	# Keep the staged traffic in view: recycle ships that sail far away.
	var rel := position - around
	rel.y = 0.0
	if recycle and rel.length() > 9000.0:
		var back := -rel.normalized()
		position = around + back * 5000.0 + Vector3(-back.z, 0.0, back.x) * _rng.randf_range(-2500.0, 2500.0)
		position.y = 0.0
		heading = atan2(back.x, -back.z) + _rng.randf_range(-0.6, 0.6)
	if ocean:
		var f := forward()
		var r := Vector3(-f.z, 0.0, f.x)
		var hb := ocean.height_at(position.x + f.x * length * 0.4, position.z + f.z * length * 0.4)
		var hs := ocean.height_at(position.x - f.x * length * 0.4, position.z - f.z * length * 0.4)
		var hp := ocean.height_at(position.x - r.x * beam * 0.45, position.z - r.z * beam * 0.45)
		var hst := ocean.height_at(position.x + r.x * beam * 0.45, position.z + r.z * beam * 0.45)
		var k := 1.0 - exp(-dt * 1.5)
		var float_w := 1.0 - smoothstep(0.0, 12.0, _sink_t) if state == State.STRICKEN else 1.0
		_heave = lerpf(_heave, (hb + hs + hp + hst) * 0.25 * float_w, k)
		_pitch = lerpf(_pitch, atan2(hb - hs, length * 0.8) * 0.8 * float_w, k)
		_roll = lerpf(_roll, atan2(hp - hst, beam) * 0.8 * float_w, k * 0.7)
	if submerged:
		_heave = 0.0
		_pitch = 0.0
		_roll = 0.0
	position += drift_velocity * dt
	position.y = _heave - _sink_depth - run_depth
	basis = Basis(Vector3.UP, -heading) * Basis(Vector3.RIGHT, _pitch - _trim * _trim_sign) * Basis(Vector3.FORWARD, _roll + _list * _list_side)


## Afloat after a hit: the crew fight the flooding; it is won or it isn't.
func _advance_damage(dt: float) -> void:
	var f := float(damage["flooding"])
	if f > 0.42:
		damage["flooding"] = minf(f + dt * 0.000012 * f, 1.0)
	else:
		damage["flooding"] = maxf(f - dt * 0.000006, 0.0)
	damage["fire"] = maxf(float(damage["fire"]) - dt * 0.00012, 0.0)
	damage["list"] = clampf(float(damage["flooding"]) * 14.0, 0.0, 25.0)
	_list = move_toward(_list, deg_to_rad(float(damage["list"])), dt * 0.0005)
	var rate := sink_rate_from_damage()
	if rate > 0.0:
		_begin_sinking(rate)


func _advance_sinking(dt: float) -> void:
	_sink_t += dt * sink_rate
	var t := _sink_t
	var total := draft + top_height + 25.0
	# Settle and list, then an accelerating plunge.
	var settle := 2.2 * smoothstep(0.0, 10.0, t)
	var plunge := pow(clampf((t - 9.0) / 38.0, 0.0, 1.0), 1.9) * total
	var deep := maxf(t - 47.0, 0.0) * 6.0
	_sink_depth = settle + plunge + deep
	_list = deg_to_rad(lerpf(0.0, 8.0, smoothstep(0.0, 8.0, t)) + lerpf(0.0, 20.0, smoothstep(10.0, 40.0, t)))
	_trim = deg_to_rad(lerpf(0.0, 1.5, smoothstep(0.0, 8.0, t)) + lerpf(0.0, 14.0, smoothstep(12.0, 42.0, t)))
	if not _secondary_done and t > 7.0:
		_secondary_done = true
		secondary_blast.emit(self, to_global(Vector3(-_list_side * beam * 0.2, 12.0, length * 0.15 * _trim_sign)))
	# Fires drown as they reach the water.
	for f in _fires:
		var under := f.global_position.y < 0.3
		var flames: GPUParticles3D = f.get_node("Flames")
		var smoke: GPUParticles3D = f.get_node("Smoke")
		var glow: OmniLight3D = f.get_node("Glow")
		flames.emitting = not under
		glow.visible = not under
		glow.light_energy = randf_range(5.0, 9.0)
		smoke.emitting = f.global_position.y > -3.0
	# White water boils around the hull while it goes down.
	_churn.global_position = Vector3(global_position.x, 0.4, global_position.z)
	_churn.emitting = t > 6.0 and _sink_depth < total
	if not _under_done and _sink_depth > draft + top_height * 0.75:
		_under_done = true
		went_under.emit(self)
	if t > 62.0:
		state = State.SUNK
		visible = false
		_churn.emitting = false
		sunk.emit(self)


## Lose the ship without an explosion (e.g. driven onto rocks): she settles
## and goes down slowly.
func founder() -> void:
	if state != State.SAILING:
		return
	_foundering = true
	state = State.STRICKEN
	_sink_t = 0.0
	_list_side = 1.0
	_trim_sign = -1.0
	recycle = false
	_secondary_done = true
	speed = 0.0
	for light in _lights:
		light.visible = false
	sinking_started.emit(self)


func _add_fire(local_pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = local_pos
	_body.add_child(holder)
	_fires.append(holder)
	var flames := _particles("Flames", 260, 1.4, Vector3(3.0, 0.8, 5.0), 3.0, 9.0, 1.2, 4.5, Color(1.0, 0.55, 0.18, 0.85), true)
	holder.add_child(flames)
	var smoke := _particles("Smoke", 260, 12.0, Vector3(3.0, 1.0, 5.0), 2.5, 6.0, 5.0, 22.0, Color(0.07, 0.065, 0.06, 0.55), false)
	(smoke.process_material as ParticleProcessMaterial).gravity = Vector3(2.0, 1.6, 0.6)
	holder.add_child(smoke)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 7.0
	glow.omni_range = 45.0
	glow.position = Vector3(0, 3.0, 0)
	holder.add_child(glow)


func _particles(n: String, amount: int, life: float, box: Vector3, vmin: float, vmax: float, smin: float, smax: float, color: Color, additive: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-200, -60, -200), Vector3(400, 260, 400))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, 2.0, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, smin / smax))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ac := Curve.new()
	ac.add_point(Vector2(0.0, 0.0))
	ac.add_point(Vector2(0.1, 1.0))
	ac.add_point(Vector2(1.0, 0.0))
	var act := CurveTexture.new()
	act.curve = ac
	pm.alpha_curve = act
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(smax, smax)
	var qm := ShaderMaterial.new()
	qm.shader = load("res://src/fx/fire_particle.gdshader" if additive else "res://src/fx/soft_particle.gdshader")
	qm.set_shader_parameter("tint", color)
	q.material = qm
	p.draw_pass_1 = q
	return p


func _make_churn() -> GPUParticles3D:
	var p := _particles("Churn", 700, 3.0, Vector3(beam * 0.6, 0.5, length * 0.45), 1.0, 5.0, 2.0, 7.0, Color(0.9, 0.94, 0.96, 0.5), false)
	(p.process_material as ParticleProcessMaterial).gravity = Vector3(0, -6.0, 0)
	(p.process_material as ParticleProcessMaterial).spread = 50.0
	p.emitting = false
	p.top_level = true
	add_child(p)
	return p


var _night := false


func set_night(on: bool) -> void:
	if on == _night:
		return
	_night = on
	if state != State.SAILING:
		return
	for l in _lights:
		l.visible = on
	if _windows_mat:
		_windows_mat.emission_energy_multiplier = 3.5 if on else 0.15


# --- construction -----------------------------------------------------------

func _ship_shader(color: Color, rough: float, heat: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/ships/ship.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("thermal_heat", heat)
	return m


func _hull_fn(l: float, b: float, depth: float, freeboard: float, bow_len: float, stern_len: float, flare: float, sheer: float) -> Callable:
	return func(u: float, v: float) -> Vector3:
		var s := u * l
		var half := b * 0.5
		var wf := 1.0
		if s < bow_len:
			wf = pow(sin(PI * 0.5 * s / bow_len), 0.75)
		elif s > l - stern_len:
			var x := (s - (l - stern_len)) / stern_len
			wf = 1.0 - 0.28 * x * x
		var a := v * TAU
		var cy := -cos(a)
		var sx := sin(a)
		var top := freeboard + sheer * pow(1.0 - minf(s / (l * 0.35), 1.0), 2.0)
		var y: float
		if cy > 0.0:
			y = lerpf(0.0, top, pow(cy, 0.35))
		else:
			y = -depth * pow(-cy, 0.45)
		var xs := signf(sx) * pow(absf(sx), 0.25)
		var hw := half * wf * (1.0 + flare * clampf(y / maxf(top, 0.1), 0.0, 1.0))
		if y < 0.0:
			hw *= lerpf(1.0, 0.85, pow(-y / depth, 3.0))
		# Cut the bow below the waterline into a raked stem.
		var z := -l * 0.5 + s
		if s < bow_len and y < 0.0:
			z += (-y / depth) * bow_len * 0.25 * (1.0 - s / bow_len)
		return Vector3(xs * hw, y, z)


func _add_hull(fn: Callable, mat: Material) -> void:
	var mesh := ArrayMesh.new()
	var uvf := func(u: float, v: float) -> Vector2: return Vector2(u * 30.0, v * 10.0)
	ParamMesh.add_to(mesh, ParamMesh.surface(fn, uvf, 120, 48), mat)
	# Close the transom so the stern reads as solid when it lifts out of the water.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	var centre := Vector3.ZERO
	for i in 48:
		var p: Vector3 = fn.call(1.0, float(i) / 48.0)
		ring.append(p)
		centre += p
	centre /= 48.0
	for i in 48:
		var a := ring[i]
		var b := ring[(i + 1) % 48]
		for tri in [[centre, a, b], [centre, b, a]]:
			for v in tri:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(Vector2(v.x, v.y))
				st.add_vertex(v)
	st.set_material(mat)
	st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_body.add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	_lod(mi, size.length())
	_body.add_child(mi)
	return mi


## Small parts fade out with distance (they would not be made out anyway).
static func _lod(gi: GeometryInstance3D, extent: float) -> void:
	if extent < 3.5:
		gi.visibility_range_end = 2500.0 + extent * 600.0
		gi.visibility_range_end_margin = 300.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _prism(bottom: Vector2, top: Vector2, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	# Tapered block: a "stealth" superstructure with inward-sloping walls.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := [Vector3(-bottom.x, 0, -bottom.y), Vector3(bottom.x, 0, -bottom.y), Vector3(bottom.x, 0, bottom.y), Vector3(-bottom.x, 0, bottom.y)]
	var t := [Vector3(-top.x, height, -top.y), Vector3(top.x, height, -top.y), Vector3(top.x, height, top.y), Vector3(-top.x, height, top.y)]
	for i in 4:
		var j := (i + 1) % 4
		_tri(st, b[i], t[i], b[j])
		_tri(st, b[j], t[i], t[j])
	_tri(st, t[0], t[2], t[1])
	_tri(st, t[0], t[3], t[2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	_body.add_child(mi)
	return mi


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)


func _cyl(r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	_lod(mi, r * 4.0)
	_body.add_child(mi)
	return mi


func _nav_light(pos: Vector3, color: Color, energy: float = 6.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	_body.add_child(holder)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 30.0
	sm.material = mat
	bulb.mesh = sm
	holder.add_child(bulb)
	var omni := OmniLight3D.new()
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = 26.0
	omni.light_volumetric_fog_energy = 0.0
	holder.add_child(omni)
	holder.visible = false
	_lights.append(holder)


func _build_merchant() -> void:
	_hull_mat = _ship_shader(Color(0.06, 0.09, 0.14), 0.6, 0.25)
	_hull_mat.set_shader_parameter("boot_color", Color(0.32, 0.06, 0.05))
	_hull_mat.set_shader_parameter("boot_top", 0.6)
	_add_hull(_hull_fn(length, beam, draft, 13.0, 34.0, 18.0, 0.04, 4.0), _hull_mat)
	var white := _ship_shader(Color(0.78, 0.78, 0.76), 0.55, 0.3)
	var grey := _ship_shader(Color(0.32, 0.33, 0.34), 0.5, 0.3)
	# Accommodation block aft with bridge wings.
	var z_house := length * 0.5 - 28.0
	_box(Vector3(24.0, 22.0, 13.0), Vector3(0, 13.0 + 11.0, z_house), white)
	_box(Vector3(beam + 2.0, 1.2, 6.0), Vector3(0, 13.0 + 21.0, z_house - 3.0), white)
	_windows_mat = StandardMaterial3D.new()
	_windows_mat.albedo_color = Color(0.05, 0.06, 0.07)
	_windows_mat.emission_enabled = true
	_windows_mat.emission = Color(1.0, 0.82, 0.55)
	_windows_mat.emission_energy_multiplier = 0.15
	_windows_mat.roughness = 0.1
	for row in 5:
		_box(Vector3(24.3, 0.9, 12.0), Vector3(0, 16.5 + row * 3.6, z_house), _windows_mat)
	_box(Vector3(beam + 2.1, 1.3, 1.0), Vector3(0, 13.0 + 20.0, z_house - 6.2), _windows_mat)
	# Funnel.
	var funnel := _box(Vector3(6.0, 12.0, 8.0), Vector3(0, 13.0 + 26.0, z_house + 9.0), grey)
	funnel.set_meta("hot", true)
	_box(Vector3(6.1, 2.2, 8.1), Vector3(0, 13.0 + 30.0, z_house + 9.0), _ship_shader(Color(0.7, 0.12, 0.08), 0.5, 0.95))
	# Mast with radar.
	_cyl(0.35, 10.0, Vector3(0, 13.0 + 27.0, z_house - 2.0), grey)
	_box(Vector3(4.0, 0.4, 0.5), Vector3(0, 13.0 + 31.5, z_house - 2.0), grey)
	# Container stacks: one MultiMesh, per-instance colours.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(2.44, 2.55, 12.0)
	var cmat := ShaderMaterial.new()
	cmat.shader = load("res://src/ships/container.gdshader")
	box.material = cmat
	mm.mesh = box
	var palette := [Color(0.55, 0.12, 0.08), Color(0.12, 0.25, 0.45), Color(0.2, 0.36, 0.22), Color(0.62, 0.62, 0.6), Color(0.75, 0.42, 0.1), Color(0.42, 0.18, 0.12), Color(0.08, 0.32, 0.38), Color(0.6, 0.55, 0.18), Color(0.3, 0.3, 0.32)]
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	var bays := 11
	for bay in bays:
		var z := -length * 0.5 + 34.0 + bay * 12.8
		if z > z_house - 9.0:
			continue
		var tiers := _rng.randi_range(3, 6)
		for row in 11:
			var x := (row - 5) * 2.5
			var t_here := tiers - (1 if absi(row - 5) == 5 and _rng.randf() < 0.5 else 0)
			for tier in t_here:
				xforms.append(Transform3D(Basis.IDENTITY, Vector3(x, 13.0 + 1.3 + tier * 2.6, z)))
				var c: Color = palette[_rng.randi_range(0, palette.size() - 1)]
				cols.append(c * _rng.randf_range(0.8, 1.1))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_body.add_child(mmi)
	# Forecastle and hatch-coaming details.
	_box(Vector3(beam * 0.7, 2.5, 14.0), Vector3(0, 14.5, -length * 0.5 + 18.0), grey)
	_nav_light(Vector3(0, 13.0 + 33.0, z_house - 2.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(0, 13.0 + 12.0, -length * 0.5 + 14.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-beam * 0.5 - 1.0, 13.0 + 21.0, z_house - 3.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(beam * 0.5 + 1.0, 13.0 + 21.0, z_house - 3.0), Color(0.1, 1.0, 0.35))
	for i in 6:
		_nav_light(Vector3(_rng.randf_range(-10, 10), 13.0 + 16.0, -length * 0.5 + 30.0 + i * 22.0), Color(1.0, 0.75, 0.45), 3.0)


func _build_frigate() -> void:
	var haze := _ship_shader(Color(0.36, 0.38, 0.4), 0.55, 0.3)
	_hull_mat = _ship_shader(Color(0.34, 0.36, 0.38), 0.6, 0.25)
	_hull_mat.set_shader_parameter("boot_color", Color(0.08, 0.08, 0.09))
	_hull_mat.set_shader_parameter("boot_top", 0.4)
	_add_hull(_hull_fn(length, beam, draft, 8.0, 40.0, 10.0, 0.1, 3.5), _hull_mat)
	var dark := _ship_shader(Color(0.12, 0.13, 0.14), 0.5, 0.35)
	# Faceted superstructure.
	_prism(Vector2(7.4, 18.0), Vector2(6.2, 16.0), 6.5, Vector3(0, 8.0, 2.0), haze)
	_prism(Vector2(6.0, 9.0), Vector2(4.6, 7.0), 6.0, Vector3(0, 14.5, -6.0), haze)
	_prism(Vector2(3.6, 3.6), Vector2(1.8, 1.8), 12.0, Vector3(0, 20.5, -6.5), haze)
	_box(Vector3(9.0, 0.9, 1.0), Vector3(0, 19.6, -15.4), dark)
	# Hangar and flight deck aft.
	_prism(Vector2(6.8, 8.0), Vector2(6.2, 7.6), 6.2, Vector3(0, 8.0, 28.0), haze)
	# Funnel.
	var funnel := _prism(Vector2(2.6, 3.4), Vector2(2.0, 2.6), 5.5, Vector3(0, 14.5, 14.0), haze)
	funnel.set_meta("hot", true)
	_box(Vector3(3.2, 0.6, 4.4), Vector3(0, 20.0, 14.0), _ship_shader(Color(0.08, 0.08, 0.08), 0.5, 0.95))
	# Main gun.
	_prism(Vector2(2.2, 2.8), Vector2(1.4, 1.9), 1.8, Vector3(0, 8.4, -length * 0.5 + 34.0), haze)
	var barrel := _cyl(0.17, 7.0, Vector3(0, 9.4, -length * 0.5 + 29.0), dark)
	barrel.rotation.x = deg_to_rad(90.0)
	# Vertical-launch deck.
	_box(Vector3(6.0, 0.4, 8.0), Vector3(0, 8.2, -length * 0.5 + 44.0), dark)
	# Radar panels on the integrated mast.
	_cyl(0.25, 6.0, Vector3(0, 35.0, -6.5), dark)
	_box(Vector3(2.6, 0.35, 1.2), Vector3(0, 37.8, -6.5), dark)
	_nav_light(Vector3(0, 38.5, -6.5), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-6.0, 15.0, -6.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(6.0, 15.0, -6.0), Color(0.1, 1.0, 0.35))
	_nav_light(Vector3(0, 10.0, length * 0.5 - 4.0), Color(1.0, 0.95, 0.85))
	# Hull number (fictional).
	for side in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = "361"
		lbl.font_size = 512
		lbl.pixel_size = 0.009
		lbl.modulate = Color(0.06, 0.06, 0.07)
		lbl.outline_size = 0
		lbl.shaded = true
		lbl.double_sided = false
		lbl.position = Vector3(side * (beam * 0.5 + 0.35), 4.5, -length * 0.5 + 24.0)
		lbl.rotation.y = side * PI * 0.5
		_body.add_child(lbl)


## Corvette (GRIM class): no hangar; ASW rocket launchers forward of the
## bridge, a lattice mast, torpedo tubes and a clear quarterdeck aft.
func _build_corvette() -> void:
	var haze := _ship_shader(Color(0.38, 0.4, 0.41), 0.55, 0.3)
	_hull_mat = _ship_shader(Color(0.35, 0.37, 0.39), 0.6, 0.25)
	_hull_mat.set_shader_parameter("boot_color", Color(0.08, 0.08, 0.09))
	_hull_mat.set_shader_parameter("boot_top", 0.35)
	_add_hull(_hull_fn(length, beam, draft, 6.0, 28.0, 8.0, 0.12, 2.6), _hull_mat)
	var dark := _ship_shader(Color(0.12, 0.13, 0.14), 0.5, 0.35)
	_prism(Vector2(4.6, 12.0), Vector2(4.0, 11.0), 4.6, Vector3(0, 6.0, -3.0), haze)
	_prism(Vector2(3.8, 5.0), Vector2(3.0, 4.0), 3.2, Vector3(0, 10.6, -9.0), haze)
	_box(Vector3(6.2, 0.6, 1.2), Vector3(0, 12.6, -13.2), dark)        # bridge windows
	# Lattice mast: legs and platforms.
	for lx in [-1.0, 1.0]:
		var leg := _cyl(0.16, 12.0, Vector3(lx * 0.9, 19.8, -6.0), dark)
		leg.rotation.z = lx * 0.06
	for k in 4:
		_box(Vector3(2.2 - k * 0.35, 0.12, 0.12), Vector3(0, 15.0 + k * 3.0, -6.0), dark)
	_box(Vector3(3.0, 0.3, 1.0), Vector3(0, 26.0, -6.0), dark)
	_cyl(0.6, 0.6, Vector3(0, 24.2, -6.0), dark)
	var funnel := _prism(Vector2(1.6, 2.4), Vector2(1.2, 1.8), 4.0, Vector3(0, 10.6, 6.0), haze)
	funnel.set_meta("hot", true)
	# Gun and ASW rocket launchers forward.
	_prism(Vector2(1.8, 2.2), Vector2(1.2, 1.6), 1.6, Vector3(0, 6.3, -length * 0.5 + 22.0), haze)
	var barrel := _cyl(0.13, 5.0, Vector3(0, 7.3, -length * 0.5 + 18.5), dark)
	barrel.rotation.x = deg_to_rad(90.0)
	for lx2 in [-1.0, 1.0]:
		var rl := _box(Vector3(1.6, 1.2, 2.4), Vector3(lx2 * 2.3, 6.9, -length * 0.5 + 30.0), dark)
		rl.rotation.x = deg_to_rad(-18.0)
		var tt := _box(Vector3(0.9, 0.9, 4.0), Vector3(lx2 * (beam * 0.5 - 1.6), 6.6, 16.0), dark)
		tt.rotation.y = lx2 * 0.3
	_box(Vector3(3.0, 1.0, 2.0), Vector3(0, 6.5, length * 0.5 - 10.0), dark)
	_nav_light(Vector3(0, 26.6, -6.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-4.2, 11.5, -9.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(4.2, 11.5, -9.0), Color(0.1, 1.0, 0.35))
	_nav_light(Vector3(0, 8.0, length * 0.5 - 3.0), Color(1.0, 0.95, 0.85))
	_hull_number("514", 3.8, -length * 0.5 + 16.0)


## Coast guard offshore patrol vessel: high bridge forward, long working
## deck with a crane aft, high-visibility stripe and markings.
func _build_opv() -> void:
	var white := _ship_shader(Color(0.8, 0.81, 0.82), 0.5, 0.2)
	_hull_mat = _ship_shader(Color(0.74, 0.75, 0.77), 0.55, 0.2)
	_hull_mat.set_shader_parameter("boot_color", Color(0.45, 0.07, 0.06))
	_hull_mat.set_shader_parameter("boot_top", 0.4)
	_add_hull(_hull_fn(length, beam, draft, 7.0, 26.0, 9.0, 0.1, 2.2), _hull_mat)
	var dark := _ship_shader(Color(0.1, 0.11, 0.12), 0.5, 0.3)
	var red := _ship_shader(Color(0.75, 0.08, 0.06), 0.5, 0.2)
	var blue := _ship_shader(Color(0.08, 0.18, 0.5), 0.5, 0.2)
	_prism(Vector2(6.6, 13.0), Vector2(6.2, 12.0), 6.0, Vector3(0, 7.0, -length * 0.5 + 34.0), white)
	_prism(Vector2(6.0, 5.0), Vector2(5.6, 4.4), 3.4, Vector3(0, 13.0, -length * 0.5 + 28.0), white)
	_box(Vector3(11.8, 1.1, 0.3), Vector3(0, 15.2, -length * 0.5 + 23.2), dark)   # wraparound windows
	_cyl(0.3, 9.0, Vector3(0, 20.9, -length * 0.5 + 30.0), dark)
	_box(Vector3(3.4, 0.35, 1.2), Vector3(0, 25.0, -length * 0.5 + 30.0), dark)
	var funnel := _prism(Vector2(1.6, 2.0), Vector2(1.3, 1.6), 3.0, Vector3(0, 13.0, -length * 0.5 + 44.0), white)
	funnel.set_meta("hot", true)
	# Working deck and crane aft.
	_box(Vector3(beam - 3.0, 0.3, 30.0), Vector3(0, 7.15, length * 0.5 - 20.0), dark)
	_cyl(0.8, 4.0, Vector3(beam * 0.25, 9.0, length * 0.5 - 30.0), red)
	var boom := _cyl(0.32, 18.0, Vector3(beam * 0.25, 11.0, length * 0.5 - 30.0), red)
	boom.rotation.x = deg_to_rad(62.0)
	# Stripes and markings.
	for side in [-1.0, 1.0]:
		var st := _box(Vector3(0.12, 5.5, 2.4), Vector3(side * (beam * 0.5 + 0.05), 4.0, -length * 0.5 + 22.0), red)
		st.rotation.x = deg_to_rad(-25.0)
		var st2 := _box(Vector3(0.12, 5.5, 0.9), Vector3(side * (beam * 0.5 + 0.05), 4.0, -length * 0.5 + 24.2), blue)
		st2.rotation.x = deg_to_rad(-25.0)
		var lbl := Label3D.new()
		lbl.text = "COAST GUARD"
		lbl.font_size = 256
		lbl.pixel_size = 0.012
		lbl.modulate = Color(0.08, 0.1, 0.2)
		lbl.shaded = true
		lbl.double_sided = false
		lbl.position = Vector3(side * (beam * 0.5 + 0.3), 5.2, 12.0)
		lbl.rotation.y = side * PI * 0.5
		lbl.visibility_range_end = 3000.0
		_body.add_child(lbl)
	_nav_light(Vector3(0, 25.6, -length * 0.5 + 30.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-6.2, 14.5, -length * 0.5 + 28.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(6.2, 14.5, -length * 0.5 + 28.0), Color(0.1, 1.0, 0.35))
	_nav_light(Vector3(0, 9.0, length * 0.5 - 3.0), Color(1.0, 0.95, 0.85))
	_name_label(Color(0.08, 0.1, 0.2), 5.0, 3.0)


## Bulk carrier: hatches and deck cranes forward, accommodation and funnel aft.
func _build_bulk() -> void:
	_hull_mat = _ship_shader(Color(0.12, 0.13, 0.15), 0.6, 0.2)
	_hull_mat.set_shader_parameter("boot_color", Color(0.42, 0.08, 0.06))
	_hull_mat.set_shader_parameter("boot_top", 0.55)
	_add_hull(_hull_fn(length, beam, draft, 9.0, 30.0, 18.0, 0.06, 1.6), _hull_mat)
	var deck := _ship_shader(Color(0.32, 0.24, 0.18), 0.7, 0.2)
	var white := _ship_shader(Color(0.82, 0.82, 0.8), 0.5, 0.25)
	var crane := _ship_shader(Color(0.75, 0.6, 0.12), 0.5, 0.2)
	var dark := _ship_shader(Color(0.1, 0.1, 0.11), 0.5, 0.3)
	for i in 6:
		var z := -length * 0.5 + 30.0 + float(i) * 20.0
		_box(Vector3(beam - 8.0, 1.6, 14.0), Vector3(0, 9.8, z), deck)
		if i in [0, 2, 4]:
			_cyl(1.0, 6.0, Vector3(0, 12.0, z + 10.0), crane)
			var jib := _cyl(0.35, 22.0, Vector3(0, 14.5, z + 10.0), crane)
			jib.rotation.x = deg_to_rad(68.0)
			jib.rotation.y = deg_to_rad(30.0 * float(i - 2))
	_prism(Vector2(11.0, 7.5), Vector2(10.6, 7.2), 13.0, Vector3(0, 9.0, length * 0.5 - 24.0), white)
	_box(Vector3(beam + 1.0, 0.6, 3.0), Vector3(0, 21.6, length * 0.5 - 30.0), white)       # bridge wings
	_box(Vector3(20.0, 1.0, 0.3), Vector3(0, 20.6, length * 0.5 - 31.6), dark)              # windows
	var funnel := _prism(Vector2(2.6, 3.6), Vector2(2.2, 3.0), 8.0, Vector3(0, 22.0, length * 0.5 - 14.0), _ship_shader(Color(0.2, 0.3, 0.55), 0.5, 0.95))
	funnel.set_meta("hot", true)
	_cyl(0.2, 8.0, Vector3(0, 26.0, length * 0.5 - 26.0), dark)
	_nav_light(Vector3(0, 30.5, length * 0.5 - 26.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(0, 14.0, -length * 0.5 + 6.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-15.5, 21.0, length * 0.5 - 30.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(15.5, 21.0, length * 0.5 - 30.0), Color(0.1, 1.0, 0.35))
	_name_label(Color(0.95, 0.95, 0.95), 6.0, 4.0)


func _hull_number(text: String, y: float, z: float) -> void:
	for side in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = text
		lbl.font_size = 512
		lbl.pixel_size = 0.007
		lbl.modulate = Color(0.06, 0.06, 0.07)
		lbl.shaded = true
		lbl.double_sided = false
		lbl.position = Vector3(side * (beam * 0.5 + 0.3), y, z)
		lbl.rotation.y = side * PI * 0.5
		lbl.visibility_range_end = 4000.0
		_body.add_child(lbl)


# --- independent behaviour -----------------------------------------------------

func set_route(points: Array, loop: bool, knots: float) -> void:
	route.clear()
	for p in points:
		route.append(p)
	route_index = 0
	route_loop = loop
	cruise_knots = knots
	behavior = "route"


func _steer_to(target: Vector3, knots: float, dt: float) -> float:
	var rel := target - position
	rel.y = 0.0
	var want := atan2(rel.x, -rel.z)
	var turn := dt * 0.012 * (1.0 - float(damage["steering"]))
	heading += clampf(wrapf(want - heading, -PI, PI), -turn, turn)
	speed = move_toward(speed, knots * 0.5144 * (1.0 - float(damage["propulsion"])), dt * 0.05)
	return rel.length()


func _think(dt: float) -> void:
	_behavior_t -= dt
	match behavior:
		"route", "patrol":
			if route.is_empty():
				return
			var d := _steer_to(route[route_index], cruise_knots, dt)
			if d < 250.0:
				route_index += 1
				if route_index >= route.size():
					route_index = 0 if route_loop else route.size() - 1
					if not route_loop:
						behavior = "drift"
			if behavior == "patrol":
				_ping_t -= dt
				if _ping_t <= 0.0:
					_ping_t = _brain_rng.randf_range(1200.0, 3000.0) * (0.3 if suspicion > 0.4 else 1.0) * ping_factor()
					pinged.emit(self)
				suspicion = maxf(suspicion - dt / 2400.0, 0.0)
		"fishing":
			if _behavior_t <= 0.0:
				var a := _brain_rng.randf() * TAU
				datum = fishing_center + Vector3(cos(a), 0.0, sin(a)) * _brain_rng.randf_range(0.0, fishing_radius)
				_behavior_t = _brain_rng.randf_range(1800.0, 4200.0)
			# Trawling slowly, sometimes stopped to haul.
			var hauling := fmod(_behavior_t, 2400.0) < 500.0
			if hauling:
				speed = move_toward(speed, 0.0, dt * 0.05)
			else:
				_steer_to(datum, 3.5, dt)
		"station":
			speed = move_toward(speed, 0.0, dt * 0.05)
			if _behavior_t <= 0.0 and not route.is_empty():
				behavior = "route"
		"investigate":
			var d2 := _steer_to(datum, 14.0, dt)
			if d2 < 600.0:
				# Search around the datum, pinging, then give up.
				heading += dt * 0.01
				_ping_t -= dt
				if _ping_t <= 0.0:
					_ping_t = _brain_rng.randf_range(90.0, 200.0)
					pinged.emit(self)
			if _behavior_t <= 0.0:
				behavior = "patrol"
				suspicion = 0.3
		"drift":
			speed = move_toward(speed, 0.0, dt * 0.03)


func _att(k: String) -> float:
	var a: Dictionary = commander.get("attitude", {})
	return float(a.get(k, 0.0))


## How much longer than usual this commander keeps searching (a grudge and a
## patient nature make for a long hunt; wariness for a careful one).
func persistence() -> float:
	return 1.0 + _att("grudge") * (0.5 + _att("patience")) + _att("wary") * 0.3


## Shorter intervals between pings for an aggressive commander with a grudge.
func ping_factor() -> float:
	return 1.0 - 0.45 * _att("grudge") * _att("aggr")


## Called by the world each sensor tick: does this ship notice the submarine?
func sense_submarine(sub: Submarine, visibility: float, darkness: float, dt: float) -> void:
	if state != State.SAILING or kind == Kind.MERCHANT:
		return
	var rel := sub.global_position - global_position
	var dist := Vector2(rel.x, rel.z).length()
	var gain := 0.0
	var mast_up := sub.mast_extension() > 0.5 and sub.depth < 13.0
	var exposed := sub.is_surfaced() or mast_up
	# Lookouts: a periscope or a surfaced boat in daylight at close range.
	var eye := visibility * (1.0 - darkness * 0.75)
	if sub.is_surfaced() and dist < eye * 0.7:
		gain += 0.25
	elif mast_up and dist < minf(eye * 0.2, 2500.0):
		gain += 0.06 * (1.0 + sub.speed)
	# Radar (patrol vessels) against masts and hulls.
	if kind == Kind.PATROL or kind == Kind.FRIGATE:
		if exposed and dist < (9000.0 if sub.is_surfaced() else 4500.0):
			gain += 0.05 if not sub.is_surfaced() else 0.2
		# Passive sonar against a noisy boat.
		var excess := sub.noise_level() - 20.0 * log(maxf(dist, 50.0)) / log(10.0) - dist * 0.0004 - 68.0 - speed * 0.8
		if excess > 0.0:
			gain += excess * 0.01
	# A commander who has met the boat before keeps a sharper lookout.
	gain *= 1.0 + 0.3 * _att("wary")
	suspicion = clampf(suspicion + gain * dt / 10.0, 0.0, 1.2)
	if gain > 0.0:
		suspicion_changed.emit(self, suspicion)


## Active ping result: below the layer and quiet is hard to find.
func ping_detects(sub: Submarine) -> bool:
	var dist := global_position.distance_to(sub.global_position)
	var rng := 5500.0 * (0.45 if sub.depth > Submarine.LAYER_DEPTH else 1.0)
	return dist < rng


func _build_trawler() -> void:
	var hull := _ship_shader(Color(0.42, 0.07, 0.05), 0.6, 0.3)
	hull.set_shader_parameter("boot_color", Color(0.06, 0.06, 0.07))
	hull.set_shader_parameter("boot_top", 0.5)
	_add_hull(_hull_fn(length, beam, draft, 6.5, 14.0, 8.0, 0.08, 3.0), hull)
	var white := _ship_shader(Color(0.82, 0.82, 0.8), 0.55, 0.35)
	var grey := _ship_shader(Color(0.3, 0.31, 0.32), 0.5, 0.3)
	var orange := _ship_shader(Color(0.75, 0.32, 0.06), 0.5, 0.3)
	_box(Vector3(10.0, 7.0, 13.0), Vector3(0, 6.5 + 3.5, -length * 0.5 + 18.0), white)
	_box(Vector3(10.6, 1.2, 4.0), Vector3(0, 6.5 + 7.6, -length * 0.5 + 15.0), white)
	_windows_mat = StandardMaterial3D.new()
	_windows_mat.albedo_color = Color(0.04, 0.05, 0.06)
	_windows_mat.emission_enabled = true
	_windows_mat.emission = Color(1.0, 0.85, 0.6)
	_windows_mat.emission_energy_multiplier = 0.15
	_box(Vector3(10.7, 1.0, 0.4), Vector3(0, 6.5 + 7.4, -length * 0.5 + 12.9), _windows_mat)
	_cyl(0.3, 12.0, Vector3(0, 6.5 + 13.0, -length * 0.5 + 20.0), grey)
	# Stern gantry and trawl gear.
	for sx in [-4.0, 4.0]:
		_cyl(0.4, 9.0, Vector3(sx, 6.5 + 4.5, length * 0.5 - 6.0), orange)
	_box(Vector3(8.8, 0.8, 0.8), Vector3(0, 6.5 + 9.0, length * 0.5 - 6.0), orange)
	_box(Vector3(6.0, 1.5, 4.0), Vector3(0, 6.5 + 0.8, length * 0.5 - 12.0), grey)
	_nav_light(Vector3(0, 6.5 + 19.0, -length * 0.5 + 20.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(0, 6.5 + 17.5, -length * 0.5 + 20.0), Color(0.1, 1.0, 0.35), 3.0)
	_nav_light(Vector3(0, 6.5 + 16.0, -length * 0.5 + 20.0), Color(1.0, 1.0, 1.0), 3.0)
	_nav_light(Vector3(0, 6.5 + 8.0, length * 0.5 - 8.0), Color(1.0, 0.9, 0.7), 5.0)
	_name_label(Color(0.95, 0.95, 0.95), 6.5 * 0.55, 3.2)


func _build_research() -> void:
	var hull := _ship_shader(Color(0.58, 0.1, 0.07), 0.55, 0.3)
	hull.set_shader_parameter("boot_color", Color(0.06, 0.06, 0.07))
	hull.set_shader_parameter("boot_top", 0.5)
	_add_hull(_hull_fn(length, beam, draft, 9.0, 26.0, 10.0, 0.06, 3.5), hull)
	var white := _ship_shader(Color(0.86, 0.86, 0.84), 0.55, 0.35)
	var grey := _ship_shader(Color(0.32, 0.33, 0.34), 0.5, 0.3)
	var yellow := _ship_shader(Color(0.8, 0.62, 0.1), 0.5, 0.3)
	_box(Vector3(17.0, 10.0, 26.0), Vector3(0, 9.0 + 5.0, -length * 0.5 + 34.0), white)
	_box(Vector3(14.0, 4.0, 14.0), Vector3(0, 9.0 + 12.0, -length * 0.5 + 30.0), white)
	_box(Vector3(20.0, 1.0, 5.0), Vector3(0, 9.0 + 13.5, -length * 0.5 + 26.0), white)
	_windows_mat = StandardMaterial3D.new()
	_windows_mat.albedo_color = Color(0.04, 0.05, 0.06)
	_windows_mat.emission_enabled = true
	_windows_mat.emission = Color(1.0, 0.85, 0.6)
	_windows_mat.emission_energy_multiplier = 0.15
	for row in 3:
		_box(Vector3(17.2, 0.8, 24.0), Vector3(0, 9.0 + 2.0 + row * 3.0, -length * 0.5 + 34.0), _windows_mat)
	_box(Vector3(14.2, 1.1, 0.5), Vector3(0, 9.0 + 12.3, -length * 0.5 + 22.9), _windows_mat)
	_cyl(0.35, 10.0, Vector3(0, 9.0 + 19.0, -length * 0.5 + 30.0), grey)
	# Crane and stern A-frame.
	var crane := _cyl(0.5, 16.0, Vector3(5.0, 9.0 + 6.0, 6.0), yellow)
	crane.rotation.z = deg_to_rad(-35.0)
	for sx in [-5.5, 5.5]:
		_cyl(0.5, 11.0, Vector3(sx, 9.0 + 5.5, length * 0.5 - 5.0), yellow)
	_box(Vector3(11.5, 1.0, 1.0), Vector3(0, 9.0 + 11.0, length * 0.5 - 5.0), yellow)
	_nav_light(Vector3(0, 9.0 + 24.5, -length * 0.5 + 30.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-10.5, 9.0 + 13.5, -length * 0.5 + 26.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(10.5, 9.0 + 13.5, -length * 0.5 + 26.0), Color(0.1, 1.0, 0.35))
	_nav_light(Vector3(0, 9.0 + 3.0, length * 0.5 - 14.0), Color(1.0, 0.9, 0.7), 6.0)
	_name_label(Color(0.95, 0.95, 0.95), 4.5, 4.0)


func _name_label(color: Color, y: float, px: float) -> void:
	for side in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.name = "NameLabel"
		lbl.text = vessel_name
		lbl.font_size = 256
		lbl.pixel_size = px * 0.004
		lbl.modulate = color
		lbl.shaded = true
		lbl.double_sided = false
		lbl.position = Vector3(side * (beam * 0.5 + 0.3), y, -length * 0.5 + length * 0.22)
		lbl.rotation.y = side * PI * 0.5
		_body.add_child(lbl)
