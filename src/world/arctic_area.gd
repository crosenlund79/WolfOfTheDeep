class_name ArcticArea
extends Node3D
## The patrol area: a fictional island (Ravnøya), bathymetry with a shelf,
## a fishing bank and a rock, drifting icebergs with deep keels, growlers and
## the floes of the marginal ice zone. Provides navigation queries and hull
## collision tests. x = east, -z = north, metres.

signal ice_calved(world_pos: Vector3, big: bool)

const HALF := 26000.0
const ISLAND_C := Vector2(4500.0, -5500.0)
const ISLAND_R := 3800.0
const BANK_C := Vector2(-7000.0, -2500.0)
const ROCK_C := Vector2(1300.0, -1150.0)
const LAYER_ICE := 1

var ocean: Ocean
var bergs: Array[Dictionary] = []
var growlers: Array[Dictionary] = []

var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _berg_nodes: Array[MeshInstance3D] = []
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
	_build_island()
	_build_seabed()
	_build_bergs()
	_build_growlers()
	_build_floes()


# --- geography queries ----------------------------------------------------

func island_radius(theta: float) -> float:
	var r := ISLAND_R * (1.0 + 0.25 * sin(2.0 * theta + 0.5) + 0.15 * sin(3.0 * theta + 1.7) + 0.08 * sin(7.0 * theta))
	# A narrow fjord cutting in from the east.
	var dt := wrapf(theta - 0.15, -PI, PI)
	r *= 1.0 - 0.55 * exp(-pow(dt / 0.07, 2.0))
	return r


## Approximate signed distance to the island coast (negative on land).
func coast_distance(x: float, z: float) -> float:
	var d := Vector2(x, z) - ISLAND_C
	return d.length() - island_radius(atan2(d.y, d.x))


func terrain_height(x: float, z: float) -> float:
	var sd := coast_distance(x, z)
	if sd > 0.0:
		return -seabed_depth(x, z)
	var inland := -sd
	var cliff := smoothstep(0.0, 160.0, inland) * 55.0
	var massif := pow(smoothstep(0.0, 2800.0, inland), 0.9) * 620.0 * (0.62 + 0.38 * (_noise.get_noise_2d(x, z) + 1.0) * 0.5)
	return cliff + massif + _noise2.get_noise_2d(x, z) * 18.0 * smoothstep(0.0, 400.0, inland)


## Water depth in metres (negative = land above sea level).
func seabed_depth(x: float, z: float) -> float:
	var sd := coast_distance(x, z)
	if sd <= 0.0:
		return -1.0
	var d := 290.0 + _noise.get_noise_2d(x * 0.6 + 900.0, z * 0.6) * 70.0
	# Northern trough toward the ice edge.
	d += smoothstep(-12000.0, -22000.0, z) * 120.0
	# Island shelf shoaling to the coast.
	d = lerpf(d, 12.0, pow(1.0 - smoothstep(0.0, 5200.0, sd), 1.6))
	# Kestrel Bank, a fishing ground.
	var bd := Vector2(x, z).distance_to(BANK_C)
	d = minf(d, 38.0 + 32.0 * pow(bd / 3000.0, 2.0))
	# A lone rock off the island's southwest shore.
	var rd := Vector2(x, z).distance_to(ROCK_C)
	d = minf(d, 6.0 + rd * 0.09)
	return maxf(d, 2.0)


func ice_edge_z(x: float) -> float:
	return -17500.0 + 1800.0 * sin(x / 7000.0) + 600.0 * sin(x / 2300.0 + 1.0)


func in_area(p: Vector3) -> bool:
	return absf(p.x) < HALF and absf(p.z) < HALF


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
	var mi := MeshInstance3D.new()
	mi.mesh = _berg_mesh(b)
	mi.material_override = _ice_mat
	mi.position = Vector3(pos.x, 0.0, pos.z)
	add_child(mi)
	_berg_nodes.append(mi)
	return b


## Horizontal radius of a berg's ice at height y (y < 0 underwater).
static func berg_radius_at(b: Dictionary, y: float) -> float:
	if y >= 0.0:
		return float(b["r"]) * (1.0 - 0.3 * clampf(y / float(b["h"]), 0.0, 1.0))
	var k := float(b["keel"])
	if -y > k:
		return 0.0
	return float(b["r"]) * 1.3 * sqrt(maxf(0.0, 1.0 - pow(-y / k, 2.0)))


func advance(dt: float) -> void:
	for i in bergs.size():
		var b := bergs[i]
		b["pos"] = (b["pos"] as Vector3) + (b["vel"] as Vector3) * dt
		b["rot"] = float(b["rot"]) + float(b["spin"]) * dt
		var n := _berg_nodes[i]
		n.position = Vector3((b["pos"] as Vector3).x, 0.0, (b["pos"] as Vector3).z)
		n.rotation.y = float(b["rot"])
	# Occasional calving or groaning from a berg (heard if close, logged if not).
	if _rng.randf() < dt / 900.0 and not bergs.is_empty():
		var b2: Dictionary = bergs[_rng.randi() % bergs.size()]
		ice_calved.emit(b2["pos"], float(b2["r"]) > 50.0)


## Ice within `radius` of p (horizontal), nearest first: [{berg, dist}].
func ice_near(p: Vector3, radius: float) -> Array:
	var out: Array = []
	for b in bergs:
		var d := Vector2(p.x - (b["pos"] as Vector3).x, p.z - (b["pos"] as Vector3).z).length() - float(b["r"]) * 1.3
		if d < radius:
			out.append({"berg": b, "dist": maxf(d, 0.0)})
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["dist"]) < float(c["dist"]))
	return out


## Test hull sample points against ice and seabed. Returns {} or
## {kind: "ice"/"seabed"/"land", normal: Vector3, depth: float, point: Vector3}.
func hull_collision(points: Array, hull_radius: float) -> Dictionary:
	for pt in points:
		var p: Vector3 = pt
		for b in bergs:
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
			return {"kind": "land" if sb < 3.0 else "seabed", "normal": Vector3.UP, "depth": -p.y + hull_radius * 0.8 - sb, "point": p}
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


func _build_seabed() -> void:
	var n := 180
	var size := HALF * 2.0
	var verts := PackedVector3Array()
	for j in n:
		for i in n:
			var x := -HALF + size * float(i) / float(n - 1)
			var z := -HALF + size * float(j) / float(n - 1)
			verts.append(Vector3(x, -seabed_depth(x, z) - 1.0, z))
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var st := SurfaceTool.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	st.create_from_arrays(arrays)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Seabed"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.1, 0.09)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_bergs() -> void:
	for b in bergs:
		var mi := MeshInstance3D.new()
		mi.mesh = _berg_mesh(b)
		mi.material_override = _ice_mat
		mi.position = Vector3((b["pos"] as Vector3).x, 0.0, (b["pos"] as Vector3).z)
		mi.rotation.y = float(b["rot"])
		add_child(mi)
		_berg_nodes.append(mi)


func _berg_mesh(b: Dictionary) -> ArrayMesh:
	var r := float(b["r"])
	var h := float(b["h"])
	var keel := float(b["keel"])
	var seed_v := float(b["seed"])
	var tabular: bool = b["tabular"]
	var f := func(u: float, v: float) -> Vector3:
		var a := v * TAU
		var wob := 1.0 + 0.16 * sin(3.0 * a + seed_v) + 0.1 * sin(5.0 * a + seed_v * 1.7) + 0.06 * sin(11.0 * a + seed_v * 0.3)
		var y: float
		var rad: float
		if u < 0.12:
			var t := u / 0.12
			y = h * (1.0 if tabular else (1.0 - 0.35 * t * t)) + (0.0 if tabular else 0.25 * h * (1.0 - t))
			rad = r * (0.85 if tabular else 0.75) * sin(t * PI * 0.5)
		elif u < 0.4:
			var t2 := (u - 0.12) / 0.28
			y = lerpf(h * (1.0 if tabular else 0.65), 0.0, t2)
			rad = r * lerpf(0.85 if tabular else 0.75, 1.0, t2) * (1.0 + 0.08 * sin(t2 * 9.0 + a * 2.0 + seed_v))
		else:
			var t3 := (u - 0.4) / 0.6
			y = -keel * t3
			rad = r * 1.3 * sqrt(maxf(0.0, 1.0 - t3 * t3)) * (1.0 + 0.12 * sin(t3 * 7.0 + a * 3.0 + seed_v))
		return Vector3(cos(a) * rad * wob, y, sin(a) * rad * wob)
	var uvf := func(u: float, v: float) -> Vector2: return Vector2(v * 8.0, u * 6.0)
	var mesh := ArrayMesh.new()
	ParamMesh.add_to(mesh, ParamMesh.surface(f, uvf, 36, 48), _ice_mat)
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
	advance(0.0)
