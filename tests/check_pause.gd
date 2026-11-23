extends SceneTree
## Practical check of the Esc pause menu (no framework):
##   godot --headless --path . -s tests/check_pause.gd
## Real key events through the viewport: Esc opens, Esc closes, repeated
## presses toggle consistently, key repeat does not toggle, the game clock
## freezes while paused and runs again after, and Esc with an orders panel
## open still just closes that panel.

var main: Node
var frame := 0
var steps: Array[Callable] = []
var failures := 0
var _clock_mark := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void:
			main.call("_begin_patrol")
			main.briefing_panel.dismiss(),
		func() -> void: _esc(),
		func() -> void:
			_expect(paused and main.hud.is_paused(), "first Esc opens the menu")
			_clock_mark = main.clock.seconds,
		func() -> void: _expect(is_equal_approx(main.clock.seconds, _clock_mark), "game clock frozen while paused"),
		func() -> void: _esc(true),
		func() -> void: _expect(paused, "key repeat does not close the menu"),
		func() -> void: _esc(),
		func() -> void:
			_expect(not paused and not main.hud.is_paused(), "second Esc closes the menu")
			_clock_mark = main.clock.seconds,
		func() -> void: _expect(main.clock.seconds > _clock_mark, "game clock runs again after closing"),
	]
	for i in 6:
		var want_paused := i % 2 == 0
		steps.append(func() -> void: _esc())
		steps.append(func() -> void: _expect(paused == want_paused and main.hud.is_paused() == want_paused, "toggle %d -> %s" % [i + 1, "paused" if want_paused else "playing"]))
	steps.append(func() -> void: main.call("_open_orders"))
	steps.append(func() -> void: _esc())
	steps.append(func() -> void: _expect(not main.menu.visible and not paused, "Esc closes an open orders panel without pausing"))
	steps.append(func() -> void: _esc())
	steps.append(func() -> void: _expect(paused, "Esc after that opens the menu"))
	steps.append(func() -> void: _esc())
	steps.append(func() -> void: _expect(not paused, "and closes it again"))


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 30 or frame % 8 != 0:
		return false
	if steps.is_empty():
		print("PAUSE CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(1 if failures > 0 else 0)
		return false
	var s: Callable = steps.pop_front()
	s.call()
	return false


func _esc(echo: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	ev.echo = echo
	root.push_input(ev)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	root.push_input(up)


func _expect(cond: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		failures += 1
