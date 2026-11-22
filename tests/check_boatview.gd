extends SceneTree
## Practical check of the cutaway interior (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_boatview.gd
## Real mouse clicks on the cutaway: compartments move the captain and
## change the view, stations open their screens, a crew member answers,
## right-click returns to the whole boat, Esc still pauses.

var main: Node
var boat: BoatView
var frame := 0
var steps: Array[Callable] = []
var failures := 0
var _log_mark := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			boat = main.boat
			main.call("_begin_patrol"),
		func() -> void:
			_expect(boat.visible and boat.focus_id == "", "patrol starts on the whole-boat cutaway")
			_expect(root.get_viewport().disable_3d, "3D rendering is off while the cutaway is shown"),
		func() -> void: _click(Vector2(790.0, 560.0)),
		func() -> void: _expect(main.view == 5 and boat.focus_id == "mess" and main.crew.captain_location == "mess", "clicking the mess takes the captain there"),
		func() -> void: _click(Vector2(790.0, 560.0), MOUSE_BUTTON_RIGHT),
		func() -> void: _expect(boat.focus_id == "", "right-click returns to the whole boat"),
		func() -> void: _click(Vector2(1380.0, 560.0)),
		func() -> void: _expect(boat.focus_id == "sonar" and main.crew.captain_location == "control", "clicking the sonar room goes there"),
		func() -> void: _click(Vector2(1418.0, 560.0)),
		func() -> void: _expect(main.view == 3, "clicking the sonar consoles opens the sonar display"),
		func() -> void: _key(KEY_1),
		func() -> void: _expect(main.view == 0 and boat.visible and boat.focus_id == "control", "key 1 returns to the control room cutaway"),
		func() -> void:
			# Ten in the morning: Miller is on watch at the conn.
			main.clock.seconds = 10.0 * 3600.0
			boat.set("_snap", true),
		func() -> void: _log_mark = main.dialogue.log_lines.size(),
		func() -> void: _click(_sprite_point("miller")),
		func() -> void: pass,
		func() -> void:
			var said := false
			for i in range(_log_mark, main.dialogue.log_lines.size()):
				said = said or String(main.dialogue.log_lines[i]).begins_with("MILLER")
			# Or still waiting its turn behind a longer line.
			for q in main.dialogue.get("_queue"):
				said = said or (String(q["who"]) == "miller" and not bool(q["intercom"]))
			_expect(said, "clicking Miller makes him talk"),
		func() -> void: _click(Vector2(1124.0, 560.0)),
		func() -> void: _expect(main.view == 1, "clicking the periscope goes to the periscope view"),
		func() -> void: _key(KEY_7),
		func() -> void: _expect(boat.focus_id == "cabin" and main.crew.captain_location == "cabin", "key 7 shows the cabin"),
		func() -> void: _click(Vector2(1520.0, 560.0)),
		func() -> void: _expect(main.menu.visible and main.menu.kind == "rest", "clicking the bunk offers rest"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(not main.menu.visible and not paused, "Esc closes the rest panel"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(paused, "Esc opens the pause menu over the cutaway"),
		func() -> void: _key(KEY_ESCAPE),
		func() -> void: _expect(not paused, "Esc closes it again"),
	]


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 30 or frame % 45 != 0:
		return false
	if steps.is_empty():
		print("BOATVIEW CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(1 if failures > 0 else 0)
		return false
	var s: Callable = steps.pop_front()
	s.call()
	return false


## World point (cutaway units) -> click on screen with the current transform.
func _click(world: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var p: Vector2 = boat.get("_xf") * world
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = p
		ev.global_position = p
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev, true)


func _sprite_point(id: String) -> Vector2:
	var s: Variant = boat.get("_sprites").get(id)
	return (s.pos as Vector2) + Vector2(0.0, -60.0) if s else Vector2.ZERO


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
