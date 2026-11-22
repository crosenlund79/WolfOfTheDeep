class_name AudioLibrary
extends RefCounted
## Resolves logical sound names to streams (see assets/README.md):
##   1. user override   <override root>/audio/<name>.ogg|.wav|.mp3
##   2. packaged template  res://assets/audio/template_<name>.ogg
##   3. nothing: callers simply play no sound.
## Each name is resolved once and cached for the session; overrides take
## effect after restarting the game (no hot reload).

const TEMPLATE_DIR := "res://assets/audio/"
const OVERRIDE_EXTENSIONS := ["ogg", "wav", "mp3"]

## Every logical sound the game uses. Custom files must use these names.
const SOUND_NAMES := [
	"submarine_dive", "submarine_surface", "periscope_raise", "periscope_lower",
	"torpedo_launch", "torpedo_running", "torpedo_impact", "ship_sinking",
	"underwater_ambience", "submarine_ambience", "sea_ambience", "wind_ambience",
	"rain_ambience", "thunder", "hull_creak", "sonar_ping", "breach_splash", "ui_click",
]

var override_root := ""
var _cache: Dictionary = {}
var _source: Dictionary = {}


func _init(root: String = "") -> void:
	override_root = root if root != "" else default_override_root()


## The single place that decides where user overrides live.
## Editor / development: the project's custom/ folder.
## Exported Windows/Linux game: custom/ next to the executable.
static func default_override_root() -> String:
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join("custom")
	return ProjectSettings.globalize_path("res://custom")


func get_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var stream := _load_override(sound)
	if stream != null:
		_source[sound] = "custom"
	else:
		stream = _load_template(sound)
		_source[sound] = "template" if stream != null else "missing"
	_cache[sound] = stream
	return stream


## "custom", "template" or "missing" (after the sound has been requested once).
func source_of(sound: String) -> String:
	if not _cache.has(sound):
		get_stream(sound)
	return String(_source.get(sound, "missing"))


func _load_override(sound: String) -> AudioStream:
	var dir := override_root.path_join("audio")
	for ext in OVERRIDE_EXTENSIONS:
		var path := dir.path_join("%s.%s" % [sound, ext])
		if not FileAccess.file_exists(path):
			continue
		var stream: AudioStream = null
		match ext:
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			"wav":
				stream = AudioStreamWAV.load_from_file(path)
			"mp3":
				stream = AudioStreamMP3.load_from_file(path)
		if stream == null or stream.get_length() <= 0.0:
			push_warning("Custom sound '%s' could not be decoded; using the template instead." % path)
			continue
		return stream
	return null


func _load_template(sound: String) -> AudioStream:
	var path := TEMPLATE_DIR + "template_%s.ogg" % sound
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


## Make any supported stream loop (used for ambience beds and engine noise).
static func set_looping(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if enabled:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
