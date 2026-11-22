class_name AudioLibrary
extends RefCounted
## Resolves logical sound names to streams (see assets/README.md, AUDIO_LIBRARY.md):
##   1. user override   <override root>/audio/<name>.ogg|.wav|.mp3   (replaces the group)
##                      <override root>/audio/<name>_<n>.ogg|...       (replaces one variant)
##   2. bundled working copies listed in res://assets/audio/audio_registry.json
##      (made from the creator's recordings in assets/audio/_inbox, which is never modified)
##   3. packaged synthesised template  res://assets/audio/template_<name>.ogg
##   4. nothing: callers simply play no sound.
## Streams are resolved once and cached; overrides apply after a restart.

const TEMPLATE_DIR := "res://assets/audio/"
const REGISTRY := "res://assets/audio/audio_registry.json"
const OVERRIDE_EXTENSIONS := ["ogg", "wav", "mp3"]

## Synthesised template sounds still used where no recording exists.
const TEMPLATE_NAMES := [
	"submarine_surface", "periscope_raise", "periscope_lower", "torpedo_launch",
	"torpedo_running", "torpedo_impact", "ship_sinking", "thunder", "breach_splash",
	"ui_click", "sonar_ping", "rain_ambience", "underwater_ambience", "submarine_ambience",
	"sea_ambience", "wind_ambience", "hull_creak", "submarine_dive",
]

var override_root := ""
var registry: Dictionary = {}
var _cache: Dictionary = {}
var _source: Dictionary = {}


func _init(root: String = "") -> void:
	override_root = root if root != "" else default_override_root()
	if FileAccess.file_exists(REGISTRY):
		var txt := FileAccess.get_file_as_string(REGISTRY)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			registry = parsed


## The single place that decides where user overrides live.
## Editor / development: the project's custom/ folder.
## Exported Windows/Linux game: custom/ next to the executable.
static func default_override_root() -> String:
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join("custom")
	return ProjectSettings.globalize_path("res://custom")


## All variants of a logical sound (custom overrides applied).
func get_variants(sound: String) -> Array:
	if _cache.has(sound):
		return _cache[sound]
	var out: Array = []
	var group := _load_override(sound)
	if group != null:
		out.append(group)
		_source[sound] = "custom"
	elif registry.has(sound):
		var files: Array = registry[sound]["files"]
		var any_custom := false
		for i in files.size():
			var stem := String(files[i]).get_file().get_basename()
			var s := _load_override(stem)
			if s != null:
				any_custom = true
			else:
				s = load(String(files[i])) as AudioStream if ResourceLoader.exists(String(files[i])) else null
			if s != null:
				out.append(s)
		_source[sound] = "custom" if any_custom else ("recording" if not out.is_empty() else "missing")
	else:
		var tpl := _load_template(sound)
		if tpl != null:
			out.append(tpl)
		_source[sound] = "template" if tpl != null else "missing"
	_cache[sound] = out
	return out


func get_stream(sound: String) -> AudioStream:
	var v := get_variants(sound)
	return v[randi() % v.size()] if not v.is_empty() else null


func has_sound(sound: String) -> bool:
	return not get_variants(sound).is_empty()


## "custom", "recording", "template" or "missing".
func source_of(sound: String) -> String:
	get_variants(sound)
	return String(_source.get(sound, "missing"))


## Basse's songs: bundled recordings named basse_song* plus any custom files.
func song_streams() -> Array:
	var out: Array = []
	for key in registry.keys():
		if String(key).begins_with("basse_song"):
			out.append_array(get_variants(key))
	var dir := DirAccess.open(override_root.path_join("audio"))
	if dir:
		for f in dir.get_files():
			if f.begins_with("basse_song") and f.get_extension().to_lower() in OVERRIDE_EXTENSIONS:
				var s := _load_file(override_root.path_join("audio").path_join(f), f.get_extension().to_lower())
				if s != null:
					out.append(s)
	return out


func _load_override(stem: String) -> AudioStream:
	var dir := override_root.path_join("audio")
	for ext in OVERRIDE_EXTENSIONS:
		var path := dir.path_join("%s.%s" % [stem, ext])
		if not FileAccess.file_exists(path):
			continue
		var stream := _load_file(path, ext)
		if stream == null or stream.get_length() <= 0.0:
			push_warning("Custom sound '%s' could not be decoded; using the bundled sound instead." % path)
			continue
		return stream
	return null


static func _load_file(path: String, ext: String) -> AudioStream:
	match ext:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
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
