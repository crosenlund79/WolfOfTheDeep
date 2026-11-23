extends SceneTree
## Practical check of the command interface (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_ui.gd
## Main menu at start, campaign start hides it and shows the command bar,
## overlays open and close (Esc closes them before pausing), the pause menu
## toggles, developer tools stay off unless enabled, the periscope trains
## continuously through 360°, the bar switches stations, and the card table
## keeps the keyboard while it is open.

var main: Node
var frame := 0
var steps: Array[Callable] = []
var failures := 0
var _b0 := 0.0
var _dev_was := false


func _initialize() -> void:
	_dev_was = bool(Settings.get_v("developer"))
	Settings.set_v("developer", false)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			_expect(main.in_main_menu and main.game_menu.visible, "main menu shows at start")
			_expect(not main.started, "no campaign runs behind the menu"),
		func() -> void: main.call("_begin_patrol"),
		func() -> void:
			_expect(not main.game_menu.visible and not main.in_main_menu, "starting a campaign hides the menu")
			_expect(main.command_bar.visible, "command bar visible in play")
			_expect(main.briefing_panel.visible and main.briefing_panel.text().contains("OBJECTIVES"), "the mission briefing opens on a new campaign"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(not main.briefing_panel.visible and not paused, "Esc dismisses the briefing without pausing"),
		func() -> void: _key(KEY_F1),
		func() -> void: _expect(main.briefing_panel.visible, "F1 reopens it"),
		func() -> void: _key(KEY_ENTER),
		func() -> void: _expect(not main.briefing_panel.visible, "Enter dismisses it"),
		func() -> void: _key(KEY_K),
		func() -> void: _expect(main.contact_list.visible, "K opens the contact list"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(not main.contact_list.visible and not paused, "Esc closes the contact list without pausing"),
		func() -> void: _key(KEY_L),
		func() -> void: _expect(main.log_view.visible, "L opens the Captain's Log"),
		func() -> void: _key(KEY_L),
		func() -> void: _expect(not main.log_view.visible, "L closes it again"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(paused and main.hud.pause_menu.visible, "Esc opens the pause menu"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(not paused, "Esc resumes"),
		func() -> void: _key(KEY_F10),
		func() -> void: _expect(not main.dev_panel.visible, "developer panel stays off by default"),
		func() -> void:
			Settings.set_v("developer", true)
			_key(KEY_F10),
		func() -> void:
			_expect(main.dev_panel.visible, "F10 opens the developer panel once enabled")
			_key(KEY_F10),
		func() -> void:
			main.call("_on_bar_request", "view_4")
			_expect(main.view == 4, "command bar switches to the chart"),
		func() -> void:
			main.set_view(1)
			main.rig.bearing = deg_to_rad(350.0)
			_b0 = 350.0
			var down := InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			main.rig.handle_input(down)
			# Drag far to the right: several full turns.
			var total := 0.0
			for _i in 400:
				var mm := InputEventMouseMotion.new()
				mm.relative = Vector2(60, 0)
				main.rig.handle_input(mm)
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			main.rig.handle_input(up)
			var deg := rad_to_deg(main.rig.bearing)
			_expect(deg >= 0.0 and deg < 360.0, "bearing stays within 000-359 (%.1f)" % deg)
			_expect(not is_equal_approx(deg, 350.0), "the scope kept training past north"),
		func() -> void:
			# Back through north the other way, in small steps, checking continuity.
			main.rig.bearing = deg_to_rad(5.0)
			var down := InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			main.rig.handle_input(down)
			var prev := 5.0
			var max_jump := 0.0
			for _i in 30:
				var mm := InputEventMouseMotion.new()
				mm.relative = Vector2(-10, 0)
				main.rig.handle_input(mm)
				var now := rad_to_deg(main.rig.bearing)
				max_jump = maxf(max_jump, absf(wrapf(now - prev, -180.0, 180.0)))
				prev = now
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			main.rig.handle_input(up)
			_expect(prev > 300.0 and max_jump < 5.0, "turning left through 000 is smooth (now %.1f)" % prev),
		func() -> void:
			main.call("_open_cards"),
		func() -> void:
			if main.poker.visible:
				_key(KEY_1)
			else:
				print("  (cards could not open at this hour; isolation step skipped)"),
		func() -> void:
			if main.poker.visible:
				_expect(main.view == 5, "keys go to the card table while it is open (no station change)"),
	]


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 30 or frame % 8 != 0:
		return false
	if steps.is_empty():
		Settings.set_v("developer", _dev_was)
		print("UI CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(1 if failures > 0 else 0)
		return false
	var s: Callable = steps.pop_front()
	s.call()
	return false


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)


func _expect(cond: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		failures += 1
