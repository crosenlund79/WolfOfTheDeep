class_name TubSound
extends Node
## The Bathtub Edition's sounds, resolved like the rest of the project
## (assets/README.md):
##   1. user override   <override root>/audio/bathtub/<name>.ogg|.wav|.mp3
##   2. packaged template  res://assets/audio/bathtub/template_<name>.wav
## Resolved once and cached; overrides apply after a restart. M mutes music.

const TEMPLATE_DIR := "res://assets/audio/bathtub/"
const POOL := 14
static var _cache := {}
static var _source := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var music_on := true
var _last := {}


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)


static func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStream = null
	var base := AudioLibrary.default_override_root().path_join("audio/bathtub/" + name)
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = base + "." + String(ext)
		if not FileAccess.file_exists(path):
			continue
		match ext:
			"ogg":
				s = AudioStreamOggVorbis.load_from_file(path)
			"wav":
				s = AudioStreamWAV.load_from_file(path)
			"mp3":
				var mp := AudioStreamMP3.new()
				mp.data = FileAccess.get_file_as_bytes(path)
				s = mp if mp.data.size() > 0 else null
		if s:
			_source[name] = "custom"
			break
		push_warning("Bathtub sound override %s could not be read; using the template." % path)
	if s == null:
		var t := TEMPLATE_DIR + "template_%s.wav" % name
		if ResourceLoader.exists(t):
			s = load(t)
			_source[name] = "template"
		else:
			_source[name] = "missing"
	_cache[name] = s
	return s


static func source_of(name: String) -> String:
	stream(name)
	return String(_source.get(name, "missing"))


func play(name: String, vol_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var s := stream(name)
	if s == null:
		return
	# The same sound at once from many places is one sound.
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 45:
		return
	_last[name] = now
	for p in _players:
		if not p.playing:
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func music(on: bool) -> void:
	if not on or not music_on:
		_music.stop()
		return
	if _music.playing:
		return
	var s := stream("music")
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_music.stream = s
	if s:
		_music.play()


func toggle_music() -> void:
	music_on = not music_on
	music(music_on)
