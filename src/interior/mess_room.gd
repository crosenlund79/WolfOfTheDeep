class_name MessRoom
extends InteriorRoom
## Galley and mess: Basse's stove, the coffee machine, two tables (one of
## them is where the cards come out), warm light and personal clutter.

var clock_label: Label3D
var poker_table: Node3D


func _init() -> void:
	room_name = "Mess"
	origin = Vector3(60.0, -5000.0, 0.0)
	eye = Vector3(0.0, 1.62, 2.1)


func build() -> void:
	var size := Vector3(7.0, 2.4, 6.0)
	shell(size, Color(0.62, 0.6, 0.55), Color(0.2, 0.17, 0.14))
	var steel := mat(Color(0.7, 0.72, 0.74), 0.35, 0.8)
	var wood := mat(Color(0.36, 0.25, 0.16), 0.6, 0.0)
	var bench := mat(Color(0.22, 0.3, 0.42), 0.7, 0.0)
	# Galley along the starboard bulkhead.
	box(Vector3(1.0, 0.92, 4.6), Vector3(2.95, 0.46, -0.4), steel)
	box(Vector3(1.0, 0.04, 4.6), Vector3(2.95, 0.94, -0.4), mat(Color(0.3, 0.3, 0.32), 0.3, 0.9))
	box(Vector3(0.7, 0.5, 4.4), Vector3(3.1, 1.85, -0.4), steel)
	for z in [-1.8, -0.9]:
		cyl(0.17, 0.22, Vector3(2.85, 1.06, z), mat(Color(0.5, 0.52, 0.55), 0.3, 0.9))
	var stove_glow := box(Vector3(0.5, 0.02, 0.9), Vector3(2.85, 0.955, -1.35), glow(Color(1.0, 0.35, 0.1), 0.8))
	stove_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Coffee machine with its little red light.
	box(Vector3(0.4, 0.5, 0.35), Vector3(2.9, 1.2, 1.1), mat(Color(0.1, 0.1, 0.1), 0.4, 0.5))
	box(Vector3(0.04, 0.04, 0.02), Vector3(2.68, 1.32, 1.1), glow(Color(1.0, 0.1, 0.05), 6.0))
	var coffee := Node3D.new()
	coffee.position = Vector3(2.9, 1.2, 1.1)
	root.add_child(coffee)
	add_interactable(coffee, "object", "coffee", "COFFEE")
	# Shelves with tins.
	for i in 8:
		cyl(0.05, 0.12, Vector3(3.3, 1.55, -2.2 + i * 0.22), mat(Color.from_hsv(randf(), 0.5, 0.6), 0.6, 0.3))
	# Two tables with benches.
	for t in [[-1.2, -1.2], [-1.2, 1.4]]:
		var tx := float(t[0])
		var tz := float(t[1])
		box(Vector3(1.0, 0.05, 1.8), Vector3(tx, 0.75, tz), wood)
		cyl(0.06, 0.72, Vector3(tx, 0.37, tz), steel)
		box(Vector3(0.45, 0.45, 1.8), Vector3(tx - 0.85, 0.22, tz), bench)
		box(Vector3(0.45, 0.45, 1.8), Vector3(tx + 0.85, 0.22, tz), bench)
	poker_table = Node3D.new()
	poker_table.position = Vector3(-1.2, 0.8, -1.2)
	root.add_child(poker_table)
	box(Vector3(0.9, 0.01, 1.6), Vector3(-1.2, 0.78, -1.2), mat(Color(0.1, 0.32, 0.2), 0.9, 0.0))
	add_interactable(poker_table, "object", "poker", "CARDS")
	# Pinned photos and the watch bill.
	for i in 6:
		box(Vector3(0.02, 0.16, 0.22), Vector3(-3.43, 1.5 + (i % 2) * 0.22, -2.0 + i * 0.32), mat(Color.from_hsv(randf(), 0.25, 0.75), 0.9, 0.0))
	box(Vector3(0.02, 0.5, 0.4), Vector3(-3.43, 1.45, 1.6), mat(Color(0.92, 0.92, 0.88), 0.9, 0.0))
	clock_label = text3d("00:00", Vector3(0.0, 1.95, -2.93), 64, Color(1.0, 0.85, 0.6))
	text3d("MESS", Vector3(-1.6, 2.15, -2.93), 40, Color(0.9, 0.9, 0.85))
	# Warm lighting.
	for p in [Vector3(-1.2, 2.25, -1.2), Vector3(-1.2, 2.25, 1.4), Vector3(2.4, 2.25, -0.5)]:
		box(Vector3(0.9, 0.04, 0.14), p + Vector3(0, 0.1, 0), glow(Color(1.0, 0.86, 0.62), 2.5))
		lamp(p, Color(1.0, 0.82, 0.6), 1.1, 4.0)
	env.ambient_light_color = Color(0.4, 0.34, 0.28)
	anchors = {
		"galley": [Vector3(2.2, 0, -1.3), PI * 0.5, false],
		"seat_1": [Vector3(-2.05, 0, -1.7), -PI * 0.5, true],
		"seat_2": [Vector3(-0.35, 0, -1.7), PI * 0.5, true],
		"seat_3": [Vector3(-2.05, 0, -0.7), -PI * 0.5, true],
		"seat_4": [Vector3(-0.35, 0, -0.7), PI * 0.5, true],
		"seat_5": [Vector3(-2.05, 0, 1.2), -PI * 0.5, true],
		"seat_6": [Vector3(-0.35, 0, 1.2), PI * 0.5, true],
		"seat_7": [Vector3(-2.05, 0, 1.9), -PI * 0.5, true],
	}
