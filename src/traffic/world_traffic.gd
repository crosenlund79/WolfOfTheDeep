class_name WorldTraffic
extends Node
## Ships and aircraft that go about their business across the region:
## merchant lanes, fishing on the banks, the coast guard, a research ship,
## foreign warships on deployment, maritime patrol aircraft and airliners on
## polar routes. Each has a real position all the time; a vessel only becomes
## a 3D ship (and enters the sensor picture) when it is within reach, and is
## parked again when it is far. All of it stays well clear of the original
## patrol area unless something draws it there.
##
## Aircraft are shown on the chart only as the boat knows them: ESM bearings
## (suspected), sightings (confirmed) and last known positions.

signal vessel_materialised(ship: SurfaceShip)
signal aircraft_event(kind: String, a: Dictionary, detail: String)

const NEAR := 42000.0          # becomes a ship (AIS reaches 40 km)
const PARK := 60000.0          # leaves the picture
const FAR_VIS := 30000.0       # beyond the horizon: no meshes or wave motion
const TICK := 10.0
const KEEP_CLEAR := 85000.0    # routes keep this far from the patrol area's centre

var world: Node3D
var ocean: Ocean
var area: ArcticArea
var sub: Submarine
var clock: GameClock
var weather: Weather
var intel: IntelDB
var vessels: Array[Node3D] = []

var voyages: Array[Dictionary] = []
var flights: Array[Dictionary] = []
var marks: Array = []                  # chart aircraft marks (known only)
var foreign_alert := 0.0               # how stirred up the foreign forces are
var datum: Array = []                  # [x, z, t] of the last incident they know of
var _known_air := {}                   # flight id -> what the boat knows
var _nodes := {}                       # voyage id -> SurfaceShip (kept once made)
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
var _next_flight := 1
var _sortie := {"heron": 0.0, "skua": 0.0, "airliner": 0.0}


func setup() -> void:
	_rng.seed = 5150
	_make_voyages()
	_sortie = {"heron": clock.seconds + 5.0 * 3600.0, "skua": clock.seconds + 2.0 * 3600.0, "airliner": clock.seconds + 1800.0}


static func _v(a: Array) -> Array:
	var out: Array = []
	for p in a:
		out.append([float(p.x) * 1000.0, float(p.y) * 1000.0])
	return out


func _voyage(id: String, kind: int, vname: String, cls: String, navy: String, flag: String, route: Array, knots: float, behavior: String, loop: bool) -> Dictionary:
	var r := _v(route)
	var v := {"id": id, "kind": kind, "name": vname, "class": cls, "navy": navy, "flag": flag, "pos": (r[0] as Array).duplicate(),
		"heading": 0.0, "knots": knots, "route": r, "ri": 1, "loop": loop, "behavior": behavior, "center": [], "radius": 0.0,
		"ais": navy != "FOREIGN", "state": "afloat", "active": true, "cid": "", "deploy_until": -1.0, "away_until": -1.0}
	voyages.append(v)
	return v


func _make_voyages() -> void:
	var K := SurfaceShip.Kind
	_voyage("T01", K.MERCHANT, "NORDLYS TRADER", "merchant", "CIVIL", "Liberia",
		[Vector2(-300, 150), Vector2(-120, 112), Vector2(0, 112), Vector2(150, 92), Vector2(300, 62)], 13.0, "transit", true)
	_voyage("T02", K.MERCHANT, "CAPE ESKER", "merchant", "CIVIL", "Marshall Islands",
		[Vector2(300, 20), Vector2(170, 15), Vector2(110, 60), Vector2(60, 120), Vector2(-40, 150), Vector2(-200, 146), Vector2(-300, 205)], 15.0, "transit", true)
	_voyage("T03", K.MERCHANT, "MAREN BULK", "merchant", "CIVIL", "Panama",
		[Vector2(-300, 280), Vector2(0, 260), Vector2(300, 240)], 11.5, "transit", true)
	# Start the lanes part-way along so the region isn't empty on day one.
	for v in voyages:
		_advance_voyage(v, _rng.randf_range(4.0, 30.0) * 3600.0)
	var tr1 := _voyage("T04", K.TRAWLER, "SØRVÆR", "trawler", "CIVIL", "Home", [Vector2(185, 165)], 3.5, "fishing", false)
	tr1["center"] = [185000.0, 165000.0]
	tr1["radius"] = 14000.0
	var tr2 := _voyage("T05", K.TRAWLER, "ISBJØRN II", "trawler", "CIVIL", "Home", [Vector2(-30, 205)], 3.5, "fishing", false)
	tr2["center"] = [-30000.0, 205000.0]
	tr2["radius"] = 12000.0
	var tr3 := _voyage("T06", K.TRAWLER, "HØGVÆR", "trawler", "CIVIL", "Home", [Vector2(-135, 195)], 3.5, "fishing", false)
	tr3["center"] = [-135000.0, 195000.0]
	tr3["radius"] = 10000.0
	_voyage("T07", K.PATROL, "KV VARDØ", "vakt", "HOME", "Home",
		[Vector2(-158, 150), Vector2(-30, 180), Vector2(150, 150), Vector2(-30, 180)], 12.0, "transit", true)
	_voyage("T08", K.RESEARCH, "HAVFORSK", "research", "CIVIL", "Home",
		[Vector2(60, 130), Vector2(122, 70), Vector2(160, 0), Vector2(122, 70)], 8.0, "transit", true)
	var fr := _voyage("T09", K.FRIGATE, "", "boreas", "FOREIGN", "Foreign",
		[Vector2(230, -10), Vector2(150, -15), Vector2(110, 30), Vector2(210, 45)], 14.0, "patrol", true)
	fr["deploy_until"] = clock.seconds + 60.0 * 3600.0
	var cv := _voyage("T10", K.PATROL, "", "grim", "FOREIGN", "Foreign",
		[Vector2(-120, -22), Vector2(-85, -8), Vector2(-170, -45)], 11.0, "patrol", true)
	cv["deploy_until"] = clock.seconds + 40.0 * 3600.0
	for v2 in voyages:
		if String(v2["navy"]) == "FOREIGN":
			var c := intel.assign_commander(String(v2["id"]), false)
			v2["cid"] = String(c.get("id", ""))


# --- simulation -------------------------------------------------------------------

func advance(dt: float) -> void:
	_acc += dt
	if _acc < TICK:
		return
	var step := _acc
	_acc = 0.0
	for v in voyages:
		if String(v["state"]) != "afloat":
			continue
		var node: SurfaceShip = _nodes.get(v["id"])
		if node and vessels.has(node):
			_pull(v, node)
		else:
			_advance_voyage(v, step)
		_deployment(v)
	_materialise()
	_air(step)
	foreign_alert = maxf(foreign_alert - step / (36.0 * 3600.0), 0.0)


func _advance_voyage(v: Dictionary, dt: float) -> void:
	if not bool(v["active"]):
		return
	var p := Vector2(float(v["pos"][0]), float(v["pos"][1]))
	if String(v["behavior"]) == "fishing":
		# Slow trawls from one spot on the bank to the next.
		var c := Vector2(float(v["center"][0]), float(v["center"][1]))
		var dat: Array = v.get("datum", [])
		if dat.is_empty() or p.distance_to(Vector2(float(dat[0]), float(dat[1]))) < 300.0:
			var nd := c + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, float(v["radius"]))
			dat = [nd.x, nd.y]
			v["datum"] = dat
		var d := Vector2(float(dat[0]), float(dat[1])) - p
		v["heading"] = atan2(d.x, -d.y)
		p += d.normalized() * minf(d.length(), 1.8 * dt)
		v["pos"] = [p.x, p.y]
		return
	var left := float(v["knots"]) * 0.5144 * dt
	var route: Array = v["route"]
	var guard := 0
	while left > 0.0 and guard < 20:
		guard += 1
		var ri := int(v["ri"])
		if ri >= route.size():
			if bool(v["loop"]):
				# Lanes run both ways: turn round at the end.
				route.reverse()
				v["ri"] = 1
				continue
			break
		var w := Vector2(float(route[ri][0]), float(route[ri][1]))
		var d2 := w - p
		v["heading"] = atan2(d2.x, -d2.y)
		if d2.length() <= left:
			p = w
			left -= d2.length()
			v["ri"] = ri + 1
		else:
			p += d2.normalized() * left
			left = 0.0
	v["pos"] = [p.x, p.y]


## Foreign units come and go: a deployment ends, the ship leaves the region,
## and some days later she (or another with a new commander) returns.
func _deployment(v: Dictionary) -> void:
	if String(v["navy"]) != "FOREIGN":
		return
	if bool(v["active"]) and float(v["deploy_until"]) > 0.0 and clock.seconds > float(v["deploy_until"]):
		var node: SurfaceShip = _nodes.get(v["id"])
		if node == null or not vessels.has(node):
			v["active"] = false
			v["away_until"] = clock.seconds + _rng.randf_range(36.0, 72.0) * 3600.0
			intel.release_commander(String(v["id"]))
			v["cid"] = ""
	elif not bool(v["active"]) and clock.seconds > float(v["away_until"]):
		v["active"] = true
		v["deploy_until"] = clock.seconds + _rng.randf_range(40.0, 80.0) * 3600.0
		var route: Array = v["route"]
		v["pos"] = (route[0] as Array).duplicate()
		v["ri"] = 1
		var c := intel.assign_commander(String(v["id"]), true)
		v["cid"] = String(c.get("id", ""))
		var node2: SurfaceShip = _nodes.get(v["id"])
		if node2:
			node2.commander = c


func _materialise() -> void:
	var sp := Vector2(sub.global_position.x, sub.global_position.z)
	for v in voyages:
		if String(v["state"]) != "afloat":
			continue
		var p := Vector2(float(v["pos"][0]), float(v["pos"][1]))
		var d := p.distance_to(sp)
		var node: SurfaceShip = _nodes.get(v["id"])
		var held := node != null and vessels.has(node)
		if bool(v["active"]) and d < NEAR and not held:
			if node == null:
				node = _make_node(v)
			_push(v, node)
			vessels.append(node)
			vessel_materialised.emit(node)
		elif held and (d > PARK or not bool(v["active"])):
			_pull(v, node)
			vessels.erase(node)
			node.set_far(true)
			node.visible = false
		if node and vessels.has(node):
			node.set_far(d > FAR_VIS)


func _make_node(v: Dictionary) -> SurfaceShip:
	var s := SurfaceShip.new()
	s.kind = int(v["kind"]) as SurfaceShip.Kind
	s.vessel_name = String(v["name"])
	s.ocean = ocean
	s.name = "Traffic_" + String(v["id"])
	s.uid = String(v["id"])
	s.recycle = false
	s.variant = {"vakt": "opv", "grim": "corvette"}.get(String(v["class"]), "bulk" if String(v["name"]).contains("BULK") else "")
	world.add_child(s)
	_nodes[v["id"]] = s
	return s


## Voyage -> ship (on materialising).
func _push(v: Dictionary, s: SurfaceShip) -> void:
	s.visible = true
	s.ais_on = bool(v["ais"])
	s.place(Vector3(float(v["pos"][0]), 0.0, float(v["pos"][1])), float(v["heading"]), float(v["knots"]))
	s.commander = intel.commanders.get(String(v["cid"]), {})
	if String(v["behavior"]) == "fishing":
		s.behavior = "fishing"
		s.fishing_center = Vector3(float(v["center"][0]), 0.0, float(v["center"][1]))
		s.fishing_radius = float(v["radius"])
		return
	var pts: Array = []
	var route: Array = v["route"]
	for i in range(int(v["ri"]), route.size()):
		pts.append(Vector3(float(route[i][0]), 0.0, float(route[i][1])))
	if pts.is_empty():
		pts.append(Vector3(float(route[0][0]), 0.0, float(route[0][1])))
	s.set_route(pts, false, float(v["knots"]))
	if String(v["behavior"]) == "patrol":
		s.behavior = "patrol"


## Ship -> voyage (while materialised the ship is the truth).
func _pull(v: Dictionary, s: SurfaceShip) -> void:
	v["pos"] = [s.position.x, s.position.z]
	v["heading"] = s.heading
	if s.state == SurfaceShip.State.SUNK:
		v["state"] = "sunk"
	elif String(v["behavior"]) != "fishing" and s.behavior in ["route", "patrol", "drift"]:
		# Remaining route points were handed over; map progress back.
		var route: Array = v["route"]
		var left := s.route.size() - s.route_index
		v["ri"] = clampi(route.size() - left, 1, route.size())
		if s.behavior == "drift" and bool(v["loop"]):
			route.reverse()
			v["ri"] = 1
			_push(v, s)


func node_for(id: String) -> SurfaceShip:
	return _nodes.get(id)


func voyage(id: String) -> Dictionary:
	for v in voyages:
		if String(v["id"]) == id:
			return v
	return {}


## Something happened that the foreign forces will hear of (an attack, a
## sinking, a confirmed detection): they become more active and come to look.
func incident(pos: Vector3, weight: float) -> void:
	foreign_alert = minf(foreign_alert + weight, 1.0)
	datum = [pos.x, pos.z, clock.seconds]
	if foreign_alert > 0.45:
		_sortie["heron"] = minf(float(_sortie["heron"]), clock.seconds + _rng.randf_range(1.5, 4.0) * 3600.0)


# --- aircraft ---------------------------------------------------------------------

func _air(dt: float) -> void:
	var now := clock.seconds
	if now >= float(_sortie["airliner"]):
		_sortie["airliner"] = now + _rng.randf_range(2.0, 5.0) * 3600.0
		var a := Vector2(-300000.0, _rng.randf_range(-250000.0, 250000.0))
		var b := Vector2(300000.0, _rng.randf_range(-250000.0, 250000.0))
		if _rng.randf() < 0.5:
			var t := a
			a = b
			b = t
		_flight("airliner", "CIVIL", [a, b], 10500.0, 470.0, true)
	if now >= float(_sortie["skua"]):
		_sortie["skua"] = now + _rng.randf_range(16.0, 26.0) * 3600.0
		# Our own patrol aircraft looks over the foreign units' areas.
		_flight("skua", "HOME", [Vector2(0, 300000), Vector2(140000, 100000), Vector2(200000, 0), Vector2(110000, 40000),
			Vector2(-110000, -30000), Vector2(-160000, 60000), Vector2(0, 300000)], 600.0, 260.0, true)
	if now >= float(_sortie["heron"]):
		_sortie["heron"] = now + _rng.randf_range(14.0, 22.0) * 3600.0 * (1.0 - 0.5 * foreign_alert)
		var path: Array = [Vector2(300000, -90000), Vector2(200000, -40000), Vector2(120000, 50000), Vector2(200000, -40000), Vector2(120000, 50000), Vector2(300000, -90000)]
		if foreign_alert > 0.45 and not datum.is_empty():
			# Sent to look where something happened.
			var dp := Vector2(float(datum[0]), float(datum[1]))
			path = [Vector2(300000, -90000), dp + Vector2(8000, 0), dp + Vector2(0, 8000), dp + Vector2(-8000, 0), dp + Vector2(0, -8000), dp + Vector2(8000, 0), Vector2(300000, -90000)]
		_flight("heron", "FOREIGN", path, 450.0, 230.0, true)
	for f in flights:
		if bool(f["done"]):
			continue
		_fly(f, dt)
	flights = flights.filter(func(f: Dictionary) -> bool: return not bool(f["done"]) or clock.seconds - float(f["t_end"]) < 3600.0)
	_sense_air()


func _flight(cls: String, navy: String, path: Array, alt: float, kts: float, emit: bool) -> Dictionary:
	var pts: Array = []
	for p in path:
		pts.append([float(p.x), float(p.y)])
	var f := {"id": "A%02d" % _next_flight, "class": cls, "navy": navy, "path": pts, "seg": 1, "pos": (pts[0] as Array).duplicate(),
		"alt": alt, "kts": kts, "emit": emit, "done": false, "t0": clock.seconds, "t_end": 0.0, "heading": 0.0, "seen_sub": false}
	_next_flight += 1
	flights.append(f)
	return f


func _fly(f: Dictionary, dt: float) -> void:
	var p := Vector2(float(f["pos"][0]), float(f["pos"][1]))
	var left := float(f["kts"]) * 0.5144 * dt
	var path: Array = f["path"]
	while left > 0.0:
		var si := int(f["seg"])
		if si >= path.size():
			f["done"] = true
			f["t_end"] = clock.seconds
			break
		var w := Vector2(float(path[si][0]), float(path[si][1]))
		var d := w - p
		f["heading"] = atan2(d.x, -d.y)
		if d.length() <= left:
			p = w
			left -= d.length()
			f["seg"] = si + 1
		else:
			p += d.normalized() * left
			left = 0.0
	f["pos"] = [p.x, p.y]
	# A foreign patrol aircraft may find the boat: radar against masts or a
	# surfaced hull, eyes in daylight.
	if String(f["class"]) == "heron" and not bool(f["done"]):
		var sp := Vector2(sub.global_position.x, sub.global_position.z)
		var dist := p.distance_to(sp)
		var mast := sub.mast_extension() > 0.5 and sub.depth < 13.0
		var light := 1.0 - weather.darkness() * 0.8
		var chance := 0.0
		if sub.is_surfaced() and dist < 40000.0:
			chance = 0.35 * (1.0 - dist / 40000.0) + 0.2 * light
		elif mast and dist < 14000.0:
			chance = 0.25 * (1.0 - dist / 14000.0) * (1.0 + sub.speed * 0.2)
		if chance > 0.0 and _rng.randf() < chance * dt / 60.0 and not bool(f["seen_sub"]):
			f["seen_sub"] = true
			foreign_alert = minf(foreign_alert + 0.3, 1.0)
			datum = [sp.x, sp.y, clock.seconds]
			aircraft_event.emit("detected_us", f, "")


## What the boat can know of aircraft: ESM with a mast up, eyes at the
## periscope or on the bridge. Everything else is a last known position.
func _sense_air() -> void:
	var now := clock.seconds
	var sp := Vector2(sub.global_position.x, sub.global_position.z)
	var masts := (sub.masts_up and sub.mast_extension() > 0.9 and sub.depth < 12.5) or sub.is_surfaced()
	var eyes := sub.periscope_state() == Submarine.Scope.CLEAR or sub.is_surfaced()
	var vis := weather.visibility_m() * (1.0 - weather.darkness() * 0.85)
	for f in flights:
		if bool(f["done"]):
			continue
		var p := Vector2(float(f["pos"][0]), float(f["pos"][1]))
		var d := p.distance_to(sp)
		var horizon := 4120.0 * (sqrt(3.0) + sqrt(float(f["alt"])))
		var how := ""
		if eyes and d < minf(vis, 14000.0 if float(f["alt"]) < 3000.0 else 35000.0):
			how = "visual"
		elif masts and bool(f["emit"]) and d < minf(horizon, 260000.0 if String(f["class"]) != "airliner" else 160000.0):
			how = "esm"
		if how == "":
			continue
		var k: Dictionary = _known_air.get(f["id"], {})
		var first := k.is_empty()
		var prev_how := String(k.get("how", ""))
		var brg := fposmod(rad_to_deg(atan2(p.x - sp.x, -(p.y - sp.y))), 360.0)
		var est := p
		var unc := d * 0.05
		if how == "esm":
			# A bearing and a strength: range is a guess.
			var rr := d * _rng.randf_range(0.6, 1.5)
			est = sp + Vector2(sin(deg_to_rad(brg)), -cos(deg_to_rad(brg))) * rr
			unc = rr * 0.5
		k = {"id": f["id"], "pos": [est.x, est.y], "t": now, "how": how, "unc": unc, "brg": brg, "from": [sp.x, sp.y], "class": f["class"], "navy": f["navy"],
			"heading": float(f["heading"]), "kts": float(f["kts"])}
		_known_air[f["id"]] = k
		if first or (how == "visual" and prev_how != "visual"):
			aircraft_event.emit("new_" + how, f, "%03d" % int(brg))
	_rebuild_marks()


func _rebuild_marks() -> void:
	var now := clock.seconds
	marks.clear()
	for id in _known_air.keys():
		var k: Dictionary = _known_air[id]
		var age := now - float(k["t"])
		if age > 1200.0:
			_known_air.erase(id)
			continue
		var kind := "confirmed" if String(k["how"]) == "visual" else "suspected"
		var unc := float(k["unc"])
		if age > 60.0:
			kind = "lkp"
			unc += float(k["kts"]) * 0.5144 * age * 0.4
		var label := ""
		match String(k["class"]):
			"airliner":
				label = "AIR (civil, prob.)"
			"skua":
				label = "AIR · own MPA" if String(k["how"]) == "visual" else "AIR · ESM, own MPA radar (prob.)"
			"heron":
				label = "AIR · MPA (foreign)" if String(k["how"]) == "visual" else "AIR · ESM, MPA radar (foreign, prob.)"
		if kind == "lkp":
			label += "  · LKP %d min" % int(age / 60.0)
		var col := Color(0.85, 0.15, 0.1) if String(k["navy"]) == "FOREIGN" else (Color(0.1, 0.45, 0.85) if String(k["navy"]) == "HOME" else Color(0.45, 0.45, 0.45))
		var m := {"pos": Vector3(float(k["pos"][0]), 0.0, float(k["pos"][1])), "kind": kind, "unc": minf(unc, 40000.0), "label": label, "color": col}
		if String(k["how"]) == "esm" and k.has("from"):
			# A bearing, not a position: drawn as a line from where it was taken.
			m["from"] = Vector3(float(k["from"][0]), 0.0, float(k["from"][1]))
			m["brg"] = float(k["brg"])
		marks.append(m)


# --- persistence ------------------------------------------------------------------

func save_state() -> Dictionary:
	for v in voyages:
		var node: SurfaceShip = _nodes.get(v["id"])
		if node and vessels.has(node):
			_pull(v, node)
	var held: Array = []
	for id in _nodes.keys():
		if vessels.has(_nodes[id]):
			held.append(id)
	return {"voyages": voyages.duplicate(true), "flights": flights.duplicate(true), "known_air": _known_air.duplicate(true),
		"alert": foreign_alert, "datum": datum.duplicate(), "next_flight": _next_flight, "sortie": _sortie.duplicate(), "rng": _rng.state,
		"ships": held.map(func(id: String) -> Dictionary: return (_nodes[id] as SurfaceShip).save_state())}


func load_state(d: Dictionary) -> void:
	var vs: Variant = d.get("voyages")
	if vs is Array:
		voyages.clear()
		for v in vs:
			voyages.append(v)
	var fs: Variant = d.get("flights")
	if fs is Array:
		flights.clear()
		for f in fs:
			flights.append(f)
	var ka: Variant = d.get("known_air")
	if ka is Dictionary:
		_known_air = ka
	foreign_alert = float(d.get("alert", 0.0))
	datum = d.get("datum", [])
	_next_flight = int(d.get("next_flight", _next_flight))
	var so: Variant = d.get("sortie")
	if so is Dictionary:
		_sortie = so
	if d.has("rng"):
		_rng.state = int(d["rng"])
	# Ships that were in the picture come back as they were.
	for sd in d.get("ships", []):
		var v := voyage(String(sd.get("uid", "")))
		if v.is_empty():
			continue
		var node: SurfaceShip = _nodes.get(v["id"])
		if node == null:
			node = _make_node(v)
		_push(v, node)
		node.load_state(sd)
		if not vessels.has(node):
			vessels.append(node)
			vessel_materialised.emit(node)
	_rebuild_marks()
