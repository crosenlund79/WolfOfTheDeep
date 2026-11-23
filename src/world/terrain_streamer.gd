class_name TerrainStreamer
extends Node3D
## Streams terrain around the point of view so the whole region never sits in
## memory at once: seabed tiles nearby (100 m grid), detailed land tiles near
## islands (80 m) and coarse distant land (500 m) out to the horizon. Tiles
## are computed on worker threads from the same Geography the chart uses.

const SEA_TILE := 4000.0
const SEA_N := 41
const SEA_RING := 1          # 3 × 3 tiles
const NEAR_TILE := 8000.0
const NEAR_N := 101
const NEAR_RING := 1
const FAR_TILE := 32000.0
const FAR_N := 65
const FAR_RANGE := 110000.0
const RAVNOYA_BOX := Rect2(-3500.0, -14500.0, 16000.0, 18000.0)   # the hand-built island mesh

var geo: Geography
var focus_pos := Vector3.ZERO
var seabed_material: Material
var land_material: ShaderMaterial
var far_material: ShaderMaterial

var _tiles := {}             # key String -> MeshInstance3D (or null while building)
var _done: Array = []
var _mutex := Mutex.new()
var _last_center := Vector2(INF, INF)
var _busy := 0
var _tasks := {}             # WorkerThreadPool task id -> true
var _cancel := false


func _ready() -> void:
	far_material = land_material.duplicate() as ShaderMaterial
	far_material.set_shader_parameter("use_hole", 1.0)


func _exit_tree() -> void:
	_cancel = true
	for id in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int(id))
	_tasks.clear()


func update_focus(p: Vector3) -> void:
	focus_pos = p


func _process(_delta: float) -> void:
	_collect()
	var c := Vector2(focus_pos.x, focus_pos.z)
	if c.distance_to(_last_center) < 500.0:
		return
	_last_center = c
	var want := {}
	_want_grid(want, "s", c, SEA_TILE, SEA_RING)
	_want_grid(want, "n", c, NEAR_TILE, NEAR_RING)
	var far_ring := int(ceil(FAR_RANGE / FAR_TILE))
	_want_grid(want, "f", c, FAR_TILE, far_ring)
	# Far tiles are only worth building where there is land.
	for k in want.keys():
		if String(k).begins_with("f") or String(k).begins_with("n"):
			var info: Array = want[k]
			if not _has_land(info[0], info[1]):
				want.erase(k)
	for k in want.keys():
		if not _tiles.has(k):
			_tiles[k] = null
			var info2: Array = want[k]
			_busy += 1
			# The ground around the point of view comes first (high priority).
			var id := WorkerThreadPool.add_task(_build.bind(String(k), info2[0], info2[1], info2[2], info2[3]), true, "terrain tile")
			_tasks[id] = true
	for k in _tiles.keys():
		if not want.has(k) and _tiles[k] != null:
			(_tiles[k] as Node).queue_free()
			_tiles.erase(k)
	# Distant land leaves a hole where the detailed near tiles are.
	var h0 := Vector2(floorf(c.x / NEAR_TILE) - NEAR_RING, floorf(c.y / NEAR_TILE) - NEAR_RING) * NEAR_TILE
	var h1 := h0 + Vector2.ONE * NEAR_TILE * (NEAR_RING * 2 + 1)
	far_material.set_shader_parameter("hole", Vector4(h0.x, h0.y, h1.x, h1.y))


func _want_grid(want: Dictionary, prefix: String, c: Vector2, size: float, ring: int) -> void:
	var ci := Vector2i(int(floorf(c.x / size)), int(floorf(c.y / size)))
	var n := SEA_N if prefix == "s" else (NEAR_N if prefix == "n" else FAR_N)
	for j in range(-ring, ring + 1):
		for i in range(-ring, ring + 1):
			var t := ci + Vector2i(i, j)
			var origin := Vector2(t) * size
			if prefix == "f" and (origin + Vector2.ONE * size * 0.5).distance_to(c) > FAR_RANGE + size:
				continue
			want["%s%d_%d" % [prefix, t.x, t.y]] = [origin, size, n, prefix]


func _has_land(origin: Vector2, size: float) -> bool:
	var rect := Rect2(origin, Vector2.ONE * size)
	for isl in geo.islands:
		var c: Vector2 = isl["c"]
		var b := float(isl["bound"])
		if rect.grow(b).has_point(c):
			return true
	# Ravnøya is drawn by its own mesh.
	return false


func _build(key: String, origin: Vector2, size: float, n: int, kind: String) -> void:
	var step := size / float(n - 1)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var any_land := false
	for j in n:
		if _cancel:
			return
		for i in n:
			var x := origin.x + float(i) * step
			var z := origin.y + float(j) * step
			var h: float
			if kind == "s":
				var d := geo.depth(x, z)
				h = -d if d > 0.0 else -1.5
			else:
				h = geo.height(x, z)
				if RAVNOYA_BOX.has_point(Vector2(x, z)):
					h = minf(h, -30.0)
				if h > 0.0:
					any_land = true
			hs[j * n + i] = h
	var result := {"key": key, "origin": origin, "size": size, "n": n, "kind": kind, "h": hs, "land": any_land}
	_mutex.lock()
	_done.append(result)
	_mutex.unlock()


func _collect() -> void:
	for id in _tasks.keys():
		if WorkerThreadPool.is_task_completed(int(id)):
			WorkerThreadPool.wait_for_task_completion(int(id))
			_tasks.erase(id)
	_mutex.lock()
	var ready := _done.duplicate()
	_done.clear()
	_mutex.unlock()
	for r in ready:
		_busy -= 1
		var key := String(r["key"])
		if not _tiles.has(key):
			continue
		if r["kind"] != "s" and not bool(r["land"]):
			_tiles[key] = Node3D.new()
			add_child(_tiles[key])
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh(r)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if r["kind"] != "n" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.material_override = seabed_material if r["kind"] == "s" else (land_material if r["kind"] == "n" else far_material)
		add_child(mi)
		_tiles[key] = mi


func _mesh(r: Dictionary) -> ArrayMesh:
	var n := int(r["n"])
	var origin: Vector2 = r["origin"]
	var step := float(r["size"]) / float(n - 1)
	var hs: PackedFloat32Array = r["h"]
	var land := String(r["kind"]) != "s"
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for j in n:
		for i in n:
			var h := hs[j * n + i]
			verts[j * n + i] = Vector3(origin.x + i * step, h, origin.y + j * step)
			var hl := hs[j * n + maxi(i - 1, 0)]
			var hr := hs[j * n + mini(i + 1, n - 1)]
			var hu := hs[maxi(j - 1, 0) * n + i]
			var hd := hs[mini(j + 1, n - 1) * n + i]
			norms[j * n + i] = Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			# Land tiles keep only triangles that reach above the sea.
			if land and maxf(maxf(hs[a], hs[a + 1]), maxf(hs[a + n], hs[a + n + 1])) < -2.0:
				continue
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if not idx.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## True when nothing is being built (useful for tests and captures).
func idle() -> bool:
	return _busy <= 0
