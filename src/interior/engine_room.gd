class_name EngineRoom
extends InteriorRoom
## Engine room: two diesel generators, the air-independent plant with its
## oxygen tanks, the main motor and the switchboard. Shakes when the diesels run.

var diesels: Array[Node3D] = []
var battery_label: Label3D


func _init() -> void:
	room_name = "Engine"
	origin = Vector3(180.0, -5000.0, 0.0)
	eye = Vector3(0.0, 1.65, 3.2)


func build() -> void:
	var size := Vector3(7.0, 2.8, 8.0)
	shell(size, Color(0.5, 0.52, 0.5), Color(0.12, 0.13, 0.13))
	var green := mat(Color(0.28, 0.36, 0.3), 0.5, 0.4)
	var steel := mat(Color(0.55, 0.57, 0.58), 0.35, 0.8)
	var yellow := mat(Color(0.75, 0.6, 0.1), 0.5, 0.3)
	for sx in [-1.8, 1.8]:
		var d := Node3D.new()
		d.position = Vector3(sx, 0, -1.0)
		root.add_child(d)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 1.5, 3.2)
		b.mesh = bm
		b.material_override = green
		b.position = Vector3(0, 0.75, 0)
		b.layers = LAYER
		d.add_child(b)
		for i in 6:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.14
			cm.bottom_radius = 0.14
			cm.height = 0.35
			c.mesh = cm
			c.material_override = steel
			c.position = Vector3(0, 1.65, -1.25 + i * 0.5)
			c.layers = LAYER
			d.add_child(c)
		diesels.append(d)
	# Oxygen tanks of the air-independent plant.
	for i in 3:
		cyl(0.45, 2.2, Vector3(-2.6 + i * 1.0, 1.1, 2.9), mat(Color(0.75, 0.78, 0.82), 0.4, 0.6))
	text3d("LOX", Vector3(-1.6, 1.6, 2.4), 48, Color(0.1, 0.2, 0.5))
	cyl(0.7, 2.2, Vector3(0, 0.75, -3.2), steel, Vector3(PI * 0.5, 0, 0), 24)
	# Switchboard with indicators.
	box(Vector3(2.4, 1.8, 0.3), Vector3(2.4, 0.9, 3.4), mat(Color(0.22, 0.24, 0.26), 0.5, 0.5))
	for i in 18:
		var c2 := Color(0.2, 1.0, 0.3) if i % 5 != 3 else Color(1.0, 0.6, 0.1)
		box(Vector3(0.05, 0.05, 0.02), Vector3(1.5 + (i % 6) * 0.35, 1.2 + (i / 6) * 0.25, 3.24), glow(c2, 4.0))
	battery_label = text3d("BATTERY 80%", Vector3(2.4, 1.7, 3.24), 36, Color(0.4, 1.0, 0.5), PI)
	for p in [Vector3(-1.8, 2.6, -1.0), Vector3(1.8, 2.6, -1.0), Vector3(0, 2.6, 2.4)]:
		box(Vector3(1.4, 0.04, 0.15), p + Vector3(0, 0.12, 0), glow(Color(0.85, 0.92, 1.0), 2.5))
		lamp(p, Color(0.85, 0.92, 1.0), 1.0, 5.0)
	env.ambient_light_color = Color(0.28, 0.3, 0.3)
	anchors = {
		"panel": [Vector3(2.4, 0, 2.6), 0.0, false],
		"diesel": [Vector3(0.0, 0, -0.5), -PI * 0.5, false],
	}


func advance(dt: float) -> void:
	super.advance(dt)
	if not active or sub == null:
		return
	var shake := 0.006 if sub.diesels_running else 0.0
	for d in diesels:
		d.position.y = sin(_t * 60.0 + d.position.x) * shake
	battery_label.text = "BATTERY %d%%   AIP %dH" % [int(sub.battery), int(sub.aip_hours)]
