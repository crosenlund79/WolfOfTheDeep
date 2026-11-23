class_name Geography
extends RefCounted
## The operating region: about 600 × 600 km of fictional but coherent Arctic
## sea around the patrol area. One continuous seabed (shelves, banks, troughs,
## a ridge, a continental slope into a deep basin), islands with coasts and
## shelves, charted hazards, ice limits, and the names and survey history the
## nautical chart uses. The physical seabed and the chart both read from here,
## so they always agree. x = east, -z = north, metres; origin near Ravnøya.
## Pure functions of position (safe to call from worker threads).

const REGION_HALF := 300000.0
const LOCAL_R0 := 26000.0    # inside: the original patrol-area bathymetry, unchanged
const LOCAL_R1 := 40000.0    # blend ring into the regional seabed

# Original patrol-area features (kept exactly).
const ISLAND_C := Vector2(4500.0, -5500.0)
const ISLAND_R := 3800.0
const BANK_C := Vector2(-7000.0, -2500.0)
const ROCK_C := Vector2(1300.0, -1150.0)

var islands: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var names: Array[Dictionary] = []
var places: Array[Dictionary] = []   # charted harbours, stations and anchorages (public)
var survey_tracks: Array = []
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _rnoise := FastNoiseLite.new()
var _cnoise := FastNoiseLite.new()
var _hnoise := FastNoiseLite.new()
var _snoise := FastNoiseLite.new()

const TROUGHS := [
	# name, points (km), half-width (km), extra depth (m)
	["RAVNRENNA", [Vector2(-300, 125), Vector2(-160, 95), Vector2(-45, 62), Vector2(80, 44), Vector2(210, 78), Vector2(300, 70)], 34.0, 170.0],
	["NORDRENNA", [Vector2(-120, -40), Vector2(-60, -24), Vector2(0, -20), Vector2(60, -24), Vector2(150, -62), Vector2(230, -125)], 13.0, 120.0],
]
const BANKS := [
	# name, centre (km), radius (km), crest depth (m)
	["SENTRALBANKEN", Vector2(115, -85), 48.0, 52.0],
	["HØGØYBANKEN", Vector2(-158, 182), 66.0, 36.0],
	["SØRBANKEN", Vector2(185, 165), 52.0, 68.0],
	["SVANEBANKEN", Vector2(-30, 205), 34.0, 85.0],
]
const RIDGE := [Vector2(30, 150), Vector2(85, 100), Vector2(122, 58), Vector2(150, 5), Vector2(170, -35)]
const SEAMOUNT := Vector2(122, 58)    # HVALTOPPEN, crest 38 m


func _init() -> void:
	# The same noise as the original patrol area (keeps its seabed identical).
	_noise.seed = 76
	_noise.frequency = 0.00035
	_noise.fractal_octaves = 5
	_noise2.seed = 11
	_noise2.frequency = 0.004
	_noise2.fractal_octaves = 3
	_rnoise.seed = 1905
	_rnoise.frequency = 0.000018
	_rnoise.fractal_octaves = 5
	_cnoise.seed = 4242
	_cnoise.frequency = 1.0
	_cnoise.fractal_octaves = 4
	_snoise.seed = 313
	_snoise.frequency = 0.00022
	_snoise.fractal_octaves = 4
	_hnoise.seed = 990
	_hnoise.frequency = 0.00012
	_hnoise.fractal_octaves = 5
	_build_islands()
	_build_hazards()
	_build_names()
	_build_places()
	_build_tracks()


# --- islands -----------------------------------------------------------------------

func _island(name_v: String, c_km: Vector2, r_km: float, peak: float, seed_v: int, shelf_km: float, fjords: int, lobes: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var fj: Array = []
	for i in fjords:
		fj.append([rng.randf() * TAU, rng.randf_range(0.04, 0.09), rng.randf_range(0.35, 0.7), rng.randf() * TAU])
	var parts: Array = []
	if lobes.is_empty():
		parts.append([c_km * 1000.0, r_km * 1000.0])
	else:
		for l in lobes:
			parts.append([(l[0] as Vector2) * 1000.0, float(l[1]) * 1000.0])
	var bound := 0.0
	for p in parts:
		bound = maxf(bound, ((p[0] as Vector2) - c_km * 1000.0).length() + float(p[1]) * 1.45)
	# Fjords: channels cut from the open sea towards the heart of the island.
	var fjd: Array = []
	for f in fj:
		var dir := Vector2(cos(float(f[0])), sin(float(f[0])))
		var head := c_km * 1000.0 + dir * r_km * 1000.0 * (1.0 - float(f[2])) + Vector2(-dir.y, dir.x) * sin(float(f[3])) * r_km * 350.0
		fjd.append({"a": c_km * 1000.0 + dir * (bound + 1000.0), "b": head,
			"w": float(f[1]) * 0.5 * r_km * 1000.0, "ph": float(f[3]), "deep": 120.0 + 180.0 * fposmod(float(f[3]) * 7.0, 1.0)})
	islands.append({"name": name_v, "c": c_km * 1000.0, "r": r_km * 1000.0, "peak": peak, "seed": seed_v,
		"shelf": shelf_km * 1000.0, "fjords": fjd, "parts": parts, "bound": bound,
		"harm": [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]})


func _build_islands() -> void:
	# The large island to the north-west: several lobes, fjords, glaciated highland.
	_island("STORØYA", Vector2(-200, -205), 70.0, 980.0, 11, 24.0, 7,
		[[Vector2(-212, -196), 68.0], [Vector2(-150, -238), 50.0], [Vector2(-262, -128), 40.0], [Vector2(-128, -178), 28.0], [Vector2(-268, -262), 36.0]])
	_island("HALVMÅNEØYA", Vector2(-96, -118), 7.5, 210.0, 23, 7.0, 1)
	_island("KVITØYA", Vector2(205, -228), 17.0, 380.0, 31, 11.0, 1)
	_island("SVANØYA", Vector2(148, -262), 9.0, 260.0, 37, 8.0, 0)
	_island("HØGØYA", Vector2(-160, 176), 8.5, 520.0, 41, 5.0, 0)
	_island("MÅKESKJÆR", Vector2(62, 96), 0.35, 18.0, 53, 1.6, 0)
	# Tusenøyane: a scatter of islets and skerries off Storøya's south-east coast.
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for i in 13:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 24.0
		_island("" if i > 0 else "TUSENØYANE", Vector2(-72, -150) + Vector2(cos(a), sin(a)) * d, rng.randf_range(0.5, 2.4), rng.randf_range(20.0, 130.0), 100 + i, rng.randf_range(1.5, 4.0), 0)


## Coast radius of one island part at angle a.
func _part_radius(isl: Dictionary, part_r: float, a: float) -> float:
	var h: Array = isl["harm"]
	var r := part_r * (1.0 + 0.16 * sin(2.0 * a + float(h[0])) + 0.09 * sin(3.0 * a + float(h[1])) + 0.05 * sin(5.0 * a + float(h[2])))
	# Ragged coast at many scales (noise sampled around the circle; its reach
	# is limited in metres so large islands don't grow a comb of headlands).
	var k := clampf(part_r / 2500.0, 2.0, 40.0)
	r += _cnoise.get_noise_2d(cos(a) * k + float(isl["seed"]) * 9.1, sin(a) * k) * minf(part_r * 0.05, 700.0)
	return r


## Approximate signed distance to an island's coast (negative ashore).
func _island_sd(isl: Dictionary, x: float, z: float) -> float:
	var best := INF
	for p in isl["parts"]:
		var c: Vector2 = p[0]
		var dx := x - c.x
		var dz := z - c.y
		var dist := sqrt(dx * dx + dz * dz)
		best = minf(best, dist - _part_radius(isl, float(p[1]), atan2(dz, dx)))
	# Headlands and bays that don't point at the island's centre.
	var r0 := float(isl["r"])
	best += _snoise.get_noise_2d(x, z) * minf(r0 * 0.06, 1800.0)
	if not (isl["fjords"] as Array).is_empty():
		best = maxf(best, -_fjord(isl, x, z).x)
	return best


## The fjords of an island at a point: x = distance outside the nearest channel
## (negative inside it), y = the channel's water depth there (a glacial trough,
## deepest along its axis). Channels run in from the open sea, wide at the mouth,
## narrowing and winding towards their heads.
func _fjord(isl: Dictionary, x: float, z: float) -> Vector2:
	var pt := Vector2(x, z)
	var r0 := float(isl["r"])
	var rough := 1.0 + 0.3 * _snoise.get_noise_2d(x * 4.0, z * 4.0)
	var best := Vector2(INF, 0.0)
	for f in isl["fjords"]:
		var a: Vector2 = f["a"]
		var ab: Vector2 = (f["b"] as Vector2) - a
		var l := ab.length()
		var t := clampf((pt - a).dot(ab) / (l * l), 0.0, 1.0)
		var wig := sin(t * l / 14000.0 + float(f["ph"])) * minf(3500.0, r0 * 0.05)
		var q := a + ab * t + Vector2(-ab.y, ab.x) / l * wig
		var from_head := (1.0 - t) * l
		var half := float(f["w"]) * (0.45 + 1.4 * clampf(from_head / (r0 * 0.8), 0.0, 1.0)) * rough
		var dq := pt.distance_to(q)
		if dq - half < best.x:
			best = Vector2(dq - half, clampf(1.0 - pow(dq / half, 2.0), 0.0, 1.0) * float(f["deep"]))
	return best


## Ravnøya, exactly as the original patrol area defined it.
func ravnoya_radius(theta: float) -> float:
	var r := ISLAND_R * (1.0 + 0.25 * sin(2.0 * theta + 0.5) + 0.15 * sin(3.0 * theta + 1.7) + 0.08 * sin(7.0 * theta))
	var dt := wrapf(theta - 0.15, -PI, PI)
	r *= 1.0 - 0.55 * exp(-pow(dt / 0.07, 2.0))
	return r


func _ravnoya_sd(x: float, z: float) -> float:
	var d := Vector2(x, z) - ISLAND_C
	return d.length() - ravnoya_radius(atan2(d.y, d.x))


## Signed distance to the nearest coast (negative on land); approximate.
func coast_distance(x: float, z: float) -> float:
	var best := _ravnoya_sd(x, z)
	for isl in islands:
		var c: Vector2 = isl["c"]
		var dx := x - c.x
		var dz := z - c.y
		var bound := float(isl["bound"])
		var far := sqrt(dx * dx + dz * dz) - bound
		if far > best:
			continue
		best = minf(best, _island_sd(isl, x, z))
	return best


## The island at a point (or {}), for terrain heights and names.
func island_at(x: float, z: float) -> Dictionary:
	for isl in islands:
		var c: Vector2 = isl["c"]
		if Vector2(x - c.x, z - c.y).length() > float(isl["bound"]):
			continue
		if _island_sd(isl, x, z) < 0.0:
			return isl
	return {}


## Ground height above the sea (positive) or seabed (negative depth).
func height(x: float, z: float) -> float:
	var rs := _ravnoya_sd(x, z)
	if rs <= 0.0:
		var inland := -rs
		var cliff := smoothstep(0.0, 160.0, inland) * 55.0
		var massif := pow(smoothstep(0.0, 2800.0, inland), 0.9) * 620.0 * (0.62 + 0.38 * (_noise.get_noise_2d(x, z) + 1.0) * 0.5)
		return cliff + massif + _noise2.get_noise_2d(x, z) * 18.0 * smoothstep(0.0, 400.0, inland)
	var isl := island_at(x, z)
	if not isl.is_empty():
		var inland2 := -_island_sd(isl, x, z)
		var scale_r := float(isl["r"])
		var peak := float(isl["peak"])
		var cliff2 := smoothstep(0.0, 120.0 + scale_r * 0.01, inland2) * minf(40.0, peak * 0.4)
		var rise := pow(smoothstep(0.0, scale_r * 0.55, inland2), 0.85) * peak * (0.55 + 0.45 * (_hnoise.get_noise_2d(x, z) + 1.0) * 0.5)
		return cliff2 + rise + _noise2.get_noise_2d(x, z) * minf(25.0, peak * 0.05)
	return -depth(x, z)


# --- seabed ------------------------------------------------------------------------

## Water depth in metres; negative on land. The single source for collision,
## sonar, the terrain mesh and the chart.
func depth(x: float, z: float) -> float:
	var q := maxf(absf(x), absf(z))
	if q <= LOCAL_R0:
		return _local_depth(x, z)
	var reg := _regional_depth(x, z)
	if q >= LOCAL_R1:
		return reg
	var loc := _local_depth(x, z)
	if reg < 0.0 or loc < 0.0:
		return reg if reg < 0.0 else loc
	return lerpf(loc, reg, smoothstep(LOCAL_R0, LOCAL_R1, q))


## The original patrol area's seabed (kept bit-for-bit).
func _local_depth(x: float, z: float) -> float:
	var sd := _ravnoya_sd(x, z)
	if sd <= 0.0:
		return -1.0
	var d := 290.0 + _noise.get_noise_2d(x * 0.6 + 900.0, z * 0.6) * 70.0
	d += smoothstep(-12000.0, -22000.0, z) * 120.0
	d = lerpf(d, 12.0, pow(1.0 - smoothstep(0.0, 5200.0, sd), 1.6))
	var bd := Vector2(x, z).distance_to(BANK_C)
	d = minf(d, 38.0 + 32.0 * pow(bd / 3000.0, 2.0))
	var rd := Vector2(x, z).distance_to(ROCK_C)
	d = minf(d, 6.0 + rd * 0.09)
	return maxf(d, 2.0)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _poly_dist(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, _seg_dist(p, (pts[i] as Vector2) * 1000.0, (pts[i + 1] as Vector2) * 1000.0))
	return best


func _regional_depth(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := 330.0 + _rnoise.get_noise_2d(x, z) * 75.0 + _noise.get_noise_2d(x * 0.25, z * 0.25) * 18.0
	for t in TROUGHS:
		var td := _poly_dist(p, t[1])
		d += float(t[3]) * exp(-pow(td / (float(t[2]) * 1000.0), 2.0))
	# Continental slope down to the deep basin in the south-west.
	var slope := smoothstep(-228000.0, -292000.0, x + _rnoise.get_noise_2d(z, x) * 9000.0) * (1.0 - smoothstep(-70000.0, -140000.0, z))
	slope = maxf(slope, smoothstep(250000.0, 296000.0, z) * smoothstep(-120000.0, -260000.0, x))
	d += slope * 2350.0
	# Banks.
	for b in BANKS:
		var bc: Vector2 = (b[1] as Vector2) * 1000.0
		var bd := p.distance_to(bc) / (float(b[2]) * 1000.0)
		if bd < 1.3:
			var crest := float(b[3]) + _rnoise.get_noise_2d(x * 3.0, z * 3.0) * 10.0
			d = lerpf(crest, d, pow(smoothstep(0.0, 1.0, bd), 0.75)) if d > crest else d
	# Hvalryggen: a ridge rising out of the deep water, with a seamount.
	var rdist := _poly_dist(p, RIDGE)
	d -= 175.0 * exp(-pow(rdist / 9000.0, 2.0)) * (0.8 + 0.2 * _cnoise.get_noise_2d(x * 0.0002, z * 0.0002))
	d = minf(d, 38.0 + p.distance_to(SEAMOUNT * 1000.0) * 0.045)
	# Charted rocks and shoals are physical.
	for h in hazards:
		if String(h["kind"]) == "rock" or String(h["kind"]) == "shoal":
			var hp: Vector2 = h["pos"]
			var hd := p.distance_to(hp)
			if hd < 2500.0:
				d = minf(d, float(h["depth"]) + hd * float(h.get("slope", 0.06)))
	# Islands and their shelves.
	for isl in islands:
		var c: Vector2 = isl["c"]
		var reach := float(isl["bound"]) + float(isl["shelf"])
		if absf(x - c.x) > reach or absf(z - c.y) > reach:
			continue
		var sd := _island_sd(isl, x, z)
		if sd <= 0.0:
			return -1.0
		var shelf := float(isl["shelf"])
		if sd < shelf:
			d = lerpf(d, 10.0, pow(1.0 - smoothstep(0.0, shelf, sd), 1.7))
			# Fjord basins and the troughs they cut across the shelf.
			if not (isl["fjords"] as Array).is_empty():
				d = maxf(d, _fjord(isl, x, z).y)
	return maxf(d, 2.0)


# --- ice -------------------------------------------------------------------------------

## Southern limit of the pack ice (z, metres) at x. Matches the original area.
func ice_edge_z(x: float) -> float:
	var z := -17500.0 + 1800.0 * sin(x / 7000.0) + 600.0 * sin(x / 2300.0 + 1.0)
	var west := smoothstep(-30000.0, -300000.0, x)
	var east := smoothstep(30000.0, 300000.0, x)
	z -= 95000.0 * pow(west, 1.15)
	z -= 45000.0 * east - 22000.0 * sin((x - 30000.0) / 85000.0) * smoothstep(30000.0, 90000.0, x)
	z += 9000.0 * sin(x / 41000.0 + 0.7) * (west + east)
	return z


## Ice cover 0..1 (0 open water, 1 close pack).
func ice_cover(x: float, z: float) -> float:
	var into := ice_edge_z(x) - z
	return clampf(into / 9000.0, 0.0, 1.0)


# --- hazards, names, survey history -----------------------------------------------

func _build_hazards() -> void:
	hazards = [
		{"pos": ROCK_C, "kind": "rock", "depth": 6.0, "name": "", "slope": 0.09},
		{"pos": Vector2(62600, 95400), "kind": "rock", "depth": 2.0, "name": ""},
		{"pos": Vector2(61200, 97100), "kind": "rock", "depth": 4.5, "name": ""},
		{"pos": SEAMOUNT * 1000.0, "kind": "shoal", "depth": 38.0, "name": "HVALTOPPEN", "slope": 0.045},
		{"pos": Vector2(-64000, -139000), "kind": "rock", "depth": 3.0, "name": ""},
		{"pos": Vector2(-81000, -158000), "kind": "rock", "depth": 1.5, "name": ""},
		{"pos": Vector2(-58000, -162000), "kind": "rock", "depth": 7.0, "name": ""},
		{"pos": Vector2(-150500, 168000), "kind": "rock", "depth": 5.0, "name": ""},
		{"pos": Vector2(196000, -214000), "kind": "rock", "depth": 6.0, "name": ""},
		{"pos": Vector2(-39000, 31000), "kind": "wreck", "depth": 212.0, "name": "Wk"},
		{"pos": Vector2(88000, -12000), "kind": "wreck", "depth": 268.0, "name": "Wk"},
		{"pos": Vector2(-120000, 120000), "kind": "wreck", "depth": 41.0, "name": "Wk"},
		{"pos": Vector2(150000, 140000), "kind": "wreck", "depth": 74.0, "name": "Wk"},
		{"pos": Vector2(20000, -60000), "kind": "obstruction", "depth": 180.0, "name": "Obstn"},
	]


func _build_names() -> void:
	# text, position (km), kind, shown between these chart scales (metres per pixel)
	var n := [
		["STORØYA", Vector2(-205, -200), "island", 120.0, 9999.0],
		["HALVMÅNEØYA", Vector2(-96, -128), "island", 20.0, 400.0],
		["TUSENØYANE", Vector2(-72, -164), "island", 25.0, 600.0],
		["KVITØYA", Vector2(205, -250), "island", 30.0, 900.0],
		["SVANØYA", Vector2(148, -276), "island", 25.0, 900.0],
		["HØGØYA", Vector2(-160, 190), "island", 18.0, 900.0],
		["MÅKESKJÆR", Vector2(62, 99), "island", 4.0, 160.0],
		["RAVNØYA", Vector2(4.5, -5.5), "island", 2.0, 300.0],
		["RAVNRENNA", Vector2(-60, 70), "trough", 120.0, 9999.0],
		["NORDRENNA", Vector2(110, -48), "trough", 80.0, 900.0],
		["SENTRALBANKEN", Vector2(115, -85), "bank", 80.0, 9999.0],
		["HØGØYBANKEN", Vector2(-150, 215), "bank", 80.0, 9999.0],
		["SØRBANKEN", Vector2(185, 165), "bank", 80.0, 9999.0],
		["SVANEBANKEN", Vector2(-30, 205), "bank", 60.0, 900.0],
		["HVALRYGGEN", Vector2(95, 95), "ridge", 60.0, 900.0],
		["HVALTOPPEN 38", Vector2(122, 60), "shoal", 15.0, 300.0],
		["DJUPBASSENGET", Vector2(-275, 220), "basin", 150.0, 9999.0],
		["VESTSKRÅNINGEN", Vector2(-262, 40), "slope", 100.0, 9999.0],
		["KESTREL BANK 38", Vector2(-7, -2.5), "bank", 2.0, 120.0],
		["RAVNSUNDET", Vector2(-130, -95), "strait", 40.0, 600.0],
	]
	# Shown while the chart scale (metres per pixel) is between min_mpp and max_mpp.
	for e in n:
		names.append({"text": e[0], "pos": (e[1] as Vector2) * 1000.0, "kind": e[2], "min_mpp": float(e[3]) * 0.12, "max_mpp": e[4]})


## Charted harbours, stations and anchorages: what any chart of the region
## shows. Each sits on its island's coast, found by walking out from the
## island's centre along a bearing until the water starts.
func _build_places() -> void:
	var list := [
		# text, kind, island, bearing from its centre (deg, 0 = north), note
		["LONGHAMN", "harbour", "STORØYA", 135.0, "Settlement and fishing harbour. Pilotage advised."],
		["STORØYA RADIO", "station", "STORØYA", 200.0, "Coast radio and meteorological station."],
		["HALVMÅNEØYA ANCHORAGE", "naval", "HALVMÅNEØYA", 170.0, "Northern Command anchorage and fuel pier."],
		["HØGØYA STATION", "station", "HØGØYA", 20.0, "Meteorological station, manned in summer."],
		["KVITØYA HUT", "station", "KVITØYA", 250.0, "Unmanned research hut and landing place."],
	]
	for e in list:
		var c := Vector2.ZERO
		for isl in islands:
			if String(isl["name"]) == String(e[2]):
				c = isl["c"]
		var dir := Vector2(sin(deg_to_rad(float(e[3]))), -cos(deg_to_rad(float(e[3]))))
		var pos := c
		for k in 4000:
			pos = c + dir * float(k) * 100.0
			if coast_distance(pos.x, pos.y) > 150.0:
				break
		places.append({"text": e[0], "kind": e[1], "pos": pos, "note": e[4]})


func _build_tracks() -> void:
	# Historical survey lines (soundings are denser along them).
	survey_tracks = [
		[Vector2(-280, 260), Vector2(-120, 120), Vector2(0, 30), Vector2(140, -60), Vector2(260, -150)],
		[Vector2(-290, -20), Vector2(-120, -40), Vector2(60, -10), Vector2(290, 20)],
		[Vector2(-40, 290), Vector2(-20, 120), Vector2(10, 20), Vector2(30, -120), Vector2(60, -260)],
		[Vector2(100, 290), Vector2(130, 120), Vector2(160, -40), Vector2(210, -200)],
		[Vector2(-250, 150), Vector2(-100, 200), Vector2(80, 230), Vector2(280, 250)],
		[Vector2(-180, 40), Vector2(-60, -60), Vector2(70, -150), Vector2(200, -280)],
	]


## Distance (m) to the nearest survey track.
func survey_distance(x: float, z: float) -> float:
	var best := INF
	for t in survey_tracks:
		best = minf(best, _poly_dist(Vector2(x, z), t))
	return best


static func latlon(x: float, z: float) -> Vector2:
	var lat := 76.5 - z / 111000.0
	var lon := 25.0 + x / (111000.0 * cos(deg_to_rad(lat)))
	return Vector2(lat, lon)


static func latlon_text(x: float, z: float) -> String:
	var ll := latlon(x, z)
	return "%02d°%04.1f'N  %03d°%04.1f'E" % [int(ll.x), fposmod(ll.x * 60.0, 60.0), int(ll.y), fposmod(ll.y * 60.0, 60.0)]


func in_region(x: float, z: float) -> bool:
	return absf(x) < REGION_HALF and absf(z) < REGION_HALF
