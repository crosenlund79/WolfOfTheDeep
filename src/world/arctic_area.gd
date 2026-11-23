class_name ArcticArea
extends Node3D
## The physical world of the operating region (see Geography): one continuous
## seabed, islands, drifting icebergs with deep keels across the region,
## growlers, pack ice and the floes of the marginal ice zone. Terrain streams
## around the point of view; only nearby icebergs get meshes. Provides
## navigation queries and hull collision tests. x = east, -z = north, metres.
## The original patrol area (Ravnøya, Kestrel Bank, the rock, its 29 bergs)
## is unchanged.

signal ice_calved(world_pos: Vector3, big: bool)

const HALF := 26000.0          # the original patrol area (local scenery)
const REGION_HALF := Geography.REGION_HALF
const BERG_RANGE := 16000.0    # icebergs closer than this get a mesh
const CELL := 8000.0           # spatial index for ice queries
const ISLAND_C := Vector2(4500.0, -5500.0)
const ISLAND_R := 3800.0
const BANK_C := Vector2(-7000.0, -2500.0)
const ROCK_C := Vector2(1300.0, -1150.0)
const LAYER_ICE := 1

var ocean: Ocean
var geo := Geography.new()
var streamer: TerrainStreamer
var focus_pos := Vector3.ZERO
var bergs: Array[Dictionary] = []
var growlers: Array[Dictionary] = []

var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _berg_nodes: Dictionary = {}     # berg id -> MeshInstance3D (nearby only)
var _grid: Dictionary = {}           # Vector2i -> Array of bergs
var _grid_t := 0.0
var _node_t := 0.0
var _node_focus := Vector3(INF, 0.0, INF)
var _local_bergs: Array = []          # the patrol area's own bergs (and later additions)
var _far_dt := 0.0
var _regional_floes: MultiMeshInstance3D
var _floe_center := Vector2(INF, INF)
var _ice_mat: ShaderMaterial
var _float_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.seed = 76
	_noise.frequency = 0.00035
	_noise.fractal_octaves = 5
	_noise2.seed = 11
	_noise2.frequency = 0.004
	_noise2.fractal_octaves = 3
	_rng.seed = 7613
	_ice_mat = ShaderMaterial.new()
	_ice_mat.shader = load("res://src/world/ice.gdshader")
	_float_mat = ShaderMaterial.new()
	_float_mat.shader = load("res://src/world/floating_ice.gdshader")
	if ocean:
		ocean.register_material(_float_mat)
	_make_bergs()
	_make_regional_bergs()
	_rebuild_grid()
	_build_island()
	var seabed := StandardMaterial3D.new()
	seabed.albedo_color = Color(0.09, 0.1, 0.09)
	seabed.roughness = 1.0
	var land := ShaderMaterial.new()
	land.shader = load("res://src/world/terrain.gdshader")
	streamer = TerrainStreamer.new()
	streamer.name = "Terrain"
	streamer.geo = geo
	streamer.seabed_material = seabed
	streamer.land_material = land
	add_child(streamer)
	_update_berg_nodes()
	_build_growlers()
	_build_floes()


# --- geography queries ----------------------------------------------------

func island_radius(theta: float) -> float:
	return geo.ravnoya_radius(theta)


## Approximate signed distance to the nearest coast (negative on land).
func coast_distance(x: float, z: float) -> float:
	return geo.coast_distance(x, z)


func terrain_height(x: float, z: float) -> float:
	return geo.height(x, z)


## Water depth in metres (negative = land above sea level).
func seabed_depth(x: float, z: float) -> float:
	return geo.depth(x, z)


func ice_edge_z(x: float) -> float:
	return geo.ice_edge_z(x)


## Inside the original patrol area (the watch keeps the boat in it while
## patrolling there).
func in_area(p: Vector3) -> bool:
	return absf(p.x) < HALF and absf(p.z) < HALF


## Inside the charted region.
func in_region(p: Vector3) -> bool:
	return geo.in_region(p.x, p.z)


# --- icebergs ---------------------------------------------------------------

func _make_bergs() -> void:
	var defs: Array = []
	# Calved from the island's eastern glacier front.
	for i in 10:
		var a := _rng.randf_range(-0.9, 0.8)
		var r := island_radius(a) + _rng.randf_range(700.0, 4200.0)
		defs.append(ISLAND_C + Vector2(cos(a), sin(a)) * r)
	# Scattered across the northern half, toward the ice edge.
	for i in 13:
		defs.append(Vector2(_rng.randf_range(-20000.0, 20000.0), _rng.randf_range(-16000.0, -5000.0)))
	# A few drifters further south.
	for i in 6:
		defs.append(Vector2(_rng.randf_range(-16000.0, 18000.0), _rng.randf_range(-4000.0, 9000.0)))
	for p in defs:
		var pv: Vector2 = p
		if coast_distance(pv.x, pv.y) < 400.0:
			continue
		var big := _rng.randf() < 0.3
		var radius := _rng.randf_range(55.0, 95.0) if big else _rng.randf_range(16.0, 48.0)
		var height := radius * _rng.randf_range(0.3, 0.6)
		bergs.append({
			"pos": Vector3(pv.x, 0.0, pv.y),
			"r": radius,
			"h": height,
			"keel": clampf(height * _rng.randf_range(4.0, 5.5), 22.0, 175.0),
			"vel": Vector3(_rng.randf_range(-0.12, -0.04), 0.0, _rng.randf_range(0.03, 0.12)),
			"spin": _rng.randf_range(-0.0004, 0.0004),
			"tabular": _rng.randf() < 0.35,
			"seed": _rng.randi() % 1000,
			"rot": _rng.randf() * TAU,
			"id": "ICE-%02d" % bergs.size(),
		})
	for i in 70:
		var b: Dictionary = bergs[_rng.randi() % bergs.size()]
		var off := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(150.0, 1400.0)
		growlers.append({"pos": (b["pos"] as Vector3) + off, "r": _rng.randf_range(3.0, 9.0), "keel": _rng.randf_range(4.0, 12.0)})


## Add an iceberg at runtime (developer hazard tests).
func add_berg(pos: Vector3, radius: float, keel: float) -> Dictionary:
	var b := {"pos": pos, "r": radius, "h": radius * 0.45, "keel": keel, "vel": Vector3.ZERO, "spin": 0.0,
		"tabular": false, "seed": _rng.randi() % 1000, "rot": 0.0, "id": "ICE-T%02d" % bergs.size()}
	bergs.append(b)
	_rebuild_grid()
	_update_berg_nodes()
	return b


## Icebergs across the region: calved from the glaciated islands and drifting
## south-west, plus bergs caught along the ice edge. None inside the original
## patrol area (that keeps its own 29).
func _make_regional_bergs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9901
	var sources := [
		# coast point (km), count, spread along the drift (km)
		[Vector2(-140, -195), 50, 150.0], [Vector2(-175, -150), 40, 140.0], [Vector2(-230, -120), 30, 120.0],
		[Vector2(196, -212), 45, 170.0], [Vector2(150, -250), 30, 130.0],
	]
	for src in sources:
		for i in int(src[1]):
			var along := pow(rng.randf(), 0.7) * float(src[2]) * 1000.0
			var drift := Vector2(-0.62, 0.78).rotated(rng.randf_range(-0.5, 0.5))
			var p := (src[0] as Vector2) * 1000.0 + drift * along + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 9000.0
			_add_regional(rng, p)
	for i in 45:
		var x := rng.randf_range(-280000.0, 280000.0)
		_add_regional(rng, Vector2(x, geo.ice_edge_z(x) + rng.randf_range(-4000.0, 12000.0)))


func _add_regional(rng: RandomNumberGenerator, p: Vector2) -> void:
	if maxf(absf(p.x), absf(p.y)) < 34000.0 or not geo.in_region(p.x, p.y):
		return
	if geo.coast_distance(p.x, p.y) < 600.0:
		return
	var big := rng.randf() < 0.28
	var tab := rng.randf() < 0.3
	var radius := rng.randf_range(60.0, 130.0) if big else rng.randf_range(14.0, 55.0)
	if tab and big:
		radius *= 1.35
	var height := radius * rng.randf_range(0.28, 0.55)
	var water := geo.depth(p.x, p.y)
	var keel := clampf(height * rng.randf_range(4.0, 5.6), 18.0, minf(240.0, water - 6.0))
	if keel < 12.0:
		return
	bergs.append({
		"pos": Vector3(p.x, 0.0, p.y), "r": radius, "h": height, "keel": keel,
		"vel": Vector3(rng.randf_range(-0.13, -0.03), 0.0, rng.randf_range(0.02, 0.12)),
		"spin": rng.randf_range(-0.0003, 0.0003), "tabular": tab, "seed": rng.randi() % 1000,
		"rot": rng.randf() * TAU, "id": "ICE-%03d" % bergs.size(), "regional": true,
	})


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf(p.x / CELL)), int(floorf(p.z / CELL)))


func _rebuild_grid() -> void:
	_grid.clear()
	_local_bergs.clear()
	for b in bergs:
		if not bool(b.get("regional", false)):
			_local_bergs.append(b)
		var k := _cell(b["pos"])
		if not _grid.has(k):
			_grid[k] = []
		(_grid[k] as Array).append(b)


## Bergs whose cells overlap a circle (cheap broad phase).
func bergs_near(p: Vector3, radius: float) -> Array:
	var out: Array = []
	var r := int(ceil((radius + 400.0) / CELL))
	var c := _cell(p)
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var k := c + Vector2i(i, j)
			if _grid.has(k):
				out.append_array(_grid[k])
	return out


## Horizontal radius of a berg's ice at height y (y < 0 underwater).
static func berg_radius_at(b: Dictionary, y: float) -> float:
	if y >= 0.0:
		return float(b["r"]) * (1.0 - 0.3 * clampf(y / float(b["h"]), 0.0, 1.0))
	var k := float(b["keel"])
	if -y > k:
		return 0.0
	return float(b["r"]) * 1.3 * sqrt(maxf(0.0, 1.0 - pow(-y / k, 2.0)))


func advance(dt: float) -> void:
	# The patrol area's bergs and any berg in view drift every step; the rest
	# of the region catches up every ten seconds (a metre or two at most).
	for b in _local_bergs:
		b["pos"] = (b["pos"] as Vector3) + (b["vel"] as Vector3) * dt
		b["rot"] = float(b["rot"]) + float(b["spin"]) * dt
	for id in _berg_nodes.keys():
		var n: MeshInstance3D = _berg_nodes[id]
		var bb: Dictionary = n.get_meta("berg")
		if bool(bb.get("regional", false)):
			bb["pos"] = (bb["pos"] as Vector3) + (bb["vel"] as Vector3) * dt
			bb["rot"] = float(bb["rot"]) + float(bb["spin"]) * dt
		n.position = Vector3((bb["pos"] as Vector3).x, 0.0, (bb["pos"] as Vector3).z)
		n.rotation.y = float(bb["rot"])
	_far_dt += dt
	if _far_dt >= 10.0:
		for b in bergs:
			if bool(b.get("regional", false)) and not _berg_nodes.has(String(b["id"])):
				b["pos"] = (b["pos"] as Vector3) + (b["vel"] as Vector3) * _far_dt
				b["rot"] = float(b["rot"]) + float(b["spin"]) * _far_dt
		_far_dt = 0.0
	_grid_t += dt
	if _grid_t > 30.0:
		_grid_t = 0.0
		_rebuild_grid()
	# Meshes for nearby bergs follow the point of view (not every sim step:
	# at high compression that would be many times a frame).
	_node_t += dt
	if _node_t > 60.0 or Vector2(focus_pos.x - _node_focus.x, focus_pos.z - _node_focus.z).length() > 500.0:
		_node_t = 0.0
		_node_focus = focus_pos
		_update_berg_nodes()
		_update_regional_floes()
	# Occasional calving or groaning from a berg near the point of view.
	if _rng.randf() < dt / 900.0:
		var pool: Array = _local_bergs if in_area(focus_pos) else bergs_near(focus_pos, 9000.0)
		if not pool.is_empty():
			var b2: Dictionary = pool[_rng.randi() % pool.size()]
			ice_calved.emit(b2["pos"], float(b2["r"]) > 50.0)


## Ice within `radius` of p (horizontal), nearest first: [{berg, dist}].
func ice_near(p: Vector3, radius: float) -> Array:
	var out: Array = []
	for b in bergs_near(p, radius):
		var d := Vector2(p.x - (b["pos"] as Vector3).x, p.z - (b["pos"] as Vector3).z).length() - float(b["r"]) * 1.3
		if d < radius:
			out.append({"berg": b, "dist": maxf(d, 0.0)})
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["dist"]) < float(c["dist"]))
	return out


## Test hull sample points against ice and seabed. Returns {} or
## {kind: "ice"/"seabed"/"land", normal: Vector3, depth: float, point: Vector3}.
func hull_collision(points: Array, hull_radius: float) -> Dictionary:
	var near := bergs_near(points[0] if not points.is_empty() else Vector3.ZERO, 200.0)
	for pt in points:
		var p: Vector3 = pt
		# Close pack ice is a lid: nothing surfaces through it.
		if p.y > -3.0 and geo.ice_cover(p.x, p.z) > 0.6:
			return {"kind": "ice", "normal": Vector3.DOWN, "depth": p.y + 3.0, "point": p, "pack": true}
		for b in near:
			var bp: Vector3 = b["pos"]
			var hd := Vector2(p.x - bp.x, p.z - bp.z)
			if hd.length() > float(b["r"]) * 1.4 + hull_radius + 2.0:
				continue
			var rr := berg_radius_at(b, p.y)
			if rr <= 0.0:
				continue
			var pen := rr + hull_radius - hd.length()
			if pen > 0.0:
				var nrm := Vector3(hd.x, 0.0, hd.y).normalized() if hd.length() > 0.01 else Vector3.BACK
				return {"kind": "ice", "normal": nrm, "depth": pen, "point": p, "berg": b}
		var sb := seabed_depth(p.x, p.z)
		if -p.y + hull_radius * 0.8 > sb:
			# The bottom's own slope: running into a rising seabed is an impact,
			# not just a nudge upwards.
			var e := 15.0
			var gx := (seabed_depth(p.x + e, p.z) - seabed_depth(p.x - e, p.z)) / (2.0 * e)
			var gz := (seabed_depth(p.x, p.z + e) - seabed_depth(p.x, p.z - e)) / (2.0 * e)
			return {"kind": "land" if sb < 3.0 else "seabed", "normal": Vector3(gx, 1.0, gz).normalized(), "depth": -p.y + hull_radius * 0.8 - sb, "point": p}
	return {}


# --- scenery ------------------------------------------------------------------

func _build_island() -> void:
	var n := 230
	var size := 13000.0
	var origin := Vector3(ISLAND_C.x - size * 0.5, 0.0, ISLAND_C.y - size * 0.5)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in n:
		for i in n:
			var x := origin.x + size * float(i) / float(n - 1)
			var z := origin.z + size * float(j) / float(n - 1)
			var h := terrain_height(x, z)
			verts.append(Vector3(x, maxf(h, -70.0), z))
			uvs.append(Vector2(x, z))
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	st.create_from_arrays(arrays)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Ravnoya"
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/terrain.gdshader")
	mi.material_override = mat
	add_child(mi)


func _update_berg_nodes() -> void:
	var want := {}
	for b in bergs_near(focus_pos, BERG_RANGE):
		var bp: Vector3 = b["pos"]
		if Vector2(bp.x - focus_pos.x, bp.z - focus_pos.z).length() < BERG_RANGE:
			want[String(b["id"])] = b
	for id in _berg_nodes.keys():
		if not want.has(id):
			(_berg_nodes[id] as Node).queue_free()
			_berg_nodes.erase(id)
	for id in want.keys():
		if _berg_nodes.has(id):
			continue
		var b: Dictionary = want[id]
		var mi := MeshInstance3D.new()
		mi.mesh = _berg_mesh(b)
		mi.material_override = _ice_mat
		mi.position = Vector3((b["pos"] as Vector3).x, 0.0, (b["pos"] as Vector3).z)
		mi.rotation.y = float(b["rot"])
		mi.set_meta("berg", b)
		add_child(mi)
		_berg_nodes[id] = mi


## Floes of the pack and the marginal ice zone around the view, wherever the
## boat is in the region (the original area keeps its own fixed floes).
func _update_regional_floes() -> void:
	var c := Vector2(focus_pos.x, focus_pos.z)
	if c.distance_to(_floe_center) < 3000.0:
		return
	_floe_center = c
	if _regional_floes:
		_regional_floes.queue_free()
		_regional_floes = null
	if maxf(absf(c.x), absf(c.y)) < HALF - 6000.0:
		return
	if geo.ice_edge_z(c.x) + 14000.0 < c.y:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x / 3000.0) * 7919 + int(c.y / 3000.0)
	var xs: Array[Transform3D] = []
	for i in 2600:
		var p := c + Vector2(rng.randf_range(-7000.0, 7000.0), rng.randf_range(-7000.0, 7000.0))
		var into := (geo.ice_edge_z(p.x) + 2500.0 - p.y) / 9000.0
		if into < 0.0 or rng.randf() > clampf(into, 0.05, 1.0) or geo.coast_distance(p.x, p.y) < 50.0:
			continue
		var size := lerpf(4.0, 28.0, clampf(into, 0.0, 1.0)) * rng.randf_range(0.6, 1.3)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, 1.4, size * rng.randf_range(0.5, 1.0))), Vector3(p.x, 0.0, p.y)))
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 7
	cyl.rings = 1
	cyl.top_radius = 1.0
	cyl.bottom_radius = 0.92
	cyl.height = 1.0
	mm.mesh = cyl
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	_regional_floes = MultiMeshInstance3D.new()
	_regional_floes.multimesh = mm
	_regional_floes.material_override = _float_mat
	add_child(_regional_floes)


func _berg_mesh(b: Dictionary) -> ArrayMesh:
	var r := float(b["r"])
	var h := float(b["h"])
	var keel := float(b["keel"])
	var seed_v := float(b["seed"])
	var tabular: bool = b["tabular"]
	# Craggy detail around the same mean profile the collisions use
	# (berg_radius_at): pinnacles on a weathered berg, cliffs and a flat top
	# on a tabular one, a wave-cut notch at the waterline, a ridged keel.
	var nz := FastNoiseLite.new()
	nz.seed = int(seed_v) + 31
	nz.frequency = 0.9
	nz.fractal_octaves = 4
	var peaks := [fposmod(seed_v * 0.37, TAU), fposmod(seed_v * 1.13 + 2.0, TAU), fposmod(seed_v * 2.71 + 4.0, TAU)]
	var f := func(u: float, v: float) -> Vector3:
		var a := v * TAU
		var ca := cos(a)
		var sa := sin(a)
		var wob := 1.0 + 0.14 * sin(3.0 * a + seed_v) + 0.08 * sin(5.0 * a + seed_v * 1.7)
		var y: float
		var rad: float
		# Height of the top along this side (pinnacles for weathered bergs).
		var top := h
		if not tabular:
			var pk := 0.0
			for p in peaks:
				pk = maxf(pk, exp(-pow(wrapf(a - float(p), -PI, PI) / 0.55, 2.0)))
			top = h * (0.55 + 0.45 * pk)
		if u < 0.14:
			var t := u / 0.14
			y = top * (1.0 - (0.04 if tabular else 0.3) * t * t) + (0.0 if tabular else 0.2 * h * (1.0 - t))
			rad = r * (0.97 if tabular else 0.7) * sin(t * PI * 0.5)
		elif u < 0.42:
			var t2 := (u - 0.14) / 0.28
			y = lerpf(top * (0.98 if tabular else 0.7), 0.0, t2)
			var mean := 1.0 - 0.3 * clampf(y / maxf(h, 1.0), 0.0, 1.0)
			rad = r * (1.0 if tabular else mean)
			# Wave-cut notch just above the water.
			rad *= 1.0 - 0.1 * exp(-pow((y - 1.2) / 1.0, 2.0))
		else:
			var t3 := (u - 0.42) / 0.58
			y = -keel * t3
			rad = r * 1.3 * sqrt(maxf(0.0, 1.0 - t3 * t3)) * (1.0 + 0.1 * sin(t3 * 7.0 + a * 3.0 + seed_v))
		var n := nz.get_noise_3d(ca * 2.0, y / maxf(r, 1.0) * 2.0, sa * 2.0)
		rad *= wob * (1.0 + 0.16 * n)
		return Vector3(ca * rad, y, sa * rad)
	var uvf := func(u: float, v: float) -> Vector2: return Vector2(v * 8.0, u * 6.0)
	var mesh := ArrayMesh.new()
	ParamMesh.add_to(mesh, ParamMesh.surface(f, uvf, 56, 80), _ice_mat)
	return mesh


func _build_growlers() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radial_segments = 9
	sm.rings = 5
	sm.radius = 1.0
	sm.height = 1.2
	mm.mesh = sm
	mm.instance_count = growlers.size()
	for i in growlers.size():
		var g := growlers[i]
		var rr := float(g["r"])
		var t := Transform3D(Basis.from_euler(Vector3(_rng.randf() * 0.4, _rng.randf() * TAU, 0.0)).scaled(Vector3(rr, rr * 0.55, rr * 0.8)), (g["pos"] as Vector3) + Vector3(0, rr * 0.08, 0))
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _float_mat
	add_child(mmi)


func _build_floes() -> void:
	var count := 2400
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 7
	cyl.rings = 1
	cyl.top_radius = 1.0
	cyl.bottom_radius = 0.92
	cyl.height = 1.0
	mm.mesh = cyl
	mm.instance_count = count
	for i in count:
		var x := _rng.randf_range(-HALF, HALF)
		var edge := ice_edge_z(x)
		# Denser and larger toward the pack.
		var into := pow(_rng.randf(), 0.6)
		var z := edge + 2500.0 - into * 8500.0
		var size := lerpf(4.0, 26.0, into) * _rng.randf_range(0.6, 1.3)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, 1.4, size * _rng.randf_range(0.5, 1.0))), Vector3(x, 0.0, z))
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Floes"
	mmi.multimesh = mm
	mmi.material_override = _float_mat
	add_child(mmi)


func save_state() -> Dictionary:
	var bs: Array = []
	for b in bergs:
		bs.append({"id": b["id"], "pos": SaveSystem.v3(b["pos"]), "rot": b["rot"]})
	return {"bergs": bs, "rng": _rng.state}


func load_state(d: Dictionary) -> void:
	var by_id := {}
	for b in bergs:
		by_id[String(b["id"])] = b
	for bd in d.get("bergs", []):
		var b: Dictionary = by_id.get(String(bd.get("id", "")), {})
		if b.is_empty():
			continue
		b["pos"] = SaveSystem.to_v3(bd.get("pos"), b["pos"])
		b["rot"] = float(bd.get("rot", b["rot"]))
	_rebuild_grid()
	_update_berg_nodes()
	advance(0.0)
