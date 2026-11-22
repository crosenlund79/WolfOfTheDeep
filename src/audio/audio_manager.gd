class_name AudioManager
extends Node
## The one place gameplay code asks for sound. Every sound is a logical name
## resolved by AudioLibrary (custom override > recording > template > silence).
## Handles compartment muffling, voice ducking, ambience beds, engine noise,
## music with fades, and Basse's overheard singing fragments.

enum Loc { CONTROL, MESS, CABIN, ENGINE, EXTERIOR, UNDERWATER }

const BUS_WORLD := "World"
const BUS_NEAR := "Near"
const BUS_MUFFLED := "Muffled"
const BUS_FAR := "Far"
const BUS_VOICE := "Voice"
const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"

## Compartment adjacency along the boat (forward to aft).
const COMPARTMENT_ORDER := [Loc.CABIN, Loc.CONTROL, Loc.MESS, Loc.ENGINE]

var library: AudioLibrary
var listener := Loc.EXTERIOR
var _beds: Dictionary = {}
var _bed_vol: Dictionary = {}
var _world_lp: AudioEffectLowPassFilter
var _duck := 0.0
var _voice_count := 0
var _music: AudioStreamPlayer
var _music_target := -80.0
var _song_player: AudioStreamPlayer
var _song_t := 0.0
var _song_end := 0.0
var _song_fade_out := 2.0
var _song_source := Loc.MESS
var _last_variant: Dictionary = {}


func _ready() -> void:
	library = AudioLibrary.new()
	_make_bus(BUS_WORLD, "Master", 20000.0, 0.0)
	_world_lp = AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS_WORLD), 0) as AudioEffectLowPassFilter
	_make_bus(BUS_AMBIENCE, "Master", 20000.0, 0.0)
	_make_bus(BUS_NEAR, "Master", 0.0, 0.0)
	_make_bus(BUS_MUFFLED, "Master", 1800.0, -7.0)
	_make_bus(BUS_FAR, "Master", 700.0, -13.0)
	_make_bus(BUS_VOICE, "Master", 0.0, 0.0)
	_make_bus(BUS_MUSIC, "Master", 0.0, -2.0)
	for bed in ["amb_sea_waves", "amb_blizzard", "amb_birds", "amb_sub_interior", "amb_ventilation", "amb_sub_exterior", "eng_low", "eng_medium", "eng_high"]:
		var p := AudioStreamPlayer.new()
		p.stream = library.get_stream(bed)
		if p.stream:
			p.stream = p.stream.duplicate()
			AudioLibrary.set_looping(p.stream, true)
		p.volume_db = -80.0
		p.bus = BUS_WORLD if bed in ["amb_sea_waves", "amb_blizzard", "amb_birds"] else BUS_AMBIENCE
		add_child(p)
		if p.stream:
			p.play(randf() * 4.0)
		_beds[bed] = p
		_bed_vol[bed] = 0.0
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	_music.volume_db = -80.0
	add_child(_music)
	_song_player = AudioStreamPlayer.new()
	add_child(_song_player)
	print("Audio: override folder ", library.override_root.path_join("audio"))
	var customised: Array = []
	for key in library.registry.keys():
		if library.source_of(key) == "custom":
			customised.append(key)
	for t in AudioLibrary.TEMPLATE_NAMES:
		if library.source_of(t) == "custom":
			customised.append(t)
	if not customised.is_empty():
		print("Audio: custom sounds in use: ", ", ".join(customised))


func _make_bus(bus_name: String, send: String, lowpass: float, vol: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	AudioServer.set_bus_volume_db(idx, vol)
	if lowpass > 0.0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = lowpass
		AudioServer.add_bus_effect(idx, lp)


## Bus for a sound made in compartment `source`, heard from the listener's place.
func bus_for(source: Loc) -> String:
	if source == Loc.EXTERIOR or source == Loc.UNDERWATER:
		return BUS_WORLD
	if listener == Loc.EXTERIOR or listener == Loc.UNDERWATER:
		return BUS_FAR
	var a := COMPARTMENT_ORDER.find(listener)
	var b := COMPARTMENT_ORDER.find(source)
	var gap := absi(a - b)
	return BUS_NEAR if gap == 0 else (BUS_MUFFLED if gap == 1 else BUS_FAR)


func _pick(sound: String) -> AudioStream:
	var v := library.get_variants(sound)
	if v.is_empty():
		return null
	var i := randi() % v.size()
	if v.size() > 1 and i == int(_last_variant.get(sound, -1)):
		i = (i + 1) % v.size()
	_last_variant[sound] = i
	return v[i]


## One-shot, non-positional. Returns the player (or null if the sound is missing).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, world: bool = false) -> AudioStreamPlayer:
	return play_on_bus(sound, BUS_WORLD if world else BUS_NEAR, volume_db, pitch)


func play_on_bus(sound: String, bus: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream := _pick(sound)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A sound made somewhere inside the boat.
func play_in(sound: String, source: Loc, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	return play_on_bus(sound, bus_for(source), volume_db, pitch)


func play_delayed(sound: String, delay: float, volume_db: float = 0.0, pitch: float = 1.0, world: bool = true) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	play(sound, volume_db, pitch, world)


## Positional one-shot at a world position.
func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, max_distance: float = 3000.0) -> void:
	var stream := _pick(sound)
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
	var stream := _pick(sound)
	if stream == null:
		return null
	stream = stream.duplicate()
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


## Voice line: ducks everything else while it plays. Returns its duration (0 if missing).
func play_voice(sound: String, source: Loc, intercom: bool = false) -> float:
	var stream := _pick(sound)
	if stream == null:
		return 0.0
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS_VOICE if (intercom or bus_for(source) == BUS_NEAR) else bus_for(source)
	p.volume_db = -3.0 if intercom else 0.0
	add_child(p)
	_voice_count += 1
	p.finished.connect(func() -> void:
		_voice_count -= 1
		p.queue_free())
	p.play()
	return stream.get_length()


func voice_playing() -> bool:
	return _voice_count > 0


# --- music ------------------------------------------------------------------------

func play_music(sound: String, volume_db: float = -4.0, from: float = 0.0) -> void:
	var stream := library.get_stream(sound)
	if stream == null:
		return
	if _music.stream != stream or not _music.playing:
		_music.stream = stream
		_music.volume_db = -50.0
		_music.play(from)
	_music_target = volume_db


func stop_music() -> void:
	_music_target = -80.0


func music_playing() -> bool:
	return _music.playing and _music_target > -60.0


# --- Basse's singing ------------------------------------------------------------

## Play a fragment of one of Basse's songs: [start, start + duration] with
## soft fades. Returns false if no song recordings are available.
func sing_fragment(start: float, duration: float, source: Loc, song_index: int = -1) -> bool:
	var songs := library.song_streams()
	if songs.is_empty():
		return false
	var stream: AudioStream = songs[song_index % songs.size()] if song_index >= 0 else songs[randi() % songs.size()]
	var length := stream.get_length()
	start = clampf(start, 0.0, maxf(length - 2.0, 0.0))
	_song_player.stream = stream
	_song_source = source
	_song_player.bus = bus_for(source)
	_song_player.volume_db = -40.0
	_song_player.play(start)
	_song_t = 0.0
	_song_end = minf(duration, length - start)
	_song_fade_out = clampf(_song_end * 0.25, 1.2, 3.0)
	return true


func song_lengths() -> Array:
	var out: Array = []
	for s in library.song_streams():
		out.append((s as AudioStream).get_length())
	return out


func stop_singing(fade: float = 1.0) -> void:
	if _song_player.playing:
		_song_end = minf(_song_end, _song_t + fade)
		_song_fade_out = fade


func singing() -> bool:
	return _song_player.playing


# --- per-frame mix ----------------------------------------------------------------

func thunder(distance_km: float) -> void:
	play_delayed("thunder", distance_km * 2.9, lerpf(-2.0, -14.0, clampf(distance_km / 6.0, 0.0, 1.0)), randf_range(0.8, 1.1))


func vents() -> void:
	play("sfx_ballast_flooding", -2.0, 1.0, listener == Loc.EXTERIOR or listener == Loc.UNDERWATER)


func splash(strength: float) -> void:
	play("breach_splash", lerpf(-8.0, 0.0, strength), 1.0, true)


## state: {view_loc, sub, weather, cam_depth, near_land, interior}
func update_mix(loc: Loc, sub: Submarine, weather: Weather, near_land: float, dt: float) -> void:
	listener = loc
	var inside := loc in [Loc.CONTROL, Loc.MESS, Loc.CABIN, Loc.ENGINE]
	var under := loc == Loc.UNDERWATER
	var snow := clampf(float(weather.current.get("snow", 0.0)), 0.0, 1.0)
	var hs := float(weather.current.get("hs", 1.5))
	var day := 1.0 - weather.darkness()
	var kn := sub.speed / Submarine.KNOT
	var engine_gain := 1.0 if loc == Loc.ENGINE else (0.55 if loc == Loc.CONTROL or loc == Loc.MESS else (0.3 if loc == Loc.CABIN else 0.0))
	var eng_low := clampf(1.0 - absf(kn - 3.0) / 4.0, 0.0, 1.0) if kn > 0.5 else 0.25
	var eng_med := clampf(1.0 - absf(kn - 9.0) / 5.0, 0.0, 1.0)
	var eng_high := clampf((kn - 10.0) / 6.0, 0.0, 1.0)
	if sub.diesels_running:
		eng_high = maxf(eng_high, 0.8)
	var target := {
		"amb_sea_waves": 0.0 if (inside or under) else clampf(0.5 + hs / 10.0, 0.0, 1.0),
		"amb_blizzard": 0.0 if (inside or under) else clampf(snow * 0.9 + maxf(hs - 3.0, 0.0) * 0.1, 0.0, 1.0),
		"amb_birds": 0.0 if (inside or under) else near_land * day * (1.0 - snow) * 0.6,
		"amb_sub_interior": 0.55 if inside else 0.0,
		"amb_ventilation": (0.35 if inside else 0.0) * (0.5 if sub.silent_running else 1.0),
		"amb_sub_exterior": 0.75 if under else 0.0,
		"eng_low": eng_low * engine_gain * (0.6 if sub.silent_running else 1.0),
		"eng_medium": eng_med * engine_gain,
		"eng_high": eng_high * engine_gain,
	}
	if inside and sub.is_surfaced():
		target["amb_sea_waves"] = 0.15
	_duck = move_toward(_duck, 1.0 if voice_playing() else 0.0, dt * (4.0 if voice_playing() else 1.2))
	var duck_db := -7.0 * _duck
	for bed in target:
		_bed_vol[bed] = move_toward(float(_bed_vol[bed]), float(target[bed]), dt * 0.7)
		var p: AudioStreamPlayer = _beds[bed]
		p.volume_db = linear_to_db(maxf(float(_bed_vol[bed]), 0.0001)) - 6.0 + duck_db
	if _world_lp:
		var want := 900.0 if (under or inside) else 20000.0
		_world_lp.cutoff_hz = lerpf(_world_lp.cutoff_hz, want, 1.0 - exp(-dt * 6.0))
	# Music fades.
	var mv := _music_target + duck_db
	_music.volume_db = move_toward(_music.volume_db, mv, dt * (12.0 if mv > _music.volume_db else 8.0))
	if _music.playing and _music.volume_db <= -79.0 and _music_target <= -79.0:
		_music.stop()
	# Singing fragment envelope.
	if _song_player.playing:
		_song_t += dt
		var fade_in := clampf(_song_end * 0.2, 0.8, 1.8)
		var env := smoothstep(0.0, fade_in, _song_t) * (1.0 - smoothstep(_song_end - _song_fade_out, _song_end, _song_t))
		_song_player.bus = bus_for(_song_source)
		_song_player.volume_db = linear_to_db(maxf(env, 0.0001)) - 8.0 + duck_db * 1.3
		if _song_t >= _song_end:
			_song_player.stop()
