class_name DevPanel
extends PanelContainer
## Developer / testing panel (F10, only when enabled in the menu). Direct
## controls for testing; never shows hidden campaign information.

var main: Node
var _depth: SpinBox
var _speed: SpinBox
var _x: SpinBox
var _z: SpinBox
var _time: SpinBox
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel_style(0.95, 14))
	UiStyle.place(self, Vector2(0, 0), Vector2(20, 84), Vector2(470, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_child(UiStyle.label("DEVELOPER  ·  TESTING ONLY", 16, UiStyle.AMBER))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var close := UiStyle.button("✕  F10", 12)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	v.add_child(top)
	_depth = _num(v, "Depth (m)", 0.0, 600.0, 1.0, "Set depth", func(val: float) -> void: main.dev_set_depth(val))
	_speed = _num(v, "Speed (kt)", 0.0, 22.0, 0.5, "Set speed", func(val: float) -> void: main.dev_set_speed(val))
	var pos_row := HBoxContainer.new()
	pos_row.add_child(UiStyle.label("Position km  E", 13, UiStyle.WHITE))
	_x = _spin(-300.0, 300.0, 0.1)
	pos_row.add_child(_x)
	pos_row.add_child(UiStyle.label("S", 13, UiStyle.WHITE))
	_z = _spin(-300.0, 300.0, 0.1)
	pos_row.add_child(_z)
	var go := UiStyle.button("Teleport", 12)
	go.pressed.connect(func() -> void: main.dev_teleport(Vector3(_x.value * 1000.0, 0.0, _z.value * 1000.0)))
	pos_row.add_child(go)
	v.add_child(pos_row)
	_time = _num(v, "Time ×", 1.0, 2000.0, 1.0, "Set time", func(val: float) -> void: main.dev_set_time(val))
	_grid(v, "BOAT", [
		["Repair all damage", func() -> void: main.dev_repair()],
		["Restore crew", func() -> void: main.dev_restore_crew()],
		["Invulnerable: toggle", func() -> void: main.dev_toggle("invulnerable")],
		["Unlimited weapons: toggle", func() -> void: main.dev_toggle("unlimited")],
		["Full battery", func() -> void: main.sub.battery = 100.0],
		["Position fix", func() -> void: main.dev_fix()],
	])
	_grid(v, "TEST CONTACTS (NOT CAMPAIGN SHIPS)", [
		["Merchant 6 km ahead", func() -> void: main.dev_spawn("merchant")],
		["Warship 8 km ahead", func() -> void: main.dev_spawn("warship")],
		["Fishing boat 4 km", func() -> void: main.dev_spawn("fishing")],
		["Remove test contacts", func() -> void: main.dev_clear_test()],
	])
	_grid(v, "WEATHER AND SEA", [
		["Clear", func() -> void: main.dev_weather("clear")],
		["Overcast", func() -> void: main.dev_weather("overcast")],
		["Fog", func() -> void: main.dev_weather("fog")],
		["Snow", func() -> void: main.dev_weather("snow")],
		["Gale (rough sea)", func() -> void: main.dev_weather("gale")],
	])
	_grid(v, "HAZARDS", [
		["Iceberg 1.5 km ahead", func() -> void: main.dev_hazard("berg")],
		["Shoal check ahead", func() -> void: main.dev_hazard("shoal")],
	])
	_grid(v, "STATIONS AND LOCATIONS", [
		["Control", func() -> void: main.set_view(0)], ["Periscope", func() -> void: main.set_view(1)],
		["Exterior", func() -> void: main.set_view(2)], ["Sonar", func() -> void: main.set_view(3)],
		["Chart", func() -> void: main.set_view(4)], ["Mess", func() -> void: main.set_view(5)],
		["Cabin", func() -> void: main.set_view(6)], ["Engine room", func() -> void: main.set_view(7)],
		["Cinematic", func() -> void: main.set_view(9)],
	])
	_status = UiStyle.label("", 12, UiStyle.DIM, UiStyle.mono())
	v.add_child(_status)
	visible = false


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(110, 0)
	s.allow_greater = false
	return s


func _num(parent: VBoxContainer, label_text: String, lo: float, hi: float, step: float, btn: String, cb: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	var l := UiStyle.label(label_text, 13, UiStyle.WHITE)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var s := _spin(lo, hi, step)
	row.add_child(s)
	var b := UiStyle.button(btn, 12)
	b.pressed.connect(func() -> void: cb.call(s.value))
	row.add_child(b)
	parent.add_child(row)
	return s


func _grid(parent: VBoxContainer, title: String, items: Array) -> void:
	parent.add_child(UiStyle.label(title, 11, UiStyle.DIM))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for it in items:
		var b := UiStyle.button(String(it[0]), 12)
		b.custom_minimum_size = Vector2(145, 0)
		b.pressed.connect(it[1])
		g.add_child(b)
	parent.add_child(g)


func toggle() -> void:
	visible = not visible
	if visible and main:
		_depth.value = main.sub.depth
		_speed.value = main.sub.knots()
		_x.value = main.sub.position.x / 1000.0
		_z.value = main.sub.position.z / 1000.0
		_time.value = main.clock.scale()


func _process(_d: float) -> void:
	if visible and main:
		_status.text = "pos %.2f / %.2f km   depth %.1f m   hull %d%%   inv %s   unl %s" % [main.sub.position.x / 1000.0, main.sub.position.z / 1000.0, main.sub.depth, int(main.sub.hull), "ON" if main.sub.invulnerable else "off", "ON" if main.unlimited_weapons else "off"]
