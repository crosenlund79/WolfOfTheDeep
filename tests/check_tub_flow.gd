extends SceneTree
## Practical check of the Bathtub Edition's flow and files (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_tub_flow.gd
## Art and sound overrides from an injected temporary custom/ folder (never
## the real one), saves kept apart from the serious campaign, and the whole
## loop driven through the real screens and keys: menu -> new game ->
## harbour panels -> battle -> pause, manage, restart -> results -> harbour
## -> save and menu -> continue.

const DIR := "user://bathtub_check_flow/"
var failures := 0
var frame := 0
var main: Node
var _t0 := 0.0
var _hull0 := 0.0
var _saved := {}


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _initialize() -> void:
	_resolvers()
	_separation()
	main = load("res://scenes/bathtub.tscn").instantiate()
	main.career.save_dir = DIR
	for f in ["career.json", "prebattle.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	root.add_child(main)


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)


## The visible button with exactly this text, else the first that starts with it.
func _find_button(n: Node, prefix: String, exact := false) -> Button:
	if not exact:
		var e := _find_button(n, prefix, true)
		if e:
			return e
	if n is Button and n.is_visible_in_tree():
		var t := (n as Button).text
		if t == prefix or (not exact and t.begins_with(prefix)):
			return n
	for c in n.get_children():
		var b := _find_button(c, prefix, exact)
		if b:
			return b
	return null


func _press(prefix: String) -> bool:
	var b := _find_button(main.ui, prefix)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _process(_d: float) -> bool:
	frame += 1
	match frame:
		3:
			print("menu and harbour")
			_ok(main.state == "menu" and _find_button(main.ui, "Continue") == null, "a fresh start: the menu offers no Continue")
			_ok(_press("How to play") and main._panel is PanelContainer, "How to play opens")
			_key(KEY_ESCAPE)
		4:
			_ok(main.state == "menu" and _find_button(main.ui, "New Game") != null, "ESC returns to the menu")
			_ok(_press("New Game"), "New Game")
		6:
			_ok(main.state == "harbour" and main.career.has_save(), "the harbour, and the new career is saved at once")
			_ok(_press("The Captains' Poker Club") and main.state == "poker" and main.poker.visible, "the poker club opens")
			_key(KEY_ESCAPE)
		8:
			_ok(main.state == "harbour" and not main.poker.visible, "ESC leaves the club for the harbour")
			_ok(_press("Repairs") and main.manage.visible and main.manage.tab == "repairs", "the repairs panel opens over the harbour")
			_key(KEY_ESCAPE)
		10:
			_ok(main.state == "harbour" and not main.manage.visible, "ESC closes it")
			_ok(_press("Upgrades") and main.manage.tab == "upgrades", "upgrades")
			_key(KEY_TAB)
		12:
			_ok(not main.manage.visible, "TAB closes it too")
			_ok(_press("The Captains") and main.manage.tab == "captains", "the captains")
			_key(KEY_ESCAPE)
		14:
			_hull0 = float(main.career.player["ship"]["hull"])
			_ok(_press("Into the bath!") and main.state == "battle" and main.hud.visible, "into the bath: battle 1")
			_ok(main.career.has_save(TubCareer.PREBATTLE_FILE), "a pre-battle snapshot is kept for a quick restart")
		30:
			print("battle: pause, manage, restart")
			_ok(main.battle.time > 0.3, "the battle runs (%.2f s)" % main.battle.time)
			_key(KEY_ESCAPE)
		31:
			_t0 = main.battle.time
			_ok(main.paused and main._pause != null, "ESC pauses")
		45:
			_ok(main.battle.time == _t0, "nothing moves while paused")
			_key(KEY_ESCAPE)
		50:
			_ok(not main.paused and main.battle.time > _t0, "ESC resumes")
			_key(KEY_TAB)
		51:
			_t0 = main.battle.time
			_ok(main.manage.visible and main.manage.tab == "sub", "TAB: the tactical pause opens on the submarine")
		60:
			_ok(main.battle.time == _t0, "the battle is frozen behind it")
			_key(KEY_TAB)
		61:
			_ok(not main.manage.visible, "TAB returns to the battle")
			main.battle.player.hull -= 40.0
			_key(KEY_ESCAPE)
		62:
			_ok(_press("Restart this battle"), "Restart this battle")
		64:
			_ok(main.state == "battle" and not main.paused and is_equal_approx(main.battle.player.hull, _hull0) and main.career.battle_no == 0, "restarted from the snapshot: hull back to %d, still battle 1" % int(_hull0))
			_key(KEY_ESCAPE)
		65:
			_ok(_press("Give up"), "Give up (withdraw)")
		140:
			print("results, saving and continuing")
			_ok(main.state == "results" and main.career.battle_no == 1, "the results screen; one battle counted")
			var on_disk := TubCareer.new()
			on_disk.save_dir = DIR
			_ok(on_disk.load_file() and on_disk.battle_no == 1, "and saved straight away")
			_key(KEY_SPACE)
		142:
			_ok(main.state == "harbour" and _find_button(main.ui, "Into the bath!  Battle 2") != null, "SPACE: back to the harbour, battle 2 next")
			_saved = main.career.to_dict()
			_ok(_press("Save and return"), "save and return to the menu")
		144:
			_ok(main.state == "menu" and _find_button(main.ui, "Continue") != null, "the menu now offers Continue")
			main.career.player["candy"] = 0
			main.career.battle_no = 99
			main.career.captain("plunge").candy = 1
			_ok(_press("Continue"), "Continue")
		146:
			var c: TubCareer = main.career
			_ok(main.state == "harbour" and c.battle_no == 1 and int(c.player["candy"]) == int(_saved["player"]["candy"]), "the career comes back as saved (battle %d, %d candy)" % [c.battle_no, int(c.player["candy"])])
			_ok(JSON.stringify(c.to_dict()) == JSON.stringify(_saved), "every captain, purse, ship, grudge and memory too")
			for f in ["career.json", "prebattle.json"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
			print("TUB FLOW CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
			return true
	return false


func _resolvers() -> void:
	print("art and sound: templates and overrides (temporary custom folder)")
	var tmp := OS.get_user_data_dir().path_join("bathtub_check_flow/custom")
	DirAccess.make_dir_recursive_absolute(tmp.path_join("graphics/bathtub"))
	DirAccess.make_dir_recursive_absolute(tmp.path_join("audio/bathtub"))
	for f in ["graphics/bathtub/candy.png", "graphics/bathtub/soap.png", "audio/bathtub/plop.wav", "audio/bathtub/pop.ogg", "audio/bathtub/pop.wav", "audio/bathtub/quack.ogg"]:
		DirAccess.remove_absolute(tmp.path_join(f))
	TubArt.override_root = tmp
	TubSound.override_root = tmp
	TubArt.clear_cache()
	TubSound.clear_cache()
	var arts := _templates("res://assets/graphics/bathtub/", ".svg")
	var sounds := _templates("res://assets/audio/bathtub/", ".wav")
	_ok(arts.size() >= 20 and arts.all(func(n: String) -> bool: return TubArt.source_of(n) == "template"), "all %d pictures come from the packaged templates" % arts.size())
	_ok(sounds.size() >= 20 and sounds.all(func(n: String) -> bool: return TubSound.source_of(n) == "template"), "all %d sounds too" % sounds.size())
	TubArt.clear_cache()
	TubSound.clear_cache()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.HOT_PINK)
	img.save_png(tmp.path_join("graphics/bathtub/candy.png"))
	var bad := FileAccess.open(tmp.path_join("graphics/bathtub/soap.png"), FileAccess.WRITE)
	bad.store_string("not a picture")
	bad.close()
	_ok(TubArt.source_of("candy") == "custom" and TubArt.texture("candy").get_width() == 16, "a PNG in custom/graphics/bathtub/ replaces the template")
	_ok(TubArt.source_of("soap") == "template", "an unreadable one falls back to the template")
	_ok(TubArt.source_of("no_such_picture") == "missing", "an unknown name is reported missing, not a crash")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(4410)
	wav.data = data
	wav.save_to_wav(tmp.path_join("audio/bathtub/plop.wav"))
	wav.save_to_wav(tmp.path_join("audio/bathtub/pop.wav"))
	for f in ["audio/bathtub/pop.ogg", "audio/bathtub/quack.ogg"]:
		var b2 := FileAccess.open(tmp.path_join(f), FileAccess.WRITE)
		b2.store_string("not a sound")
		b2.close()
	_ok(TubSound.source_of("plop") == "custom", "a WAV in custom/audio/bathtub/ replaces the template")
	_ok(TubSound.source_of("pop") == "custom" and TubSound.stream("pop") is AudioStreamWAV, "a broken OGG is skipped for a good WAV of the same name")
	_ok(TubSound.source_of("quack") == "template", "a broken OGG alone falls back to the template")
	TubArt.override_root = ""
	TubSound.override_root = ""
	TubArt.clear_cache()
	TubSound.clear_cache()
	_ok(TubArt.root() == AudioLibrary.default_override_root() and TubSound.root() == TubArt.root(), "by default both use the project's one custom/ folder (next to the game when exported)")


func _templates(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("template_") and f.ends_with(ext):
			out.append(f.trim_prefix("template_").trim_suffix(ext))
	return out


func _separation() -> void:
	print("saves kept apart from the serious campaign")
	_ok(String(ProjectSettings.get_setting("application/config/name")).contains("Bathtub"), "the experiment has its own name, so its own user folder")
	_ok(OS.get_user_data_dir().ends_with("Wolf of the Deep Bathtub Edition"), "  " + OS.get_user_data_dir())
	_ok(TubCareer.SAVE_DIR == "user://bathtub/" and TubCareer.SAVE_DIR != SaveSystem.DIR, "and its own save folder inside it (bathtub/, not the campaign's saves/)")
