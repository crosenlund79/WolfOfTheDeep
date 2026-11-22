class_name AudioManager
extends Node
## The one place gameplay code asks for sound. Every sound is a logical name
## resolved by AudioLibrary (custom override > template > silence), so user
## files replace sounds without code changes. Also runs the ambience beds.

const BUS_WORLD := "World"

var library: AudioLibrary
var _beds: Dictionary = {}
var _bed_vol: Dictionary = {}
var _lowpass: AudioEffectLowPassFilter
var _creak_t := 6.0
var _ping_t := 20.0


func _ready() -> void:
	library = AudioLibrary.new()
	# Outside-world sounds go through a bus that muffles when the listener is
	# underwater or inside the boat.
	if AudioServer.get_bus_index(BUS_WORLD) < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_WORLD)
		AudioServer.set_bus_send(idx, "Master")
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(idx, _lowpass)
	for bed in ["sea_ambience", "wind_ambience", "rain_ambience", "submarine_ambience", "underwater_ambience"]:
		var p := AudioStreamPlayer.new()
		p.stream = library.get_stream(bed)
		AudioLibrary.set_looping(p.stream, true)
		p.volume_db = -80.0
		p.bus = BUS_WORLD if bed in ["sea_ambience", "wind_ambience", "rain_ambience"] else "Master"
		add_child(p)
		if p.stream:
			p.play(randf() * 2.0)
		_beds[bed] = p
		_bed_vol[bed] = 0.0
	print("Audio: override folder ", library.override_root.path_join("audio"))
	for s in AudioLibrary.SOUND_NAMES:
		if library.source_of(s) == "custom":
			print("Audio: custom sound in use: ", s)


## One-shot, non-positional. Returns the player (or null if the sound is missing).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, world: bool = false) -> AudioStreamPlayer:
	var stream := library.get_stream(sound)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = BUS_WORLD if world else "Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


func play_delayed(sound: String, delay: float, volume_db: float = 0.0, pitch: float = 1.0, world: bool = true) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	play(sound, volume_db, pitch, world)


## Positional one-shot at a world position.
func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, max_distance: float = 3000.0) -> void:
	var stream := library.get_stream(sound)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 40.0
	p.bus = BUS_WORLD
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Looping positional sound that follows a node (e.g. a running torpedo).
func attach_loop(sound: String, node: Node3D, volume_db: float = 0.0, max_distance: float = 2500.0) -> AudioStreamPlayer3D:
	var stream := library.get_stream(sound)
	if stream == null:
		return null
	AudioLibrary.set_looping(stream, true)
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 25.0
	p.bus = BUS_WORLD
	node.add_child(p)
	p.play()
	return p


func thunder(distance_km: float) -> void:
	play_delayed("thunder", distance_km * 2.9, lerpf(-2.0, -14.0, clampf(distance_km / 6.0, 0.0, 1.0)), randf_range(0.8, 1.1))


func vents() -> void:
	play("submarine_dive", -3.0, 1.0, true)


func splash(strength: float) -> void:
	play("breach_splash", lerpf(-8.0, 0.0, strength), 1.0, true)


func update_state(view: int, sub: Submarine, weather: Weather, cam_depth: float) -> void:
	var dt := get_process_delta_time()
	var inside := view == 3 or view == 4
	var under := cam_depth > 0.0 and not inside
	var storm := clampf(float(weather.current.get("rain", 0.0)), 0.0, 1.0)
	var hs := float(weather.current.get("hs", 1.5))
	var target := {
		"sea_ambience": 0.0 if (inside or under) else clampf(0.45 + hs / 10.0, 0.0, 1.0),
		"wind_ambience": 0.0 if (inside or under) else clampf(0.12 + storm * 0.8 + hs / 25.0, 0.0, 1.0),
		"rain_ambience": 0.0 if (inside or under) else storm * 0.75,
		"submarine_ambience": 0.6 if inside else 0.0,
		"underwater_ambience": 0.7 if under else (0.25 if inside and not sub.is_surfaced() else 0.0),
	}
	if inside and sub.is_surfaced():
		target["sea_ambience"] = 0.18
	for bed in target:
		_bed_vol[bed] = move_toward(float(_bed_vol[bed]), float(target[bed]), dt * 0.8)
		var p: AudioStreamPlayer = _beds[bed]
		p.volume_db = linear_to_db(maxf(float(_bed_vol[bed]), 0.0001)) - 6.0
	if _lowpass:
		var want := 900.0 if (under or inside) else 20000.0
		_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, want, 1.0 - exp(-dt * 6.0))
	# Occasional creaks and distant active sonar while inside or submerged.
	if inside or under:
		_creak_t -= dt
		if _creak_t <= 0.0:
			_creak_t = randf_range(5.0, 14.0) * (1.0 if sub.depth > 30.0 else 2.0)
			play("hull_creak", randf_range(-20.0, -10.0), randf_range(0.7, 1.3))
		_ping_t -= dt
		if _ping_t <= 0.0:
			_ping_t = randf_range(22.0, 40.0)
			play("sonar_ping", randf_range(-20.0, -12.0))
