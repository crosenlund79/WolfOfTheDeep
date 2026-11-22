class_name CrewFigure
extends Node3D
## A simple, recognisable crew member: proportions, clothing and a few
## personal details. Breathes, glances around, sits or stands.

var member_id := ""
var display_name := ""
var seated := false
var _torso: Node3D
var _head: Node3D
var _legs: Node3D
var _label: Label3D
var _t := 0.0
var _glance := 0.0
var _glance_target := 0.0
var _glance_t := 2.0

const STYLE := {
	"miller": {"h": 1.8, "w": 1.0, "top": Color(0.12, 0.15, 0.22), "legs": Color(0.08, 0.09, 0.11), "hair": Color(0.62, 0.62, 0.6), "skin": Color(0.86, 0.7, 0.6)},
	"basse": {"h": 1.74, "w": 1.25, "top": Color(0.88, 0.88, 0.85), "legs": Color(0.15, 0.15, 0.16), "hair": Color(0.12, 0.12, 0.13), "skin": Color(0.88, 0.68, 0.58), "apron": true, "beanie": true, "beard": true},
	"freja": {"h": 1.68, "w": 0.9, "top": Color(0.12, 0.15, 0.22), "legs": Color(0.08, 0.09, 0.11), "hair": Color(0.85, 0.76, 0.5), "skin": Color(0.92, 0.78, 0.7), "headphones": true, "bun": true},
	"erik": {"h": 1.86, "w": 1.1, "top": Color(0.2, 0.22, 0.24), "legs": Color(0.2, 0.22, 0.24), "hair": Color(0.45, 0.33, 0.22), "skin": Color(0.88, 0.7, 0.6), "overalls": true, "beard": true},
	"maya": {"h": 1.65, "w": 0.9, "top": Color(0.12, 0.15, 0.22), "legs": Color(0.08, 0.09, 0.11), "hair": Color(0.06, 0.05, 0.05), "skin": Color(0.86, 0.7, 0.56), "ponytail": true},
	"default": {"h": 1.76, "w": 1.0, "top": Color(0.16, 0.22, 0.32), "legs": Color(0.16, 0.22, 0.32), "hair": Color(0.25, 0.2, 0.16), "skin": Color(0.85, 0.68, 0.58)},
}


func setup(id: String, p_name: String) -> void:
	member_id = id
	display_name = p_name
	var st: Dictionary = STYLE.get(id, STYLE["default"])
	var h := float(st["h"])
	var w := float(st["w"])
	var k := h / 1.76
	var top := _mat(st["top"])
	var legs_m := _mat(st["legs"])
	var skin := _mat(st["skin"])
	var hair := _mat(st["hair"])
	_legs = Node3D.new()
	add_child(_legs)
	for sx in [-0.1, 0.1]:
		_part(_legs, _capsule(0.075 * w, 0.88 * k), Vector3(sx * w, 0.44 * k, 0), legs_m)
		_part(_legs, _box(Vector3(0.11, 0.07, 0.26)), Vector3(sx * w, 0.035, 0.05), _mat(Color(0.05, 0.05, 0.05)))
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.88 * k, 0)
	add_child(_torso)
	_part(_torso, _capsule(0.19 * w, 0.62 * k), Vector3(0, 0.3 * k, 0), top)
	for sx2 in [-1.0, 1.0]:
		var arm := _part(_torso, _capsule(0.055 * w, 0.62 * k), Vector3(sx2 * 0.25 * w, 0.27 * k, 0.02), top)
		arm.rotation.z = sx2 * 0.08
		_part(_torso, _sphere(0.05), Vector3(sx2 * 0.27 * w, -0.04, 0.04), skin)
	if st.get("apron", false):
		_part(_torso, _box(Vector3(0.34 * w, 0.55 * k, 0.03)), Vector3(0, 0.12 * k, 0.18 * w), _mat(Color(0.95, 0.95, 0.93)))
	if st.get("overalls", false):
		_part(_torso, _box(Vector3(0.06, 0.4 * k, 0.03)), Vector3(-0.1, 0.38 * k, 0.18 * w), _mat(Color(0.85, 0.42, 0.08)))
		_part(_torso, _box(Vector3(0.06, 0.4 * k, 0.03)), Vector3(0.1, 0.38 * k, 0.18 * w), _mat(Color(0.85, 0.42, 0.08)))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.7 * k, 0)
	_torso.add_child(_head)
	_part(_head, _sphere(0.105), Vector3(0, 0.1, 0), skin)
	_part(_head, _sphere(0.11), Vector3(0, 0.15, -0.015), hair).scale = Vector3(1.0, 0.62, 1.0)
	if st.get("beanie", false):
		_part(_head, _sphere(0.115), Vector3(0, 0.17, -0.005), _mat(Color(0.18, 0.2, 0.24))).scale = Vector3(1.0, 0.7, 1.0)
	if st.get("beard", false):
		_part(_head, _sphere(0.08), Vector3(0, 0.03, 0.06), hair).scale = Vector3(1.0, 0.8, 0.6)
	if st.get("headphones", false):
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.105
		tm.outer_radius = 0.125
		band.mesh = tm
		band.material_override = _mat(Color(0.1, 0.1, 0.1))
		band.position = Vector3(0, 0.12, 0)
		band.rotation.z = PI * 0.5
		_head.add_child(band)
		for sx3 in [-0.11, 0.11]:
			_part(_head, _cyl(0.045, 0.04), Vector3(sx3, 0.1, 0), _mat(Color(0.1, 0.1, 0.1))).rotation.z = PI * 0.5
	if st.get("bun", false):
		_part(_head, _sphere(0.05), Vector3(0, 0.2, -0.09), hair)
	if st.get("ponytail", false):
		_part(_head, _capsule(0.035, 0.22), Vector3(0, 0.08, -0.12), hair).rotation.x = 0.4
	_label = Label3D.new()
	_label.text = p_name
	_label.font = UiStyle.display()
	_label.font_size = 40
	_label.pixel_size = 0.0022
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.85, 0.92, 1.0, 0.0)
	_label.outline_size = 6
	_label.position = Vector3(0, h + 0.22, 0)
	_label.no_depth_test = true
	add_child(_label)
	_glance_t = randf_range(1.0, 5.0)


func set_seated(v: bool) -> void:
	seated = v
	if v:
		_legs.rotation.x = -PI * 0.5
		_legs.position = Vector3(0, 0.45, 0.0)
		_torso.position.y = 0.45
	else:
		_legs.rotation.x = 0.0
		_legs.position = Vector3.ZERO
		_torso.position.y = 0.88 * (float((STYLE.get(member_id, STYLE["default"]) as Dictionary)["h"]) / 1.76)


func show_label(v: bool) -> void:
	_label.modulate.a = move_toward(_label.modulate.a, 0.95 if v else 0.0, 0.15)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_torso.scale = Vector3(1.0, 1.0 + sin(_t * 1.6 + float(member_id.length())) * 0.008, 1.0)
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance_t = randf_range(2.5, 7.0)
		_glance_target = randf_range(-0.6, 0.6) if randf() < 0.6 else 0.0
	_glance = lerpf(_glance, _glance_target, 1.0 - exp(-delta * 3.0))
	_head.rotation.y = _glance


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = CommandRoom.LAYER
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c
