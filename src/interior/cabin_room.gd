class_name CabinRoom
extends InteriorRoom
## The captain's cabin: bunk, desk and lamp, the patrol log, a repeater for
## depth and time. Rest is taken here.

var clock_label: Label3D
var depth_label: Label3D


func _init() -> void:
	room_name = "Cabin"
	origin = Vector3(120.0, -5000.0, 0.0)
	eye = Vector3(0.3, 1.55, 1.2)
	look_range = Vector2(2.2, 0.8)


func build() -> void:
	var size := Vector3(3.2, 2.2, 3.4)
	shell(size, Color(0.55, 0.56, 0.54), Color(0.18, 0.16, 0.14))
	var wood := mat(Color(0.4, 0.28, 0.17), 0.6, 0.0)
	# Bunk with blanket and pillow.
	box(Vector3(0.95, 0.4, 2.0), Vector3(-1.1, 0.35, -0.5), wood)
	var bunk := box(Vector3(0.9, 0.16, 1.95), Vector3(-1.1, 0.62, -0.5), mat(Color(0.2, 0.26, 0.38), 0.95, 0.0))
	box(Vector3(0.5, 0.1, 0.3), Vector3(-1.1, 0.75, -1.3), mat(Color(0.85, 0.85, 0.82), 0.95, 0.0))
	add_interactable(bunk, "object", "rest", "REST")
	# Desk, lamp, logbook.
	box(Vector3(1.1, 0.05, 0.6), Vector3(1.0, 0.76, -1.2), wood)
	box(Vector3(0.05, 0.75, 0.55), Vector3(0.48, 0.38, -1.2), wood)
	box(Vector3(0.05, 0.75, 0.55), Vector3(1.52, 0.38, -1.2), wood)
	var log_book := box(Vector3(0.32, 0.04, 0.24), Vector3(0.95, 0.8, -1.15), mat(Color(0.25, 0.08, 0.06), 0.8, 0.0))
	add_interactable(log_book, "object", "log", "PATROL LOG")
	cyl(0.02, 0.35, Vector3(1.35, 0.95, -1.35), mat(Color(0.2, 0.2, 0.2), 0.4, 0.6))
	cyl(0.1, 0.1, Vector3(1.35, 1.12, -1.35), glow(Color(1.0, 0.78, 0.45), 1.5))
	lamp(Vector3(1.3, 1.05, -1.2), Color(1.0, 0.75, 0.45), 1.2, 3.2)
	# Photo on the desk and a chart on the bulkhead.
	box(Vector3(0.18, 0.13, 0.02), Vector3(0.7, 0.86, -1.42), mat(Color(0.7, 0.62, 0.5), 0.9, 0.0), Vector3(-0.3, 0, 0))
	box(Vector3(0.9, 0.6, 0.02), Vector3(1.0, 1.55, -1.64), mat(Color(0.8, 0.82, 0.78), 0.9, 0.0))
	# Repeaters.
	box(Vector3(0.5, 0.25, 0.04), Vector3(-0.2, 1.75, -1.65), mat(Color(0.05, 0.05, 0.06), 0.4, 0.4))
	clock_label = text3d("00:00", Vector3(-0.2, 1.8, -1.62), 40, Color(1.0, 0.5, 0.3))
	depth_label = text3d("0 M", Vector3(-0.2, 1.7, -1.62), 28, Color(1.0, 0.5, 0.3))
	box(Vector3(0.8, 0.03, 0.14), Vector3(0.0, 2.17, 0.0), glow(Color(0.85, 0.9, 1.0), 1.0))
	lamp(Vector3(0.0, 2.0, 0.0), Color(0.85, 0.9, 1.0), 0.35, 3.0)
	env.ambient_light_color = Color(0.32, 0.28, 0.24)
	text3d("CAPTAIN", Vector3(1.55, 2.0, 1.66), 30, Color(0.85, 0.85, 0.8), PI)
