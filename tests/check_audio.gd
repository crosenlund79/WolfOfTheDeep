extends SceneTree
## Practical check of sound resolution (no framework):
##   godot --headless --path . -s tests/check_audio.gd
## Uses a temporary override root: group override, single-variant override,
## a broken file (must fall back), template fallback, song discovery, missing.

var failures := 0


func _init() -> void:
	var root := OS.get_user_data_dir().path_join("audio_check/custom")
	var dir := root.path_join("audio")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var sample := ProjectSettings.globalize_path("res://assets/audio/template_ui_click.ogg")
	var bytes := FileAccess.get_file_as_bytes(sample)
	_write(dir.path_join("sfx_alarm.ogg"), bytes)
	_write(dir.path_join("amb_sea_waves_2.ogg"), bytes)
	_write(dir.path_join("basse_song_1.ogg"), bytes)
	_write(dir.path_join("sfx_ice_scrape.ogg"), PackedByteArray([1, 2, 3, 4, 5]))
	var lib := AudioLibrary.new(root)
	_expect(lib.source_of("sfx_alarm") == "custom", "group override wins: " + lib.source_of("sfx_alarm"))
	_expect(lib.get_variants("sfx_alarm").size() == 1, "group override replaces all variants")
	_expect(lib.get_variants("amb_sea_waves").size() == 4, "variant override keeps the group size")
	_expect(lib.source_of("sfx_ice_scrape") == "recording", "broken override falls back to recordings: " + lib.source_of("sfx_ice_scrape"))
	_expect(lib.source_of("vo_miller_pd_reached") == "recording", "recording used")
	_expect(lib.source_of("torpedo_launch") == "template", "template fallback")
	_expect(lib.source_of("no_such_sound") == "missing", "missing is silent")
	_expect(lib.song_streams().size() == 1, "custom song discovered")
	var plain := AudioLibrary.new(OS.get_user_data_dir().path_join("audio_check/none"))
	_expect(plain.source_of("sfx_alarm") == "recording", "no override root: recordings")
	_expect(plain.song_streams().is_empty(), "no songs without files")
	print("AUDIO CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _write(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("  FAILED: ", what)
