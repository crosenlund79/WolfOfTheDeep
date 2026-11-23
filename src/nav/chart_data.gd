class_name ChartData
extends RefCounted
## Hydrographic chart data built from the same Geography as the physical
## seabed, on worker threads: a tile pyramid of depth tints and land, depth
## contours (marching squares on the depth grid) and a stable set of
## historical soundings, dense where waters were surveyed often (coasts, old
## survey lines) and sparse in remote deep water.

const LEVELS := 9                 # tile pyramid 0..8 (600 km .. 2.3 km tiles)
const N := 65                     # depth samples per tile side (a tile is ~150 px on screen)
const PX := 128                   # tint image size
const CONTOURS := [0.0, 10.0, 20.0, 30.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0]
const CELL := 20000.0             # soundings spatial index

var geo: Geography
var night := false
var _tiles := {}                  # key -> {state, tex, lines}
var _done: Array = []
var _mutex := Mutex.new()
var _busy := 0
var _soundings := {}              # Vector2i cell -> PackedFloat32Array [x, z, depth, priority, ...]
var _soundings_ready := false
var _sound_task := -1
var _tasks := {}                  # WorkerThreadPool task id -> true (waited on when finished)
var _cancel := false


func _init(g: Geography) -> void:
	geo = g
	_sound_task = WorkerThreadPool.add_task(_make_soundings, false, "chart soundings")


static func tile_size(level: int) -> float:
	return Geography.REGION_HALF * 2.0 / float(1 << level)


static func key(level: int, i: int, j: int) -> String:
	return "%d_%d_%d" % [level, i, j]


## The tile if it is ready ({} otherwise); requests it if needed.
func tile(level: int, i: int, j: int) -> Dictionary:
	var k := key(level, i, j)
	if _tiles.has(k):
		var t: Dictionary = _tiles[k]
		return t if t["state"] == "ready" else {}
	if _cancel:
		return {}
	_tiles[k] = {"state": "pending"}
	_busy += 1
	var id := WorkerThreadPool.add_task(_build.bind(k, level, i, j, night), false, "chart tile")
	_tasks[id] = true
	return {}


## The tile if it is ready ({} otherwise) without requesting it.
func peek(level: int, i: int, j: int) -> Dictionary:
	var t: Dictionary = _tiles.get(key(level, i, j), {})
	return t if String(t.get("state", "")) == "ready" else {}


## Stop background work and wait for running tasks (scene change or quit).
func shutdown() -> void:
	_cancel = true
	for id in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int(id))
	_tasks.clear()
	if _sound_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_sound_task)
		_sound_task = -1


func busy() -> bool:
	return _busy > 0 or not _soundings_ready


## Rebuild everything (palette change).
func set_night(on: bool) -> void:
	if on == night:
		return
	night = on
	_tiles.clear()


## Main thread: turn finished work into textures.
func poll() -> bool:
	for id in _tasks.keys():
		if WorkerThreadPool.is_task_completed(int(id)):
			WorkerThreadPool.wait_for_task_completion(int(id))
			_tasks.erase(id)
	if _sound_task >= 0 and WorkerThreadPool.is_task_completed(_sound_task):
		WorkerThreadPool.wait_for_task_completion(_sound_task)
		_sound_task = -1
	_mutex.lock()
	var ready := _done.duplicate()
	_done.clear()
	_mutex.unlock()
	for r in ready:
		_busy -= 1
		if bool(r["night"]) != night:
			_tiles.erase(r["key"])
			continue
		r["tex"] = ImageTexture.create_from_image(r["img"])
		r.erase("img")
		r["state"] = "ready"
		_tiles[r["key"]] = r
	if _tiles.size() > 420:
		# Keep the cache bounded: drop the oldest detailed tiles; the coarse
		# levels (fallbacks everywhere) stay.
		var dropped := 0
		for k in _tiles.keys():
			var t: Dictionary = _tiles[k]
			if t["state"] == "ready" and int(t["level"]) >= 4:
				_tiles.erase(k)
				dropped += 1
				if dropped >= 120:
					break
	return not ready.is_empty()


static func tint(d: float, night_mode: bool) -> Color:
	if night_mode:
		if d < 0.0:
			return Color(0.16, 0.13, 0.09)
		if d < 10.0:
			return Color(0.05, 0.13, 0.22)
		if d < 20.0:
			return Color(0.04, 0.1, 0.18)
		if d < 50.0:
			return Color(0.03, 0.075, 0.13)
		if d < 200.0:
			return Color(0.02, 0.05, 0.085)
		return Color(0.01, 0.025, 0.045).lerp(Color(0.0, 0.01, 0.025), clampf((d - 200.0) / 2000.0, 0.0, 1.0))
	if d < 0.0:
		return Color(0.93, 0.86, 0.66)
	if d < 10.0:
		return Color(0.52, 0.72, 0.88)
	if d < 20.0:
		return Color(0.64, 0.8, 0.93)
	if d < 50.0:
		return Color(0.78, 0.88, 0.96)
	if d < 200.0:
		return Color(0.9, 0.95, 0.985)
	return Color(0.985, 0.99, 1.0).lerp(Color(0.9, 0.93, 0.97), clampf((d - 600.0) / 2000.0, 0.0, 1.0))


func _build(k: String, level: int, i: int, j: int, night_mode: bool) -> void:
	var size := tile_size(level)
	var origin := Vector2(-Geography.REGION_HALF + float(i) * size, -Geography.REGION_HALF + float(j) * size)
	var step := size / float(N - 1)
	var g := PackedFloat32Array()
	g.resize(N * N)
	var lo := INF
	var hi := -INF
	for y in N:
		if _cancel:
			return
		for x in N:
			var d := geo.depth(origin.x + float(x) * step, origin.y + float(y) * step)
			g[y * N + x] = d
			lo = minf(lo, d)
			hi = maxf(hi, d)
	var img := Image.create(PX, PX, false, Image.FORMAT_RGB8)
	for y in PX:
		var gy := float(y) / float(PX - 1) * float(N - 1)
		var y0 := mini(int(gy), N - 2)
		var fy := gy - float(y0)
		for x in PX:
			var gx := float(x) / float(PX - 1) * float(N - 1)
			var x0 := mini(int(gx), N - 2)
			var fx := gx - float(x0)
			var a := lerpf(g[y0 * N + x0], g[y0 * N + x0 + 1], fx)
			var b := lerpf(g[(y0 + 1) * N + x0], g[(y0 + 1) * N + x0 + 1], fx)
			img.set_pixel(x, y, tint(lerpf(a, b, fy), night_mode))
	var lines := {}
	for c in CONTOURS:
		var cv := float(c)
		if cv < lo or cv > hi:
			continue
		if _cancel:
			return
		var seg := _march(g, origin, step, cv)
		if not seg.is_empty():
			lines[cv] = seg
	var r := {"key": k, "state": "built", "img": img, "lines": lines, "level": level, "origin": origin, "size": size,
		"night": night_mode, "lo": lo, "hi": hi}
	_mutex.lock()
	_done.append(r)
	_mutex.unlock()


## Marching squares: segments (pairs of world points) where depth crosses `lv`.
static func _march(g: PackedFloat32Array, origin: Vector2, step: float, lv: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for y in N - 1:
		for x in N - 1:
			var a := g[y * N + x] - lv
			var b := g[y * N + x + 1] - lv
			var c := g[(y + 1) * N + x + 1] - lv
			var d := g[(y + 1) * N + x] - lv
			var idx := (1 if a > 0.0 else 0) | (2 if b > 0.0 else 0) | (4 if c > 0.0 else 0) | (8 if d > 0.0 else 0)
			if idx == 0 or idx == 15:
				continue
			var p0 := origin + Vector2(x, y) * step
			var e := []   # edge crossing points: top, right, bottom, left
			var top := p0 + Vector2(a / (a - b), 0.0) * step if (a > 0.0) != (b > 0.0) else Vector2.INF
			var right := p0 + Vector2(1.0, b / (b - c)) * step if (b > 0.0) != (c > 0.0) else Vector2.INF
			var bottom := p0 + Vector2(d / (d - c), 1.0) * step if (d > 0.0) != (c > 0.0) else Vector2.INF
			var left := p0 + Vector2(0.0, a / (a - d)) * step if (a > 0.0) != (d > 0.0) else Vector2.INF
			for p in [top, right, bottom, left]:
				if p != Vector2.INF:
					e.append(p)
			if e.size() == 2:
				out.append(e[0])
				out.append(e[1])
			elif e.size() == 4:
				out.append(e[0])
				out.append(e[1])
				out.append(e[2])
				out.append(e[3])
	return out


# --- soundings --------------------------------------------------------------------

## Historical soundings: generated once with a fixed seed, so the same chart
## always shows the same numbers. Each has a priority used for thinning.
func _make_soundings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18960
	var pts := {}
	var add := func(x: float, z: float, pri: float) -> void:
		if not geo.in_region(x, z):
			return
		var d := geo.depth(x, z)
		if d <= 0.0:
			return
		# Older surveys round coarsely; shallow water to the decimetre.
		var v := snappedf(d, 0.1) if d < 31.0 else float(int(d))
		var cell := Vector2i(int(floorf(x / CELL)), int(floorf(z / CELL)))
		if not pts.has(cell):
			pts[cell] = PackedFloat32Array()
		var arr: PackedFloat32Array = pts[cell]
		arr.append_array([x, z, v, pri])
		pts[cell] = arr
	# Along historical survey lines: a sounding every 1.5-4 km.
	for t in geo.survey_tracks:
		for i in (t as Array).size() - 1:
			var a: Vector2 = (t[i] as Vector2) * 1000.0
			var b: Vector2 = (t[i + 1] as Vector2) * 1000.0
			var l := a.distance_to(b)
			var s := 0.0
			while s < l and not _cancel:
				var p := a.lerp(b, s / l) + Vector2(rng.randf_range(-350.0, 350.0), rng.randf_range(-350.0, 350.0))
				add.call(p.x, p.y, rng.randf())
				s += rng.randf_range(1500.0, 4000.0)
	# Coastal and bank surveys: dense near land and in shoal water.
	for i in 26000:
		if _cancel:
			return
		var p2 := Vector2(rng.randf_range(-Geography.REGION_HALF, Geography.REGION_HALF), rng.randf_range(-Geography.REGION_HALF, Geography.REGION_HALF))
		var cd := geo.coast_distance(p2.x, p2.y)
		var keep := exp(-maxf(cd, 0.0) / 14000.0)
		if rng.randf() < keep:
			add.call(p2.x, p2.y, rng.randf())
	# Patrol area of long standing interest: well surveyed.
	for i in 5000:
		var p3 := Vector2(rng.randf_range(-40000.0, 40000.0), rng.randf_range(-40000.0, 40000.0))
		add.call(p3.x, p3.y, rng.randf())
	# Remote water: sparse, scattered spot soundings.
	for i in 2600:
		add.call(rng.randf_range(-Geography.REGION_HALF, Geography.REGION_HALF), rng.randf_range(-Geography.REGION_HALF, Geography.REGION_HALF), rng.randf())
	_mutex.lock()
	_soundings = pts
	_soundings_ready = true
	_mutex.unlock()


## Soundings [x, z, depth, priority] in a world rectangle with priority above
## `min_pri` (at most `limit`).
func soundings_in(rect: Rect2, min_pri: float, limit: int) -> Array:
	var out: Array = []
	if not _soundings_ready:
		return out
	var c0 := Vector2i(int(floorf(rect.position.x / CELL)), int(floorf(rect.position.y / CELL)))
	var c1 := Vector2i(int(floorf(rect.end.x / CELL)), int(floorf(rect.end.y / CELL)))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var arr: PackedFloat32Array = _soundings.get(Vector2i(cx, cy), PackedFloat32Array())
			var k := 0
			while k < arr.size():
				if arr[k + 3] >= min_pri and rect.has_point(Vector2(arr[k], arr[k + 1])):
					out.append([arr[k], arr[k + 1], arr[k + 2], arr[k + 3]])
					if out.size() >= limit:
						return out
				k += 4
	return out


func sounding_count() -> int:
	var n := 0
	for arr in _soundings.values():
		n += (arr as PackedFloat32Array).size() / 4
	return n
