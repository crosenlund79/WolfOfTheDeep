extends SceneTree
## Practical check of the control room pilot (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_control_room.gd
## Plates and live layers load; viewpoints switch by key and by clicking a
## station; stations hand over to the periscope; Esc still pauses.

var main: Node
var pilot: ControlRoomPilot
var frame := 0
var steps: Array[Callable] = []
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			pilot = main.pilot
			main.call("_begin_patrol")
			main.briefing_panel.dismiss(),
		func() -> void:
			main.call("set_view", 0),
		func() -> void:
			_expect(pilot.visible and pilot.view == "command", "key 1 view shows the control room at the command position")
			_expect(pilot.get("_ready_ok"), "plates and views.json load")
			_expect((pilot.get("_screens") as Dictionary).get("command", []).size() >= 3, "live displays are composited in the command view")
			_expect(root.get_viewport().disable_3d, "main 3D view is off while the plates are shown"),
		func() -> void: _key(KEY_E),
		func() -> void: _expect(pilot.view == "sonar", "E moves to the sonar console viewpoint"),
		func() -> void: _key(KEY_Q),
		func() -> void: _expect(pilot.view == "command", "Q moves back"),
		func() -> void: _click_hot("sonar"),
		func() -> void: _expect(pilot.view == "sonar", "clicking the sonar console goes to its viewpoint"),
		func() -> void: _click_hot("sonar"),
		func() -> void: _expect(main.view == 3, "clicking it again opens the full sonar display"),
		func() -> void: _key(KEY_1),
		func() -> void: _expect(main.view == 0 and pilot.view == "command", "key 1 returns to the command position"),
		func() -> void: _click_hot("periscope"),
		func() -> void: _expect(main.view == 1, "clicking the periscope goes to the periscope view"),
		func() -> void: _key(KEY_1),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(paused, "Esc opens the pause menu in the control room"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(not paused and pilot.visible, "Esc closes it and the room is back"),
	]


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 30 or frame % 40 != 0:
		return false
	if steps.is_empty():
		print("CONTROL ROOM CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(1 if failures > 0 else 0)
		return false
	var s: Callable = steps.pop_front()
	s.call()
	return false


func _click_hot(name: String) -> void:
	var vm: Dictionary = pilot.meta["views"][pilot.view]
	if not vm["hot"].has(name):
		_expect(false, "hotspot %s exists in %s" % [name, pilot.view])
		return
	var r: Array = vm["hot"][name]
	# Click the middle of the part of the station that is on screen (headless
	# runs use a square window, so the cover-scaled plate is cropped at the sides).
	var xf: Transform2D = pilot.get("_xf")
	var on_screen := Rect2(xf * Vector2(float(r[0]), float(r[1])), Vector2.ZERO).expand(xf * Vector2(float(r[2]), float(r[3])))
	on_screen = on_screen.intersection(Rect2(Vector2.ZERO, pilot.size).grow(-8.0))
	var p := on_screen.get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv, true)
	pilot.call("_update_hover")
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = p
		ev.global_position = p
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		root.push_input(ev, true)


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
