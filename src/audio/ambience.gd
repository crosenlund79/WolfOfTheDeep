class_name Ambience
extends Node
## Procedurally synthesised soundscape (no audio files): sea and wind wash,
## rain, hull hum, creaks, distant active sonar, thunder and ballast vents.
## Loops are generated on a worker thread at startup.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Dictionary = {}
var _ready_flag := false
var _task := -1
var _creak_t := 6.0
var _ping_t := 18.0
var _vol: Dictionary = {}


func _ready() -> void:
	_task = WorkerThreadPool.add_task(_generate_all)


func _process(_delta: float) -> void:
	if not _ready_flag and _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		for key in ["sea", "wind", "rain", "hull", "under"]:
			var p := AudioStreamPlayer.new()
			p.stream = _streams[key]
			p.volume_db = -80.0
			add_child(p)
			p.play(randf() * 2.0)
			_players[key] = p
			_vol[key] = 0.0
		for key2 in ["ping", "creak", "thunder", "vents"]:
			var p2 := AudioStreamPlayer.new()
			p2.stream = _streams[key2]
			add_child(p2)
			_players[key2] = p2
		_ready_flag = true


func thunder(distance_km: float) -> void:
	if not _ready_flag:
		return
	await get_tree().create_timer(distance_km * 2.9).timeout
	var p: AudioStreamPlayer = _players["thunder"]
	p.volume_db = lerpf(-2.0, -14.0, clampf(distance_km / 6.0, 0.0, 1.0))
	p.pitch_scale = randf_range(0.8, 1.1)
	p.play()


func vents() -> void:
	if not _ready_flag:
		return
	var p: AudioStreamPlayer = _players["vents"]
	p.volume_db = -6.0
	p.pitch_scale = 1.0
	p.play()


func splash(strength: float) -> void:
	if not _ready_flag:
		return
	var p: AudioStreamPlayer = _players["thunder"]
	p.volume_db = lerpf(-8.0, 0.0, strength)
	p.pitch_scale = 1.6
	p.play()
	var v: AudioStreamPlayer = _players["vents"]
	v.volume_db = lerpf(-10.0, -2.0, strength)
	v.pitch_scale = 0.7
	v.play()


func update_state(view: int, sub: Submarine, weather: Weather, cam_depth: float) -> void:
	if not _ready_flag:
		return
	var dt := get_process_delta_time()
	var inside := view == 3 or view == 4
	var under := cam_depth > 0.0 and not inside
	var storm := clampf(float(weather.current.get("rain", 0.0)), 0.0, 1.0)
	var hs := float(weather.current.get("hs", 1.5))
	var target := {
		"sea": 0.0 if (inside or under) else clampf(0.45 + hs / 10.0, 0.0, 1.0),
		"wind": 0.0 if (inside or under) else clampf(0.12 + storm * 0.8 + hs / 25.0, 0.0, 1.0),
		"rain": 0.0 if (inside or under) else storm * 0.75,
		"hull": 0.55 if inside else 0.0,
		"under": 0.7 if under else (0.25 if inside else 0.0),
	}
	if inside and sub.is_surfaced():
		target["sea"] = 0.18
	for key in target:
		_vol[key] = move_toward(float(_vol[key]), float(target[key]), dt * 0.8)
		var p: AudioStreamPlayer = _players[key]
		p.volume_db = linear_to_db(maxf(float(_vol[key]), 0.0001)) - 6.0
	# Occasional creaks and distant active sonar while inside or submerged.
	if inside or under:
		_creak_t -= dt
		if _creak_t <= 0.0:
			_creak_t = randf_range(5.0, 14.0) * (1.0 if sub.depth > 30.0 else 2.0)
			var c: AudioStreamPlayer = _players["creak"]
			c.pitch_scale = randf_range(0.7, 1.3)
			c.volume_db = randf_range(-20.0, -10.0)
			c.play()
		_ping_t -= dt
		if _ping_t <= 0.0:
			_ping_t = randf_range(22.0, 40.0)
			var pg: AudioStreamPlayer = _players["ping"]
			pg.volume_db = randf_range(-20.0, -12.0)
			pg.play()


# --- synthesis --------------------------------------------------------------

func _generate_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_streams["sea"] = _loop(_sea(rng, 9.0), 0.6)
	_streams["wind"] = _loop(_wind(rng, 7.0), 0.6)
	_streams["rain"] = _loop(_rain(rng, 4.5), 0.4)
	_streams["hull"] = _loop(_hull(rng, 10.0), 0.6)
	_streams["under"] = _loop(_under(rng, 9.0), 0.6)
	_streams["ping"] = _wav(_ping(4.5), false)
	_streams["creak"] = _wav(_creak(rng, 1.8), false)
	_streams["thunder"] = _wav(_thunder(rng, 7.0), false)
	_streams["vents"] = _wav(_vent(rng, 4.0), false)


func _sea(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		brown = (brown + 0.03 * w) / 1.03
		lp += 0.08 * (w - lp)
		lp2 += 0.02 * (lp - lp2)
		var swell := 0.55 + 0.45 * sin(TAU * t / 4.5) * sin(TAU * t / 3.0 + 1.0)
		var wash := (lp - lp2) * (0.4 + 0.6 * pow(maxf(sin(TAU * t / 4.5 + 0.5), 0.0), 3.0))
		out[i] = brown * 2.2 * swell + wash * 1.6
	return out


func _wind(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		var f := 0.03 + 0.02 * sin(TAU * t / 3.5)
		a += f * (w - a)
		b += f * 0.5 * (a - b)
		var gust := 0.5 + 0.5 * sin(TAU * t / 7.0) * sin(TAU * t / 2.3)
		out[i] = (a - b) * 3.5 * gust
	return out


func _rain(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		lp += 0.5 * (w - lp)
		var crackle := 0.0
		if rng.randf() < 0.004:
			crackle = rng.randf_range(-1.0, 1.0)
		out[i] = (w - lp) * 0.35 + crackle * 0.5
	return out


func _hull(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var vent := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		brown = (brown + 0.02 * w) / 1.02
		vent += 0.15 * (w - vent)
		var hum := sin(TAU * 60.0 * t) * 0.25 + sin(TAU * 120.3 * t) * 0.14 + sin(TAU * 180.0 * t) * 0.06 + sin(TAU * 49.7 * t) * 0.08
		hum *= 0.85 + 0.15 * sin(TAU * t * 0.7)
		out[i] = hum * 0.6 + brown * 2.0 + vent * 0.06
	return out


func _under(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var lp := 0.0
	var bubble_t := 0.0
	var bubble_f := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		brown = (brown + 0.02 * w) / 1.02
		lp += 0.01 * (brown - lp)
		var v := lp * 9.0 * (0.7 + 0.3 * sin(TAU * t / 5.0))
		if rng.randf() < 0.0004:
			bubble_t = 0.06
			bubble_f = rng.randf_range(400.0, 1100.0)
		if bubble_t > 0.0:
			bubble_t -= 1.0 / RATE
			v += sin(TAU * bubble_f * t * (1.0 + (0.06 - bubble_t) * 4.0)) * bubble_t * 2.0
		out[i] = v
	return out


func _ping(secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var dry := PackedFloat32Array()
	dry.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		if t < 0.6:
			env = smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(0.35, 0.6, t))
		dry[i] = sin(TAU * 3150.0 * t) * env * 0.5
	# Sparse echo tail: the ocean answering back.
	var taps := [[0.0, 1.0], [0.21, 0.45], [0.47, 0.3], [0.83, 0.2], [1.3, 0.14], [1.9, 0.08], [2.6, 0.05]]
	for tap in taps:
		var off := int(float(tap[0]) * RATE)
		var g := float(tap[1])
		for i in range(off, n):
			out[i] += dry[i - off] * g
	return out


func _creak(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(95.0, 70.0, t / secs) + sin(t * 23.0) * 6.0
		ph += TAU * f / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += 0.05 * (w - lp)
		var env := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.6, secs, t))
		var grain := 0.6 + 0.4 * sin(TAU * 31.0 * t + sin(TAU * 7.0 * t) * 3.0)
		out[i] = (sin(ph) * 0.5 + lp * 1.2) * env * grain
	return out


func _thunder(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		brown = (brown + 0.04 * w) / 1.04
		lp += 0.03 * (brown - lp)
		var crack := w * 0.5 * exp(-t * 9.0)
		var env := smoothstep(0.0, 0.15, t) * exp(-t * 0.55) * (0.7 + 0.3 * sin(TAU * t * 1.3) * sin(TAU * t * 0.7))
		out[i] = lp * 10.0 * env + crack
	return out


func _vent(rng: RandomNumberGenerator, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += 0.25 * (w - lp)
		lp2 += 0.04 * (lp - lp2)
		var env := smoothstep(0.0, 0.08, t) * exp(-t * 0.9)
		out[i] = (lp * 0.6 + lp2 * 2.0) * env
	return out


## Crossfade the tail into the head so the loop is seamless.
func _loop(data: PackedFloat32Array, fade_secs: float) -> AudioStreamWAV:
	var f := int(fade_secs * RATE)
	var n := data.size() - f
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = data[i]
	for i in f:
		var a := float(i) / float(f)
		out[i] = data[n + i] * (1.0 - a) + data[i] * a
	return _wav(out, true)


func _wav(data: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.0001
	for v in data:
		peak = maxf(peak, absf(v))
	var g := 0.85 / peak
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = data.size()
	return s
